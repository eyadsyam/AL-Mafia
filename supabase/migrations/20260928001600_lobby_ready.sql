-- F8: server-owned lobby readiness. All state is public pre-deal state and
-- remains inert until the operator enables the capability.

alter table public.economy_config
  add column if not exists lobby_ready_enabled boolean not null default false;

alter table public.rooms
  add column if not exists lobby_revision integer not null default 0
    check (lobby_revision >= 0);

alter table public.room_players
  add column if not exists lobby_ready boolean not null default false,
  add column if not exists ready_deadline timestamptz,
  add column if not exists ready_deadline_revision integer,
  add column if not exists ready_expired boolean not null default false;

create function public.lobby_ready_on() returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select lobby_ready_enabled from public.economy_config where id=true),false)
$$;
revoke all on function public.lobby_ready_on() from public,anon,authenticated;
grant execute on function public.lobby_ready_on() to service_role;

-- A roster mutation is a new proposition: everybody confirms again. This is
-- deliberately limited to INSERT/DELETE/kicked; readiness writes cannot loop.
create function public.bump_lobby_revision_for_roster() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid:=coalesce(new.room_id,old.room_id); room_status text;
begin
  if not public.lobby_ready_on() then return coalesce(new,old); end if;
  select status into room_status from public.rooms where id=target for update;
  if room_status='lobby' then
    update public.rooms set lobby_revision=lobby_revision+1 where id=target;
    update public.room_players set lobby_ready=false,ready_deadline=null,
      ready_deadline_revision=null,ready_expired=false where room_id=target;
  end if;
  return coalesce(new,old);
end $$;
revoke all on function public.bump_lobby_revision_for_roster() from public,anon,authenticated;
grant execute on function public.bump_lobby_revision_for_roster() to service_role;

drop trigger if exists room_players_lobby_revision_insert_delete on public.room_players;
create trigger room_players_lobby_revision_insert_delete
after insert or delete on public.room_players for each row
execute function public.bump_lobby_revision_for_roster();
drop trigger if exists room_players_lobby_revision_kick on public.room_players;
create trigger room_players_lobby_revision_kick
after update of kicked on public.room_players for each row
when (old.kicked is distinct from new.kicked)
execute function public.bump_lobby_revision_for_roster();

-- Rules, preset and series live in settings. Presentation/narrator packs and
-- the room title are cosmetics and therefore do not invalidate readiness.
create function public.bump_lobby_revision_for_room() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not public.lobby_ready_on() then return new; end if;
  if old.status='lobby' and (
       old.visibility is distinct from new.visibility or
       (coalesce(old.settings,'{}') - array['presentationPack','narratorPack'])
         is distinct from
       (coalesce(new.settings,'{}') - array['presentationPack','narratorPack'])
     ) then
    new.lobby_revision:=old.lobby_revision+1;
    update public.room_players set lobby_ready=false,ready_deadline=null,
      ready_deadline_revision=null,ready_expired=false where room_id=old.id;
  end if;
  return new;
end $$;
revoke all on function public.bump_lobby_revision_for_room() from public,anon,authenticated;
grant execute on function public.bump_lobby_revision_for_room() to service_role;

drop trigger if exists rooms_lobby_revision on public.rooms;
create trigger rooms_lobby_revision before update of settings,visibility on public.rooms
for each row execute function public.bump_lobby_revision_for_room();

-- A seat outside connected state cannot advertise itself as ready. Its one
-- deadline for this revision is retained so reconnecting cannot reset it.
create function public.clear_away_lobby_ready() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if new.status<>'connected' or not new.connected then new.lobby_ready:=false; end if;
  return new;
end $$;
revoke all on function public.clear_away_lobby_ready() from public,anon,authenticated;
grant execute on function public.clear_away_lobby_ready() to service_role;

drop trigger if exists room_players_away_clears_lobby_ready on public.room_players;
create trigger room_players_away_clears_lobby_ready
before insert or update of status,connected,lobby_ready on public.room_players
for each row execute function public.clear_away_lobby_ready();

