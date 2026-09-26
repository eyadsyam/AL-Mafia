begin;
do $$
declare
  host1 uuid:=gen_random_uuid(); host2 uuid:=gen_random_uuid();
  host3 uuid:=gen_random_uuid(); viewer uuid:=gen_random_uuid();
  banned uuid:=gen_random_uuid(); kicked_user uuid:=gen_random_uuid();
  p uuid; r_near jsonb; r_far jsonb; r_full jsonb; r_private jsonb;
  listing record; codes text[]; i int;
begin
  insert into auth.users(id) values(host1),(host2),(host3),(viewer),(banned),(kicked_user);

  -- One player, capacity 10: four short of the start floor.
  r_far:=public.create_room_atomic('FARAAA',host1,'H1','male',1,
    '{"visibility":"public","title":"far","settings":{"maxPlayers":10}}'::jsonb);
  -- Four players, one kicked: three count, two short.
  r_near:=public.create_room_atomic('NEARAA',host2,'H2','male',2,
    '{"visibility":"public","title":"near","settings":{"maxPlayers":8}}'::jsonb);
  for i in 1..2 loop
    p:=gen_random_uuid(); insert into auth.users(id) values(p);
    perform public.join_room_atomic('NEARAA',p,'P'||i,'male');
  end loop;
  perform public.join_room_atomic('NEARAA',kicked_user,'K','male');
  update room_players set kicked=true where user_id=kicked_user;
  -- Full five-seat room.
  r_full:=public.create_room_atomic('FULLAA',host3,'H3','male',3,
    '{"visibility":"public","title":"full","settings":{"maxPlayers":5}}'::jsonb);
  for i in 1..4 loop
    p:=gen_random_uuid(); insert into auth.users(id) values(p);
    perform public.join_room_atomic('FULLAA',p,'F'||i,'male');
  end loop;
  -- Private rooms are never listed.
  p:=gen_random_uuid(); insert into auth.users(id) values(p);
  r_private:=public.create_room_atomic('PRVTAA',p,'X','male',4,
    '{"visibility":"private","settings":{"maxPlayers":10}}'::jsonb);
  -- A room the viewer is banned from.
  update rooms set banned_user_ids=array[banned] where code='FARAAA';

  select array_agg(code order by ord) into codes from (
    select code, row_number() over () as ord
    from public.public_room_listing(viewer)
    where code in ('FARAAA','NEARAA','FULLAA','PRVTAA')
  ) t;
  assert codes=array['NEARAA','FARAAA','FULLAA'], codes::text;

  select * into listing from public.public_room_listing(viewer) where code='NEARAA';
  assert listing.players=3, 'kicked seats do not count';
  assert listing.capacity=8 and listing.min_players=5;
  select * into listing from public.public_room_listing(viewer) where code='FULLAA';
  assert listing.players=5 and listing.capacity=5;

  assert not exists(select 1 from public.public_room_listing(banned) where code='FARAAA'),
    'a banned player is not offered the room';

  -- Once started, a room leaves the list.
  update rooms set status='playing' where code='NEARAA';
  assert not exists(select 1 from public.public_room_listing(viewer) where code='NEARAA');

  -- An empty lobby is not offered as if it had players in it.
  delete from room_players where room_id=(r_far->>'roomId')::uuid;
  assert not exists(select 1 from public.public_room_listing(viewer) where code='FARAAA');

  -- Only the service role may call it.
  assert not has_function_privilege('authenticated','public.public_room_listing(uuid)','execute');
  assert not has_function_privilege('anon','public.public_room_listing(uuid)','execute');
end $$;
rollback;
