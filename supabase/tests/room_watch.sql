-- Contract for 20261119000300_room_watch. Rolled back.
begin;

create function pg_temp.rw_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

do $$
declare
  host uuid := pg_temp.rw_user();
  p2 uuid := pg_temp.rw_user();
  p3 uuid := pg_temp.rw_user();
  free uuid := pg_temp.rw_user();
  free2 uuid := pg_temp.rw_user();
  r uuid := gen_random_uuid();
  told int;
begin
  update public.economy_config set push_invites_enabled=true, friends_enabled=true;
  -- Only this test's rooms count: any other public lobby is hidden for now.
  update public.rooms set visibility='private' where visibility='public';
  perform public.push_token_register(free,repeat('a',40),'android');
  perform public.push_token_register(free2,repeat('b',40),'android');
  perform public.push_token_register(host,repeat('c',40),'android');

  -- set / get / unset, and a second "on" changes nothing
  assert not public.room_watch_get(free);
  assert public.room_watch_set(free,true);
  assert public.room_watch_set(free,true);
  assert public.room_watch_get(free);
  assert (select count(*) from public.room_watchers where user_id=free)=1;
  assert not public.room_watch_set(free,false);
  assert not public.room_watch_get(free);
  assert public.room_watch_set(free,true);

  -- A public lobby with two connected players and one who dropped: nothing.
  insert into public.rooms(id,code,host_id,match_seed,status,visibility)
    values(r,'QQ7PX2',host,7,'lobby','public');
  insert into public.room_players(room_id,user_id,name,seat,connected)
    values(r,host,'host',0,true),(r,p2,'two',1,true),(r,p3,'three',2,false);
  told := public.rooms_gathering_sweep();
  assert told=0, told::text;
  assert public.room_watch_get(free), 'two connected players must not notify';
  assert not exists(select 1 from public.push_outbox where kind='rooms_gathering');

  -- Three connected players: the watcher who is not seated is told, once,
  -- and the watch is gone. The host, who is seated, is not told and stays.
  update public.room_players set connected=true where room_id=r and user_id=p3;
  assert public.room_watch_set(host,true);
  told := public.rooms_gathering_sweep();
  assert told=1, told::text;
  assert (select count(*) from public.push_outbox where kind='rooms_gathering')=1;
  assert exists(select 1 from public.push_outbox where kind='rooms_gathering' and user_id=free and status='pending');
  assert not exists(select 1 from public.push_outbox where kind='rooms_gathering' and user_id=host);
  assert not public.room_watch_get(free), 'the notified watch is turned off';
  assert public.room_watch_get(host), 'a seated watcher keeps the watch';

  -- Nothing left to tell: a second sweep adds nothing.
  told := public.rooms_gathering_sweep();
  assert told=0, told::text;
  assert (select count(*) from public.push_outbox where kind='rooms_gathering')=1;

  -- A full room does not count, and a private one never does.
  update public.rooms set settings='{"maxPlayers":5}'::jsonb where id=r;
  insert into public.room_players(room_id,user_id,name,seat,connected)
    values(r,gen_random_uuid(),'four',3,true),(r,gen_random_uuid(),'five',4,true);
  assert public.room_watch_set(free2,true);
  assert public.rooms_gathering_sweep()=0, 'a full room is not an invitation';
  update public.rooms set settings='{}'::jsonb,visibility='private' where id=r;
  assert public.rooms_gathering_sweep()=0, 'a private room is not an invitation';
  assert public.room_watch_get(free2);

  -- Only the service role may call any of them.
  assert not has_function_privilege('anon','public.room_watch_set(uuid,boolean)','execute');
  assert not has_function_privilege('authenticated','public.room_watch_set(uuid,boolean)','execute');
  assert not has_function_privilege('anon','public.room_watch_get(uuid)','execute');
  assert not has_function_privilege('authenticated','public.room_watch_get(uuid)','execute');
  assert not has_function_privilege('anon','public.rooms_gathering_sweep()','execute');
  assert not has_function_privilege('authenticated','public.rooms_gathering_sweep()','execute');
  assert has_function_privilege('service_role','public.room_watch_set(uuid,boolean)','execute');
  assert not has_table_privilege('authenticated','public.room_watchers','select');
  assert not has_table_privilege('anon','public.room_watchers','select');
end $$;

rollback;
