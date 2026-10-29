-- Contract for 20261029000100_app_config_latest_build. Rolled back by the harness.
begin;
do $$
declare failed text; a int; w int; m text; n int; mb int;
begin
  -- Defaults: no newer build announced, banners per screen, minimum untouched.
  select latest_build_android,latest_build_web,banner_mode into a,w,m
    from public.app_config;
  assert a=0 and w=0,'default announces no newer build';
  assert m='per_screen','default banner mode is per_screen';
  select min_build_android into mb from public.app_config;
  assert mb=0,'the minimum is untouched';

  -- The operator moves each field on its own.
  update public.app_config set latest_build_android=18;
  select latest_build_android,latest_build_web into a,w from public.app_config;
  assert a=18 and w=0;
  update public.app_config set latest_build_web=19, banner_mode='shell';
  select latest_build_web,banner_mode into w,m from public.app_config;
  assert w=19 and m='shell';

  -- Nonsense is refused by the table.
  begin update public.app_config set latest_build_android=-1; failed:=null;
  exception when check_violation then failed:='check'; end;
  assert failed='check','a negative latest build is refused';
  begin update public.app_config set latest_build_web=100001; failed:=null;
  exception when check_violation then failed:='check'; end;
  assert failed='check','an absurd latest build is refused';
  begin update public.app_config set banner_mode='everywhere'; failed:=null;
  exception when check_violation then failed:='check'; end;
  assert failed='check','an unknown banner mode is refused';

  -- Reads and writes are exactly as before: the bare key and a signed-in client
  -- read the new columns, nobody but the service role writes.
  set local role anon;
  select count(*),max(latest_build_web) into n,w from public.app_config;
  select banner_mode into m from public.app_config;
  reset role;
  assert n=1 and w=19 and m='shell','the bare key reads the new columns';
  set local role authenticated;
  select max(latest_build_android) into a from public.app_config;
  reset role;
  assert a=18,'a signed-in client reads the new columns';
  assert not has_table_privilege('anon','public.app_config','update');
  assert not has_table_privilege('authenticated','public.app_config','update');
  assert not has_table_privilege('anon','public.economy_config','select');
end $$;
rollback;
