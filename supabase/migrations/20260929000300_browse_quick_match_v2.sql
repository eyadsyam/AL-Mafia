-- M7 (§7 post-launch): browse and quick match without a per-room subquery.
--
-- Both used to count seats with a correlated `count(*)` per candidate room,
-- and quick match evaluated it twice per row (filter and sort) under the pool
-- lock. Seats are now counted once per room from a partial index of active
-- seats, and the pairwise safety check runs only on the few rooms that
-- survive the cheap filters, in order. Output, ordering and locking are the
-- same as before (supabase/tests/browse_quick_match_v2.sql compares them).

create index if not exists room_players_active_seat
  on public.room_players(room_id) where not kicked;
create index if not exists rooms_public_lobby
  on public.rooms(created_at,id) where status='lobby' and visibility='public';

create function public.public_lobby_seats()
returns table(room_id uuid, players int)
language sql stable security definer set search_path=public,pg_temp as $$
  select p.room_id,count(*)::int
    from public.room_players p join public.rooms r on r.id=p.room_id
   where not p.kicked and r.status='lobby' and r.visibility='public'
   group by p.room_id
$$;
revoke all on function public.public_lobby_seats() from public,anon,authenticated;
grant execute on function public.public_lobby_seats() to service_role;

alter function public.public_room_listing_v2(uuid) rename to public_room_listing_v2_pre_m7;
create function public.public_room_listing_v2(p_user uuid)
returns table (
  code text, title text, players int, capacity int, min_players int,
  voice boolean, waiting boolean
)
language plpgsql security definer set search_path=public,pg_temp stable as $$
begin
  if public.safety_restricted(p_user,'public_rooms') then return; end if;
  return query
  with seats as (select * from public.public_lobby_seats()),
  listed as (
    select r.id, r.code, r.title, r.created_at, r.system_pool is not null as waiting,
      coalesce(s.players,0) as players,
      case when r.settings->>'maxPlayers' in ('5','8','10','15')
        then (r.settings->>'maxPlayers')::int else 10 end as capacity,
      coalesce((r.settings->>'voice')::boolean,true) as voice
    from public.rooms r left join seats s on s.room_id=r.id
    where r.visibility='public' and r.status='lobby'
      and not (p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])))
  ),
  shown as (
    select * from listed l where l.players>0 or l.waiting
  )
  select sh.code, sh.title, sh.players, sh.capacity, 5, sh.voice, sh.waiting
  from shown sh
  where public.safety_room_compatible(sh.id, p_user)
  order by (sh.players >= sh.capacity), sh.waiting, greatest(5 - sh.players, 0),
    sh.players desc, sh.created_at desc
  limit 50;
end $$;
revoke all on function public.public_room_listing_v2_pre_m7(uuid) from public,anon,authenticated;
grant execute on function public.public_room_listing_v2_pre_m7(uuid) to service_role;
revoke all on function public.public_room_listing_v2(uuid) from public,anon,authenticated;
grant execute on function public.public_room_listing_v2(uuid) to service_role;

-- The room quick match would seat [p_user] in right now, without locking or
-- joining: the fullest open classic public lobby this player may sit at,
-- oldest first. Read-only; the caller holds the pool lock.
create function public.quick_match_candidates(p_user uuid)
returns table(room_id uuid, code text, players int)
language sql stable security definer set search_path=public,pg_temp as $$
  select r.id,r.code,coalesce(s.players,0)
    from public.rooms r left join public.public_lobby_seats() s on s.room_id=r.id
   where r.status='lobby' and r.visibility='public'
     and coalesce(r.settings->>'scenarioCode','classic')='classic'
     and coalesce(s.players,0) < case when coalesce((r.settings->>'maxPlayers')::integer,10)
       in (5,8,10,15) then coalesce((r.settings->>'maxPlayers')::integer,10) else 10 end
     and not (p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])))
   order by coalesce(s.players,0) desc,r.created_at,r.id
$$;
revoke all on function public.quick_match_candidates(uuid) from public,anon,authenticated;
grant execute on function public.quick_match_candidates(uuid) to service_role;

create or replace function public.quick_match_atomic(
  p_user uuid,p_name text,p_gender text
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare c record; candidate text; result jsonb; new_code text; seed bigint; attempt integer;
begin
  if length(btrim(p_name)) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  if public.safety_restricted(p_user,'public_rooms') then raise exception 'ACCOUNT_RESTRICTED'; end if;
  perform pg_advisory_xact_lock(hashtext('quick_match:classic'));

  -- Cheap filters first, the pairwise safety check only while walking the
  -- ordered survivors; a row another transaction holds is skipped as before.
  for c in select * from public.quick_match_candidates(p_user) loop
    continue when not public.safety_room_compatible(c.room_id,p_user);
    select r.code into candidate from public.rooms r
     where r.id=c.room_id and r.status='lobby' for update skip locked;
    exit when candidate is not null;
  end loop;

  if candidate is not null then
    result:=public.join_room_atomic(candidate,p_user,p_name,p_gender);
    return result||jsonb_build_object('code',candidate,'created',false);
  end if;

  for attempt in 1..8 loop
    select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
      1+floor(random()*32)::integer,1),'') into new_code
      from generate_series(1,6);
    seed:=floor(random()*2147483647)::bigint;
    begin
      result:=public.create_room_atomic(
        new_code,p_user,p_name,p_gender,seed,
        jsonb_build_object(
          'visibility','public','title','لعب سريع',
          'settings',jsonb_build_object(
            'maxPlayers',10,'voice',true,'muteAllAtNight',true,
            'speechSeconds',45,'discussionSeconds',300,
            'openVoting',false,'traceEnabled',true,
            'discussionMode','structured','confrontationEnabled',true,
            'whisperEnabled',true,'scenarioCode','classic'
          )
        )
      );
      return result||jsonb_build_object('created',true);
    exception when unique_violation then
    end;
  end loop;
  raise exception 'BAD_REQUEST';
end $$;
revoke all on function public.quick_match_atomic(uuid,text,text) from public,anon,authenticated;
grant execute on function public.quick_match_atomic(uuid,text,text) to service_role;
