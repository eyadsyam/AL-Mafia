begin;
do $$
declare
  u uuid := gen_random_uuid(); v uuid := gen_random_uuid(); w uuid := gen_random_uuid();
  a jsonb; b jsonb; c jsonb; ra uuid; rb uuid; rc uuid;
begin
  -- u hosts room A with v; v then creates room B: v's lobby seat in A is freed
  -- and A's roster closes up behind it.
  a := public.create_room_atomic('SEATA7',u,'U','male',1,'{"settings":{"maxPlayers":5}}');
  ra := (a->>'roomId')::uuid;
  perform public.join_room_atomic('SEATA7',v,'V','female');
  perform public.join_room_atomic('SEATA7',w,'W','male');
  if (select count(*) from public.room_players where room_id=ra)<>3 then raise exception 'lobby of three expected'; end if;
  b := public.create_room_atomic('SEATB8',v,'V','female',2,'{}');
  rb := (b->>'roomId')::uuid;
  if (b->>'vacated')::integer<>1 then raise exception 'create did not report the vacated seat: %', b; end if;
  if exists(select 1 from public.room_players where room_id=ra and user_id=v) then
    raise exception 'v still seated in A after creating B';
  end if;
  if (select seat from public.room_players where room_id=ra and user_id=w)<>1 then
    raise exception 'A did not close the gap behind v';
  end if;
  if (select host_id from public.rooms where id=ra)<>u then raise exception 'A lost its host'; end if;

  -- w joins B: leaves A. u is now alone in A's lobby.
  c := public.join_room_atomic('SEATB8',w,'W','male');
  if (c->>'vacated')::integer<>1 then raise exception 'join did not vacate A: %', c; end if;
  if (select count(*) from public.room_players where room_id=ra)<>1 then raise exception 'w still in A'; end if;

  -- rejoining the room you are already in keeps the seat and vacates nothing
  c := public.join_room_atomic('SEATB8',w,'W','male');
  if (c->>'rejoined')<>'true' or (c->>'seat')::integer<>1 or (c->>'vacated')::integer<>0 then
    raise exception 'rejoin changed the seat: %', c;
  end if;

  -- a playing room: the host u starts A alone? no — bring w back to A, start A,
  -- then w joins B mid-match: w is marked left in A (not deleted) and A's host
  -- passes on if it was w.
  perform public.join_room_atomic('SEATA7',w,'W','male');
  if exists(select 1 from public.room_players where room_id=rb and user_id=w) then
    raise exception 'w still seated in B after rejoining A';
  end if;
  update public.rooms set status='playing' where id=ra;
  update public.room_state set phase='night',phase_number=1 where room_id=ra;
  update public.room_players set status='connected',connected=true,last_seen=now() where room_id=ra;
  update public.rooms set host_id=w where id=ra;
  c := public.join_room_atomic('SEATB8',w,'W','male');
  if (select status from public.room_players where room_id=ra and user_id=w)<>'left' then
    raise exception 'w not marked left in the playing room';
  end if;
  if not exists(select 1 from public.room_players where room_id=ra and user_id=w) then
    raise exception 'a playing seat was deleted';
  end if;
  if (select host_id from public.rooms where id=ra)<>u then
    raise exception 'A did not hand the host on when w left for B';
  end if;
  -- and w can still come back to A's seat
  c := public.join_room_atomic('SEATA7',w,'W','male');
  if (c->>'rejoined')<>'true' then raise exception 'w could not return to A: %', c; end if;
  if (select status from public.room_players where room_id=ra and user_id=w)<>'connected' then
    raise exception 'return did not reconnect';
  end if;
  if exists(select 1 from public.room_players where room_id=rb and user_id=w) then
    raise exception 'w kept a seat in B while back in A';
  end if;

  -- a finished room is not a seat anybody holds
  update public.rooms set status='finished' where id=ra;
  c := public.join_room_atomic('SEATB8',w,'W','male');
  if (c->>'vacated')::integer<>0 then raise exception 'a finished room was vacated: %', c; end if;
  if (select status from public.room_players where room_id=ra and user_id=w)<>'connected' then
    raise exception 'the finished room''s row was touched';
  end if;

  if has_function_privilege('authenticated','public.vacate_other_rooms(uuid,uuid)','execute') then
    raise exception 'a client can vacate seats';
  end if;
end $$;
select 'PASS one seat per user across create, join, rejoin, playing rooms and finished rooms' as result;
rollback;