create function public.set_lobby_ready(
  p_room uuid,p_user uuid,p_ready boolean,p_revision integer
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; p public.room_players%rowtype; ready_count integer;
begin
  if not public.lobby_ready_on() then raise exception 'FEATURE_OFF'; end if;
  select * into r from public.rooms where id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if p_revision is distinct from r.lobby_revision then raise exception 'STALE_REVISION'; end if;
  if r.status<>'lobby' then raise exception 'PHASE_CLOSED'; end if;
  select * into p from public.room_players
    where room_id=p_room and user_id=p_user and not kicked for update;
  if not found then raise exception 'NOT_A_MEMBER'; end if;
  if p.status<>'connected' or not p.connected then raise exception 'BAD_REQUEST'; end if;

  update public.room_players set lobby_ready=coalesce(p_ready,false),
    ready_expired=case when coalesce(p_ready,false) then false else ready_expired end
    where room_id=p_room and user_id=p_user;

  select count(*) into ready_count from public.room_players
    where room_id=p_room and not kicked and status='connected' and connected and lobby_ready;
  if ready_count>=5 then
    update public.room_players set ready_deadline=now()+interval '45 seconds',
      ready_deadline_revision=r.lobby_revision,ready_expired=false
      where room_id=p_room and not kicked and status='connected' and connected
        and not lobby_ready and ready_deadline_revision is distinct from r.lobby_revision;
  end if;
  return jsonb_build_object('ready',coalesce(p_ready,false),'revision',r.lobby_revision);
end $$;
revoke all on function public.set_lobby_ready(uuid,uuid,boolean,integer) from public,anon,authenticated;
grant execute on function public.set_lobby_ready(uuid,uuid,boolean,integer) to service_role;

-- The lock held by apply_match_deal serializes this check with joins/leaves.
create or replace function public.apply_match_deal(
  p_room_id uuid,p_host_id uuid,p_roles text[],p_settings jsonb,p_phase_ends_at timestamptz
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare player_count integer; dealt_count integer; connected_count integer;
begin
  if p_roles is null or array_length(p_roles,1) is null or exists(
    select 1 from unnest(p_roles) dealt(role_name)
      where role_name not in ('mafia','doctor','detective','citizen')) then return false; end if;
  perform 1 from public.rooms where id=p_room_id and host_id=p_host_id and status='lobby' for update;
  if not found then return false; end if;

  select count(*)::integer into player_count from public.room_players
    where room_id=p_room_id and not kicked;
  if public.lobby_ready_on() then
    select count(*)::integer into connected_count from public.room_players
      where room_id=p_room_id and not kicked and status='connected' and connected;
    if connected_count<5 or exists(select 1 from public.room_players
      where room_id=p_room_id and not kicked and status='connected' and connected and not lobby_ready)
    then raise exception 'NOT_READY'; end if;
  end if;
  if player_count<>array_length(p_roles,1) then return false; end if;

  with ordered as (
    select user_id,row_number() over(order by seat)::integer position
      from public.room_players where room_id=p_room_id and not kicked)
  update public.room_players player set role=p_roles[ordered.position],saw_role=false
    from ordered where player.room_id=p_room_id and player.user_id=ordered.user_id;
  get diagnostics dealt_count=row_count;
  if dealt_count<>player_count then raise exception 'incomplete role deal'; end if;
  update public.room_players set alive=false where room_id=p_room_id and kicked;
  update public.rooms set status='playing',settings=coalesce(p_settings,'{}'::jsonb)||settings
    where id=p_room_id;
  update public.room_state set phase='reveal',phase_number=1,phase_ends_at=p_phase_ends_at,
    public_data=jsonb_build_object('playerCount',player_count,'rosterSeats',
      (select jsonb_agg(seat order by seat) from public.room_players
        where room_id=p_room_id and not kicked)) where room_id=p_room_id;
  if not found then raise exception 'room state missing'; end if;
  return true;
end $$;
revoke all on function public.apply_match_deal(uuid,uuid,text[],jsonb,timestamptz) from public,anon,authenticated;
grant execute on function public.apply_match_deal(uuid,uuid,text[],jsonb,timestamptz) to service_role;

create function public.expire_lobby_ready() returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare due record; changed integer:=0;
begin
  if not public.lobby_ready_on() then return 0; end if;
  for due in select p.room_id,p.user_id,r.visibility from public.room_players p
    join public.rooms r on r.id=p.room_id
    where r.status='lobby' and p.status='connected' and p.connected and not p.kicked
      and not p.lobby_ready and not p.ready_expired and p.ready_deadline<=now()
    order by p.ready_deadline,p.seat
  loop
    if due.visibility='public' then
      perform public.leave_room(due.room_id,due.user_id);
    else
      update public.room_players set ready_expired=true
        where room_id=due.room_id and user_id=due.user_id and not lobby_ready;
    end if;
    changed:=changed+1;
  end loop;
  return changed;
end $$;
revoke all on function public.expire_lobby_ready() from public,anon,authenticated;
grant execute on function public.expire_lobby_ready() to service_role;

do $$ begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.unschedule('expire-lobby-ready') where exists(select 1 from cron.job where jobname='expire-lobby-ready');
    perform cron.schedule('expire-lobby-ready','5 seconds',$cron$select public.expire_lobby_ready();$cron$);
  end if;
end $$;

-- These are public pre-deal facts. Keep both views, column grants and the
-- Realtime publication explicit so a future column cannot ride along.
drop view if exists public.room_players_public;
create view public.room_players_public with (security_invoker=true) as
select room_id,user_id,name,seat,alive,connected,last_seen,gender,saw_role,status,
  muted,kicked,cosmetics,lobby_ready,ready_deadline,ready_deadline_revision,ready_expired
from public.room_players;
grant select (lobby_ready,ready_deadline,ready_deadline_revision,ready_expired)
  on public.room_players to authenticated;
grant select on public.room_players_public to authenticated;

drop view if exists public.rooms_public;
create view public.rooms_public with (security_invoker=true) as
select id,code,host_id,status,settings,visibility,title,created_at,ended_at,lobby_revision
from public.rooms;
grant select (lobby_revision) on public.rooms to authenticated;
grant select on public.rooms_public to authenticated;

alter publication supabase_realtime drop table public.room_players;
alter publication supabase_realtime add table public.room_players
  (room_id,user_id,name,seat,alive,connected,last_seen,gender,saw_role,status,muted,kicked,
   cosmetics,lobby_ready,ready_deadline,ready_deadline_revision,ready_expired);
alter publication supabase_realtime drop table public.rooms;
alter publication supabase_realtime add table public.rooms
  (id,code,host_id,status,settings,created_at,ended_at,visibility,title,lobby_revision);

-- Last wrapper wins: 001500 is Thursday Night in this launch row.
alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_lobby_ready;
create function public.economy_capabilities(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.economy_capabilities_pre_lobby_ready(p_user);
  return base||jsonb_build_object('lobbyReady',public.lobby_ready_on());
end $$;
revoke all on function public.economy_capabilities_pre_lobby_ready(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_lobby_ready(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
