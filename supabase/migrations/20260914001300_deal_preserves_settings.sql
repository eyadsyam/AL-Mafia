-- Stored settings win under the room lock, including edits concurrent with start.
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
     set status = 'playing', settings = coalesce(p_settings,'{}'::jsonb) || settings
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

