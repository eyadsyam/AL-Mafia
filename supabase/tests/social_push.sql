-- Contract for 20260930000200_social_push. Rolled back.
begin;

create function pg_temp.sp_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

do $$
declare a uuid := pg_temp.sp_user(); b uuid := pg_temp.sp_user(); r uuid; t jsonb;
begin
  update public.economy_config set friends_enabled=true;
  perform public.directory_hello(a,'إياد','male','EG','ar');
  r := (public.create_room_atomic('SPSH22',a,'U1','male',1,'{}'::jsonb)->>'roomId')::uuid;
  insert into public.room_players(room_id,user_id,name,gender,seat) values(r,b,'U2','female',1);
  update public.room_players set role='citizen' where room_id=r;
  update public.rooms set status='finished', ended_at=now() where id=r;
  perform public.push_token_register(b,repeat('b',40),'android');
  perform public.push_token_register(a,repeat('a',40),'web');

  perform public.friend_request(a,b);
  -- Push off: nothing.
  assert public.friend_push_targets(a,b)->>'enabled'='false';
  update public.economy_config set push_invites_enabled=true;
  t := public.friend_push_targets(a,b);
  assert t->>'kind'='friend_request' and t->>'fromName'='إياد', t::text;
  assert jsonb_array_length(t->'tokens')=1 and t->'tokens'->0->>'platform'='android', t::text;
  assert (select array_agg(k order by k) from jsonb_object_keys(t) k)
    = array['enabled','fromName','kind','tokens'], t::text;
  -- The other direction is not a fresh request.
  assert public.friend_push_targets(b,a)->>'enabled'='false';

  -- Accepting tells the requester.
  perform public.friend_respond(b,a,true);
  t := public.friend_push_targets(b,a);
  assert t->>'kind'='friend_accepted' and t->'tokens'->0->>'platform'='web', t::text;

  -- An old event is not pushed again; a block stops everything.
  update public.friend_links set accepted_at=now()-interval '5 minutes';
  assert public.friend_push_targets(b,a)->>'enabled'='false';
  update public.friend_links set accepted_at=now();
  insert into public.player_blocks(blocker_id,blocked_id) values(a,b);
  assert public.friend_push_targets(b,a)->>'enabled'='false';
  assert not has_function_privilege('authenticated','public.friend_push_targets(uuid,uuid)','execute');
end $$;
rollback;
