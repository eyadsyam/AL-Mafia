begin;
do $$
declare r uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'APNDLN',a,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role) values
    (r,a,'A',0,'citizen'),(r,b,'B',1,'citizen');
  insert into public.room_state(room_id,phase,phase_number,phase_ends_at,public_data)
    values(r,'opening',1,now()-interval '3 seconds','{"openingSeat":0}');
  assert not public.commit_accusation(r,1,0,1,1,now()+interval '10 seconds',now()+interval '30 seconds'),
    'late accusation accepted';
  assert (select public_data #> '{openingAccusations,0}' from public.room_state where room_id=r) is null,
    'late accusation stored';
  update public.room_state set phase_ends_at=now()-interval '1 second' where room_id=r;
  assert public.commit_accusation(r,1,0,1,1,now()+interval '10 seconds',now()+interval '30 seconds'),
    'two second grace refused';
end $$;
rollback;
select 'PASS opener deadline: late refused, two-second grace accepted' as result;
