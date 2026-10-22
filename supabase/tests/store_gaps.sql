-- LOCAL ONLY: node tool/test_sql_without_docker.mjs store_gaps.sql
-- Proofs for the GAP rows of docs/plans/audit/M4-store.md that SQL can carry.
-- One transaction, rolled back. Single connection (PGlite): proves rules,
-- guards, idempotency and conservation, NOT hosted lock ordering between two
-- clients; rows that depend on a real race stay `needs-live` in the matrix and
-- are only walked through here in serial order.
begin;

create function pg_temp.sg_code() returns text language sql as $$
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',1+floor(random()*32)::int,1),'')
    from generate_series(1,6)
$$;

-- A playing table: seat i holds p_roles[i+1], everybody alive and connected.
create function pg_temp.sg_room(p_roles text[], p_phase text, p_number int default 1,
  p_data jsonb default '{"morning":{"silencedSeat":null}}'::jsonb) returns uuid
language plpgsql as $$
declare r uuid:=gen_random_uuid(); u uuid; i int;
begin
  for i in 1..cardinality(p_roles) loop
    u:=gen_random_uuid();
    insert into auth.users(id,is_anonymous) values(u,true);
    if i=1 then
      insert into public.rooms(id,code,host_id,match_seed,status,started_at)
        values(r,pg_temp.sg_code(),u,1,'playing',now());
    end if;
    insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
      values(r,u,'Seat '||(i-1),i-1,p_roles[i],true,'connected');
  end loop;
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r,p_phase,p_number,p_data);
  return r;
end $$;

create function pg_temp.sg_user(p_room uuid, p_seat int) returns uuid language sql as $$
  select user_id from public.room_players where room_id=p_room and seat=p_seat
$$;

create function pg_temp.sg_charges(p_user uuid, p_tool text) returns int language sql as $$
  select coalesce((select charges from public.player_tool_charges
    where user_id=p_user and tool_code=p_tool),0)
$$;

create function pg_temp.sg_give(p_user uuid, p_tool text, p_n int) returns void language sql as $$
  insert into public.player_tool_charges(user_id,tool_code,charges) values(p_user,p_tool,p_n)
  on conflict (user_id,tool_code) do update set charges=excluded.charges
$$;

create function pg_temp.sg_phase(p_room uuid, p_phase text, p_number int default null)
returns void language sql as $$
  update public.room_state set phase=p_phase, phase_number=coalesce(p_number,phase_number)
   where room_id=p_room
$$;

-- The refusal contract: the exact code, no charge, no use row, no public line.
create function pg_temp.sg_refuse(p_user uuid, p_room uuid, p_tool text, p_targets int[],
  p_note text, p_code text) returns void language plpgsql as $$
declare c0 int; u0 int; l0 jsonb;
begin
  c0:=pg_temp.sg_charges(p_user,p_tool);
  select count(*) into u0 from public.room_tool_uses where room_id=p_room;
  select public_data->'toolLog' into l0 from public.room_state where room_id=p_room;
  begin
    perform public.use_table_tool(p_user,p_room,p_tool,p_targets,p_note);
    raise exception 'ACCEPTED % (wanted %)',p_tool,p_code;
  exception when others then
    if sqlerrm<>p_code then
      raise exception 'wrong refusal for %: wanted %, got %',p_tool,p_code,sqlerrm;
    end if;
  end;
  assert pg_temp.sg_charges(p_user,p_tool)=c0, 'refusal charged '||p_tool||' '||p_code;
  assert (select count(*) from public.room_tool_uses where room_id=p_room)=u0,
    'refusal wrote a use '||p_tool||' '||p_code;
  assert (select public_data->'toolLog' from public.room_state where room_id=p_room)
    is not distinct from l0, 'refusal wrote the public log '||p_tool||' '||p_code;
end $$;

create function pg_temp.sg_last_log(p_room uuid) returns jsonb language sql as $$
  select public_data->'toolLog'->-1 from public.room_state where room_id=p_room
$$;

-- M4-19 anon_note: a public, short, anonymous message; wrong phase, empty or
-- long notes are refused before any charge.
do $$
declare r uuid; a uuid; dead_user uuid; ph text; entry jsonb; res jsonb; hundred_forty text:=repeat('ن',140);
begin
  r:=pg_temp.sg_room(array['citizen','mafia','citizen','doctor','citizen'],'discuss');
  a:=pg_temp.sg_user(r,0); dead_user:=pg_temp.sg_user(r,4);
  perform pg_temp.sg_give(a,'anon_note',3);
  perform pg_temp.sg_give(dead_user,'anon_note',3);

  perform pg_temp.sg_refuse(a,r,'anon_note','{}',null,'BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'anon_note','{}','','BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'anon_note','{}','   ','BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'anon_note','{}',repeat('ن',141),'BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'anon_note','{1}','hi','BAD_TARGETS');
  foreach ph in array array['night','vote','verdict','reveal','result'] loop
    perform pg_temp.sg_phase(r,ph);
    perform pg_temp.sg_refuse(a,r,'anon_note','{}','hi','WRONG_PHASE');
  end loop;
  perform pg_temp.sg_phase(r,'discuss');
  update public.room_players set alive=false where room_id=r and user_id=dead_user;
  perform pg_temp.sg_refuse(dead_user,r,'anon_note','{}','hi','NOT_ALIVE');

  res:=public.use_table_tool(a,r,'anon_note','{}','  proof  ');
  assert pg_temp.sg_charges(a,'anon_note')=2, 'one note, one charge';
  entry:=pg_temp.sg_last_log(r);
  assert entry->>'tool'='anon_note' and entry->>'note'='proof', 'note not delivered trimmed: '||entry::text;
  assert entry->'seat'='null'::jsonb and entry->'targets'='[]'::jsonb,
    'the public line names no author and no target: '||entry::text;
  assert (select array_agg(k order by k) from jsonb_object_keys(entry) k)
    =array['note','phaseNumber','seat','targets','tool'], 'unexpected public keys: '||entry::text;
  assert (select public_data::text from public.room_state where room_id=r)
    !~ '(mafia|silencer|doctor|detective|citizen|elder|sniper)', 'a role word reached the public payload';
  -- The author's seat is kept on the server row only, which no client can read.
  assert (select seat from public.room_tool_uses where room_id=r and tool_code='anon_note')=0;
  assert not has_table_privilege('authenticated','public.room_tool_uses','select')
    and not has_table_privilege('anon','public.room_tool_uses','select'),
    'a client can read who wrote the note';

  perform pg_temp.sg_refuse(a,r,'anon_note','{}','again','LIMIT_PHASE');
  perform pg_temp.sg_phase(r,'discuss',2);
  perform public.use_table_tool(a,r,'anon_note','{}',hundred_forty);
  assert length(pg_temp.sg_last_log(r)->>'note')=140, 'a 140 character note is the longest accepted';
  perform pg_temp.sg_phase(r,'discuss',3);
  perform pg_temp.sg_refuse(a,r,'anon_note','{}','third','LIMIT_TOOL');
  assert pg_temp.sg_charges(a,'anon_note')=1, 'only the two delivered notes were charged';
end $$;

