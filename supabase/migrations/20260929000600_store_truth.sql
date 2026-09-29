-- Store truth: what a player equips shows where their identity is shown to
-- others, not only at the online table.
--
-- * Friends rows (friends, requests, recent tablemates) carry each person's
--   equipped frame and nameplate.
-- * Council leaderboard rows already carried the frame; they now carry the
--   nameplate too.
--
-- Both are presentation only and public by design (the same two codes every
-- seat already publishes in `room_players.cosmetics`). No role, room or
-- match fact is added. Nothing is granted or equipped here.

create function public.public_cosmetics(p_user uuid) returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object(
    'frame',(select item_code from public.player_equipment where user_id=p_user and slot='frame'),
    'plate',(select item_code from public.player_equipment where user_id=p_user and slot='nameplate'))
$$;
revoke all on function public.public_cosmetics(uuid) from public,anon,authenticated;
grant execute on function public.public_cosmetics(uuid) to service_role;

-- Adds {frame, plate} to every row of a friends list that names an id.
create function public.with_public_cosmetics(p_rows jsonb) returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(jsonb_agg(case
      when r ? 'id' and (r->>'id') ~ '^[0-9a-f-]{36}$'
        then r||public.public_cosmetics((r->>'id')::uuid)
      else r end order by n),'[]'::jsonb)
    from jsonb_array_elements(coalesce(p_rows,'[]'::jsonb)) with ordinality as t(r,n)
$$;
revoke all on function public.with_public_cosmetics(jsonb) from public,anon,authenticated;
grant execute on function public.with_public_cosmetics(jsonb) to service_role;

alter function public.friends_status(uuid) rename to friends_status_pre_store_truth;
create function public.friends_status(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.friends_status_pre_store_truth(p_user);
  if not coalesce((base->>'enabled')::boolean,false) then return base; end if;
  return base||jsonb_build_object(
    'friends',public.with_public_cosmetics(base->'friends'),
    'incoming',public.with_public_cosmetics(base->'incoming'),
    'recent',public.with_public_cosmetics(base->'recent'));
end $$;
revoke all on function public.friends_status_pre_store_truth(uuid) from public,anon,authenticated;
grant execute on function public.friends_status_pre_store_truth(uuid) to service_role;
revoke all on function public.friends_status(uuid) from public,anon,authenticated;
grant execute on function public.friends_status(uuid) to service_role;

-- The leaderboard body as of 20260925000300, with the nameplate beside the
-- frame. Rows still carry no user id.
create or replace function public.council_leaderboard(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := public.economy_today(); wk text := public.council_week(today);
  top jsonb; me jsonb;
begin
  perform public.council_settle_invites(p_user);
  perform public.council_sync(p_user);
  if not public.council_on('leaderboard') then return jsonb_build_object('enabled',false); end if;
  with board as (
    select e.user_id, sum(e.xp) as xp, rank() over (order by sum(e.xp) desc) as pos
      from public.council_xp_events e where e.week=wk
       and (e.user_id=p_user or public.council_visible(e.user_id))
     group by e.user_id having sum(e.xp) > 0
  ), shown as (
    select * from board where public.council_visible(user_id)
     order by pos, user_id limit 50
  )
  select coalesce(jsonb_agg(jsonb_build_object('position',b.pos,'xp',b.xp,
      'name',coalesce(i.name,'—'),'gender',coalesce(i.gender,'unspecified'),
      'me',b.user_id=p_user) || public.public_cosmetics(b.user_id) || public.council_rank_of(
        (select sum(a.xp) from public.council_xp_events a where a.user_id=b.user_id))
      order by b.pos, i.name), '[]'),
    (select jsonb_build_object('position',x.pos,'xp',x.xp) from board x where x.user_id=p_user)
    into top, me
    from shown b
    left join public.council_identity i on i.user_id=b.user_id
   where not exists(select 1 from public.player_blocks k
     where (k.blocker_id=p_user and k.blocked_id=b.user_id)
        or (k.blocker_id=b.user_id and k.blocked_id=p_user));
  return jsonb_build_object('enabled',true,'week',wk,
    'nextWeekAt',(today - extract(isodow from today)::int + 8)::timestamp at time zone 'utc',
    'entries',top,'me',coalesce(me,jsonb_build_object('position',null,'xp',0)),
    'visible',public.council_visible(p_user));
end $$;
revoke all on function public.council_leaderboard(uuid) from public,anon,authenticated;
grant execute on function public.council_leaderboard(uuid) to service_role;
