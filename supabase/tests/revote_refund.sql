begin;
do $$
declare
  r uuid := gen_random_uuid();
  paid uuid := gen_random_uuid();
  free uuid := gen_random_uuid();
begin
  insert into auth.users(id,is_anonymous) values(paid,true),(free,true);
  insert into public.rooms(id,code,host_id,match_seed,status)
    values(r,'RVREF2',paid,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role)
    values(r,paid,'Paid',0,'citizen'),(r,free,'All access',1,'citizen');
  insert into public.room_state(room_id,phase,phase_number)
    values(r,'vote',1);
  insert into public.all_access_grants(user_id,reason)
    values(free,'refund test');
  insert into public.player_tool_charges(user_id,tool_code,charges)
    values(paid,'revote',1),(free,'revote',4);

  -- Simulate one charged use and one all-access use of the same day.
  update public.player_tool_charges set charges=charges-1
    where user_id=paid and tool_code='revote';
  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number)
    values(r,paid,0,'revote','vote',1),(r,free,1,'revote','vote',1);

  assert public.refund_unused_table_tool(r,'revote',1)=1,
    'only the spent charge is refunded';
  assert (select charges from public.player_tool_charges
    where user_id=paid and tool_code='revote')=1, 'paid charge restored';
  assert (select charges from public.player_tool_charges
    where user_id=free and tool_code='revote')=4, 'all-access user gained no charge';
  assert not exists(select 1 from public.room_tool_uses
    where room_id=r and tool_code='revote' and phase_number=1), 'use rows removed';
  assert public.refund_unused_table_tool(r,'revote',1)=0, 'retry refunded again';
  assert (select charges from public.player_tool_charges
    where user_id=paid and tool_code='revote')=1, 'retry duplicated credit';
  assert not has_function_privilege('authenticated',
    'public.refund_unused_table_tool(uuid,text,integer)','execute'),
    'authenticated can call refund';
  assert not has_function_privilege('anon',
    'public.refund_unused_table_tool(uuid,text,integer)','execute'),
    'anon can call refund';
end $$;
rollback;
select 'PASS revote refund credit, deletion, retry, all-access and grants' as result;
