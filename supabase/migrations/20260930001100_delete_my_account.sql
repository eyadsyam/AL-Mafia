-- In-app account deletion (Google Play's account-deletion requirement).
--
-- Until now deletion was a *request*: the player filed it, the operator
-- reviewed it, and `complete_data_deletion` ran by hand. This adds the
-- self-serve path: the player confirms inside the app, the `delete_account`
-- Edge Function calls `delete_my_account(p_user)` with the id from the JWT, and
-- the same `complete_data_deletion` chain the operator uses does the work, so
-- there is one definition of "everything of theirs".
--
-- Two things change on the chain:
--
--  1. It is wrapped once more to sweep the per-player tables added after the
--     last wrapper (friends, directory, push tokens, Council, Casebook,
--     referrals, season rows…). The sweep is read from the catalog, so a table
--     added later that follows the naming convention is covered too. What is
--     deliberately kept: abuse evidence (safety reports, whisper reports,
--     audit logs, admin receipts), accounting rows (orders and Play purchases
--     are already detached from the person by the chain, never deleted) and the
--     deletion request itself, which `purge_resolved_safety` removes later.
--  2. `delete_my_account` refuses while the player is in an unfinished room or
--     has a payment under review. Both are the chain's own refusals
--     (`ACTIVE_ROOM`, `ORDER_UNDER_REVIEW`); the function only lets them out.

alter function public.complete_data_deletion(uuid)
  rename to complete_data_deletion_pre_account;

create function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare
  who uuid;
  target record;
begin
  select user_id into who from public.data_deletion_requests
   where id=p_request and completed_at is null;
  perform public.complete_data_deletion_pre_account(p_request);
  if who is null then return; end if;
  for target in
    select c.table_name::text as tbl, c.column_name::text as col
      from information_schema.columns c
      join information_schema.tables t
        on t.table_schema=c.table_schema and t.table_name=c.table_name
     where c.table_schema='public'
       and t.table_type='BASE TABLE'
       and c.data_type='uuid'
       and c.column_name in ('user_id','blocker_id','blocked_id','from_user',
                             'to_user','inviter','invitee','user_lo','user_hi')
       and c.table_name not in (
         'data_deletion_requests',
         'safety_reports','whisper_reports','safety_audit','safety_audit_monthly',
         'safety_admin_receipts','operator_audit_log',
         'coin_orders','coin_order_events','play_purchases','ad_ssv_transactions',
         'commerce_admins','creator_entitlement_audit',
         'rooms','room_players','night_actions')
     order by 1, 2
  loop
    execute format('delete from public.%I where %I = $1', target.tbl, target.col)
      using who;
  end loop;
  -- The order trail keeps its rows (accounting) but no longer names the person.
  update public.coin_order_events set actor_id=null where actor_id=who;
end $$;

revoke all on function public.complete_data_deletion_pre_account(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion_pre_account(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;

-- The self-serve entry. The id is the caller's own (the Edge Function takes it
-- from the verified JWT), so there is nobody else's account to name.
create function public.delete_my_account(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare receipt uuid;
begin
  if p_user is null then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 73));
  insert into public.data_deletion_requests(user_id) values(p_user)
    on conflict(user_id) do update set user_id=excluded.user_id
    returning id into receipt;
  perform public.complete_data_deletion(receipt);
  return jsonb_build_object('deleted', true);
end $$;

revoke all on function public.delete_my_account(uuid) from public,anon,authenticated;
grant execute on function public.delete_my_account(uuid) to service_role;
