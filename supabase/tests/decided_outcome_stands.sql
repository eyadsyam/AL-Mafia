-- LOCAL ONLY: node tool/test_sql_without_docker.mjs decided_outcome_stands.sql
begin;
do $$
declare
  strike_room uuid := gen_random_uuid(); strike_host uuid := gen_random_uuid();
  strike_mafia uuid := gen_random_uuid(); strike_town uuid := gen_random_uuid();
  kick_room uuid := gen_random_uuid(); kick_host uuid := gen_random_uuid();
  kick_mafia uuid := gen_random_uuid(); kick_town uuid := gen_random_uuid();
  fresh_strike uuid := gen_random_uuid(); fresh_strike_host uuid := gen_random_uuid();
  fresh_strike_mafia uuid := gen_random_uuid(); fresh_strike_town uuid := gen_random_uuid();
  fresh_kick uuid := gen_random_uuid(); fresh_kick_host uuid := gen_random_uuid();
  fresh_kick_mafia uuid := gen_random_uuid(); fresh_kick_town uuid := gen_random_uuid();
  got jsonb;
begin
  -- Each room starts with one mafia and two town seats. Removing seat 1
  -- reaches parity, which would otherwise produce a mafia win.
  insert into public.rooms(id,code,host_id,match_seed,status) values
    (strike_room,'DECSA2',strike_host,1,'playing'),
    (kick_room,'DECKA2',kick_host,1,'playing'),
    (fresh_strike,'DECSB2',fresh_strike_host,1,'playing'),
    (fresh_kick,'DECKB2',fresh_kick_host,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,connected,last_seen) values
    (strike_room,strike_host,'host',0,'mafia',true,true,now()),
    (strike_room,strike_town,'target',1,'citizen',true,true,now()-interval '5 minutes'),
    (strike_room,strike_mafia,'other',2,'citizen',true,true,now()),
    (kick_room,kick_host,'host',0,'mafia',true,true,now()),
    (kick_room,kick_town,'target',1,'citizen',true,true,now()),
    (kick_room,kick_mafia,'other',2,'citizen',true,true,now()),
    (fresh_strike,fresh_strike_host,'host',0,'mafia',true,true,now()),
    (fresh_strike,fresh_strike_town,'target',1,'citizen',true,true,now()-interval '5 minutes'),
    (fresh_strike,fresh_strike_mafia,'other',2,'citizen',true,true,now()),
    (fresh_kick,fresh_kick_host,'host',0,'mafia',true,true,now()),
    (fresh_kick,fresh_kick_town,'target',1,'citizen',true,true,now()),
    (fresh_kick,fresh_kick_mafia,'other',2,'citizen',true,true,now());
  insert into public.room_state(room_id,phase,phase_number,public_data) values
    (strike_room,'discuss',2,'{"outcome":"town"}'::jsonb),
    (kick_room,'discuss',2,'{"outcome":"town"}'::jsonb),
    (fresh_strike,'discuss',2,'{}'::jsonb),
    (fresh_kick,'discuss',2,'{}'::jsonb);

  got := public.strike_absent_member(strike_room,strike_host,1);
  assert got->>'outcome'='town', 'strike did not return the decided outcome';
  assert (select public_data->>'outcome' from public.room_state where room_id=strike_room)='town',
    'strike changed a decided outcome';
  assert not exists(select 1 from public.economy_void_rooms where room_id=strike_room),
    'strike voided an already decided match';
  assert (select not alive from public.room_players where room_id=strike_room and seat=1),
    'strike did not remove the seat';

  assert public.kick_member(kick_room,kick_host,1)=kick_town, 'kick returned the wrong player';
  assert (select public_data->>'outcome' from public.room_state where room_id=kick_room)='town',
    'kick changed a decided outcome';
  assert not exists(select 1 from public.economy_void_rooms where room_id=kick_room),
    'kick voided an already decided match';
  assert (select kicked and not alive from public.room_players where room_id=kick_room and seat=1),
    'kick did not remove the seat';

  got := public.strike_absent_member(fresh_strike,fresh_strike_host,1);
  assert got->>'outcome'='mafia', 'deciding strike did not report the mafia win';
  assert (select public_data->>'outcome' from public.room_state where room_id=fresh_strike)='mafia',
    'deciding strike did not write the outcome';
  assert exists(select 1 from public.economy_void_rooms where room_id=fresh_strike),
    'deciding strike did not void rewards';

  assert public.kick_member(fresh_kick,fresh_kick_host,1)=fresh_kick_town,
    'deciding kick returned the wrong player';
  assert (select public_data->>'outcome' from public.room_state where room_id=fresh_kick)='mafia',
    'deciding kick did not write the outcome';
  assert exists(select 1 from public.economy_void_rooms where room_id=fresh_kick),
    'deciding kick did not void rewards';
end $$;
select 'PASS decided outcome stands after strike and kick; fresh decisions still void rewards' as result;
rollback;
