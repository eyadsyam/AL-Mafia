begin;
do $$
declare r uuid := gen_random_uuid(); h uuid := gen_random_uuid(); a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); got uuid;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'KCKQ7M',h,1,'lobby');
  insert into public.room_players(room_id,user_id,name,seat) values(r,h,'host',0),(r,a,'a',1),(r,b,'b',2);
  -- only the host removes, and never itself
  begin
    perform public.kick_member(r,a,2);
    raise exception 'a guest removed a seat';
  exception when raise_exception then if sqlerrm<>'NOT_HOST' then raise; end if; end;
  begin
    perform public.kick_member(r,h,0);
    raise exception 'the host removed itself';
  exception when raise_exception then if sqlerrm<>'BAD_REQUEST' then raise; end if; end;
  begin
    perform public.kick_member(r,h,9);
    raise exception 'an empty seat was removed';
  exception when raise_exception then if sqlerrm<>'BAD_REQUEST' then raise; end if; end;
  -- a kick bans and marks in one statement, and a second kick appends
  got := public.kick_member(r,h,1);
  if got<>a then raise exception 'wrong player removed'; end if;
  if not exists(select 1 from public.rooms where id=r and a = any(banned_user_ids)) then raise exception 'not banned'; end if;
  if not (select kicked and status='left' and not connected from public.room_players where room_id=r and user_id=a) then
    raise exception 'seat not marked';
  end if;
  perform public.kick_member(r,h,2);
  if (select cardinality(banned_user_ids) from public.rooms where id=r)<>2 then
    raise exception 'second kick lost the first ban';
  end if;
  -- the ban holds at the door, for a rejoin and for a fresh join alike
  begin
    perform public.join_room_atomic('KCKQ7M',a,'a','male');
    raise exception 'a removed player rejoined';
  exception when raise_exception then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  -- kicking the same seat again is idempotent on the ban list
  perform public.kick_member(r,h,1);
  if (select cardinality(banned_user_ids) from public.rooms where id=r)<>2 then
    raise exception 'ban duplicated';
  end if;
  if has_function_privilege('authenticated','public.kick_member(uuid,uuid,integer)','execute') then
    raise exception 'a client can kick';
  end if;
end $$;
select 'PASS atomic kick: host-only, ban appended, seat marked, door held, idempotent' as result;
rollback;
