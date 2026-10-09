-- The Silencer is on the Mafia's side. Every team / win / parity / settlement
-- check that compared the role to the literal 'mafia' counted the Silencer as
-- town. One immutable helper now names the team and each affected function is
-- recreated (bodies unchanged except for the role test).

create or replace function public.is_mafia_team(p_role text)
returns boolean language sql immutable strict parallel safe as $$
  select p_role in ('mafia','silencer')
$$;
revoke all on function public.is_mafia_team(text) from public, anon, authenticated;
grant execute on function public.is_mafia_team(text) to service_role;

create or replace function public.kick_member(p_room uuid, p_host uuid, p_seat integer) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; p public.room_players%rowtype; s public.room_state%rowtype;
        mafia integer; town integer;
begin
  select * into r from public.rooms where id=p_room and host_id=p_host for update;
  if not found then raise exception 'NOT_HOST'; end if;
  select * into p from public.room_players where room_id=p_room and seat=p_seat for update;
  if not found then raise exception 'BAD_REQUEST'; end if;
  if p.user_id=p_host then raise exception 'BAD_REQUEST'; end if;
  update public.rooms set banned_user_ids =
    case when p.user_id = any(banned_user_ids) then banned_user_ids
         else array_append(banned_user_ids, p.user_id) end
    where id=p_room;
  update public.room_players set status='left', connected=false, kicked=true
    where room_id=p_room and user_id=p.user_id;
  if r.status='playing' and p.alive and p.role is not null then
    select * into s from public.room_state where room_id=p_room for update;
    update public.room_players set alive=false where room_id=p_room and user_id=p.user_id;
    -- Doc 09 §3.4: anything still in flight to a seat that is gone is voided,
    -- exactly as it is for a seat that died.
    update public.whisper_meta set voided=true where room_id=p_room and to_id=p.user_id and not voided;
    perform public.set_public_path(p_room, array['eliminations', p_seat::text],
      jsonb_build_object('phase', case when s.phase='night' then 'night' else 'day' end, 'number', s.phase_number));
    -- W8: the win check runs after the removal is applied.
    select count(*) filter (where public.is_mafia_team(role)), count(*) filter (where not public.is_mafia_team(role))
      into mafia, town from public.room_players where room_id=p_room and alive;
    if mafia=0 then
      perform public.merge_public_data(p_room, jsonb_build_object('outcome','town'));
    elsif mafia>=town then
      perform public.merge_public_data(p_room, jsonb_build_object('outcome','mafia'));
    end if;
  end if;
  return p.user_id;
end;
$$;

create or replace function public.strike_absent_member(p_room uuid, p_host uuid, p_seat integer)
returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; p public.room_players%rowtype; s public.room_state%rowtype;
        mafia integer; town integer; outcome text;
begin
  select * into r from public.rooms where id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if r.host_id<>p_host then raise exception 'NOT_HOST'; end if;
  if r.status<>'playing' then raise exception 'PHASE_CLOSED'; end if;
  select * into p from public.room_players where room_id=p_room and seat=p_seat for update;
  if not found then raise exception 'BAD_REQUEST'; end if;
  -- The host is the one asking; a host who is here cannot be gone.
  if p.user_id=p_host then raise exception 'BAD_REQUEST'; end if;
  if not p.alive then raise exception 'ALREADY_OUT'; end if;
  -- Three minutes of silence, by the server's clock. A seat that is still
  -- beating — or went quiet less than three minutes ago — is still here.
  if p.connected and public.heard_at(p.room_id, p.user_id, p.last_seen) > now() - interval '3 minutes' then
    raise exception 'STILL_HERE';
  end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  update public.room_players set alive=false where room_id=p_room and user_id=p.user_id;
  -- Doc 09 §3.4: anything still in flight to a seat that is gone is voided,
  -- exactly as it is for a seat that died.
  update public.whisper_meta set voided=true where room_id=p_room and to_id=p.user_id and not voided;
  perform public.set_public_path(p_room, array['eliminations', p_seat::text],
    jsonb_build_object('phase', case when s.phase='night' then 'night' else 'day' end, 'number', s.phase_number));
  -- W8: the win check runs after the removal is applied.
  select count(*) filter (where public.is_mafia_team(role)), count(*) filter (where not public.is_mafia_team(role))
    into mafia, town from public.room_players where room_id=p_room and alive;
  if mafia=0 then outcome:='town';
  elsif mafia>=town then outcome:='mafia';
  end if;
  if outcome is not null then
    perform public.merge_public_data(p_room, jsonb_build_object('outcome',outcome));
  end if;
  return jsonb_build_object('removed', p_seat, 'outcome', outcome);
