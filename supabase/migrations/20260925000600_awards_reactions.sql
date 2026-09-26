-- Phase 109 "Awards, reactions, welcome-back": match awards at the result,
-- quick reactions in the lobby and on the result, and the Founder badge.
--
-- Additive only. Every feature ships OFF (a missing config row reads as off)
-- and is announced through `economy_capabilities` → `fun`.
--
-- Zero leakage (Doc 05): awards are computed only for a room that is
-- `finished`, whose phase is `result` and whose outcome is public — the moment
-- the result screen flips every card. A live room answers `ready:false` and
-- nothing is stored for it. Reactions are refused by the server during every
-- match phase: only a lobby (before any role exists) or a finished result.
-- The engine never sees any of it.
--
-- Lock order is unchanged: the caller's wallet lock first (same key as every
-- other wallet writer), then rows.

-- 0. Configuration -------------------------------------------------------------
alter table public.economy_config
  add column if not exists awards_enabled boolean not null default false,
  add column if not exists reactions_enabled boolean not null default false,
  add column if not exists founder_enabled boolean not null default false,
  add column if not exists founder_window_start timestamptz,
  add column if not exists founder_window_days int not null default 30
    check (founder_window_days between 1 and 60),
  add column if not exists award_mvp_coins bigint not null default 15
    check (award_mvp_coins between 0 and 50),
  add column if not exists award_coins bigint not null default 5
    check (award_coins between 0 and 20);

