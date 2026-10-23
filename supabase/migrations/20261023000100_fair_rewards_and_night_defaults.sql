-- A finished room has settled its roster and cannot lose receipts to a late kick.
create or replace function public.kick_member(p_room uuid,p_host uuid,p_seat integer)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare playing boolean; removed uuid; prior_outcome text; room_status text;
begin
  -- Keep the same room then state lock order as the removal body.
  select status into room_status from public.rooms where id=p_room for update;
  if room_status='finished' then raise exception 'PHASE_CLOSED'; end if;
  select public_data->>'outcome' into prior_outcome
    from public.room_state where room_id=p_room for update;
  select r.status='playing' and p.alive and p.role is not null into playing
    from public.rooms r join public.room_players p on p.room_id=r.id
    where r.id=p_room and p.seat=p_seat;
  removed:=public.kick_member_pre_economy(p_room,p_host,p_seat);
  if playing and prior_outcome is null and exists(select 1 from public.room_state
      where room_id=p_room and public_data->>'outcome' in ('mafia','town')) then
    insert into public.economy_void_rooms(room_id) values(p_room) on conflict do nothing;
  end if;
  return removed;
end $$;
revoke all on function public.kick_member(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.kick_member(uuid,uuid,integer) to service_role;

-- The marker is authoritative for matches started after it was introduced.
create or replace function public.economy_kick_voided(p_room uuid)
returns boolean language plpgsql stable security definer set search_path=public,pg_temp as $$
declare outcome text; mafia int; town int;
begin
  if exists(select 1 from public.economy_void_rooms where room_id=p_room) then return true; end if;
  if not exists(select 1 from public.rooms where id=p_room
      and started_at < timestamptz '2026-10-09 00:00:00+00') then return false; end if;
  select public_data->>'outcome' into outcome from public.room_state where room_id=p_room;
  if outcome not in ('mafia','town') then return false; end if;
  select count(*) filter(where alive and public.is_mafia_team(role)),
    count(*) filter(where alive and not public.is_mafia_team(role)) into mafia,town
    from public.room_players where room_id=p_room;
  return exists(select 1 from public.room_players p where p.room_id=p_room and p.kicked
    and p.role is not null and
    ((outcome='town' and public.is_mafia_team(p.role)) or
     (outcome='mafia' and not public.is_mafia_team(p.role) and mafia<town+1)));
end $$;
revoke all on function public.economy_kick_voided(uuid) from public,anon,authenticated;
grant execute on function public.economy_kick_voided(uuid) to service_role;

-- A night victim took part even when they had no legal move before dying.
create or replace function public.economy_took_part(p_room uuid,p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.room_players p
    where p.room_id=p_room and p.user_id=p_user and not p.kicked
      and p.status is distinct from 'left' and p.role is not null
      and (exists(select 1 from public.votes v where v.room_id=p_room
          and v.voter_id=p_user and v.action_id is not null)
        or exists(select 1 from public.night_actions a where a.room_id=p_room
          and a.actor_id=p_user and a.action_id is not null)
        or (not p.alive and exists(select 1 from public.night_actions a
          where a.room_id=p_room and a.target_id=p_user
            and (a.action='kill' or (a.action='suspect' and a.used_bullet=true))))));
$$;
revoke all on function public.economy_took_part(uuid,uuid) from public,anon,authenticated;
grant execute on function public.economy_took_part(uuid,uuid) to service_role;

create or replace function public.economy_roster_fingerprint(p_room uuid,p_day date)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare s bytea; roster text;
begin
  select string_agg(distinct p.user_id::text,',' order by p.user_id::text) into roster
    from public.room_players p where p.room_id=p_room
      and public.economy_took_part(p_room,p.user_id);
  if roster is null then return null; end if;
  insert into public.economy_roster_salts(day,salt)
    values(p_day,decode(replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-',''),'hex'))
    on conflict(day) do nothing;
  select salt into strict s from public.economy_roster_salts where day=p_day;
  return encode(public.metric_hmac_sha256(s,convert_to(roster,'UTF8')),'hex');
end $$;
revoke all on function public.economy_roster_fingerprint(uuid,date) from public,anon,authenticated;
grant execute on function public.economy_roster_fingerprint(uuid,date) to service_role;

create or replace function public.economy_v3_issue_receipt(p_user uuid,p_room uuid)
returns public.match_receipts language plpgsql security definer set search_path=public,pg_temp as $$
declare rec public.match_receipts; m record; humans int; mates uuid[]; d date; fp text;
  day_used int; fp_used int; v_won boolean;
begin
  select * into rec from public.match_receipts where user_id=p_user and room_id=p_room;
  if found then return rec; end if;
  if not public.economy_v3_on() then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into rec from public.match_receipts where user_id=p_user and room_id=p_room;
  if found then return rec; end if;
  select r.started_at,r.ended_at,p.role,s.public_data->>'outcome' as outcome into m
    from public.rooms r join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
   where r.id=p_room and p.user_id=p_user and not p.kicked
     and p.status is distinct from 'left' and p.role is not null
     and r.status='finished' and r.ended_at is not null
     and s.public_data->>'outcome' in ('mafia','town');
  if not found or m.started_at is null or m.ended_at<m.started_at+interval '3 minutes'
      or public.economy_kick_voided(p_room)
      or not public.economy_took_part(p_room,p_user) then
    return null;
  end if;
  select count(distinct p.user_id)::int,
      coalesce(array_agg(distinct p.user_id) filter(where p.user_id<>p_user),'{}')
    into humans,mates from public.room_players p
    where p.room_id=p_room and public.economy_took_part(p_room,p.user_id);
  if humans<5 then return null; end if;
  d:=(m.ended_at at time zone 'utc')::date;
  select count(*)::int into day_used from public.match_receipts where user_id=p_user and day=d;
  if day_used>=6 then return null; end if;
  fp:=public.economy_roster_fingerprint(p_room,d);
  select count(*)::int into fp_used from public.match_receipts
   where user_id=p_user and day=d and roster_fingerprint=fp;
  if fp_used>=3 then return null; end if;
  v_won:=(public.is_mafia_team(m.role))=(m.outcome='mafia');
  insert into public.match_receipts(user_id,room_id,day,week,ended_at,won,human_count,
      roster_fingerprint,day_ordinal,roster_ordinal,co_players,completion_coins,win_coins,
      first_day_coins,season_xp,council_xp)
    values(p_user,p_room,d,public.council_week(d),m.ended_at,v_won,humans,fp,day_used+1,
      fp_used+1,mates,25,case when v_won then 10 else 0 end,case when day_used=0 then 25 else 0 end,
      5+case when v_won then 5 else 0 end,30+case when v_won then 20 else 0 end)
    returning * into rec;
  return rec;
end $$;
revoke all on function public.economy_v3_issue_receipt(uuid,uuid) from public,anon,authenticated;
grant execute on function public.economy_v3_issue_receipt(uuid,uuid) to service_role;

-- Compute the titles for any seated member, but credit only where the match
-- earned its rewards. Issue before taking the award wallet lock; the receipt
-- issuer takes that same lock.
create or replace function public.match_awards_get_pre_economy(p_user uuid, p_room uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; awards jsonb; mine jsonb; granted bigint := 0;
  amount bigint; eligible boolean;
begin
  if not public.fun_on('awards') then return jsonb_build_object('enabled',false); end if;
  if not exists(select 1 from public.room_players where room_id=p_room and user_id=p_user
      and not kicked) then
    return jsonb_build_object('enabled',true,'ready',false,'awards','[]'::jsonb);
  end if;
  -- Without receipts (v3 off), and for a room already paid under the amounts
  -- before them (sync_player_rewards skips that room the same way), the award
  -- pays as it always did. Otherwise only the receipt's rules let it pay.
  if not public.economy_v3_on()
      or exists(select 1 from public.match_receipts where user_id=p_user and room_id=p_room)
      or exists(select 1 from public.wallet_ledger where user_id=p_user
        and source_room=p_room and kind='match_completion') then
    eligible := true;
  else
    eligible := (public.economy_v3_issue_receipt(p_user,p_room)).user_id is not null;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  if not public.compute_match_awards(p_room) then
    return jsonb_build_object('enabled',true,'ready',false,'awards','[]'::jsonb,
      'granted',0);
  end if;
  select * into cfg from public.economy_config;
  select coalesce(sum(case when award='mvp' then cfg.award_mvp_coins else cfg.award_coins end),0)
    into amount from public.match_awards where room_id=p_room and user_id=p_user;
  if eligible and amount > 0 and public.credit_earned(p_user,'match_award',amount,p_room,
      'awards:'||p_room::text) then
    granted := amount;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('code',x.award,'seats',x.seats,'names',x.names,
      'coins',case when x.award='mvp' then cfg.award_mvp_coins else cfg.award_coins end)
      order by x.ord),'[]')
    into awards from (
      select m.award, array_position(array['mvp','sharp_eye','silver_tongue','first_blood',
          'lifesaver','perfect_crime','survivor'], m.award) ord,
        jsonb_agg(m.seat order by m.seat) seats,
        jsonb_agg(left(btrim(p.name),40) order by m.seat) names
        from public.match_awards m join public.room_players p
          on p.room_id=m.room_id and p.user_id=m.user_id
       where m.room_id=p_room group by m.award) x;
  select coalesce(jsonb_agg(award order by award),'[]') into mine
    from public.match_awards where room_id=p_room and user_id=p_user;
  return jsonb_build_object('enabled',true,'ready',true,'awards',awards,'mine',mine,
    'granted',granted,
    'balance',(select balance from public.wallet_accounts where user_id=p_user),
    'founder',public.fun_grant_founder(p_user));
end $$;
revoke all on function public.match_awards_get_pre_economy(uuid,uuid) from public,anon,authenticated;
grant execute on function public.match_awards_get_pre_economy(uuid,uuid) to service_role;

-- Unchanged from 20261009002200: a void match shows no awards at all.
create or replace function public.match_awards_get(p_user uuid,p_room uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if public.economy_kick_voided(p_room) then
    return jsonb_build_object('enabled',true,'ready',true,'awards','[]'::jsonb,
      'mine','[]'::jsonb,'granted',0,
      'balance',(select balance from public.wallet_accounts where user_id=p_user));
  end if;
  return public.match_awards_get_pre_economy(p_user,p_room);
end $$;
revoke all on function public.match_awards_get(uuid,uuid) from public,anon,authenticated;
grant execute on function public.match_awards_get(uuid,uuid) to service_role;

-- Reject stale resolutions under the same room lock used by kicks and strikes.
create or replace function public.commit_resolution(
  p_room uuid, p_phase text, p_number integer, p_round integer,
  p_victim uuid, p_saved_seat integer, p_archive jsonb,
  p_patch jsonb, p_next text, p_deadline timestamptz, p_fingerprint text
) returns boolean language plpgsql security definer
set search_path = public, pg_temp as $$
declare s public.room_state; victim_seat integer;
begin
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase <> p_phase or s.phase_number <> p_number then return false; end if;
  if p_phase='vote' and coalesce((s.public_data #>> '{revote,round}')::integer,1) <> p_round then
    return false;
  end if;
  if not ((p_phase='night' and p_next='morning') or
          (p_phase='vote' and p_next in ('vote','verdict'))) then
    raise exception 'invalid resolution transition';
  end if;
  if p_fingerprint is distinct from (case when p_phase='night'
      then public.night_fingerprint(p_room,p_number)
      else public.vote_fingerprint(p_room,p_number,p_round) end) then
    return false;
  end if;
  -- A removal may have decided the match after the caller's tally.
  if s.public_data->>'outcome' in ('mafia','town') and
    (p_patch->>'outcome' is distinct from s.public_data->>'outcome'
      or p_victim is not null or p_next='vote') then return false; end if;
  if p_victim is not null then
    update public.room_players set alive=false
      where room_id=p_room and user_id=p_victim and alive returning seat into victim_seat;
    if not found then raise exception 'resolution victim unavailable'; end if;
    perform public.set_public_path(p_room, array['eliminations',victim_seat::text],
      jsonb_build_object('phase',case when p_phase='night' then 'night' else 'day' end,'number',p_number));
    update public.whisper_meta set voided=true where room_id=p_room and to_id=p_victim and not voided;
  end if;
  if p_phase='night' then
    perform public.record_night_resolution(p_room,p_number,p_saved_seat,p_archive);
  end if;
  update public.room_state set public_data=public_data || p_patch,
    phase=p_next, phase_ends_at=p_deadline, active_speaker=null, updated_at=now()
    where room_id=p_room;
  if p_phase='vote' and p_patch->>'outcome' is not null then
    update public.rooms set status='finished',ended_at=now() where id=p_room;
  end if;
  return true;
end;
$$;
revoke all on function public.commit_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz,text) from public,anon,authenticated;
grant execute on function public.commit_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz,text) to service_role;

create or replace function public.commit_night_roles_resolution(
  p_room uuid, p_number integer, p_victims uuid[], p_saved_seat integer,
  p_archive jsonb, p_patch jsonb, p_next text, p_deadline timestamptz,
  p_fingerprint text
) returns boolean language plpgsql security definer
set search_path=public,pg_temp as $$
declare
  s public.room_state;
  victim uuid;
  victim_seat integer;
begin
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>'night' or s.phase_number<>p_number or p_next<>'morning' then
    return false;
  end if;
  if p_fingerprint is distinct from public.night_fingerprint(p_room,p_number) then
    return false;
  end if;

  -- Reject a stale tally after a removal has decided the match.
  if s.public_data->>'outcome' in ('mafia','town') and
    (p_patch->>'outcome' is distinct from s.public_data->>'outcome'
      or cardinality(coalesce(p_victims,array[]::uuid[]))>0) then return false; end if;
  foreach victim in array coalesce(p_victims, array[]::uuid[]) loop
    update public.room_players set alive=false
      where room_id=p_room and user_id=victim and alive
      returning seat into victim_seat;
    if not found then raise exception 'resolution victim unavailable'; end if;
    perform public.set_public_path(
      p_room, array['eliminations',victim_seat::text],
      jsonb_build_object('phase','night','number',p_number)
    );
    update public.whisper_meta set voided=true
      where room_id=p_room and to_id=victim and not voided;
  end loop;

  perform public.record_night_resolution(
    p_room,p_number,p_saved_seat,p_archive
  );
  update public.room_state set
    public_data=public_data||p_patch,
    phase='morning',phase_ends_at=p_deadline,active_speaker=null,updated_at=now()
    where room_id=p_room;
  if p_patch->>'outcome' is not null then
    update public.rooms set status='finished',ended_at=now() where id=p_room;
  end if;
  return true;
end;
$$;
revoke all on function public.commit_night_roles_resolution(uuid,integer,uuid[],integer,jsonb,jsonb,text,timestamptz,text) from public,anon,authenticated;
grant execute on function public.commit_night_roles_resolution(uuid,integer,uuid[],integer,jsonb,jsonb,text,timestamptz,text) to service_role;
