-- `public.rls_auto_enable()` — a platform object, in our exposed schema.
--
-- Supabase installs this itself: an event-trigger function that turns RLS on
-- for any table created in `public`, so a forgotten `enable row level
-- security` cannot quietly ship a readable table. It is a good thing to have
-- and this migration does not remove it.
--
-- What it removes is the REST route. Because it lives in `public` and carries
-- the default `execute` grant to `PUBLIC`, the linter reports it — correctly —
-- as a `security definer` function any anonymous caller can reach at
-- `/rest/v1/rpc/rls_auto_enable`. In practice Postgres refuses to run an event
-- trigger function outside an event trigger, so the reachable damage is an
-- error message; but "it happens to fail" is not the same as "it cannot be
-- called", and this is the one function in the schema whose whole job is to
-- keep somebody else's mistake from mattering.
--
-- Guarded on existence and wrapped, because it is not ours: a project where
-- the platform has not installed it, or has changed its ownership, must still
-- migrate cleanly.

do $$
begin
  if exists (
    select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'rls_auto_enable'
  ) then
    begin
      execute 'revoke all on function public.rls_auto_enable() from public, anon, authenticated';
    exception when insufficient_privilege then
      raise notice 'rls_auto_enable is owned by the platform here; grant left as found';
    end;
  end if;
end
$$;
