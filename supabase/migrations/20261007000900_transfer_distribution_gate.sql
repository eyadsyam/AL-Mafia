-- M01: Android manual transfers require separate operational approval.
-- Play clients never expose transfers. Direct clients require an explicit
-- build approval and this independent server gate plus the existing switch.
-- Client platform/channel strings are not proof of policy eligibility.
-- Keep web sales and existing order review/refund paths unchanged.
alter table public.economy_config
  add column if not exists transfer_android_direct_approved boolean not null default false;

create or replace function public.transfer_enabled(p_platform text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select case p_platform
      when 'android' then c.transfer_enabled_android and c.transfer_android_direct_approved
      when 'web' then c.transfer_enabled_web
      else false end
    from public.economy_config c limit 1), false)
$$;

revoke all on function public.transfer_enabled(text) from public, anon, authenticated;
grant execute on function public.transfer_enabled(text) to service_role;

comment on column public.economy_config.transfer_android_direct_approved is
  'Operator approval for direct-distribution Android transfers; default off. Not Play alternative-billing enrollment.';
