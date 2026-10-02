begin;
do $$
declare r uuid := gen_random_uuid(); h uuid := gen_random_uuid(); a uuid := gen_random_uuid(); k uuid := gen_random_uuid(); b uuid := gen_random_uuid();
        r2 uuid := gen_random_uuid(); n integer;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'LBDPQ7',h,1,'lobby');
  insert into public.room_players(room_id,user_id,name,seat,status,connected,last_seen)
    values(r,h,'host',0,'connected',true,now()),(r,a,'a',1,'connected',true,now()),(r,k,'k',2,'connected',true,now()),(r,b,'b',3,'connected',true,now());
  update public.room_players set kicked=true,status='left',connected=false where room_id=r and user_id=k;
  -- a silent lobby seat becomes a departure: the row goes and the seats re-pack
  update public.room_players set last_seen=now()-interval '2 minutes' where room_id=r and user_id=a;
  n := public.age_presence();
  if exists(select 1 from public.room_players where room_id=r and user_id=a) then raise exception 'silent lobby seat kept'; end if;
  if (select seat from public.room_players where room_id=r and user_id=b)<>2 then raise exception 'seats not re-packed'; end if;
  if (select count(*) from public.room_players where room_id=r and not kicked)<>2 then raise exception 'wrong seated count'; end if;
  -- the removed row is not a departure and stays where it is
  if not exists(select 1 from public.room_players where room_id=r and user_id=k and kicked) then raise exception 'removed row aged away'; end if;
  -- a silent host hands the room to the lowest seated row, never to a removed one
  update public.room_players set last_seen=now()-interval '2 minutes' where room_id=r and user_id=h;
  n := public.age_presence();
  if (select host_id from public.rooms where id=r)<>b then raise exception 'host not handed to the seated player: %', (select host_id from public.rooms where id=r); end if;
  if (select seat from public.room_players where room_id=r and user_id=b)<>1 then raise exception 'seats not re-packed after the host left'; end if;
  -- the last seated player leaving empties the lobby, removed rows notwithstanding
  perform public.leave_room(r,b);
  if exists(select 1 from public.rooms where id=r) then raise exception 'an emptied lobby survived on its removed rows'; end if;
  -- mid-match a silent seat is kept for its return
  insert into public.rooms(id,code,host_id,match_seed,status) values(r2,'LBDPQ8',h,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,status,connected,last_seen)
    values(r2,h,'host',0,'mafia','connected',true,now()),(r2,a,'a',1,'citizen','connected',true,now()-interval '2 minutes');
  n := public.age_presence();
  if not exists(select 1 from public.room_players where room_id=r2 and user_id=a and status='left') then raise exception 'mid-match seat not kept'; end if;
  if (select count(*) from public.room_players where room_id=r2)<>2 then raise exception 'mid-match row deleted'; end if;
  if has_function_privilege('authenticated','public.age_presence()','execute') or has_function_privilege('authenticated','public.leave_room(uuid,uuid)','execute') then
    raise exception 'a client can age or leave for others';
  end if;
end $$;
select 'PASS lobby departures: silent lobby seats re-pack, removed rows stay, host handover skips removed rows, emptied lobby goes, mid-match seats kept' as result;
rollback;
