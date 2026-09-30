-- Contract for 20260930001200_min_app_build. Rolled back by the harness.
begin;
do $$
declare r jsonb; failed text;
begin
  -- Default: no minimum on either platform, so no existing build is blocked.
  r:=public.app_min_build();
  assert r='{"android": 0, "web": 0}'::jsonb,r::text;

  -- The operator raises one number; the other is untouched.
  update public.economy_config set min_build_android=11;
  r:=public.app_min_build();
  assert r='{"android": 11, "web": 0}'::jsonb,r::text;
  update public.economy_config set min_build_web=12;
  r:=public.app_min_build();
  assert r='{"android": 11, "web": 12}'::jsonb,r::text;

  -- Nonsense is refused by the table.
  begin update public.economy_config set min_build_android=-1; failed:=null;
  exception when check_violation then failed:='check'; end;
  assert failed='check','a negative minimum is refused';

  -- Anyone with the publishable key may ask, and gets nothing but the numbers.
  assert has_function_privilege('anon','public.app_min_build()','execute');
  assert has_function_privilege('authenticated','public.app_min_build()','execute');
  assert not has_table_privilege('anon','public.economy_config','select'),
    'the config itself stays private';
  set local role anon;
  r:=public.app_min_build();
  reset role;
  assert r->>'web'='12',r::text;

  -- An empty config table reads as no minimum, never as an error.
  delete from public.economy_config;
  assert public.app_min_build()='{"android": 0, "web": 0}'::jsonb;
end $$;
rollback;
