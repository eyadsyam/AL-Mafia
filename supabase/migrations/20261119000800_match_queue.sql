-- O1 «استناني» (owner 2026-11-19): a queue that keeps working with the app closed.
--
-- A player who finds no public lobby with people in it joins match_queue. Every
-- 15 seconds queue_tick():
--   * seats nobody twice (a queued player who is seated in a room leaves the queue),
--   * removes rows older than 2 hours (push 'queue_expired'),
--   * closes rounds whose 60 s deadline passed or whose members all said yes:
--     5 or more yes -> ONE public room (title «لعب سريع», 180 s discussion,
--     settings.autoStart true, the app starts it), confirmed players seated in
--     joined_at order (first = host), their rows deleted; fewer than 5 yes ->
--     the yes players keep their place, silent players take a miss, a second
--     miss removes them,
--   * opens a round when 5 or more queued players have none (the oldest 10),
--     push 'queue_ready' to each.
-- (Closing runs before opening so a round that just failed does not re-ping the
-- same players in the same tick; they are looked at again 15 seconds later.)
-- The match is never started here. quick_match_atomic stays as it is, for old builds.
-- Counts: queue/{join,matched,expired,ready_yes,ready_no} (20261119000700).
-- Push kinds: 'queue_ready', 'queue_expired' and 'play_night' (20261119000900) are
-- added to push_outbox_kind_check and to the non-gentle claim bucket here,
-- keeping every kind that 20261119000300 has.
-- Idempotent.

create table if not exists public.match_queue (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  gender text not null,
  joined_at timestamptz not null default now(),
  round_id uuid,
  round_deadline timestamptz,
  confirmed boolean not null default false,
  misses smallint not null default 0
);
alter table public.match_queue enable row level security;
revoke all on public.match_queue from anon, authenticated;
create index if not exists match_queue_waiting on public.match_queue(joined_at, user_id) where round_id is null;
create index if not exists match_queue_round on public.match_queue(round_id) where round_id is not null;

-- The caller's current seat in a lobby or playing room, not kicked and not
-- left, as the answer a client reads: {roomId, code, seat}. Null when none.
create or replace function public.queue_current_seat(p_user uuid)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object('roomId', r.id, 'code', r.code, 'seat', p.seat)
    from public.room_players p
    join public.rooms r on r.id = p.room_id
   where p.user_id = p_user and not p.kicked and p.status is distinct from 'left'
     and r.status in ('lobby', 'playing')
   order by r.created_at desc, r.id
   limit 1
$$;
revoke all on function public.queue_current_seat(uuid) from public, anon, authenticated;
grant execute on function public.queue_current_seat(uuid) to service_role;

