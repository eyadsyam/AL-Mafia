-- P7: owner-granted, account-bound creator relief from automatic ads.
create table public.creator_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  campaign text not null check (char_length(campaign) between 1 and 60),
  status text not null default 'active' check (status in ('active','revoked')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  granted_by uuid,
  revoked_reason text,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  check (ends_at is null or ends_at > starts_at)
);
create unique index creator_entitlements_one_active
  on public.creator_entitlements(user_id) where status='active';

create table public.creator_entitlement_audit (
  id bigint generated always as identity primary key,
  entitlement_id uuid not null references public.creator_entitlements(id),
  actor uuid,
  action text not null,
  created_at timestamptz not null default now()
);

create table public.creator_entitlement_receipts (
  admin_id uuid not null,
  request_id uuid not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (admin_id,request_id)
);

alter table public.creator_entitlements enable row level security;
alter table public.creator_entitlement_audit enable row level security;
alter table public.creator_entitlement_receipts enable row level security;
revoke all on table public.creator_entitlements,public.creator_entitlement_audit,
  public.creator_entitlement_receipts from public,anon,authenticated;
grant all on table public.creator_entitlements,public.creator_entitlement_audit,
  public.creator_entitlement_receipts to service_role;

create function public.creator_ad_free(p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(
    select 1 from public.creator_entitlements e
     where e.user_id=p_user and e.status='active' and e.starts_at<=now()
       and (e.ends_at is null or e.ends_at>now())
  )
$$;
revoke all on function public.creator_ad_free(uuid) from public,anon,authenticated;
grant execute on function public.creator_ad_free(uuid) to service_role;

create function public.operator_creator_entitlement_grant(
  p_admin uuid,p_creator uuid,p_campaign text,p_starts timestamptz,
  p_ends timestamptz,p_request uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare done jsonb; entitlement uuid;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_creator is null or p_request is null or p_starts is null
     or char_length(coalesce(p_campaign,'')) not between 1 and 60
     or (p_ends is not null and p_ends<=p_starts) then
    raise exception 'BAD_REQUEST';
  end if;
  select result into done from public.creator_entitlement_receipts
   where admin_id=p_admin and request_id=p_request;
  if done is not null then return done||jsonb_build_object('replayed',true); end if;

  insert into public.creator_entitlements(user_id,campaign,starts_at,ends_at,granted_by)
    values(p_creator,p_campaign,p_starts,p_ends,p_admin) returning id into entitlement;
  insert into public.creator_entitlement_audit(entitlement_id,actor,action)
    values(entitlement,p_admin,'grant');
  done:=jsonb_build_object('entitlementId',entitlement,'creatorId',p_creator,
    'campaign',p_campaign,'status','active','startsAt',p_starts,'endsAt',p_ends);
  insert into public.creator_entitlement_receipts(admin_id,request_id,result)
    values(p_admin,p_request,done);
  return done;
end $$;
revoke all on function public.operator_creator_entitlement_grant(uuid,uuid,text,timestamptz,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.operator_creator_entitlement_grant(uuid,uuid,text,timestamptz,timestamptz,uuid) to service_role;

create function public.operator_creator_entitlement_revoke(
  p_admin uuid,p_creator uuid,p_reason text,p_request uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare done jsonb; entitlement uuid;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_creator is null or p_request is null
     or char_length(btrim(coalesce(p_reason,''))) not between 1 and 500 then
    raise exception 'BAD_REQUEST';
  end if;
  select result into done from public.creator_entitlement_receipts
   where admin_id=p_admin and request_id=p_request;
  if done is not null then return done||jsonb_build_object('replayed',true); end if;

  select id into entitlement from public.creator_entitlements
   where user_id=p_creator and status='active' for update;
  if entitlement is null then raise exception 'BAD_REQUEST'; end if;
  update public.creator_entitlements set status='revoked',revoked_reason=btrim(p_reason),
    revoked_at=now() where id=entitlement;
  insert into public.creator_entitlement_audit(entitlement_id,actor,action)
    values(entitlement,p_admin,'revoke');
  done:=jsonb_build_object('entitlementId',entitlement,'creatorId',p_creator,
    'status','revoked');
  insert into public.creator_entitlement_receipts(admin_id,request_id,result)
    values(p_admin,p_request,done);
  return done;
end $$;
revoke all on function public.operator_creator_entitlement_revoke(uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.operator_creator_entitlement_revoke(uuid,uuid,text,uuid) to service_role;

alter function public.economy_capabilities(uuid)
  rename to economy_capabilities_pre_creator;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.economy_capabilities_pre_creator(p_user);
  return base||jsonb_build_object('creator',public.creator_ad_free(p_user));
end $$;
revoke all on function public.economy_capabilities_pre_creator(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_creator(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
