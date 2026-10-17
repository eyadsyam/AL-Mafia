begin;
do $$
declare returned_user uuid:=gen_random_uuid(); own_user uuid:=gen_random_uuid();
  other_user uuid:=gen_random_uuid(); bundle_time timestamptz:=now()+interval '1 second';
  component text;
begin
  insert into auth.users(id) values(returned_user),(own_user),(other_user);
  perform public.commit_play_product(returned_user,'bundle-refund-1','mm_coins_500',
    'GPA.B1','active',now(),1,public.account_tag(returned_user));
  perform public.commit_play_product(own_user,'bundle-refund-2','mm_coins_500',
    'GPA.B2','active',now(),1,public.account_tag(own_user));

  -- This component was independently bought before the second user's bundle.
  insert into public.wallet_ledger(user_id,kind,amount,item_code,created_at)
    values(own_user,'catalog_spend',-200,'frame_gilded',now()-interval '2 seconds');
  insert into public.player_inventory(user_id,item_code,acquired_at)
    values(own_user,'frame_gilded',now()-interval '2 seconds');

  foreach component in array (select contents from public.reward_catalog where code='bundle_identity') loop
    insert into public.player_inventory(user_id,item_code,acquired_at)
      values(returned_user,component,bundle_time),(other_user,component,bundle_time)
      on conflict do nothing;
    insert into public.player_inventory(user_id,item_code,acquired_at)
      values(own_user,component,bundle_time) on conflict do nothing;
  end loop;
  insert into public.player_inventory(user_id,item_code)
    values(returned_user,'bundle_identity'),(own_user,'bundle_identity'),
          (other_user,'bundle_identity');
  insert into public.wallet_ledger(user_id,kind,amount,item_code,created_at)
    values(returned_user,'catalog_spend',-100,'bundle_identity',bundle_time),
          (own_user,'catalog_spend',-100,'bundle_identity',bundle_time);
  insert into public.player_equipment(user_id,slot,item_code)
    values(returned_user,'frame','frame_gilded'),
          (own_user,'frame','frame_gilded'),
          (other_user,'frame','frame_gilded');

  -- The coin pack was spent on the bundle, so the returned pack must revoke it.
  update public.wallet_accounts set purchased_balance=0
    where user_id in (returned_user,own_user);
  assert public.reverse_play_coins('bundle-refund-1'), 'first return processed';
  assert not exists(select 1 from public.player_inventory
    where user_id=returned_user and item_code='bundle_identity'), 'bundle removed';
  assert not exists(select 1 from public.player_inventory i
    join public.reward_catalog b on b.code='bundle_identity'
    where i.user_id=returned_user and i.item_code=any(b.contents)), 'components removed';
  assert not exists(select 1 from public.player_equipment
    where user_id=returned_user and slot='frame'), 'removed component unequipped';

  assert public.reverse_play_coins('bundle-refund-2'), 'second return processed';
  assert not exists(select 1 from public.player_inventory
    where user_id=own_user and item_code='bundle_identity'), 'second bundle removed';
  assert exists(select 1 from public.player_inventory
    where user_id=own_user and item_code='frame_gilded'), 'separate purchase kept';
  assert exists(select 1 from public.player_equipment
    where user_id=own_user and slot='frame' and item_code='frame_gilded'),
    'separately owned component stays equipped';
  assert not exists(select 1 from public.player_inventory i
    join public.reward_catalog b on b.code='bundle_identity'
    where i.user_id=own_user and i.item_code=any(b.contents)
      and i.item_code<>'frame_gilded'), 'other components removed';

  assert exists(select 1 from public.player_inventory
    where user_id=other_user and item_code='bundle_identity'), 'other bundle untouched';
  assert (select count(*) from public.player_inventory i
    join public.reward_catalog b on b.code='bundle_identity'
    where i.user_id=other_user and i.item_code=any(b.contents))=
    (select cardinality(contents) from public.reward_catalog where code='bundle_identity'),
    'other user components untouched';
  assert exists(select 1 from public.player_equipment
    where user_id=other_user and slot='frame' and item_code='frame_gilded'),
    'other user equipment untouched';
end $$;
rollback;
