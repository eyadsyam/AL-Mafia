-- A settings change is one statement under the room lock. `room_settings`
-- used to read the status, count the seats and then update the row by id
-- alone, so a start or a join landing between its reads and its write could
-- see a started match's rules change under it, or a capacity drop below the
-- population the door had already admitted. The population counted here is
-- the one `join_room_atomic` counts (every seat that is not kicked), so a
-- capacity this accepts is a capacity the door agrees with.
create function public.commit_room_settings(p_room uuid, p_host uuid, p_patch jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; cap integer; n integer;
begin
  select * into r from public.rooms where id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if r.host_id<>p_host then raise exception 'NOT_HOST'; end if;
  if r.status<>'lobby' then raise exception 'PHASE_CLOSED'; end if;
  if p_patch ? 'visibility' and p_patch->>'visibility' not in ('private','public') then
    raise exception 'BAD_REQUEST';
  end if;
  cap := (p_patch->'settings'->>'maxPlayers')::integer;
  if cap is not null then
    if cap not in (5,8,10,15) then raise exception 'BAD_REQUEST'; end if;
    select count(*) into n from public.room_players where room_id=p_room and not kicked;
    if cap < n then raise exception 'BAD_REQUEST'; end if;
  end if;
  update public.rooms set
    visibility = coalesce(p_patch->>'visibility', visibility),
    title = case when p_patch ? 'title' then nullif(left(btrim(coalesce(p_patch->>'title','')),40),'') else title end,
    -- Merged here, not by the caller: two hosts' taps on two different
    -- switches in the same instant both land instead of the later stale
    -- merge overwriting the earlier one.
    settings = case when p_patch ? 'settings' then coalesce(settings,'{}'::jsonb) || (p_patch->'settings') else settings end
    where id=p_room;
  return jsonb_build_object('changed', true);
end;
$$;
revoke all on function public.commit_room_settings(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.commit_room_settings(uuid,uuid,jsonb) to service_role;
