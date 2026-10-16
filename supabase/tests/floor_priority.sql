-- LOCAL ONLY: node tool/test_sql_without_docker.mjs floor_priority.sql
-- RL15 / D21 — spotlight and last word decide who takes the floor next in talk by turns.
-- `now()` is constant inside a transaction, so time is moved by editing the
-- columns the function reads (`updated_at`, `created_at`, `speaker_until`).
-- Seat n is player p[n+1].
begin;
do $$
declare
  r uuid := gen_random_uuid();
  p uuid[] := array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
  i int;
begin
  insert into public.rooms(id,code,host_id,match_seed,status,settings)
    values(r,'FLRPRA',p[1],1,'playing','{"discussionMode":"structured"}');
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
      values(r,p[i],'P'||i,i-1,'citizen',true,'connected');
  end loop;
  insert into public.room_state(room_id,phase,phase_number,public_data,updated_at)
    values(r,'discuss',1,'{}',now()-interval '60 seconds');

  -- ── spotlight: seat 0 puts seat 2 next ──────────────────────────────────
  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats)
    values(r,p[1],0,'spotlight','discuss',1,'{2}');
  assert not public.claim_floor_with_tools(r,p[2],30,'discuss',1),
    'another hand took the chosen player''s turn';
  assert not public.claim_floor_with_tools(r,p[5],30,'discuss',1),
    'a third hand took the chosen player''s turn';
  assert public.claim_floor_with_tools(r,p[3],30,'discuss',1), 'the chosen player was refused';
  assert (select active_speaker from public.room_state where room_id=r)=p[3];
  assert not exists(select 1 from public.room_tool_uses
    where room_id=r and tool_code='spotlight' and consumed_at is null), 'spotlight not consumed on grant';
  -- once: after he finishes, the table is first come again.
  perform public.release_speaking_floor(r,p[3]);
  assert public.claim_floor_with_tools(r,p[2],30,'discuss',1), 'the turn was held a second time';
  perform public.release_speaking_floor(r,p[2]);

  -- ── the hold runs out: an absent player cannot stall the table ──────────
  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats,created_at)
    values(r,p[1],0,'spotlight','discuss',1,'{3}',now()-interval '60 seconds');
  update public.room_state set updated_at=now()-interval '60 seconds' where room_id=r;
  assert public.claim_floor_with_tools(r,p[5],30,'discuss',1), 'a hold with nobody claiming never lapsed';
  assert not exists(select 1 from public.room_tool_uses
    where room_id=r and tool_code='spotlight' and consumed_at is null), 'lapsed spotlight left pending';
  perform public.release_speaking_floor(r,p[5]);
  assert public.claim_floor_with_tools(r,p[2],30,'discuss',1), 'a lapsed spotlight held the next turn too';
  perform public.release_speaking_floor(r,p[2]);

  -- ── the previous speaker's deadline starts the hold, not the purchase ───
  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats,created_at)
    values(r,p[1],0,'spotlight','discuss',1,'{4}',now()-interval '60 seconds');
  update public.room_state set active_speaker=p[2],speaker_until=now()-interval '5 seconds',
    updated_at=now()-interval '60 seconds' where room_id=r;
  assert not public.claim_floor_with_tools(r,p[3],30,'discuss',1),
    'the hold ignored the lapsed speaker''s deadline';
  assert public.claim_floor_with_tools(r,p[5],30,'discuss',1),
    'the chosen player was refused after a lapse';
  perform public.release_speaking_floor(r,p[5]);

  -- ── a seat that cannot speak holds nothing ──────────────────────────────
  update public.room_players set alive=false where room_id=r and user_id=p[5];
  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats)
    values(r,p[1],0,'spotlight','discuss',1,'{4}');
  assert public.claim_floor_with_tools(r,p[2],30,'discuss',1), 'a dead player''s spotlight held the floor';
  perform public.release_speaking_floor(r,p[2]);
  update public.room_players set alive=true where room_id=r and user_id=p[5];
  update public.room_tool_uses set consumed_at=now() where room_id=r;

  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats)
    values(r,p[1],0,'spotlight','discuss',1,'{2}');
  update public.room_state set public_data='{"morning":{"silencedSeat":2}}' where room_id=r;
  assert public.claim_floor_with_tools(r,p[2],30,'discuss',1), 'a silenced player''s spotlight held the floor';
  perform public.release_speaking_floor(r,p[2]);
  assert not public.claim_floor_with_tools(r,p[3],30,'discuss',1), 'the silenced seat took the floor';
  update public.room_state set public_data='{}' where room_id=r;
  update public.room_tool_uses set consumed_at=now() where room_id=r;

  -- ── free discussion: nothing changes ────────────────────────────────────
  update public.rooms set settings='{"discussionMode":"free"}' where id=r;
  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats)
    values(r,p[1],0,'spotlight','discuss',1,'{2}');
  assert public.claim_floor_with_tools(r,p[2],30,'discuss',1), 'free talk was held for a spotlight';
  assert exists(select 1 from public.room_tool_uses
    where room_id=r and tool_code='spotlight' and consumed_at is null), 'free talk spent a spotlight';
  perform public.release_speaking_floor(r,p[2]);
  update public.rooms set settings='{"discussionMode":"structured"}' where id=r;
  update public.room_tool_uses set consumed_at=now() where room_id=r;

  -- ── only the discussion phase is ordered ────────────────────────────────
  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats)
    values(r,p[1],0,'spotlight','discuss',1,'{2}');
  update public.room_state set phase='defense',public_data='{"confrontation":{"targetSeat":4}}',
    updated_at=now() where room_id=r;
  assert public.claim_floor_with_tools(r,p[5],30,'defense',1), 'a spotlight reached the defense';
