-- F11 — Safety v11.
--
-- One compatibility rule on every surface where two people could meet, names
-- checked on every write, reports with categories, limits and retention, and
-- the owner's review queue with its actions.
--
-- The rule is a single predicate, `safety_users_compatible(a,b)`: false when
-- either has blocked the other. The join (which is also how a series' next
-- room is entered), the public list, quick match, friends and invitations
-- all ask it, and a refusal is always the same generic ROOM_UNAVAILABLE. A
-- refusal never says who, or that it was a block.
--
-- A block made during a match does not change the table: the seat stays and
-- the room is not told. The blocker stops receiving the other's whispers and
-- voice (client, already), and reactions (the read policy below).
--
-- Doc 05: nothing here reads a role, an action, a whisper or voice. Report
-- evidence is a fixed whitelist of public facts, captured at report time.

-- ── The predicate ───────────────────────────────────────────────────────────

create or replace function public.safety_users_compatible(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select p_a is null or p_b is null or p_a=p_b or not exists(
    select 1 from public.player_blocks
     where (blocker_id=p_a and blocked_id=p_b) or (blocker_id=p_b and blocked_id=p_a))
$$;
revoke all on function public.safety_users_compatible(uuid,uuid) from public,anon,authenticated;
grant execute on function public.safety_users_compatible(uuid,uuid) to service_role;

-- Every seat still at the table (not removed, not gone) is compatible with p_user.
create or replace function public.safety_room_compatible(p_room uuid, p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select not exists(
    select 1 from public.room_players p
      join public.player_blocks b
        on (b.blocker_id=p.user_id and b.blocked_id=p_user)
        or (b.blocker_id=p_user and b.blocked_id=p.user_id)
     where p.room_id=p_room and p.user_id<>p_user and not p.kicked
       and p.status is distinct from 'left')
$$;
revoke all on function public.safety_room_compatible(uuid,uuid) from public,anon,authenticated;
grant execute on function public.safety_room_compatible(uuid,uuid) to service_role;

-- Friends asked the same question under its own name; it is now this rule.
create or replace function public.friends_blocked(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select not public.safety_users_compatible(p_a, p_b)
$$;
revoke all on function public.friends_blocked(uuid,uuid) from public,anon,authenticated;
grant execute on function public.friends_blocked(uuid,uuid) to service_role;

-- ── A block ends what the pair had ──────────────────────────────────────────
-- Friendship and pending requests (one row per pair) and room invitations in
-- either direction. Removing the block later does not bring them back.

create or replace function public.safety_block_cleanup()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  delete from public.friend_links
   where user_lo=least(new.blocker_id,new.blocked_id)
     and user_hi=greatest(new.blocker_id,new.blocked_id);
  delete from public.room_invites
   where (from_user=new.blocker_id and to_user=new.blocked_id)
      or (from_user=new.blocked_id and to_user=new.blocker_id);
  return null;
end $$;
revoke all on function public.safety_block_cleanup() from public,anon,authenticated;
drop trigger if exists player_blocks_cleanup on public.player_blocks;
create trigger player_blocks_cleanup after insert on public.player_blocks
  for each row execute function public.safety_block_cleanup();

-- ── Reactions from someone you blocked never reach you ──────────────────────
drop policy if exists room_reactions_member_read on public.room_reactions;
create policy room_reactions_member_read on public.room_reactions
  for select to authenticated using (
    private.is_room_member(room_id)
    and not exists(select 1 from public.player_blocks b
                    where b.blocker_id=(select auth.uid()) and b.blocked_id=room_reactions.user_id));

-- ── Restrictions and notices (the owner's actions) ──────────────────────────

create table public.safety_restrictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  kind text not null check (kind in ('voice','public_rooms','online')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,                 -- null: permanent
  report_id uuid,
  created_by uuid,
  lifted_at timestamptz
);
create index safety_restrictions_user on public.safety_restrictions(user_id) where lifted_at is null;

create table public.safety_notices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  kind text not null check (kind in ('warn','restrict_voice','restrict_public','suspend')),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  seen_at timestamptz
);
create index safety_notices_user on public.safety_notices(user_id, created_at);

-- An 'online' suspension covers everything; 'public_rooms' covers the public list,
-- quick match and public rooms; 'voice' covers voice only.
create or replace function public.safety_restricted(p_user uuid, p_kind text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.safety_restrictions s
    where s.user_id=p_user and s.lifted_at is null
      and s.starts_at<=now() and (s.ends_at is null or s.ends_at>now())
      and (s.kind=p_kind or s.kind='online'))
$$;
revoke all on function public.safety_restricted(uuid,text) from public,anon,authenticated;
grant execute on function public.safety_restricted(uuid,text) to service_role;

-- What this account may not do right now, and the notices it has not seen.
create or replace function public.safety_my_status(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object(
    'restrictions', coalesce((select jsonb_agg(jsonb_build_object('kind',kind,'endsAt',ends_at) order by kind)
      from public.safety_restrictions s where s.user_id=p_user and s.lifted_at is null
        and s.starts_at<=now() and (s.ends_at is null or s.ends_at>now())), '[]'::jsonb),
    'notices', coalesce((select jsonb_agg(jsonb_build_object('id',id,'kind',kind,'endsAt',ends_at,
        'createdAt',created_at) order by created_at)
      from public.safety_notices n where n.user_id=p_user and n.seen_at is null), '[]'::jsonb))
$$;
revoke all on function public.safety_my_status(uuid) from public,anon,authenticated;
grant execute on function public.safety_my_status(uuid) to service_role;

create or replace function public.safety_ack_notice(p_user uuid, p_notice uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  update public.safety_notices set seen_at=now()
   where id=p_notice and user_id=p_user and seen_at is null;
  return found;
end $$;
revoke all on function public.safety_ack_notice(uuid,uuid) from public,anon,authenticated;
grant execute on function public.safety_ack_notice(uuid,uuid) to service_role;

-- ── Names and titles ────────────────────────────────────────────────────────
-- Terms are data. Both sides are normalised the same way: Arabic diacritics,
-- tatweel and invisible direction/width marks removed, أ/إ/آ/ٱ→ا, ى/ی→ي,
-- English lower-cased, spaces collapsed.

create or replace function public.safety_normalize_name(p_text text)
returns text language sql immutable set search_path=pg_catalog as $$
  select btrim(regexp_replace(lower(translate(
    regexp_replace(coalesce(p_text,''),
      '[ً-ٰٟـ​-‏‪-‮⁦-⁩﻿]', '', 'g'),
    'أإآٱىی', 'اااايي')), '\s+', ' ', 'g'))
$$;
revoke all on function public.safety_normalize_name(text) from public,anon,authenticated;
grant execute on function public.safety_normalize_name(text) to service_role;

create table public.safety_name_terms (
  id bigint generated always as identity primary key,
  locale_scope text not null default 'all' check (locale_scope in ('ar','en','all')),
  normalized_term text not null check (char_length(normalized_term) between 2 and 40
    and normalized_term=public.safety_normalize_name(normalized_term)),
  match_mode text not null check (match_mode in ('exact','word','contains')),
  applies_to text not null default 'both' check (applies_to in ('name','title','both')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (normalized_term, match_mode, applies_to)
);
alter table public.safety_name_terms enable row level security;

-- `exact`: the whole name (or the name with its spaces removed) is the term.
-- `word`: one word of the name is the term. Short words live here, because
--   as a substring they sit inside ordinary words.
-- `contains`: the term appears anywhere once spaces are removed, which also
--   catches a word typed with gaps between its letters.
create or replace function public.safety_name_allowed(p_text text, p_kind text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  with n as (select public.safety_normalize_name(p_text) as full_name),
  w as (
    select full_name, replace(full_name,' ','') as compact,
      regexp_split_to_array(full_name, '[^0-9a-zء-ي٠-٩]+') as words
      from n)
  select not exists(
    select 1 from public.safety_name_terms t, w
     where t.active and t.applies_to in (p_kind,'both')
       and case t.match_mode
             when 'exact' then w.full_name=t.normalized_term
                            or w.compact=replace(t.normalized_term,' ','')
             when 'word' then t.normalized_term=any(w.words)
             else position(replace(t.normalized_term,' ','') in w.compact)>0
           end)
$$;
revoke all on function public.safety_name_allowed(text,text) from public,anon,authenticated;
grant execute on function public.safety_name_allowed(text,text) to service_role;

-- Every write of a seat name or a room title passes through here, whichever
-- function or Edge path makes it.
create or replace function public.safety_check_player_name()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if tg_op='UPDATE' and new.name is not distinct from old.name then return new; end if;
  if not public.safety_name_allowed(new.name,'name') then raise exception 'NAME_NOT_ALLOWED'; end if;
  return new;
end $$;
revoke all on function public.safety_check_player_name() from public,anon,authenticated;
drop trigger if exists room_players_name_allowed on public.room_players;
create trigger room_players_name_allowed before insert or update of name on public.room_players
  for each row execute function public.safety_check_player_name();

create or replace function public.safety_check_room_title()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if tg_op='UPDATE' and new.title is not distinct from old.title then return new; end if;
  if coalesce(new.title,'')<>'' and not public.safety_name_allowed(new.title,'title') then
    raise exception 'NAME_NOT_ALLOWED';
  end if;
  return new;
end $$;
revoke all on function public.safety_check_room_title() from public,anon,authenticated;
drop trigger if exists rooms_title_allowed on public.rooms;
create trigger rooms_title_allowed before insert or update of title on public.rooms
  for each row execute function public.safety_check_room_title();

-- A starter list. The owner extends it with plain inserts; each term is stored
-- already normalised (the check constraint refuses one that is not).
insert into public.safety_name_terms(locale_scope,normalized_term,match_mode,applies_to) values
  -- Posing as the game or its staff.
  ('all','mafia master','exact','name'), ('all','مافيا ماستر','exact','name'),
  ('en','admin','word','name'), ('en','moderator','word','name'), ('en','support','exact','name'),
  ('en','official','word','name'), ('ar','ادمن','word','name'), ('ar','مشرف','word','name'),
  ('ar','الدعم الفني','exact','name'), ('ar','الاداره','exact','name'), ('ar','الادارة','exact','name'),
  -- Unambiguous abuse: long enough to be matched anywhere.
  ('ar','شرموط','contains','both'), ('ar','متناك','contains','both'), ('ar','منيوك','contains','both'),
  ('ar','قحبه','contains','both'), ('ar','قحبة','contains','both'), ('ar','كسمك','contains','both'),
  ('ar','كسم','word','both'), ('ar','كسختك','contains','both'), ('ar','ابن المتناكه','contains','both'),
  ('en','fuck','contains','both'), ('en','bitch','contains','both'), ('en','whore','contains','both'),
  ('en','nigger','contains','both'), ('en','faggot','contains','both'), ('en','sharmoot','contains','both'),
  ('en','sharmota','contains','both'),
  -- Short words: whole words only (as substrings they sit inside ordinary words).
  ('ar','خول','word','both'), ('ar','عرص','word','both'), ('ar','معرص','word','both'),
  ('ar','زب','word','both'), ('ar','زبي','word','both'), ('ar','طيز','word','both'),
  ('ar','كس','word','both'), ('ar','نيك','word','both'), ('ar','احا','word','both'),
  ('en','dick','word','both'), ('en','porn','word','both'), ('en','sex','word','both')
on conflict do nothing;

-- ── Every room entry asks the rule ──────────────────────────────────────────

-- create_room_atomic as of 20260921000100, plus the restriction check. A series'
-- next room is created here too (rematch_room_atomic).
create or replace function public.create_room_atomic(
  p_code text,p_host uuid,p_name text,p_gender text,p_seed bigint,p_configuration jsonb
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r uuid; vacated integer; accepting boolean;
begin
  if length(btrim(p_name)) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  select new_rooms_enabled into accepting from public.operations_control where singleton=true;
  if accepting is false then raise exception 'NEW_ROOMS_PAUSED'; end if;
  if public.safety_restricted(p_host,'online') or
     (coalesce(p_configuration->>'visibility','private')='public'
      and public.safety_restricted(p_host,'public_rooms')) then
    raise exception 'ACCOUNT_RESTRICTED';
  end if;
  perform pg_advisory_xact_lock(hashtext('room_entry:'||p_host::text));
  vacated := public.vacate_other_rooms(p_host, null);
  insert into public.rooms(code,host_id,match_seed,settings,visibility,title)
    values(p_code,p_host,p_seed,coalesce(p_configuration->'settings','{}'),
      coalesce(p_configuration->>'visibility','private'),coalesce(p_configuration->>'title',''))
    returning id into r;
  insert into public.room_players(room_id,user_id,name,gender,seat)
    values(r,p_host,btrim(p_name),p_gender,0);
  insert into public.room_state(room_id,phase) values(r,'lobby');
  return jsonb_build_object('roomId',r,'code',p_code,'seat',0,'vacated',vacated);
end $$;
revoke all on function public.create_room_atomic(text,uuid,text,text,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.create_room_atomic(text,uuid,text,text,bigint,jsonb) to service_role;

-- join_room_atomic as of 20260924000200, plus restriction and compatibility on
-- a new seat. A seat already taken keeps its place (rejoin), block or not.
create or replace function public.join_room_atomic(p_code text,p_user uuid,p_name text,p_gender text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms; player public.room_players; n integer; cap integer; chosen text; suffix integer:=2; vacated integer; claimed boolean:=false;
begin
  if length(btrim(p_name)) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtext('room_entry:'||p_user::text));
  select * into r from public.rooms where code=upper(btrim(p_code)) for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if r.status='finished' then raise exception 'ROOM_FINISHED'; end if;
  if p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])) then raise exception 'NOT_A_MEMBER'; end if;
  select * into player from public.room_players where room_id=r.id and user_id=p_user;
  if found then
    if player.kicked then raise exception 'NOT_A_MEMBER'; end if;
    vacated := public.vacate_other_rooms(p_user, r.id);
    update public.room_players set status='connected',connected=true,last_seen=now()
      where room_id=r.id and user_id=p_user;
    return jsonb_build_object('roomId',r.id,'seat',player.seat,'rejoined',true,'vacated',vacated);
  end if;
  if r.status <> 'lobby' then raise exception 'PHASE_CLOSED'; end if;
  if public.safety_restricted(p_user,'online') or
     (r.visibility='public' and public.safety_restricted(p_user,'public_rooms')) then
    raise exception 'ACCOUNT_RESTRICTED';
  end if;
  if not public.safety_room_compatible(r.id,p_user) then raise exception 'ROOM_UNAVAILABLE'; end if;
  select count(*) into n from public.room_players where room_id=r.id and not kicked;
  cap := coalesce((r.settings->>'maxPlayers')::integer,10);
  if cap not in (5,8,10,15) then cap:=10; end if;
  if n>=cap then raise exception 'ROOM_FULL'; end if;
  vacated := public.vacate_other_rooms(p_user, r.id);
  if r.system_pool is not null then
    -- First real join: this player becomes the host. The row is locked, so a
    -- concurrent joiner waits here and then joins as an ordinary player.
    update public.rooms
       set host_id=p_user, system_pool=null, created_at=now(),
           match_seed=floor(random()*2147483647)::bigint
     where id=r.id;
    claimed := true;
  end if;
  chosen:=btrim(p_name);
  while exists(select 1 from public.room_players where room_id=r.id and name=chosen) loop
    chosen:=left(btrim(p_name),20-length(suffix::text)-1)||' '||suffix;
    suffix:=suffix+1;
  end loop;
  select coalesce(max(seat),-1)+1 into n from public.room_players where room_id=r.id;
  insert into public.room_players(room_id,user_id,name,gender,seat)
    values(r.id,p_user,chosen,p_gender,n);
  return jsonb_build_object('roomId',r.id,'seat',n,'name',chosen,'vacated',vacated,'host',claimed);
end;
$$;
revoke all on function public.join_room_atomic(text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.join_room_atomic(text,uuid,text,text) to service_role;

-- The public list shows only tables this player could sit at.
create or replace function public.public_room_listing_v2(p_user uuid)
returns table (
  code text, title text, players int, capacity int, min_players int,
  voice boolean, waiting boolean
)
language sql security definer set search_path=public,pg_temp stable as $$
  with listed as (
    select r.code, r.title, r.created_at, r.system_pool is not null as waiting,
      (select count(*) from public.room_players p
        where p.room_id=r.id and not p.kicked)::int as players,
      case when r.settings->>'maxPlayers' in ('5','8','10','15')
        then (r.settings->>'maxPlayers')::int else 10 end as capacity,
      coalesce((r.settings->>'voice')::boolean,true) as voice
    from public.rooms r
    where r.visibility='public' and r.status='lobby'
      and not (p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])))
      and public.safety_room_compatible(r.id, p_user)
      and not public.safety_restricted(p_user,'public_rooms')
  )
  select code, title, players, capacity, 5, voice, waiting
  from listed
  where players > 0 or waiting
  order by (players >= capacity), waiting, greatest(5 - players, 0),
    players desc, created_at desc
  limit 50;
$$;
revoke all on function public.public_room_listing_v2(uuid) from public,anon,authenticated;
grant execute on function public.public_room_listing_v2(uuid) to service_role;

-- quick_match_atomic as of 20260921001100: never offers a table with someone
-- this player is incompatible with.
create or replace function public.quick_match_atomic(
  p_user uuid,p_name text,p_gender text
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare candidate text; result jsonb; new_code text; seed bigint; attempt integer;
begin
  if length(btrim(p_name)) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  if public.safety_restricted(p_user,'public_rooms') then raise exception 'ACCOUNT_RESTRICTED'; end if;
  perform pg_advisory_xact_lock(hashtext('quick_match:classic'));

  select r.code into candidate
  from public.rooms r
  where r.status='lobby' and r.visibility='public'
    and coalesce(r.settings->>'scenarioCode','classic')='classic'
    and (select count(*) from public.room_players p where p.room_id=r.id and not p.kicked)
      < case when coalesce((r.settings->>'maxPlayers')::integer,10) in (5,8,10,15)
        then coalesce((r.settings->>'maxPlayers')::integer,10) else 10 end
    and not (p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])))
    and public.safety_room_compatible(r.id, p_user)
  order by (select count(*) from public.room_players p where p.room_id=r.id and not p.kicked) desc,
    r.created_at,r.id
  limit 1 for update skip locked;

  if candidate is not null then
    result:=public.join_room_atomic(candidate,p_user,p_name,p_gender);
    return result||jsonb_build_object('code',candidate,'created',false);
  end if;

  for attempt in 1..8 loop
    select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
      1+floor(random()*32)::integer,1),'') into new_code
      from generate_series(1,6);
    seed:=floor(random()*2147483647)::bigint;
    begin
      result:=public.create_room_atomic(
        new_code,p_user,p_name,p_gender,seed,
        jsonb_build_object(
          'visibility','public','title','لعب سريع',
          'settings',jsonb_build_object(
            'maxPlayers',10,'voice',true,'muteAllAtNight',true,
            'speechSeconds',45,'discussionSeconds',300,
            'openVoting',false,'traceEnabled',true,
            'discussionMode','structured','confrontationEnabled',true,
            'whisperEnabled',true,'scenarioCode','classic'
          )
        )
      );
      return result||jsonb_build_object('created',true);
    exception when unique_violation then
    end;
  end loop;
  raise exception 'BAD_REQUEST';
