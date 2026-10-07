-- Local/disposable database only; always roll back fixtures.
begin;
insert into public.economy_config(id) values(true) on conflict do nothing;
update public.economy_config set
  transfer_enabled_android=true, transfer_enabled_web=true,
  transfer_android_direct_approved=false;

do $$ begin
  assert not public.transfer_enabled('android'), 'legacy switch bypasses direct approval';
  assert public.transfer_enabled('web'), 'web transfers changed';
  assert not public.transfer_enabled('ios'), 'unsupported native platform enabled';
  assert not public.transfer_enabled(null), 'unknown platform enabled';
end $$;

update public.economy_config set transfer_android_direct_approved=true;
do $$ begin
  assert public.transfer_enabled('android'), 'approved direct channel remains disabled';
  assert public.transfer_enabled('web'), 'Android approval affects web';
end $$;

update public.economy_config set transfer_enabled_android=false;
do $$ begin
  assert not public.transfer_enabled('android'), 'approval bypasses Android kill switch';
end $$;

update public.economy_config set transfer_enabled_web=false;
do $$ begin
  assert not public.transfer_enabled('web'), 'web kill switch ignored';
  assert not has_function_privilege('anon', 'public.transfer_enabled(text)', 'execute'),
    'anonymous can invoke operational gate';
  assert not has_function_privilege('authenticated', 'public.transfer_enabled(text)', 'execute'),
    'client can invoke operational gate';
  assert has_function_privilege('service_role', 'public.transfer_enabled(text)', 'execute'),
    'service role cannot evaluate gate';
end $$;
rollback;
