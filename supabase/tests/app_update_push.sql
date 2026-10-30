-- Contract for 20261030005000_app_update_push. Rolled back.
begin;

create function pg_temp.au_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

do $$
declare
  old_phone uuid := pg_temp.au_user();
  new_phone uuid := pg_temp.au_user();
  web_only uuid := pg_temp.au_user();
  both_kinds uuid := pg_temp.au_user();
  result jsonb;
  claimed jsonb;
  row_tokens jsonb;
begin
  update public.economy_config set push_invites_enabled=true, friends_enabled=true;
  perform public.push_token_register(old_phone,repeat('a',40),'android');
  perform public.push_token_register(new_phone,repeat('b',40),'android',25);
  perform public.push_token_register(web_only,repeat('c',40),'web');
  perform public.push_token_register(both_kinds,repeat('d',40),'android',19);
  perform public.push_token_register(both_kinds,repeat('e',40),'web');

  -- A build number outside the range is refused; a later register without one
  -- (an old client) keeps what the device last reported.
  begin perform public.push_token_register(old_phone,repeat('a',40),'android',0); assert false, 'build 0';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  perform public.push_token_register(new_phone,repeat('b',40),'android');
  assert (select app_build from public.push_tokens where token=repeat('b',40))=25;

  -- Build 19 was recorded when this shipped: no notice, prompt raised.
  assert (select latest_build_android from public.app_config)>=19;
  assert not (public.app_update_announce(19)->>'announced')::boolean;
  assert not exists(select 1 from public.push_outbox where kind='app_update');

  -- The approved build reaches the Android devices below it, nobody else.
  update public.app_config set latest_build_android=19;
  result := public.app_update_announce(20);
  assert (result->>'announced')::boolean, result::text;
  assert (result->>'users')::int=2, result::text;
  assert (select latest_build_android from public.app_config)=20;
  assert (select count(*) from public.push_outbox where kind='app_update')=2;
  assert not exists(select 1 from public.push_outbox where kind='app_update' and user_id in (new_phone,web_only));
  assert (select users from public.app_release_notices where build=20)=2;

  -- Once per build, and never for an older one.
  assert not (public.app_update_announce(20)->>'announced')::boolean;
  assert not (public.app_update_announce(18)->>'announced')::boolean;
  assert (select count(*) from public.push_outbox where kind='app_update')=2;
  assert (select latest_build_android from public.app_config)=20;

  -- The claim hands over Android tokens only.
  claimed := public.push_outbox_claim(100);
  assert jsonb_array_length(claimed)=2, claimed::text;
  select r->'tokens' into row_tokens from jsonb_array_elements(claimed) r
   where (select user_id from public.push_outbox o where o.id=(r->>'id')::bigint)=both_kinds;
  assert jsonb_array_length(row_tokens)=1 and row_tokens->0->>'platform'='android', row_tokens::text;

  assert row_tokens->0->>'build'='19', row_tokens::text;

  -- A device updated between the announcement and the send is skipped.
  perform public.app_update_announce(21);
  perform public.push_token_register(old_phone,repeat('a',40),'android',21);
  claimed := public.push_outbox_claim(100);
  select r->'tokens' into row_tokens from jsonb_array_elements(claimed) r
   where (select user_id from public.push_outbox o where o.id=(r->>'id')::bigint)=old_phone;
  assert jsonb_array_length(row_tokens)=0, row_tokens::text;

  -- Push switched off: the build is still recorded and the prompt raised.
  update public.economy_config set push_invites_enabled=false;
  result := public.app_update_announce(22);
  assert (result->>'users')::int=0, result::text;
  assert (select latest_build_android from public.app_config)=22;

  -- Nobody but the server may call it.
  assert not has_function_privilege('authenticated','public.app_update_announce(integer)','execute');
  assert not has_function_privilege('anon','public.app_update_announce(integer)','execute');
  assert not has_function_privilege('authenticated','public.push_token_register(uuid,text,text,integer)','execute');
  assert has_function_privilege('service_role','public.app_update_announce(integer)','execute');
end $$;

rollback;
