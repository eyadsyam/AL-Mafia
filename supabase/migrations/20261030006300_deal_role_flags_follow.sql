-- A host may switch on a bought role before the table can take it; `start_match`
-- then deals without it and clears its flag for the match. The stored room
-- settings were merged over that, putting the flag back on a match that has no
-- such role. Same body as deal_all_roles, except the three flags come from the
-- deal. Every other stored setting still wins, as it did.

create or replace function public.apply_match_deal(
  p_room_id uuid,p_host_id uuid,p_roles text[],p_settings jsonb,p_phase_ends_at timestamptz
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare player_count integer; dealt_count integer; connected_count integer;
begin
  if p_roles is null or array_length(p_roles,1) is null or exists(
    select 1 from unnest(p_roles) dealt(role_name)
      where role_name not in ('mafia','silencer','doctor','detective','elder','sniper','citizen')) then return false; end if;
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
  update public.rooms set status='playing',settings=coalesce(p_settings,'{}'::jsonb)||settings||jsonb_build_object(
      'silencerEnabled','silencer'=any(p_roles),
      'elderEnabled','elder'=any(p_roles),
      'sniperEnabled','sniper'=any(p_roles))
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
