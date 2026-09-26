-- «عملات المافيا» catalog: real cosmetic content, equip slots, bundles, and the
-- strategy guide leaving the store.
--
-- Everything here is presentation. Nothing changes votes, roles, information
-- or outcomes; the engine never reads any of it. Prices are server-owned; the
-- client only ever sends an item code.

-- 1. Catalog shape ----------------------------------------------------------
alter table public.reward_catalog
  add column if not exists kind text not null default 'guide',
  add column if not exists slot text,
  add column if not exists contents text[] not null default '{}',
  add column if not exists released boolean not null default true;
alter table public.reward_catalog add constraint reward_catalog_kind_known
  check (kind in ('guide','frame','nameplate','presentation_pack','narrator_pack','bundle'));
alter table public.reward_catalog add constraint reward_catalog_slot_known
  check ((kind in ('guide','bundle') and slot is null) or
         (kind='frame' and slot='frame') or (kind='nameplate' and slot='nameplate') or
         (kind='presentation_pack' and slot='room_pack') or
         (kind='narrator_pack' and slot='narrator'));
alter table public.reward_catalog add constraint reward_catalog_bundle_contents
  check ((kind='bundle') = (cardinality(contents) > 0));

-- Prices: 100 coins per finished online match (+25 on a win). 150–300 basic,
-- 600–1200 content packs, bundles below the sum of their contents.
insert into public.reward_catalog(code,coin_price,sort_order,kind,slot,contents) values
  ('frame_gilded',200,110,'frame','frame','{}'),
  ('frame_crimson',250,120,'frame','frame','{}'),
  ('frame_moonlit',300,130,'frame','frame','{}'),
  ('plate_noir',150,210,'nameplate','nameplate','{}'),
  ('plate_gilded',250,220,'nameplate','nameplate','{}'),
  ('plate_ember',300,230,'nameplate','nameplate','{}'),
  ('pack_midnight_manor',600,310,'presentation_pack','room_pack','{}'),
  ('pack_old_town',900,320,'presentation_pack','room_pack','{}'),
  ('narrator_storyteller',1200,410,'narrator_pack','narrator','{}'),
  ('bundle_council',2300,510,'bundle',null,
    '{pack_midnight_manor,pack_old_town,narrator_storyteller}'),
  ('bundle_identity',1200,520,'bundle',null,
    '{frame_gilded,frame_crimson,frame_moonlit,plate_noir,plate_gilded,plate_ember}')
on conflict(code) do update set coin_price=excluded.coin_price,
  sort_order=excluded.sort_order, kind=excluded.kind, slot=excluded.slot,
  contents=excluded.contents, active=true, released=true;

-- 2. The guide is free now (Help). Owners keep it; its cost comes back once.
update public.reward_catalog set active=false, kind='guide' where code='mastermind_guide';

alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
alter table public.wallet_ledger add constraint wallet_ledger_kind_check check (kind in (
  'match_completion','match_win','catalog_spend','operator_adjustment','ad_reward',
  'purchase','catalog_refund','coin_purchase','coin_purchase_reversal'));
create unique index if not exists wallet_catalog_refund_once
  on public.wallet_ledger(user_id,item_code) where kind='catalog_refund';

with spent as (
  select l.user_id, -sum(l.amount) as paid
  from public.wallet_ledger l
  where l.kind='catalog_spend' and l.item_code='mastermind_guide'
  group by l.user_id
), refunded as (
  insert into public.wallet_ledger(user_id,kind,amount,item_code)
  select user_id,'catalog_refund',paid,'mastermind_guide' from spent where paid>0
  on conflict do nothing
  returning user_id, amount
)
update public.wallet_accounts a
   set balance=a.balance+r.amount, lifetime_spent=greatest(a.lifetime_spent-r.amount,0),
       updated_at=now()
  from refunded r where a.user_id=r.user_id;

