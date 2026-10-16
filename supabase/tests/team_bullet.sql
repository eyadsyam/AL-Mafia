-- LOCAL ONLY: node tool/test_sql_without_docker.mjs team_bullet.sql
-- RL1 / D1 — the quiet night is the Mafia team's one bullet, held by the database.
begin;
do $$
declare
  r uuid := gen_random_uuid();
  m1 uuid := '00000000-0000-4000-8000-0000000000d1';
  m2 uuid := '00000000-0000-4000-8000-0000000000d2';
  sil uuid := '00000000-0000-4000-8000-0000000000d3';
  doc uuid := '00000000-0000-4000-8000-0000000000d4';
  c uuid := '00000000-0000-4000-8000-0000000000d5';
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'TEAMBL',m1,5,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role)
    values(r,m1,'M1',0,'mafia'),(r,m2,'M2',1,'mafia'),(r,sil,'S',2,'silencer'),
          (r,doc,'Doc',3,'doctor'),(r,c,'C',4,'citizen');
  insert into public.room_state(room_id,phase,phase_number) values(r,'night',1);

  -- The first Mafioso arms the quiet night.
  insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
    values(r,1,m1,'skip',null,true);

  -- His teammate may not, tonight or on any night after.
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
      values(r,1,m2,'kill',c,true);
    raise exception 'a second Mafioso spent the same night';
  exception when raise_exception then if sqlerrm<>'BULLET_SPENT' then raise; end if; end;

  -- A teammate may act without the bullet; arming it by update is refused too.
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,1,m2,'kill',c);
  begin
    update public.night_actions set used_bullet=true where room_id=r and night=1 and actor_id=m2;
    raise exception 'a second Mafioso armed the bullet by update';
  exception when raise_exception then if sqlerrm<>'BULLET_SPENT' then raise; end if; end;
  if (select used_bullet from public.night_actions where room_id=r and night=1 and actor_id=m2) then
    raise exception 'the refused bullet stayed on the row';
  end if;

  -- The one who spent it keeps it: a retry (upsert) is the same move.
  insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
    values(r,1,m1,'kill',c,true)
    on conflict (room_id,night,actor_id) do update
      set action=excluded.action,target_id=excluded.target_id,used_bullet=excluded.used_bullet;
  if not (select used_bullet from public.night_actions where room_id=r and night=1 and actor_id=m1) then
    raise exception 'the retry lost the bullet';
  end if;

  -- A later night: the team's bullet is still gone for the teammate, and the
  -- per-player index still refuses the same Mafioso a second one.
  update public.room_state set phase_number=2 where room_id=r;
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
      values(r,2,m2,'skip',null,true);
    raise exception 'a teammate spent the bullet on a later night';
  exception when raise_exception then if sqlerrm<>'BULLET_SPENT' then raise; end if; end;
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
      values(r,2,m1,'skip',null,true);
    raise exception 'the same Mafioso spent a second bullet';
  exception when unique_violation then null; end;

  -- Moves without the bullet are untouched, and so are the other roles'.
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,2,m1,'kill',c);
  insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
    values(r,2,doc,'protect',doc,true);
end $$;

-- Another room's Mafioso has a bullet of his own.
do $$
declare
  r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid();
  a uuid := '00000000-0000-4000-8000-0000000000e1';
  b uuid := '00000000-0000-4000-8000-0000000000e2';
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r1,'TEAMBX',a,5,'playing'),(r2,'TEAMBY',b,5,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role) values(r1,a,'A',0,'mafia'),(r2,b,'B',0,'mafia');
  insert into public.room_state(room_id,phase,phase_number) values(r1,'night',1),(r2,'night',1);
  insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
    values(r1,1,a,'skip',null,true);
  insert into public.night_actions(room_id,night,actor_id,action,target_id,used_bullet)
    values(r2,1,b,'skip',null,true);
end $$;
select 'PASS team bullet: one per team for the match, retries keep it, per-player index and other roles and rooms unaffected' as result;
rollback;
