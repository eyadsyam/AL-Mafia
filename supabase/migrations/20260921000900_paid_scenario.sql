-- Non-consumable scenario entitlement. Purchase tokens are server-only and
-- verified against Google Play before an entitlement is granted. Restoring on
-- a new anonymous identity rebinds the same store purchase; it never duplicates
-- ownership or credits coins.
create table public.play_purchases (
  purchase_token text primary key,
  user_id uuid,
  product_id text not null,
  order_id text,
  state text not null check(state in ('active','pending','revoked')),
  purchased_at timestamptz,
  verified_at timestamptz not null default now()
);
create index play_purchases_user on public.play_purchases(user_id) where user_id is not null;
create table public.player_entitlements (
  user_id uuid not null,
  item_code text not null check(item_code in ('scenario_shadows')),
  purchase_token text not null references public.play_purchases(purchase_token) on delete cascade,
  acquired_at timestamptz not null default now(),
  primary key(user_id,item_code),
  unique(purchase_token,item_code)
);
alter table public.play_purchases enable row level security;
alter table public.player_entitlements enable row level security;
revoke all on public.play_purchases,public.player_entitlements from public,anon,authenticated;
grant all on public.play_purchases,public.player_entitlements to service_role;

create or replace function public.purchase_snapshot(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object('owned',coalesce(jsonb_agg(item_code order by item_code),'[]'::jsonb))
  from public.player_entitlements where user_id=p_user
$$;
revoke all on function public.purchase_snapshot(uuid) from public,anon,authenticated;
grant execute on function public.purchase_snapshot(uuid) to service_role;

create or replace function public.commit_play_purchase(
  p_user uuid,p_token text,p_product text,p_order text,p_state text,p_purchased_at timestamptz
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare old_user uuid;
begin
  if p_product<>'mafia_scenario_mastermind' or p_state not in ('active','pending','revoked')
    or length(p_token)<8 then raise exception 'INVALID_PURCHASE'; end if;
  perform pg_advisory_xact_lock(hashtextextended('purchase:'||p_token,97));
  select user_id into old_user from public.play_purchases where purchase_token=p_token for update;
  if old_user is not null and old_user<>p_user then
    delete from public.player_entitlements where purchase_token=p_token;
  end if;
  insert into public.play_purchases(purchase_token,user_id,product_id,order_id,state,purchased_at)
    values(p_token,p_user,p_product,p_order,p_state,p_purchased_at)
    on conflict(purchase_token) do update set user_id=excluded.user_id,product_id=excluded.product_id,
      order_id=excluded.order_id,state=excluded.state,purchased_at=excluded.purchased_at,verified_at=now();
  if p_state='active' then
    insert into public.player_entitlements(user_id,item_code,purchase_token)
      values(p_user,'scenario_shadows',p_token)
      on conflict(user_id,item_code) do update set purchase_token=excluded.purchase_token;
  else
    delete from public.player_entitlements where purchase_token=p_token;
  end if;
  return public.purchase_snapshot(p_user)||jsonb_build_object('state',p_state);
end $$;
revoke all on function public.commit_play_purchase(uuid,text,text,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.commit_play_purchase(uuid,text,text,text,text,timestamptz) to service_role;

create or replace function public.user_owns_entitlement(p_user uuid,p_item text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.player_entitlements where user_id=p_user and item_code=p_item)
$$;
revoke all on function public.user_owns_entitlement(uuid,text) from public,anon,authenticated;
grant execute on function public.user_owns_entitlement(uuid,text) to service_role;

create or replace function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests where id=p_request and completed_at is null for update;
  if who is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  if exists(select 1 from public.rooms r join public.room_players p on p.room_id=r.id
    where p.user_id=who and r.status<>'finished') then raise exception 'ACTIVE_ROOM'; end if;
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
