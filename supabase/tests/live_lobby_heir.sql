begin;
do $$
declare r uuid:=gen_random_uuid(); h uuid:=gen_random_uuid(); stale uuid:=gen_random_uuid(); live uuid:=gen_random_uuid();
begin
  insert into public.rooms(id,code,host_id,match_seed,status)
    values(r,'LLHAAA',h,1,'lobby');
  insert into public.room_players(room_id,user_id,name,seat,status,connected,last_seen)
    values(r,h,'host',0,'connected',true,now()),
          (r,stale,'stale',1,'connected',true,now()-interval '31 seconds'),
          (r,live,'live',2,'connected',true,now());

  -- A guest leaving changes the seats and nothing else.
  assert public.leave_room(r,stale)='left';
  assert (select host_id from public.rooms where id=r)=h, 'a guest leaving moved the host';
  assert (select status from public.rooms where id=r)='lobby', 'a guest leaving closed the room';

  -- The host leaving on purpose closes the room for everybody (owner, 2026-10-30).
  assert public.leave_room(r,h)='closed';
  assert (select status from public.rooms where id=r)='finished', 'the host left and the room stayed open';
  assert (select ended_at from public.rooms where id=r) is not null;
  assert (select host_id from public.rooms where id=r)=h, 'a closed room changed hands';

  -- The same in a match, with no result and no reward.
  r:=gen_random_uuid();
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'LLHAAB',h,2,'playing');
  insert into public.room_players(room_id,user_id,name,seat,status,connected,last_seen)
    values(r,h,'host',0,'connected',true,now()),(r,live,'live',1,'connected',true,now());
  insert into public.room_state(room_id,phase,phase_number,public_data) values(r,'discuss',2,'{}');
  assert public.leave_room(r,live)='disconnected', 'a guest leaving a match ends only their seat';
  assert (select status from public.rooms where id=r)='playing';
  assert public.leave_room(r,h)='closed';
  assert (select status from public.rooms where id=r)='finished';
  assert (select public_data->>'outcome' from public.room_state where room_id=r) is null,
    'closing invented a winner';
  assert not exists(select 1 from public.wallet_ledger where source_room=r), 'closing granted a reward';
end $$;
select 'PASS host leaving closes the room' as result;
rollback;