create or replace function public.queue_join(p_user uuid, p_name text, p_gender text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  c record; candidate text; result jsonb; seat jsonb; accepting boolean;
  was_queued boolean; waiting integer;
begin
  if p_user is null or length(btrim(coalesce(p_name, ''))) not between 1 and 20 then
    raise exception 'BAD_REQUEST';
  end if;
  if public.safety_restricted(p_user, 'public_rooms') then raise exception 'ACCOUNT_RESTRICTED'; end if;

  -- Already seated in a lobby or a match: that is the answer, nothing is queued.
  seat := public.queue_current_seat(p_user);
  if seat is not null then
    delete from public.match_queue where user_id = p_user;
    return seat || jsonb_build_object('rejoined', true, 'created', false);
  end if;

  if not public.safety_name_allowed(btrim(p_name), 'name') then raise exception 'NAME_NOT_ALLOWED'; end if;

  -- The same lock quick match takes, so the two never seat people in each
  -- other's way. A public classic lobby with at least one connected player
  -- and a free seat is seated exactly as quick_match_atomic seats.
  perform pg_advisory_xact_lock(hashtext('quick_match:classic'));
  for c in select * from public.quick_match_candidates(p_user) loop
    continue when not exists (
      select 1 from public.room_players p
       where p.room_id = c.room_id and p.connected and not p.kicked);
    continue when not public.safety_room_compatible(c.room_id, p_user);
    select r.code into candidate from public.rooms r
     where r.id = c.room_id and r.status = 'lobby' for update skip locked;
    exit when candidate is not null;
  end loop;
  if candidate is not null then
    result := public.join_room_atomic(candidate, p_user, p_name, p_gender);
    delete from public.match_queue where user_id = p_user;
    return result || jsonb_build_object('code', candidate, 'created', false);
  end if;

  -- Nobody to sit with: wait in the queue. Rooms are paused -> nothing to wait for.
  select new_rooms_enabled into accepting from public.operations_control where singleton = true;
  if accepting is false then raise exception 'NEW_ROOMS_PAUSED'; end if;
  was_queued := exists (select 1 from public.match_queue where user_id = p_user);
  insert into public.match_queue(user_id, name, gender)
    values (p_user, btrim(p_name), coalesce(nullif(btrim(p_gender), ''), 'unspecified'))
    on conflict (user_id) do update set name = excluded.name, gender = excluded.gender;
  if not was_queued then perform public.metric_note(p_user, 'queue', 'join'); end if;
  select count(*) into waiting from public.match_queue;
  return jsonb_build_object('queued', true, 'count', waiting);
end $$;

create or replace function public.queue_leave(p_user uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare n integer;
begin
  delete from public.match_queue where user_id = p_user;
  get diagnostics n = row_count;
  return n > 0;
end $$;

create or replace function public.queue_status(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare q public.match_queue; waiting integer; rnd jsonb := null; me jsonb := null;
begin
  select count(*) into waiting from public.match_queue;
  select * into q from public.match_queue where user_id = p_user;
  if q.user_id is not null then
    me := jsonb_build_object('confirmed', q.confirmed);
    if q.round_id is not null then
      rnd := (select jsonb_build_object('id', q.round_id, 'deadline', q.round_deadline,
                'confirmed', count(*) filter (where m.confirmed), 'total', count(*))
                from public.match_queue m where m.round_id = q.round_id);
    end if;
  end if;
  return jsonb_build_object(
    'queued', q.user_id is not null, 'count', waiting,
    'round', rnd, 'me', me, 'room', public.queue_current_seat(p_user));
end $$;

create or replace function public.queue_ready(p_user uuid, p_round uuid, p_yes boolean)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare q public.match_queue;
begin
  select * into q from public.match_queue where user_id = p_user for update;
  if not found or p_round is null or q.round_id is distinct from p_round
     or q.round_deadline is null or q.round_deadline <= now() then
    raise exception 'ROUND_CLOSED';
  end if;
  if coalesce(p_yes, false) then
    update public.match_queue set confirmed = true where user_id = p_user;
    perform public.metric_note(p_user, 'queue', 'ready_yes');
    return jsonb_build_object('queued', true, 'confirmed', true);
  end if;
  delete from public.match_queue where user_id = p_user;
  perform public.metric_note(p_user, 'queue', 'ready_no');
  return jsonb_build_object('queued', false, 'confirmed', false);
end $$;

-- Builds the one public room for a closed round from the confirmed players,
-- in the order given: the first who can sit is the host, the rest join.
-- Returns how many were seated. A player who cannot be seated because of a
-- restriction or an unacceptable name leaves the queue; one who cannot be
-- seated for any other reason keeps their place.
create or replace function public.queue_make_room(p_users uuid[])
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare
  q record; new_code text; room_code text; seed bigint; attempt integer;
  seated integer := 0; outcome text;
begin
  for q in
    select m.user_id, m.name, m.gender
      from unnest(p_users) with ordinality t(uid, ord)
      join public.match_queue m on m.user_id = t.uid
     order by t.ord
  loop
    outcome := 'keep';
    if room_code is null then
      for attempt in 1..8 loop
        select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
          1 + floor(random() * 32)::integer, 1), '') into new_code
          from generate_series(1, 6);
        seed := floor(random() * 2147483647)::bigint;
        begin
          perform public.create_room_atomic(
            new_code, q.user_id, q.name, q.gender, seed,
            jsonb_build_object(
              'visibility', 'public', 'title', 'لعب سريع',
              'settings', jsonb_build_object(
                'maxPlayers', 10, 'voice', true, 'muteAllAtNight', true,
                'speechSeconds', 45, 'discussionSeconds', 180,
                'openVoting', false, 'traceEnabled', true,
                'discussionMode', 'structured', 'confrontationEnabled', true,
                'whisperEnabled', true, 'scenarioCode', 'classic',
                'autoStart', true)));
          room_code := new_code;
          outcome := 'seated';
          exit;
        exception
          when unique_violation then
            outcome := 'retry';
          when others then
            outcome := case when sqlerrm like '%ACCOUNT_RESTRICTED%' or sqlerrm like '%NAME_NOT_ALLOWED%'
                            then 'drop' else 'keep' end;
            exit;
        end;
      end loop;
    else
      begin
        perform public.join_room_atomic(room_code, q.user_id, q.name, q.gender);
        outcome := 'seated';
      exception when others then
        outcome := case when sqlerrm like '%ACCOUNT_RESTRICTED%' or sqlerrm like '%NAME_NOT_ALLOWED%'
                        then 'drop' else 'keep' end;
      end;
    end if;

    if outcome = 'seated' then
      seated := seated + 1;
      delete from public.match_queue where user_id = q.user_id;
      perform public.metric_note(q.user_id, 'queue', 'matched');
    elsif outcome = 'drop' then
      delete from public.match_queue where user_id = q.user_id;
    end if;
  end loop;
  return seated;
end $$;

-- Every 15 seconds (pg_cron). Returns how much it did: rows expired, rounds
-- closed and rounds opened. A second tick while one runs does nothing.
create or replace function public.queue_tick()
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_now timestamptz := now();
  accepting boolean; work integer := 0; closed_any boolean := false;
  rd record; ids uuid[]; confirmed_ids uuid[]; waiting integer; rid uuid; u uuid;
begin
  if not pg_try_advisory_xact_lock(hashtext('match_queue:tick')) then return 0; end if;
  select new_rooms_enabled into accepting from public.operations_control where singleton = true;

  -- Someone who sat down somewhere else is no longer waiting.
  delete from public.match_queue m
   where exists (
     select 1 from public.room_players p join public.rooms r on r.id = p.room_id
      where p.user_id = m.user_id and not p.kicked and p.status is distinct from 'left'
        and r.status in ('lobby', 'playing'));

  -- (c) Two hours without a match: out, and told once.
  with d as (
    delete from public.match_queue where joined_at < v_now - interval '2 hours' returning user_id)
  select array_agg(user_id) into ids from d;
  if ids is not null then
    work := work + array_length(ids, 1);
    perform public.push_enqueue('queue_expired', ids, '{}'::jsonb,
      'queue_expired:' || to_char((v_now at time zone 'utc')::date, 'YYYY-MM-DD'), interval '6 hours');
    foreach u in array ids loop
      perform public.metric_note(u, 'queue', 'expired');
    end loop;
  end if;

  -- (b) Close the rounds that are over: the deadline passed, or everyone who is
  -- left said yes.
  for rd in
    select m.round_id from public.match_queue m
     where m.round_id is not null
     group by m.round_id
    having max(m.round_deadline) <= v_now or bool_and(m.confirmed)
  loop
    perform 1 from public.match_queue where round_id = rd.round_id for update;
    confirmed_ids := array(
      select m.user_id from public.match_queue m
       where m.round_id = rd.round_id and m.confirmed
       order by m.joined_at, m.user_id);
    if coalesce(array_length(confirmed_ids, 1), 0) >= 5 and accepting is not false then
      perform public.queue_make_room(confirmed_ids);
    end if;
    -- Whoever is still in the round: the yes players keep their place, the
    -- silent ones take a miss; a second miss removes them.
    update public.match_queue
       set misses = (misses + case when confirmed then 0 else 1 end)::smallint,
           round_id = null, round_deadline = null, confirmed = false
     where round_id = rd.round_id;
    delete from public.match_queue where misses >= 2;
    work := work + 1;
    closed_any := true;
  end loop;

  -- (a) Open rounds: 5 or more waiting without a round -> the oldest 10.
  -- Not in a tick that just closed one: the people it sent back wait for the next.
  while accepting is not false and not closed_any loop
    select count(*) into waiting from public.match_queue where round_id is null;
    exit when waiting < 5;
    rid := gen_random_uuid();
    with picked as (
      select user_id from public.match_queue
       where round_id is null
       order by joined_at, user_id
       limit 10
       for update),
    upd as (
      update public.match_queue m
         set round_id = rid, round_deadline = v_now + interval '60 seconds', confirmed = false
        from picked where m.user_id = picked.user_id
      returning m.user_id)
    select array_agg(user_id) into ids from upd;
    exit when ids is null;
    perform public.push_enqueue('queue_ready', ids, '{}'::jsonb,
      'queue_ready:' || rid, interval '2 minutes');
    work := work + 1;
  end loop;

  return work;
end $$;

revoke all on function public.queue_join(uuid, text, text) from public, anon, authenticated;
revoke all on function public.queue_leave(uuid) from public, anon, authenticated;
revoke all on function public.queue_status(uuid) from public, anon, authenticated;
revoke all on function public.queue_ready(uuid, uuid, boolean) from public, anon, authenticated;
revoke all on function public.queue_make_room(uuid[]) from public, anon, authenticated;
revoke all on function public.queue_tick() from public, anon, authenticated;
grant execute on function public.queue_join(uuid, text, text) to service_role;
grant execute on function public.queue_leave(uuid) to service_role;
grant execute on function public.queue_status(uuid) to service_role;
grant execute on function public.queue_ready(uuid, uuid, boolean) to service_role;
grant execute on function public.queue_make_room(uuid[]) to service_role;
grant execute on function public.queue_tick() to service_role;

-- Push kinds, as 20261119000300 plus queue_ready / queue_expired / play_night. All three are game
-- notifications like room_start (never the gentle daily ones), so they ride the second claim bucket.
alter table public.push_outbox drop constraint if exists push_outbox_kind_check;
alter table public.push_outbox add constraint push_outbox_kind_check
  check (kind in ('room_start','night','daily','thursday','comeback','app_update','rooms_gathering',
                  'queue_ready','queue_expired','play_night',
                  'owner_order','owner_claimed','owner_play','owner_report','owner_tester','owner_feedback'));

create or replace function public.push_outbox_claim(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $function$
declare
  enabled boolean := coalesce((select push_invites_enabled from public.economy_config limit 1),false);
  out jsonb;
begin
  update public.push_outbox
     set status='pending', claimed_at=null
   where status='processing'
     and claimed_at < now()-interval '2 minutes'
     and expires_at >= now();
  with picked as (
    -- One gentle kind per player per batch: the rest wait for the next drain,
    -- where the 20-hour rule below sees what was just sent.
    select id from public.push_outbox where status='pending' and id in (
        select w.id from (select id, kind,
            row_number() over (partition by user_id order by id) rn
          from public.push_outbox
         where status='pending' and kind in ('daily','thursday','comeback')) w
         where w.rn=1
        union all
        select id from public.push_outbox
         where status='pending' and kind in ('room_start','rooms_gathering','night','app_update',
           'queue_ready','queue_expired','play_night',
           'owner_order','owner_claimed','owner_play','owner_report','owner_tester','owner_feedback'))
     order by id limit greatest(1,least(p_limit,500)) for update skip locked
  ), upd as (
    update public.push_outbox o set claimed_at=now(),
      status = case
        -- The player switch holds back players' pushes, never the owner's.
        when not enabled and left(o.kind, 6) <> 'owner_' then 'skipped'
        when o.expires_at < now() then 'skipped'
        when o.kind in ('daily','thursday','comeback') and exists (
          select 1 from public.push_outbox x
           where x.user_id=o.user_id and x.id<>o.id and x.status='sent'
             and x.kind in ('daily','thursday','comeback')
             and x.claimed_at > now()-interval '20 hours') then 'skipped'
        else 'processing' end
    from picked where o.id=picked.id
    returning o.id, o.user_id, o.kind, o.payload, o.status
  )
  -- An update notice goes only to the player's Android devices still behind it.
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',u.id,'kind',u.kind,'payload',u.payload,
      'tokens',(select coalesce(jsonb_agg(jsonb_build_object('token',t.token,'platform',t.platform,'build',t.app_build)
                  order by t.updated_at desc),'[]'::jsonb)
                  from public.push_tokens t where t.user_id=u.user_id
                   and (u.kind<>'app_update' or (t.platform='android'
                     and (t.app_build is null
                          or t.app_build < coalesce((u.payload->>'build')::int,0))))))),'[]'::jsonb)
    into out from upd u where u.status='processing';
  return out;
end $function$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'match-queue-tick') then
      perform cron.unschedule('match-queue-tick');
    end if;
    perform cron.schedule('match-queue-tick', '15 seconds', 'select public.queue_tick();');
  end if;
end $$;