end;
$$;

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

  select r.ended_at,p.role,s.public_data->>'outcome' as outcome into m
    from public.rooms r join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
   where r.id=p_room and p.user_id=p_user and not p.kicked and p.role is not null
     and r.status='finished' and r.ended_at is not null
     and s.public_data->>'outcome' in ('mafia','town');
  if not found then return null; end if;

  select count(distinct user_id)::int,
      coalesce(array_agg(distinct user_id) filter (where user_id<>p_user),'{}')
    into humans,mates
    from public.room_players where room_id=p_room and not kicked and role is not null;
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

create or replace function public.council_record_match(p_user uuid,p_room uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare m record; v_team text; mates uuid[]; n int; humans int; rec public.match_receipts;
  d date; wk text; reunion_credit boolean;
begin
  if not public.economy_v3_on() then return public.council_record_match_pre_v3(p_user,p_room); end if;
  if not public.council_on('any') and not public.missions_on() then return false; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  perform pg_advisory_xact_lock(hashtextextended('casebook:'||p_user::text,93));
  select r.id,r.ended_at,r.host_id,p.role,p.name,p.gender,
      s.public_data->>'outcome' as outcome into m
    from public.rooms r join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
   where r.id=p_room and p.user_id=p_user and not p.kicked and p.role is not null
     and r.status='finished' and r.ended_at is not null
     and s.public_data->>'outcome' in ('mafia','town');
  if not found then return false; end if;
  rec:=public.economy_v3_issue_receipt(p_user,p_room);

  d:=(m.ended_at at time zone 'utc')::date;
  wk:=public.council_week(d);
  v_team:=case when public.is_mafia_team(m.role) then 'mafia' else 'town' end;
  select coalesce(array_agg(user_id order by user_id) filter(where user_id<>p_user),'{}'),
      count(distinct user_id)
    into mates,humans from public.room_players
   where room_id=p_room and not kicked and role is not null;
  select exists(
    select 1 from unnest(mates) mate
     where exists(select 1 from public.council_match_records old
       where old.user_id=p_user and old.ended_at<m.ended_at
         and old.ended_at>m.ended_at-interval '7 days' and mate=any(old.co_players))
       and not exists(select 1 from public.council_match_records used
         where used.user_id=p_user and used.week=wk and used.reunion
           and mate=any(used.co_players))) into reunion_credit;

  insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,
      reunion,co_players,eligible,human_count,group_fingerprint)
    values(p_user,p_room,m.ended_at,d,wk,v_team,v_team=m.outcome,
      m.host_id is not distinct from p_user,reunion_credit,mates,
      rec.user_id is not null,least(humans,20),coalesce(left(rec.roster_fingerprint,32),''))
    on conflict do nothing;
  get diagnostics n=row_count;
  if n=0 then return false; end if;
  insert into public.council_identity(user_id,name,gender,updated_at)
    values(p_user,left(btrim(m.name),40),coalesce(m.gender,'unspecified'),now())
    on conflict(user_id) do update set name=excluded.name,gender=excluded.gender,
      updated_at=now() where council_identity.updated_at<=excluded.updated_at;
  perform public.casebook_record_match(p_user,p_room);
  return true;
end $$;