-- M4-20 last_will: read at once after exit; refused at night without spending.
do $$
declare r uuid; a uuid; b uuid; entry jsonb;
begin
  r:=pg_temp.sg_room(array['citizen','mafia','citizen','doctor','citizen'],'morning');
  a:=pg_temp.sg_user(r,2); b:=pg_temp.sg_user(r,0);
  perform pg_temp.sg_give(a,'last_will',2);
  perform pg_temp.sg_give(b,'last_will',2);

  -- A living player cannot write a will: the dead tool needs a dead seat.
  perform pg_temp.sg_refuse(b,r,'last_will','{}','my will','ALIVE');
  update public.room_players set alive=false where room_id=r and user_id=a;
  -- The night is closed to a will, and nothing is spent.
  perform pg_temp.sg_phase(r,'night');
  perform pg_temp.sg_refuse(a,r,'last_will','{}','my will','WRONG_PHASE');
  perform pg_temp.sg_phase(r,'morning');
  perform pg_temp.sg_refuse(a,r,'last_will','{}','','BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'last_will','{}',null,'BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'last_will','{}',repeat('ن',141),'BAD_NOTE');
  update public.room_players set kicked=true where room_id=r and user_id=a;
  perform pg_temp.sg_refuse(a,r,'last_will','{}','my will','NOT_A_MEMBER');
  update public.room_players set kicked=false where room_id=r and user_id=a;

  perform public.use_table_tool(a,r,'last_will','{}','لا تثقوا بالجار');
  entry:=pg_temp.sg_last_log(r);
  assert entry->>'tool'='last_will' and entry->>'note'='لا تثقوا بالجار' and (entry->>'seat')::int=2,
    'the will is on the public line at once: '||entry::text;
  assert pg_temp.sg_charges(a,'last_will')=1, 'one will, one charge';
  -- Dead seat, public phase: the same table state every client reads.
  assert (select phase from public.room_state where room_id=r)='morning';
  perform pg_temp.sg_refuse(a,r,'last_will','{}','second','LIMIT_TOOL');
end $$;

-- M4-26 double_vote: a silenced or dead owner cannot buy a useless ballot; a
-- valid purchase is on the public line for everyone.
do $$
declare r uuid; a uuid; b uuid; ph text; entry jsonb;
begin
  r:=pg_temp.sg_room(array['citizen','mafia','citizen','doctor','citizen'],'discuss');
  a:=pg_temp.sg_user(r,0); b:=pg_temp.sg_user(r,2);
  perform pg_temp.sg_give(a,'double_vote',2);
  perform pg_temp.sg_give(b,'double_vote',2);

  update public.room_state set public_data='{"morning":{"silencedSeat":0}}' where room_id=r;
  perform pg_temp.sg_refuse(a,r,'double_vote','{}',null,'SILENCED');
  update public.room_state set public_data='{"morning":{"silencedSeat":null}}' where room_id=r;
  foreach ph in array array['night','verdict','reveal','result'] loop
    perform pg_temp.sg_phase(r,ph);
    perform pg_temp.sg_refuse(a,r,'double_vote','{}',null,'WRONG_PHASE');
  end loop;
  perform pg_temp.sg_phase(r,'discuss');
  update public.room_players set alive=false where room_id=r and user_id=b;
  perform pg_temp.sg_refuse(b,r,'double_vote','{}',null,'NOT_ALIVE');

  -- Someone else being silenced does not block the owner.
  update public.room_state set public_data='{"morning":{"silencedSeat":3}}' where room_id=r;
  perform public.use_table_tool(a,r,'double_vote','{}',null);
  entry:=pg_temp.sg_last_log(r);
  assert entry->>'tool'='double_vote' and (entry->>'seat')::int=0 and entry->'targets'='[]'::jsonb,
    'the doubled ballot is announced with its owner: '||entry::text;
  assert pg_temp.sg_charges(a,'double_vote')=1;
  perform pg_temp.sg_refuse(a,r,'double_vote','{}',null,'LIMIT_TOOL');
  perform pg_temp.sg_phase(r,'discuss',2);
  perform pg_temp.sg_refuse(a,r,'double_vote','{}',null,'LIMIT_TOOL');
end $$;

-- M4-27 camouflage: bought in the day, secret on the public line.
do $$
declare r uuid; a uuid; entry jsonb;
begin
  r:=pg_temp.sg_room(array['citizen','mafia','citizen','doctor','citizen'],'discuss');
  a:=pg_temp.sg_user(r,1);
  perform pg_temp.sg_give(a,'camouflage',1);
  perform pg_temp.sg_phase(r,'vote');
  perform pg_temp.sg_refuse(a,r,'camouflage','{}',null,'WRONG_PHASE');
  perform pg_temp.sg_phase(r,'discuss');
  perform public.use_table_tool(a,r,'camouflage','{}',null);
  entry:=pg_temp.sg_last_log(r);
  assert entry->'seat'='null'::jsonb and entry->'targets'='[]'::jsonb and entry->'note'='null'::jsonb
    and entry->>'tool'='camouflage', 'camouflage is secret on the public line: '||entry::text;
  assert (select public_data::text from public.room_state where room_id=r)
    !~ '(mafia|silencer|doctor|detective|citizen|elder|sniper)', 'a role word reached the public payload';
end $$;

-- M4-28 revote: one purchase in the opening ballot only; never bought for a
-- second round, so a table can never be sent to a third.
do $$
declare r uuid; a uuid; entry jsonb;
begin
  r:=pg_temp.sg_room(array['citizen','mafia','citizen','doctor','citizen'],'vote');
  a:=pg_temp.sg_user(r,0);
  perform pg_temp.sg_give(a,'revote',3);
  perform pg_temp.sg_phase(r,'night');
  perform pg_temp.sg_refuse(a,r,'revote','{}',null,'WRONG_PHASE');
  perform pg_temp.sg_phase(r,'vote');
  update public.room_state set public_data='{"morning":{"silencedSeat":null},"revote":{"round":2,"tiedSeats":[1,2]}}'
   where room_id=r;
  perform pg_temp.sg_refuse(a,r,'revote','{}',null,'WRONG_PHASE');
  update public.room_state set public_data='{"morning":{"silencedSeat":null}}' where room_id=r;
  perform public.use_table_tool(a,r,'revote','{}',null);
  entry:=pg_temp.sg_last_log(r);
  assert entry->>'tool'='revote' and (entry->>'seat')::int=0, 'revote is announced: '||entry::text;
  assert pg_temp.sg_charges(a,'revote')=2;
  perform pg_temp.sg_refuse(a,r,'revote','{}',null,'LIMIT_TOOL');
  perform pg_temp.sg_phase(r,'vote',2);
  perform pg_temp.sg_refuse(a,r,'revote','{}',null,'LIMIT_TOOL');
  assert pg_temp.sg_charges(a,'revote')=2, 'a refused third ballot costs nothing';
end $$;

-- M4-29 grave_vote is retired (20261022000100): off the store, refused in every
-- match, and an old charge is never spent.
do $$
declare r uuid; a uuid;
begin
  r:=pg_temp.sg_room(array['citizen','mafia','citizen','doctor','citizen','citizen'],'vote');
  a:=pg_temp.sg_user(r,2);
  perform pg_temp.sg_give(a,'grave_vote',2);
  update public.room_players set alive=false where room_id=r and user_id=a;
  perform pg_temp.sg_refuse(a,r,'grave_vote','{}',null,'ITEM_NOT_FOUND');
  assert pg_temp.sg_charges(a,'grave_vote')=2, 'a retired tool spends nothing';
  assert not exists(select 1 from jsonb_array_elements(public.table_tools_snapshot(a)->'tools') x
                     where x->>'code'='grave_vote'), 'a retired tool is not offered';
  begin
    perform public.buy_table_tool(a,'grave_vote',1);
    raise exception 'a retired tool was sold';
  exception when others then
    assert sqlerrm='ITEM_NOT_FOUND', sqlerrm;
  end;
