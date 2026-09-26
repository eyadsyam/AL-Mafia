-- Contract for 20260924000300_cosmetic_catalog. Rolled back.
begin;
do $$
declare
  buyer uuid:=gen_random_uuid(); poor uuid:=gen_random_uuid(); host uuid:=gen_random_uuid();
  snap jsonb; r jsonb; bal bigint;
begin
  insert into auth.users(id) values(buyer),(poor),(host);
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values
    (buyer,3000,3000),(poor,100,100),(host,1000,1000);

  -- The guide is not for sale; the new catalog is.
  snap:=public.wallet_snapshot(buyer);
  assert not (snap->'catalog') @> '[{"code":"mastermind_guide"}]';
  assert (snap->'catalog') @> '[{"code":"pack_midnight_manor","price":600,"charge":600}]';
  -- Eleven from this migration, four more from 20260924000700_store_v2_catalog.
  assert jsonb_array_length(snap->'catalog')=15, (snap->'catalog')::text;

  -- One purchase, charged once, however often it is asked.
  snap:=public.buy_reward_item(buyer,'pack_midnight_manor');
  snap:=public.buy_reward_item(buyer,'pack_midnight_manor');
  assert (snap->>'balance')::bigint=2400, snap::text;
  assert (select count(*) from public.wallet_ledger where user_id=buyer and kind='catalog_spend')=1;

  -- Bundles subtract what is owned and grant the rest.
  assert public.catalog_charge(buyer,'bundle_council')=2300-600;
  snap:=public.buy_reward_item(buyer,'bundle_council');
  assert (snap->>'balance')::bigint=2400-1700, snap::text;
  assert (snap->'owned') @> '["pack_old_town","narrator_storyteller","bundle_council"]';

  -- Not enough coins: refused, nothing written.
  begin
    perform public.buy_reward_item(poor,'frame_moonlit');
    assert false, 'bought without coins';
  exception when others then assert sqlerrm='INSUFFICIENT_COINS', sqlerrm;
  end;
  assert (select balance from public.wallet_accounts where user_id=poor)=100;
  assert not exists(select 1 from public.player_inventory where user_id=poor);

  -- Unknown or retired codes are refused.
  begin
    perform public.buy_reward_item(buyer,'mastermind_guide');
    assert false, 'retired guide sold';
  exception when others then assert sqlerrm='ITEM_NOT_FOUND', sqlerrm;
  end;

  -- Equip only what is owned, only in its slot.
  begin
    perform public.equip_reward_item(poor,'frame','frame_gilded');
    assert false, 'equipped without owning';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED', sqlerrm;
  end;
  begin
    perform public.equip_reward_item(buyer,'frame','pack_old_town');
    assert false, 'wrong slot accepted';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED', sqlerrm;
  end;
  perform public.buy_reward_item(host,'frame_gilded');
  snap:=public.equip_reward_item(host,'frame','frame_gilded');
  assert snap->'equipped'->>'frame'='frame_gilded';

  -- A seat copies the equipped frame when it is taken, and clients can read it.
  r:=public.create_room_atomic('CSMTAA',host,'H','male',7,'{"visibility":"private"}'::jsonb);
  assert (select cosmetics->>'frame' from public.room_players where user_id=host)='frame_gilded';
  assert has_column_privilege('authenticated','public.room_players','cosmetics','select');
  assert exists(select 1 from information_schema.columns
    where table_name='room_players_public' and column_name='cosmetics');

  -- Unequip.
  snap:=public.equip_reward_item(host,'frame',null);
  assert snap->'equipped' = '{}'::jsonb;

  -- The guide refund is once per player (unique index).
  insert into public.wallet_ledger(user_id,kind,amount,item_code)
    values(buyer,'catalog_refund',400,'mastermind_guide');
  begin
    insert into public.wallet_ledger(user_id,kind,amount,item_code)
      values(buyer,'catalog_refund',400,'mastermind_guide');
    assert false, 'second refund accepted';
  exception when unique_violation then null;
  end;

  assert not has_function_privilege('authenticated','public.buy_reward_item(uuid,text)','execute');
  assert not has_function_privilege('authenticated','public.equip_reward_item(uuid,text,text)','execute');
end $$;
rollback;
