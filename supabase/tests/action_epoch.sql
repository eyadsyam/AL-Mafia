begin;
do $$
declare
  r uuid := gen_random_uuid();
  a uuid := '00000000-0000-4000-8000-00000000000a';
  b uuid := '00000000-0000-4000-8000-00000000000b';
  c uuid := '00000000-0000-4000-8000-00000000000c';
  fp text; s public.room_state;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'EPCH42',a,3,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role)
    values(r,a,'A',0,'mafia'),(r,b,'B',1,'doctor'),(r,c,'C',2,'citizen');
  insert into public.room_state(room_id,phase,phase_number) values(r,'night',1);

  -- a move belongs to the night the room is in, and no other
  insert into public.night_actions(room_id,night,actor_id,action,target_id) values(r,1,a,'kill',c);
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id) values(r,2,b,'protect',c);
    raise exception 'a move for a future night was accepted';
  exception when others then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;
  update public.room_state set phase='morning' where room_id=r;
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id) values(r,1,b,'protect',c);
    raise exception 'a move after the night closed was accepted';
  exception when others then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;
  begin
    update public.night_actions set target_id=a where room_id=r and actor_id=a;
    raise exception 'a rewrite after the night closed was accepted';
  exception when others then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;
  if (select target_id from public.night_actions where room_id=r and actor_id=a)<>c then
    raise exception 'refused rewrite changed the move';
  end if;

  -- the resolution commits only the moves it counted
  update public.room_state set phase='night' where room_id=r;
  insert into public.night_actions(room_id,night,actor_id,action,target_id) values(r,1,b,'protect',c);
  fp := public.night_fingerprint(r,1);
  if fp <> a::text||'|kill|'||c::text||';'||b::text||'|protect|'||c::text||'#roster:'||public.roster_fingerprint(r) then
    raise exception 'fingerprint shape changed: %', fp;
  end if;
  -- a driver that tallied before B acted is refused, and nothing moves
  if public.commit_resolution(r,'night',1,1,c,null,'{"victimSeat":2}','{"morning":{"victimSeat":2}}','morning',now(),
       a::text||'|kill|'||c::text) then
    raise exception 'resolution committed against a stale tally';
  end if;
  if not (select alive from public.room_players where room_id=r and user_id=c) then
    raise exception 'stale tally killed a player';
  end if;
  if (select phase from public.room_state where room_id=r)<>'night' then raise exception 'stale tally moved the phase'; end if;
  -- the driver that counted everything commits
  if not public.commit_resolution(r,'night',1,1,null,2,'{"victimSeat":null}','{"morning":{"someoneSavedUnnamed":true}}','morning',now(),fp) then
    raise exception 'current tally refused';
  end if;
  if (select phase from public.room_state where room_id=r)<>'morning' then raise exception 'resolution did not open the morning'; end if;
  -- a late move against the resolved night is refused by the guard
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id) values(r,1,c,'suspect',a);
    raise exception 'a late move landed on a resolved night';
  exception when others then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;

  -- ballots: the round is the room's
  update public.room_state set phase='vote',phase_number=1,public_data='{}' where room_id=r;
  insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,a,c,1);
  begin
    insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,b,c,2);
    raise exception 'a ballot for a round not yet open was accepted';
  exception when others then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;
  begin
    insert into public.votes(room_id,day,voter_id,target_id,round) values(r,2,b,c,1);
    raise exception 'a ballot for another day was accepted';
  exception when others then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;
  insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,b,a,1);
  insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,c,a,1);
  fp := public.vote_fingerprint(r,1,1);
  -- a tally that missed C's ballot is refused
  if public.commit_resolution(r,'vote',1,1,a,null,'{}','{"lastVote":{"eliminatedSeat":0}}','verdict',now(),
       a::text||'|'||c::text||';'||b::text||'|'||a::text) then
    raise exception 'ballot resolved against a stale tally';
  end if;
  if not (select alive from public.room_players where room_id=r and user_id=a) then
    raise exception 'stale ballot tally eliminated a player';
  end if;
  -- a revote opens round two; round-one ballots are then refused, round two admitted
  if not public.commit_resolution(r,'vote',1,1,null,null,'{}','{"revote":{"round":2,"tiedSeats":[0,2]}}','vote',now(),fp) then
    raise exception 'revote refused';
  end if;
  begin
    update public.votes set target_id=c where room_id=r and voter_id=c and round=1;
    raise exception 'a round-one ballot was rewritten during round two';
  exception when others then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;
  -- round two: the table turns on c. (The round itself is a separate CAS
  -- argument; the fingerprint names the ballots, so two rounds cast the same
  -- way legitimately print the same.)
  insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,a,c,2),(r,1,b,c,2),(r,1,c,a,2);
  fp := public.vote_fingerprint(r,1,2);
  if fp = public.vote_fingerprint(r,1,1) then raise exception 'round two ballots not counted apart'; end if;
  -- a round-one driver cannot close round two even with round two's ballots
  if public.commit_resolution(r,'vote',1,1,c,null,'{}','{"lastVote":{"eliminatedSeat":2}}','verdict',now(),fp) then
    raise exception 'a round-one driver closed round two';
  end if;
  if not public.commit_resolution(r,'vote',1,2,c,null,'{}','{"lastVote":{"eliminatedSeat":2}}','verdict',now(),fp) then
    raise exception 'round two refused';
  end if;
  if (select alive from public.room_players where room_id=r and user_id=c) then
    raise exception 'round two did not eliminate';
  end if;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'verdict' or s.public_data#>>'{eliminations,2,phase}'<>'day' then
    raise exception 'verdict not published: %', s;
  end if;
  if (select status from public.rooms where id=r)<>'playing' then
    raise exception 'an undecided ballot finished the room';
  end if;
  -- a deciding ballot finishes the room at once (`resolution_outcome`)
  update public.room_state set phase='vote',phase_number=2,public_data='{}' where room_id=r;
  insert into public.votes(room_id,day,voter_id,target_id,round) values(r,2,a,b,1),(r,2,b,a,1);
  fp := public.vote_fingerprint(r,2,1);
  if not public.commit_resolution(r,'vote',2,1,a,null,'{}','{"lastVote":{"eliminatedSeat":0},"outcome":"town"}','verdict',now(),fp) then
    raise exception 'deciding ballot refused';
  end if;
  if (select status from public.rooms where id=r)<>'finished' then
    raise exception 'deciding ballot did not finish the room';
  end if;

  if has_function_privilege('authenticated','public.night_fingerprint(uuid,integer)','execute')
   or has_function_privilege('authenticated','public.vote_fingerprint(uuid,integer,integer)','execute')
   or has_function_privilege('authenticated',
      'public.commit_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz,text)','execute') then
    raise exception 'a client can fingerprint or resolve';
  end if;
  if exists (select 1 from pg_proc where proname='commit_resolution' and pronargs=10) then
    raise exception 'the fingerprint-less resolution is still callable';
  end if;
end $$;
select 'PASS phase guards on moves and ballots, fingerprinted resolution, revote rounds, grants' as result;
rollback;
