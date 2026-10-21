-- LOCAL ONLY: node tool/test_sql_without_docker.mjs online_retry_rows.sql
-- M3-25: a write retried after a lost acknowledgement has the effect of one write.
-- M3-37: a playing room every client went silent in closes, with no invented winner.
-- M3-56: a match receipt is issued once per participant; a deciding removal voids it.
-- Serial only: true concurrency stays with the owner's live suite.
begin;
alter table public.votes disable trigger vote_phase_guard;
do $$
declare
  people uuid[]; rid uuid := gen_random_uuid(); lobby uuid := gen_random_uuid();
  idle uuid := gen_random_uuid(); old uuid := gen_random_uuid(); i int;
  rec public.match_receipts; again public.match_receipts; rev int; first jsonb; second jsonb;
  before_settings jsonb;
begin
  select array_agg(gen_random_uuid()) into people from generate_series(1,6);
  insert into auth.users(id) select unnest(people);
  update public.economy_config set economy_v11_enabled=true, lobby_ready_enabled=true;

  -- M3-56: the same participant asking twice gets the same receipt, once.
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(rid,'RTRY56',people[1],'finished',1,now()-interval '10 minutes',now());
  for i in 1..6 loop
    insert into public.room_players(room_id,user_id,seat,name,role,status)
      values(rid,people[i],i-1,'Seat'||i,case when i=2 then 'mafia' else 'citizen' end,'connected');
  end loop;
  insert into public.room_state(room_id,phase,public_data) values(rid,'result','{"outcome":"town"}');
  insert into public.votes(room_id,day,voter_id,action_id)
    select rid,1,unnest(people),gen_random_uuid();
  rec := public.economy_v3_issue_receipt(people[1],rid);
  assert rec.user_id=people[1], 'an eligible participant got no receipt';
  again := public.economy_v3_issue_receipt(people[1],rid);
  assert again.user_id=people[1] and again.day_ordinal=rec.day_ordinal
    and again.completion_coins=rec.completion_coins, 'a retried receipt differs from the first';
  assert (select count(*) from public.match_receipts where user_id=people[1] and room_id=rid)=1,
    'a retried receipt was issued twice';
  -- A removal that decided the match voids the rewards of everyone who has not claimed yet.
  insert into public.economy_void_rooms(room_id) values(rid);
  assert (public.economy_v3_issue_receipt(people[3],rid)).user_id is null,
    'a match decided by a removal still paid';

  -- M3-37: every seat still marked connected, none heard from in ten minutes.
  insert into public.rooms(id,code,host_id,status,match_seed,started_at)
    values(idle,'RTRY37',people[1],'playing',2,now()-interval '30 minutes');
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role,status,connected,last_seen)
      values(idle,people[i],i-1,'Seat'||i,case when i=2 then 'mafia' else 'citizen' end,
        'connected',true,now()-interval '10 minutes');
  end loop;
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(idle,'discuss',2,'{}');
  assert public.archive_abandoned_rooms()>=1, 'a silent room was not archived';
  assert (select status from public.rooms where id=idle)='finished', 'the silent room stayed open';
  assert (select public_data->>'outcome' from public.room_state where room_id=idle) is null,
    'archiving invented a winner';
  assert not exists(select 1 from public.match_receipts where room_id=idle),
    'archiving paid a receipt';

  -- M3-25, lobby: ready, settings and a kick, each sent twice.
  insert into public.rooms(id,code,host_id,status,match_seed)
    values(lobby,'RTRY25',people[1],'lobby',3);
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,status,connected,last_seen)
      values(lobby,people[i],i-1,'Seat'||i,'connected',true,now());
  end loop;
  rev := (select lobby_revision from public.rooms where id=lobby);
  first := public.set_lobby_ready(lobby,people[2],true,rev);
  begin
    second := public.set_lobby_ready(lobby,people[2],true,rev);
  exception when raise_exception then
    assert sqlerrm='STALE_REVISION', sqlerrm;
  end;
  assert (select lobby_ready from public.room_players where room_id=lobby and user_id=people[2]),
    'a retried ready left the seat unready';

  perform public.commit_room_settings(lobby,people[1],'{"settings":{"voice":false}}'::jsonb);
  before_settings := (select settings from public.rooms where id=lobby);
  perform public.commit_room_settings(lobby,people[1],'{"settings":{"voice":false}}'::jsonb);
  assert (select settings from public.rooms where id=lobby)=before_settings,
    'a retried settings write changed the room again';

  assert public.kick_member(lobby,people[1],4)=people[5], 'the kick removed someone else';
  assert public.kick_member(lobby,people[1],4)=people[5], 'a retried kick removed someone else';
  assert (select count(*) from public.room_players where room_id=lobby and kicked)=1,
    'a retried kick removed two seats';
  assert (select cardinality(banned_user_ids) from public.rooms where id=lobby)=1,
    'a retried kick banned twice';

  -- M3-25, in play: a strike sent twice takes one seat out once.
  update public.rooms set status='playing' where id=lobby;
  update public.room_players set role=case when seat=1 then 'mafia' else 'citizen' end,
    alive=not kicked where room_id=lobby;
  update public.room_players set last_seen=now()-interval '5 minutes', connected=false
    where room_id=lobby and seat=2;
  insert into public.room_state(room_id,phase,phase_number,public_data) values(lobby,'discuss',2,'{}');
  perform public.strike_absent_member(lobby,people[1],2);
  begin
    perform public.strike_absent_member(lobby,people[1],2);
    raise exception 'a retried strike was applied twice';
  exception when raise_exception then
    assert sqlerrm='ALREADY_OUT', sqlerrm;
  end;
  assert (select count(*) from public.room_players where room_id=lobby and not alive)=2,
    'the strike took out more than the struck seat';

  -- M3-25, after the match: a rematch sent twice opens one next room.
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(old,'RTRYRM',people[1],'finished',4,now()-interval '20 minutes',now());
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role,status,connected,last_seen)
      values(old,people[i],i-1,'Seat'||i,'citizen','connected',true,now());
  end loop;
  insert into public.room_state(room_id,phase,public_data) values(old,'result','{"outcome":"town"}');
  first := public.rematch_room_atomic(old,people[1],'Host','male','RTRYNA',5);
  second := public.rematch_room_atomic(old,people[1],'Host','male','RTRYNB',6);
  assert first->>'roomId'=second->>'roomId', 'a retried rematch opened a second room';
  assert (select count(*) from public.rooms where code in ('RTRYNA','RTRYNB'))=1,
    'a retried rematch left two rooms';
end $$;
rollback;
