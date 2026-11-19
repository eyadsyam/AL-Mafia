-- Contract for 20261119000900_play_night (O2 «ليلة اللعب»). Rolled back.
-- Fixed clocks: 2026-11-18 is a Wednesday and Cairo is UTC+2 then; 2026-11-19 is a
-- Thursday; 2026-07-15 is a Wednesday and Cairo is UTC+3 (daylight saving).
begin;

create function pg_temp.pn_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

create function pg_temp.pn_metric(p_prop text) returns bigint language sql as $$
  select coalesce((select sum(total) from public.product_metric_daily
                    where event='play_night' and prop=p_prop),0)
$$;

do $$
declare
  u uuid[] := array[]::uuid[];
  i int; s jsonb; n int; before_remind bigint; before_push bigint;
  wed timestamptz := '2026-11-18 18:50:00+00';   -- 20:50 in Cairo
  room uuid := gen_random_uuid();
begin
  update public.economy_config set push_invites_enabled=true, friends_enabled=true;
  update public.rooms set visibility='private' where visibility='public';
  delete from public.match_queue;
  for i in 1..9 loop
    u := u || pg_temp.pn_user();
    perform public.push_token_register(u[i], repeat(chr(96+i),40), 'android');
  end loop;

  -- 1. The times. Before 21:00, inside the window, after it (-> tomorrow), and in summer time.
  s := public.play_night_status(u[1], '2026-11-18 17:30:00+00');
  assert (s->>'startsAt')::timestamptz='2026-11-18 19:00:00+00', s::text;
  assert (s->>'endsAt')::timestamptz='2026-11-18 20:00:00+00', s::text;
  assert not (s->>'active')::boolean, s::text;
  s := public.play_night_status(u[1], '2026-11-18 19:00:00+00');
  assert (s->>'active')::boolean, 'active from 21:00 Cairo';
  s := public.play_night_status(u[1], '2026-11-18 19:59:00+00');
  assert (s->>'active')::boolean, s::text;
  s := public.play_night_status(u[1], '2026-11-18 20:00:00+00');
  assert not (s->>'active')::boolean, 'over at 22:00 Cairo';
  assert (s->>'startsAt')::timestamptz='2026-11-19 19:00:00+00', 'after the window: tomorrow ('||s::text||')';
  s := public.play_night_status(u[1], '2026-11-18 22:30:00+00');
  assert (s->>'startsAt')::timestamptz='2026-11-19 19:00:00+00', s::text;
  s := public.play_night_status(u[1], '2026-07-15 17:00:00+00');
  assert (s->>'startsAt')::timestamptz='2026-07-15 18:00:00+00', 'summer time: 21:00 is 18:00 UTC ('||s::text||')';
  assert (s->>'endsAt')::timestamptz='2026-07-15 19:00:00+00', s::text;
  -- Just after midnight Cairo is still tonight's calendar day of the NEXT night.
  s := public.play_night_status(u[1], '2026-11-18 22:30:00+00');
  assert (s->>'queueCount')::int=0, s::text;
  insert into public.match_queue(user_id,name,gender) values (u[9],'Q9','male');
  assert (public.play_night_status(u[1], wed)->>'queueCount')::int=1;
  delete from public.match_queue;

  -- 2. Remind on and off; the number shows only from five.
  before_remind := pg_temp.pn_metric('remind');
  assert public.play_night_remind(u[1], true, wed);
  assert public.play_night_remind(u[1], true, wed), 'a second "on" changes nothing';
  assert pg_temp.pn_metric('remind')=before_remind+1, 'counted once';
  s := public.play_night_status(u[1], wed);
  assert (s->>'reminded')::boolean, s::text;
  assert s->'remindedCount' = 'null'::jsonb, 'one is below five: '||s::text;
  assert not (public.play_night_status(u[2], wed)->>'reminded')::boolean;
  assert not public.play_night_remind(u[1], false, wed);
  assert not (public.play_night_status(u[1], wed)->>'reminded')::boolean;
  assert public.play_night_remind(u[1], true, wed);
  for i in 2..4 loop perform public.play_night_remind(u[i], true, wed); end loop;
  assert (public.play_night_status(u[1], wed)->'remindedCount') = 'null'::jsonb, 'four is still below five';
  perform public.play_night_remind(u[5], true, wed);
  assert (public.play_night_status(u[6], wed)->>'remindedCount')::int=5, 'five shows';
  -- A reminder after the window belongs to the next night.
  perform public.play_night_remind(u[6], true, '2026-11-18 22:30:00+00');
  assert (public.play_night_status(u[6], '2026-11-19 10:00:00+00')->>'reminded')::boolean;
  assert not (public.play_night_status(u[6], wed)->>'reminded')::boolean;
  delete from public.play_night_reminders where user_id=u[6];

  -- 3. The push: reminders (u1..u5) and recent players (u7 played 3 days ago, u8 40 days ago);
  --    u2 sits in a lobby and is skipped.
  insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,reunion,created_at)
    values (u[7],gen_random_uuid(),wed-interval '3 days',(wed-interval '3 days')::date,'w','town',true,false,false,wed-interval '3 days'),
           (u[8],gen_random_uuid(),wed-interval '40 days',(wed-interval '40 days')::date,'w','town',true,false,false,wed-interval '40 days');
  insert into public.rooms(id,code,host_id,match_seed,status,visibility)
    values(room,'QPN2AB',u[2],9,'lobby','private');
  insert into public.room_players(room_id,user_id,name,seat,connected) values(room,u[2],'Seated',0,true);

  -- Too early (20:40) and too late (21:00): nothing, and nothing is spent.
  assert public.play_night_push('2026-11-18 18:40:00+00')=0;
  assert public.play_night_push('2026-11-18 19:00:00+00')=0;
  assert not exists(select 1 from public.play_night_sent);

  before_push := pg_temp.pn_metric('push');
  n := public.play_night_push(wed);
  assert n>=5, 'u1,u3,u4,u5 (reminded) and u7 (recent) = 5, got '||n;
  assert (select count(*) from public.push_outbox where kind='play_night' and user_id=any(u) and status='pending')=5;
  assert exists(select 1 from public.push_outbox where kind='play_night' and user_id=u[7]);
  assert not exists(select 1 from public.push_outbox where kind='play_night' and user_id=u[2]), 'seated player skipped';
  assert not exists(select 1 from public.push_outbox where kind='play_night' and user_id=u[8]), '40 days ago is not recent';
  assert not exists(select 1 from public.push_outbox where kind='play_night' and user_id=u[6]);
  assert pg_temp.pn_metric('push')=before_push+n, 'one push count per recipient';
  assert (select recipients from public.play_night_sent where night='2026-11-18')=n;
  -- A second run the same evening, even a few minutes later, sends nothing.
  assert public.play_night_push('2026-11-18 18:55:00+00')=0;
  assert (select count(*) from public.push_outbox where kind='play_night' and user_id=any(u))=5;
  assert (select count(*) from public.play_night_sent where night='2026-11-18')=1;

  -- 4. Thursday (Cairo): Thursday Night has its own push, so nothing here.
  assert public.play_night_push('2026-11-19 18:50:00+00')=0, 'thursday is skipped';
  assert not exists(select 1 from public.play_night_sent where night='2026-11-19');
  -- Friday sends again (20:50 Cairo, summer or winter).
  perform public.play_night_remind(u[9], true, '2026-11-20 18:50:00+00');
  assert public.play_night_push('2026-11-20 18:50:00+00')>=1, 'friday sends';
  assert exists(select 1 from public.push_outbox where kind='play_night' and user_id=u[9]);
  -- Summer time: the same evening is 17:50 UTC.
  assert public.play_night_push('2026-07-15 17:50:00+00')>=0;
  assert exists(select 1 from public.play_night_sent where night='2026-07-15'), 'summer window 20:45-21:00 Cairo';
  assert public.play_night_push('2026-07-15 18:50:00+00')=0, '21:50 Cairo is outside';

  -- 5. Only the service role may call any of it.
  assert not has_function_privilege('anon','public.play_night_status(uuid,timestamptz)','execute');
  assert not has_function_privilege('authenticated','public.play_night_status(uuid,timestamptz)','execute');
  assert not has_function_privilege('anon','public.play_night_remind(uuid,boolean,timestamptz)','execute');
  assert not has_function_privilege('authenticated','public.play_night_remind(uuid,boolean,timestamptz)','execute');
  assert not has_function_privilege('anon','public.play_night_push(timestamptz)','execute');
  assert not has_function_privilege('authenticated','public.play_night_push(timestamptz)','execute');
  assert not has_function_privilege('authenticated','public.play_night_window(timestamptz)','execute');
  assert has_function_privilege('service_role','public.play_night_push(timestamptz)','execute');
  assert not has_table_privilege('anon','public.play_night_reminders','select');
  assert not has_table_privilege('authenticated','public.play_night_reminders','select');
  assert not has_table_privilege('authenticated','public.play_night_sent','select');
  assert (select relrowsecurity from pg_class where oid='public.play_night_reminders'::regclass);
  assert (select relrowsecurity from pg_class where oid='public.play_night_sent'::regclass);
  raise notice 'play_night PASS';
end $$;

rollback;
