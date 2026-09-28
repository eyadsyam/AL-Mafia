-- Row 9 core (spec §4 F10): titles and the core Partner, server layer.
--
-- Both are dark: `titles_enabled` and `partner_enabled` default OFF (Partner
-- also needs `character_bonds_enabled`, its dependency in §6). With a switch
-- off every read answers `{enabled:false}` and every write `DISABLED`.
--
-- Doc 05: a title is an account-level earned label and a Partner is a chosen
-- portrait; neither is derived from, or correlated with, a role in any match.
-- Titles are shown only on Profile, the Casebook, the pre-deal lobby plate and
-- the public result, so `room_titles` answers only for a room in the lobby or
-- finished, never while it is being played. The Partner is never read by any
-- room function at all.

alter table public.economy_config
  add column if not exists titles_enabled boolean not null default false,
  add column if not exists partner_enabled boolean not null default false;

create function public.titles_on() returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select titles_enabled from public.economy_config where id=true),false)
$$;
create function public.partner_on() returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select partner_enabled and character_bonds_enabled
    from public.economy_config where id=true),false)
$$;

-- 1. Titles --------------------------------------------------------------------
create table public.title_catalog(
  code text primary key check (code ~ '^[a-z0-9_]{3,60}$'),
  source text not null check (source in ('season','invite','achievement','chapter','founder','pass')),
  name_ar text not null check (char_length(name_ar) between 1 and 40),
  name_en text not null check (char_length(name_en) between 1 and 40),
  sort_order int not null default 0,
  active boolean not null default true
);
insert into public.title_catalog(code,source,name_ar,name_en,sort_order) values
  ('season_zero_night_scribe','season','كاتب الليل','Night Scribe',10),
  ('season_zero_casekeeper','season','حافظ القضايا','Casekeeper',20),
  ('kabir_elshella','invite','كبير الشلة','Head of the Gang',30)
on conflict(code) do nothing;

create table public.player_titles(
  user_id uuid not null,
  code text not null references public.title_catalog(code),
  source_key text not null check (char_length(source_key) between 3 and 120),
  granted_at timestamptz not null default now(),
  primary key(user_id,code)
);

create table public.player_showcase(
  user_id uuid primary key,
  equipped_title text references public.title_catalog(code),
  updated_at timestamptz not null default now()
);

-- One answer per mutation request, replayed on retry (F10 envelopes).
create table public.profile_request_receipts(
  user_id uuid not null,
  request_id uuid not null,
  action text not null check (action in ('titleEquip','partnerSet')),
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key(user_id,request_id)
);

-- 2. Partner --------------------------------------------------------------------
create table public.player_partner(
  user_id uuid primary key,
  side text not null check (side in ('detective','doctor','mafia','citizen')),
  updated_at timestamptz not null default now()
);

alter table public.title_catalog enable row level security;
alter table public.player_titles enable row level security;
alter table public.player_showcase enable row level security;
alter table public.profile_request_receipts enable row level security;
alter table public.player_partner enable row level security;
revoke all on public.title_catalog,public.player_titles,public.player_showcase,
  public.profile_request_receipts,public.player_partner from public,anon,authenticated;
grant all on public.title_catalog,public.player_titles,public.player_showcase,
  public.profile_request_receipts,public.player_partner to service_role;

-- 3. Granting ----------------------------------------------------------------------
-- Titles come from sources that are already exact-once: a claimed Season
-- level that carries a title, and the invite unlock. Re-running grants
-- nothing twice.
create function public.titles_sync(p_user uuid) returns int
language plpgsql security definer set search_path=public,pg_temp as $$
declare n int:=0; k int;
begin
  insert into public.player_titles(user_id,code,source_key)
    select p_user,r.title_code,'season:'||s.code||':'||c.level
      from public.season_reward_claims c
      join public.season_reward_catalog r on r.season_id=c.season_id and r.level=c.level
      join public.mission_seasons s on s.id=c.season_id
      join public.title_catalog t on t.code=r.title_code and t.active
     where c.user_id=p_user and r.title_code is not null
    on conflict do nothing;
  get diagnostics k=row_count; n:=n+k;
  if to_regclass('public.invite_unlocks') is not null then
    insert into public.player_titles(user_id,code,source_key)
      select p_user,'kabir_elshella','invite:3'
        from public.invite_unlocks u
       where u.user_id=p_user and u.code='title_kabir_elshella'
      on conflict do nothing;
    get diagnostics k=row_count; n:=n+k;
  end if;
  return n;
