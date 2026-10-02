-- Contract for 20260924000700_store_v2_catalog. Rolled back.
begin;
do $$
declare
  buyer uuid:=gen_random_uuid(); fresh uuid:=gen_random_uuid();
  snap jsonb; spent bigint;
begin
  insert into auth.users(id) values(buyer),(fresh);
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values
    (buyer,5000,5000),(fresh,5000,5000);

  -- Five cosmetic categories, three or more items each.
  assert (select count(*) from public.reward_catalog where active and released
    and kind='frame')>=3;
  assert (select count(*) from public.reward_catalog where active and released
    and kind='nameplate')>=3;
  assert (select count(*) from public.reward_catalog where active and released
    and kind='presentation_pack')>=3;
  assert (select count(*) from public.reward_catalog where active and released
    and kind='narrator_pack')>=3;
  assert (select count(*) from public.reward_catalog where active and released
    and kind='bundle')>=3;

  -- The new rows are listed with their slots and exact contents.
  snap:=public.wallet_snapshot(fresh);
  assert (snap->'catalog') @> '[{"code":"pack_moonlit_archive","slot":"room_pack"}]', snap::text;
  assert (snap->'catalog') @> '[{"code":"narrator_keeper","slot":"narrator"}]';
  assert (snap->'catalog') @> '[{"code":"narrator_noir","slot":"narrator"}]';
  assert (select contents from public.reward_catalog where code='bundle_nocturne')
    = '{pack_moonlit_archive,frame_moonlit,plate_noir,narrator_keeper}'::text[];
  -- The original collections keep what they always granted.
  assert (select contents from public.reward_catalog where code='bundle_council')
    = '{pack_midnight_manor,pack_old_town,narrator_storyteller}'::text[];
  assert (select contents from public.reward_catalog where code='bundle_identity')
    = '{frame_gilded,frame_crimson,frame_moonlit,plate_noir,plate_gilded,plate_ember}'::text[];

  -- The collection charges only for what is not owned, grants each item once,
  -- and a repeated purchase pays nothing.
  perform public.buy_reward_item(buyer,'frame_moonlit');
  assert public.catalog_charge(buyer,'bundle_nocturne')=1800-300;
  snap:=public.buy_reward_item(buyer,'bundle_nocturne');
  snap:=public.buy_reward_item(buyer,'bundle_nocturne');
  select -sum(amount) into spent from public.wallet_ledger
    where user_id=buyer and kind='catalog_spend';
  assert spent=300+1500, spent::text;
  assert (snap->>'balance')::bigint=5000-1800, snap::text;
  assert (snap->'owned') @> '["pack_moonlit_archive","frame_moonlit","plate_noir","narrator_keeper","bundle_nocturne"]';
  assert (select count(*) from public.player_inventory where user_id=buyer)=5;
  assert not (snap->'owned') @> '["narrator_noir"]';

  -- Each new item equips only in its own slot.
  snap:=public.equip_reward_item(buyer,'narrator','narrator_keeper');
  assert snap->'equipped'->>'narrator'='narrator_keeper';
  snap:=public.equip_reward_item(buyer,'room_pack','pack_moonlit_archive');
  assert snap->'equipped'->>'room_pack'='pack_moonlit_archive';
  begin
    perform public.equip_reward_item(buyer,'frame','narrator_keeper');
    assert false, 'wrong slot accepted';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED', sqlerrm;
  end;
  begin
    perform public.equip_reward_item(buyer,'narrator','narrator_noir');
    assert false, 'equipped without owning';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED', sqlerrm;
  end;
end $$;
rollback;
