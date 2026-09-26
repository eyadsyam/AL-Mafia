begin;
do $$
declare r uuid; h uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
  c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); fp text; payload jsonb;
begin
  payload:=public.create_room_atomic('RSTR78',h,'host','male',1,'{"settings":{"voice":false,"maxPlayers":5}}');
  r:=(payload->>'roomId')::uuid;
  perform public.join_room_atomic('RSTR78',a,'A','male');
  perform public.join_room_atomic('RSTR78',b,'B','male');
  perform public.join_room_atomic('RSTR78',c,'C','male');
  perform public.join_room_atomic('RSTR78',d,'D','male');
  -- A stale start payload must not undo the host's saved switch change.
  if not public.apply_match_deal(r,h,array['mafia','doctor','citizen','citizen','citizen'],
    '{"voice":true,"maxPlayers":10}',now()) then raise exception 'deal refused'; end if;
  if (select settings->>'voice' from public.rooms where id=r)<>'false' or
     (select settings->>'maxPlayers' from public.rooms where id=r)<>'5' then
    raise exception 'start overwrote saved settings';
  end if;
  update public.room_state set phase='night' where room_id=r;
  fp:=public.night_fingerprint(r,1);
  -- No action changed. Only a different player's neutral removal occurred.
  perform public.kick_member(r,h,1);
  if fp=public.night_fingerprint(r,1) then raise exception 'kick did not invalidate tally'; end if;
  if public.commit_resolution(r,'night',1,1,null,null,'{}','{"outcome":"mafia"}','morning',now(),fp) then
    raise exception 'stale population committed';
  end if;
  if (select public_data ? 'outcome' from public.room_state where room_id=r) then
    raise exception 'stale winner leaked into state';
  end if;
  if not public.commit_resolution(r,'night',1,1,null,null,'{}','{}','morning',now(),public.night_fingerprint(r,1)) then
    raise exception 'fresh population did not recover';
  end if;
  update public.room_state set phase='vote' where room_id=r;
  fp:=public.vote_fingerprint(r,1,1);
  perform public.kick_member(r,h,2);
  if public.commit_resolution(r,'vote',1,1,null,null,'{}','{}','verdict',now(),fp) then
    raise exception 'ballot used stale population';
  end if;
  if not public.commit_resolution(r,'vote',1,1,null,null,'{}','{}','verdict',now(),public.vote_fingerprint(r,1,1)) then
    raise exception 'fresh ballot did not recover';
  end if;
  if has_function_privilege('authenticated','public.roster_fingerprint(uuid)','execute') then
    raise exception 'client can access private mutation helper';
  end if;
end $$;
select 'PASS stale population rejected for night/vote, fresh retry, stored settings preserved, grants' as result;
rollback;
