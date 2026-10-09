-- LOCAL ONLY: node tool/test_sql_without_docker.mjs live_tools_regressions.sql
begin;
do $$
declare
  a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); r uuid:=gen_random_uuid();
  reply jsonb; entry jsonb; first_deadline timestamptz; t record; n int;
begin
  insert into auth.users(id,is_anonymous) values(a,true),(b,true);
  insert into public.rooms(id,code,host_id,match_seed,status,started_at)
    values(r,'TLABCD',a,1,'playing',now());
  insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
    values(r,a,'Bot A',0,'citizen',true,'connected'),(r,b,'Bot B',1,'mafia',true,'connected');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r,'discuss',1,'{"morning":{"silencedSeat":null}}');
  insert into public.player_tool_charges(user_id,tool_code,charges)
    select a,code,3 from public.table_tools;

  reply:=public.use_table_tool(a,r,'anon_note','{}','anonymous bot note');
  select public_data->'toolLog'->0 into entry from public.room_state where room_id=r;
  assert entry->>'seat' is null, 'anonymous note exposes its author';
  assert entry->>'note'='anonymous bot note', 'anonymous note lost its text';

  -- Acquiring the floor and spending a bonus are one transaction. Retrying
  -- while holding it preserves the deadline, and cannot consume twice.
  perform public.use_table_tool(a,r,'extra_minute','{}',null);
  assert public.claim_floor_with_tools(r,a,30,'discuss',1);
  select speaker_until into first_deadline from public.room_state where room_id=r;
  assert first_deadline=now()+interval '75 seconds', 'bonus not added exactly once';
  assert public.claim_floor_with_tools(r,a,30,'discuss',1);
  assert (select speaker_until from public.room_state where room_id=r)=first_deadline,
    'same-holder retry changed deadline';
  perform public.release_speaking_floor(r,a);
  assert public.claim_floor_with_tools(r,a,30,'discuss',1);
  assert (select speaker_until from public.room_state where room_id=r)=now()+interval '30 seconds',
    'bonus was spent twice';
  assert not public.claim_floor_with_tools(r,b,30,'discuss',1), 'stole live floor';
  update public.room_state set phase='night',active_speaker=null where room_id=r;
  assert not public.claim_floor_with_tools(r,a,30,'discuss',1), 'stale floor claim crossed phase';
  update public.room_state set phase='discuss' where room_id=r;
  assert not public.claim_floor_with_tools(r,a,30,'discuss',2), 'stale day claim accepted';
  update public.room_state set public_data='{"morning":{"silencedSeat":0}}' where room_id=r;
  assert not public.claim_floor_with_tools(r,a,30,'discuss',1), 'silenced seat claimed floor';

  -- Every alive-only tool refuses a dead user without spending a charge.
  update public.room_players set alive=false where room_id=r and user_id=a;
  for t in select * from public.table_tools where phase<>'dead' loop
    select charges into n from public.player_tool_charges where user_id=a and tool_code=t.code;
    begin
      perform public.use_table_tool(a,r,t.code,'{}',null);
      raise exception 'dead use accepted: %',t.code;
    exception when others then
      if sqlerrm<>'NOT_ALIVE' then raise; end if;
    end;
    assert (select charges from public.player_tool_charges where user_id=a and tool_code=t.code)=n;
  end loop;
end $$;
rollback;