end $$;
revoke all on function public.quick_match_atomic(uuid,text,text) from public,anon,authenticated;
grant execute on function public.quick_match_atomic(uuid,text,text) to service_role;

-- ── Reports ─────────────────────────────────────────────────────────────────

alter table public.safety_reports alter column room_id drop not null;
alter table public.safety_reports
  add column if not exists context text,
  add column if not exists evidence jsonb not null default '{}'::jsonb,
  add column if not exists request_id uuid;
-- Older rows keep their reasons; new reports use the v11 categories.
alter table public.safety_reports drop constraint if exists safety_reports_reason_check;
alter table public.safety_reports add constraint safety_reports_reason_check check (reason in (
  'abuse','inappropriate',
  'harassment','hate','sexual','threat','spam','cheating','inappropriate_name','other'));
alter table public.safety_reports drop constraint if exists safety_reports_context_valid;
alter table public.safety_reports add constraint safety_reports_context_valid
  check (context is null or context in ('lobby','match','result','friends'));
create unique index if not exists safety_reports_request
  on public.safety_reports(reporter_id, request_id) where request_id is not null;
create index if not exists safety_reports_target_time
  on public.safety_reports(reporter_id, target_id, created_at);

-- One report. The same request id replays the first answer; the same target and
-- category within 24 hours returns the report already filed. Evidence is the
-- whitelist below and nothing else: never a role, an action, a whisper or voice.
create or replace function public.safety_report(
  p_user uuid, p_context text, p_room uuid, p_seat integer, p_target uuid,
  p_category text, p_details text, p_request uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid; evidence jsonb; r public.rooms; prior uuid; receipt uuid; target_name text;
begin
  if p_user is null or p_request is null
     or p_context not in ('lobby','match','result','friends')
     or p_category not in ('harassment','hate','sexual','threat','spam','cheating','inappropriate_name','other')
     or char_length(coalesce(p_details,''))>1000 then
    raise exception 'BAD_REQUEST';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 73));

  select id into prior from public.safety_reports where reporter_id=p_user and request_id=p_request;
  if prior is not null then return jsonb_build_object('receipt',prior,'replayed',true); end if;

  if p_context='friends' then
    target := p_target;
    if target is null or target=p_user then raise exception 'BAD_REQUEST'; end if;
    select name into target_name from public.friends_tablemates(p_user,'365 days') where user_id=target;
    if target_name is null and not exists(select 1 from public.friend_links
        where user_lo=least(p_user,target) and user_hi=greatest(p_user,target)) then
      raise exception 'NOT_A_MEMBER';
    end if;
    evidence := jsonb_build_object('context','friends','targetName',coalesce(target_name,''));
  else
    if not exists(select 1 from public.room_players where room_id=p_room and user_id=p_user) then
      raise exception 'NOT_A_MEMBER';
    end if;
    select * into r from public.rooms where id=p_room;
    select user_id, name into target, target_name from public.room_players
     where room_id=p_room and seat=p_seat;
    if target is null or target=p_user then raise exception 'BAD_REQUEST'; end if;
    evidence := jsonb_build_object('context',p_context,'roomCode',r.code,'roomTitle',coalesce(r.title,''),
      'roomStatus',r.status,'targetName',target_name,'targetSeat',p_seat);
  end if;

  select id into prior from public.safety_reports
   where reporter_id=p_user and target_id=target and reason=p_category
     and created_at>now()-interval '24 hours'
   order by created_at limit 1;
  if prior is not null then return jsonb_build_object('receipt',prior,'deduplicated',true); end if;

  if (select count(*) from public.safety_reports
       where reporter_id=p_user and created_at>now()-interval '1 day')>=10
     or (select count(*) from public.safety_reports
       where reporter_id=p_user and target_id=target and created_at>now()-interval '1 day')>=2 then
    raise exception 'RATE_LIMITED';
  end if;

  insert into public.safety_reports(reporter_id,room_id,target_id,reason,details,context,evidence,request_id)
    values(p_user,case when p_context='friends' then null else p_room end,target,p_category,
      coalesce(p_details,''),p_context,evidence,p_request)
    returning id into receipt;
  return jsonb_build_object('receipt',receipt);