end $$;

-- M4-30 sense and M4-32 narrator_whisper: distinct legal living targets; a true
-- private answer that is never written on the public line.
do $$
declare r uuid; a uuid; b uuid; res jsonb; entry jsonb; mine jsonb; theirs jsonb; ph text;
begin
  -- seat: 0 citizen, 1 citizen, 2 doctor, 3 silencer, 4 citizen, 5 mafia, 6 detective
  r:=pg_temp.sg_room(array['citizen','citizen','doctor','silencer','citizen','mafia','detective'],'night');
  a:=pg_temp.sg_user(r,0); b:=pg_temp.sg_user(r,6);
  perform pg_temp.sg_give(a,'sense',3);
  perform pg_temp.sg_give(a,'narrator_whisper',3);
  perform pg_temp.sg_give(b,'sense',1);

  -- Three distinct, living, other seats for sense; two for the whisper.
  perform pg_temp.sg_refuse(a,r,'sense','{1,2}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'sense','{1,2,3,4}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'sense','{1,1,2}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'sense','{0,1,2}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'sense','{1,2,7}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'sense','{}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'narrator_whisper','{1}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'narrator_whisper','{1,2,3}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'narrator_whisper','{2,2}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'narrator_whisper','{0,2}',null,'BAD_TARGETS');
  update public.room_players set alive=false where room_id=r and seat=4;
  perform pg_temp.sg_refuse(a,r,'sense','{1,2,4}',null,'BAD_TARGETS');
  perform pg_temp.sg_refuse(a,r,'narrator_whisper','{1,4}',null,'BAD_TARGETS');
  foreach ph in array array['discuss','vote','morning','verdict'] loop
    perform pg_temp.sg_phase(r,ph);
    perform pg_temp.sg_refuse(a,r,'sense','{1,2,3}',null,'WRONG_PHASE');
    perform pg_temp.sg_refuse(a,r,'narrator_whisper','{1,2}',null,'WRONG_PHASE');
  end loop;
  perform pg_temp.sg_phase(r,'night');

  -- A silencer among the chosen seats counts as Mafia: the answer is yes.
  res:=public.use_table_tool(a,r,'sense','{1,2,3}',null);
  assert (res->>'answer')::boolean is true, 'sense: a silencer is among the seats: '||res::text;
  assert (res->>'seat')::int=0, 'the answer goes back to the asker';
  entry:=pg_temp.sg_last_log(r);
  assert entry->>'tool'='sense' and entry->'targets'='[]'::jsonb and not (entry ? 'answer'),
    'the public line carries neither the targets nor the answer: '||entry::text;
  -- Only town among the chosen seats: no.
  update public.room_state set phase_number=2 where room_id=r;
  perform pg_temp.sg_give(a,'sense',3);
  -- (one sense per match: the second purchase is a limit, answered below)
  perform pg_temp.sg_refuse(a,r,'sense','{1,2,6}',null,'LIMIT_TOOL');
  -- The narrator whisper is its own tool: no mafioso among seats 1 and 2 -> no.
  res:=public.use_table_tool(a,r,'narrator_whisper','{1,2}',null);
  assert (res->>'answer')::boolean is false, 'whisper over two town seats is no: '||res::text;
  entry:=pg_temp.sg_last_log(r);
  assert entry->>'tool'='narrator_whisper' and entry->'targets'='[]'::jsonb and not (entry ? 'answer'),
    'the whisper names nobody on the public line: '||entry::text;
  -- Another asker, mafioso chosen directly -> yes.
  res:=public.use_table_tool(b,r,'sense','{1,3,5}',null);
  assert (res->>'answer')::boolean is true, 'sense over a mafioso is yes: '||res::text;

  -- The answers are stored with the asker and read back for the asker only.
  mine:=public.my_tool_answers(a,r);
  theirs:=public.my_tool_answers(b,r);
  assert jsonb_array_length(mine->'answers')=2 and jsonb_array_length(theirs->'answers')=1,
    'each asker reads only his own answers: '||mine::text||' / '||theirs::text;
  assert (mine->'answers'->0->>'answer')::boolean is true
    and (mine->'answers'->1->>'answer')::boolean is false, mine::text;
  assert not (select public_data::text from public.room_state where room_id=r) ~ 'answer',
    'an answer reached the public payload';
  assert not has_function_privilege('authenticated','public.my_tool_answers(uuid,uuid)','execute')
    and not has_table_privilege('authenticated','public.room_tool_uses','select'),
    'a client can read someone else''s answer';
end $$;

-- M4-31 impersonate: only the two real faces; the chosen face is never public.
do $$
declare r uuid; a uuid; entry jsonb; face text;
begin
  r:=pg_temp.sg_room(array['citizen','mafia','citizen','doctor','citizen'],'discuss');
  a:=pg_temp.sg_user(r,1);
  perform pg_temp.sg_give(a,'impersonate',2);
  perform pg_temp.sg_refuse(a,r,'impersonate','{}',null,'BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'impersonate','{}','','BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'impersonate','{}','doctor','BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'impersonate','{}','Mafia','BAD_NOTE');
  perform pg_temp.sg_refuse(a,r,'impersonate','{}','detective','BAD_NOTE');
  perform pg_temp.sg_phase(r,'night');
  perform pg_temp.sg_refuse(a,r,'impersonate','{}','citizen','WRONG_PHASE');
  perform pg_temp.sg_phase(r,'discuss');
  update public.room_players set alive=false where room_id=r and seat=1;
  perform pg_temp.sg_refuse(a,r,'impersonate','{}','citizen','NOT_ALIVE');
  update public.room_players set alive=true where room_id=r and seat=1;
  assert pg_temp.sg_charges(a,'impersonate')=2, 'a refused face costs nothing';

  face:='citizen';
  perform public.use_table_tool(a,r,'impersonate','{}',face);
  entry:=pg_temp.sg_last_log(r);
  assert entry->'seat'='null'::jsonb and entry->'note'='null'::jsonb and entry->'targets'='[]'::jsonb,
    'the face and its owner stay off the public line: '||entry::text;
  assert (select public_data::text from public.room_state where room_id=r) !~ 'citizen',
    'the chosen face reached the public payload';
  assert (select note from public.room_tool_uses where room_id=r and tool_code='impersonate')='citizen',
    'the face is kept on the server row for the Detective answer';
  assert not has_table_privilege('authenticated','public.room_tool_uses','select');
  -- The other real face is also accepted, in a later phase.
  perform pg_temp.sg_phase(r,'discuss',2);
  perform pg_temp.sg_refuse(a,r,'impersonate','{}','mafia','LIMIT_TOOL');
end $$;


-- M4-39 (serial walk; the row stays needs-live for the real race): at the moment
-- a seat is kicked, a match ends, a phase moves on, or a target dies, every
-- tool is refused with its own code and leaves no charge, use row or public line.
do $$
declare
  t record; r uuid; a uuid; targets int[]; good_phase text; bad_phase text; note text;
begin
  for t in select * from public.table_tools where active order by sort_order loop
    good_phase:=case t.phase when 'night' then 'night' when 'vote' then 'vote'
      when 'dead' then case when t.code='grave_vote' then 'vote' else 'discuss' end
      else 'discuss' end;
    bad_phase:=case when t.phase='night' then 'vote' else 'night' end;
    targets:=array(select generate_series(1,t.targets));
    note:=case when t.code in ('anon_note','last_will') then 'proof'
      when t.code='impersonate' then 'citizen' else null end;
    r:=pg_temp.sg_room(array['citizen','mafia','citizen','doctor','citizen','citizen','detective'],good_phase);
    a:=pg_temp.sg_user(r,0);
    perform pg_temp.sg_give(a,t.code,3);
    if t.phase='dead' then update public.room_players set alive=false where room_id=r and user_id=a; end if;

    -- The phase moved on (timer): wrong window, nothing written.
    perform pg_temp.sg_phase(r,bad_phase);
    perform pg_temp.sg_refuse(a,r,t.code,targets,note,'WRONG_PHASE');
    perform pg_temp.sg_phase(r,good_phase);
    -- Seat removed by the host between the tap and the write.
    update public.room_players set kicked=true where room_id=r and user_id=a;
    perform pg_temp.sg_refuse(a,r,t.code,targets,note,'NOT_A_MEMBER');
    update public.room_players set kicked=false where room_id=r and user_id=a;
    -- A chosen target died first.
    if t.targets>0 then
      update public.room_players set alive=false where room_id=r and seat=1;
      perform pg_temp.sg_refuse(a,r,t.code,targets,note,'BAD_TARGETS');
      update public.room_players set alive=true where room_id=r and seat=1;
    end if;
    -- The match ended first.
    update public.rooms set status='finished', ended_at=now() where id=r;
    perform pg_temp.sg_refuse(a,r,t.code,targets,note,'NOT_PLAYING');
    update public.rooms set status='playing', ended_at=null where id=r;
    assert pg_temp.sg_charges(a,t.code)=3, 'a refusal charged '||t.code;
    assert (select count(*) from public.room_tool_uses where room_id=r)=0, 'a refusal left a use '||t.code;
    -- And the same request, once the window is right, is spent exactly once.
    perform public.use_table_tool(a,r,t.code,targets,note);
    assert pg_temp.sg_charges(a,t.code)=2 and (select count(*) from public.room_tool_uses where room_id=r)=1,
      'the one valid use was not charged exactly once: '||t.code;
  end loop;
end $$;

-- M4-40: what a seat bought outlives its connection and its seat. A disconnect
-- and a reconnect change neither the use nor the public line; a kicked author's
-- note stays, a kicked seat can buy nothing further.
do $$
declare r uuid; a uuid; b uuid; host uuid; before_log jsonb; removed uuid;
begin
  r:=pg_temp.sg_room(array['citizen','mafia','citizen','doctor','citizen','citizen','detective'],'discuss');
  host:=pg_temp.sg_user(r,0); a:=pg_temp.sg_user(r,2); b:=pg_temp.sg_user(r,4);
  perform pg_temp.sg_give(a,'anon_note',2);
  perform pg_temp.sg_give(a,'double_vote',1);
  perform pg_temp.sg_give(b,'lock_door',1);
  perform public.use_table_tool(a,r,'anon_note','{}','still here');
  perform public.use_table_tool(a,r,'double_vote','{}',null);
  perform public.use_table_tool(b,r,'lock_door','{}',null);
  before_log:=(select public_data->'toolLog' from public.room_state where room_id=r);

  -- Connection drops (away, then left) and returns: the spent effect is the same rows, nothing replays.
  update public.room_players set status='away' where room_id=r and user_id in (a,b);
  update public.room_players set status='left' where room_id=r and user_id in (a,b);
  update public.room_players set status='connected' where room_id=r and user_id in (a,b);
  assert (select public_data->'toolLog' from public.room_state where room_id=r)=before_log,
    'a reconnect changed the table''s tool line';
  assert (select count(*) from public.room_tool_uses where room_id=r)=3;
  perform pg_temp.sg_refuse(b,r,'lock_door','{}',null,'LIMIT_TOOL');
  assert pg_temp.sg_charges(b,'lock_door')=0 and pg_temp.sg_charges(a,'anon_note')=1,
    'a reconnect gave back or took a charge';

  -- The host removes the author: the seat is out, its note and its uses stay.
  removed:=public.kick_member(r,host,2);
  assert removed=a, 'wrong seat removed';
  assert (select public_data->'toolLog' from public.room_state where room_id=r)=before_log,
    'a kick rewrote the table''s tool line';
  assert (select count(*) from public.room_tool_uses where room_id=r and user_id=a)=2,
    'a kick erased the author''s uses';
  perform pg_temp.sg_refuse(a,r,'anon_note','{}','one more','NOT_A_MEMBER');
  assert pg_temp.sg_charges(a,'anon_note')=1, 'the kicked seat''s remaining charge was spent or refunded';
end $$;

-- M4-37 and M4-36 (serial order; M4-36 stays needs-live for real concurrency):
-- a refused pack leaves no coin, ledger, charge or request behind; a repeated
-- request id grants once; a balance never goes below zero.
create function pg_temp.sg_wallet(p_user uuid) returns text language sql as $$
  select coalesce((select balance||'/'||lifetime_spent from public.wallet_accounts where user_id=p_user),'none')
    ||'/ledger '||(select count(*) from public.wallet_ledger where user_id=p_user)
    ||'/charges '||(select coalesce(sum(charges),0) from public.player_tool_charges where user_id=p_user)
    ||'/requests '||(select count(*) from public.tool_purchase_requests where user_id=p_user)
$$;

create function pg_temp.sg_buy_refuse(p_user uuid, p_tool text, p_pack int, p_request uuid, p_code text)
returns void language plpgsql as $$
declare before_state text:=pg_temp.sg_wallet(p_user);
begin
  begin
    perform public.buy_table_tool(p_user,p_tool,p_pack,p_request);
    raise exception 'ACCEPTED % x% (wanted %)',p_tool,p_pack,p_code;
  exception when others then
    if sqlerrm<>p_code then
      raise exception 'wrong refusal for % x%: wanted %, got %',p_tool,p_pack,p_code,sqlerrm;
    end if;
  end;
  assert pg_temp.sg_wallet(p_user)=before_state,
    'a refused purchase left a trace: '||before_state||' -> '||pg_temp.sg_wallet(p_user);
end $$;

do $$
declare u uuid:=gen_random_uuid(); poor uuid:=gen_random_uuid(); req uuid:=gen_random_uuid();
  req2 uuid:=gen_random_uuid(); snap jsonb;
begin
  insert into auth.users(id,is_anonymous) values(u,true),(poor,true);
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values(u,1000,1000),(poor,149,149);
  assert public.tool_pack_price(150,1)=150 and public.tool_pack_price(150,3)=420
    and public.tool_pack_price(150,7)=950, 'pack prices of extra_minute';

  -- M4-37: wrong pack, unknown or inactive tool, too few coins.
  perform pg_temp.sg_buy_refuse(u,'extra_minute',0,null,'BAD_PACK');
  perform pg_temp.sg_buy_refuse(u,'extra_minute',2,req,'BAD_PACK');
  perform pg_temp.sg_buy_refuse(u,'extra_minute',10,null,'BAD_PACK');
  perform pg_temp.sg_buy_refuse(u,'no_such_tool',1,null,'ITEM_NOT_FOUND');
  update public.table_tools set active=false where code='extra_minute';
  perform pg_temp.sg_buy_refuse(u,'extra_minute',1,req,'ITEM_NOT_FOUND');
  update public.table_tools set active=true where code='extra_minute';
  perform pg_temp.sg_buy_refuse(poor,'extra_minute',1,req,'INSUFFICIENT_COINS');
  assert not exists(select 1 from public.tool_purchase_requests where request_id=req),
    'a refused request id was left behind and would block the retry';
  assert (select balance from public.wallet_accounts where user_id=poor)=149;

  -- The refused request id is free: once the coins are there the same id buys.
  update public.wallet_accounts set balance=150, lifetime_earned=150 where user_id=poor;
  snap:=public.buy_table_tool(poor,'extra_minute',1,req);
  assert (select balance from public.wallet_accounts where user_id=poor)=0, 'exact balance spent';
  assert (select charges from public.player_tool_charges where user_id=poor and tool_code='extra_minute')=1;
  -- Nothing left: the next purchase is refused and the balance stays at zero.
  perform pg_temp.sg_buy_refuse(poor,'extra_minute',1,gen_random_uuid(),'INSUFFICIENT_COINS');
  assert (select balance from public.wallet_accounts where user_id=poor)=0, 'balance went below zero';

  -- M4-36 serial: the same request id again grants and charges nothing more.
  snap:=public.buy_table_tool(u,'extra_minute',1,req2);
  snap:=public.buy_table_tool(u,'extra_minute',1,req2);
  snap:=public.buy_table_tool(u,'extra_minute',1,req2);
  assert (select balance from public.wallet_accounts where user_id=u)=850, 'charged more than once';
  assert (select charges from public.player_tool_charges where user_id=u and tool_code='extra_minute')=1;
  assert (select count(*) from public.wallet_ledger where user_id=u and kind='tool_spend')=1,
    'one ledger line for one request';
  -- A new request id is a new purchase; a 3-pack is priced and granted as 3.
  snap:=public.buy_table_tool(u,'extra_minute',3,gen_random_uuid());
  assert (select balance from public.wallet_accounts where user_id=u)=850-420, 'three-pack price';
  assert (select charges from public.player_tool_charges where user_id=u and tool_code='extra_minute')=4;
  assert (select lifetime_spent from public.wallet_accounts where user_id=u)=150+420;
  -- Two packs that together cost more than the balance: the second is refused whole.
  perform pg_temp.sg_buy_refuse(u,'extra_minute',7,gen_random_uuid(),'INSUFFICIENT_COINS');
  assert (select balance from public.wallet_accounts where user_id=u)=430, 'refused pack changed the balance';
end $$;


-- M4-44 and M4-45: the optional rewarded ad (daily vault offer). A claim alone
-- pays nothing; only a verified completion pays, once; a late confirmation is
-- still waiting for the player when the app is reopened.
do $$
declare u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); w uuid:=gen_random_uuid();
  day date:=public.economy_today(); c jsonb; claim uuid; claim_v uuid; again jsonb; st jsonb;
  room uuid:=gen_random_uuid(); amount bigint;
begin
  insert into auth.users(id,is_anonymous) values(u,true),(v,true),(w,true);
  insert into public.wallet_accounts(user_id) values(u),(v),(w);
  update public.economy_config set daily_enabled=true, daily_ad_enabled=true;
  select daily_ad_coins into amount from public.economy_config;

  -- A claim made, the ad closed or failed: no callback ever comes. Nothing is paid.
  c:=public.create_daily_ad_claim(v,day); claim_v:=(c->>'claimId')::uuid;
  assert c->>'state'='pending' and (c->>'amount')::bigint=amount, c::text;
  assert (select balance from public.wallet_accounts where user_id=v)=0
    and not exists(select 1 from public.wallet_ledger where user_id=v), 'a bare claim paid';
  again:=public.create_daily_ad_claim(v,day);
  assert (again->>'claimId')::uuid=claim_v and again->>'state'='pending', 'reopen made a second claim: '||again::text;
  assert public.daily_status(v)->'ad'->>'state'='pending' and (public.daily_status(v)->'ad'->>'claimId')::uuid=claim_v;

  -- Callbacks that are not a verified completion for this claim pay nothing.
  begin perform public.commit_daily_ad(claim_v,'short','unit',1,v); assert false, 'short transaction id paid';
  exception when others then assert sqlerrm='BAD_SSV', sqlerrm; end;
  begin perform public.commit_daily_ad(claim_v,null,'unit',1,v); assert false, 'missing transaction id paid';
  exception when others then assert sqlerrm='BAD_SSV', sqlerrm; end;
  begin perform public.commit_daily_ad(claim_v,'zero-reward-0001','unit',0,v); assert false, 'zero reward paid';
  exception when others then assert sqlerrm='BAD_SSV', sqlerrm; end;
  begin perform public.commit_daily_ad(claim_v,'someone-else-001','unit',1,u); assert false, 'another player completed it';
  exception when others then assert sqlerrm='CLAIM_NOT_FOUND', sqlerrm; end;
  begin perform public.commit_daily_ad(gen_random_uuid(),'unknown-claim-01','unit',1,v); assert false, 'unknown claim paid';
  exception when others then assert sqlerrm='CLAIM_NOT_FOUND', sqlerrm; end;
  assert (select balance from public.wallet_accounts where user_id=v)=0
    and not exists(select 1 from public.wallet_ledger where user_id=v)
    and not exists(select 1 from public.ad_ssv_transactions where user_id=v)
    and (select state from public.daily_ad_claims where id=claim_v)='pending',
    'a refused callback left a credit, a ledger line or a spent transaction';

  -- M4-44: claim, the app is closed while the ad completes, the confirmation is late.
  c:=public.create_daily_ad_claim(u,day); claim:=(c->>'claimId')::uuid;
  assert (select balance from public.wallet_accounts where user_id=u)=0;
  again:=public.create_daily_ad_claim(u,day);
  assert (again->>'claimId')::uuid=claim and again->>'state'='pending', 'reopen before the confirmation';
  st:=public.commit_daily_ad(claim,'late-callback-001','unit-1',1,u);
  assert st->>'state'='awarded' and (st->>'amount')::bigint=amount, st::text;
  assert (select balance from public.wallet_accounts where user_id=u)=amount, 'exactly one credit';
  -- The app is opened again: the same claim reads awarded, nothing new to claim.
  again:=public.create_daily_ad_claim(u,day);
  assert (again->>'claimId')::uuid=claim and again->>'state'='awarded', 'reopen after: '||again::text;
  assert public.daily_status(u)->'ad'->>'state'='awarded';

  -- M4-45: the same callback delivered again, or another one for the same claim.
  st:=public.commit_daily_ad(claim,'late-callback-001','unit-1',1,u);
  assert st->>'state'='awarded' and (select balance from public.wallet_accounts where user_id=u)=amount,
    'a repeated callback paid again';
  begin perform public.commit_daily_ad(claim,'late-callback-002','unit-1',1,u); assert false, 'second transaction paid';
  exception when others then assert sqlerrm='CLAIM_ALREADY_USED', sqlerrm; end;
  begin perform public.commit_daily_ad(claim_v,'late-callback-001','unit-1',1,v); assert false, 'a spent transaction paid another claim';
  exception when others then assert sqlerrm='TRANSACTION_ALREADY_USED', sqlerrm; end;
  assert (select count(*) from public.wallet_ledger where user_id=u and kind='daily_ad')=1
    and (select balance from public.wallet_accounts where user_id=u)=amount
    and (select balance from public.wallet_accounts where user_id=v)=0,
    'duplicate callbacks changed a balance or the ledger';
  -- One claim a day: asking again never opens a second payable claim.
  assert (select count(*) from public.daily_ad_claims where user_id=u)=1;

  -- A player in a running match gets no claim at all.
  insert into public.rooms(id,code,host_id,match_seed,status,started_at)
    values(room,pg_temp.sg_code(),w,1,'playing',now());
  insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
    values(room,w,'W',0,'citizen',true,'connected');
  begin perform public.create_daily_ad_claim(w,day); assert false, 'claim opened inside a match';
  exception when others then assert sqlerrm='IN_MATCH', sqlerrm; end;
  assert not exists(select 1 from public.daily_ad_claims where user_id=w);
end $$;

-- M4-46 (serial taps; the row stays needs-live for real concurrency): a second
-- tap on the same item owns it once and charges once; the balance never goes
-- negative; a refusal changes nothing.
do $$
declare u uuid:=gen_random_uuid(); item text; price bigint; other text; other_price bigint;
  s1 jsonb; s2 jsonb; l int;
begin
  select code,coin_price into strict item,price from public.reward_catalog
    where active and released and kind='frame' order by coin_price,code limit 1;
  select code,coin_price into strict other,other_price from public.reward_catalog
    where active and released and kind='narrator_pack' order by coin_price desc,code limit 1;
  insert into auth.users(id,is_anonymous) values(u,true);
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values(u,price+50,price+50);

  s1:=public.buy_reward_item(u,item);
  s2:=public.buy_reward_item(u,item);
  assert (s1->>'balance')::bigint=50 and (s2->>'balance')::bigint=50, 'second tap charged again: '||s2::text;
  assert (select count(*) from public.player_inventory where user_id=u and item_code=item)=1, 'owned twice';
  assert (select count(*) from public.wallet_ledger where user_id=u and kind='catalog_spend' and item_code=item)=1
    and (select lifetime_spent from public.wallet_accounts where user_id=u)=price, 'one tap, one ledger line';

  -- Short of coins for the next item: refused, balance and inventory as they were.
  begin perform public.buy_reward_item(u,other); assert false, 'bought without enough coins';
  exception when others then assert sqlerrm='INSUFFICIENT_COINS', sqlerrm; end;
  begin perform public.buy_reward_item(u,other); assert false, 'second tap bought without enough coins';
  exception when others then assert sqlerrm='INSUFFICIENT_COINS', sqlerrm; end;
  assert (select balance from public.wallet_accounts where user_id=u)=50
    and (select count(*) from public.wallet_ledger where user_id=u)=1
    and not exists(select 1 from public.player_inventory where user_id=u and item_code=other),
    'a refused tap changed the wallet';
  -- The database itself refuses a negative balance, whoever asks.
  begin update public.wallet_accounts set balance=-1 where user_id=u; assert false, 'negative balance accepted';
  exception when check_violation then null; end;
end $$;

-- M4-48: purchased-coin debt offsets the next grant; the purchase receipt and
-- the reversal receipt are each applied once, in either order.
do $$
declare u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); tag text; vtag text; s jsonb; n int;
  w public.wallet_accounts; code text; hash2 text;
  t1 text:='debt-token-aaaa1'; t2 text:='debt-token-bbbb2'; t3 text:='order-first-tkn3'; t4 text:='grant-then-void4';
