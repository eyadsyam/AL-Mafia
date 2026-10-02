-- Play purchase integrity, ahead of any paid product going live.
--
-- 1. Refunds and chargebacks are revoked by the server itself. A refunded
--    player has no reason to send their token again, so revocation cannot
--    wait for the client: `play_voided_sync` (edge function, run on a
--    schedule) reads Google Play's Voided Purchases API and calls
--    `revoke_voided_play_purchases`. The checkpoint lives in play_sync_state.
-- 2. Restoring onto a new anonymous identity still moves the entitlement (a
--    reinstall must not lose a purchase), but a single token may move at most
--    three times in thirty days, so a shared token cannot be passed around a
--    group to unlock it for everyone in turn.
alter table public.play_purchases
  add column if not exists rebind_count int not null default 0,
  add column if not exists last_rebound_at timestamptz;

create table if not exists public.play_sync_state (
  id text primary key,
  voided_since_ms bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.play_sync_state enable row level security;
revoke all on public.play_sync_state from public,anon,authenticated;
grant all on public.play_sync_state to service_role;

create or replace function public.commit_play_purchase(
  p_user uuid,p_token text,p_product text,p_order text,p_state text,p_purchased_at timestamptz
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare existing public.play_purchases; moves int := 0;
begin
  if p_product<>'mafia_scenario_mastermind' or p_state not in ('active','pending','revoked')
    or length(p_token)<8 then raise exception 'INVALID_PURCHASE'; end if;
  perform pg_advisory_xact_lock(hashtextextended('purchase:'||p_token,97));
  select * into existing from public.play_purchases where purchase_token=p_token for update;
  if existing.purchase_token is not null then
    moves := case when existing.last_rebound_at > now()-interval '30 days'
      then existing.rebind_count else 0 end;
  end if;
  if existing.user_id is not null and existing.user_id<>p_user then
    if moves >= 3 then raise exception 'REBIND_LIMIT'; end if;
    delete from public.player_entitlements where purchase_token=p_token;
    moves := moves + 1;
  end if;
  insert into public.play_purchases(purchase_token,user_id,product_id,order_id,state,purchased_at)
    values(p_token,p_user,p_product,p_order,p_state,p_purchased_at)
    on conflict(purchase_token) do update set user_id=excluded.user_id,product_id=excluded.product_id,
      order_id=excluded.order_id,state=excluded.state,purchased_at=excluded.purchased_at,verified_at=now(),
      rebind_count=moves,
      last_rebound_at=case when existing.user_id is not null and existing.user_id<>p_user
        then now() else play_purchases.last_rebound_at end;
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

-- Revokes by purchase token (Google's voided list carries the token and the
-- order id; either is enough). Idempotent. Returns how many rows changed.
create or replace function public.revoke_voided_play_purchases(
  p_tokens text[], p_orders text[]
) returns int language plpgsql security definer set search_path=public,pg_temp as $$
declare changed int;
begin
  with hit as (
    update public.play_purchases set state='revoked', verified_at=now()
    where state<>'revoked'
      and (purchase_token=any(coalesce(p_tokens,'{}')) or order_id=any(coalesce(p_orders,'{}')))
    returning purchase_token
  ), gone as (
    delete from public.player_entitlements e using hit
    where e.purchase_token=hit.purchase_token returning 1
  )
  select count(*) into changed from hit;
  return changed;
end $$;
revoke all on function public.revoke_voided_play_purchases(text[],text[]) from public,anon,authenticated;
grant execute on function public.revoke_voided_play_purchases(text[],text[]) to service_role;
