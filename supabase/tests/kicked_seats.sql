begin;
do $$
declare r uuid; h uuid:=gen_random_uuid(); removed uuid:=gen_random_uuid();
  replacement uuid:=gen_random_uuid(); result jsonb; replacement_seat integer; deadline timestamptz;
begin
  result:=public.create_room_atomic('KCKS78',h,'host','male',7,'{"settings":{"maxPlayers":5}}');
  r:=(result->>'roomId')::uuid;
  perform public.join_room_atomic('KCKS78',removed,'removed','female');
  for i in 1..3 loop
    perform public.join_room_atomic('KCKS78',gen_random_uuid(),'guest'||i,'male');
  end loop;
  perform public.kick_member(r,h,1);
  update public.rooms set visibility='public' where id=r;
  if (select players from public.public_rooms() where code='KCKS78') is distinct from 4 then
    raise exception 'public list counts removed player';
  end if;
  result:=public.join_room_atomic('KCKS78',replacement,'replacement','female');
  replacement_seat:=(result->>'seat')::integer;
  if replacement_seat<>5 then raise exception 'replacement collided with retained seat'; end if;
  begin
    perform public.join_room_atomic('KCKS78',removed,'renamed','male');
    raise exception 'removed player rejoined';
  exception when raise_exception then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  begin
    perform public.join_room_atomic('KCKS78',gen_random_uuid(),'overflow','male');
    raise exception 'sixth active player admitted';
  exception when raise_exception then if sqlerrm<>'ROOM_FULL' then raise; end if; end;
  if public.apply_match_deal(r,h,array['mafia','citizen'], '{}',now()+interval '90 seconds') then
    raise exception 'stale roster count accepted';
  end if;
  deadline:=now()+interval '90 seconds';
  if not public.apply_match_deal(r,h,array['mafia','doctor','detective','citizen','citizen'], '{}',deadline) then
    raise exception 'valid deal refused after kick';
  end if;
  if (select count(*) from public.room_players where room_id=r and role is not null)<>5 then
    raise exception 'incorrect deal count';
  end if;
  if not exists(select 1 from public.room_players where room_id=r and user_id=removed and kicked and not alive and role is null) then
    raise exception 'removal notification lost or became living/dealt';
  end if;
  if (select public_data->'rosterSeats' from public.room_state where room_id=r)<>'[0,2,3,4,5]'::jsonb then
    raise exception 'wrong public participant seats';
  end if;
  update public.room_players set saw_role=true where room_id=r and not kicked;
  if not public.commit_phase_open(r,'reveal',1,deadline,'night',1,now()+interval '90 seconds','{}',true) then
    raise exception 'removed player held reveal gate';
  end if;
  perform public.kick_member(r,h,replacement_seat);
  if not exists(select 1 from public.room_players where room_id=r and user_id=replacement and kicked and role is not null) then
    raise exception 'in-match participant history lost';
  end if;
  if not (select public_data->'rosterSeats' @> to_jsonb(array[replacement_seat]) from public.room_state where room_id=r) then
    raise exception 'in-match removal changed participant list';
  end if;
  if has_function_privilege('authenticated','public.apply_match_deal(uuid,uuid,text[],jsonb,timestamptz)','execute') or
     has_function_privilege('authenticated','public.join_room_atomic(text,uuid,text,text)','execute') then
    raise exception 'private mutation exposed';
  end if;
end $$;
select 'PASS kicked seats: capacity, collision, ban, deal, reveal, retained participants, grants' as result;
rollback;
