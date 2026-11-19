-- Contract for 20261119000800_match_queue (O1 «استناني»). Rolled back.
begin;

create function pg_temp.mq_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

create function pg_temp.mq_metric(p_prop text) returns bigint language sql as $$
  select coalesce((select sum(total) from public.product_metric_daily
                    where event='queue' and prop=p_prop),0)
$$;

do $$
declare
  u uuid[] := array[]::uuid[];
  i int;
  r jsonb; rid uuid; room uuid; room_code text;
  lobby uuid := gen_random_uuid();
  m_join bigint; m_ready_yes bigint; m_ready_no bigint; m_matched bigint; m_expired bigint;
  joined_before timestamptz; work int; quick_rooms int; seated int;
begin
  update public.economy_config set push_invites_enabled=true, friends_enabled=true;
  -- Only this test's rooms count: any other public lobby is hidden for now.
  update public.rooms set visibility='private' where visibility='public';
  update public.operations_control set new_rooms_enabled=true where singleton=true;
  delete from public.match_queue;
  for i in 1..16 loop
    u := u || pg_temp.mq_user();
    perform public.push_token_register(u[i], repeat(chr(96+i),40), 'android');
  end loop;

  -- 1. No lobby anywhere: the player waits in the queue, and joining twice changes nothing.
  m_join := pg_temp.mq_metric('join');
  r := public.queue_join(u[1],'Ana','female');
  assert (r->>'queued')::boolean and (r->>'count')::int=1, r::text;
  update public.match_queue set joined_at=now()-interval '5 minutes' where user_id=u[1];
  joined_before := now()-interval '5 minutes';
  r := public.queue_join(u[1],'Ana','female');
  assert (r->>'count')::int=1, r::text;
  assert (select joined_at from public.match_queue where user_id=u[1])=joined_before, 'joined_at is kept';
  assert pg_temp.mq_metric('join')=m_join+1, 'queue/join counted once';
  assert (public.queue_status(u[1])->>'queued')::boolean;
  assert public.queue_status(u[1])->'round' = 'null'::jsonb;
  assert public.queue_status(u[1])->'room' = 'null'::jsonb;
  assert (public.queue_status(u[1])->'me'->>'confirmed')::boolean is false;
  assert public.queue_status(u[2])->'me' = 'null'::jsonb;
  assert not (public.queue_status(u[2])->>'queued')::boolean;

  -- 2. A public lobby with one connected player: the newcomer is seated, not queued,
  --    and a player already waiting is seated by joining again.
  insert into public.rooms(id,code,host_id,match_seed,status,visibility)
    values(lobby,'QMQ2AB',u[2],5,'lobby','public');
  insert into public.room_players(room_id,user_id,name,seat,connected)
    values(lobby,u[2],'Nour',0,true);
  insert into public.room_state(room_id,phase) values(lobby,'lobby');
  r := public.queue_join(u[3],'Omar','male');
  assert r->>'queued' is null, r::text;
  assert r->>'code'='QMQ2AB' and (r->>'seat')::int=1 and (r->>'roomId')::uuid=lobby, r::text;
  assert not exists(select 1 from public.match_queue where user_id=u[3]);
  r := public.queue_join(u[1],'Ana','female');
  assert r->>'code'='QMQ2AB' and (r->>'seat')::int=2, r::text;
  assert not exists(select 1 from public.match_queue where user_id=u[1]), 'seated players leave the queue';
  -- Already seated: the seat is the answer.
  r := public.queue_join(u[3],'Omar','male');
  assert (r->>'rejoined')::boolean and r->>'code'='QMQ2AB', r::text;
  assert (public.queue_status(u[3])->'room'->>'code')='QMQ2AB';
  -- A lobby whose only player dropped is not a table to wait at.
  update public.room_players set connected=false where room_id=lobby;
  update public.rooms set visibility='private' where id=lobby;

  -- 3. Five wait: one tick opens one round and sends five «queue_ready» pushes.
  for i in 4..8 loop
    r := public.queue_join(u[i],'P'||i,'male');
    assert (r->>'queued')::boolean, r::text;
    update public.match_queue set joined_at=now()-interval '20 minutes'+(i*interval '1 minute') where user_id=u[i];
  end loop;
  assert (public.queue_status(u[4])->>'count')::int=5;
  work := public.queue_tick();
  assert work=1, work::text;
  rid := (select round_id from public.match_queue where user_id=u[4]);
  assert rid is not null;
  assert (select count(*) from public.match_queue where round_id=rid)=5, 'one round holds all five';
  assert (select count(*) from public.match_queue where round_deadline>now()+interval '55 seconds'
            and round_deadline<=now()+interval '61 seconds')=5, '60 second deadline';
  assert (select count(*) from public.push_outbox where kind='queue_ready' and status='pending' and user_id=any(u))=5;
  assert (select count(*) from public.push_outbox where kind='queue_ready' and user_id=any(u)
            and dedupe_key like 'queue_ready:'||rid||':%')=5, 'dedupe key carries the round';
  assert (public.queue_status(u[4])->'round'->>'total')::int=5
     and (public.queue_status(u[4])->'round'->>'confirmed')::int=0;
  assert public.queue_tick()=0, 'a second tick changes nothing';
  assert (select count(*) from public.push_outbox where kind='queue_ready' and user_id=any(u))=5;

  -- A wrong round is closed to the caller.
  begin
    perform public.queue_ready(u[4], gen_random_uuid(), true);
    assert false, 'wrong round accepted';
  exception when others then
    assert sqlerrm like '%ROUND_CLOSED%', sqlerrm;
  end;
  -- A player outside any round cannot answer one.
  begin
    perform public.queue_ready(u[9], rid, true);
    assert false, 'outsider accepted';
  exception when others then
    assert sqlerrm like '%ROUND_CLOSED%', sqlerrm;
  end;

  -- 4. Five say yes: the next tick makes ONE public room, host first in line, queue empty.
  m_ready_yes := pg_temp.mq_metric('ready_yes');
  m_matched := pg_temp.mq_metric('matched');
  for i in 4..8 loop
    r := public.queue_ready(u[i], rid, true);
    assert (r->>'confirmed')::boolean and (r->>'queued')::boolean, r::text;
  end loop;
  assert pg_temp.mq_metric('ready_yes')=m_ready_yes+5;
  assert (public.queue_status(u[4])->'round'->>'confirmed')::int=5;
  quick_rooms := (select count(*) from public.rooms where title='لعب سريع');
  work := public.queue_tick();
  assert work=1, work::text;
  assert (select count(*) from public.rooms where title='لعب سريع')=quick_rooms+1, 'exactly one room';
  room := (public.queue_status(u[4])->'room'->>'roomId')::uuid;
  room_code := public.queue_status(u[4])->'room'->>'code';
  assert room is not null and room_code is not null;
  assert (select visibility from public.rooms where id=room)='public';
  assert (select status from public.rooms where id=room)='lobby';
  assert (select title from public.rooms where id=room)='لعب سريع';
  assert (select settings->>'autoStart' from public.rooms where id=room)='true';
  assert (select (settings->>'discussionSeconds')::int from public.rooms where id=room)=180;
  assert (select host_id from public.rooms where id=room)=u[4], 'host is the first confirmed';
  assert (select count(*) from public.room_players where room_id=room and not kicked)=5;
  for i in 4..8 loop
    assert (select seat from public.room_players where room_id=room and user_id=u[i])=i-4, 'seats follow joined_at';
    assert public.queue_status(u[i])->'room'->>'code'=room_code;
  end loop;
  assert exists(select 1 from public.room_state where room_id=room and phase='lobby');
  assert (select status from public.rooms where id=room)<>'playing', 'the server does not start the match';
  assert (select count(*) from public.match_queue)=0, 'queue is empty';
  assert pg_temp.mq_metric('matched')=m_matched+5;
  assert public.queue_tick()=0;
  -- Those who sit in a room cannot be queued again.
  r := public.queue_join(u[5],'P5','male');
  assert r->>'code'=room_code, r::text;
  update public.rooms set visibility='private' where id=room;

  -- 5. Four say yes, one stays silent: the yes players keep their place and their
  --    joined_at, the silent one takes a miss.
  delete from public.match_queue;
  for i in 9..13 loop
    r := public.queue_join(u[i],'P'||i,'female');
    assert (r->>'queued')::boolean, r::text;
    update public.match_queue set joined_at=now()-interval '30 minutes'+(i*interval '1 minute') where user_id=u[i];
  end loop;
  assert public.queue_tick()=1;
  rid := (select round_id from public.match_queue where user_id=u[9]);
  assert rid is not null and (select count(*) from public.match_queue where round_id=rid)=5;
  for i in 9..12 loop perform public.queue_ready(u[i], rid, true); end loop;
  assert (select count(*) from public.match_queue where round_id=rid and not confirmed)=1;
  joined_before := (select joined_at from public.match_queue where user_id=u[9]);
  update public.match_queue set round_deadline=now()-interval '1 second' where round_id=rid;
  quick_rooms := (select count(*) from public.rooms where title='لعب سريع');
  work := public.queue_tick();
  assert work=1, work::text;
  assert (select count(*) from public.rooms where title='لعب سريع')=quick_rooms, 'no room with four';
  assert (select count(*) from public.match_queue)=5, 'nobody left yet';
  assert (select count(*) from public.match_queue where round_id is null and not confirmed)=5, 'round cleared';
  assert (select joined_at from public.match_queue where user_id=u[9])=joined_before, 'place kept';
  assert (select misses from public.match_queue where user_id=u[13])=1, 'silent player has a miss';
  assert (select sum(misses) from public.match_queue where user_id<>u[13])=0;
  -- The tick that closed a round does not open the next one.
  assert (select count(*) from public.push_outbox where kind='queue_ready' and user_id=any(u))=10, 'no new push in that tick';

  -- 6. The next tick asks the five again. One says no (leaves), three say yes, one is silent again:
  --    the silent player's second miss removes him.
  m_ready_no := pg_temp.mq_metric('ready_no');
  assert public.queue_tick()=1;
  rid := (select round_id from public.match_queue where user_id=u[9]);
  assert rid is not null and (select count(*) from public.match_queue where round_id=rid)=5;
  assert (select count(*) from public.push_outbox where kind='queue_ready' and user_id=any(u))=15;
  for i in 9..11 loop perform public.queue_ready(u[i], rid, true); end loop;
  r := public.queue_ready(u[12], rid, false);
  assert not (r->>'queued')::boolean, r::text;
  assert pg_temp.mq_metric('ready_no')=m_ready_no+1;
  assert not exists(select 1 from public.match_queue where user_id=u[12]), 'a no leaves the queue';
  update public.match_queue set round_deadline=now()-interval '1 second' where round_id=rid;
  assert public.queue_tick()=1;
  assert not exists(select 1 from public.match_queue where user_id=u[13]), 'second miss removes';
  assert (select count(*) from public.match_queue)=3, 'the yes players stay';
  assert (select count(*) from public.match_queue where round_id is null and misses=0)=3;
  -- A closed round cannot be answered late.
  begin
    perform public.queue_ready(u[9], rid, true);
    assert false, 'late answer accepted';
  exception when others then
    assert sqlerrm like '%ROUND_CLOSED%', sqlerrm;
  end;

  -- 7. Two hours in the queue: out, told once.
  m_expired := pg_temp.mq_metric('expired');
  r := public.queue_join(u[14],'P14','male');
  assert (r->>'queued')::boolean, r::text;
  update public.match_queue set joined_at=now()-interval '2 hours 1 minute' where user_id=u[14];
  work := public.queue_tick();
  assert work=1, work::text;
  assert not exists(select 1 from public.match_queue where user_id=u[14]), 'expired row is gone';
  assert exists(select 1 from public.push_outbox where kind='queue_expired' and user_id=u[14] and status='pending');
  assert (select count(*) from public.push_outbox where kind='queue_expired' and user_id=any(u))=1;
  assert pg_temp.mq_metric('expired')=m_expired+1;
  assert (select count(*) from public.match_queue)=3, 'fresh rows stay';
  assert public.queue_tick()=0;

  -- 8. Leaving, and the pause.
  assert public.queue_leave(u[9]);
  assert not public.queue_leave(u[9]);
  assert (select count(*) from public.match_queue)=2;
  update public.operations_control set new_rooms_enabled=false where singleton=true;
  begin
    perform public.queue_join(u[15],'P15','male');
    assert false, 'queued while rooms are paused';
  exception when others then
    assert sqlerrm like '%NEW_ROOMS_PAUSED%', sqlerrm;
  end;
  update public.operations_control set new_rooms_enabled=true where singleton=true;
  begin
    perform public.queue_join(u[15],repeat('x',21),'male');
    assert false, 'long name accepted';
  exception when others then
    assert sqlerrm like '%BAD_REQUEST%', sqlerrm;
  end;

  -- 9. Only the service role may call any of it.
  assert not has_function_privilege('anon','public.queue_join(uuid,text,text)','execute');
  assert not has_function_privilege('authenticated','public.queue_join(uuid,text,text)','execute');
  assert not has_function_privilege('anon','public.queue_leave(uuid)','execute');
  assert not has_function_privilege('authenticated','public.queue_leave(uuid)','execute');
  assert not has_function_privilege('anon','public.queue_status(uuid)','execute');
  assert not has_function_privilege('authenticated','public.queue_status(uuid)','execute');
  assert not has_function_privilege('anon','public.queue_ready(uuid,uuid,boolean)','execute');
  assert not has_function_privilege('authenticated','public.queue_ready(uuid,uuid,boolean)','execute');
  assert not has_function_privilege('anon','public.queue_tick()','execute');
  assert not has_function_privilege('authenticated','public.queue_tick()','execute');
  assert not has_function_privilege('authenticated','public.queue_make_room(uuid[])','execute');
  assert not has_function_privilege('authenticated','public.queue_current_seat(uuid)','execute');
  assert has_function_privilege('service_role','public.queue_join(uuid,text,text)','execute');
  assert has_function_privilege('service_role','public.queue_tick()','execute');
  assert not has_table_privilege('anon','public.match_queue','select');
  assert not has_table_privilege('authenticated','public.match_queue','select');
  assert (select relrowsecurity from pg_class where oid='public.match_queue'::regclass);

  -- 10. The three new push kinds are accepted by the outbox, and none of the old ones was lost.
  insert into public.push_outbox(user_id,kind,payload,dedupe_key,expires_at)
    values (u[1],'play_night','{}','mq_kind_play_night',now()+interval '1 hour'),
           (u[1],'rooms_gathering','{}','mq_kind_gathering',now()+interval '1 hour'),
           (u[1],'owner_feedback','{}','mq_kind_owner',now()+interval '1 hour'),
           (u[1],'thursday','{}','mq_kind_thursday',now()+interval '1 hour');
  raise notice 'match_queue PASS';
end $$;

rollback;
