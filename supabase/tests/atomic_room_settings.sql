begin;
do $$
declare r uuid := gen_random_uuid(); h uuid := gen_random_uuid(); a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); k uuid := gen_random_uuid();
begin
  insert into public.rooms(id,code,host_id,match_seed,status,settings) values(r,'STNGQ7',h,1,'lobby','{"maxPlayers":10,"voice":true}'::jsonb);
  insert into public.room_players(room_id,user_id,name,seat) values(r,h,'host',0),(r,a,'a',1),(r,b,'b',2),(r,k,'k',3);
  update public.room_players set kicked=true,status='left',connected=false where room_id=r and user_id=k;
  -- only the host
  begin
    perform public.commit_room_settings(r,a,'{"visibility":"public"}'::jsonb);
    raise exception 'a guest changed the room';
  exception when raise_exception then if sqlerrm<>'NOT_HOST' then raise; end if; end;
  -- a merge, not a replacement: one switch flips, the rest stays
  perform public.commit_room_settings(r,h,'{"settings":{"voice":false}}'::jsonb);
  if (select settings from public.rooms where id=r) <> '{"maxPlayers":10,"voice":false}'::jsonb then
    raise exception 'settings were replaced instead of merged';
  end if;
  -- capacity counts the seats the door counts: kicked rows are not seats
  perform public.commit_room_settings(r,h,'{"settings":{"maxPlayers":5}}'::jsonb);
  if (select settings->>'maxPlayers' from public.rooms where id=r) <> '5' then raise exception 'capacity not applied'; end if;
  insert into public.room_players(room_id,user_id,name,seat) values(r,gen_random_uuid(),'c',4),(r,gen_random_uuid(),'d',5),(r,gen_random_uuid(),'e',6);
  -- six seated (kicked row excluded) > 5: the same value is now refused
  begin
    perform public.commit_room_settings(r,h,'{"settings":{"maxPlayers":5}}'::jsonb);
    raise exception 'capacity dropped below the population';
  exception when raise_exception then if sqlerrm<>'BAD_REQUEST' then raise; end if; end;
  begin
    perform public.commit_room_settings(r,h,'{"settings":{"maxPlayers":7}}'::jsonb);
    raise exception 'an off-list capacity was accepted';
  exception when raise_exception then if sqlerrm<>'BAD_REQUEST' then raise; end if; end;
  -- title and visibility
  perform public.commit_room_settings(r,h,'{"visibility":"public","title":"  Friday table  "}'::jsonb);
  if (select visibility||'/'||title from public.rooms where id=r) <> 'public/Friday table' then raise exception 'title or visibility lost'; end if;
  perform public.commit_room_settings(r,h,'{"title":null}'::jsonb);
  if (select title from public.rooms where id=r) is not null then raise exception 'title not cleared'; end if;
  begin
    perform public.commit_room_settings(r,h,'{"visibility":"hidden"}'::jsonb);
    raise exception 'an unknown visibility was accepted';
  exception when raise_exception then if sqlerrm<>'BAD_REQUEST' then raise; end if; end;
  -- nothing changes once the cards are out
  update public.rooms set status='playing' where id=r;
  begin
    perform public.commit_room_settings(r,h,'{"settings":{"voice":true}}'::jsonb);
    raise exception 'a started match changed its rules';
  exception when raise_exception then if sqlerrm<>'PHASE_CLOSED' then raise; end if; end;
  if (select settings->>'voice' from public.rooms where id=r) <> 'false' then raise exception 'rules changed after the deal'; end if;
  begin
    perform public.commit_room_settings(gen_random_uuid(),h,'{"visibility":"public"}'::jsonb);
    raise exception 'a missing room was changed';
  exception when raise_exception then if sqlerrm<>'ROOM_NOT_FOUND' then raise; end if; end;
  if has_function_privilege('authenticated','public.commit_room_settings(uuid,uuid,jsonb)','execute') then
    raise exception 'a client can change room settings directly';
  end if;
end $$;
select 'PASS atomic room settings: host-only, merged, capacity against seated population, locked after the deal' as result;
rollback;
