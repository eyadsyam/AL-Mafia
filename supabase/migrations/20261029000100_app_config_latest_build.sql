-- Update 1.5 (WP1): the newest build per platform, and one switch for where the
-- ad banner lives.
--
--   update public.app_config set latest_build_android = 18;  -- newest Play build
--   update public.app_config set latest_build_web = 18;      -- newest web build
--
-- A build below `min_build_*` is stopped by the blocking update screen (see
-- 20260930001200). A build at or above the minimum but below `latest_build_*`
-- gets the soft «فيه نسخة جديدة» sheet on the Home screen, once per launch,
-- with «بعدين». 0 means "no newer build announced" and is the default, so
-- nothing here prompts any build that exists today (the minimum is untouched).
--
-- `banner_mode` is read by builds that know it (per_screen: each screen draws
-- its own banner, shell: one banner owned by the app shell). Old builds ignore
-- the column; they ask only for the two minimum columns.
--
-- Same one-row table, same grants and policies as before: `anon` and
-- `authenticated` keep select (20261001000100); nobody but the service role may
-- write. Public config only: nothing here is private, nothing about the
-- economy. Idempotent.

alter table public.app_config
  add column if not exists latest_build_android integer not null default 0
    check (latest_build_android between 0 and 100000),
  add column if not exists latest_build_web integer not null default 0
    check (latest_build_web between 0 and 100000),
  add column if not exists banner_mode text not null default 'per_screen'
    check (banner_mode in ('per_screen', 'shell'));