begin
  insert into auth.users(id) values(u),(v);
  tag:=public.account_tag(u); vtag:=public.account_tag(v);
  s:=public.commit_play_product(u,t1,'mm_coins_500','GPA.D1','active',now(),1,tag);
  assert (s->>'credited')::bigint=500, s::text;
  -- The same receipt presented again credits nothing more.
  s:=public.commit_play_product(u,t1,'mm_coins_500','GPA.D1','active',now(),1,tag);
  assert (select balance from public.wallet_accounts where user_id=u)=500
    and (select count(*) from public.wallet_ledger where user_id=u and kind='play_coin_purchase')=1,
    'a repeated purchase receipt credited twice';

  -- Spend all of it, and more, on tool charges that are then used up: the refund
  -- cannot be covered by taking anything back, so the shortfall becomes debt.
  update public.wallet_accounts set balance=balance+1000, lifetime_earned=lifetime_earned+1000 where user_id=u;
  foreach code in array array['extra_minute','spotlight','objection','anon_note'] loop
    perform public.buy_table_tool(u,code,1);
  end loop;
  update public.player_tool_charges set charges=0 where user_id=u;
  select * into w from public.wallet_accounts where user_id=u;
  assert w.balance=770 and w.purchased_balance=0 and w.purchase_debt=0, w::text;

  n:=public.revoke_voided_play_purchases(null,array['GPA.D1']);
  assert n=1, 'first refund not applied: '||n;
  select * into w from public.wallet_accounts where user_id=u;
  assert w.purchase_debt=500 and w.balance=770, 'refund must leave debt 500 and the balance alone: '||w::text;
  assert public.revoke_voided_play_purchases(null,array['GPA.D1'])=0, 'second refund applied';
  assert not public.reverse_play_coins(t1), 'reversal receipt applied twice';
  assert (select purchase_debt from public.wallet_accounts where user_id=u)=500, 'debt doubled';

  -- The next grant is eaten by the debt: no new coins, debt cleared, receipt recorded once.
  s:=public.commit_play_product(u,t2,'mm_coins_500','GPA.D2','active',now(),1,tag);
  s:=public.commit_play_product(u,t2,'mm_coins_500','GPA.D2','active',now(),1,tag);
  select * into w from public.wallet_accounts where user_id=u;
  assert w.balance=770 and w.purchase_debt=0, 'debt did not offset the grant: '||w::text;
  assert (select credited from public.play_purchases where purchase_token=t2)=0
    and (select debt_offset from public.play_purchases where purchase_token=t2)=500;
  -- Returning that grant puts the debt back, to 500 and not to 0 or 1000.
  assert public.revoke_voided_play_purchases(null,array['GPA.D2'])=1;
  assert public.revoke_voided_play_purchases(null,array['GPA.D2'])=0;
  select * into w from public.wallet_accounts where user_id=u;
  assert w.balance=770 and w.purchase_debt=500, 'offset not restored exactly once: '||w::text;

  -- Order of arrival, void first: the late grant never pays.
  assert public.revoke_voided_play_purchases(array[t3],array['GPA.D3'])=0;
  s:=public.commit_play_product(u,t3,'mm_coins_500','GPA.D3','active',now(),1,tag);
  s:=public.commit_play_product(u,t3,'mm_coins_500','GPA.D3','active',now(),1,tag);
  select * into w from public.wallet_accounts where user_id=u;
  assert s->>'state'='revoked' and not (s->>'granted')::boolean and w.balance=770 and w.purchase_debt=500,
    'a voided purchase paid when it arrived late: '||s::text||' '||w::text;

  -- Order of arrival, grant first: reversed once, and a stale "active" never re-grants it.
  s:=public.commit_play_product(v,t4,'mm_coins_500','GPA.D4','active',now(),1,vtag);
  assert (select balance from public.wallet_accounts where user_id=v)=500;
  assert public.revoke_voided_play_purchases(null,array['GPA.D4'])=1;
  assert (select balance from public.wallet_accounts where user_id=v)=0 and
    (select purchase_debt from public.wallet_accounts where user_id=v)=0;
  assert public.revoke_voided_play_purchases(null,array['GPA.D4'])=0;
  s:=public.commit_play_product(v,t4,'mm_coins_500','GPA.D4','active',now(),1,vtag);
  assert (select balance from public.wallet_accounts where user_id=v)=0
    and (select count(*) from public.wallet_ledger where user_id=v and kind='play_coin_reversal')=1
    and (select count(*) from public.wallet_ledger where user_id=v and kind='play_coin_purchase')=1,
    'ledger shows more than one purchase and one reversal';
