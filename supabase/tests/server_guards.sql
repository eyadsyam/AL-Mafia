begin;
do $$
declare
  r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid();
  r3 uuid := gen_random_uuid(); r4 uuid := gen_random_uuid();
  h1 uuid := gen_random_uuid(); h2 uuid := gen_random_uuid();
  h3 uuid := gen_random_uuid(); h4 uuid := gen_random_uuid();
  d0 timestamptz := now() + interval '30 seconds';
  d1 timestamptz := now() + interval '120 seconds';
  s public.room_state;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values
    (r1,'QQ7PX2',h1,7,'playing'),(r2,'QQ7PX3',h2,7,'playing'),
    (r3,'QQ7PX4',h3,7,'playing'),(r4,'QQ7PX5',h4,7,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,saw_role) values
    (r1,h1,'host',0,'mafia',true),(r2,h2,'host',0,'mafia',true),
    (r3,h3,'host',0,'mafia',true),(r4,h4,'host',0,'mafia',true);
  insert into public.room_state(room_id,phase,phase_number,phase_ends_at,public_data) values
    (r1,'verdict',2,d0,'{"outcome":"mafia"}'),
    (r2,'discuss',2,d0,'{"outcome":"town"}'),
    (r3,'morning',2,d0,'{}'),
    (r4,'morning',2,d0,'{"outcome":"town"}');

  if public.commit_phase_open(r1,'verdict',2,d0,'night',3,d1,'{}',false) then
    raise exception 'decided verdict opened a night';
  end if;
  select * into s from public.room_state where room_id=r1;
  if s.phase<>'verdict' or s.phase_number<>2 or s.phase_ends_at<>d0 or s.public_data<>'{"outcome":"mafia"}'::jsonb then
    raise exception 'refused verdict transition changed the row';
  end if;
  if not public.commit_phase_open(r1,'verdict',2,d0,'result',2,null,'{}',false) then
    raise exception 'decided verdict could not open result';
  end if;
  if public.commit_phase_open(r2,'discuss',2,d0,'vote',2,d1,'{}',false) then
    raise exception 'decided discussion opened a vote';
  end if;
  if not public.commit_confrontation(r3,2,d0,null,'discuss',d1) then
    raise exception 'undecided morning could not open discussion';
  end if;
  if public.commit_confrontation(r4,2,d0,null,'discuss',d1) then
    raise exception 'decided morning opened discussion';
  end if;
  if to_regprocedure('public.claim_bot_win(uuid,uuid)') is not null
    or to_regprocedure('public.start_bot_match(uuid)') is not null then
    raise exception 'retired bot reward functions still exist';
  end if;
  if position('x-sync-secret' in pg_get_functiondef('public.push_wake()'::regprocedure))=0 then
    raise exception 'push_wake lacks sync secret';
  end if;
  if has_function_privilege('authenticated','public.payment_proof_orphans(integer)','execute')
    or not has_function_privilege('service_role','public.payment_proof_orphans(integer)','execute') then
    raise exception 'proof orphan privileges are wrong';
  end if;
  -- The job follows the flag only where pg_cron is installed (the function
  -- returns early without it, as every migration's cron block does); the
  -- local PGlite runner has a cron schema but no extension.
  if exists (select 1 from pg_extension where extname='pg_cron') then
    update public.economy_config set lobby_ready_enabled=true where id=true;
    if not exists(select 1 from cron.job where jobname='expire-lobby-ready') then
      raise exception 'enabled lobby ready has no cron job';
    end if;
    update public.economy_config set lobby_ready_enabled=false where id=true;
    if exists(select 1 from cron.job where jobname='expire-lobby-ready') then
      raise exception 'disabled lobby ready still has cron job';
    end if;
  end if;
end $$;
select 'PASS server guards' as result;
rollback;
