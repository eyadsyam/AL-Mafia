begin;
do $$
declare
  r uuid := gen_random_uuid();
  m uuid := '00000000-0000-4000-8000-0000000000b1';
  d uuid := '00000000-0000-4000-8000-0000000000b2';
  c uuid := '00000000-0000-4000-8000-0000000000b3';
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'BLLT55',m,5,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role)
    values(r,m,'M',0,'mafia'),(r,d,'D',1,'doctor'),(r,c,'C',2,'citizen');
  insert into public.room_state(room_id,phase,phase_number) values(r,'night',1);

  -- The Doctor spends the self-protect bullet on night 1…
  insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
    values(r,1,d,'protect',d,true);
  -- …the same move is retried (a lost response): the row stays spent.
  insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
    values(r,1,d,'protect',d,true)
    on conflict (room_id,night,actor_id) do update
      set action=excluded.action,target_id=excluded.target_id,used_bullet=excluded.used_bullet;
  -- …then a resubmit without the bullet: the move changes, the bullet does not come back.
  insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
    values(r,1,d,'protect',c,false)
    on conflict (room_id,night,actor_id) do update
      set action=excluded.action,target_id=excluded.target_id,used_bullet=excluded.used_bullet;
  if (select target_id from public.night_actions where room_id=r and night=1 and actor_id=d)<>c then
    raise exception 'the resubmitted move did not land';
  end if;
  if not (select used_bullet from public.night_actions where room_id=r and night=1 and actor_id=d) then
    raise exception 'a spent bullet was refunded by a same-night resubmit';
  end if;

  -- A plain update cannot unsay it either.
  update public.night_actions set used_bullet=false where room_id=r and night=1 and actor_id=d;
  if not (select used_bullet from public.night_actions where room_id=r and night=1 and actor_id=d) then
    raise exception 'a spent bullet was cleared by an update';
  end if;

  -- A move that never spent one is untouched by the rule.
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,1,m,'kill',c);
  update public.night_actions set target_id=d where room_id=r and night=1 and actor_id=m;
  if (select used_bullet from public.night_actions where room_id=r and night=1 and actor_id=m) then
    raise exception 'a move without a bullet became spent';
  end if;

  -- A second night is a different row, and the second bullet is still refused there.
  update public.room_state set phase_number=2 where room_id=r;
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
      values(r,2,d,'protect',d,true);
    raise exception 'a second bullet was accepted on a later night';
  exception when unique_violation then null;
  end;
end $$;
rollback;