end $$;

-- M4-49: refunding the coins takes back what those coins bought afterwards,
-- newest first and only as much as is needed: the item leaves the inventory and
-- its equipped slot; what was bought before the grant, or is not needed, stays.
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); s jsonb; w public.wallet_accounts;
  ta text:='refund-tokenA-01'; tb text:='refund-tokenB-01';
begin
  insert into auth.users(id) values(a),(b);
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values(a,3000,3000),(b,12000,12000);

  -- A: an older frame, then the purchase, then a frame and a narrator pack, both worn.
  perform public.buy_reward_item(a,'frame_crimson');
  update public.wallet_ledger set created_at=now()-interval '1 hour' where user_id=a and item_code='frame_crimson';
  s:=public.commit_play_product(a,ta,'mm_coins_500','GPA.RA','active',now(),1,public.account_tag(a));
  perform public.buy_reward_item(a,'frame_gilded');
  update public.wallet_ledger set created_at=now()+interval '1 second' where user_id=a and item_code='frame_gilded';
  perform public.buy_reward_item(a,'narrator_keeper');
  update public.wallet_ledger set created_at=now()+interval '2 seconds' where user_id=a and item_code='narrator_keeper';
  perform public.equip_reward_item(a,'frame','frame_gilded');
  perform public.equip_reward_item(a,'narrator','narrator_keeper');
  select * into w from public.wallet_accounts where user_id=a;
  assert w.balance=2050 and w.purchased_balance=0, w::text;

  assert public.revoke_voided_play_purchases(null,array['GPA.RA'])=1;
  assert not exists(select 1 from public.player_inventory where user_id=a and item_code='narrator_keeper'),
    'the newest purchase was not taken back';
  assert not exists(select 1 from public.player_equipment where user_id=a and slot='narrator'),
    'the taken-back item is still equipped';
  assert exists(select 1 from public.player_inventory where user_id=a and item_code='frame_gilded')
    and exists(select 1 from public.player_equipment where user_id=a and slot='frame' and item_code='frame_gilded'),
    'an item that was not needed to cover the refund was taken';
  assert exists(select 1 from public.player_inventory where user_id=a and item_code='frame_crimson'),
    'an item bought before the grant was taken';
  select * into w from public.wallet_accounts where user_id=a;
  assert w.purchase_debt=0 and w.balance=2550, 'earned share of the taken item must return: '||w::text;
  assert (select count(*) from public.play_refund_revocations r join public.wallet_ledger l on l.id=r.ledger_id
    where l.user_id=a)=1, 'only one purchase was taken back';
  assert public.revoke_voided_play_purchases(null,array['GPA.RA'])=0;

  -- B: a sold role bought after the grant is taken back; the role bought before stays.
  perform public.buy_reward_item(b,'role_sniper');
  update public.wallet_ledger set created_at=now()-interval '1 hour' where user_id=b and item_code='role_sniper';
  s:=public.commit_play_product(b,tb,'mm_coins_500','GPA.RB','active',now(),1,public.account_tag(b));
  perform public.buy_reward_item(b,'role_elder');
  update public.wallet_ledger set created_at=now()+interval '1 second' where user_id=b and item_code='role_elder';
  assert public.user_owns_item(b,'role_elder') and public.user_owns_item(b,'role_sniper');
  assert public.revoke_voided_play_purchases(null,array['GPA.RB'])=1;
  assert not public.user_owns_item(b,'role_elder'), 'a refunded role is still owned';
  assert public.user_owns_item(b,'role_sniper'), 'the older role was taken';
  select * into w from public.wallet_accounts where user_id=b;
  assert w.purchase_debt=0 and w.balance=6000, 'role refund balance: '||w::text;
