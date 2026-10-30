begin;
do $$
declare r uuid:=gen_random_uuid(); h uuid:=gen_random_uuid(); stale uuid:=gen_random_uuid(); live uuid:=gen_random_uuid();
begin
  insert into public.rooms(id,code,host_id,match_seed,status)
    values(r,'LLHAAA',h,1,'lobby');
  insert into public.room_players(room_id,user_id,name,seat,status,connected,last_seen)
    values(r,h,'host',0,'connected',true,now()),
          (r,stale,'stale',1,'connected',true,now()-interval '31 seconds'),
          (r,live,'live',2,'connected',true,now());
  assert public.leave_room(r,h)='left';
  assert (select host_id from public.rooms where id=r)=live,
    'explicit departure selected an unheard heir';

  -- With no recently heard connected heir, keep the lowest seated fallback.
  update public.room_players set last_seen=now()-interval '31 seconds' where room_id=r;
  assert public.leave_room(r,live)='left';
  assert (select host_id from public.rooms where id=r)=stale,
    'room lost its host when no live heir remained';
end $$;
select 'PASS live lobby heir' as result;
rollback;
