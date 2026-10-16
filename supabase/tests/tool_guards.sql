-- LOCAL ONLY: node tool/test_sql_without_docker.mjs tool_guards.sql
begin;
create function pg_temp.expect_tool_error(
  p_user uuid, p_room uuid, p_tool text, p_targets int[], p_note text, p_code text
) returns void language plpgsql as $$
declare before_charges int;
begin
  select charges into before_charges from public.player_tool_charges
    where user_id=p_user and tool_code=p_tool;
  begin
    perform public.use_table_tool(p_user,p_room,p_tool,p_targets,p_note);
    raise exception 'tool unexpectedly accepted: %',p_tool;
  exception when others then
    if sqlerrm<>p_code then raise; end if;
  end;
  if (select charges from public.player_tool_charges
      where user_id=p_user and tool_code=p_tool) is distinct from before_charges then
    raise exception 'refused tool spent a charge: %',p_tool;
  end if;
  if exists(select 1 from public.room_tool_uses
      where room_id=p_room and user_id=p_user and tool_code=p_tool) then
    raise exception 'refused tool recorded a use: %',p_tool;
  end if;
end $$;
do $$
declare
  a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); dead_user uuid:=gen_random_uuid();
  r uuid:=gen_random_uuid(); old_fp text; new_fp text;
begin
  insert into auth.users(id,is_anonymous) values(a,true),(b,true),(dead_user,true);
  insert into public.rooms(id,code,host_id,match_seed,status,started_at)
    values(r,'TGUARD',a,1,'playing',now());
  insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
    values(r,a,'A',0,'citizen',true,'connected'),
      (r,b,'B',1,'mafia',true,'connected'),
      (r,dead_user,'Dead',2,'citizen',false,'connected');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r,'vote',1,'{"morning":{"silencedSeat":null}}');
  insert into public.player_tool_charges(user_id,tool_code,charges)
    select u.id,t.code,5 from (values(a),(b),(dead_user)) u(id) cross join public.table_tools t;

  -- T2: a bought revote has no effect after the opening ballot.
  update public.room_state set public_data='{"morning":{"silencedSeat":null},"revote":{"round":2}}' where room_id=r;
  perform pg_temp.expect_tool_error(a,r,'revote','{}',null,'WRONG_PHASE');
  update public.room_state set public_data='{"morning":{"silencedSeat":null}}' where room_id=r;

  -- T3: the dead seat cannot buy a ballot after this vote window.
  update public.room_state set phase='night' where room_id=r;
  perform pg_temp.expect_tool_error(dead_user,r,'grave_vote','{}',null,'WRONG_PHASE');
  update public.room_state set phase='vote' where room_id=r;

  -- T4: silence blocks both ways of buying ballot weight.
  update public.room_state set phase='discuss',public_data='{"morning":{"silencedSeat":0}}' where room_id=r;
  perform pg_temp.expect_tool_error(a,r,'double_vote','{}',null,'SILENCED');
  update public.room_state set phase='vote',public_data='{"morning":{"silencedSeat":2}}' where room_id=r;
  perform pg_temp.expect_tool_error(dead_user,r,'grave_vote','{}',null,'SILENCED');

  -- T5: spotlight requires an alive, speaking target and a talk phase.
  update public.room_state set phase='discuss',public_data='{"morning":{"silencedSeat":1}}' where room_id=r;
  perform pg_temp.expect_tool_error(a,r,'spotlight','{1}',null,'BAD_TARGETS');
  update public.room_state set public_data='{"morning":{"silencedSeat":null}}' where room_id=r;
  perform pg_temp.expect_tool_error(a,r,'spotlight','{2}',null,'BAD_TARGETS');
  update public.room_state set phase='vote' where room_id=r;
  perform pg_temp.expect_tool_error(a,r,'spotlight','{1}',null,'WRONG_PHASE');

  -- T6: a will recorded during night is not immediately public.
  update public.room_state set phase='night' where room_id=r;
  perform pg_temp.expect_tool_error(dead_user,r,'last_will','{}','read me','WRONG_PHASE');

  -- T1: the commit must reject a tally made before a vote tool was bought.
  update public.room_state set phase='vote',public_data='{"morning":{"silencedSeat":null}}' where room_id=r;
  old_fp:=public.vote_fingerprint(r,1,1);
  perform public.use_table_tool(a,r,'revote','{}',null);
  new_fp:=public.vote_fingerprint(r,1,1);
  assert old_fp<>new_fp, 'new vote tool did not alter the fingerprint';
  assert not public.commit_resolution(r,'vote',1,1,null,null,'{}','{}','verdict',now(),old_fp),
    'stale tool tally committed';
  assert public.commit_resolution(r,'vote',1,1,null,null,'{}','{"revote":{"round":2}}','vote',now(),new_fp),
    'fresh tool tally was refused';
end $$;
select 'PASS vote tool fingerprint and T2-T6 tool guards' as result;
rollback;
