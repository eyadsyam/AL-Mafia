-- P7 creator entitlement contract. Rolled back by the SQL harness.
begin;
do $$
declare
  admin uuid:=gen_random_uuid(); creator uuid:=gen_random_uuid();
  viewer uuid:=gen_random_uuid(); expired_user uuid:=gen_random_uuid();
  grant_request uuid:=gen_random_uuid(); revoke_request uuid:=gen_random_uuid();
  result jsonb; entitlement uuid; blocked boolean:=false;
begin
  insert into public.commerce_admins(user_id) values(admin);

  assert not public.creator_ad_free(creator), 'creator defaults ad-supported';
  assert public.economy_capabilities(creator)->'creator'='false'::jsonb,
    'capabilities creator default is not false';

  result:=public.operator_creator_entitlement_grant(admin,creator,'launch-partner',
    now()-interval '1 minute',now()+interval '1 day',grant_request);
  entitlement:=(result->>'entitlementId')::uuid;
  assert result->>'status'='active' and public.creator_ad_free(creator), result::text;
  assert not public.creator_ad_free(viewer), 'creator relief transferred to another user';
  assert public.economy_capabilities(creator)->'creator'='true'::jsonb,
    'active creator missing from capabilities';

  result:=public.operator_creator_entitlement_grant(admin,creator,'changed-on-replay',
    now(),null,grant_request);
  assert (result->>'replayed')::boolean, result::text;
  assert (select count(*) from public.creator_entitlements where user_id=creator)=1,
    'grant replay inserted another entitlement';
  assert (select campaign from public.creator_entitlements where id=entitlement)='launch-partner',
    'grant replay changed the original';

  begin
    perform public.operator_creator_entitlement_grant(admin,creator,'second-active',
      now(),null,gen_random_uuid());
  exception when unique_violation then blocked:=true;
  end;
  assert blocked, 'two active entitlements were accepted';

  insert into public.creator_entitlements(user_id,campaign,starts_at,ends_at,granted_by)
    values(expired_user,'expired',now()-interval '2 days',now()-interval '1 day',admin);
  assert not public.creator_ad_free(expired_user), 'expired entitlement disabled ads';

  blocked:=false;
  begin
    perform public.operator_creator_entitlement_grant(viewer,viewer,'not-admin',now(),null,
      gen_random_uuid());
  exception when others then blocked:=sqlerrm like '%NOT_ADMIN%';
  end;
  assert blocked, 'non-admin grant was accepted';

  result:=public.operator_creator_entitlement_revoke(admin,creator,'campaign ended',revoke_request);
  assert result->>'status'='revoked' and not public.creator_ad_free(creator), result::text;
  result:=public.operator_creator_entitlement_revoke(admin,creator,'different replay reason',revoke_request);
  assert (result->>'replayed')::boolean, result::text;
  assert (select count(*) from public.creator_entitlement_audit where entitlement_id=entitlement)=2,
    'grant/revoke audit is incomplete or replayed';
  assert (select string_agg(action,',' order by id) from public.creator_entitlement_audit
    where entitlement_id=entitlement)='grant,revoke', 'unexpected audit actions';

  assert not has_function_privilege('public',
    'public.creator_ad_free(uuid)','execute');
  assert not has_function_privilege('anon',
    'public.operator_creator_entitlement_grant(uuid,uuid,text,timestamptz,timestamptz,uuid)','execute');
  assert not has_function_privilege('authenticated',
    'public.operator_creator_entitlement_revoke(uuid,uuid,text,uuid)','execute');
  assert has_function_privilege('service_role',
    'public.creator_ad_free(uuid)','execute');
  assert has_function_privilege('service_role',
    'public.operator_creator_entitlement_grant(uuid,uuid,text,timestamptz,timestamptz,uuid)','execute');
  assert has_function_privilege('service_role',
    'public.operator_creator_entitlement_revoke(uuid,uuid,text,uuid)','execute');
end $$;
rollback;
