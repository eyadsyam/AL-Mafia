-- Row 4: host continuity and hand-off reliability.
--
-- The SQL harness has one connection, so a "race" here is each complete
-- interleaving the room lock allows: both orders of start/leave, start/kick
-- and join/start, and a host hand-off during every phase. Each order must end
-- in one consistent room. (Real concurrent sessions run in
-- supabase/tests/concurrency_match.py against a hosted project.)
begin;
create function pg_temp.hc_room(p_code text,p_host uuid,p_seats uuid[],p_ready boolean)
returns uuid language plpgsql as $$
declare rid uuid:=gen_random_uuid(); i int;
begin
  insert into public.rooms(id,code,host_id,match_seed,settings)
    values(rid,p_code,p_host,7,'{"maxPlayers":10,"openVoting":true,"speechSeconds":45}');
  insert into public.room_state(room_id,phase) values(rid,'lobby');
  for i in 1..cardinality(p_seats) loop
    insert into public.room_players(room_id,user_id,name,seat,connected,status,last_seen)
      values(rid,p_seats[i],'S'||i,i-1,true,'connected',now());
  end loop;
  if p_ready then update public.room_players set lobby_ready=true where room_id=rid; end if;
  return rid;
end $$;

do $$
declare
  u uuid[]:=array(select gen_random_uuid() from generate_series(1,8));
  rid uuid; rev int; settings_before jsonb; roles5 text[]:=array['mafia','doctor','detective','citizen','citizen'];
  roles6 text[]:=array['mafia','doctor','detective','citizen','citizen','citizen'];
  phase_before text; number_before int; refused boolean; ph text;
