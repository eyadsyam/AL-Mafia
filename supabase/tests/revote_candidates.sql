begin;
do $$
declare r uuid:=gen_random_uuid(); a uuid:=gen_random_uuid();
  b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid();
begin
  insert into public.rooms(id,code,host_id,match_seed,status)
    values(r,'RVCN42',a,3,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role) values
    (r,a,'A',0,'mafia'),(r,b,'B',1,'doctor'),(r,c,'C',2,'citizen'),(r,d,'D',3,'citizen');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r,'vote',1,'{"revote":{"round":2,"tiedSeats":[1,2]}}');
  begin
    insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,a,d,2);
    raise exception 'noncandidate accepted';
  exception when others then
    if sqlerrm<>'INVALID_REVOTE_TARGET' then raise; end if;
  end;
  insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,a,b,2);
  begin
    update public.votes set target_id=d where room_id=r and voter_id=a;
    raise exception 'noncandidate update accepted';
  exception when others then
    if sqlerrm<>'INVALID_REVOTE_TARGET' then raise; end if;
  end;
  if (select target_id from public.votes where room_id=r and voter_id=a)<>b then
    raise exception 'refusal changed a valid ballot';
  end if;
  insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,b,null,2);
  begin
    insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,c,b,1);
    raise exception 'wrong round accepted';
  exception when others then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;
  update public.room_state set public_data='{"revote":{"round":2}}' where room_id=r;
  begin
    insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,c,b,2);
    raise exception 'missing candidate list accepted';
  exception when others then
    if sqlerrm<>'INVALID_REVOTE_TARGET' then raise; end if;
  end;
end $$;
rollback;
