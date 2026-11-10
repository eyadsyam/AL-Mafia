-- play_release_watch has failed every ten minutes with SQLSTATE 21000: the
-- hosted database refuses an UPDATE without a WHERE clause, and
-- app_update_announce raised the build with a bare
-- `update public.app_config set ...;`. So a build Google approved never raised
-- latest_build_android and never queued its update notice. Same body,
-- each update scoped explicitly.
-- Applied to hosted 2026-11-10 with the owner's go: the next watch run raises
-- latest_build_android to the build live on Play and queues its notice.
do $$
declare
  body text := pg_get_functiondef('public.app_update_announce(integer)'::regprocedure);
  fixed text;
begin
  fixed := replace(body,
    'update public.app_config set latest_build_android = greatest(latest_build_android, p_build);',
    'update public.app_config set latest_build_android = greatest(latest_build_android, p_build) where true;');
  if fixed = body then
    raise exception 'app_update_announce: app_config update not found';
  end if;
  execute fixed;
end $$;