end $$;
revoke all on function public.safety_report(uuid,text,uuid,integer,uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function public.safety_report(uuid,text,uuid,integer,uuid,text,text,uuid) to service_role;

-- A block by account id (the friends list has no seat). Idempotent; limited
-- to 30 new blocks a day and 500 held at once.
create or replace function public.safety_block(p_user uuid, p_target uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_user is null or p_target is null or p_user=p_target then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 73));
  if exists(select 1 from public.player_blocks where blocker_id=p_user and blocked_id=p_target) then
    return true;
  end if;
  if (select count(*) from public.player_blocks
       where blocker_id=p_user and created_at>now()-interval '1 day')>=30
     or (select count(*) from public.player_blocks where blocker_id=p_user)>=500 then
    raise exception 'RATE_LIMITED';
  end if;
  insert into public.player_blocks(blocker_id,blocked_id) values(p_user,p_target);
  return true;
end $$;
revoke all on function public.safety_block(uuid,uuid) from public,anon,authenticated;
grant execute on function public.safety_block(uuid,uuid) to service_role;

-- submit_player_safety as of 20260920000200; a block now goes through the one
-- limited path above.
create or replace function public.submit_player_safety(p_user uuid, p_action text,
  p_room uuid default null, p_seat integer default null,
  p_reason text default 'other', p_details text default '')
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid; receipt uuid;
begin
  if p_user is null then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 73));
  if p_action = 'delete' then
    insert into public.data_deletion_requests(user_id) values(p_user)
      on conflict(user_id) do update set user_id=excluded.user_id
      returning id into receipt;
    return receipt;
  end if;
  if not exists(select 1 from public.room_players where room_id=p_room and user_id=p_user) then
    raise exception 'NOT_A_MEMBER';
  end if;
  if p_seat is not null then
    select user_id into target from public.room_players where room_id=p_room and seat=p_seat;
    if target is null or target=p_user then raise exception 'BAD_REQUEST'; end if;
  end if;
  if p_action = 'block' then
    if target is null then raise exception 'BAD_REQUEST'; end if;
    perform public.safety_block(p_user, target);
    return target;
  elsif p_action = 'report' then
    if p_reason not in ('abuse','harassment','inappropriate','other') or
      char_length(coalesce(p_details,'')) > 1000 then raise exception 'BAD_REQUEST'; end if;
    if (select count(*) from public.safety_reports where reporter_id=p_user and created_at>now()-interval '1 day') >= 10 then
      raise exception 'RATE_LIMITED';
    end if;
    insert into public.safety_reports(reporter_id,room_id,target_id,reason,details)
      values(p_user,p_room,target,p_reason,coalesce(p_details,'')) returning id into receipt;
    return receipt;
  end if;
  raise exception 'BAD_REQUEST';
