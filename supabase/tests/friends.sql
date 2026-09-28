-- Contract for 20260928000300_friends. Rolled back.
begin;

create function pg_temp.fr_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

-- A finished room where every listed user held a role.
create function pg_temp.fr_table(p_users uuid[], p_code text) returns uuid language plpgsql as $$
declare r uuid; i int;
begin
  r := (public.create_room_atomic(p_code,p_users[1],'U1','male',1,'{}'::jsonb)->>'roomId')::uuid;
  for i in 2..array_length(p_users,1) loop
    insert into public.room_players(room_id,user_id,name,gender,seat)
      values(r,p_users[i],'U'||i,'female',i-1);
  end loop;
  update public.room_players set role='citizen' where room_id=r;
  update public.rooms set status='finished', ended_at=now() where id=r;
  return r;
end $$;

do $$
declare a uuid := pg_temp.fr_user(); b uuid := pg_temp.fr_user(); c uuid := pg_temp.fr_user();
  stranger uuid := pg_temp.fr_user(); s jsonb; lobby uuid;
begin
  -- Off by default: nothing answers.
  assert public.friends_status(a)->>'enabled'='false';
  assert (public.economy_capabilities(a)->'social'->>'friends')::boolean = false;
  begin perform public.friend_request(a,b); assert false, 'requested while off';
  exception when others then assert sqlerrm='FEATURE_OFF', sqlerrm; end;

  update public.economy_config set friends_enabled=true;
  perform pg_temp.fr_table(array[a,b,c], 'FRND22');

  -- Tablemates appear as recent; strangers cannot be asked.
  s := public.friends_status(a);
  assert jsonb_array_length(s->'recent')=2, s::text;
  begin perform public.friend_request(a,stranger); assert false, 'asked a stranger';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;

  -- Request, then the other side asking back accepts it.
  s := public.friend_request(a,b);
  assert jsonb_array_length(s->'outgoing')=1, s::text;
  assert jsonb_array_length(public.friends_status(b)->'incoming')=1;
  s := public.friend_request(b,a);
  assert jsonb_array_length(s->'friends')=1, s::text;
  assert s->'friends'->0->'presence'->>'state'='away', s::text;
  -- Friends leave the recent list.
  assert not (public.friends_status(a)->'recent') @> jsonb_build_array(jsonb_build_object('id',b));

  -- Presence: a friend sitting in a lobby shows its code; invites land.
  lobby := (public.create_room_atomic('FRND33',a,'U1','male',2,'{}'::jsonb)->>'roomId')::uuid;
  assert public.friends_status(b)->'friends'->0->'presence'->>'code'='FRND33';
  perform public.friend_invite(a,b,lobby);
  s := public.friends_status(b);
  assert s->'invites'->0->>'code'='FRND33', s::text;
  -- Only friends can be invited.
  begin perform public.friend_invite(a,c,lobby); assert false, 'invited a non-friend';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;

  -- A block hides both ways and stops invites.
  insert into public.player_blocks(blocker_id,blocked_id) values(b,a);
  assert jsonb_array_length(public.friends_status(a)->'friends')=0;
  assert jsonb_array_length(public.friends_status(b)->'invites')=0;
  begin perform public.friend_invite(a,b,lobby); assert false, 'invited through a block';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  delete from public.player_blocks where blocker_id=b;

  -- Declining and removing.
  perform public.friend_request(a,c);
  perform public.friend_respond(c,a,false);
  assert jsonb_array_length(public.friends_status(a)->'outgoing')=0;
  perform public.friend_remove(a,b);
  assert jsonb_array_length(public.friends_status(a)->'friends')=0;

  assert not has_function_privilege('authenticated','public.friends_status(uuid)','execute');
  assert not has_function_privilege('authenticated','public.friend_request(uuid,uuid)','execute');
  assert (public.economy_capabilities(a)->'social'->>'friends')::boolean;
  assert public.economy_capabilities(a) ? 'fun', 'earlier capabilities lost';
end $$;
rollback;