create or replace function public.council_record_match_pre_v3(p_user uuid, p_room uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare m record; v_team text; mates uuid[]; n int; humans int; fp text;
  d date; wk text; day_used int; group_used int; reunion_credit boolean;
begin
  if not public.council_on('any') and not public.missions_on() then return false; end if;
  perform pg_advisory_xact_lock(hashtextextended('casebook:'||p_user::text,93));
  select r.id,r.ended_at,r.host_id,p.role,p.name,p.gender,
      s.public_data->>'outcome' as outcome
    into m
    from public.rooms r join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
   where r.id=p_room and p.user_id=p_user and not p.kicked and p.role is not null
     and r.status='finished' and r.ended_at is not null
     and s.public_data->>'outcome' in ('mafia','town');
  if not found then return false; end if;

  d := (m.ended_at at time zone 'utc')::date;
  wk := public.council_week(d);
  v_team := case when public.is_mafia_team(m.role) then 'mafia' else 'town' end;
  select coalesce(array_agg(user_id order by user_id) filter(where user_id<>p_user),'{}'),
      count(distinct user_id),md5(string_agg(user_id::text,',' order by user_id))
    into mates,humans,fp from public.room_players
   where room_id=p_room and not kicked and role is not null;
  select count(*) into day_used from public.council_match_records
   where user_id=p_user and day=d and eligible;
  select count(*) into group_used from public.council_match_records
   where user_id=p_user and day=d and eligible and group_fingerprint=fp;

  -- A reunion credit needs a previously met player, and that same player can
  -- unlock it only once in an ISO week.
  select exists(
    select 1 from unnest(mates) mate
     where exists(select 1 from public.council_match_records old
       where old.user_id=p_user and old.ended_at<m.ended_at
         and old.ended_at>m.ended_at-interval '7 days' and mate=any(old.co_players))
       and not exists(select 1 from public.council_match_records used
         where used.user_id=p_user and used.week=wk and used.reunion
           and mate=any(used.co_players))) into reunion_credit;

  insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,
      reunion,co_players,eligible,human_count,group_fingerprint)
    values(p_user,p_room,m.ended_at,d,wk,v_team,v_team=m.outcome,
      m.host_id is not distinct from p_user,reunion_credit,mates,
      humans>=5 and day_used<6 and group_used<3,humans,fp)
    on conflict do nothing;
  get diagnostics n=row_count;
  if n=0 then return false; end if;
  insert into public.council_identity(user_id,name,gender,updated_at)
    values(p_user,left(btrim(m.name),40),coalesce(m.gender,'unspecified'),now())
    on conflict(user_id) do update set name=excluded.name,gender=excluded.gender,
      updated_at=now() where council_identity.updated_at<=excluded.updated_at;
  perform public.casebook_record_match(p_user,p_room);
  return true;
end $$;

