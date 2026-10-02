create or replace function public.purge_orphan_economy()
returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare removed integer;
begin
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

do $$ begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.unschedule('purge-orphan-economy') where exists(select 1 from cron.job where jobname='purge-orphan-economy');
    perform cron.schedule('purge-orphan-economy','37 4 * * *',$cron$select public.purge_orphan_economy();$cron$);
  end if;
end $$;

