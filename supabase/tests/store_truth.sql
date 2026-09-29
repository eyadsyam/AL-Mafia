-- Store truth: every paid item is owned exactly once, equips only into its
-- own slot and only when owned, a bundle grants all its parts idempotently,
-- a revoked item leaves the equipment safely, and the public identity rows
-- (friends, leaderboard, seat) carry what is equipped.
begin;
do $$
declare
  a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); snap jsonb; bal bigint;
  spent_before int; rid uuid:=gen_random_uuid(); st jsonb; i int; v_code text;
begin
  insert into auth.users(id) values(a),(b);
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values(a,10000,10000),(b,500,500);

  -- Every item on sale has a slot (or is a bundle of slotted items).
  for v_code in select c.code from public.reward_catalog c where c.active and c.released loop
    assert exists(select 1 from public.reward_catalog x where x.code=v_code and
      ((x.kind='bundle' and x.slot is null and cardinality(x.contents)>0 and not exists(
          select 1 from unnest(x.contents) part join public.reward_catalog y on y.code=part
           where y.slot is null)) or (x.kind<>'bundle' and x.slot is not null))),
      'item without an effect slot: '||v_code;
  end loop;

  -- Bundle: grants every part, charges once, a second buy changes nothing.
  snap:=public.buy_reward_item(a,'bundle_identity');
  bal:=(snap->>'balance')::bigint;
  assert bal=10000-1200,snap::text;
  assert (snap->'owned') @> '["frame_gilded","frame_crimson","frame_moonlit","plate_noir","plate_gilded","plate_ember","bundle_identity"]',snap::text;
  select count(*) into spent_before from public.wallet_ledger where user_id=a and kind='catalog_spend';
  snap:=public.buy_reward_item(a,'bundle_identity');
  assert (snap->>'balance')::bigint=bal,'second bundle buy charged';
  assert (select count(*) from public.wallet_ledger where user_id=a and kind='catalog_spend')=spent_before;
  assert (select count(*) from public.player_inventory where user_id=a and item_code='frame_moonlit')=1;
  -- An overlapping bundle charges only for the parts not yet owned.
  assert public.catalog_charge(a,'bundle_nocturne')=1800-300-150,
    'nocturne charge: '||public.catalog_charge(a,'bundle_nocturne');
  snap:=public.buy_reward_item(a,'bundle_nocturne');
  assert (snap->'owned') @> '["pack_moonlit_archive","narrator_keeper","bundle_nocturne"]';
  -- Buying a part already owned through a bundle is free and writes nothing.
  select count(*) into spent_before from public.wallet_ledger where user_id=a and kind='catalog_spend';
  snap:=public.buy_reward_item(a,'plate_ember');
  assert (select count(*) from public.wallet_ledger where user_id=a and kind='catalog_spend')=spent_before;

  -- Equip: only owned, only into its own slot; unequip clears.
  begin
    perform public.equip_reward_item(b,'frame','frame_gilded');
    raise exception 'unowned frame equipped';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED',sqlerrm;
  end;
  begin
    perform public.equip_reward_item(a,'nameplate','frame_gilded');
    raise exception 'frame equipped as a nameplate';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED',sqlerrm;
  end;
  begin
    perform public.equip_reward_item(a,'crown','frame_gilded');
    raise exception 'unknown slot accepted';
  exception when others then assert sqlerrm='BAD_REQUEST',sqlerrm;
  end;
  begin
    perform public.equip_reward_item(a,'frame','bundle_identity');
    raise exception 'a bundle was equipped';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED',sqlerrm;
  end;
  snap:=public.equip_reward_item(a,'frame','frame_crimson');
  snap:=public.equip_reward_item(a,'nameplate','plate_ember');
  snap:=public.equip_reward_item(a,'room_pack','pack_moonlit_archive');
  snap:=public.equip_reward_item(a,'narrator','narrator_keeper');
  assert snap->'equipped'='{"frame":"frame_crimson","nameplate":"plate_ember","room_pack":"pack_moonlit_archive","narrator":"narrator_keeper"}'::jsonb,snap::text;

  -- A seat copies frame and plate (never packs) when it is taken.
  insert into public.rooms(id,code,host_id,match_seed) values(rid,'STRTHA',a,1);
  insert into public.room_players(room_id,user_id,name,seat) values(rid,a,'A',0);
  assert (select cosmetics->>'frame'='frame_crimson' and cosmetics->>'nameplate'='plate_ember'
    and not (cosmetics ? 'room_pack') from public.room_players where room_id=rid and user_id=a);

  -- Public identity rows carry frame and plate.
  assert public.public_cosmetics(a)='{"frame":"frame_crimson","plate":"plate_ember"}'::jsonb;
  assert public.public_cosmetics(b)='{"frame":null,"plate":null}'::jsonb;
  st:=public.with_public_cosmetics(jsonb_build_array(jsonb_build_object('id',a,'name','A'),
    jsonb_build_object('name','no id')));
  assert st->0->>'frame'='frame_crimson' and st->0->>'plate'='plate_ember',st::text;
  assert not (st->1 ? 'frame'),'a row without an id is left alone';
  update public.economy_config set friends_enabled=true;
  insert into public.friend_links(user_lo,user_hi,requested_by,accepted_at)
    values(least(a,b),greatest(a,b),a,now());
  st:=public.friends_status(b);
  assert st->'friends'->0->>'frame'='frame_crimson',st::text;
  assert st->'friends'->0->>'plate'='plate_ember',st::text;
  update public.economy_config set council_rank_enabled=true,council_leaderboard_enabled=true;
  insert into public.council_xp_events(user_id,source_key,xp,week)
    values(a,'test:1',50,public.council_week(public.economy_today()));
  st:=public.council_leaderboard(b);
  assert st->'entries'->0->>'frame'='frame_crimson' and st->'entries'->0->>'plate'='plate_ember',st::text;
  assert not (st::text like '%'||a::text||'%'),'leaderboard rows carry no user id';

  -- A revoked item (the Starter Bundle's frame) leaves the equipment safely:
  -- the equipment row goes with the inventory row, other slots stay.
  insert into public.player_inventory(user_id,item_code) values(a,'frame_council_seal');
  perform public.equip_reward_item(a,'frame','frame_council_seal');
  delete from public.player_inventory where user_id=a and item_code='frame_council_seal';
  snap:=public.wallet_snapshot(a);
  assert not (snap->'equipped' ? 'frame'),'revoked frame still equipped: '||snap::text;
  assert snap->'equipped'->>'nameplate'='plate_ember','other slots untouched';
  -- A new seat after the revocation carries no revoked frame.
  insert into public.room_players(room_id,user_id,name,seat) values(rid,b,'B',1);
  delete from public.room_players where room_id=rid and user_id=a;
  insert into public.room_players(room_id,user_id,name,seat) values(rid,a,'A',0);
  assert (select not (cosmetics ? 'frame') from public.room_players where room_id=rid and user_id=a);
end $$;
rollback;