end $$;
revoke all on function public.submit_player_safety(uuid,text,uuid,integer,text,text) from public,anon,authenticated;
grant execute on function public.submit_player_safety(uuid,text,uuid,integer,text,text) to service_role;

-- ── The owner's queue ───────────────────────────────────────────────────────

create or replace function public.is_safety_admin(p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select public.is_commerce_admin(p_user)
$$;
revoke all on function public.is_safety_admin(uuid) from public,anon,authenticated;
grant execute on function public.is_safety_admin(uuid) to service_role;

create table public.safety_admin_receipts (
  admin_id uuid not null,
  request_id uuid not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (admin_id, request_id)
);
create table public.safety_audit (
  id bigint generated always as identity primary key,
  report_id uuid,
  admin_id uuid not null,
  action text not null,
  duration_days integer,
  note text not null default '' check (char_length(note)<=1000),
  created_at timestamptz not null default now()
);
create table public.safety_audit_monthly (
  month date not null,
  action text not null,
  total integer not null,
  primary key (month, action)
);
alter table public.safety_restrictions enable row level security;
alter table public.safety_notices enable row level security;
alter table public.safety_admin_receipts enable row level security;
alter table public.safety_audit enable row level security;
alter table public.safety_audit_monthly enable row level security;
revoke all on public.safety_restrictions, public.safety_notices, public.safety_name_terms,
  public.safety_admin_receipts, public.safety_audit, public.safety_audit_monthly
  from public, anon, authenticated;
grant all on public.safety_restrictions, public.safety_notices, public.safety_name_terms,
  public.safety_admin_receipts, public.safety_audit, public.safety_audit_monthly to service_role;

-- A page of reports, newest first. `status` is open (pending or reviewing),
-- actioned, dismissed, or null for all; the cursor is the last row's
-- "created_at|id".
create or replace function public.admin_safety_list(
  p_admin uuid, p_status text, p_category text, p_cursor text, p_limit integer default 25
) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare c_at timestamptz; c_id uuid; items jsonb; lim integer := least(greatest(coalesce(p_limit,25),1),100);
begin
  if not public.is_safety_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_status is not null and p_status not in ('open','actioned','dismissed') then raise exception 'BAD_REQUEST'; end if;
  if p_cursor is not null then
    begin
      c_at := split_part(p_cursor,'|',1)::timestamptz;
      c_id := split_part(p_cursor,'|',2)::uuid;
    exception when others then raise exception 'BAD_REQUEST';
    end;
  end if;
  with page as (
    select s.* from public.safety_reports s
     where (p_status is null
            or (p_status='open' and s.status in ('pending','reviewing'))
            or s.status=p_status)
       and (p_category is null or s.reason=p_category)
       and (c_at is null or (s.created_at, s.id) < (c_at, c_id))
     order by s.created_at desc, s.id desc
     limit lim
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',p.id,'category',p.reason,'context',p.context,'status',p.status,
      'createdAt',p.created_at,'details',p.details,'evidence',p.evidence,
      'targetId',p.target_id,'note',p.resolution_note,
      'targetOpenReports',(select count(*) from public.safety_reports o
        where o.target_id=p.target_id and o.status in ('pending','reviewing')),
      'targetActioned',(select count(*) from public.safety_reports o
        where o.target_id=p.target_id and o.status='actioned'),
      'targetRestrictions',(select coalesce(jsonb_agg(x.kind order by x.kind),'[]'::jsonb)
        from public.safety_restrictions x where x.user_id=p.target_id and x.lifted_at is null
         and (x.ends_at is null or x.ends_at>now())))
    order by p.created_at desc, p.id desc), '[]'::jsonb)
    into items from page p;
  return jsonb_build_object('items',items,'next',
    case when jsonb_array_length(items)=lim
      then (items->(lim-1)->>'createdAt')||'|'||(items->(lim-1)->>'id') end);
