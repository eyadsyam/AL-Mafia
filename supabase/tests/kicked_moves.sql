begin;
do $$
declare r uuid := gen_random_uuid(); h uuid := gen_random_uuid(); a uuid := gen_random_uuid(); k uuid := gen_random_uuid();
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'KMVSQ7',h,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive) values(r,h,'host',0,'mafia',true),(r,a,'a',1,'citizen',true),(r,k,'k',2,'citizen',true);
  update public.room_players set kicked=true,status='left',connected=false where room_id=r and user_id=k;
  insert into public.room_state(room_id,phase,phase_number,public_data) values(r,'night',1,'{}'::jsonb);
  -- a seated player's night move lands; the removed seat's is refused by name
  insert into public.night_actions(room_id,night,actor_id,action,target_id) values(r,1,a,'suspect',h);
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id) values(r,1,k,'suspect',h);
    raise exception 'a removed seat moved at night';
  exception when raise_exception then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  if (select count(*) from public.night_actions where room_id=r)<>1 then raise exception 'wrong night rows'; end if;
  -- the same at the ballot, on insert and on the retry path (update)
  update public.room_state set phase='vote' where room_id=r;
  insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,a,h,1);
  begin
    insert into public.votes(room_id,day,voter_id,target_id,round) values(r,1,k,h,1);
    raise exception 'a removed seat voted';
  exception when raise_exception then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  update public.room_players set kicked=true,status='left' where room_id=r and user_id=a;
  begin
    update public.votes set target_id=a where room_id=r and voter_id=a;
    raise exception 'a seat removed after voting changed its ballot';
  exception when raise_exception then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  update public.room_players set kicked=false,status='connected' where room_id=r and user_id=a;
  -- the phase guard still comes first: a stale move is PHASE_CLOSED, not a membership question
  begin
    insert into public.votes(room_id,day,voter_id,target_id,round) values(r,2,k,h,1);
    raise exception 'a stale ballot landed';
  exception when raise_exception then if sqlerrm<>'PHASE_CLOSED' then raise; end if; end;
  -- the opening accusation
  update public.room_state set phase='opening', public_data='{"openingSeat":2}'::jsonb where room_id=r;
  begin
    perform public.commit_accusation(r,1,2,1,null,null,now()+interval '1 minute');
    raise exception 'a removed seat accused';
  exception when raise_exception then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  update public.room_state set public_data='{"openingSeat":1}'::jsonb where room_id=r;
  if not public.commit_accusation(r,1,1,0,null,null,now()+interval '1 minute') then raise exception 'a seated accusation was refused'; end if;
  if (select phase from public.room_state where room_id=r)<>'discuss' then raise exception 'accusation did not move the floor'; end if;
end $$;
select 'PASS kicked moves: a removed seat is refused at night, at the ballot, on the retry path and at the opening floor; seated moves land' as result;
rollback;