begin
  update public.economy_config set lobby_ready_enabled=true where id=true;

  -- ── Hand-off without a roster change: configuration and readiness survive.
  rid:=pg_temp.hc_room('HCAAAA',u[1],u[1:5],true);
  select lobby_revision,settings into rev,settings_before from public.rooms where id=rid;
  update public.room_players set connected=false,status='away',
      last_seen=now()-interval '5 minutes' where room_id=rid and user_id=u[1];
  -- The host going away clears only the host's own readiness (away cannot
  -- be ready); everyone else keeps theirs.
  assert public.migrate_host(rid,u[2])=u[2],'lowest live seat claims';
  assert (select host_id from public.rooms where id=rid)=u[2];
  assert (select settings from public.rooms where id=rid)=settings_before,'configuration survives';
  assert (select lobby_revision from public.rooms where id=rid)=rev,'hand-off is not a new proposition';
  assert (select count(*) from public.room_players where room_id=rid and lobby_ready)=4,
    'the other seats stay ready';
  -- A second claimant after the winner gets the winner back, no change.
  assert public.migrate_host(rid,u[3])=u[2],'second claim returns the winner';
  -- The old host can no longer start; the new host can once all are ready.
  update public.room_players set connected=true,status='connected',last_seen=now()
    where room_id=rid and user_id=u[1];
  update public.room_players set lobby_ready=true where room_id=rid;
  assert not public.apply_match_deal(rid,u[1],roles5,'{}',now()+interval '1 minute'),
    'the previous host cannot start';
  assert public.apply_match_deal(rid,u[2],roles5,'{}',now()+interval '1 minute'),'new host starts';

  -- ── The host leaving the lobby is a roster change: readiness clears, the
  --    lowest seated row hosts, configuration is untouched.
  rid:=pg_temp.hc_room('HCBBBB',u[1],u[1:6],true);
  update public.room_players set lobby_ready=true where room_id=rid;
  select lobby_revision,settings into rev,settings_before from public.rooms where id=rid;
  assert public.leave_room(rid,u[1])='left';
  assert (select host_id from public.rooms where id=rid)=u[2],'lowest seated row hosts';
  assert (select settings from public.rooms where id=rid)=settings_before,'configuration survives';
  assert (select lobby_revision from public.rooms where id=rid)>rev,'roster change bumps the revision';
  assert not exists(select 1 from public.room_players where room_id=rid and lobby_ready),
    'readiness cleared by the roster change';
  assert (select array_agg(seat order by seat) from public.room_players where room_id=rid)
    =array[0,1,2,3,4],'seats close up';

  -- ── start / kick, both orders.
  rid:=pg_temp.hc_room('HCCCCC',u[1],u[1:6],true);
  update public.room_players set lobby_ready=true where room_id=rid;
  perform public.kick_member(rid,u[1],5);                 -- kick first
  update public.room_players set lobby_ready=true where room_id=rid and not kicked;
  assert not public.apply_match_deal(rid,u[1],roles6,'{}',now()+interval '1 minute'),
    'a six-role deal after a kick is refused (five seats remain)';
  assert public.apply_match_deal(rid,u[1],roles5,'{}',now()+interval '1 minute'),
    'the five remaining seats start';
  assert (select role from public.room_players where room_id=rid and user_id=u[6]) is null,
    'the kicked seat was dealt nothing';

  rid:=pg_temp.hc_room('HCDDDD',u[1],u[1:6],true);
  update public.room_players set lobby_ready=true where room_id=rid;
  assert public.apply_match_deal(rid,u[1],roles6,'{}',now()+interval '1 minute');  -- start first
  perform public.kick_member(rid,u[1],5);
  assert (select kicked and not alive from public.room_players where room_id=rid and user_id=u[6]),
    'a kick after the deal eliminates the seat';
  assert (select status from public.rooms where id=rid) in ('playing','finished');

  -- ── join / start, both orders.
  rid:=pg_temp.hc_room('HCEEEE',u[1],u[1:5],true);
  perform public.join_room_atomic('HCEEEE',u[6],'Late','male');   -- join first
  update public.room_players set connected=true,status='connected' where room_id=rid;
  refused:=false;
  begin
    perform public.apply_match_deal(rid,u[1],roles6,'{}',now()+interval '1 minute');
  exception when raise_exception then refused:=sqlerrm='NOT_READY';
  end;
  assert refused,'a join clears readiness, so the old proposition cannot start';
  update public.room_players set lobby_ready=true where room_id=rid;
  assert not public.apply_match_deal(rid,u[1],roles5,'{}',now()+interval '1 minute'),
    'a deal sized for the old roster is refused';
  assert public.apply_match_deal(rid,u[1],roles6,'{}',now()+interval '1 minute');

  rid:=pg_temp.hc_room('HCFFFF',u[1],u[1:5],true);
  update public.room_players set lobby_ready=true where room_id=rid;
  assert public.apply_match_deal(rid,u[1],roles5,'{}',now()+interval '1 minute');   -- start first
  refused:=false;
  begin
    perform public.join_room_atomic('HCFFFF',u[6],'Late','male');
  exception when raise_exception then refused:=sqlerrm='PHASE_CLOSED';
  end;
  assert refused,'a join after the deal is refused';
  assert (select count(*) from public.room_players where room_id=rid)=5;

  -- ── Hand-off during every phase leaves the phase exactly where it was.
  foreach ph in array array['reveal','night','morning','opening','confront','discuss',
      'defense','vote','verdict','result'] loop
    rid:=pg_temp.hc_room('HP'||substr('ABCDEFGHJKLMN',1+(select count(*)::int
      from public.rooms where code like 'HP%QRS'),1)||'QRS',u[1],u[1:5],true);
    update public.room_players set lobby_ready=true where room_id=rid;
    assert public.apply_match_deal(rid,u[1],roles5,'{}',now()+interval '1 minute');
    update public.room_state set phase=ph,phase_number=3 where room_id=rid;
    select phase,phase_number into phase_before,number_before from public.room_state where room_id=rid;
    update public.room_players set connected=false,status='left' where room_id=rid and user_id=u[1];
    -- The departure trigger already hands over to the lowest live seat.
    assert (select host_id from public.rooms where id=rid)=u[2],'handover during '||ph;
    assert public.migrate_host(rid,u[3])=u[2],'claim during '||ph||' returns the heir';
    assert (select phase=phase_before and phase_number=number_before from public.room_state
      where room_id=rid),'phase moved during a hand-off in '||ph;
    assert (select status from public.rooms where id=rid)='playing','room still playing in '||ph;
  end loop;

  -- ── Flag off: the old start path is unchanged by any of this.
  update public.economy_config set lobby_ready_enabled=false where id=true;
  rid:=pg_temp.hc_room('HCZZZZ',u[1],u[1:5],false);
  assert public.apply_match_deal(rid,u[1],roles5,'{}',now()+interval '1 minute'),
    'flag off: unready roster starts as before';
end $$;
rollback;