create or replace function public.sync_player_rewards_pre_v3(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare candidate record; inserted_count integer; reward bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  for candidate in
    select r.id,r.ended_at,p.role,s.public_data->>'outcome' as outcome
    from public.rooms r join public.room_players p on p.room_id=r.id
      join public.room_state s on s.room_id=r.id
    where p.user_id=p_user and not p.kicked and p.role is not null
      and r.status='finished' and r.ended_at is not null
      and s.public_data->>'outcome' in ('mafia','town')
  loop
    insert into public.wallet_ledger(user_id,kind,amount,source_room)
      values(p_user,'match_completion',100,candidate.id) on conflict do nothing;
    get diagnostics inserted_count=row_count;
    if inserted_count=1 then
      update public.wallet_accounts set balance=balance+100,lifetime_earned=lifetime_earned+100,updated_at=now()
        where user_id=p_user;
    end if;
    reward:=case when (public.is_mafia_team(candidate.role) and candidate.outcome='mafia') or
      (not public.is_mafia_team(candidate.role) and candidate.outcome='town') then 25 else 0 end;
    if reward>0 then
      insert into public.wallet_ledger(user_id,kind,amount,source_room)
        values(p_user,'match_win',reward,candidate.id) on conflict do nothing;
      get diagnostics inserted_count=row_count;
      if inserted_count=1 then
        update public.wallet_accounts set balance=balance+reward,lifetime_earned=lifetime_earned+reward,updated_at=now()
          where user_id=p_user;
      end if;
    end if;
  end loop;
  return public.wallet_snapshot(p_user);
end $$;

create or replace function public.compute_match_awards(p_room uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_outcome text; pub jsonb;
begin
  if not public.room_at_public_end(p_room) then return false; end if;
  perform pg_advisory_xact_lock(hashtextextended('awards:'||p_room::text,92));
  if exists(select 1 from public.match_awards_computed where room_id=p_room) then
    return true;
  end if;
  select s.public_data into pub from public.room_state s where s.room_id=p_room;
  v_outcome := pub->>'outcome';

  create temp table if not exists fun_players(user_id uuid, seat int, mafia boolean,
    alive boolean, winner boolean) on commit drop;
  create temp table if not exists fun_ballots(day int, voter uuid, target uuid,
    at timestamptz) on commit drop;
  create temp table if not exists fun_day_out(day int, target uuid) on commit drop;
  delete from fun_players; delete from fun_ballots; delete from fun_day_out;

  insert into fun_players
    select p.user_id, p.seat, public.is_mafia_team(p.role), p.alive,
      (case when public.is_mafia_team(p.role) then 'mafia' else 'town' end)=v_outcome
      from public.room_players p
     where p.room_id=p_room and not p.kicked and p.role is not null;
  insert into fun_ballots
    select v.day, v.voter_id, v.target_id, v.created_at from public.votes v
     where v.room_id=p_room and v.target_id is not null
       and v.round=(select max(w.round) from public.votes w
                     where w.room_id=p_room and w.day=v.day)
       and exists(select 1 from fun_players f where f.user_id=v.voter_id);
  insert into fun_day_out
    select (e.value->>'number')::int, p.user_id
      from jsonb_each(coalesce(pub->'eliminations','{}'::jsonb)) e
      join public.room_players p on p.room_id=p_room and p.seat=e.key::int
     where e.value->>'phase'='day';

  -- sharp_eye
  insert into public.match_awards
    select p_room,'sharp_eye',x.voter,x.seat from (
      select b.voter, f.seat, count(*) n, min(b.at) first from fun_ballots b
        join fun_players f on f.user_id=b.voter and not f.mafia
        join fun_players t on t.user_id=b.target and t.mafia
       group by b.voter, f.seat order by n desc, first, f.seat limit 1) x;

  -- first_blood
  insert into public.match_awards
    select p_room,'first_blood',b.voter,f.seat from fun_ballots b
      join fun_players f on f.user_id=b.voter and not f.mafia
      join (select o.day, o.target from fun_day_out o
              join fun_players t on t.user_id=o.target and t.mafia
             order by o.day limit 1) d on d.day=b.day and d.target=b.target
     order by b.at, f.seat limit 1;

  -- silver_tongue
  insert into public.match_awards
    select p_room,'silver_tongue',x.voter,x.seat from (
      select b.voter, f.seat,
          sum((select count(*) from fun_ballots c
                where c.day=b.day and c.target=b.target and c.voter<>b.voter)) n,
          min(b.at) first
        from fun_ballots b
        join fun_players f on f.user_id=b.voter and not f.mafia
        join fun_day_out o on o.day=b.day and o.target=b.target
        join fun_players t on t.user_id=o.target and t.mafia
       group by b.voter, f.seat) x
     where x.n >= 1 order by x.n desc, x.first, x.seat limit 1;

  -- lifesaver
  insert into public.match_awards
    select distinct p_room,'lifesaver',a.actor_id,f.seat
      from public.night_actions a
      join public.night_resolution_private n on n.room_id=a.room_id and n.night=a.night
      join public.room_players t on t.room_id=a.room_id and t.seat=n.saved_seat
      join fun_players f on f.user_id=a.actor_id
      join public.room_players d on d.room_id=a.room_id and d.user_id=a.actor_id
     where a.room_id=p_room and a.action='protect' and a.target_id=t.user_id
       and d.role='doctor'
    on conflict do nothing;

  -- perfect_crime
  if v_outcome='mafia' and not exists(select 1 from public.room_players p
       where p.room_id=p_room and public.is_mafia_team(p.role) and (not p.alive or p.kicked)) then
    insert into public.match_awards
      select p_room,'perfect_crime',f.user_id,f.seat from fun_players f where f.mafia;
  end if;

  -- survivor
  insert into public.match_awards
    select p_room,'survivor',f.user_id,f.seat from fun_players f where f.winner and f.alive;

  -- mvp
  insert into public.match_awards
    select p_room,'mvp',x.user_id,x.seat from (
      select f.user_id, f.seat,
        3*(select count(*) from fun_ballots b join fun_players t on t.user_id=b.target
            where b.voter=f.user_id and not f.mafia and t.mafia)
        + 3*(select count(*) from public.match_awards a
              where a.room_id=p_room and a.award='lifesaver' and a.user_id=f.user_id)
        + 2*(select count(*) from fun_ballots b
              join fun_day_out o on o.day=b.day and o.target=b.target
              join fun_players t on t.user_id=o.target and not t.mafia
             where b.voter=f.user_id and f.mafia)
        + case when f.alive then 2 else 0 end as score
        from fun_players f where f.winner) x
     order by x.score desc, x.seat limit 1;

  insert into public.match_awards_computed(room_id) values(p_room);
  return true;
end $$;
