-- Row 12: launch events. Operator scheduling (validation, no backdate,
-- replay, audit), Cairo-local window, eligibility by start time and stored
-- preset fingerprint, public-result-only read, dark by default.
begin;
create function pg_temp.le_room(p_code text,p_users uuid[],p_start timestamptz,p_fp text,
  p_status text default 'finished') returns uuid language plpgsql as $$
declare rid uuid:=gen_random_uuid(); i int;
begin
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at,
      scenario_fingerprint,settings)
    values(rid,p_code,p_users[1],p_status,1,p_start,
      case when p_status='finished' then p_start+interval '40 minutes' end,p_fp,
      public.thursday_preset());
  for i in 1..cardinality(p_users) loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(rid,p_users[i],i-1,'P'||i,case when i=2 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(rid,'result','{"outcome":"town"}');
  return rid;
end $$;

do $$
declare
  u uuid[]:=array(select gen_random_uuid() from generate_series(1,6));
  req uuid:=gen_random_uuid(); r jsonb; again jsonb; t0 timestamptz:=date_trunc('hour',now())+interval '2 hours';
  inside uuid; outside uuid; wrong uuid; crossing uuid; live uuid; st jsonb; i int;
begin
  for i in 1..6 loop insert into auth.users(id) values(u[i]); end loop;
  update public.economy_config set council_contracts_enabled=true;

  -- Dark: nothing scheduled.
  st:=public.launch_event_state(now());
  assert st->>'enabled'='false' and st->'active'='[]'::jsonb,st::text;

  -- Validation.
  assert (public.operator_event_set('launch_night',t0,t0,'classic',true,gen_random_uuid()))->>'code'='BAD_REQUEST','empty window';
  assert (public.operator_event_set('launch_night',t0,t0+interval '8 days','classic',true,gen_random_uuid()))->>'code'='BAD_REQUEST','over seven days';
  assert (public.operator_event_set('launch_night',t0,t0+interval '5 hours','deck',true,gen_random_uuid()))->>'code'='BAD_REQUEST','unknown scenario';
  assert (public.operator_event_set('Launch Night',t0,t0+interval '5 hours','classic',true,gen_random_uuid()))->>'code'='BAD_REQUEST','code shape';
  assert (public.operator_event_set('launch_night',now()-interval '1 hour',now()+interval '1 hour','classic',true,gen_random_uuid()))->>'code'='BACKDATED','no backdate';

  -- Schedule, replay, audit.
  r:=public.operator_event_set('launch_night',t0,t0+interval '5 hours','classic',true,req);
  assert (r->>'ok')::boolean and r->'before'='null'::jsonb,r::text;
  assert r->'after'->>'cairoStartsAt'=(t0 at time zone 'Africa/Cairo')::text,'Cairo-local bounds';
  again:=public.operator_event_set('launch_night',t0,t0+interval '9 hours','classic',false,req);
  assert (again->>'replayed')::boolean and again-'replayed'=r,'replay returns the first answer';
  assert (select ends_at from public.launch_events where code='launch_night')=t0+interval '5 hours';
  assert (select count(*) from public.operator_audit_log where action='operator_event_set')=1;
  begin
    update public.operator_audit_log set target='x';
    raise exception 'audit updated';
  exception when others then assert sqlerrm='AUDIT_IMMUTABLE',sqlerrm;
  end;
  begin
    delete from public.operator_audit_log;
    raise exception 'audit deleted';
  exception when others then assert sqlerrm='AUDIT_IMMUTABLE',sqlerrm;
  end;
  -- Upcoming, then (moved into the past for the test) active.
  assert jsonb_array_length(public.launch_event_state(now())->'upcoming')=1;
  update public.launch_events set starts_at=now()-interval '2 hours',ends_at=now()+interval '3 hours'
    where code='launch_night';
  assert jsonb_array_length(public.launch_event_state(now())->'active')=1;
  -- A live window's start cannot move; its end cannot move into the past.
  assert (public.operator_event_set('launch_night',now()-interval '1 hour',now()+interval '3 hours','classic',true,gen_random_uuid()))->>'code'='EVENT_STARTED';
  assert (public.operator_event_set('launch_night',(select starts_at from public.launch_events where code='launch_night'),now()-interval '1 minute','classic',true,gen_random_uuid()))->>'code'='BACKDATED';
  r:=public.operator_event_set('launch_night',(select starts_at from public.launch_events where code='launch_night'),now()+interval '4 hours','classic',true,gen_random_uuid());
  assert (r->>'ok')::boolean and r->'before' is not null,'extension recorded with its before';

  -- Eligibility: started inside with the canonical fingerprint counts; a
  -- match that starts inside and ends after the window still counts; one
  -- that started before, or with another fingerprint, does not.
  inside:=pg_temp.le_room('LEVTAA',u[1:5],now()-interval '90 minutes',public.thursday_preset_fingerprint());
  crossing:=pg_temp.le_room('LEVTBB',u[1:5],now()-interval '5 minutes',public.thursday_preset_fingerprint());
  outside:=pg_temp.le_room('LEVTCC',u[1:5],now()-interval '3 hours',public.thursday_preset_fingerprint());
  wrong:=pg_temp.le_room('LEVTDD',u[1:5],now()-interval '60 minutes',md5('other'));
  update public.rooms set ended_at=now()+interval '5 hours' where id=crossing;
  foreach live in array array[inside,crossing,outside,wrong] loop
    perform public.council_record_match(u[1],live);
  end loop;
  assert public.launch_event_result(u[1],inside)->'events'='["launch_night"]'::jsonb,'inside counts';
  assert public.launch_event_result(u[1],crossing)->'events'='["launch_night"]'::jsonb,'start owns the window';
  assert public.launch_event_result(u[1],outside)->'events'='[]'::jsonb,'started before the window';
  assert public.launch_event_result(u[1],wrong)->'events'='[]'::jsonb,'wrong stored fingerprint';
  -- Four humans: not an eligible match, so no stamp.
  live:=pg_temp.le_room('LEVTEE',u[1:4],now()-interval '30 minutes',public.thursday_preset_fingerprint());
  perform public.council_record_match(u[1],live);
  assert public.launch_event_result(u[1],live)->'events'='[]'::jsonb,'ineligible match';
  -- Public result only: a room still being played answers empty.
  live:=pg_temp.le_room('LEVTFF',u[1:5],now()-interval '20 minutes',public.thursday_preset_fingerprint(),'playing');
  assert public.launch_event_result(u[1],live)->'events'='[]'::jsonb,'live room';
  begin
    perform public.launch_event_result(u[6],inside);
    raise exception 'non-member read';
  exception when others then assert sqlerrm='NOT_MEMBER',sqlerrm;
  end;
  assert not (public.launch_event_result(u[1],inside)::text ~ '"role"|"seat"'),'no seat facts';
  -- Replay is idempotent; disabling stops new stamps, keeps recorded ones.
  perform public.launch_event_record_match(u[1],inside);
  assert (select count(*) from public.launch_event_participation where user_id=u[1] and room_id=inside)=1;
  perform public.operator_event_set('launch_night',(select starts_at from public.launch_events where code='launch_night'),
    (select ends_at from public.launch_events where code='launch_night'),'classic',false,gen_random_uuid());
  assert public.launch_event_state(now())->'active'='[]'::jsonb,'disabled';
  assert public.launch_event_result(u[1],inside)->'events'='["launch_night"]'::jsonb,'recorded stays';

  assert not has_function_privilege('authenticated','public.operator_event_set(text,timestamptz,timestamptz,text,boolean,uuid)','execute');
  assert not has_function_privilege('anon','public.launch_event_state(timestamptz)','execute');
end $$;
rollback;
