-- LOCAL ONLY: node tool/test_sql_without_docker.mjs one_investigation.sql
-- RL5 / D6 — one investigation a night, held by the database.
begin;
do $$
declare
  r uuid := gen_random_uuid();
  d uuid := '00000000-0000-4000-8000-0000000000c1';
  m uuid := '00000000-0000-4000-8000-0000000000c2';
  c uuid := '00000000-0000-4000-8000-0000000000c3';
  doc uuid := '00000000-0000-4000-8000-0000000000c4';
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'NVSTGT',m,5,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role)
    values(r,d,'D',0,'detective'),(r,m,'M',1,'mafia'),(r,c,'C',2,'citizen'),(r,doc,'Doc',3,'doctor');
  insert into public.room_state(room_id,phase,phase_number) values(r,'night',1);

  -- The first question is free.
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,1,d,'investigate',m);

  -- A different target is refused, by update and by upsert.
  begin
    update public.night_actions set target_id=c where room_id=r and night=1 and actor_id=d;
    raise exception 'a second question was accepted';
  exception when raise_exception then if sqlerrm<>'ALREADY_INVESTIGATED' then raise; end if; end;
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id)
      values(r,1,d,'investigate',c)
      on conflict (room_id,night,actor_id) do update
        set action=excluded.action,target_id=excluded.target_id;
    raise exception 'a second question was accepted through an upsert';
  exception when raise_exception then if sqlerrm<>'ALREADY_INVESTIGATED' then raise; end if; end;

  -- Giving the night up after looking is refused too.
  begin
    update public.night_actions set action='skip',target_id=null
      where room_id=r and night=1 and actor_id=d;
    raise exception 'the look was taken back with a skip';
  exception when raise_exception then if sqlerrm<>'ALREADY_INVESTIGATED' then raise; end if; end;

  -- The same target again is the same request arriving twice: it lands.
  update public.night_actions set note='again',action_id=gen_random_uuid()
    where room_id=r and night=1 and actor_id=d;
  insert into public.night_actions(room_id,night,actor_id,action,target_id,note)
    values(r,1,d,'investigate',m,'retry')
    on conflict (room_id,night,actor_id) do update
      set action=excluded.action,target_id=excluded.target_id,note=excluded.note;
  if (select target_id from public.night_actions where room_id=r and night=1 and actor_id=d)<>m
     or (select note from public.night_actions where room_id=r and night=1 and actor_id=d)<>'retry' then
    raise exception 'the same question did not land';
  end if;

  -- The timer default never overwrites a move (on conflict do nothing).
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,1,d,'skip',null) on conflict do nothing;
  if (select action from public.night_actions where room_id=r and night=1 and actor_id=d)<>'investigate' then
    raise exception 'a default overwrote the question';
  end if;

  -- Other roles keep changing their minds within the night.
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,1,m,'kill',c),(r,1,doc,'protect',c);
  update public.night_actions set target_id=doc where room_id=r and night=1 and actor_id=m;
  update public.night_actions set target_id=m where room_id=r and night=1 and actor_id=doc;

  -- A detective who skipped may still look; after looking the night is closed.
  update public.room_state set phase_number=2 where room_id=r;
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,2,d,'skip',null);
  update public.night_actions set action='investigate',target_id=c
    where room_id=r and night=2 and actor_id=d;
  begin
    update public.night_actions set target_id=m where room_id=r and night=2 and actor_id=d;
    raise exception 'night two allowed a second question';
  exception when raise_exception then if sqlerrm<>'ALREADY_INVESTIGATED' then raise; end if; end;

  -- A new night is a new row, and a fresh question.
  update public.room_state set phase_number=3 where room_id=r;
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,3,d,'investigate',doc);
end $$;
select 'PASS one investigation: first free, other target / skip refused, same target lands, other roles and new nights unaffected' as result;
rollback;