end $$;

create function public.title_hub(p_user uuid) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare equipped text;
begin
  if not public.titles_on() then return jsonb_build_object('enabled',false); end if;
  perform public.titles_sync(p_user);
  select equipped_title into equipped from public.player_showcase where user_id=p_user;
  return jsonb_build_object('enabled',true,'equipped',equipped,
    'titles',coalesce((select jsonb_agg(jsonb_build_object('code',t.code,'source',t.source,
        'nameAr',t.name_ar,'nameEn',t.name_en,'owned',pt.user_id is not null,
        'grantedAt',pt.granted_at) order by t.sort_order,t.code)
      from public.title_catalog t
      left join public.player_titles pt on pt.user_id=p_user and pt.code=t.code
      where t.active),'[]'::jsonb));
end $$;

create function public.title_equip(p_user uuid,p_code text,p_request uuid) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare kept jsonb; body jsonb;
begin
  if p_request is null then return jsonb_build_object('ok',false,'code','BAD_REQUEST'); end if;
  select response into kept from public.profile_request_receipts
   where user_id=p_user and request_id=p_request;
  if found then return kept; end if;
  if not public.titles_on() then
    return jsonb_build_object('ok',false,'requestId',p_request,'code','DISABLED');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('profile:'||p_user::text,95));
  select response into kept from public.profile_request_receipts
   where user_id=p_user and request_id=p_request;
  if found then return kept; end if;
  perform public.titles_sync(p_user);
  if p_code is not null and not exists(select 1 from public.player_titles pt
      join public.title_catalog t on t.code=pt.code and t.active
      where pt.user_id=p_user and pt.code=p_code) then
    return jsonb_build_object('ok',false,'requestId',p_request,'code','NOT_READY');
  end if;
  insert into public.player_showcase(user_id,equipped_title,updated_at)
    values(p_user,p_code,now())
    on conflict(user_id) do update set equipped_title=excluded.equipped_title,updated_at=now();
  body:=jsonb_build_object('ok',true,'requestId',p_request,
    'grant',jsonb_build_object('coins',0,'xp',0),'state',public.title_hub(p_user));
  insert into public.profile_request_receipts(user_id,request_id,action,response)
    values(p_user,p_request,'titleEquip',body);
  return body;
end $$;

-- The equipped titles of a room's seats, for the pre-deal lobby plate and the
-- public result only. While the room is being played the answer is empty for
-- everyone, so no live surface can draw one.
create function public.room_titles(p_user uuid,p_room uuid) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare room_status text;
begin
  if not public.titles_on() then return jsonb_build_object('enabled',false); end if;
  select r.status into room_status from public.rooms r
    join public.room_players me on me.room_id=r.id and me.user_id=p_user and not me.kicked
   where r.id=p_room;
  if room_status is null then raise exception 'NOT_MEMBER'; end if;
  if room_status='playing' then
    return jsonb_build_object('enabled',true,'seats','{}'::jsonb);
  end if;
  return jsonb_build_object('enabled',true,'seats',coalesce((
    select jsonb_object_agg(p.seat::text,jsonb_build_object('code',t.code,
        'nameAr',t.name_ar,'nameEn',t.name_en))
      from public.room_players p
      join public.player_showcase sc on sc.user_id=p.user_id
      join public.player_titles pt on pt.user_id=p.user_id and pt.code=sc.equipped_title
      join public.title_catalog t on t.code=pt.code and t.active
     where p.room_id=p_room and not p.kicked),'{}'::jsonb));
end $$;

