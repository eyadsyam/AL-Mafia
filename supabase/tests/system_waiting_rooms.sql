-- Contract for 20260924000200_system_waiting_rooms. Runs inside a rolled-back
-- transaction against a database with every migration applied.
begin;
do $$
declare
  viewer uuid:=gen_random_uuid(); first_in uuid:=gen_random_uuid();
  second_in uuid:=gen_random_uuid(); host uuid:=gen_random_uuid();
  waiting public.rooms; joined jsonb; listing record; rooms_before int;
begin
  insert into auth.users(id) values(viewer),(first_in),(second_in),(host);
  delete from public.rooms where visibility='public' and status='lobby';

  -- Nothing joinable: exactly one waiting room, however often it is asked.
  assert public.ensure_system_waiting_room(viewer,'default'), 'created on demand';
  assert not public.ensure_system_waiting_room(viewer,'default'), 'no duplicate';
  assert not public.ensure_system_waiting_room(first_in,'default'), 'one per pool';
  assert (select count(*) from public.rooms where system_pool='default')=1;
  select * into waiting from public.rooms where system_pool='default';
  assert waiting.host_id is null and waiting.status='lobby' and waiting.visibility='public';
  assert exists(select 1 from public.room_state where room_id=waiting.id and phase='lobby');

  begin
    perform public.ensure_system_waiting_room(viewer,'ranked');
    assert false, 'unknown pool accepted';
  exception when others then
    assert sqlerrm='BAD_REQUEST', sqlerrm;
  end;

  -- It is listed as waiting, empty, never as occupied.
  select * into listing from public.public_room_listing_v2(viewer) where code=waiting.code;
  assert listing.waiting and listing.players=0 and listing.capacity=10;

  -- It cannot hold a player row, so it cannot count, beat or start.
  begin
    insert into public.room_players(room_id,user_id,name,gender,seat)
      values(waiting.id,viewer,'X','male',0);
    assert false, 'player inserted into an unclaimed room';
  exception when others then
    assert sqlerrm='SYSTEM_ROOM_UNCLAIMED', sqlerrm;
  end;
  assert not public.apply_match_deal(waiting.id,viewer,array['mafia','doctor','detective','citizen','citizen'],'{}'::jsonb,now());

  -- First real join claims host; the next joiner is an ordinary player.
  joined:=public.join_room_atomic(waiting.code,first_in,'First','male');
  assert (joined->>'host')::boolean, 'first join is the host';
  select * into waiting from public.rooms where id=waiting.id;
  assert waiting.host_id=first_in and waiting.system_pool is null;
  joined:=public.join_room_atomic(waiting.code,second_in,'Second','female');
  assert not (joined->>'host')::boolean, 'second join is not the host';
  assert (select host_id from public.rooms where id=waiting.id)=first_in;
  assert (select count(*) from public.room_players where room_id=waiting.id)=2;

  -- A joinable human room means no new waiting room.
  assert not public.ensure_system_waiting_room(viewer,'default'),
    'demand satisfied by an existing room with a free seat';

  -- Expiry: an idle placeholder older than two hours is replaced, not kept.
  delete from public.rooms where id=waiting.id;
  assert public.ensure_system_waiting_room(viewer,'default');
  update public.rooms set created_at=now()-interval '3 hours' where system_pool='default';
  select count(*) into rooms_before from public.rooms where system_pool='default';
  assert public.ensure_system_waiting_room(viewer,'default');
  assert (select count(*) from public.rooms where system_pool='default')=rooms_before;
  assert (select created_at from public.rooms where system_pool='default') > now()-interval '1 minute';

  -- Paused operations create nothing.
  delete from public.rooms where system_pool='default';
  update public.operations_control set new_rooms_enabled=false where singleton;
  assert not public.ensure_system_waiting_room(viewer,'default');
  update public.operations_control set new_rooms_enabled=true where singleton;

  -- Shape is enforced by the table, not only by the functions.
  begin
    insert into public.rooms(code,host_id,match_seed,visibility,system_pool)
      values('ZZZZZZ',host,1,'public','default');
    assert false, 'system room with a host accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.rooms(code,host_id,match_seed,visibility)
      values('ZZZZZY',null,1,'public');
    assert false, 'hostless human room accepted';
  exception when check_violation then null;
  end;

  assert not has_function_privilege('authenticated','public.ensure_system_waiting_room(uuid,text)','execute');
  assert not has_function_privilege('anon','public.public_room_listing_v2(uuid)','execute');
end $$;
rollback;
