begin;
do $$
declare
  r uuid := gen_random_uuid(); a uuid := gen_random_uuid(); b uuid := gen_random_uuid();
  d timestamptz := now() + interval '5 minutes';
begin
  insert into public.rooms(id,code,host_id,match_seed,status)
    values(r,'R3ADY2',a,7,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive)
    values(r,a,'A',0,'mafia',true),(r,b,'B',1,'citizen',true);
  insert into public.room_state(room_id,phase,phase_number,phase_ends_at,public_data)
    values(r,'discuss',1,d,'{"readyToVote":{"number":1,"seats":[0]}}');
  if public.commit_phase_open(r,'discuss',1,d,'vote',1,d,'{}',true) then
    raise exception 'one player opened the ballot for two';
  end if;
  update public.room_state set public_data='{"readyToVote":{"number":0,"seats":[0,1]}}'
    where room_id=r;
  if public.commit_phase_open(r,'discuss',1,d,'vote',1,d,'{}',true) then
    raise exception 'old readiness opened the ballot';
  end if;
  update public.room_state set public_data='{"readyToVote":{"number":1,"seats":[0,1]}}'
    where room_id=r;
  if not public.commit_phase_open(r,'discuss',1,d,'vote',1,d,'{}',true) then
    raise exception 'everyone ready could not open the ballot';
  end if;
end;
$$;
rollback;
