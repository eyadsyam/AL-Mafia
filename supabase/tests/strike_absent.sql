begin;
do $$
declare r uuid := gen_random_uuid(); h uuid := gen_random_uuid(); a uuid := gen_random_uuid(); b uuid := gen_random_uuid();
        c uuid := gen_random_uuid(); d uuid := gen_random_uuid(); got jsonb; pd jsonb;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'STRKQ7',h,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,connected,last_seen) values
    (r,h,'host',0,'mafia',true,true,now()),
    (r,a,'a',1,'citizen',true,true,now()-interval '4 minutes'),
    (r,b,'b',2,'doctor',true,true,now()),
    (r,c,'c',3,'citizen',true,false,now()-interval '1 minute'),
    (r,d,'d',4,'citizen',true,true,now()-interval '2 minutes');
  insert into public.room_state(room_id,phase,phase_number,public_data) values(r,'night',2,'{}'::jsonb);
  insert into public.whisper_meta(room_id,day,from_id,to_id) values(r,1,b,a);
  -- only the host, only a running match, only a seat that exists
  begin
    perform public.strike_absent_member(r,b,1);
    raise exception 'a guest struck a seat';
  exception when raise_exception then if sqlerrm<>'NOT_HOST' then raise; end if; end;
  begin
    perform public.strike_absent_member(r,h,9);
    raise exception 'an empty seat was struck';
  exception when raise_exception then if sqlerrm<>'BAD_REQUEST' then raise; end if; end;
  update public.room_players set connected=false, last_seen=now()-interval '10 minutes' where room_id=r and user_id=h;
  begin
    perform public.strike_absent_member(r,h,0);
    raise exception 'the host struck itself';
  exception when raise_exception then if sqlerrm<>'BAD_REQUEST' then raise; end if; end;
  update public.room_players set connected=true, last_seen=now() where room_id=r and user_id=h;
  -- a seat still beating, or quiet for less than three minutes, is still here
  begin
    perform public.strike_absent_member(r,h,2);
    raise exception 'a present seat was struck';
  exception when raise_exception then if sqlerrm<>'STILL_HERE' then raise; end if; end;
  begin
    perform public.strike_absent_member(r,h,4);
    raise exception 'a seat two minutes quiet was struck';
  exception when raise_exception then if sqlerrm<>'STILL_HERE' then raise; end if; end;
  -- four minutes of silence: out, whisper voided, recorded as a night elimination, no outcome with four living
  got := public.strike_absent_member(r,h,1);
  if (got->>'removed')::int<>1 or got->>'outcome' is not null then raise exception 'wrong answer: %', got; end if;
  if (select alive from public.room_players where room_id=r and user_id=a) then raise exception 'seat still alive'; end if;
  if not (select voided from public.whisper_meta where room_id=r and to_id=a) then raise exception 'whisper not voided'; end if;
  select public_data into pd from public.room_state where room_id=r;
  if pd #> '{eliminations,1}' <> '{"phase":"night","number":2}'::jsonb then raise exception 'elimination not recorded: %', pd; end if;
  if pd ? 'outcome' then raise exception 'an outcome was invented'; end if;
  -- a disconnected seat that went quiet a minute ago is already counted as gone by its own status
  got := public.strike_absent_member(r,h,3);
  if (select alive from public.room_players where room_id=r and user_id=c) then raise exception 'disconnected seat still alive'; end if;
  -- struck twice is refused, the record stays
  begin
    perform public.strike_absent_member(r,h,1);
    raise exception 'a dead seat was struck again';
  exception when raise_exception then if sqlerrm<>'ALREADY_OUT' then raise; end if; end;
  -- one mafia, two town: the next strike reaches parity and the match ends
  update public.room_players set last_seen=now()-interval '5 minutes' where room_id=r and user_id=d;
  update public.room_state set phase='discuss', phase_number=2 where room_id=r;
  got := public.strike_absent_member(r,h,4);
  select public_data into pd from public.room_state where room_id=r;
  if got->>'outcome'<>'mafia' or pd->>'outcome'<>'mafia' then raise exception 'parity did not end the match: % %', got, pd; end if;
  if pd #> '{eliminations,4}' <> '{"phase":"day","number":2}'::jsonb then raise exception 'day elimination not recorded: %', pd; end if;
  -- a lobby is not a match
  update public.rooms set status='lobby' where id=r;
  begin
    perform public.strike_absent_member(r,h,2);
    raise exception 'a lobby seat was struck';
  exception when raise_exception then if sqlerrm<>'PHASE_CLOSED' then raise; end if; end;
  if has_function_privilege('authenticated','public.strike_absent_member(uuid,uuid,integer)','execute') then
    raise exception 'a client can strike';
  end if;
end $$;
select 'PASS strike absent: host-only, running match only, silence by the server clock, neutral elimination with phase, whispers voided, win check, never twice, grants' as result;
rollback;
