-- Server fixes of 2026-10-09: all seven roles dealt, tool_spend ledger kind,
-- idempotent tool purchase, Silencer on the Mafia team, stored tool answers,
-- grave_vote without a target. Rolled back by the SQL harness.
begin;
do $$
declare
  hst uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
  c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid();
  room uuid:=gen_random_uuid(); got uuid; pd jsonb; res jsonb; req uuid:=gen_random_uuid();
  buyer uuid:=gen_random_uuid(); bal bigint;
begin
  -- 1. every role the players table allows can be dealt online.
  insert into public.rooms(id,code,host_id,match_seed,status) values(room,'SFKM7Q',hst,1,'lobby');
  insert into public.room_state(room_id,phase) values(room,'lobby');
  insert into public.room_players(room_id,user_id,name,seat) values
    (room,hst,'h',0),(room,a,'a',1),(room,b,'b',2),(room,c,'c',3),(room,d,'d',4);
  assert public.apply_match_deal(room,hst,array['mafia','silencer','doctor','elder','sniper'],
    '{}', now()+interval '1 minute'), 'silencer/elder/sniper refused by the deal';
  assert (select role from public.room_players where room_id=room and user_id=a)='silencer';

  -- 3. the Silencer is on the Mafia team.
  assert public.is_mafia_team('silencer') and public.is_mafia_team('mafia');
  assert not public.is_mafia_team('citizen') and not public.is_mafia_team('elder');
  assert public.is_mafia_team(null) is null;

  -- parity with a lone Silencer: 1 silencer + 2 citizens alive -> kick -> 1 v 1 = mafia wins
  -- (a Silencer counted as town used to end it as a town win).
  update public.room_players set role='silencer' where room_id=room and user_id=hst;
  update public.room_players set role='citizen' where room_id=room and user_id in (a,b,c,d);
  update public.room_state set phase='night',phase_number=2 where room_id=room;
  got:=public.kick_member(room,hst,1);
  got:=public.kick_member(room,hst,2);
  assert not ((select public_data from public.room_state where room_id=room) ? 'outcome'),
    'outcome invented with a silencer and two citizens';
  got:=public.kick_member(room,hst,3);
  select public_data into pd from public.room_state where room_id=room;
  assert pd->>'outcome'='mafia', 'lone Silencer at parity must win for the Mafia: '||pd::text;

  -- 2 + 13. buying a tool writes the tool_spend ledger row; a repeat request id is a no-op.
  insert into auth.users(id) values(buyer);
  insert into public.wallet_accounts(user_id,balance) values(buyer,5000);
  perform public.buy_table_tool(buyer,'extra_minute',1,req);
  perform public.buy_table_tool(buyer,'extra_minute',1,req);
  assert (select balance from public.wallet_accounts where user_id=buyer)=4850,
    'repeat request charged twice';
  assert (select charges from public.player_tool_charges where user_id=buyer and tool_code='extra_minute')=1;
  assert (select count(*) from public.wallet_ledger where user_id=buyer and kind='tool_spend')=1;
  perform public.buy_table_tool(buyer,'extra_minute',1);
  assert (select charges from public.player_tool_charges where user_id=buyer and tool_code='extra_minute')=2,
    'a purchase without a request id must still work';
end $$;

-- 9 + 10. stored tool answers (own rows only) and grave_vote without a target.
do $$
declare
  room uuid:=gen_random_uuid(); u0 uuid:=gen_random_uuid(); u1 uuid:=gen_random_uuid();
  u2 uuid:=gen_random_uuid(); u3 uuid:=gen_random_uuid(); u4 uuid:=gen_random_uuid();
  u5 uuid:=gen_random_uuid(); res jsonb; ans jsonb;
begin
  insert into auth.users(id) select x from unnest(array[u0,u5]) x;
  insert into public.rooms(id,code,host_id,match_seed,status,started_at)
    values(room,'SFKM8Q',u0,2,'playing',now()-interval '1 minute');
  insert into public.room_state(room_id,phase,phase_number) values(room,'night',1);
  insert into public.room_players(room_id,user_id,name,seat,role,alive) values
    (room,u0,'seer',0,'citizen',true),(room,u1,'s',1,'silencer',true),
    (room,u2,'c',2,'citizen',true),(room,u3,'d',3,'doctor',true),
    (room,u4,'m',4,'mafia',true),(room,u5,'ghost',5,'citizen',false);
  insert into public.player_tool_charges(user_id,tool_code,charges) values
    (u0,'sense',1),(u0,'narrator_whisper',1),(u5,'grave_vote',1);

  res:=public.use_table_tool(u0,room,'sense',array[1,2,3],null);
  assert (res->>'answer')::boolean, 'a Silencer among the seats must answer yes';
  res:=public.use_table_tool(u0,room,'narrator_whisper',array[2,3],null);
  assert not (res->>'answer')::boolean;

  ans:=public.my_tool_answers(u0,room)->'answers';
  assert jsonb_array_length(ans)=2, ans::text;
  assert (ans->0->>'tool')='sense' and (ans->0->>'answer')::boolean;
  assert public.my_tool_answers(u2,room)->'answers'='[]'::jsonb, 'another player read answers that are not theirs';

  -- grave_vote is retired (20261022000100): the dead seat's charge is refused, not spent.
  update public.room_state set phase='discuss' where room_id=room;
  assert not (select active from public.table_tools where code='grave_vote');
  begin
    perform public.use_table_tool(u5,room,'grave_vote',array[]::int[],null);
    raise exception 'a retired grave_vote was accepted';
  exception when raise_exception then assert sqlerrm='ITEM_NOT_FOUND',sqlerrm; end;
  assert (select charges from public.player_tool_charges where user_id=u5 and tool_code='grave_vote')=1;
end $$;
rollback;