-- 3. Equipment ----------------------------------------------------------------
create table if not exists public.player_equipment (
  user_id uuid not null,
  slot text not null check (slot in ('frame','nameplate','room_pack','narrator')),
  item_code text not null references public.reward_catalog(code),
  updated_at timestamptz not null default now(),
  primary key (user_id, slot),
  foreign key (user_id, item_code) references public.player_inventory(user_id, item_code)
    on delete cascade
);
alter table public.player_equipment enable row level security;
revoke all on public.player_equipment from public, anon, authenticated;
grant all on public.player_equipment to service_role;

-- 4. Snapshot, purchase, equip ------------------------------------------------
create or replace function public.catalog_charge(p_user uuid, p_item text)
returns bigint language sql stable security definer set search_path=public,pg_temp as $$
  -- A bundle never charges for what the player already owns.
  select case when c.kind <> 'bundle' then c.coin_price else greatest(0,
    c.coin_price - coalesce((select sum(x.coin_price) from public.reward_catalog x
      join public.player_inventory i on i.item_code=x.code and i.user_id=p_user
      where x.code = any(c.contents)),0)) end
  from public.reward_catalog c where c.code=p_item
$$;
revoke all on function public.catalog_charge(uuid,text) from public,anon,authenticated;
grant execute on function public.catalog_charge(uuid,text) to service_role;

