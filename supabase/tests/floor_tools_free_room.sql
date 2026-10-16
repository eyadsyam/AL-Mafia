-- LOCAL ONLY: node tool/test_sql_without_docker.mjs floor_tools_free_room.sql
-- RL14 / D24 — extra_minute and objection are refused in a free-discussion room,
-- before any charge is spent; every other tool and every structured room is unchanged.
begin;
do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid();
  free_room uuid := gen_random_uuid(); turns_room uuid := gen_random_uuid(); bare_room uuid := gen_random_uuid();
  t text; before_charges int;
begin
  insert into auth.users(id,is_anonymous) values(a,true),(b,true);
  insert into public.player_tool_charges(user_id,tool_code,charges)
    select a,code,3 from public.table_tools;

  -- a free-talk room
  insert into public.rooms(id,code,host_id,match_seed,status,started_at,settings)
    values(free_room,'FRTLAA',a,1,'playing',now(),'{"discussionMode":"free"}');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
    values(free_room,a,'A',0,'citizen',true,'connected'),(free_room,b,'B',1,'mafia',true,'connected');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(free_room,'discuss',1,'{"morning":{"silencedSeat":null}}');

  foreach t in array array['extra_minute','objection'] loop
    select charges into before_charges from public.player_tool_charges where user_id=a and tool_code=t;
    begin
      perform public.use_table_tool(a,free_room,t,'{}',null);
      raise exception 'a floor tool was accepted in free talk: %',t;
    exception when others then
      if sqlerrm<>'NOT_THIS_ROOM' then raise; end if;
    end;
    assert (select charges from public.player_tool_charges where user_id=a and tool_code=t)=before_charges,
      'the charge was spent: '||t;
    assert not exists(select 1 from public.room_tool_uses where room_id=free_room and tool_code=t),
      'the use was recorded: '||t;
  end loop;
  assert not (select public_data ? 'toolLog' from public.room_state where room_id=free_room),
    'the table was told about a refused tool';

  -- everything else still works in free talk
  perform public.use_table_tool(a,free_room,'anon_note','{}','still allowed');
  perform public.use_table_tool(a,free_room,'spotlight','{1}',null);

  -- a room that talks by turns takes both
  insert into public.rooms(id,code,host_id,match_seed,status,started_at,settings)
    values(turns_room,'FRTLBB',a,1,'playing',now(),'{"discussionMode":"structured"}');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
    values(turns_room,a,'A',0,'citizen',true,'connected'),(turns_room,b,'B',1,'mafia',true,'connected');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(turns_room,'discuss',1,'{"morning":{"silencedSeat":null}}');
  perform public.use_table_tool(a,turns_room,'extra_minute','{}',null);
  perform public.use_table_tool(a,turns_room,'objection','{}',null);
  assert (select charges from public.player_tool_charges where user_id=a and tool_code='extra_minute')=2;

  -- and so does a room that never set a mode (default: by turns)
  insert into public.rooms(id,code,host_id,match_seed,status,started_at)
    values(bare_room,'FRTLCC',a,1,'playing',now());
  insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
    values(bare_room,a,'A',0,'citizen',true,'connected'),(bare_room,b,'B',1,'mafia',true,'connected');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(bare_room,'discuss',1,'{"morning":{"silencedSeat":null}}');
  perform public.use_table_tool(a,bare_room,'extra_minute','{}',null);
end $$;
select 'PASS floor tools: refused before the charge in free talk, allowed by turns and by default, other tools unchanged' as result;
rollback;
