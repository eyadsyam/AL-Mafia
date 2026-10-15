-- Account-scoped game ownership. No catalog, wallet, ad or receipt rows are minted.
create table public.all_access_grants (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reason text not null,
  granted_by text,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz
);
alter table public.all_access_grants enable row level security;
revoke all on table public.all_access_grants from public, anon, authenticated;
grant all on table public.all_access_grants to service_role;

-- The existing equipment FK requires inventory for an equipped item. Track
-- those rows so revocation removes only inventory created for this purpose.
create table public.all_access_materialized_items (
  user_id uuid not null,
  item_code text not null,
  primary key(user_id,item_code),
  foreign key(user_id,item_code) references public.player_inventory(user_id,item_code)
    on delete cascade
);
alter table public.all_access_materialized_items enable row level security;
revoke all on table public.all_access_materialized_items from public,anon,authenticated;
grant all on table public.all_access_materialized_items to service_role;

create function public.has_all_access(p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.all_access_grants
    where user_id=p_user and revoked_at is null)
$$;
revoke all on function public.has_all_access(uuid) from public,anon,authenticated;
grant execute on function public.has_all_access(uuid) to service_role;

create function public.my_entitlements()
returns jsonb language sql stable security definer set search_path=public,auth,pg_temp as $$
  select jsonb_build_object('allAccess',
    coalesce((select not u.is_anonymous and public.has_all_access(u.id)
      from auth.users u where u.id=auth.uid()),false))
$$;
revoke all on function public.my_entitlements() from public,anon,authenticated;
grant execute on function public.my_entitlements() to authenticated;

create function public.grant_all_access_by_email(p_email text,p_reason text)
returns uuid language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  if nullif(btrim(p_email),'') is null or nullif(btrim(p_reason),'') is null then
    raise exception 'BAD_REQUEST';
  end if;
  select id into who from auth.users
   where lower(email)=lower(btrim(p_email)) and email_confirmed_at is not null
     and coalesce(is_anonymous,false)=false;
  if who is null then raise exception 'ACCOUNT_NOT_ELIGIBLE'; end if;
  insert into public.all_access_grants(user_id,reason,granted_by)
    values(who,p_reason,'service_role')
    on conflict(user_id) do update set reason=excluded.reason,
      granted_by=excluded.granted_by, revoked_at=null;
  return who;
end $$;

revoke all on function public.grant_all_access_by_email(text,text) from public,anon,authenticated;
grant execute on function public.grant_all_access_by_email(text,text) to service_role;