create or replace function public.wallet_snapshot(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare account public.wallet_accounts; items jsonb; owned jsonb; equipped jsonb; history jsonb;
begin
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  select * into account from public.wallet_accounts where user_id=p_user;
  select coalesce(jsonb_agg(jsonb_build_object(
      'code',code,'price',coin_price,'kind',kind,'slot',slot,'contents',to_jsonb(contents),
      'charge',public.catalog_charge(p_user,code)) order by sort_order,code),'[]')
    into items from public.reward_catalog where active and released;
  select coalesce(jsonb_agg(item_code order by item_code),'[]') into owned
    from public.player_inventory where user_id=p_user;
  select coalesce(jsonb_object_agg(slot,item_code),'{}') into equipped
    from public.player_equipment where user_id=p_user;
  select coalesce(jsonb_agg(jsonb_build_object('kind',kind,'amount',amount,
      'item',item_code,'at',created_at) order by created_at desc),'[]')
    into history from (select * from public.wallet_ledger where user_id=p_user
      order by created_at desc limit 30) recent;
  return jsonb_build_object('balance',account.balance,'catalog',items,'owned',owned,
    'equipped',equipped,'history',history,
    'earned',account.lifetime_earned,'spent',account.lifetime_spent);
end $$;
revoke all on function public.wallet_snapshot(uuid) from public,anon,authenticated;
grant execute on function public.wallet_snapshot(uuid) to service_role;

create or replace function public.buy_reward_item(p_user uuid,p_item text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare item public.reward_catalog; charge bigint;
begin
  -- One wallet lock: simultaneous taps and retries serialize here, and the
  -- second one finds the item already owned and pays nothing.
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  select * into item from public.reward_catalog where code=p_item and active and released;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  if exists(select 1 from public.player_inventory where user_id=p_user and item_code=p_item) then
    return public.wallet_snapshot(p_user);
  end if;
  charge := public.catalog_charge(p_user,p_item);
  if charge > 0 then
    update public.wallet_accounts set balance=balance-charge,lifetime_spent=lifetime_spent+charge,
      updated_at=now() where user_id=p_user and balance>=charge;
    if not found then raise exception 'INSUFFICIENT_COINS'; end if;
    insert into public.wallet_ledger(user_id,kind,amount,item_code)
      values(p_user,'catalog_spend',-charge,p_item);
  end if;
  insert into public.player_inventory(user_id,item_code) values(p_user,p_item);
  if item.kind='bundle' then
    insert into public.player_inventory(user_id,item_code)
      select p_user, c from unnest(item.contents) c on conflict do nothing;
  end if;
  return public.wallet_snapshot(p_user);
end $$;
revoke all on function public.buy_reward_item(uuid,text) from public,anon,authenticated;
grant execute on function public.buy_reward_item(uuid,text) to service_role;

create or replace function public.equip_reward_item(p_user uuid,p_slot text,p_item text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_slot not in ('frame','nameplate','room_pack','narrator') then raise exception 'BAD_REQUEST'; end if;
  if p_item is null then
    delete from public.player_equipment where user_id=p_user and slot=p_slot;
    return public.wallet_snapshot(p_user);
  end if;
  if not exists(select 1 from public.reward_catalog c join public.player_inventory i
      on i.item_code=c.code and i.user_id=p_user where c.code=p_item and c.slot=p_slot) then
    raise exception 'ITEM_NOT_OWNED';
  end if;
  insert into public.player_equipment(user_id,slot,item_code) values(p_user,p_slot,p_item)
    on conflict(user_id,slot) do update set item_code=excluded.item_code, updated_at=now();
  return public.wallet_snapshot(p_user);
end $$;
revoke all on function public.equip_reward_item(uuid,text,text) from public,anon,authenticated;
grant execute on function public.equip_reward_item(uuid,text,text) to service_role;

create or replace function public.user_owns_item(p_user uuid,p_item text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.player_inventory where user_id=p_user and item_code=p_item)
$$;
revoke all on function public.user_owns_item(uuid,text) from public,anon,authenticated;
grant execute on function public.user_owns_item(uuid,text) to service_role;

-- 5. Seat cosmetics -------------------------------------------------------------
-- Copied from the player's equipment when they take a seat, so a room shows
-- what each player chose and nothing changes mid-match. Frame and nameplate
-- only; room-level packs live in the room's settings (host-owned, validated
-- by the room functions).
alter table public.room_players add column if not exists cosmetics jsonb not null default '{}';

create or replace function public.seat_cosmetics()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  new.cosmetics := coalesce((select jsonb_object_agg(slot,item_code)
    from public.player_equipment where user_id=new.user_id and slot in ('frame','nameplate')),'{}');
  return new;
end $$;
drop trigger if exists room_players_seat_cosmetics on public.room_players;
revoke all on function public.seat_cosmetics() from public,anon,authenticated;
create trigger room_players_seat_cosmetics before insert on public.room_players
  for each row execute function public.seat_cosmetics();

create or replace view public.room_players_public
with (security_invoker = true) as
select room_id, user_id, name, seat, alive, connected, last_seen, gender,
       saw_role, status, muted, kicked, cosmetics
from public.room_players;
grant select (cosmetics) on public.room_players to authenticated;
grant select on public.room_players_public to authenticated;

alter publication supabase_realtime drop table public.room_players;
alter publication supabase_realtime add table public.room_players
  (room_id, user_id, name, seat, alive, connected, last_seen, gender,
   saw_role, status, muted, kicked, cosmetics);

-- 6. Deletion covers equipment too.
create or replace function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests where id=p_request and completed_at is null for update;
  if who is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  if exists(select 1 from public.rooms r join public.room_players p on p.room_id=r.id
    where p.user_id=who and r.status<>'finished') then raise exception 'ACTIVE_ROOM'; end if;
  delete from public.player_equipment where user_id=who;
  delete from public.player_entitlements where user_id=who;
  update public.play_purchases set user_id=null where user_id=who;
  delete from public.ad_reward_claims where user_id=who;
  delete from public.rooms where id in (select room_id from public.room_players where user_id=who);
  delete from public.player_blocks where blocker_id=who or blocked_id=who;
  delete from public.player_inventory where user_id=who;
  delete from public.wallet_ledger where user_id=who;
  delete from public.wallet_accounts where user_id=who;
  delete from auth.users where id=who;
  update public.data_deletion_requests set completed_at=now() where id=p_request;
end $$;
revoke all on function public.complete_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;

create or replace function public.purge_orphan_economy()
returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare removed integer;
begin
  delete from public.player_equipment e where not exists(select 1 from auth.users u where u.id=e.user_id);
  delete from public.player_inventory i where not exists(select 1 from auth.users u where u.id=i.user_id);
  delete from public.wallet_ledger l where not exists(select 1 from auth.users u where u.id=l.user_id);
  with gone as (
    delete from public.wallet_accounts a where not exists(select 1 from auth.users u where u.id=a.user_id)
    returning 1
  ) select count(*) into removed from gone;
  return removed;
end $$;
revoke all on function public.purge_orphan_economy() from public,anon,authenticated;
grant execute on function public.purge_orphan_economy() to service_role;
