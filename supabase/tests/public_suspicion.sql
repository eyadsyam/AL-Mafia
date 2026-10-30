-- Contract for 20261030003000_public_suspicion. Rolled back.
begin;

create function pg_temp.ps_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

create function pg_temp.refused(p_room uuid, p_user uuid, p_target integer, p_code text)
returns void language plpgsql as $$
begin
  perform public.set_public_suspicion(p_room, p_user, p_target);
  raise exception 'expected % but it was accepted', p_code;
exception when others then
  if sqlerrm <> p_code then raise exception 'expected %, got %', p_code, sqlerrm; end if;
end $$;

do $$
declare
  a uuid := pg_temp.ps_user(); b uuid := pg_temp.ps_user();
  c uuid := pg_temp.ps_user(); d uuid := pg_temp.ps_user();
  r uuid; out jsonb;
begin
  r := (public.create_room_atomic('PSUS22', a, 'A', 'male', 1, '{}'::jsonb)->>'roomId')::uuid;
  insert into public.room_players(room_id,user_id,name,gender,seat) values
    (r,b,'B','male',1),(r,c,'C','female',2),(r,d,'D','male',3);
  update public.room_players set role='citizen' where room_id=r;
  update public.rooms set status='playing' where id=r;
  update public.room_state set phase='morning', phase_number=2,
    public_data = jsonb_build_object('morning', jsonb_build_object('silencedSeat', 3))
   where room_id=r;

  -- Not before the discussion.
  perform pg_temp.refused(r, a, 1, 'PHASE_CLOSED');
  update public.room_state set phase='discuss' where room_id=r;

  -- A names B: public at once, under day 2, by seat.
  out := public.set_public_suspicion(r, a, 1);
  assert out->'suspicions' = '{"0": 1}'::jsonb, out::text;
  assert (select public_data->'suspicions'->'2'->>'0' from public.room_state where room_id=r) = '1';
  -- The morning and anything else in public_data survive.
  assert (select public_data->'morning'->>'silencedSeat' from public.room_state where room_id=r) = '3';

  -- Changing it replaces it; another player's pick stays.
  perform public.set_public_suspicion(r, b, 2);
  perform public.set_public_suspicion(r, a, 2);
  assert (select public_data->'suspicions'->'2' from public.room_state where room_id=r)
    = '{"0": 2, "1": 2}'::jsonb;
  -- Clearing removes only the caller's.
  perform public.set_public_suspicion(r, a, null);
  assert (select public_data->'suspicions'->'2' from public.room_state where room_id=r)
    = '{"1": 2}'::jsonb;

  -- Not yourself, not the dead, not while silenced, not when dead.
  perform pg_temp.refused(r, a, 0, 'BAD_REQUEST');
  update public.room_players set alive=false where room_id=r and seat=2;
  perform pg_temp.refused(r, a, 2, 'BAD_REQUEST');
  perform pg_temp.refused(r, d, 0, 'SILENCED');
  perform pg_temp.refused(r, c, 0, 'NOT_ALIVE');

  -- A stranger is not a member.
  perform pg_temp.refused(r, pg_temp.ps_user(), 0, 'NOT_A_MEMBER');

  -- The next day's picks live under their own day; yesterday's are kept.
  update public.room_state set phase_number=3 where room_id=r;
  perform public.set_public_suspicion(r, a, 1);
  assert (select public_data->'suspicions' from public.room_state where room_id=r)
    = '{"2": {"1": 2}, "3": {"0": 1}}'::jsonb;

  assert not has_function_privilege('authenticated','public.set_public_suspicion(uuid,uuid,integer)','execute');
end $$;

rollback;
