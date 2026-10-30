-- LOCAL ONLY: node tool/test_sql_without_docker.mjs online_life_gaps.sql
begin;
do $$
declare
  r uuid := gen_random_uuid(); h uuid := gen_random_uuid(); a uuid := gen_random_uuid();
  b uuid := gen_random_uuid(); rev integer;
begin
  -- M3-6: readiness belongs to the shown revision and a connected seat.
  update public.economy_config set lobby_ready_enabled=true where id=true;
  insert into public.rooms(id,code,host_id,match_seed) values(r,'LFG226',h,1);
  insert into public.room_players(room_id,user_id,name,seat) values
    (r,h,'host',0),(r,a,'guest',1);
  select lobby_revision into rev from public.rooms where id=r;
  begin
    perform public.set_lobby_ready(r,a,true,rev-1);
    raise exception 'stale ready was accepted';
  exception when raise_exception then assert sqlerrm='STALE_REVISION',sqlerrm; end;
  assert not (select lobby_ready from public.room_players where room_id=r and user_id=a),
    'stale request changed readiness';
  update public.room_players set connected=false where room_id=r and user_id=a;
  begin
    perform public.set_lobby_ready(r,a,true,rev);
    raise exception 'disconnected ready was accepted';
  exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  assert not (select lobby_ready from public.room_players where room_id=r and user_id=a),
    'disconnected seat became ready';

  -- M3-13: a guest leaving a lobby compacts the seats; the host stays.
  insert into public.rooms(id,code,host_id,match_seed) values(gen_random_uuid(),'LFG237',a,2)
    returning id into r;
  insert into public.room_players(room_id,user_id,name,seat) values
    (r,h,'guest',0),(r,a,'host',1),(r,b,'second',2);
  assert public.leave_room(r,h)='left', 'lobby departure was refused';
  assert (select host_id from public.rooms where id=r)=a, 'a guest leaving moved the host';
  assert (select seat from public.room_players where room_id=r and user_id=a)=0,
    'first remaining seat was not compacted';
  assert (select seat from public.room_players where room_id=r and user_id=b)=1,
    'second remaining seat was not compacted';

  -- M3-44/M3-54: an idle playing room closes with no invented result or reward.
  -- (Hosted by someone else: the host leaving closes it at once, see live_lobby_heir.)
  insert into public.rooms(id,code,host_id,match_seed,status) values
    (gen_random_uuid(),'LFG248',a,3,'playing') returning id into r;
  insert into public.room_players(room_id,user_id,name,seat,connected,status,last_seen) values
    (r,h,'host',0,true,'connected',now());
  insert into public.room_state(room_id,phase,phase_number,public_data) values
    (r,'discuss',2,'{}');
  assert public.leave_room(r,h)='disconnected', 'last player could not leave';
  assert (select status from public.room_players where room_id=r and user_id=h)='left',
    'last player remained connected';
  assert public.archive_abandoned_rooms()>=1, 'idle room was not archived';
  assert (select status from public.rooms where id=r)='finished', 'idle room stayed open';
  assert (select ended_at from public.rooms where id=r) is not null, 'archive omitted end time';
  assert (select public_data->>'outcome' from public.room_state where room_id=r) is null,
    'archive invented a winner';
  assert not exists(select 1 from public.wallet_ledger where source_room=r),
    'archive granted a reward';
  assert not exists(select 1 from public.match_receipts where room_id=r),
    'archive issued a reward receipt';
end $$;
rollback;
