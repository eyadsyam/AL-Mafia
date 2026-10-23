begin;

do $$
declare u uuid:=gen_random_uuid(); tag text; n int; w public.wallet_accounts;
  wallet_before jsonb;
begin
  insert into auth.users(id) values(u);
  tag:=public.account_tag(u);
  perform public.commit_play_product(u,'role-refund-0001','mm_coins_2500',
    'GPA.PR1','active',now(),2,tag);
  perform public.buy_reward_item(u,'role_elder');
  assert exists(select 1 from public.player_inventory
    where user_id=u and item_code='role_elder'), 'role was not granted';
  n:=public.revoke_voided_play_purchases(null,array['GPA.PR1']);
  assert n=1, 'unused role pack was not revoked: '||n;
  assert not exists(select 1 from public.player_inventory
    where user_id=u and item_code='role_elder'), 'unspent role entitlement remains';
  assert (select count(*) from public.play_refund_revocations v
    join public.wallet_ledger l on l.id=v.ledger_id
    where l.user_id=u and l.item_code='role_elder')=1,
    'role spend was not revoked exactly once';
  select * into w from public.wallet_accounts where user_id=u;
  assert w.purchase_debt=0, 'unused role refund created debt: '||w.purchase_debt;
  select to_jsonb(a) into wallet_before from public.wallet_accounts a where a.user_id=u;
  assert public.revoke_voided_play_purchases(null,array['GPA.PR1'])=0,
    'second role refund changed purchase';
  assert (select to_jsonb(a) from public.wallet_accounts a where a.user_id=u)=wallet_before,
    'second role refund changed wallet';
  assert not exists(select 1 from public.player_inventory
    where user_id=u and item_code='role_elder'), 'role returned after retry';
  assert (select count(*) from public.play_refund_revocations v
    join public.wallet_ledger l on l.id=v.ledger_id
    where l.user_id=u and l.item_code='role_elder')=1,
    'second role refund duplicated revocation';
end $$;

do $$
declare u uuid:=gen_random_uuid(); tag text; n int; price bigint;
  wallet_before jsonb;
begin
  insert into auth.users(id) values(u);
  tag:=public.account_tag(u);
  perform public.commit_play_product(u,'tool-refund-0001','mm_coins_500',
    'GPA.PT1','active',now(),1,tag);
  select public.tool_pack_price(coin_price,3) into price
    from public.table_tools where code='extra_minute';
  perform public.buy_table_tool(u,'extra_minute',3);
  assert (select charges from public.player_tool_charges
    where user_id=u and tool_code='extra_minute')=3, 'tool pack was not granted';
  n:=public.revoke_voided_play_purchases(null,array['GPA.PT1']);
  assert n=1, 'unused tool pack was not revoked: '||n;
  assert (select charges from public.player_tool_charges
    where user_id=u and tool_code='extra_minute')=0, 'unspent tool charges remain';
  assert (select v.covered from public.play_refund_revocations v
    join public.wallet_ledger l on l.id=v.ledger_id
    where l.user_id=u and l.item_code='extra_minute')=price,
    'unused tool pack coverage differs from its price';
  select to_jsonb(a) into wallet_before from public.wallet_accounts a where a.user_id=u;
  assert public.revoke_voided_play_purchases(null,array['GPA.PT1'])=0,
    'second unused tool refund changed purchase';
  assert (select to_jsonb(a) from public.wallet_accounts a where a.user_id=u)=wallet_before,
    'second unused tool refund changed wallet';
  assert (select charges from public.player_tool_charges
    where user_id=u and tool_code='extra_minute')=0, 'retry restored charges';
  assert (select count(*) from public.play_refund_revocations v
    join public.wallet_ledger l on l.id=v.ledger_id
    where l.user_id=u and l.item_code='extra_minute')=1,
    'retry duplicated tool revocation';
end $$;

do $$
declare u uuid:=gen_random_uuid(); r uuid:=gen_random_uuid(); tag text;
  n int; price bigint; before_use bigint; covered bigint; history_id bigint;
  wallet_before jsonb;
begin
  insert into auth.users(id) values(u);
  tag:=public.account_tag(u);
  perform public.commit_play_product(u,'tool-refund-0002','mm_coins_2500',
    'GPA.PT2','active',now(),1,tag);
  select public.tool_pack_price(coin_price,3) into price
    from public.table_tools where code='revote';
  perform public.buy_table_tool(u,'revote',3);
  select balance into before_use from public.wallet_accounts where user_id=u;
  insert into public.rooms(id,code,host_id,match_seed,status)
    values(r,'PRT234',u,24,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role)
    values(r,u,'Buyer',0,'citizen');
  insert into public.room_state(room_id,phase,phase_number)
    values(r,'vote',1);
  perform public.use_table_tool(u,r,'revote','{}'::int[],null);
  select id into history_id from public.room_tool_uses
    where room_id=r and user_id=u and tool_code='revote';
  assert history_id is not null, 'paid use was not recorded';
  assert (select charges from public.player_tool_charges
    where user_id=u and tool_code='revote')=2, 'paid use did not consume one charge';
  update public.room_state set phase='result',public_data='{"outcome":"town"}'::jsonb
    where room_id=r;
  update public.rooms set status='finished',ended_at=now() where id=r;

  n:=public.revoke_voided_play_purchases(null,array['GPA.PT2']);
  assert n=1, 'partly used tool pack was not revoked: '||n;
  assert (select charges from public.player_tool_charges
    where user_id=u and tool_code='revote')=0, 'remaining charges were not removed';
  assert exists(select 1 from public.room_tool_uses h
    join public.rooms x on x.id=h.room_id
    join public.room_state s on s.room_id=x.id
    where h.id=history_id and h.user_id=u and h.tool_code='revote'
      and x.status='finished' and s.phase='result'), 'consumed use was erased';
  select v.covered into covered from public.play_refund_revocations v
    join public.wallet_ledger l on l.id=v.ledger_id
    where l.user_id=u and l.item_code='revote';
  assert covered=price*2/3, 'partial coverage: '||coalesce(covered::text,'null');
  select to_jsonb(a) into wallet_before from public.wallet_accounts a where a.user_id=u;
  assert public.revoke_voided_play_purchases(null,array['GPA.PT2'])=0,
    'second partial refund changed purchase';
  assert (select to_jsonb(a) from public.wallet_accounts a where a.user_id=u)=wallet_before,
    'second partial refund changed wallet';
  assert (select charges from public.player_tool_charges
    where user_id=u and tool_code='revote')=0, 'retry restored remaining charges';
  assert exists(select 1 from public.room_tool_uses where id=history_id),
    'retry erased consumed use';
  assert (select balance from public.wallet_accounts where user_id=u)<=before_use,
    'refund increased wallet after partial use';
  assert (select count(*) from public.play_refund_revocations v
    join public.wallet_ledger l on l.id=v.ledger_id
    where l.user_id=u and l.item_code='revote')=1,
    'retry duplicated partial revocation';
end $$;

rollback;
select 'PASS role/tool revoke before use, partial use preserved, retry' as result;