end $$;

-- M4-56: the council seal and the invite frame are grants, never for sale; a
-- granted owner can wear them.
do $$
declare u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); snap jsonb; s jsonb;
begin
  insert into auth.users(id) values(u),(v);
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values(u,100000,100000),(v,100000,100000);

  -- Neither is in the catalogue the shop reads, and neither can be bought, however rich.
  snap:=public.wallet_snapshot(u);
  assert not (snap->'catalog') @> '[{"code":"frame_council_seal"}]'
    and not (snap->'catalog') @> '[{"code":"frame_invite"}]', 'a grant-only frame is in the shop';
  assert not exists(select 1 from public.reward_catalog where code in ('frame_council_seal','frame_invite') and active),
    'a grant-only frame is active in the catalogue';
  begin perform public.buy_reward_item(u,'frame_council_seal'); assert false, 'seal sold for coins';
  exception when others then assert sqlerrm='ITEM_NOT_FOUND', sqlerrm; end;
  begin perform public.buy_reward_item(u,'frame_invite'); assert false, 'invite frame sold for coins';
  exception when others then assert sqlerrm='ITEM_NOT_FOUND', sqlerrm; end;
  begin perform public.equip_reward_item(u,'frame','frame_council_seal'); assert false, 'worn without owning';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED', sqlerrm; end;
  begin perform public.equip_reward_item(u,'frame','frame_invite'); assert false, 'worn without owning';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED', sqlerrm; end;
  assert (select balance from public.wallet_accounts where user_id=u)=100000, 'a refused sale charged';

  -- The seal is granted by its starter product; the invite frame by the invite
  -- settlement, which puts it in the inventory exactly as below (the settlement
  -- itself is proved in economy_v3.sql).
  update public.play_products set active=true where product_id='mm_starter_bundle';
  s:=public.commit_play_product(u,'seal-grant-token1','mm_starter_bundle','GPA.S1','active',now(),1,public.account_tag(u));
  assert (s->>'granted')::boolean and s->>'item'='frame_council_seal', s::text;
  insert into public.player_inventory(user_id,item_code) values(v,'frame_invite');
  snap:=public.equip_reward_item(u,'frame','frame_council_seal');
  assert snap->'equipped'->>'frame'='frame_council_seal' and (snap->'owned') @> '["frame_council_seal"]', snap::text;
  snap:=public.equip_reward_item(v,'frame','frame_invite');
  assert snap->'equipped'->>'frame'='frame_invite' and (snap->'owned') @> '["frame_invite"]', snap::text;
  -- Still not for sale, even to the owner, and the other player's frame is not his.
  assert not (public.wallet_snapshot(u)->'catalog') @> '[{"code":"frame_council_seal"}]';
  begin perform public.equip_reward_item(u,'frame','frame_invite'); assert false, 'wore another player''s grant';
  exception when others then assert sqlerrm='ITEM_NOT_OWNED', sqlerrm; end;
