-- Server-driven minimum app build: «حدّث التطبيق».
--
-- The operator raises a number when an old build must stop (a security fix, a
-- changed contract); the app compares it with its own build number on start and
-- shows a blocking update sheet. 0 means "no minimum", and that is the default,
-- so nothing here blocks any build that exists today.
--
--   update public.app_config set min_build_android = 11;  -- Play build number
--   update public.app_config set min_build_web = 11;      -- the web build's number
--
-- It is a one-row table any signed-in client may read (every player has at
-- least the anonymous session), not a function: no security-definer function
-- may be callable by the client and no policy may be `to public` (see
-- `server_surface_test.dart`). Two integers and nothing else live here; the
-- economy's configuration stays private.

create table public.app_config (
  singleton boolean primary key default true check (singleton),
  min_build_android integer not null default 0
    check (min_build_android between 0 and 100000),
  min_build_web integer not null default 0
    check (min_build_web between 0 and 100000)
);
insert into public.app_config default values;

alter table public.app_config enable row level security;
revoke all on public.app_config from public, anon, authenticated;
grant select on public.app_config to authenticated;
grant all on public.app_config to service_role;
create policy app_config_read on public.app_config
  for select to authenticated using (true);
