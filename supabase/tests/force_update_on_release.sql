-- 20261119001200: the minimum build follows Play, never the upload.
begin;
do $$
declare c public.app_config;
begin
  update public.app_config set min_build_android = 22, latest_build_android = 22,
    pending_min_build_android = 23 where true;
  select * into c from public.app_config;
  assert c.min_build_android = 22 and c.pending_min_build_android = 23, 'nothing moves at upload';
  -- Play still serves 22: an unrelated update leaves the pending value alone.
  update public.app_config set latest_build_android = 22 where true;
  select * into c from public.app_config;
  assert c.min_build_android = 22 and c.pending_min_build_android = 23, 'still waiting';
  -- Play publishes 23.
  update public.app_config set latest_build_android = 23 where true;
  select * into c from public.app_config;
  assert c.min_build_android = 23, 'forced once live: '||c.min_build_android;
  assert c.pending_min_build_android is null, 'pending cleared';
  -- A lower pending never lowers the minimum.
  update public.app_config set pending_min_build_android = 5, latest_build_android = 24 where true;
  select * into c from public.app_config;
  assert c.min_build_android = 23, 'never lowered';
  raise notice 'force_update_on_release PASS';
end $$;
rollback;