end $$;

-- ── last word: the first floor of the next day ────────────────────────────
do $$
declare
  r uuid := gen_random_uuid();
  p uuid[] := array[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
  i int;
begin
  insert into public.rooms(id,code,host_id,match_seed,status,settings)
    values(r,'FLRPRB',p[1],1,'playing','{"discussionMode":"structured"}');
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
      values(r,p[i],'P'||i,i-1,'citizen',i<>5,'connected');
  end loop;
  -- Day 2's discussion, after seat 4 (out) was voted out on day 1 and named seat 3.
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r,'discuss',2,'{"lastWordFloor":{"seat":4,"target":3,"day":1}}');
  assert not public.claim_floor_with_tools(r,p[1],30,'discuss',2), 'another hand took the last word''s floor';
  assert public.claim_floor_with_tools(r,p[4],30,'discuss',2), 'the named player was refused';
  assert not (select public_data ? 'lastWordFloor' from public.room_state where room_id=r),
    'the grant was not spent';
  perform public.release_speaking_floor(r,p[4]);
  assert public.claim_floor_with_tools(r,p[1],30,'discuss',2), 'the last word held a second floor';
  perform public.release_speaking_floor(r,p[1]);

  -- a stale grant (another day) is ignored
  update public.room_state set public_data='{"lastWordFloor":{"seat":4,"target":3,"day":7}}' where room_id=r;
  assert public.claim_floor_with_tools(r,p[2],30,'discuss',2), 'a stale last word held the floor';
  perform public.release_speaking_floor(r,p[2]);

  -- the hold runs out, and the grant with it
  update public.room_state set public_data='{"lastWordFloor":{"seat":4,"target":3,"day":1}}',
    updated_at=now()-interval '60 seconds' where room_id=r;
  assert public.claim_floor_with_tools(r,p[1],30,'discuss',2), 'an unclaimed last word stalled the day';
  assert not (select public_data ? 'lastWordFloor' from public.room_state where room_id=r),
    'lapsed grant left behind';
  perform public.release_speaking_floor(r,p[1]);

  -- a last word comes before a spotlight; the spotlight follows
  update public.room_state set public_data='{"lastWordFloor":{"seat":4,"target":3,"day":1}}',updated_at=now()
    where room_id=r;
  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats)
    values(r,p[1],0,'spotlight','discuss',2,'{1}');
  assert not public.claim_floor_with_tools(r,p[2],30,'discuss',2), 'the spotlight jumped the last word';
  assert public.claim_floor_with_tools(r,p[4],30,'discuss',2), 'the last word was refused';
  perform public.release_speaking_floor(r,p[4]);
  assert not public.claim_floor_with_tools(r,p[1],30,'discuss',2),
    'the spotlight was not honoured after the last word';
  assert public.claim_floor_with_tools(r,p[2],30,'discuss',2), 'the spotlighted player was refused';
  perform public.release_speaking_floor(r,p[2]);
  assert public.claim_floor_with_tools(r,p[1],30,'discuss',2), 'a spent spotlight held the floor again';
  perform public.release_speaking_floor(r,p[1]);

  -- a named player who is out holds nothing
  update public.room_players set alive=false where room_id=r and user_id=p[4];
  update public.room_state set public_data='{"lastWordFloor":{"seat":4,"target":3,"day":1}}' where room_id=r;
  assert public.claim_floor_with_tools(r,p[1],30,'discuss',2), 'a dead player''s last word held the floor';
end $$;
select 'PASS floor priority: spotlight and last word go first once, lapse, ignore dead / silenced / free / other phases' as result;
rollback;
