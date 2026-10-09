create table public.economy_void_rooms(
  room_id uuid primary key references public.rooms(id) on delete cascade
);
alter table public.economy_void_rooms enable row level security;
revoke all on public.economy_void_rooms from public,anon,authenticated;
grant select,insert on public.economy_void_rooms to service_role;

alter function public.kick_member(uuid,uuid,integer) rename to kick_member_pre_economy;
create function public.kick_member(p_room uuid,p_host uuid,p_seat integer)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare playing boolean; removed uuid;
begin
  select r.status='playing' and p.alive and p.role is not null into playing
    from public.rooms r join public.room_players p on p.room_id=r.id
    where r.id=p_room and p.seat=p_seat;
  removed:=public.kick_member_pre_economy(p_room,p_host,p_seat);
  if playing and exists(select 1 from public.room_state
      where room_id=p_room and public_data->>'outcome' in ('mafia','town')) then
    insert into public.economy_void_rooms(room_id) values(p_room) on conflict do nothing;
  end if;
  return removed;
end $$;

revoke all on function public.kick_member(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.kick_member(uuid,uuid,integer) to service_role;
revoke all on function public.kick_member_pre_economy(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.kick_member_pre_economy(uuid,uuid,integer) to service_role;

create function public.economy_kick_voided(p_room uuid)
returns boolean language plpgsql stable security definer set search_path=public,pg_temp as $$
declare outcome text; mafia int; town int;
begin
  if exists(select 1 from public.economy_void_rooms where room_id=p_room) then return true; end if;
  select public_data->>'outcome' into outcome from public.room_state where room_id=p_room;
  if outcome not in ('mafia','town') then return false; end if;
  select count(*) filter(where alive and public.is_mafia_team(role)),
    count(*) filter(where alive and not public.is_mafia_team(role)) into mafia,town
    from public.room_players where room_id=p_room;
  return exists(select 1 from public.room_players p where p.room_id=p_room and p.kicked
    and p.role is not null and
    ((outcome='town' and public.is_mafia_team(p.role)) or
     (outcome='mafia' and not public.is_mafia_team(p.role) and mafia<town+1)));
end $$;
revoke all on function public.economy_kick_voided(uuid) from public,anon,authenticated;
grant execute on function public.economy_kick_voided(uuid) to service_role;

alter function public.match_awards_get(uuid,uuid) rename to match_awards_get_pre_economy;
create function public.match_awards_get(p_user uuid,p_room uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if public.economy_kick_voided(p_room) then
    return jsonb_build_object('enabled',true,'ready',true,'awards','[]'::jsonb,
      'mine','[]'::jsonb,'granted',0,
      'balance',(select balance from public.wallet_accounts where user_id=p_user));
  end if;
  return public.match_awards_get_pre_economy(p_user,p_room);
end $$;
revoke all on function public.match_awards_get(uuid,uuid) from public,anon,authenticated;
grant execute on function public.match_awards_get(uuid,uuid) to service_role;
revoke all on function public.match_awards_get_pre_economy(uuid,uuid) from public,anon,authenticated;
grant execute on function public.match_awards_get_pre_economy(uuid,uuid) to service_role;

create or replace function public.economy_roster_fingerprint(p_room uuid,p_day date)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare s bytea; roster text;
begin
  select string_agg(distinct p.user_id::text,',' order by p.user_id::text) into roster
    from public.room_players p where p.room_id=p_room and not p.kicked
      and p.status is distinct from 'left' and p.role is not null
      and (exists(select 1 from public.votes v where v.room_id=p_room and v.voter_id=p.user_id
        and v.action_id is not null)
        or exists(select 1 from public.night_actions a where a.room_id=p_room and a.actor_id=p.user_id
        and a.action_id is not null));
  if roster is null then return null; end if;
  insert into public.economy_roster_salts(day,salt)
    values(p_day,decode(replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-',''),'hex'))
    on conflict(day) do nothing;
  select salt into strict s from public.economy_roster_salts where day=p_day;
  return encode(public.metric_hmac_sha256(s,convert_to(roster,'UTF8')),'hex');
end $$;

create or replace function public.economy_v3_issue_receipt(p_user uuid,p_room uuid)
returns public.match_receipts language plpgsql security definer set search_path=public,pg_temp as $$
declare rec public.match_receipts; m record; humans int; mates uuid[]; d date; fp text;
  day_used int; fp_used int; v_won boolean;
begin
  select * into rec from public.match_receipts where user_id=p_user and room_id=p_room;
  if found then return rec; end if;
  if not public.economy_v3_on() then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into rec from public.match_receipts where user_id=p_user and room_id=p_room;
  if found then return rec; end if;

  select r.started_at,r.ended_at,p.role,s.public_data->>'outcome' as outcome into m
    from public.rooms r join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
   where r.id=p_room and p.user_id=p_user and not p.kicked
     and p.status is distinct from 'left' and p.role is not null
     and r.status='finished' and r.ended_at is not null
     and s.public_data->>'outcome' in ('mafia','town');
  if not found or m.started_at is null or m.ended_at<m.started_at+interval '3 minutes'
      or public.economy_kick_voided(p_room)
      or not (exists(select 1 from public.votes where room_id=p_room and voter_id=p_user
        and action_id is not null)
        or exists(select 1 from public.night_actions where room_id=p_room and actor_id=p_user
        and action_id is not null)) then
    return null;
  end if;

  select count(distinct p.user_id)::int,
      coalesce(array_agg(distinct p.user_id) filter(where p.user_id<>p_user),'{}')
    into humans,mates from public.room_players p
    where p.room_id=p_room and not p.kicked and p.status is distinct from 'left'
      and p.role is not null
      and (exists(select 1 from public.votes v where v.room_id=p_room and v.voter_id=p.user_id
        and v.action_id is not null)
        or exists(select 1 from public.night_actions a where a.room_id=p_room and a.actor_id=p.user_id
        and a.action_id is not null));
  if humans<5 then return null; end if;

  d:=(m.ended_at at time zone 'utc')::date;
  select count(*)::int into day_used from public.match_receipts where user_id=p_user and day=d;
  if day_used>=6 then return null; end if;
  fp:=public.economy_roster_fingerprint(p_room,d);
  select count(*)::int into fp_used from public.match_receipts
   where user_id=p_user and day=d and roster_fingerprint=fp;
  if fp_used>=3 then return null; end if;

  v_won:=(public.is_mafia_team(m.role))=(m.outcome='mafia');
  insert into public.match_receipts(user_id,room_id,day,week,ended_at,won,human_count,
      roster_fingerprint,day_ordinal,roster_ordinal,co_players,completion_coins,win_coins,
      first_day_coins,season_xp,council_xp)
    values(p_user,p_room,d,public.council_week(d),m.ended_at,v_won,humans,fp,day_used+1,
      fp_used+1,mates,25,case when v_won then 10 else 0 end,case when day_used=0 then 25 else 0 end,
      5+case when v_won then 5 else 0 end,30+case when v_won then 20 else 0 end)
    returning * into rec;
  return rec;
end $$;
