-- Contract for 20261030000200_owner_push. Rolled back.
begin;

create function pg_temp.op_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

do $$
declare
  owner uuid := pg_temp.op_user();
  player uuid := pg_temp.op_user();
  quiet_admin uuid := pg_temp.op_user();
  rep uuid;
  claimed jsonb;
begin
  update public.economy_config set push_invites_enabled=true, friends_enabled=true;
  insert into public.commerce_admins(user_id,note) values(owner,'owner'),(quiet_admin,'no device');
  perform public.push_token_register(owner,repeat('o',40),'android');
  perform public.push_token_register(player,repeat('p',40),'android');

  -- A report reaches the admin with a device, and nobody else.
  insert into public.safety_reports(reporter_id,target_id,reason)
    values(player,owner,'spam') returning id into rep;
  assert (select count(*) from public.push_outbox where kind='owner_report')=1;
  assert (select user_id from public.push_outbox where kind='owner_report')=owner;
  assert not exists(select 1 from public.push_outbox where user_id in (player,quiet_admin));
  -- It carries no detail of the report.
  assert (select payload from public.push_outbox where kind='owner_report')='{}'::jsonb;

  -- A tester request is one notice; the same event twice is still one.
  insert into public.tester_signups(name,email,source) values('سارة','sara@example.com','beta');
  assert (select count(*) from public.push_outbox where kind='owner_tester')=1;
  perform public.push_owner('owner_tester','tester:x');
  perform public.push_owner('owner_tester','tester:x');
  assert (select count(*) from public.push_outbox where kind='owner_tester')=2;

  -- The claim hands the owner's notices out at once, with the owner's device.
  claimed := public.push_outbox_claim(100);
  assert jsonb_array_length(claimed)=3, claimed::text;
  assert claimed->0->'tokens'->0->>'token'=repeat('o',40), claimed::text;

  -- Push switched off: nothing is queued.
  update public.economy_config set push_invites_enabled=false;
  perform public.push_owner('owner_play','play:off');
  assert not exists(select 1 from public.push_outbox where kind='owner_play');

  -- A kind outside the list is refused by the table, and push_owner swallows
  -- it rather than breaking the row that caused it.
  update public.economy_config set push_invites_enabled=true;
  assert public.push_owner('owner_nonsense','x')=0;

  -- Nobody but the database may call it.
  assert not has_function_privilege('authenticated','public.push_owner(text,text)','execute');
  assert not has_function_privilege('anon','public.push_owner(text,text)','execute');
end $$;

rollback;
