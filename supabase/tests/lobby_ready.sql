-- F8 lobby ready contract. Rolled back by the SQL harness.
begin;
do $$
declare
  host uuid:='00000000-0000-4000-8000-00000000f800';
  u1 uuid:='00000000-0000-4000-8000-00000000f801';
  u2 uuid:='00000000-0000-4000-8000-00000000f802';
  u3 uuid:='00000000-0000-4000-8000-00000000f803';
  u4 uuid:='00000000-0000-4000-8000-00000000f804';
  u5 uuid:='00000000-0000-4000-8000-00000000f805';
  off_room uuid:=gen_random_uuid(); ready_room uuid:=gen_random_uuid();
  public_room uuid:=gen_random_uuid(); private_room uuid:=gen_random_uuid();
  leave_first uuid:=gen_random_uuid(); start_first uuid:=gen_random_uuid();
  rev integer; blocked boolean; result jsonb;
  roles text[]:=array['mafia','doctor','detective','citizen','citizen'];
begin
  -- Flag off: the old unready roster starts exactly as it did before F8.
  insert into public.rooms(id,code,host_id,match_seed) values(off_room,'F8XFFA',host,1);
  insert into public.room_state(room_id,phase) values(off_room,'lobby');
  insert into public.room_players(room_id,user_id,name,seat) values
    (off_room,host,'H',0),(off_room,u1,'A',1),(off_room,u2,'B',2),
    (off_room,u3,'C',3),(off_room,u4,'D',4);
  assert (select lobby_revision from public.rooms where id=off_room)=0;
  assert public.apply_match_deal(off_room,host,roles,'{}',now()+interval '1 minute'),
    'flag off changed the old start path';

  update public.economy_config set lobby_ready_enabled=true where id=true;
  assert public.economy_capabilities(host)->'lobbyReady'='true'::jsonb;

  insert into public.rooms(id,code,host_id,match_seed) values(ready_room,'F8RDYA',host,2);
  insert into public.room_state(room_id,phase) values(ready_room,'lobby');
  insert into public.room_players(room_id,user_id,name,seat) values
    (ready_room,host,'H',0),(ready_room,u1,'A',1),(ready_room,u2,'B',2),
    (ready_room,u3,'C',3),(ready_room,u4,'D',4);
  select lobby_revision into rev from public.rooms where id=ready_room;

  result:=public.set_lobby_ready(ready_room,host,true,rev);
  assert (result->>'ready')::boolean and
    (select lobby_ready from public.room_players where room_id=ready_room and user_id=host);
  perform public.set_lobby_ready(ready_room,host,false,rev);
  assert not (select lobby_ready from public.room_players where room_id=ready_room and user_id=host);
  begin
    perform public.set_lobby_ready(ready_room,host,true,rev-1);
    raise exception 'stale revision accepted';
  exception when raise_exception then assert sqlerrm='STALE_REVISION',sqlerrm; end;

  -- Rule changes invalidate; room cosmetics and seat cosmetics do not.
  perform public.set_lobby_ready(ready_room,host,true,rev);
  update public.rooms set settings=settings||'{"presentationPack":"noir"}'::jsonb where id=ready_room;
  assert (select lobby_revision from public.rooms where id=ready_room)=rev;
  assert (select lobby_ready from public.room_players where room_id=ready_room and user_id=host),
    'presentation cosmetic cleared readiness';
  update public.room_players set cosmetics='{"frame":"brass"}' where room_id=ready_room and user_id=host;
  assert (select lobby_ready from public.room_players where room_id=ready_room and user_id=host),
    'seat cosmetic cleared readiness';
  update public.rooms set settings=settings||'{"openVoting":true}'::jsonb where id=ready_room;
  assert (select lobby_revision from public.rooms where id=ready_room)=rev+1;
  assert not exists(select 1 from public.room_players where room_id=ready_room and lobby_ready);

  -- A roster change also invalidates, and an away seat cannot remain ready.
  select lobby_revision into rev from public.rooms where id=ready_room;
  perform public.set_lobby_ready(ready_room,host,true,rev);
  insert into public.room_players(room_id,user_id,name,seat) values(ready_room,u5,'E',5);
  assert not exists(select 1 from public.room_players where room_id=ready_room and lobby_ready);
  select lobby_revision into rev from public.rooms where id=ready_room;
  perform public.set_lobby_ready(ready_room,host,true,rev);
  update public.room_players set status='away' where room_id=ready_room and user_id=host;
  assert not (select lobby_ready from public.room_players where room_id=ready_room and user_id=host);
  begin
    perform public.set_lobby_ready(ready_room,host,true,rev);
    raise exception 'away seat became ready';
  exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;

  -- Start is refused until at least five connected seats are all ready.
  update public.room_players set status='connected',connected=true where room_id=ready_room;
  update public.room_players set lobby_ready=false where room_id=ready_room;
  blocked:=false;
  begin
    perform public.apply_match_deal(ready_room,host,
      array['mafia','doctor','detective','citizen','citizen','citizen'],'{}',now()+interval '1 minute');
  exception when raise_exception then blocked:=sqlerrm='NOT_READY'; end;
  assert blocked,'unready start was accepted';
  update public.room_players set lobby_ready=true where room_id=ready_room;
  assert public.apply_match_deal(ready_room,host,
    array['mafia','doctor','detective','citizen','citizen','citizen'],'{}',now()+interval '1 minute');

  -- Five ready seats arm the one unready seat for this revision.
  insert into public.rooms(id,code,host_id,match_seed,visibility) values
    (public_room,'F8PUBA',host,3,'public'),(private_room,'F8PRVA',host,4,'private');
  insert into public.room_state(room_id,phase) values(public_room,'lobby'),(private_room,'lobby');
  insert into public.room_players(room_id,user_id,name,seat) values
    (public_room,host,'H',0),(public_room,u1,'A',1),(public_room,u2,'B',2),
    (public_room,u3,'C',3),(public_room,u4,'D',4),(public_room,u5,'E',5),
    (private_room,host,'H',0),(private_room,u1,'A',1),(private_room,u2,'B',2),
    (private_room,u3,'C',3),(private_room,u4,'D',4),(private_room,u5,'E',5);
  update public.room_players set lobby_ready=true where room_id in(public_room,private_room) and seat<4;
  select lobby_revision into rev from public.rooms where id=public_room;
  perform public.set_lobby_ready(public_room,u4,true,rev);
  select lobby_revision into rev from public.rooms where id=private_room;
  perform public.set_lobby_ready(private_room,u4,true,rev);
  assert (select ready_deadline is not null from public.room_players where room_id=public_room and user_id=u5);
  assert (select ready_deadline is not null from public.room_players where room_id=private_room and user_id=u5);
  update public.room_players set ready_deadline=now()-interval '1 second'
    where room_id in(public_room,private_room) and user_id=u5;
  perform public.expire_lobby_ready();
  assert not exists(select 1 from public.room_players where room_id=public_room and user_id=u5),
    'public expiry did not use leave_room';
  assert exists(select 1 from public.room_players where room_id=private_room and user_id=u5 and ready_expired),
    'private expiry removed the seat instead of marking it';

  -- The room lock makes start/leave races resolve in one complete order.
  insert into public.rooms(id,code,host_id,match_seed) values
    (leave_first,'F8RACA',host,5),(start_first,'F8RACB',host,6);
  insert into public.room_state(room_id,phase) values(leave_first,'lobby'),(start_first,'lobby');
  insert into public.room_players(room_id,user_id,name,seat,lobby_ready) values
    (leave_first,host,'H',0,true),(leave_first,u1,'A',1,true),(leave_first,u2,'B',2,true),
    (leave_first,u3,'C',3,true),(leave_first,u4,'D',4,true),
    (start_first,host,'H',0,true),(start_first,u1,'A',1,true),(start_first,u2,'B',2,true),
    (start_first,u3,'C',3,true),(start_first,u4,'D',4,true);
  -- Inserts are roster changes and clear readiness; establish the final proposition.
  update public.room_players set lobby_ready=true where room_id in(leave_first,start_first);
  perform public.leave_room(leave_first,u4);
  blocked:=false;
  begin
    perform public.apply_match_deal(leave_first,host,
      array['mafia','doctor','detective','citizen'],'{}',now()+interval '1 minute');
  exception when raise_exception then blocked:=sqlerrm='NOT_READY'; end;
  assert blocked,'leave-first race started an incomplete table';
  assert public.apply_match_deal(start_first,host,roles,'{}',now()+interval '1 minute');
  assert public.leave_room(start_first,u4)='disconnected';
  assert (select status from public.rooms where id=start_first)='playing';

  -- Every definer function is service-only, including trigger helpers.
  assert not has_function_privilege('public','public.set_lobby_ready(uuid,uuid,boolean,integer)','execute');
  assert not has_function_privilege('anon','public.expire_lobby_ready()','execute');
  assert not has_function_privilege('authenticated','public.lobby_ready_on()','execute');
  assert not has_function_privilege('authenticated','public.bump_lobby_revision_for_roster()','execute');
  assert not has_function_privilege('authenticated','public.bump_lobby_revision_for_room()','execute');
  assert not has_function_privilege('authenticated','public.clear_away_lobby_ready()','execute');
  assert has_function_privilege('service_role','public.set_lobby_ready(uuid,uuid,boolean,integer)','execute');
  assert has_function_privilege('service_role','public.expire_lobby_ready()','execute');
end $$;
rollback;
