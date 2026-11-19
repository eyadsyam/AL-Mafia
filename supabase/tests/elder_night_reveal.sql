begin;
-- The Elder's night reveal (owner, 2026-11-19): a 'reveal' row is stored for the
-- Elder only; the morning commit marks him revealed when he is alive after the
-- night's deaths and publishes morning.elderRevealedSeat; otherwise the key is
-- absent. Weight 3 is read from public_data.elderRevealedSeats (resolve_vote).
do $$
declare
  r uuid := gen_random_uuid();
  u0 uuid := gen_random_uuid(); u1 uuid := gen_random_uuid();
  u2 uuid := gen_random_uuid(); u3 uuid := gen_random_uuid();
  d timestamptz := now() + interval '120 seconds';
  pd jsonb; ok boolean;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'QQ7PXE',u0,7,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,saw_role) values
    (r,u0,'m',0,'mafia',true),(r,u1,'c',1,'citizen',true),
    (r,u2,'e',2,'elder',true),(r,u3,'d',3,'doctor',true);
  insert into public.room_state(room_id,phase,phase_number,phase_ends_at,public_data)
    values(r,'night',1,d,'{}');

  -- the Elder's reveal row is accepted by the table (no target)
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,1,u2,'reveal',null);
  -- a reveal naming a target is refused by the constraint
  begin
    insert into public.night_actions(room_id,night,actor_id,action,target_id)
      values(r,1,u1,'reveal',u0);
    raise exception 'a reveal with a target was accepted';
  exception when check_violation then null; end;

  -- a stray citizen reveal row (the function never stores one) is ignored
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,1,u1,'reveal',null);

  -- A) Elder alive: revealed, payload seat, marker for the vote weight
  ok := public.commit_night_roles_resolution(
    r,1,array[]::uuid[],null,'{}',
    '{"morning":{"victimSeats":[]},"outcome":null}','morning',d,
    public.night_fingerprint(r,1));
  if not ok then raise exception 'night with a reveal did not commit'; end if;
  select public_data into pd from public.room_state where room_id=r;
  if (pd->'morning'->>'elderRevealedSeat')<>'2' then raise exception 'no payload seat: %', pd; end if;
  if pd->'elderRevealedSeats' is distinct from '[2]'::jsonb then
    raise exception 'marker (vote weight 3) missing: %', pd; end if;

  -- B) next night, nobody reveals: the key is absent, the marker stays
  update public.room_state set phase='night',phase_number=2 where room_id=r;
  ok := public.commit_night_roles_resolution(
    r,2,array[]::uuid[],null,'{}',
    '{"morning":{"victimSeats":[]},"outcome":null}','morning',d,
    public.night_fingerprint(r,2));
  select public_data into pd from public.room_state where room_id=r;
  if not ok or (pd->'morning') ? 'elderRevealedSeat' then
    raise exception 'a morning without a reveal carried the key: %', pd; end if;

  -- C) a fresh room: the Elder reveals and is killed the same night
  declare r2 uuid := gen_random_uuid();
          v0 uuid := gen_random_uuid(); v1 uuid := gen_random_uuid(); v2 uuid := gen_random_uuid();
  begin
    insert into public.rooms(id,code,host_id,match_seed,status) values(r2,'QQ7PXF',v0,7,'playing');
    insert into public.room_players(room_id,user_id,name,seat,role,saw_role) values
      (r2,v0,'m',0,'mafia',true),(r2,v1,'c',1,'citizen',true),(r2,v2,'e',2,'elder',true);
    insert into public.room_state(room_id,phase,phase_number,phase_ends_at,public_data)
      values(r2,'night',1,d,'{}');
    insert into public.night_actions(room_id,night,actor_id,action,target_id)
      values(r2,1,v2,'reveal',null),(r2,1,v0,'kill',v2);
    ok := public.commit_night_roles_resolution(
      r2,1,array[v2],null,'{}',
      '{"morning":{"victimSeats":[2]},"outcome":null}','morning',d,
      public.night_fingerprint(r2,1));
    if not ok then raise exception 'night with a death did not commit'; end if;
    select public_data into pd from public.room_state where room_id=r2;
    if pd ? 'elderRevealedSeats' or (pd->'morning') ? 'elderRevealedSeat' then
      raise exception 'a dead Elder revealed: %', pd; end if;
  end;
end $$;
rollback;
