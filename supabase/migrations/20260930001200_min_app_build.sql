-- Server-driven minimum app build: «حدّث التطبيق».
--
-- The operator raises a number when an old build must stop (a security fix, a
-- changed contract); the app compares it with its own build number on start and
-- shows a blocking update sheet. 0 means "no minimum", and that is the default,
-- so nothing here blocks any build that exists today.
--
--   update public.economy_config set min_build_android = 11;  -- Play build number
--   update public.economy_config set min_build_web = 11;      -- the web build's number
--
-- The app reads it through `app_min_build()`, callable with the publishable key
-- and no session, like `server_now()`: a build too old to sign in or to call the
-- capability negotiation must still be told to update. It returns two integers
-- and nothing else of the economy's configuration.

alter table public.economy_config
  add column if not exists min_build_android integer not null default 0
    check (min_build_android between 0 and 100000),
  add column if not exists min_build_web integer not null default 0
    check (min_build_web between 0 and 100000);

create or replace function public.app_min_build()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'android', coalesce((select min_build_android from public.economy_config limit 1), 0),
    'web', coalesce((select min_build_web from public.economy_config limit 1), 0));
$$;

revoke all on function public.app_min_build() from public;
grant execute on function public.app_min_build() to anon, authenticated, service_role;
