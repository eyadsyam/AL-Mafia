-- Launch audit A3: the Founder badge is granted only inside a window that
-- starts at `economy_config.founder_window_start`, and nothing ever set it:
-- no operator function, no migration. With `founder_enabled` on and the
-- start still null, `fun_on('founder')` is false, so the badge the flag
-- promises was never granted to anyone.
--
-- Idempotent: opens the window now only where the flag is already on and no
-- window was ever set. A window that was set (running or over) is left as is,
-- and a switched-off flag stays off.
create or replace function public.founder_window_open()
returns timestamptz language plpgsql security definer set search_path=public,pg_temp as $$
declare opened timestamptz;
begin
  update public.economy_config
     set founder_window_start = clock_timestamp()
   where founder_enabled and founder_window_start is null
  returning founder_window_start into opened;
  return opened;
end $$;
revoke all on function public.founder_window_open() from public,anon,authenticated;
grant execute on function public.founder_window_open() to service_role;

select public.founder_window_open();
