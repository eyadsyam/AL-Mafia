-- Contract for 20261030006300_deal_role_flags_follow. Rolled back.
begin;

do $$
declare
  host uuid := gen_random_uuid();
  room uuid := gen_random_uuid();
  u uuid;
  s jsonb;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(host,null,null,true);
  insert into public.rooms(id,code,host_id,status,match_seed,settings) values
    (room,'K7M2QT',host,'lobby',1,'{"sniperEnabled":true,"elderEnabled":true,"speechSeconds":30}');
  insert into public.room_state(room_id,phase) values(room,'lobby') on conflict do nothing;
  insert into public.room_players(room_id,user_id,seat,name,status,connected,lobby_ready)
    values(room,host,0,'h','connected',true,true);
  for i in 1..5 loop
    u := gen_random_uuid();
    insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
    insert into public.room_players(room_id,user_id,seat,name,status,connected,lobby_ready)
      values(room,u,i,'p','connected',true,true);
  end loop;

  -- Six seats: the elder fits, the sniper the host wished for does not.
  assert public.apply_match_deal(room,host,
    array['mafia','detective','elder','citizen','citizen','citizen'],
    '{"sniperEnabled":false,"elderEnabled":true,"speechSeconds":45}',now());
  select settings into s from public.rooms where id=room;
  assert (s->>'sniperEnabled')::boolean = false, s::text;
  assert (s->>'elderEnabled')::boolean = true, s::text;
  assert (s->>'silencerEnabled')::boolean = false, s::text;
  assert (s->>'speechSeconds')::int = 30, 'the rest of the stored settings still win';
end $$;

rollback;
