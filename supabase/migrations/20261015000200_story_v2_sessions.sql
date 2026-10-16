-- «قصص» V2 (docs/plans/STORIES-V2-PLAN.md §5): a rewritten case deals a new
-- version at every table, so the culprit is not fixed per story. The server
-- picks who did it, keeps the pick as a session, and pays the story's one
-- first solve only when the table's answer matches that session. Groups send
-- who only; solo sends who, why and how. Offline tables deal locally and
-- earn nothing.

-- Who can be the culprit in each rewritten case, with the answers solo must
-- name. Rows follow assets/stories_v2/*.json; a Dart test fails on drift.
create table if not exists public.story_v2_suspects(
  story_id text not null references public.story_rewards(story_id),
  suspect_id text not null check (suspect_id ~ '^[a-z0-9_]{3,40}$'),
  motive_id text not null check (motive_id ~ '^[a-z0-9_]{3,40}$'),
  method_id text not null check (method_id ~ '^[a-z0-9_]{3,40}$'),
  partner_id text check (partner_id ~ '^[a-z0-9_]{3,40}$'),
  primary key (story_id, suspect_id)
);
alter table public.story_v2_suspects enable row level security;
revoke all on public.story_v2_suspects from public, anon, authenticated;
grant select on public.story_v2_suspects to service_role;

insert into public.story_v2_suspects(story_id,suspect_id,motive_id,method_id,partner_id) values
  ('qahwet_el_moallem','n01','rent_eviction','sprayed_tobacco',null),
  ('qahwet_el_moallem','n02','inheritance','sprayed_tobacco',null),
  ('qahwet_el_moallem','n03','stall_removal','sprayed_tobacco',null),
  ('qahwet_el_moallem','n04','denied_debt','hose_tip',null),
  ('qahwet_el_moallem','n05','clinic_drugs','hose_tip',null),
  ('qahwet_el_moallem','n06','wages_firing','hose_tip',null),
  ('qahwet_el_moallem','n07','building_deal','hose_tip',null),
  ('qahwet_el_moallem','n08','son_fired','sprayed_tobacco',null),
  ('qahwet_el_moallem','n09','trust_receipt','sprayed_tobacco',null),
  ('qahwet_el_moallem','n10','association_money','hose_tip',null)
on conflict (story_id, suspect_id) do update set motive_id=excluded.motive_id,
  method_id=excluded.method_id, partner_id=excluded.partner_id;

create table if not exists public.story_v2_sessions(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  story_id text not null references public.story_rewards(story_id),
  players int not null check (players between 1 and 10),
  culprit_id text not null,
  partner_id text,
  -- clock_timestamp: two tables dealt in one transaction still order.
  started_at timestamptz not null default clock_timestamp(),
  answered_at timestamptz
);
create index if not exists story_v2_sessions_user_story
  on public.story_v2_sessions(user_id, story_id, started_at desc);
alter table public.story_v2_sessions enable row level security;
revoke all on public.story_v2_sessions from public, anon, authenticated;
grant select, insert, update, delete on public.story_v2_sessions to service_role;

-- Deals who did it for one table. The account's last three culprits of this
-- story, and the phone's own ([p_avoid]), are skipped while anyone else is
-- left. A 5–10 table plays the culprit's partner half the time.
create or replace function public.start_story_session(
  p_user uuid, p_story text, p_players int, p_avoid text[] default '{}')
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare picked public.story_v2_suspects; partner text; session_id uuid;
  skip text[];
begin
  if p_players is null or p_players not between 1 and 10
      or coalesce(cardinality(p_avoid), 0) > 10 then
    raise exception 'BAD_REQUEST';
  end if;
  if not exists(select 1 from public.story_v2_suspects where story_id=p_story) then
    raise exception 'NOT_FOUND';
  end if;
  perform pg_advisory_xact_lock(hashtext('story_v2:' || p_user::text));
  if (select count(*) from public.story_v2_sessions where user_id=p_user
      and started_at > now() - interval '1 hour') >= 30 then
    raise exception 'STORY_LIMIT';
  end if;

  select coalesce(array_agg(culprit_id), '{}') into skip from (
    select culprit_id from public.story_v2_sessions
     where user_id=p_user and story_id=p_story
     order by started_at desc limit 3) recent;
  skip := skip || coalesce(p_avoid, '{}');
  select * into picked from public.story_v2_suspects
   where story_id=p_story and suspect_id <> all(skip)
   order by random() limit 1;
  if not found then
    select * into picked from public.story_v2_suspects
     where story_id=p_story order by random() limit 1;
  end if;
  partner := case when p_players >= 5 and picked.partner_id is not null
      and random() < 0.5 then picked.partner_id end;

  -- Ten tables per story are plenty of history; older ones go once they
  -- no longer count towards the hourly limit.
  delete from public.story_v2_sessions where id in (
    select id from public.story_v2_sessions
     where user_id=p_user and story_id=p_story
     order by started_at desc offset 9) and started_at < now() - interval '1 hour';
  insert into public.story_v2_sessions(user_id, story_id, players, culprit_id, partner_id)
    values (p_user, p_story, p_players, picked.suspect_id, partner)
    returning id into session_id;
  return jsonb_build_object('sessionId', session_id,
    'culprit', picked.suspect_id, 'partner', partner);
end $$;

-- One answer per session, at least a minute after the deal and within twelve
-- hours. A right answer pays the story's first solve (once per account,
-- shared with the old flow's story_solves); a wrong one only closes the
-- session.
create or replace function public.claim_story_session(
  p_user uuid, p_session uuid, p_who text, p_why text default null, p_how text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.story_v2_sessions; truth public.story_v2_suspects;
  r public.story_rewards; right_answer boolean := false; n int := 0; xp int := 0;
begin
  perform pg_advisory_xact_lock(hashtext('story_v2:' || p_user::text));
  select * into s from public.story_v2_sessions
   where id=p_session and user_id=p_user for update;
  if not found or s.answered_at is not null
      or s.started_at > now() - interval '1 minute'
      or s.started_at < now() - interval '12 hours' then
    return jsonb_build_object('granted', 0, 'xpGranted', 0, 'solved', false,
      'balance', (select balance from public.wallet_accounts where user_id=p_user));
  end if;
  update public.story_v2_sessions set answered_at=now() where id=s.id;
  select * into truth from public.story_v2_suspects
   where story_id=s.story_id and suspect_id=s.culprit_id;
  right_answer := coalesce(p_who = s.culprit_id and (s.players > 1
      or (p_why = truth.motive_id and p_how = truth.method_id)), false);
  if right_answer then
    select * into r from public.story_rewards where story_id=s.story_id;
    insert into public.story_solves(user_id, story_id) values (p_user, s.story_id)
      on conflict do nothing;
    get diagnostics n = row_count;
    if n = 1 then
      perform public.credit_earned(p_user, 'story_first_solve', r.coins, null,
        'story:' || s.story_id);
      xp := public.casebook_grant_season_xp(p_user, 'story:' || s.story_id, r.xp);
    end if;
  end if;
  return jsonb_build_object(
    'granted', case when n = 1 then r.coins else 0 end,
    'xpGranted', xp,
    'solved', right_answer,
    'balance', (select balance from public.wallet_accounts where user_id=p_user));
end $$;

revoke all on function public.start_story_session(uuid,text,int,text[]) from public,anon,authenticated;
grant execute on function public.start_story_session(uuid,text,int,text[]) to service_role;
revoke all on function public.claim_story_session(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.claim_story_session(uuid,uuid,text,text,text) to service_role;
