begin;
do $$
declare
  u uuid:=gen_random_uuid(); users uuid[]; rid uuid; wrong uuid; crossing uuid;
  third uuid; request uuid:=gen_random_uuid(); first_create jsonb; replay jsonb;
  s jsonb; bal bigint; season bigint; i int;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u,u::text||'@thursday.test',now(),false);
  select id into season from public.mission_seasons where code='season_zero';
  update public.mission_seasons set active=true,
    starts_at='2026-10-15 00:00+00',ends_at='2026-11-12 00:00+00'
    where id=season;

  -- Dark by default; the capability is added without disturbing the chain.
  assert public.economy_capabilities(u)->'thursday'='false'::jsonb,'dark capability';
  update public.economy_config set thursday_event_enabled=true,missions_enabled=true;
  assert public.economy_capabilities(u)->'thursday'='true'::jsonb,'enabled capability';

  -- Cairo window bounds during DST.
  s:=public.thursday_cairo_state('2026-10-22 19:59:00+03');
  assert (s->>'isThursday')::boolean and not (s->>'inWindow')::boolean,s::text;
  s:=public.thursday_cairo_state('2026-10-22 20:00:00+03');
  assert (s->>'isThursday')::boolean and (s->>'inWindow')::boolean,s::text;
  s:=public.thursday_cairo_state('2026-10-23 00:59:59+03');
  assert not (s->>'isThursday')::boolean and (s->>'inWindow')::boolean,s::text;
  s:=public.thursday_cairo_state('2026-10-23 01:00:00+03');
  assert not (s->>'inWindow')::boolean,s::text;
  s:=public.thursday_cairo_state('2026-10-22 02:00:00+03');
  assert (s->>'isThursday')::boolean and not (s->>'inWindow')::boolean,s::text;

  -- Egypt changes from UTC+3 to UTC+2 at the end of the last October
  -- Thursday. Both repeated sides still belong to the same Cairo event.
  s:=public.thursday_cairo_state('2026-10-29 23:30:00+03');
  assert (s->>'inWindow')::boolean and s->>'eventWeek'='2026-10-29',s::text;
  s:=public.thursday_cairo_state('2026-10-29 23:30:00+02');
  assert (s->>'inWindow')::boolean and s->>'eventWeek'='2026-10-29',s::text;

  -- eventCreateRoom owns the canonical stored fingerprint and replays the
  -- first response even after the Thursday boundary has passed.
  insert into public.council_identity(user_id,name,gender)
    values(u,'Thursday Host','female');
  first_create:=public.event_create_room(u,'thursday',request,'THUR88',17,
    '2026-10-29 21:00:00+02');
  replay:=public.event_create_room(u,'thursday',request,'REPL88',99,
    '2026-10-30 02:00:00+02');
  assert first_create->>'roomId'=replay->>'roomId' and (replay->>'replayed')::boolean,
    replay::text;
  assert (select scenario_fingerprint=public.thursday_preset_fingerprint()
    and settings=public.thursday_preset() from public.rooms
    where id=(first_create->>'roomId')::uuid),'event preset was not canonical';
  -- The event room is listed in «أوض عامة», marked from its fingerprint.
  assert (select visibility='public' and title='ليلة الخميس' from public.rooms
    where id=(first_create->>'roomId')::uuid),'event room was not public';
  assert exists(select 1 from public.public_room_listing_v3(u) l
    join public.rooms r on r.code=l.code
    where r.id=(first_create->>'roomId')::uuid and l.thursday),
    'event room not marked in the listing';
  assert not exists(select 1 from public.public_room_listing_v3(u) l
    where l.thursday and l.code<>(select code from public.rooms
      where id=(first_create->>'roomId')::uuid)),'a plain room marked Thursday';
  assert (select count(*) from public.thursday_event_receipts
    where creator_id=u and request_id=request)=1,'request replay duplicated receipt';

  select coalesce(balance,0) into bal from public.wallet_accounts where user_id=u;
  bal:=coalesce(bal,0);

  -- Helper data: every room has five eligible non-kicked humans. The first
  -- starts Thursday and ends Friday, proving start time owns the window.
  users:=array[u];
  for i in 1..4 loop
    users:=users||gen_random_uuid();
    insert into auth.users(id,email,email_confirmed_at,is_anonymous)
      values(users[i+1],users[i+1]::text||'@thursday.test',now(),false);
  end loop;
  crossing:=gen_random_uuid();
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at,
      scenario_fingerprint,settings)
    values(crossing,'CRSS88',u,'finished',1,'2026-10-29 23:59:00+02',
      '2026-10-30 01:10:00+02',public.thursday_preset_fingerprint(),
      public.thursday_preset());
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(crossing,users[i],i-1,'P'||i,case when i=2 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(crossing,'result','{"outcome":"town"}');
  assert public.council_record_match(u,crossing),'crossing room not recorded';
  assert (select ordinal=1 and xp=20 and not stamp_granted
    from public.thursday_participation where user_id=u and room_id=crossing);

  -- A matching eligible result with the wrong stored fingerprint earns zero.
  wrong:=gen_random_uuid();
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at,
      scenario_fingerprint,settings)
    values(wrong,'WRNG88',u,'finished',2,'2026-10-29 20:30:00+02',
      '2026-10-29 21:30:00+02',md5('wrong'),public.thursday_preset());
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(wrong,users[i],i-1,'P'||i,case when i=2 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(wrong,'result','{"outcome":"town"}');
  assert public.council_record_match(u,wrong),'wrong fingerprint base receipt missing';
  assert not exists(select 1 from public.thursday_participation where room_id=wrong),
    'wrong fingerprint earned Thursday credit';

  -- A second canonical match grants the one community stamp; a third grants
  -- neither XP nor another stamp.
  foreach rid in array array[gen_random_uuid(),gen_random_uuid()] loop
    users:=array[u];
    for i in 1..4 loop
      users:=users||gen_random_uuid();
      insert into auth.users(id,email,email_confirmed_at,is_anonymous)
        values(users[i+1],users[i+1]::text||'@thursday.test',now(),false);
    end loop;
    insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at,
        scenario_fingerprint,settings)
      values(rid,case when third is null then 'SECN88' else 'THRD88' end,u,
        'finished',3,'2026-10-29 22:00:00+02','2026-10-29 23:00:00+02',
        public.thursday_preset_fingerprint(),public.thursday_preset());
    for i in 1..5 loop
      insert into public.room_players(room_id,user_id,seat,name,role)
        values(rid,users[i],i-1,'Q'||i,case when i=2 then 'mafia' else 'citizen' end);
    end loop;
    insert into public.room_state(room_id,phase,public_data)
      values(rid,'result','{"outcome":"town"}');
    assert public.council_record_match(u,rid),'capped room base receipt missing';
    if third is null then third:=rid; else third:=rid; end if;
  end loop;
  assert (select count(*) from public.thursday_participation
    where user_id=u and event_week='2026-10-29')=2,'weekly cap failed';
  assert (select count(*) from public.thursday_participation
    where user_id=u and event_week='2026-10-29' and stamp_granted)=1,
    'community stamp was not exactly once';
  assert (select eligible_matches=2 and season_xp=40 and stamp_granted
    from public.thursday_aggregates where user_id=u and event_week='2026-10-29');
  assert (select count(*)=2 and sum(xp)=40 from public.season_xp_events
    where user_id=u and source_key like 'thursday:%'),'Thursday XP cap failed';
  assert coalesce((select balance from public.wallet_accounts where user_id=u),0)=bal,
    'Thursday granted coins';

  -- Recording and creation replays are idempotent.
  perform public.thursday_record_match(u,crossing);
  assert (select count(*) from public.thursday_participation where user_id=u)=2,
    'record replay duplicated participation';
  assert not has_function_privilege('authenticated','public.thursday_event(uuid)','execute'),
    'authenticated can execute read function';
  assert not has_function_privilege('anon',
    'public.event_create_room(uuid,text,uuid,text,bigint,timestamptz)','execute');
  assert has_function_privilege('service_role','public.thursday_event(uuid)','execute'),
    'service role cannot execute read function';
end $$;
rollback;
