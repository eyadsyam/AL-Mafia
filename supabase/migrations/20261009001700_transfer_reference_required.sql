-- Review 2026-10-09: approving a transfer fell back to the proof image's hash
-- as the transfer id, and a re-saved screenshot has a new hash, so one real
-- transfer could be approved on two orders. The admin now has to enter the
-- payment app's own transaction reference; the unique index on
-- provider_transaction then refuses it on a second order (TRANSFER_ALREADY_USED).
create or replace function public.admin_approve_coin_order(p_admin uuid, p_order uuid,
  p_transaction text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.coin_orders; ref text := btrim(coalesce(p_transaction,''));
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  select * into o from public.coin_orders where id=p_order;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if o.proof_sha256 is null then raise exception 'PROOF_REQUIRED'; end if;
  if char_length(ref) < 4 or ref like 'proof:%' then raise exception 'TRANSACTION_REQUIRED'; end if;
  return public.admin_review_coin_order(p_admin, p_order, 'approve', ref, o.amount_piastres, null);
end $$;
revoke all on function public.admin_approve_coin_order(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_approve_coin_order(uuid,uuid,text) to service_role;
