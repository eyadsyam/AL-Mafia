begin;

do $$
declare u uuid:=gen_random_uuid(); r uuid:=gen_random_uuid();
  before_balance bigint; price bigint; got text;
begin
  insert into auth.users(id) values(u);
  insert into public.wallet_accounts(user_id,balance) values(u,100);
  insert into public.player_tool_charges(user_id,tool_code,charges)
    values(u,'grave_vote',3);
  select coin_price into price from public.table_tools where code='grave_vote';
  assert price=850, 'retirement price changed: '||price;
  assert not (select active from public.table_tools where code='grave_vote'),
    'retired tool is active';
  assert not exists(select 1 from jsonb_array_elements(public.table_tools_snapshot(u)->'tools') x
    where x->>'code'='grave_vote'), 'retired tool appears in app catalogue';

  before_balance:=(select balance from public.wallet_accounts where user_id=u);
  begin
    perform public.buy_table_tool(u,'grave_vote',1);
    raise exception 'retired tool purchase succeeded';
  exception when others then
    get stacked diagnostics got=message_text;
    assert got='ITEM_NOT_FOUND', 'purchase error: '||got;
  end;
  assert (select balance from public.wallet_accounts where user_id=u)=before_balance,
    'refused purchase changed balance';

  insert into public.rooms(id,code,host_id,match_seed,status)
    values(r,'GRV234',u,17,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive)
    values(r,u,'Former owner',0,'citizen',false);
  insert into public.room_state(room_id,phase,phase_number)
    values(r,'vote',1);
  begin
    perform public.use_table_tool(u,r,'grave_vote','{}'::int[],null);
    raise exception 'retired tool use succeeded';
  exception when others then
    get stacked diagnostics got=message_text;
    assert got='ITEM_NOT_FOUND', 'use error: '||got;
  end;
  assert (select charges from public.player_tool_charges
    where user_id=u and tool_code='grave_vote')=3, 'refused use spent a charge';
  assert not exists(select 1 from public.room_tool_uses
    where room_id=r and tool_code='grave_vote'), 'refused use wrote history';
end $$;

-- Replay the migration's inline credit block against a pre-retirement fixture.
create function pg_temp.credit_retired_grave_vote() returns void language plpgsql as $$
declare r record; amount bigint;
begin
  for r in
    select c.user_id, c.charges, t.coin_price
      from public.player_tool_charges c
      join public.table_tools t on t.code=c.tool_code
     where c.tool_code='grave_vote' and c.charges>0
       for update of c
  loop
    amount := r.charges::bigint * r.coin_price;
    update public.wallet_accounts set balance=balance+amount, updated_at=now()
     where user_id=r.user_id;
    if found then
      insert into public.wallet_ledger(user_id,kind,amount,item_code)
        values(r.user_id,'operator_adjustment',amount,'grave_vote');
      update public.player_tool_charges set charges=0, updated_at=now()
       where user_id=r.user_id and tool_code='grave_vote';
    end if;
  end loop;
end $$;

do $$
declare u uuid; r uuid; price bigint; before_balance bigint;
begin
  select c.user_id into u from public.player_tool_charges c
    where c.tool_code='grave_vote' and c.charges=3;
  select coin_price into price from public.table_tools where code='grave_vote';
  select balance into before_balance from public.wallet_accounts where user_id=u;
  perform pg_temp.credit_retired_grave_vote();
  assert (select balance from public.wallet_accounts where user_id=u)=before_balance+3*price,
    'unused charges did not credit at migration price';
  assert (select charges from public.player_tool_charges
    where user_id=u and tool_code='grave_vote')=0, 'credited charges remain';
  assert (select count(*) from public.wallet_ledger
    where user_id=u and kind='operator_adjustment' and item_code='grave_vote'
      and amount=3*price)=1, 'retirement ledger row missing or duplicated';
  perform pg_temp.credit_retired_grave_vote();
  assert (select balance from public.wallet_accounts where user_id=u)=before_balance+3*price,
    'second retirement credit changed balance';
  assert (select count(*) from public.wallet_ledger
    where user_id=u and kind='operator_adjustment' and item_code='grave_vote')=1,
    'second retirement credit wrote ledger';

  select id into r from public.rooms where host_id=u and code='GRV234';
  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number)
    values(r,u,0,'grave_vote','vote',1);
  update public.room_state set phase='result',public_data='{"outcome":"town"}'::jsonb
    where room_id=r;
  update public.rooms set status='finished',ended_at=now() where id=r;
  assert exists(select 1 from public.rooms x
    join public.room_state s on s.room_id=x.id
    join public.room_tool_uses h on h.room_id=x.id
    where x.id=r and x.status='finished' and s.phase='result'
      and s.public_data->>'outcome'='town' and h.user_id=u
      and h.tool_code='grave_vote'), 'past result lost grave_vote history';
end $$;

rollback;
select 'PASS retired grave_vote catalogue, buy/use refusal, credit replay, history' as result;
