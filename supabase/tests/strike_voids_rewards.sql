-- LOCAL ONLY: node tool/test_sql_without_docker.mjs strike_voids_rewards.sql
-- RL16 / D37 — a host's strike of an absent player that decides the match voids
-- the rewards, as a kick does; a strike that leaves the match running does not.
begin;
do $$
declare
  r uuid := gen_random_uuid(); h uuid := gen_random_uuid(); a uuid := gen_random_uuid();
  b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); got jsonb;
  r2 uuid := gen_random_uuid(); h2 uuid := gen_random_uuid(); a2 uuid := gen_random_uuid(); b2 uuid := gen_random_uuid();
begin
  -- Room 1: host (mafia), a, b, c (town). Striking a leaves 1 mafia vs 2 town; striking b then ends it.
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'STRKVA',h,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,connected,last_seen) values
    (r,h,'host',0,'mafia',true,true,now()),
    (r,a,'a',1,'citizen',true,true,now()-interval '5 minutes'),
    (r,b,'b',2,'citizen',true,true,now()-interval '5 minutes'),
    (r,c,'c',3,'doctor',true,true,now());
  insert into public.room_state(room_id,phase,phase_number,public_data) values(r,'discuss',2,'{}');

  -- A strike that leaves the match running voids nothing.
  got := public.strike_absent_member(r,h,1);
  assert got->>'outcome' is null, 'the match ended early';
  assert not exists(select 1 from public.economy_void_rooms where room_id=r), 'a running match was voided';
  assert not public.economy_kick_voided(r), 'a running match reads as voided';

  -- The strike that reaches parity ends the match and voids it.
  got := public.strike_absent_member(r,h,2);
  assert got->>'outcome'='mafia', 'parity did not end the match';
  assert exists(select 1 from public.economy_void_rooms where room_id=r), 'the deciding strike did not void the match';
  assert public.economy_kick_voided(r), 'the deciding strike is not read as voided';

  -- Room 2: the last Mafioso is struck, the town wins, and that is voided too.
  insert into public.rooms(id,code,host_id,match_seed,status) values(r2,'STRKVB',h2,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,connected,last_seen) values
    (r2,h2,'host',0,'citizen',true,true,now()),
    (r2,a2,'a',1,'mafia',true,true,now()-interval '5 minutes'),
    (r2,b2,'b',2,'citizen',true,true,now());
  insert into public.room_state(room_id,phase,phase_number,public_data) values(r2,'night',3,'{}');
  got := public.strike_absent_member(r2,h2,1);
  assert got->>'outcome'='town', 'removing the last Mafioso did not end the match';
  assert exists(select 1 from public.economy_void_rooms where room_id=r2), 'the town win by strike was paid';

  -- The same refusals as before.
  begin
    perform public.strike_absent_member(r2,h2,1);
    raise exception 'a seat already out was struck again';
  exception when raise_exception then if sqlerrm<>'ALREADY_OUT' then raise; end if; end;
  assert has_function_privilege('service_role','public.strike_absent_member(uuid,uuid,integer)','execute');
  assert not has_function_privilege('authenticated','public.strike_absent_member(uuid,uuid,integer)','execute'),
    'a client can strike';
end $$;
select 'PASS strike voids rewards: only the strike that decides the match, in both directions, grants unchanged' as result;
rollback;