-- 1. Ledger kind (extends whatever list is current) ------------------------------
do $$
declare kinds text[];
begin
  select coalesce(array_agg(distinct m[1]), '{}') into kinds
    from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z0-9_]+)''', 'g') m
   where c.conname='wallet_ledger_kind_check' and c.conrelid='public.wallet_ledger'::regclass;
  select array_agg(distinct k order by k) into kinds from unnest(kinds || array['match_award']) k;
  alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
  -- Written as an IN list so the constraint reads back as quoted words the
  -- next migration's scan finds (an array literal would read back empty).
  execute format('alter table public.wallet_ledger add constraint wallet_ledger_kind_check '
    'check (kind in (%s))', (select string_agg(quote_literal(k), ',' order by k) from unnest(kinds) k));
end $$;

create or replace function public.fun_on(p_flag text)
returns boolean language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config;
begin
  select * into cfg from public.economy_config;
  return coalesce(case p_flag
    when 'awards' then cfg.awards_enabled
    when 'reactions' then cfg.reactions_enabled
    when 'founder' then cfg.founder_enabled and cfg.founder_window_start is not null
    end, false);
end $$;

-- A room at its public end: finished, on the result, outcome public.
create or replace function public.room_at_public_end(p_room uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.rooms r join public.room_state s on s.room_id=r.id
    where r.id=p_room and r.status='finished' and s.phase='result'
      and s.public_data->>'outcome' in ('mafia','town'))
$$;

-- 2. Awards ------------------------------------------------------------------------
create table public.match_awards (
  room_id uuid not null references public.rooms(id) on delete cascade,
  award text not null check (award in ('mvp','sharp_eye','survivor','silver_tongue',
    'lifesaver','perfect_crime','first_blood')),
  user_id uuid not null,
  seat int not null,
  primary key (room_id, award, user_id)
);
create table public.match_awards_computed (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  computed_at timestamptz not null default now()
);
alter table public.match_awards enable row level security;
alter table public.match_awards_computed enable row level security;
revoke all on public.match_awards, public.match_awards_computed from public, anon, authenticated;
grant all on public.match_awards, public.match_awards_computed to service_role;

-- Computes a room's awards once, from what is public at its end. Returns
-- false (and stores nothing) for any room that is not at its public end.
--
-- Definitions (mirrored by lib/ui/postgame/match_awards.dart for pass-and-play,
-- which has no Silver Tongue). Kicked players are never awarded. A day's
-- ballot is its final round. "Town" is every non-Mafia role.
--   sharp_eye      town voter with the most ballots on Mafia (≥1); ties →
--                  earliest such ballot, then lowest seat.
--   first_blood    the first day a Mafia was voted out: the earliest town
--                  ballot on that Mafia.
--   silver_tongue  over Mafia voted out: each town voter on the eliminated
--                  scores the other voters who joined them; most (≥1) wins;
--                  ties → earliest ballot, then seat.
--   lifesaver      every Doctor whose protection blocked a kill.
--   perfect_crime  Mafia won and no Mafia was eliminated: every Mafia.
--   survivor       every living member of the winning team.
--   mvp            one winner: 3·ballots on Mafia (town) + 3·saves +
--                  2·ballots on a town player voted out (Mafia) + 2 if alive;
--                  ties → lowest seat.
create or replace function public.compute_match_awards(p_room uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_outcome text; pub jsonb;
begin
  if not public.room_at_public_end(p_room) then return false; end if;
  perform pg_advisory_xact_lock(hashtextextended('awards:'||p_room::text,92));
  if exists(select 1 from public.match_awards_computed where room_id=p_room) then
    return true;
  end if;
  select s.public_data into pub from public.room_state s where s.room_id=p_room;
  v_outcome := pub->>'outcome';

  create temp table if not exists fun_players(user_id uuid, seat int, mafia boolean,
    alive boolean, winner boolean) on commit drop;
  create temp table if not exists fun_ballots(day int, voter uuid, target uuid,
    at timestamptz) on commit drop;
  create temp table if not exists fun_day_out(day int, target uuid) on commit drop;
  delete from fun_players; delete from fun_ballots; delete from fun_day_out;

  insert into fun_players
    select p.user_id, p.seat, p.role='mafia', p.alive,
      (case when p.role='mafia' then 'mafia' else 'town' end)=v_outcome
      from public.room_players p
     where p.room_id=p_room and not p.kicked and p.role is not null;
  insert into fun_ballots
    select v.day, v.voter_id, v.target_id, v.created_at from public.votes v
     where v.room_id=p_room and v.target_id is not null
       and v.round=(select max(w.round) from public.votes w
                     where w.room_id=p_room and w.day=v.day)
       and exists(select 1 from fun_players f where f.user_id=v.voter_id);
  insert into fun_day_out
    select (e.value->>'number')::int, p.user_id
      from jsonb_each(coalesce(pub->'eliminations','{}'::jsonb)) e
      join public.room_players p on p.room_id=p_room and p.seat=e.key::int
     where e.value->>'phase'='day';

  -- sharp_eye
  insert into public.match_awards
    select p_room,'sharp_eye',x.voter,x.seat from (
      select b.voter, f.seat, count(*) n, min(b.at) first from fun_ballots b
        join fun_players f on f.user_id=b.voter and not f.mafia
        join fun_players t on t.user_id=b.target and t.mafia
       group by b.voter, f.seat order by n desc, first, f.seat limit 1) x;

  -- first_blood
  insert into public.match_awards
    select p_room,'first_blood',b.voter,f.seat from fun_ballots b
      join fun_players f on f.user_id=b.voter and not f.mafia
      join (select o.day, o.target from fun_day_out o
              join fun_players t on t.user_id=o.target and t.mafia
             order by o.day limit 1) d on d.day=b.day and d.target=b.target
     order by b.at, f.seat limit 1;

  -- silver_tongue
  insert into public.match_awards
    select p_room,'silver_tongue',x.voter,x.seat from (
      select b.voter, f.seat,
          sum((select count(*) from fun_ballots c
                where c.day=b.day and c.target=b.target and c.voter<>b.voter)) n,
          min(b.at) first
        from fun_ballots b
        join fun_players f on f.user_id=b.voter and not f.mafia
        join fun_day_out o on o.day=b.day and o.target=b.target
        join fun_players t on t.user_id=o.target and t.mafia
       group by b.voter, f.seat) x
     where x.n >= 1 order by x.n desc, x.first, x.seat limit 1;

  -- lifesaver
  insert into public.match_awards
    select distinct p_room,'lifesaver',a.actor_id,f.seat
      from public.night_actions a
      join public.night_resolution_private n on n.room_id=a.room_id and n.night=a.night
      join public.room_players t on t.room_id=a.room_id and t.seat=n.saved_seat
      join fun_players f on f.user_id=a.actor_id
      join public.room_players d on d.room_id=a.room_id and d.user_id=a.actor_id
     where a.room_id=p_room and a.action='protect' and a.target_id=t.user_id
       and d.role='doctor'
    on conflict do nothing;

  -- perfect_crime
  if v_outcome='mafia' and not exists(select 1 from public.room_players p
       where p.room_id=p_room and p.role='mafia' and (not p.alive or p.kicked)) then
    insert into public.match_awards
      select p_room,'perfect_crime',f.user_id,f.seat from fun_players f where f.mafia;
  end if;

  -- survivor
  insert into public.match_awards
    select p_room,'survivor',f.user_id,f.seat from fun_players f where f.winner and f.alive;

  -- mvp
  insert into public.match_awards
    select p_room,'mvp',x.user_id,x.seat from (
      select f.user_id, f.seat,
        3*(select count(*) from fun_ballots b join fun_players t on t.user_id=b.target
            where b.voter=f.user_id and not f.mafia and t.mafia)
        + 3*(select count(*) from public.match_awards a
              where a.room_id=p_room and a.award='lifesaver' and a.user_id=f.user_id)
        + 2*(select count(*) from fun_ballots b
              join fun_day_out o on o.day=b.day and o.target=b.target
              join fun_players t on t.user_id=o.target and not t.mafia
             where b.voter=f.user_id and f.mafia)
        + case when f.alive then 2 else 0 end as score
        from fun_players f where f.winner) x
     order by x.score desc, x.seat limit 1;

  insert into public.match_awards_computed(room_id) values(p_room);
  return true;
end $$;

-- Computes at the public end, on either completion path. Contained: an award
-- failure must never fail the phase change that ends a match; the read
-- computes again.
create or replace function public.fun_on_public_end()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_room uuid;
begin
  if public.fun_on('awards') then
    begin
      if tg_table_name='rooms' then
        v_room := (to_jsonb(new)->>'id')::uuid;
      else
        v_room := (to_jsonb(new)->>'room_id')::uuid;
      end if;
      perform public.compute_match_awards(v_room);
    exception when others then
      raise warning 'fun_on_public_end: %', sqlerrm;
    end;
  end if;
  return new;
end $$;
create trigger room_state_fun_awards after update of phase on public.room_state
  for each row when (new.phase='result' and old.phase is distinct from 'result')
  execute function public.fun_on_public_end();
create trigger rooms_fun_awards after update of status on public.rooms
  for each row when (new.status='finished' and old.status is distinct from 'finished')
  execute function public.fun_on_public_end();

-- 3. Founder badge ------------------------------------------------------------------
create table public.player_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge text not null check (badge in ('founder')),
  granted_at timestamptz not null default now(),
  primary key (user_id, badge)
);
alter table public.player_badges enable row level security;
revoke all on public.player_badges from public, anon, authenticated;
grant all on public.player_badges to service_role;

-- Grants the Founder badge when the caller completed a match inside the
-- window. Reached only through 1.0.1 actions, so only 1.0.1 players earn it.
create or replace function public.fun_grant_founder(p_user uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config;
begin
  if not public.fun_on('founder') then return false; end if;
  select * into cfg from public.economy_config;
  if exists(select 1 from public.player_badges where user_id=p_user and badge='founder') then
    return true;
  end if;
  if not exists(select 1 from public.rooms r join public.room_players p on p.room_id=r.id
      join public.room_state s on s.room_id=r.id
     where p.user_id=p_user and not p.kicked and p.role is not null
       and r.status='finished' and s.public_data->>'outcome' in ('mafia','town')
       and r.ended_at >= cfg.founder_window_start
       and r.ended_at < cfg.founder_window_start + make_interval(days => cfg.founder_window_days)) then
    return false;
  end if;
  insert into public.player_badges(user_id,badge) values(p_user,'founder') on conflict do nothing;
  return true;
end $$;

create or replace function public.fun_profile(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; badges jsonb;
begin
  perform public.fun_grant_founder(p_user);
  select * into cfg from public.economy_config;
  select coalesce(jsonb_agg(badge order by badge),'[]') into badges
    from public.player_badges where user_id=p_user;
  return jsonb_build_object('badges',badges,
    'founder',jsonb_build_object('enabled',public.fun_on('founder'),
      'windowEnds',case when public.fun_on('founder')
        then cfg.founder_window_start + make_interval(days => cfg.founder_window_days) end));
end $$;

-- The caller's view of a room's awards. Never errors for a live room: it
-- answers ready:false with nothing in it. Credits the caller's own award
-- coins once per room (idempotent ledger key).
create or replace function public.match_awards_get(p_user uuid, p_room uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; awards jsonb; mine jsonb; granted bigint := 0;
  amount bigint;
begin
  if not public.fun_on('awards') then return jsonb_build_object('enabled',false); end if;
  if not exists(select 1 from public.room_players where room_id=p_room and user_id=p_user
      and not kicked) then
    return jsonb_build_object('enabled',true,'ready',false,'awards','[]'::jsonb);
  end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  if not public.compute_match_awards(p_room) then
    return jsonb_build_object('enabled',true,'ready',false,'awards','[]'::jsonb);
  end if;
  select * into cfg from public.economy_config;
  -- One ledger row per player and room (the ledger allows one per kind and
  -- room), carrying the sum of that player's awards.
  select coalesce(sum(case when award='mvp' then cfg.award_mvp_coins else cfg.award_coins end),0)
    into amount from public.match_awards where room_id=p_room and user_id=p_user;
  if amount > 0 and public.credit_earned(p_user,'match_award',amount,p_room,
      'awards:'||p_room::text) then
    granted := amount;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('code',x.award,'seats',x.seats,'names',x.names,
      'coins',case when x.award='mvp' then cfg.award_mvp_coins else cfg.award_coins end)
      order by x.ord),'[]')
    into awards from (
      select m.award, array_position(array['mvp','sharp_eye','silver_tongue','first_blood',
          'lifesaver','perfect_crime','survivor'], m.award) ord,
        jsonb_agg(m.seat order by m.seat) seats,
        jsonb_agg(left(btrim(p.name),40) order by m.seat) names
        from public.match_awards m join public.room_players p
          on p.room_id=m.room_id and p.user_id=m.user_id
       where m.room_id=p_room group by m.award) x;
  select coalesce(jsonb_agg(award order by award),'[]') into mine
    from public.match_awards where room_id=p_room and user_id=p_user;
  return jsonb_build_object('enabled',true,'ready',true,'awards',awards,'mine',mine,
    'granted',granted,
    'balance',(select balance from public.wallet_accounts where user_id=p_user),
    'founder',public.fun_grant_founder(p_user));
end $$;

-- 4. Reactions ----------------------------------------------------------------------
-- Eight quick reactions, in the lobby and on the result only. The server is
-- the gate: a reaction during any match phase is refused, not hidden.
create table public.room_reactions (
  id bigserial primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null,
  seat int not null,
  kind text not null check (kind in ('laugh','shock','suspicious','applause','rose',
    'skull','coffee','crown')),
  created_at timestamptz not null default now()
);
create index room_reactions_rate on public.room_reactions(room_id, user_id, created_at);
alter table public.room_reactions enable row level security;
drop policy if exists room_reactions_member_read on public.room_reactions;
create policy room_reactions_member_read on public.room_reactions
  for select to authenticated using (private.is_room_member(room_id));
revoke all on public.room_reactions from public, anon, authenticated;
grant select (id, room_id, seat, kind, created_at) on public.room_reactions to authenticated;
grant all on public.room_reactions to service_role;
grant usage, select on sequence public.room_reactions_id_seq to service_role;

do $$
begin
  if exists (select 1 from pg_publication where pubname='supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime'
       and schemaname='public' and tablename='room_reactions') then
    execute 'alter publication supabase_realtime add table public.room_reactions';
  end if;
end $$;

-- 1 per 1.5 s on average with a burst of 3: at most 3 in any 4.5 s window.
create or replace function public.send_room_reaction(p_user uuid, p_room uuid, p_kind text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_seat int; n int;
begin
  if not public.fun_on('reactions') then raise exception 'FEATURE_OFF'; end if;
  if p_kind is null or p_kind not in ('laugh','shock','suspicious','applause','rose',
      'skull','coffee','crown') then
    raise exception 'REACTION_UNKNOWN';
  end if;
  select seat into v_seat from public.room_players
   where room_id=p_room and user_id=p_user and not kicked;
  if not found then raise exception 'NOT_MEMBER'; end if;
  if not exists(select 1 from public.rooms r join public.room_state s on s.room_id=r.id
      where r.id=p_room and ((r.status='lobby' and s.phase='lobby')
        or (r.status='finished' and s.phase='result'
            and s.public_data->>'outcome' in ('mafia','town')))) then
    raise exception 'REACTION_CLOSED';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('react:'||p_room::text||':'||p_user::text,93));
  select count(*) into n from public.room_reactions
   where room_id=p_room and user_id=p_user and created_at > now() - interval '4.5 seconds';
  if n >= 3 then raise exception 'REACTION_RATE_LIMIT'; end if;
  insert into public.room_reactions(room_id,user_id,seat,kind) values(p_room,p_user,v_seat,p_kind);
  delete from public.room_reactions where room_id=p_room and created_at < now() - interval '10 minutes';
  return jsonb_build_object('ok',true,'seat',v_seat,'kind',p_kind);
end $$;

-- Reactions keep the sender's user_id (for the rate limit only). They are
-- gone with the person's deletion, with an orphaned identity, and in any case
-- a day after they were sent (the room itself trims to ten minutes as it goes;
-- this catches the rooms nobody reacts in again).
create function public.purge_room_reactions()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n int;
begin
  delete from public.room_reactions where created_at < now() - interval '1 day';
  get diagnostics n = row_count;
  return n;
end $$;

do $$ begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.unschedule('purge-room-reactions') where exists(select 1 from cron.job where jobname='purge-room-reactions');
    perform cron.schedule('purge-room-reactions','17 * * * *',$cron$select public.purge_room_reactions();$cron$);
  end if;
end $$;

alter function public.complete_data_deletion(uuid) rename to complete_data_deletion_pre_fun;
create function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests
   where id=p_request and completed_at is null;
  perform public.complete_data_deletion_pre_fun(p_request);
  if who is not null then
    delete from public.room_reactions where user_id=who;
    delete from public.player_badges where user_id=who;
  end if;
end $$;

alter function public.purge_orphan_economy() rename to purge_orphan_economy_pre_fun;
create function public.purge_orphan_economy()
returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  delete from public.room_reactions d where not exists(select 1 from auth.users u where u.id=d.user_id);
  return public.purge_orphan_economy_pre_fun();
end $$;

-- 5. Capabilities -------------------------------------------------------------------
alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_fun;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  return public.economy_capabilities_pre_fun(p_user) || jsonb_build_object('fun',
    jsonb_build_object('awards',public.fun_on('awards'),
      'reactions',public.fun_on('reactions'),
      'founder',public.fun_on('founder')));
end $$;

-- 6. Grants -------------------------------------------------------------------------
revoke all on function public.fun_on(text) from public, anon, authenticated;
grant execute on function public.fun_on(text) to service_role;
revoke all on function public.room_at_public_end(uuid) from public, anon, authenticated;
grant execute on function public.room_at_public_end(uuid) to service_role;
revoke all on function public.compute_match_awards(uuid) from public, anon, authenticated;
grant execute on function public.compute_match_awards(uuid) to service_role;
revoke all on function public.fun_on_public_end() from public, anon, authenticated;
revoke all on function public.fun_grant_founder(uuid) from public, anon, authenticated;
grant execute on function public.fun_grant_founder(uuid) to service_role;
revoke all on function public.fun_profile(uuid) from public, anon, authenticated;
grant execute on function public.fun_profile(uuid) to service_role;
revoke all on function public.match_awards_get(uuid,uuid) from public, anon, authenticated;
grant execute on function public.match_awards_get(uuid,uuid) to service_role;
revoke all on function public.send_room_reaction(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.send_room_reaction(uuid,uuid,text) to service_role;
revoke all on function public.purge_room_reactions() from public, anon, authenticated;
grant execute on function public.purge_room_reactions() to service_role;
revoke all on function public.complete_data_deletion_pre_fun(uuid) from public, anon, authenticated;
grant execute on function public.complete_data_deletion_pre_fun(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public, anon, authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
revoke all on function public.purge_orphan_economy_pre_fun() from public, anon, authenticated;
grant execute on function public.purge_orphan_economy_pre_fun() to service_role;
revoke all on function public.purge_orphan_economy() from public, anon, authenticated;
grant execute on function public.purge_orphan_economy() to service_role;
revoke all on function public.economy_capabilities_pre_fun(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities_pre_fun(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