end $$;

-- M4-43 (serial order; the row stays needs-live for real simultaneous settlement):
-- one receipt and one credit per player and match, however often the result is
-- refreshed or the settlement retried.
do $$
declare p uuid[]; i int; room uuid:=gen_random_uuid(); bal bigint; led int; rec public.match_receipts;
  ended timestamptz:=now()-interval '1 minute';
begin
  alter table public.votes disable trigger vote_phase_guard;
  for i in 1..5 loop
    p[i]:=gen_random_uuid();
    insert into auth.users(id,email,email_confirmed_at,is_anonymous)
      values(p[i],p[i]::text||'@store-gaps.test',now(),false);
  end loop;
  update public.economy_config set economy_v11_enabled=true;
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(room,pg_temp.sg_code(),p[1],'finished',1,ended-interval '20 minutes',ended);
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role,kicked)
      values(room,p[i],i-1,'Seat'||i,case when i=2 then 'mafia' else 'citizen' end,false);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(room,'result',jsonb_build_object('outcome','town'));
  insert into public.votes(room_id,day,voter_id,action_id)
    select room,1,unnest(p),gen_random_uuid();

  perform public.sync_player_rewards(p[1]);
  select * into rec from public.match_receipts where user_id=p[1] and room_id=room;
  assert rec.user_id is not null and rec.won and rec.completion_coins=25 and rec.win_coins=10, row_to_json(rec)::text;
  select balance into bal from public.wallet_accounts where user_id=p[1];
  select count(*) into led from public.wallet_ledger where user_id=p[1] and source_room=room;
  assert bal=25+10+rec.first_day_coins and led>=2, 'unexpected first credit '||bal||' '||led;

  -- Refresh, retry, another player's settlement, the direct issue and settle calls.
  perform public.sync_player_rewards(p[1]);
  perform public.sync_player_rewards(p[2]);
  perform public.sync_player_rewards(p[1]);
  rec:=public.economy_v3_issue_receipt(p[1],room);
  assert public.economy_v3_settle_receipt(p[1],room)=0, 'a settled receipt paid again';
  assert (select count(*) from public.match_receipts where user_id=p[1] and room_id=room)=1, 'two receipts';
  assert (select balance from public.wallet_accounts where user_id=p[1])=bal
    and (select count(*) from public.wallet_ledger where user_id=p[1] and source_room=room)=led,
    'a retry changed the balance or the ledger';
  assert (select count(*) from public.match_receipts where room_id=room)=2, 'one receipt per settled player';
