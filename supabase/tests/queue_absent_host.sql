-- Contract for 20261119002300_queue_absent_host (review #3). Rolled back.
begin;

create function pg_temp.qa_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

-- A lobby with seats 0..n-1; seat 0 is the host. present: which seats are connected.
create function pg_temp.qa_room(p_code text, p_title text, p_auto boolean, p_age interval,
                                p_users uuid[], p_present int[], p_status text default 'lobby')
returns uuid language plpgsql as $$
declare rid uuid := gen_random_uuid(); i int;
begin
  insert into public.rooms(id,code,host_id,match_seed,status,visibility,title,settings,created_at)
    values(rid,p_code,p_users[1],7,p_status,'public',p_title,
           jsonb_build_object('autoStart',p_auto,'maxPlayers',10),now()-p_age);
  insert into public.room_state(room_id,phase) values(rid,'lobby');
  for i in 1..array_length(p_users,1) loop
    insert into public.room_players(room_id,user_id,name,seat,connected,status)
      values(rid,p_users[i],'P'||i,i-1,(i-1)=any(p_present),
             case when (i-1)=any(p_present) then 'connected' else 'away' end);
  end loop;
  return rid;
end $$;

do $$
declare
  u uuid[] := array[]::uuid[]; i int; n int;
  a uuid; b uuid; c uuid; d uuid; e uuid; f uuid;
begin
  for i in 1..36 loop u := u || pg_temp.qa_user(); end loop;

  -- a: queue room, host and seat 1 silent, seats 2..5 here, a minute old -> seat 2 hosts.
  a := pg_temp.qa_room('QAHZAA','لعب سريع',true,interval '1 minute',u[1:6],array[2,3,4,5]);
  -- b: queue room whose host is here -> untouched.
  b := pg_temp.qa_room('QAHZBB','لعب سريع',true,interval '1 minute',u[7:12],array[0,1,2,3,4,5]);
  -- c: queue room only 10 s old -> the host still has time.
  c := pg_temp.qa_room('QAHZCC','لعب سريع',true,interval '10 seconds',u[13:18],array[1,2,3,4,5]);
  -- d: a room somebody made by hand, same silent host -> untouched.
  d := pg_temp.qa_room('QAHZDD','سهرة',false,interval '1 minute',u[19:24],array[1,2,3,4,5]);
  -- e: queue room where nobody else is here either -> nobody to hand it to.
  e := pg_temp.qa_room('QAHZEE','لعب سريع',true,interval '1 minute',u[25:30],array[]::int[]);
  -- f: a queue room already playing -> never.
  f := pg_temp.qa_room('QAHZFF','لعب سريع',true,interval '1 minute',u[31:36],array[1,2,3,4,5],'playing');

  n := public.queue_hand_absent_hosts();
  assert n = 1, 'one room handed over, got ' || n;
  assert (select host_id from public.rooms where id=a) = u[3], 'lowest connected seat hosts';
  assert (select host_id from public.rooms where id=b) = u[7], 'present host kept';
  assert (select host_id from public.rooms where id=c) = u[13], 'young room kept';
  assert (select host_id from public.rooms where id=d) = u[19], 'hand-made room kept';
  assert (select host_id from public.rooms where id=e) = u[25], 'nobody to hand to';
  assert (select host_id from public.rooms where id=f) = u[31], 'playing room kept';
  -- The old host keeps his seat as an ordinary player.
  assert exists(select 1 from public.room_players where room_id=a and user_id=u[1] and seat=0 and not kicked);
  assert (select status from public.rooms where id=a) = 'lobby';

  -- Again: the new host is here, nothing moves.
  n := public.queue_hand_absent_hosts();
  assert n = 0, 'second pass moves nothing, got ' || n;
  assert (select host_id from public.rooms where id=a) = u[3];

  -- The old host, now an ordinary seat, gone past the limit: his seat goes, the room stays.
  perform public.leave_room(a, u[1]);
  assert (select status from public.rooms where id=a) = 'lobby', 'room lives on';
  assert not exists(select 1 from public.room_players where room_id=a and user_id=u[1]);

  -- The job runs both statements.
  if exists (select 1 from pg_extension where extname='pg_cron') then
    assert (select command from cron.job where jobname='match-queue-tick') like '%queue_hand_absent_hosts%';
  end if;
  raise notice 'queue_absent_host PASS';
end $$;

rollback;
