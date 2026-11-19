-- Contract for 20261119000700_honest_usage (O6): harness rooms leave the usage
-- counters and the owner's daily page; the queue / play_night counts exist. Rolled back.
begin;

create function pg_temp.hu_room(p_code text, p_names text[]) returns uuid language plpgsql as $$
declare r uuid; i int;
begin
  insert into public.rooms(code,host_id,match_seed) values(p_code,gen_random_uuid(),7) returning id into r;
  for i in 1..array_length(p_names,1) loop
    insert into public.room_players(room_id,user_id,name,seat,role,kicked)
      values(r,gen_random_uuid(),p_names[i],i-1,case when i=1 then 'mafia' else 'citizen' end,false);
  end loop;
  return r;
end $$;

create function pg_temp.hu_usage(p_col text) returns bigint language plpgsql as $$
declare v bigint;
begin
  execute format('select coalesce((select %I from public.usage_daily where day=(now() at time zone ''utc'')::date),0)', p_col) into v;
  return v;
end $$;

do $$
declare
  harness uuid; real_room uuid; mixed uuid; half uuid; hab uuid; rab uuid; empty_room uuid;
  admin uuid := gen_random_uuid();
  b_created bigint := pg_temp.hu_usage('rooms_created');
  b_started bigint := pg_temp.hu_usage('matches_started');
  b_finished bigint := pg_temp.hu_usage('matches_finished');
  b_aband bigint := pg_temp.hu_usage('abandoned_rooms');
  b_players bigint := pg_temp.hu_usage('player_matches');
  before_page jsonb; after_page jsonb; today_before jsonb; today_after jsonb; rid uuid; e text;