end $$;
revoke all on function public.admin_safety_list(uuid,text,text,text,integer) from public,anon,authenticated;
grant execute on function public.admin_safety_list(uuid,text,text,text,integer) to service_role;

-- One decision on one open report. Replayed by request id.
-- dismiss | warn | restrict_voice | restrict_public | suspend;
-- durationDays 1, 7 or 30, or null for permanent (not used by dismiss/warn).
create or replace function public.admin_safety_resolve(
  p_admin uuid, p_report uuid, p_action text, p_days integer, p_note text, p_request uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.safety_reports; done jsonb; ends timestamptz; kind text; notice text;
begin
  if not public.is_safety_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_request is null or p_action not in ('dismiss','warn','restrict_voice','restrict_public','suspend')
     or (p_days is not null and p_days not in (1,7,30))
     or char_length(coalesce(p_note,''))>1000 then
    raise exception 'BAD_REQUEST';
  end if;
  select result into done from public.safety_admin_receipts where admin_id=p_admin and request_id=p_request;
  if done is not null then return done||jsonb_build_object('replayed',true); end if;

  select * into s from public.safety_reports where id=p_report for update;
  if s.id is null then raise exception 'BAD_REQUEST'; end if;
  if s.status not in ('pending','reviewing') then raise exception 'REPORT_CLOSED'; end if;
  if p_action<>'dismiss' and s.target_id is null then raise exception 'BAD_REQUEST'; end if;

  ends := case when p_action in ('restrict_voice','restrict_public','suspend') and p_days is not null
    then now()+make_interval(days=>p_days) end;
  kind := case p_action when 'restrict_voice' then 'voice' when 'restrict_public' then 'public_rooms'
    when 'suspend' then 'online' end;
  notice := case when p_action='dismiss' then null else p_action end;

  if kind is not null then
    insert into public.safety_restrictions(user_id,kind,ends_at,report_id,created_by)
      values(s.target_id,kind,ends,s.id,p_admin);
  end if;
  if notice is not null then
    insert into public.safety_notices(user_id,kind,ends_at) values(s.target_id,notice,ends);
  end if;
  update public.safety_reports
     set status=case when p_action='dismiss' then 'dismissed' else 'actioned' end,
         resolution_note=coalesce(p_note,''), reviewed_at=now(), reviewed_by=p_admin::text, resolved_at=now()
   where id=s.id;
  insert into public.safety_audit(report_id,admin_id,action,duration_days,note)
    values(s.id,p_admin,p_action,p_days,coalesce(p_note,''));

  done := jsonb_build_object('reportId',s.id,'action',p_action,
    'status',case when p_action='dismiss' then 'dismissed' else 'actioned' end,'endsAt',ends);
  insert into public.safety_admin_receipts(admin_id,request_id,result) values(p_admin,p_request,done);
  return done;
end $$;
revoke all on function public.admin_safety_resolve(uuid,uuid,text,integer,text,uuid) from public,anon,authenticated;
grant execute on function public.admin_safety_resolve(uuid,uuid,text,integer,text,uuid) to service_role;

-- ── Retention ───────────────────────────────────────────────────────────────
-- Open and actioned reports 180 days, dismissed 90; completed deletion
-- requests 90; the audit trail 365 days, then only monthly counts per action.
-- The nightly job (purge-resolved-safety) and the owner's purge run the same
-- function.
drop function if exists public.purge_resolved_safety();
create function public.purge_resolved_safety()
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare reports integer; audits integer; other integer;
begin
  with gone as (
    delete from public.safety_reports
     where (status in ('pending','reviewing') and created_at < now()-interval '180 days')
        or (status='actioned' and coalesce(resolved_at,created_at) < now()-interval '180 days')
        or (status='dismissed' and coalesce(resolved_at,created_at) < now()-interval '90 days')
    returning 1)
  select count(*) into reports from gone;
  delete from public.data_deletion_requests where completed_at < now()-interval '90 days';
  insert into public.safety_audit_monthly(month,action,total)
    select date_trunc('month',created_at)::date, action, count(*)
      from public.safety_audit where created_at < now()-interval '365 days'
     group by 1,2
  on conflict (month,action) do update set total=safety_audit_monthly.total+excluded.total;
  with gone as (delete from public.safety_audit where created_at < now()-interval '365 days' returning 1)
  select count(*) into audits from gone;
  with gone as (
    delete from public.safety_restrictions
     where coalesce(lifted_at, ends_at) < now()-interval '365 days' returning 1)
  select count(*) into other from gone;
  delete from public.safety_notices where seen_at < now()-interval '180 days';
  delete from public.safety_admin_receipts where created_at < now()-interval '30 days';
  return jsonb_build_object('reports',reports,'audit',audits,'restrictions',other);
end $$;
revoke all on function public.purge_resolved_safety() from public,anon,authenticated;
grant execute on function public.purge_resolved_safety() to service_role;

create or replace function public.purge_safety_evidence(p_admin uuid, p_request uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare done jsonb;
begin
  if not public.is_safety_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_request is null then raise exception 'BAD_REQUEST'; end if;
  select result into done from public.safety_admin_receipts where admin_id=p_admin and request_id=p_request;
  if done is not null then return done||jsonb_build_object('replayed',true); end if;
  done := public.purge_resolved_safety();
  insert into public.safety_audit(admin_id,action) values(p_admin,'purge');
  insert into public.safety_admin_receipts(admin_id,request_id,result) values(p_admin,p_request,done);
  return done;
end $$;
revoke all on function public.purge_safety_evidence(uuid,uuid) from public,anon,authenticated;
grant execute on function public.purge_safety_evidence(uuid,uuid) to service_role;

-- ── The client learns only that v11 is on ───────────────────────────────────
alter table public.economy_config
  add column if not exists safety_v11_enabled boolean not null default false;

alter function public.economy_capabilities(uuid)
  rename to economy_capabilities_pre_safety_v11;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.economy_capabilities_pre_safety_v11(p_user);
  return base||jsonb_build_object('safety',jsonb_build_object('v11',
    coalesce((select safety_v11_enabled from public.economy_config limit 1),false)));
end $$;
revoke all on function public.economy_capabilities_pre_safety_v11(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_safety_v11(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