-- 4. Partner reads and writes -----------------------------------------------------------
create function public.partner_get(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.partner_on() then return jsonb_build_object('enabled',false); end if;
  return jsonb_build_object('enabled',true,
    'side',(select side from public.player_partner where user_id=p_user));
end $$;

-- A free switch, any time outside a live match. Seated in a room that is
-- being played means "not now"; the answer never says which room or seat.
create function public.partner_set(p_user uuid,p_side text,p_request uuid) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare kept jsonb; body jsonb;
begin
  if p_request is null then return jsonb_build_object('ok',false,'code','BAD_REQUEST'); end if;
  select response into kept from public.profile_request_receipts
   where user_id=p_user and request_id=p_request;
  if found then return kept; end if;
  if not public.partner_on() then
    return jsonb_build_object('ok',false,'requestId',p_request,'code','DISABLED');
  end if;
  if p_side is null or p_side not in ('detective','doctor','mafia','citizen') then
    return jsonb_build_object('ok',false,'requestId',p_request,'code','BAD_REQUEST');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('profile:'||p_user::text,95));
  select response into kept from public.profile_request_receipts
   where user_id=p_user and request_id=p_request;
  if found then return kept; end if;
  if exists(select 1 from public.room_players p join public.rooms r on r.id=p.room_id
      where p.user_id=p_user and not p.kicked and r.status='playing'
        and p.status is distinct from 'left') then
    return jsonb_build_object('ok',false,'requestId',p_request,'code','IN_MATCH');
  end if;
  insert into public.player_partner(user_id,side,updated_at) values(p_user,p_side,now())
    on conflict(user_id) do update set side=excluded.side,updated_at=now();
  body:=jsonb_build_object('ok',true,'requestId',p_request,
    'grant',jsonb_build_object('coins',0,'xp',0),'state',public.partner_get(p_user));
  insert into public.profile_request_receipts(user_id,request_id,action,response)
    values(p_user,p_request,'partnerSet',body);
  return body;
end $$;

create function public.purge_profile_request_receipts() returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
begin
  delete from public.profile_request_receipts where created_at<now()-interval '7 days';
  get diagnostics n=row_count;
  return n;
end $$;

-- 5. Capability, deletion ----------------------------------------------------------------
alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_titles;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  return public.economy_capabilities_pre_titles(p_user)
    ||jsonb_build_object('titles',public.titles_on(),'partner',public.partner_on());
end $$;

alter function public.complete_data_deletion(uuid) rename to complete_data_deletion_pre_titles;
create function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests
   where id=p_request and completed_at is null;
  perform public.complete_data_deletion_pre_titles(p_request);
  if who is not null then
    delete from public.player_titles where user_id=who;
    delete from public.player_showcase where user_id=who;
    delete from public.player_partner where user_id=who;
    delete from public.profile_request_receipts where user_id=who;
  end if;
end $$;

-- 6. Grants -------------------------------------------------------------------------------
revoke all on function public.titles_on() from public,anon,authenticated;
grant execute on function public.titles_on() to service_role;
revoke all on function public.partner_on() from public,anon,authenticated;
grant execute on function public.partner_on() to service_role;
revoke all on function public.titles_sync(uuid) from public,anon,authenticated;
grant execute on function public.titles_sync(uuid) to service_role;
revoke all on function public.title_hub(uuid) from public,anon,authenticated;
grant execute on function public.title_hub(uuid) to service_role;
revoke all on function public.title_equip(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.title_equip(uuid,text,uuid) to service_role;
revoke all on function public.room_titles(uuid,uuid) from public,anon,authenticated;
grant execute on function public.room_titles(uuid,uuid) to service_role;
revoke all on function public.partner_get(uuid) from public,anon,authenticated;
grant execute on function public.partner_get(uuid) to service_role;
revoke all on function public.partner_set(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.partner_set(uuid,text,uuid) to service_role;
revoke all on function public.purge_profile_request_receipts() from public,anon,authenticated;
grant execute on function public.purge_profile_request_receipts() to service_role;
revoke all on function public.economy_capabilities_pre_titles(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_titles(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
revoke all on function public.complete_data_deletion_pre_titles(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion_pre_titles(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