create function public.revoke_all_access(p_user uuid,p_reason text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if nullif(btrim(p_reason),'') is null then raise exception 'BAD_REQUEST'; end if;
  update public.all_access_grants set revoked_at=now(),reason=p_reason where user_id=p_user;
  delete from public.player_inventory i using public.all_access_materialized_items m
    where i.user_id=p_user and m.user_id=i.user_id and m.item_code=i.item_code;
end $$;
revoke all on function public.revoke_all_access(uuid,text) from public,anon,authenticated;
grant execute on function public.revoke_all_access(uuid,text) to service_role;

create or replace function public.user_owns_item(p_user uuid,p_item text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select public.has_all_access(p_user) or exists(select 1 from public.player_inventory where user_id=p_user and item_code=p_item)
$$;

create or replace function public.user_owns_entitlement(p_user uuid,p_item text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select (p_item <> 'remove_interruptions' and public.has_all_access(p_user)) or exists(select 1 from public.player_entitlements where user_id=p_user and item_code=p_item)
$$;

create or replace function public.catalog_charge(p_user uuid, p_item text)
returns bigint language sql stable security definer set search_path=public,pg_temp as $$
  -- A bundle never charges for what the player already owns.
  select case when public.has_all_access(p_user) then 0 when c.kind <> 'bundle' then c.coin_price else greatest(0,
    c.coin_price - coalesce((select sum(x.coin_price) from public.reward_catalog x
      join public.player_inventory i on i.item_code=x.code and i.user_id=p_user
      where x.code = any(c.contents)),0)) end
  from public.reward_catalog c where c.code=p_item
$$;

create or replace function public.buy_reward_item(p_user uuid,p_item text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare item public.reward_catalog; charge bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  select * into item from public.reward_catalog where code=p_item and active and released;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  if public.has_all_access(p_user) or exists(select 1 from public.player_inventory where user_id=p_user and item_code=p_item) then
    return public.wallet_snapshot(p_user);
  end if;
  charge := public.catalog_charge(p_user,p_item);
  if charge > 0 then
    update public.wallet_accounts set balance=balance-charge,
      purchased_balance=greatest(0,purchased_balance-charge),
      lifetime_spent=lifetime_spent+charge, updated_at=now()
     where user_id=p_user and balance>=charge;
    if not found then raise exception 'INSUFFICIENT_COINS'; end if;
    insert into public.wallet_ledger(user_id,kind,amount,item_code)
      values(p_user,'catalog_spend',-charge,p_item);
  end if;
  insert into public.player_inventory(user_id,item_code) values(p_user,p_item);
  if item.kind='bundle' then
    insert into public.player_inventory(user_id,item_code)
      select p_user, c from unnest(item.contents) c on conflict do nothing;
  end if;
  return public.wallet_snapshot(p_user);
end $$;

create or replace function public.equip_reward_item(p_user uuid,p_slot text,p_item text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_slot not in ('frame','nameplate','room_pack','narrator') then raise exception 'BAD_REQUEST'; end if;
  if p_item is null then
    delete from public.player_equipment where user_id=p_user and slot=p_slot;
    return public.wallet_snapshot(p_user);
  end if;
  if not exists(select 1 from public.reward_catalog c where c.code=p_item and c.slot=p_slot
      and (public.has_all_access(p_user) or exists(select 1 from public.player_inventory i
        where i.user_id=p_user and i.item_code=c.code))) then
    raise exception 'ITEM_NOT_OWNED';
  end if;
  if public.has_all_access(p_user) and not exists(select 1 from public.player_inventory
      where user_id=p_user and item_code=p_item) then
    insert into public.player_inventory(user_id,item_code) values(p_user,p_item);
    insert into public.all_access_materialized_items(user_id,item_code) values(p_user,p_item);
  end if;
  insert into public.player_equipment(user_id,slot,item_code) values(p_user,p_slot,p_item)
    on conflict(user_id,slot) do update set item_code=excluded.item_code, updated_at=now();
  return public.wallet_snapshot(p_user);
end $$;

create or replace function public.wallet_snapshot(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare account public.wallet_accounts; items jsonb; owned jsonb; equipped jsonb; history jsonb;
begin
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  select * into account from public.wallet_accounts where user_id=p_user;
  select coalesce(jsonb_agg(jsonb_build_object(
      'code',code,'price',coin_price,'kind',kind,'slot',slot,'contents',to_jsonb(contents),
      'charge',public.catalog_charge(p_user,code)) order by sort_order,code),'[]')
    into items from public.reward_catalog where active and released;
  select coalesce(jsonb_agg(item_code order by item_code),'[]') into owned
    from (select item_code from public.player_inventory where user_id=p_user
      union select code from public.reward_catalog where public.has_all_access(p_user)
        and active and released) inventory;
  select coalesce(jsonb_object_agg(slot,item_code),'{}') into equipped
    from public.player_equipment where user_id=p_user;
  select coalesce(jsonb_agg(jsonb_build_object('kind',kind,'amount',amount,
      'item',item_code,'at',created_at) order by created_at desc),'[]')
    into history from (select * from public.wallet_ledger where user_id=p_user
      order by created_at desc limit 30) recent;
  return jsonb_build_object('balance',account.balance,'catalog',items,'owned',owned,
    'equipped',equipped,'history',history,
    'earned',account.lifetime_earned,'spent',account.lifetime_spent,
    'allAccess',public.has_all_access(p_user));
end $$;

create or replace function public.purchase_snapshot(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object('owned',coalesce(jsonb_agg(item_code order by item_code),'[]'::jsonb))
  from (select item_code from public.player_entitlements where user_id=p_user
    union select 'scenario_shadows' where public.has_all_access(p_user)) entitlements
$$;

create or replace function public.table_tools_snapshot(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object(
    'tools', coalesce((select jsonb_agg(jsonb_build_object(
        'code', t.code, 'tier', t.tier, 'price', t.coin_price,
        'packs', jsonb_build_object('1', public.tool_pack_price(t.coin_price,1),
                                    '3', public.tool_pack_price(t.coin_price,3),
                                    '7', public.tool_pack_price(t.coin_price,7)),
        'perMatch', t.per_match, 'phase', t.phase, 'targets', t.targets,
        'charges', case when public.has_all_access(p_user) then 1 else coalesce(c.charges,0) end) order by t.sort_order)
      from public.table_tools t
      left join public.player_tool_charges c on c.tool_code=t.code and c.user_id=p_user
      where t.active), '[]'::jsonb),
    'limits', jsonb_build_object('perMatch', 4, 'heavyPerMatch', 2),
    'balance', coalesce((select balance from public.wallet_accounts where user_id=p_user), 0))
$$;

create or replace function public.buy_table_tool(p_user uuid, p_tool text, p_pack int, p_request uuid default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.table_tools; charge bigint; fresh int;
begin
  if p_pack not in (1,3,7) then raise exception 'BAD_PACK'; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into t from public.table_tools where code=p_tool and active;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  if public.has_all_access(p_user) then return public.table_tools_snapshot(p_user); end if;
  if p_request is not null then
    insert into public.tool_purchase_requests(user_id,request_id,tool_code)
      values(p_user,p_request,p_tool) on conflict do nothing;
    get diagnostics fresh = row_count;
    if fresh = 0 then return public.table_tools_snapshot(p_user); end if;
  end if;
  charge := public.tool_pack_price(t.coin_price, p_pack);
  update public.wallet_accounts set balance=balance-charge,
    purchased_balance=greatest(0,purchased_balance-charge),
    lifetime_spent=lifetime_spent+charge, updated_at=now()
   where user_id=p_user and balance>=charge;
  if not found then raise exception 'INSUFFICIENT_COINS'; end if;
  insert into public.wallet_ledger(user_id,kind,amount,item_code)
    values(p_user,'tool_spend',-charge,p_tool);
  insert into public.player_tool_charges(user_id,tool_code,charges)
    values(p_user,p_tool,p_pack)
  on conflict (user_id,tool_code) do update
    set charges=player_tool_charges.charges+p_pack, updated_at=now();
  return public.table_tools_snapshot(p_user);
end $$;

create or replace function public.use_table_tool(
  p_user uuid, p_room uuid, p_tool text, p_targets int[], p_note text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  t public.table_tools;
  me public.room_players;
  st public.room_state;
  used_all int; used_heavy int; used_this int; living int; ans boolean;
  targets int[] := coalesce(p_targets,'{}');
begin
  perform pg_advisory_xact_lock(hashtextextended('tools:'||p_room::text||p_user::text,7));
  select * into t from public.table_tools where code=p_tool and active;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  -- Match transitions lock room then state. Hold the same locks before
  -- reading membership so a concurrent death/phase close cannot spend a tool.
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then raise exception 'NOT_PLAYING'; end if;
  select * into st from public.room_state where room_id=p_room for update;
  if not found then raise exception 'NOT_PLAYING'; end if;
  select * into me from public.room_players
   where room_id=p_room and user_id=p_user and not kicked;
  if not found then raise exception 'NOT_A_MEMBER'; end if;

  if t.phase='dead' then
    if me.alive then raise exception 'ALIVE'; end if;
  else
    if not me.alive then raise exception 'NOT_ALIVE'; end if;
    if t.phase='discuss' and st.phase not in ('discuss','opening','confront','defense','morning') then
      raise exception 'WRONG_PHASE';
    end if;
    if t.phase='vote' and st.phase not in ('vote','discuss','defense') then raise exception 'WRONG_PHASE'; end if;
    if t.phase='night' and st.phase <> 'night' then raise exception 'WRONG_PHASE'; end if;
  end if;

  if coalesce(array_length(targets,1),0) <> t.targets then raise exception 'BAD_TARGETS'; end if;
  if t.targets > 0 then
    select count(*) into living from public.room_players
     where room_id=p_room and alive and not kicked and seat = any(targets) and seat <> me.seat;
    if living <> t.targets or (select count(distinct x) from unnest(targets) x) <> t.targets then
      raise exception 'BAD_TARGETS';
    end if;
  end if;
  if p_tool in ('anon_note','last_will') and
     (p_note is null or length(btrim(p_note)) = 0 or length(p_note) > 140) then
    raise exception 'BAD_NOTE';
  end if;
  if p_tool='impersonate' and coalesce(p_note,'') not in ('citizen','mafia') then
    raise exception 'BAD_NOTE';
  end if;

  select count(*), count(*) filter (where tt.tier='heavy'), count(*) filter (where u.tool_code=p_tool)
    into used_all, used_heavy, used_this
    from public.room_tool_uses u join public.table_tools tt on tt.code=u.tool_code
   where u.room_id=p_room and u.user_id=p_user
     and u.created_at >= coalesce((select started_at from public.rooms where id=p_room), '-infinity');
  if used_all >= 4 then raise exception 'LIMIT_MATCH'; end if;
  if t.tier='heavy' and used_heavy >= 2 then raise exception 'LIMIT_HEAVY'; end if;
  if used_this >= t.per_match then raise exception 'LIMIT_TOOL'; end if;
  -- One of each kind per phase, so two charges never stack on the same beat.
  if exists(select 1 from public.room_tool_uses where room_id=p_room and user_id=p_user
             and tool_code=p_tool and phase_number=st.phase_number) then
    raise exception 'LIMIT_PHASE';
  end if;

  if not public.has_all_access(p_user) then
    update public.player_tool_charges set charges=charges-1, updated_at=now()
     where user_id=p_user and tool_code=p_tool and charges>0;
    if not found then raise exception 'NO_CHARGES'; end if;
  end if;

  -- The narrator's private answer: is a mafioso (Silencer included) among the
  -- chosen seats? Stored with the use so the caller can read it again.
  ans := case when p_tool in ('narrator_whisper','sense') then
    exists(select 1 from public.room_players x where x.room_id=p_room
      and x.seat = any(targets) and public.is_mafia_team(x.role))
    else null end;

  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats,note,answer)
    values(p_room,p_user,me.seat,p_tool,st.phase,st.phase_number,targets,
           case when p_note is null then null else left(btrim(p_note),140) end,ans);

  -- The table hears it: who (or «someone» for a secret tool), which tool,
  -- and on whom. The note of a secret tool (the chosen face) never goes here.
  update public.room_state set public_data = jsonb_set(coalesce(public_data,'{}'::jsonb),
      '{toolLog}', coalesce(public_data->'toolLog','[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'tool', p_tool,
        'seat', case when t.secret then null else me.seat end,
        'targets', case when t.secret or p_tool in ('narrator_whisper','sense') then '[]'::jsonb else to_jsonb(targets) end,
        'note', case when p_tool in ('anon_note','last_will') then left(btrim(p_note),140) else null end,
        'phaseNumber', st.phase_number)))
   where room_id=p_room;

  -- The narrator's private answer, to the user's own request only (like the
  -- Detective's): is a mafioso among the chosen seats?
  return jsonb_build_object('tool',p_tool,'seat',me.seat,'phaseNumber',st.phase_number,
    'answer', ans,
    'secret',t.secret,'charges',(select charges from public.player_tool_charges
       where user_id=p_user and tool_code=p_tool));
end $$;
