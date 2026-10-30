-- Contract for 20261030006200_equipment_reaches_lobby. Rolled back.
begin;

do $$
declare
  host uuid := gen_random_uuid();
  guest uuid := gen_random_uuid();
  lobby_room uuid := gen_random_uuid();
  played_room uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
    (host,null,null,true),(guest,null,null,true);
  insert into public.rooms(id,code,host_id,status,match_seed) values
    (lobby_room,'K7M2QP',host,'lobby',1),(played_room,'K7M2QR',host,'finished',2);
  insert into public.room_players(room_id,user_id,seat,name) values
    (lobby_room,guest,1,'g'),(played_room,guest,1,'g');
  update public.room_players set cosmetics='{"rank":3,"frame":"frame_old"}' where user_id=guest;

  insert into public.player_inventory(user_id,item_code) values(guest,'frame_gilded'),(guest,'narrator_noir');
  insert into public.player_equipment(user_id,slot,item_code) values(guest,'frame','frame_gilded');
  assert (select cosmetics from public.room_players where room_id=lobby_room and user_id=guest)
    = '{"frame":"frame_gilded","rank":3}'::jsonb, 'the lobby seat follows; the rank stays';
  assert (select cosmetics->>'frame' from public.room_players where room_id=played_room and user_id=guest)
    = 'frame_old', 'a room past its lobby is fixed';

  -- A narrator is the host's room setting, not something a seat wears.
  insert into public.player_equipment(user_id,slot,item_code) values(guest,'narrator','narrator_noir');
  assert not (select cosmetics ? 'narrator' from public.room_players where room_id=lobby_room and user_id=guest);

  delete from public.player_equipment where user_id=guest and slot='frame';
  assert (select cosmetics from public.room_players where room_id=lobby_room and user_id=guest)
    = '{"rank":3}'::jsonb, 'taking it off shows too';
end $$;

rollback;
