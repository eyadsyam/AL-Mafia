begin;
do $$
declare
  r uuid := gen_random_uuid(); h uuid := gen_random_uuid(); g uuid := gen_random_uuid();
  d0 timestamptz := now() + interval '30 seconds';
  d1 timestamptz;
  s public.room_state; moved boolean;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'QQ7PX2',h,7,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,saw_role)
    values(r,h,'host',0,'mafia',true),(r,g,'guest',1,'citizen',false);
  insert into public.room_state(room_id,phase,phase_number,phase_ends_at,public_data)
    values(r,'reveal',1,d0,'{"playerCount":2}');

  -- reveal -> night: the gate holds while a card is unseen ...
  if public.commit_phase_open(r,'reveal',1,d0,'night',1,d0,'{}',true) then
    raise exception 'night opened with a card unseen';
  end if;
  -- ... and the caller who says the clock ran out is not believed either, if
  -- the deadline it read is not the row's.
  if public.commit_phase_open(r,'reveal',1,now(),'night',1,d0,'{}',false) then
    raise exception 'changed deadline was accepted';
  end if;
  -- a stale caller (wrong phase / wrong day) moves nothing
  if public.commit_phase_open(r,'night',1,d0,'morning',1,d0,'{}',false) then
    raise exception 'stale phase accepted';
  end if;
  if public.commit_phase_open(r,'reveal',2,d0,'night',2,d0,'{}',false) then
    raise exception 'stale day accepted';
  end if;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'reveal' or s.phase_ends_at<>d0 then raise exception 'refusals wrote'; end if;

  -- the expired deal opens the night without the gate; two drivers, one move
  d1 := now() + interval '120 seconds';
  moved := public.commit_phase_open(r,'reveal',1,d0,'night',1,d1,'{"morning":null}',false);
  if not moved then raise exception 'expired deal did not open'; end if;
  if public.commit_phase_open(r,'reveal',1,d0,'night',1,now(),'{}',false) then
    raise exception 'second driver re-opened the night';
  end if;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'night' or s.phase_ends_at<>d1 or s.public_data->>'playerCount'<>'2' then
    raise exception 'night not opened as asked: %', s;
  end if;

  -- the gate, when every card was seen
  update public.room_state set phase='reveal',phase_ends_at=d0 where room_id=r;
  update public.room_players set saw_role=true where room_id=r;
  if not public.commit_phase_open(r,'reveal',1,d0,'night',1,d1,'{}',true) then
    raise exception 'gate refused a fully seen deal';
  end if;

  -- same-phase move: the opening round hands the floor on with a fresh clock
  update public.room_state set phase='opening',phase_ends_at=d0,
    public_data=public_data||'{"openingSeat":0}' where room_id=r;
  if not public.commit_phase_open(r,'opening',1,d0,'opening',1,d1,'{"openingSeat":1}',false) then
    raise exception 'opening skip refused';
  end if;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'opening' or s.phase_ends_at<>d1 or (s.public_data->>'openingSeat')<>'1' then
    raise exception 'opening skip wrote wrongly: %', s;
  end if;
  -- the driver that read the old clock is refused: it must not re-point the floor
  if public.commit_phase_open(r,'opening',1,d0,'opening',1,now(),'{"openingSeat":0}',false) then
    raise exception 'late opening driver re-pointed the floor';
  end if;

  -- standings never leave the server before the result ...
  update public.room_state set phase='verdict',phase_ends_at=d0 where room_id=r;
  begin
    perform public.commit_phase_open(r,'verdict',1,d0,'night',2,d1,'{"standings":[{"seat":0,"role":"mafia"}]}',false);
    raise exception 'standings accepted before the result';
  exception when others then
    if sqlerrm not like 'standings may only%' then raise; end if;
  end;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'verdict' or s.public_data ? 'standings' then raise exception 'refused standings wrote'; end if;
  -- ... and a verdict -> night moves the day number
  if not public.commit_phase_open(r,'verdict',1,d0,'night',2,d1,'{}',false) then
    raise exception 'verdict -> night refused';
  end if;
  select * into s from public.room_state where room_id=r;
  if s.phase_number<>2 then raise exception 'day did not move'; end if;

  -- a failed write rolls the whole move back: an illegal phase name violates
  -- the check constraint after the lock was taken and nothing else survives
  update public.room_state set phase='verdict',phase_ends_at=d0 where room_id=r;
  begin
    perform public.commit_phase_open(r,'verdict',2,d0,'bogus',2,d1,'{"leak":1}',false);
    raise exception 'illegal phase accepted';
  exception when check_violation then null;
  end;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'verdict' or s.public_data ? 'leak' then raise exception 'failed move left writes'; end if;

  -- no outcome, no result: a closed room (finished, nothing won) stays put
  if public.commit_phase_open(r,'verdict',2,d0,'result',2,null,'{}',false) then
    raise exception 'result opened without an outcome';
  end if;
  update public.rooms set status='finished' where id=r;
  if public.commit_phase_open(r,'verdict',2,d0,'result',2,null,'{}',false) then
    raise exception 'a closed room reached the result';
  end if;
  -- the deciding ballot already marked the room finished (`resolution_outcome`);
  -- the verdict still opens the result, and only the result
  update public.room_state set public_data=public_data||'{"outcome":"mafia"}' where room_id=r;
  if public.commit_phase_open(r,'verdict',2,d0,'night',3,d1,'{}',false) then
    raise exception 'a finished room opened a night';
  end if;
  if not public.commit_phase_open(r,'verdict',2,d0,'result',2,null,'{"standings":[{"seat":0,"role":"mafia"}]}',false) then
    raise exception 'result refused';
  end if;
  if (select status from public.rooms where id=r)<>'finished' then raise exception 'room not finished'; end if;
  if (select ended_at from public.rooms where id=r) is null then raise exception 'ended_at not set'; end if;
  -- a finished room moves no further
  if public.commit_phase_open(r,'result',2,null,'night',3,d1,'{}',false) then
    raise exception 'finished room moved';
  end if;

  -- confrontation: only from the morning the driver read, and the archive,
  -- the live payload and the phase land together
  update public.rooms set status='playing' where id=r;
  update public.room_state set phase='morning',phase_number=2,phase_ends_at=d0 where room_id=r;
  if public.commit_confrontation(r,1,d0,'{"targetSeat":1}','confront',d1) then
    raise exception 'confrontation accepted for the wrong day';
  end if;
  if public.commit_confrontation(r,2,now(),'{"targetSeat":1}','confront',d1) then
    raise exception 'confrontation accepted with a changed deadline';
  end if;
  begin
    perform public.commit_confrontation(r,2,d0,null,'confront',d1);
    raise exception 'confront without a payload accepted';
  exception when others then
    if sqlerrm not like 'confrontation payload%' then raise; end if;
  end;
  if not public.commit_confrontation(r,2,d0,'{"targetSeat":1,"type":"x"}','confront',d1) then
    raise exception 'confrontation refused';
  end if;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'confront' or s.public_data#>>'{confrontation,targetSeat}'<>'1'
     or s.public_data#>>'{confrontations,2,targetSeat}'<>'1' then
    raise exception 'confrontation not published: %', s.public_data;
  end if;
  if public.commit_confrontation(r,2,d0,'{"targetSeat":1}','confront',d1) then
    raise exception 'second driver published a second confrontation';
  end if;
  -- a morning with nothing to say opens the discussion and archives nothing
  update public.room_state set phase='morning',phase_number=3,phase_ends_at=d0 where room_id=r;
  if not public.commit_confrontation(r,3,d0,null,'discuss',d1) then
    raise exception 'quiet morning refused';
  end if;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'discuss' or jsonb_typeof(s.public_data->'confrontation')<>'null'
     or s.public_data#>'{confrontations,3}' is not null then
    raise exception 'quiet morning wrote a confrontation: %', s.public_data;
  end if;

  -- the opening round: one name, while the floor is that seat's
  update public.room_state set phase='opening',phase_number=3,phase_ends_at=d0,
    public_data=public_data||'{"openingSeat":0,"openingAccusations":{}}' where room_id=r;
  if public.commit_accusation(r,3,1,0,null,d1,d1) then
    raise exception 'a seat spoke out of turn';
  end if;
  if not public.commit_accusation(r,3,0,1,1,d1,d1) then
    raise exception 'first name refused';
  end if;
  if public.commit_accusation(r,3,0,1,1,d1,d1) then
    raise exception 'double tap recorded twice / re-pointed the floor';
  end if;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'opening' or (s.public_data->>'openingSeat')<>'1'
     or s.public_data#>>'{openingAccusations,0}'<>'1' then
    raise exception 'first name not recorded: %', s.public_data;
  end if;
  if not public.commit_accusation(r,3,1,0,null,d1,d0) then
    raise exception 'last name refused';
  end if;
  select * into s from public.room_state where room_id=r;
  if s.phase<>'discuss' or jsonb_typeof(s.public_data->'openingSeat')<>'null'
     or s.public_data#>>'{openingAccusations,1}'<>'0' or s.phase_ends_at<>d0 then
    raise exception 'round did not close into the discussion: %', s;
  end if;

  if has_function_privilege('authenticated',
    'public.commit_phase_open(uuid,text,integer,timestamptz,text,integer,timestamptz,jsonb,boolean)','execute')
   or has_function_privilege('authenticated',
    'public.commit_confrontation(uuid,integer,timestamptz,jsonb,text,timestamptz)','execute')
   or has_function_privilege('authenticated',
    'public.commit_accusation(uuid,integer,integer,integer,integer,timestamptz,timestamptz)','execute') then
    raise exception 'a client can drive the phase';
  end if;
  if (select prosecdef and coalesce(array_to_string(proconfig,','),'') like '%search_path=public, pg_temp%'
        from pg_proc where proname='commit_phase_open') is distinct from true then
    raise exception 'commit_phase_open is not a definer with a pinned search_path';
  end if;
end $$;
select 'PASS phase open CAS, reveal gate, same-phase clock, standings guard, rollback, result, confrontation, accusation, grants' as result;
rollback;