end $$;


-- M4-3, M4-5 and M4-8 (Buy): each sold role is bought once, at its price, and
-- owned afterwards; a second tap or too few coins changes nothing.
do $$
declare u uuid:=gen_random_uuid(); poor uuid:=gen_random_uuid(); snap jsonb; item text; price bigint; bal bigint:=30000;
begin
  insert into auth.users(id,is_anonymous) values(u,true),(poor,true);
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values(u,30000,30000),(poor,4999,4999);
  assert (select count(*) from jsonb_array_elements(public.wallet_snapshot(u)->'catalog') e where e->>'kind'='role')=3,
    'the three sold roles are in the shop';
  foreach item in array array['role_silencer','role_elder','role_sniper'] loop
    select coin_price into strict price from public.reward_catalog where code=item;
    assert price=case item when 'role_silencer' then 7000 when 'role_elder' then 5000 else 6000 end, 'price of '||item;
    assert not public.user_owns_item(u,item), item||' owned before buying';
    snap:=public.buy_reward_item(u,item);
    snap:=public.buy_reward_item(u,item);
    bal:=bal-price;
    assert (snap->>'balance')::bigint=bal, 'charged other than once: '||item||' '||snap::text;
    assert public.user_owns_item(u,item), item||' not owned after buying';
    assert (select count(*) from public.wallet_ledger where user_id=u and kind='catalog_spend' and item_code=item)=1;
  end loop;
  begin perform public.buy_reward_item(poor,'role_elder'); assert false, 'bought a role one coin short';
  exception when others then assert sqlerrm='INSUFFICIENT_COINS', sqlerrm; end;
  assert not public.user_owns_item(poor,'role_elder')
    and (select balance from public.wallet_accounts where user_id=poor)=4999
    and not exists(select 1 from public.wallet_ledger where user_id=poor), 'a refused role purchase left a trace';
end $$;

-- M4-5 and M4-6: the Elder's reveal. Only a living Elder, only by day, once; it
-- costs nothing; before it, nothing public hints at the role.
do $$
declare r uuid; elder_user uuid; citizen_user uuid; ph text; pd jsonb; wallet_rows int; charge_rows int; ok boolean;
begin
  r:=pg_temp.sg_room(array['citizen','mafia','elder','doctor','citizen','citizen'],'discuss');
  elder_user:=pg_temp.sg_user(r,2); citizen_user:=pg_temp.sg_user(r,0);
  select (select count(*) from public.wallet_ledger), (select count(*) from public.player_tool_charges)
    into wallet_rows, charge_rows;

  -- Before any reveal the public payload names nobody and no role.
  assert not (select public_data ? 'elderRevealedSeats' from public.room_state where room_id=r), 'a reveal marker before the reveal';
  assert (select public_data::text from public.room_state where room_id=r) !~ 'elder', 'a hint of the role before the reveal';

  -- Wrong phase: night, the reveal screen, the result, the defence.
  foreach ph in array array['night','reveal','result','defense'] loop
    perform pg_temp.sg_phase(r,ph);
    assert not public.reveal_elder_role(r,elder_user), 'revealed in '||ph;
  end loop;
  perform pg_temp.sg_phase(r,'discuss');
  -- Not the Elder: refused and nothing written.
  assert not public.reveal_elder_role(r,citizen_user), 'a citizen revealed as Elder';
  assert not public.reveal_elder_role(r,pg_temp.sg_user(r,1)), 'the Mafia revealed as Elder';
  -- Dead Elder: refused.
  update public.room_players set alive=false where room_id=r and user_id=elder_user;
  assert not public.reveal_elder_role(r,elder_user), 'a dead Elder revealed';
  update public.room_players set alive=true where room_id=r and user_id=elder_user;
  assert not (select public_data ? 'elderRevealedSeats' from public.room_state where room_id=r), 'a refusal wrote the marker';

  -- Every day phase is a window; the reveal marks the seat, never a role word.
  foreach ph in array array['morning','opening','confront','discuss','vote','verdict'] loop
    delete from public.room_state where room_id=r;
    insert into public.room_state(room_id,phase,phase_number,public_data) values(r,ph,1,'{}');
    assert public.reveal_elder_role(r,elder_user), 'refused in '||ph;
    assert (select public_data->'elderRevealedSeats' from public.room_state where room_id=r)='[2]'::jsonb;
  end loop;
  -- Repeated: still true and still one entry, so the ballot is never weighted twice.
  assert public.reveal_elder_role(r,elder_user) and public.reveal_elder_role(r,elder_user);
  assert (select public_data->'elderRevealedSeats' from public.room_state where room_id=r)='[2]'::jsonb, 'duplicated marker';
  select public_data into pd from public.room_state where room_id=r;
  assert (pd - 'elderRevealedSeats')::text !~ '(elder|mafia|doctor|citizen)'
    and jsonb_typeof(pd->'elderRevealedSeats'->0)='number'
    and (select count(*) from jsonb_object_keys(pd))=1,
    'the reveal put anything but the seat number on the public payload';
  select (select count(*) from public.wallet_ledger)=wallet_rows and (select count(*) from public.player_tool_charges)=charge_rows into ok;
  assert ok, 'a reveal touched the wallet or the tool charges';
  assert not has_column_privilege('authenticated','public.room_players','role','select'), 'a client can read roles';
end $$;

select 'PASS store_gaps' as result;
rollback;
