-- Contract for 20261030006900_no_seat_outlives_its_player. Rolled back.
begin;

do $$
declare
  h uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); s uuid:=gen_random_uuid();
  a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid();
  r uuid:=gen_random_uuid(); n int;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'K7M2QU',h,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,connected,status,last_seen) values
    (r,h,'h',0,'citizen',true,true,'connected',now()),
    (r,m,'m',1,'mafia',true,true,'connected',now()),
    (r,s,'s',2,'silencer',true,true,'connected',now()),
    (r,a,'a',3,'citizen',true,true,'connected',now()),
    (r,b,'b',4,'citizen',true,true,'connected',now()),
    (r,c,'c',5,'citizen',true,true,'connected',now());
  insert into public.room_state(room_id,phase,phase_number,public_data) values(r,'discuss',2,'{}');

  -- A blip inside the limit costs nothing.
  update public.room_players set last_seen=now()-interval '60 seconds' where room_id=r and user_id=a;
  n:=public.age_presence();
  assert (select alive from public.room_players where room_id=r and user_id=a),'a blip struck a seat';

  -- Past the limit the seat is out, with no role said, and the match goes on.
  update public.room_players set last_seen=now()-interval '2 minutes' where room_id=r and user_id=a;
  n:=public.age_presence();
  assert (select not alive from public.room_players where room_id=r and user_id=a),'silent seat kept';
  assert (select public_data->'eliminations' ? '3' from public.room_state where room_id=r);
  assert not (select public_data::text like '%citizen%' from public.room_state where room_id=r),'a role was said';
  assert (select public_data->>'outcome' from public.room_state where room_id=r) is null;
  assert (select status from public.rooms where id=r)='playing';

  -- One Mafioso gone: the silencer is still Mafia, and the match still goes on.
  update public.room_players set last_seen=now()-interval '2 minutes' where room_id=r and user_id=m;
  n:=public.age_presence();
  assert (select public_data->>'outcome' from public.room_state where room_id=r) is null,'silencer not counted';

  -- The last of them gone: the town wins, and a removal-decided match pays nothing.
  update public.room_players set last_seen=now()-interval '2 minutes' where room_id=r and user_id=s;
  n:=public.age_presence();
  assert (select public_data->>'outcome' from public.room_state where room_id=r)='town','last Mafia left';
  assert exists(select 1 from public.economy_void_rooms where room_id=r),'decided by a removal, and rewards stand';

  -- The host silent past the limit: the room ends for everybody, in the match…
  r:=gen_random_uuid();
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'K7M2QV',h,2,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,connected,status,last_seen) values
    (r,h,'h',0,'mafia',true,true,'connected',now()-interval '2 minutes'),
    (r,a,'a',1,'citizen',true,true,'connected',now()),
    (r,b,'b',2,'citizen',true,true,'connected',now());
  insert into public.room_state(room_id,phase,phase_number,public_data) values(r,'night',1,'{}');
  n:=public.age_presence();
  assert (select status from public.rooms where id=r)='finished','the host went and the match stayed';
  assert (select host_id from public.rooms where id=r)=h,'somebody inherited';
  assert (select public_data->>'outcome' from public.room_state where room_id=r) is null,'closing invented a result';
  assert not (select public_data ? 'eliminations' from public.room_state where room_id=r),'closing said who left';

  -- …and in the lobby.
  r:=gen_random_uuid();
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'K7M2QW',h,3,'lobby');
  insert into public.room_players(room_id,user_id,name,seat,connected,status,last_seen) values
    (r,h,'h',0,true,'connected',now()-interval '2 minutes'),
    (r,a,'a',1,true,'connected',now());
  n:=public.age_presence();
  assert (select status from public.rooms where id=r)='finished','the host went and the lobby stayed';

  -- Nobody can claim a room.
  r:=gen_random_uuid();
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'K7M2QX',h,4,'lobby');
  insert into public.room_players(room_id,user_id,name,seat,connected,status,last_seen) values
    (r,h,'h',0,true,'connected',now()-interval '60 seconds'),(r,a,'a',1,true,'connected',now());
  assert public.migrate_host(r,a)=h,'a claim moved the host';
  assert (select host_id from public.rooms where id=r)=h;
end $$;

rollback;
