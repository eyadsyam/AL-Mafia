begin;
do $$
declare r uuid := gen_random_uuid(); h uuid := gen_random_uuid(); a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid(); d uuid := gen_random_uuid(); got uuid; pd jsonb;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'KELMQ7',h,1,'lobby');
  insert into public.room_players(room_id,user_id,name,seat) values(r,h,'host',0),(r,a,'a',1),(r,b,'b',2),(r,c,'c',3),(r,d,'d',4);
  -- in the lobby a kick is a ban and a mark, nothing else: no role, still "alive" until the deal marks it
  got := public.kick_member(r,h,4);
  if not (select kicked and alive and role is null from public.room_players where room_id=r and user_id=d) then
    raise exception 'a lobby kick did more than ban and mark';
  end if;
  if (select public_data from public.room_state where room_id=r) is not null then raise exception 'lobby kick wrote match state'; end if;
  -- the deal: four seated, the removed row not alive, no role
  update public.room_players set role='mafia' where room_id=r and user_id=h;
  update public.room_players set role='citizen' where room_id=r and user_id in (a,b,c);
  update public.room_players set alive=false where room_id=r and user_id=d;
  update public.rooms set status='playing' where id=r;
  insert into public.room_state(room_id,phase,phase_number,public_data) values(r,'opening',1,'{"openingSeat":1}'::jsonb);
  insert into public.whisper_meta(room_id,day,from_id,to_id) values(r,1,b,a);
  -- a mid-match kick of a dealt seat is a neutral elimination: out, whispers to it voided, recorded as a day elimination
  got := public.kick_member(r,h,1);
  if got<>a then raise exception 'wrong seat removed'; end if;
  if not (select kicked and not alive and role='citizen' from public.room_players where room_id=r and user_id=a) then
    raise exception 'the removed seat is not out, or lost its role';
  end if;
  if not (select voided from public.whisper_meta where room_id=r and to_id=a) then raise exception 'whisper to the removed seat not voided'; end if;
  select public_data into pd from public.room_state where room_id=r;
  if pd #>> '{eliminations,1,phase}' <> 'day' or (pd #>> '{eliminations,1,number}')::int <> 1 then
    raise exception 'elimination not recorded: %', pd;
  end if;
  if pd ? 'outcome' then raise exception 'an outcome was invented with three living'; end if;
  if not exists(select 1 from public.rooms where id=r and a = any(banned_user_ids)) then raise exception 'not banned'; end if;
  -- one mafia, two town: the next removal reaches parity and the match ends for the mafia
  update public.room_state set phase='night', phase_number=2 where room_id=r;
  got := public.kick_member(r,h,2);
  select public_data into pd from public.room_state where room_id=r;
  if pd #>> '{eliminations,2,phase}' <> 'night' or (pd #>> '{eliminations,2,number}')::int <> 2 then
    raise exception 'night elimination not recorded: %', pd;
  end if;
  if pd->>'outcome' <> 'mafia' then raise exception 'parity did not end the match: %', pd; end if;
  -- a seat already out is not eliminated twice and the outcome is not rewritten
  update public.room_players set alive=false where room_id=r and user_id=c;
  got := public.kick_member(r,h,3);
  select public_data into pd from public.room_state where room_id=r;
  if pd #> '{eliminations,3}' is not null then raise exception 'a dead seat was eliminated again'; end if;
  if pd->>'outcome' <> 'mafia' then raise exception 'outcome rewritten'; end if;
  if (select cardinality(banned_user_ids) from public.rooms where id=r)<>4 then raise exception 'bans lost'; end if;
end $$;
select 'PASS kick eliminates: lobby kick only bans; a dealt seat is out neutrally, whispers voided, elimination recorded, win check applied, never twice' as result;
rollback;
