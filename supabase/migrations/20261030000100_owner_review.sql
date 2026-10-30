-- Read-only owner review. The edge function checks the same administrator row
-- before calling this service-role-only function; this check is the second gate.
create function public.owner_review(p_admin uuid, p_action text, p_query text default '')
returns jsonb language plpgsql stable security definer
set search_path = public, auth, pg_temp as $$
declare result jsonb := '{}'::jsonb;
declare prefix text := replace(replace(replace(left(coalesce(p_query,''), 40), '\', '\\'), '%', '\%'), '_', '\_') || '%';
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_action = 'overview' then
    result := jsonb_build_object(
      'accountsTotal', (select count(*) from auth.users),
      'accountsNew7d', (select count(*) from auth.users where created_at >= now()-interval '7 days'),
      'signedIn7d', (select count(*) from auth.users where last_sign_in_at >= now()-interval '7 days'),
      'roomsOpen', (select count(*) from public.rooms where status in ('lobby','playing')),
      'matches7d', (select count(*) from public.rooms where status in ('playing','finished') and created_at >= now()-interval '7 days'),
      'matchesEver', (select count(*) from public.rooms where status in ('playing','finished')),
      'pushTokens', (select count(*) from public.push_tokens),
      'safetyOpen', (select count(*) from public.safety_reports where status in ('pending','reviewing')),
      'pendingItems', jsonb_build_object(
        'coinOrders', (select count(*) from public.coin_orders where status in ('claimed','needs_info')),
        'safetyReports', (select count(*) from public.safety_reports where status in ('pending','reviewing')),
        'testerSignups', (select count(*) from public.tester_signups where status='new'),
        'deletions', (select count(*) from public.data_deletion_requests where completed_at is null)));
  elsif p_action = 'players' then
    result := jsonb_build_object('items', coalesce((
      select jsonb_agg(jsonb_build_object('displayName', x.name,
        'createdAt', x.created_at, 'lastSignIn', x.last_sign_in_at,
        'level', x.level, 'allAccess', x.all_access) order by x.created_at desc)
      from (select coalesce(i.name, '') name, u.created_at, u.last_sign_in_at,
        case when xp.total is null then null else public.council_level_for(xp.total) end level,
        (g.user_id is not null) all_access
        from auth.users u left join public.council_identity i on i.user_id=u.id
        left join lateral (select sum(e.xp)::bigint total from public.council_xp_events e where e.user_id=u.id) xp on true
        left join public.all_access_grants g on g.user_id=u.id and g.revoked_at is null
        where coalesce(i.name,'') ilike prefix escape '\'
        order by u.created_at desc limit 50) x), '[]'::jsonb));
  elsif p_action = 'rooms' then
    result := jsonb_build_object('items', coalesce((
      select jsonb_agg(jsonb_build_object('code',x.code,'status',x.status,
        'phase',x.phase,'playerCount',x.player_count,'createdAt',x.created_at,
        'hostName',x.host_name) order by x.created_at desc)
      from (select r.code,r.status,s.phase,r.created_at,
        (select count(*) from public.room_players p where p.room_id=r.id and not p.kicked) player_count,
        coalesce(i.name,(select p.name from public.room_players p
          where p.room_id=r.id and p.user_id=r.host_id limit 1),'') host_name
        from public.rooms r left join public.room_state s on s.room_id=r.id
        left join public.council_identity i on i.user_id=r.host_id
        order by r.created_at desc limit 50) x), '[]'::jsonb));
  elsif p_action = 'store' then
    result := jsonb_build_object('items', coalesce((
      select jsonb_agg(jsonb_build_object('code',x.code,'kind',x.kind,
        'coinPrice',x.coin_price,'active',x.active,'owners',x.owners) order by x.code)
      from (select c.code,c.kind,c.coin_price,c.active,
        (select count(*) from public.player_inventory p where p.item_code=c.code) owners
        from public.reward_catalog c where c.active
        union all
        select t.code,'tool' kind,t.coin_price,t.active,
          (select count(*) from public.player_tool_charges p where p.tool_code=t.code and p.charges>0) owners
        from public.table_tools t where t.active
        order by code limit 50) x), '[]'::jsonb),
      'grants', coalesce((select jsonb_agg(jsonb_build_object('displayName',x.name,
        'since',x.granted_at) order by x.granted_at desc)
        from (select coalesce(i.name,'') name,g.granted_at from public.all_access_grants g
          left join public.council_identity i on i.user_id=g.user_id
          where g.revoked_at is null order by g.granted_at desc limit 50) x), '[]'::jsonb));
  elsif p_action = 'config' then
    result := jsonb_build_object('app',coalesce((select to_jsonb(c) from public.app_config c limit 1),'{}'::jsonb),
      'economy',coalesce((select to_jsonb(c) from public.economy_config c limit 1),'{}'::jsonb));
  elsif p_action = 'push' then
    result := jsonb_build_object('items',coalesce((select jsonb_agg(jsonb_build_object(
      'kind',x.kind,'status',x.status,'count',x.n) order by x.kind,x.status)
      from (select kind,status,count(*) n from public.push_outbox
        where created_at >= now()-interval '7 days' group by kind,status
        order by kind,status limit 50) x),'[]'::jsonb));
  elsif p_action = 'testers' then
    -- Reuse the existing admin query and discard email, IP hash and notes.
    result := jsonb_build_object('items',coalesce((select jsonb_agg(jsonb_build_object(
      'name',s->>'name','status',s->>'status','createdAt',s->>'createdAt',
      'source',s->>'source') order by s->>'createdAt' desc)
      from (select s from jsonb_array_elements(public.admin_testers(p_admin)->'signups') s
        order by s->>'createdAt' desc limit 50) x),'[]'::jsonb));
  else
    raise exception 'BAD_REQUEST';
  end if;
  return result;
exception when undefined_table or undefined_column or undefined_function then
  -- An older local schema can lack a later review source.
  return case when p_action='overview' then '{}'::jsonb
    when p_action='config' then jsonb_build_object('app','{}'::jsonb,'economy','{}'::jsonb)
    else jsonb_build_object('items','[]'::jsonb) end;
end $$;
revoke all on function public.owner_review(uuid,text,text) from public,anon,authenticated;
grant execute on function public.owner_review(uuid,text,text) to service_role;