begin
  insert into public.commerce_admins(user_id,note) values(admin,'honest usage test');
  before_page := public.owner_review_usage(admin);
  today_before := before_page->'items'->0;

  harness   := pg_temp.hu_room('QHU2AB', array['Amina','Bassem','Camelia','Dawoud','Enas']);
  real_room := pg_temp.hu_room('QHU2AC', array['Layan','Mostafa','Dalia','Tarek','Mona']);
  mixed     := pg_temp.hu_room('QHU2AD', array['Amina','Layan','Mostafa','Dalia','Tarek']);
  half      := pg_temp.hu_room('QHU2AE', array['Amina','Bassem','Camelia','Dawoud','Layan']);
  hab       := pg_temp.hu_room('QHU2AF', array['Rami','Taha','Wafa','Uday','Mona']);
  rab       := pg_temp.hu_room('QHU2AG', array['Layan','Mostafa','Dalia','Tarek','Mona']);
  empty_room := gen_random_uuid();

  assert public.is_harness_room(harness), 'five harness names';
  assert not public.is_harness_room(real_room), 'real names';
  assert not public.is_harness_room(mixed), 'one harness name among five is a real room';
  assert public.is_harness_room(half), 'four of five (80%) counts';
  assert public.is_harness_room(hab), 'four of five';
  assert not public.is_harness_room(empty_room), 'no seats, no harness';
  -- The bot names of play_with_app / new_roles_tools_match count too.
  update public.room_players set name='LiveBot'||seat where room_id=rab and seat in (0,1,2,3);
  assert public.is_harness_room(rab);
  update public.room_players set name=(array['Layan','Mostafa','Dalia','Tarek'])[seat+1] where room_id=rab and seat in (0,1,2,3);
  assert not public.is_harness_room(rab);

  assert pg_temp.hu_usage('rooms_created')=b_created+6, 'all six counted when created';

  -- Start four of them, finish them; abandon two from the lobby.
  update public.rooms set status='playing' where id in (harness, real_room, mixed, half);
  assert pg_temp.hu_usage('matches_started')=b_started+2, 'only real rooms start: '||(pg_temp.hu_usage('matches_started')-b_started);
  update public.rooms set status='finished', ended_at=now()+interval '2 minutes'
    where id in (harness, real_room, mixed, half);
  update public.rooms set status='finished', ended_at=now() where id in (hab, rab);
  assert pg_temp.hu_usage('matches_finished')=b_finished+2, 'only real rooms finish';
  assert pg_temp.hu_usage('abandoned_rooms')=b_aband+1, 'only the real abandoned room counts';
  assert pg_temp.hu_usage('player_matches')=b_players+10, 'players of real matches only';
  assert pg_temp.hu_usage('rooms_created')=b_created+3, 'harness rooms taken back out once each: '||(pg_temp.hu_usage('rooms_created')-b_created);

  -- The owner's page: receipts and match records of harness rooms do not show.
  foreach rid in array array[harness, real_room] loop
    -- A receipt is only written once the room is at its result.
    insert into public.room_state(room_id,phase) values(rid,'result');
    insert into public.match_receipts(user_id,room_id,day,week,ended_at,won,human_count,
        roster_fingerprint,day_ordinal,roster_ordinal,completion_coins,win_coins,
        first_day_coins,season_xp,council_xp)
      values(gen_random_uuid(),rid,(now() at time zone 'utc')::date,'x',now(),false,5,repeat('a',64),1,1,25,0,0,5,30),
            (gen_random_uuid(),rid,(now() at time zone 'utc')::date,'x',now(),false,5,repeat('b',64),1,1,25,0,0,5,30);
    insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,reunion)
      values(gen_random_uuid(),rid,now(),(now() at time zone 'utc')::date,'x','town',false,false,false),
            (gen_random_uuid(),rid,now(),(now() at time zone 'utc')::date,'x','town',false,false,false);
  end loop;
  after_page := public.owner_review_usage(admin);
  today_after := after_page->'items'->0;
  assert (today_after->>'onlinePlayers')::int=(today_before->>'onlinePlayers')::int+2,
    'only the two players of the real room: '||today_after::text;
  assert (today_after->>'onlineMatches')::int=(today_before->>'onlineMatches')::int+1,
    'only the match of the real room: '||today_after::text;

  -- The new counts pass the allow-list; near misses do not.
  foreach e in array array['join','matched','expired','ready_yes','ready_no'] loop
    perform public.metric_record(admin,'queue',e,gen_random_uuid());
  end loop;
  foreach e in array array['remind','push'] loop
    perform public.metric_record(admin,'play_night',e,gen_random_uuid());
  end loop;
  foreach e in array array['','ready','remind','join:x','Join'] loop
    begin
      perform public.metric_record(admin,'queue',e,gen_random_uuid());
      raise exception 'queue prop accepted: %',e;
    exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  end loop;
  foreach e in array array['','join','matched','push:x'] loop
    begin
      perform public.metric_record(admin,'play_night',e,gen_random_uuid());
      raise exception 'play_night prop accepted: %',e;
    exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  end loop;
  -- Older pairs still pass, and a replayed request id is not counted twice.
  perform public.metric_record(admin,'online_action','home_line',gen_random_uuid());
  perform public.metric_record(admin,'first_run','done',gen_random_uuid());
  perform public.metric_record(admin,'app_open','',gen_random_uuid());
  rid := gen_random_uuid();
  perform public.metric_record(admin,'queue','join',rid);
  assert (public.metric_record(admin,'queue','join',rid)->>'replayed')::boolean;
  -- metric_note never raises.
  perform public.metric_note(admin,'queue','not_a_prop');
  perform public.metric_note(null,'queue','join');
  today_after := public.owner_review_usage(admin)->'items'->0;
  assert (today_after->'events'->>'queue/join')::int>=2, today_after::text;
  assert (today_after->'events'->>'play_night/push')::int>=1, today_after::text;
  assert not (today_after->'events' ? 'queue/not_a_prop');

  assert not has_function_privilege('anon','public.is_harness_room(uuid)','execute');
  assert not has_function_privilege('authenticated','public.is_harness_room(uuid)','execute');
  assert not has_function_privilege('authenticated','public.metric_note(uuid,text,text)','execute');
  assert has_function_privilege('service_role','public.is_harness_room(uuid)','execute');
  raise notice 'honest_usage PASS';
end $$;

rollback;
