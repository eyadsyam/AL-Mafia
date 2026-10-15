begin;
do $$
declare owner_id uuid:=gen_random_uuid(); normal_id uuid:=gen_random_uuid();
  anonymous_id uuid:=gen_random_uuid(); unconfirmed_id uuid:=gen_random_uuid();
  room_id uuid:=gen_random_uuid(); item record; before_balance bigint;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
    (owner_id,'owner-all-access@example.test',now(),false),
    (normal_id,'normal-all-access@example.test',now(),false),
    (anonymous_id,'anonymous-all-access@example.test',now(),true),
    (unconfirmed_id,'unconfirmed-all-access@example.test',null,false);
  insert into public.wallet_accounts(user_id,balance) values(owner_id,0),(normal_id,0);
  assert public.grant_all_access_by_email('OWNER-ALL-ACCESS@example.test','owner')=owner_id;
  assert public.grant_all_access_by_email('owner-all-access@example.test','owner again')=owner_id;
  assert (select count(*) from public.all_access_grants where user_id=owner_id)=1;
  assert public.has_all_access(owner_id) and not public.has_all_access(normal_id);
  for item in select code from public.reward_catalog where active and released loop
    assert public.user_owns_item(owner_id,item.code), item.code;
    assert not public.user_owns_item(normal_id,item.code), item.code;
    assert public.catalog_charge(owner_id,item.code)=0, item.code;
  end loop;
  assert public.user_owns_entitlement(owner_id,'scenario_shadows');
  assert not public.user_owns_entitlement(owner_id,'remove_interruptions'), 'ads changed';
  -- The once-per-account paid bundle gate is money, not ownership: unchanged.
  assert not public.owns_starter_bundle(owner_id), 'paid bundle gate changed';
  assert not public.owns_starter_bundle(normal_id);
  assert (public.wallet_snapshot(owner_id)->'owned') @> '["role_silencer","role_elder","role_sniper"]';
  assert (public.purchase_snapshot(owner_id)->'owned') @> '["scenario_shadows"]';
  assert public.wallet_snapshot(owner_id)->>'allAccess'='true';
  assert public.wallet_snapshot(normal_id)->>'allAccess'='false';
  select balance into before_balance from public.wallet_accounts where user_id=owner_id;
  perform public.buy_reward_item(owner_id,'role_silencer');
  assert (select balance from public.wallet_accounts where user_id=owner_id)=before_balance;
  assert not exists(select 1 from public.player_inventory where user_id=owner_id);
  assert not exists(select 1 from public.wallet_ledger where user_id=owner_id);
  begin
    perform public.buy_reward_item(normal_id,'role_silencer');
    raise exception 'normal bought role with zero balance';
  exception when others then
    if sqlerrm <> 'INSUFFICIENT_COINS' then raise; end if;
  end;
  perform public.equip_reward_item(owner_id,'frame','frame_moonlit');
  assert (select item_code from public.player_equipment where user_id=owner_id and slot='frame')='frame_moonlit';
  begin
    perform public.equip_reward_item(normal_id,'frame','frame_moonlit');
    raise exception 'normal equipped unowned item';
  exception when others then
    if sqlerrm <> 'ITEM_NOT_OWNED' then raise; end if;
  end;
  perform public.buy_table_tool(owner_id,'anon_note',1);
  assert not exists(select 1 from public.player_tool_charges where user_id=owner_id);
  insert into public.rooms(id,code,host_id,match_seed,status,started_at)
    values(room_id,'AALACS',owner_id,1,'playing',now());
  insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
    values(room_id,owner_id,'Owner',0,'citizen',true,'connected'),
      (room_id,normal_id,'Normal',1,'mafia',true,'connected');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(room_id,'discuss',1,'{}');
  perform public.use_table_tool(owner_id,room_id,'anon_note','{}','one');
  assert not exists(select 1 from public.player_tool_charges where user_id=owner_id);
  update public.room_state set phase_number=2;
  perform public.use_table_tool(owner_id,room_id,'anon_note','{}','two');
  update public.room_state set phase_number=3;
  begin
    perform public.use_table_tool(owner_id,room_id,'anon_note','{}','three');
    raise exception 'per-match limit bypassed';
  exception when others then
    if sqlerrm <> 'LIMIT_TOOL' then raise; end if;
  end;
  begin
    perform public.buy_table_tool(normal_id,'anon_note',1);
    raise exception 'normal bought tool with zero balance';
  exception when others then
    if sqlerrm <> 'INSUFFICIENT_COINS' then raise; end if;
  end;
  begin
    perform public.use_table_tool(normal_id,room_id,'anon_note','{}','normal note');
    raise exception 'normal used tool without charges';
  exception when others then
    if sqlerrm <> 'NO_CHARGES' then raise; end if;
  end;
  begin
    perform public.grant_all_access_by_email('unknown@example.test','test');
    raise exception 'unknown account granted';
  exception when others then
    if sqlerrm <> 'ACCOUNT_NOT_ELIGIBLE' then raise; end if;
  end;
  begin
    perform public.grant_all_access_by_email('unconfirmed-all-access@example.test','test');
    raise exception 'unconfirmed account granted';
  exception when others then
    if sqlerrm <> 'ACCOUNT_NOT_ELIGIBLE' then raise; end if;
  end;
  begin
    perform public.grant_all_access_by_email('anonymous-all-access@example.test','test');
    raise exception 'anonymous account granted';
  exception when others then
    if sqlerrm <> 'ACCOUNT_NOT_ELIGIBLE' then raise; end if;
  end;
  insert into public.all_access_grants(user_id,reason) values(anonymous_id,'ineligible fixture');
  perform set_config('request.jwt.claim.sub',anonymous_id::text,true);
  assert public.my_entitlements()->>'allAccess'='false';
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  assert public.my_entitlements()->>'allAccess'='true';
  perform public.revoke_all_access(owner_id,'closed');
  assert not public.has_all_access(owner_id);
  assert not public.user_owns_item(owner_id,'role_silencer');
  assert not exists(select 1 from public.player_equipment where user_id=owner_id);
  assert public.my_entitlements()->>'allAccess'='false';
end $$;
set local role authenticated;
do $$ begin
  begin
    insert into public.all_access_grants(user_id,reason) values(gen_random_uuid(),'attack');
    raise exception 'authenticated inserted grant';
  exception when insufficient_privilege then null; end;
  begin
    perform public.has_all_access(gen_random_uuid());
    raise exception 'authenticated called private grant check';
  exception when insufficient_privilege then null; end;
  begin
    perform public.grant_all_access_by_email('owner-all-access@example.test','attack');
    raise exception 'authenticated called grant';
  exception when insufficient_privilege then null; end;
  begin
    perform public.revoke_all_access(gen_random_uuid(),'attack');
    raise exception 'authenticated called revoke';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
