-- Lobby bans retain notification rows but do not occupy a match seat.
create or replace function public.apply_match_deal(
  p_room_id uuid,
  p_host_id uuid,
  p_roles text[],
  p_settings jsonb,
  p_phase_ends_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  player_count integer;
  dealt_count integer;
begin
  if p_roles is null or array_length(p_roles, 1) is null or
     exists (
       select 1
       from unnest(p_roles) as dealt(role_name)
       where role_name not in ('mafia', 'doctor', 'detective', 'citizen')
     ) then
    return false;
  end if;

  -- Serialize start attempts against this room before reading its roster.
  -- The status predicate also makes retries safe after a successful start.
  perform 1 from public.rooms
  where id = p_room_id and host_id = p_host_id and status = 'lobby'
  for update;
  if not found then return false; end if;

  select count(*)::integer into player_count
  from public.room_players
  where room_id = p_room_id and not kicked;

  if player_count <> array_length(p_roles, 1) then
    return false;
  end if;

  with ordered as (
    select user_id, row_number() over (order by seat)::integer as position
    from public.room_players
    where room_id = p_room_id and not kicked
  )
  update public.room_players player
     set role = p_roles[ordered.position], saw_role = false
    from ordered
   where player.room_id = p_room_id
     and player.user_id = ordered.user_id;

  get diagnostics dealt_count = row_count;
  if dealt_count <> player_count then
    raise exception 'incomplete role deal';
  end if;

  -- Retain removal notification rows, but never count them as living players.
  update public.room_players set alive=false where room_id=p_room_id and kicked;

  update public.rooms
     set status = 'playing', settings = p_settings
   where id = p_room_id;

  update public.room_state
     set phase = 'reveal',
         phase_number = 1,
         phase_ends_at = p_phase_ends_at,
         public_data = jsonb_build_object('playerCount', player_count, 'rosterSeats',
           (select jsonb_agg(seat order by seat) from public.room_players
             where room_id=p_room_id and not kicked))
   where room_id = p_room_id;
  if not found then raise exception 'room state missing'; end if;

  return true;
end;
$$;

revoke all on function public.apply_match_deal(uuid, uuid, text[], jsonb, timestamptz)
  from public, anon, authenticated;
grant execute on function public.apply_match_deal(uuid, uuid, text[], jsonb, timestamptz)
  to service_role;

comment on function public.apply_match_deal(uuid, uuid, text[], jsonb, timestamptz) is
  'Atomically writes every private role and opens the reveal phase, on a clock. Service role only.';

create or replace function public.join_room_atomic(p_code text,p_user uuid,p_name text,p_gender text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms; player public.room_players; n integer; cap integer; chosen text; suffix integer:=2; vacated integer;
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
  select count(*) into n from public.room_players where room_id=r.id and not kicked;
  cap := coalesce((r.settings->>'maxPlayers')::integer,10);
  if cap not in (5,8,10,15) then cap:=10; end if;
  if n>=cap then raise exception 'ROOM_FULL'; end if;
  vacated := public.vacate_other_rooms(p_user, r.id);
  chosen:=btrim(p_name);
  while exists(select 1 from public.room_players where room_id=r.id and name=chosen) loop
    chosen:=left(btrim(p_name),20-length(suffix::text)-1)||' '||suffix;
    suffix:=suffix+1;
  end loop;
  select coalesce(max(seat),-1)+1 into n from public.room_players where room_id=r.id;
  insert into public.room_players(room_id,user_id,name,gender,seat)
    values(r.id,p_user,chosen,p_gender,n);
  return jsonb_build_object('roomId',r.id,'seat',n,'name',chosen,'vacated',vacated);
end;
$$;

create or replace function public.commit_phase_open(
  p_room uuid, p_expected text, p_number integer, p_expected_deadline timestamptz,
  p_next text, p_next_number integer, p_deadline timestamptz, p_patch jsonb,
  p_require_all_seen boolean default false
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  if p_next <> 'result' and p_patch ? 'standings' then
    raise exception 'standings may only be published with the result';
  end if;
  perform 1 from public.rooms where id=p_room
    and (status='playing' or (p_next='result' and status='finished')) for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>p_expected or s.phase_number<>p_number or
    s.phase_ends_at is distinct from p_expected_deadline then return false; end if;
  if p_next='result' and s.public_data->>'outcome' is null then return false; end if;
  if p_require_all_seen and exists (
    select 1 from public.room_players where room_id=p_room and not kicked and not saw_role
  ) then return false; end if;
  update public.room_state set phase=p_next,phase_number=p_next_number,
    phase_ends_at=p_deadline,public_data=public_data || p_patch,
    active_speaker=null,updated_at=now() where room_id=p_room;
  if p_next='result' then
    update public.rooms set status='finished',ended_at=coalesce(ended_at,now()) where id=p_room;
  end if;
  return true;
end;
$$;
