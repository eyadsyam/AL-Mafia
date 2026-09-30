-- Contract for 20260930001200_min_app_build. Rolled back by the harness.
begin;
do $$
declare failed text; a int; w int; n int;
begin
  -- Default: no minimum on either platform, so no existing build is blocked.
  select min_build_android,min_build_web into a,w from public.app_config;
  assert a=0 and w=0,'default blocks nothing';

  -- The operator raises one number; the other is untouched.
  update public.app_config set min_build_android=11;
  select min_build_android,min_build_web into a,w from public.app_config;
  assert a=11 and w=0;
  update public.app_config set min_build_web=12;
  select min_build_android,min_build_web into a,w from public.app_config;
  assert a=11 and w=12;

  -- Nonsense is refused by the table, and there is only ever one row.
  begin update public.app_config set min_build_android=-1; failed:=null;
  exception when check_violation then failed:='check'; end;
  assert failed='check','a negative minimum is refused';
  begin insert into public.app_config(singleton) values(false); failed:=null;
  exception when check_violation then failed:='check'; end;
  assert failed='check','the singleton check holds';
  begin insert into public.app_config default values; failed:=null;
  exception when unique_violation then failed:='unique'; end;
  assert failed='unique','one row only';

  -- Any signed-in client may read it (the anonymous session counts), and
  -- nobody but the service role may change it. The bare key reads nothing.
  assert has_table_privilege('anon','public.app_config','select'),
    'the bare key reads the public config (20261001000100)';
  assert has_table_privilege('authenticated','public.app_config','select');
  assert not has_table_privilege('anon','public.app_config','insert');
  assert not has_table_privilege('anon','public.app_config','delete');
  set local role anon;
  select count(*),max(min_build_web) into n,w from public.app_config;
  reset role;
  assert n=1 and w=12,'the bare key reads the row';
  assert not has_table_privilege('anon','public.app_config','update');
  assert not has_table_privilege('authenticated','public.app_config','update');
  assert not has_table_privilege('authenticated','public.app_config','insert');
  set local role authenticated;
  select count(*),max(min_build_web) into n,w from public.app_config;
  reset role;
  assert n=1 and w=12,'a signed-in client reads the row';
  -- And it does not open the economy's private configuration.
  assert not has_table_privilege('anon','public.economy_config','select');
end $$;
rollback;
