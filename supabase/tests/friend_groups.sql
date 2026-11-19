-- Contract for 20261119002200_friend_groups. Rolled back.
begin;

create function pg_temp.fg_user(p_handle text) returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  insert into public.player_directory(user_id,handle,handle_norm,display_name,name_norm)
    values(u,p_handle,public.directory_norm(p_handle),p_handle,public.directory_norm(p_handle));
  return u;
end $$;

create function pg_temp.fg_friends(a uuid, b uuid) returns void language sql as $$
  insert into public.friend_links(user_lo,user_hi,requested_by,accepted_at)
    values(least(a,b),greatest(a,b),a,now())
$$;

do $$
declare me uuid := pg_temp.fg_user('grp_me');
  a uuid := pg_temp.fg_user('grp_a'); b uuid := pg_temp.fg_user('grp_b');
  c uuid := pg_temp.fg_user('grp_c'); s uuid := pg_temp.fg_user('grp_stranger');
  room uuid; gl jsonb; gid uuid; r jsonb; ids uuid[]; i int;
begin
  update public.economy_config set friends_enabled=true;
  perform pg_temp.fg_friends(me,a); perform pg_temp.fg_friends(me,b); perform pg_temp.fg_friends(me,c);

  -- Save, list.
  gl := public.friend_group_save(me,null,'  الشلة  ',array[a,b]);
  assert jsonb_array_length(gl->'groups')=1 and gl->'groups'->0->>'name'='الشلة', gl::text;
  assert jsonb_array_length(gl->'groups'->0->'members')=2, gl::text;
  gid := (gl->'groups'->0->>'id')::uuid;
  -- Replace members and name under the same id (no second group).
  gl := public.friend_group_save(me,gid,'ثانية',array[a,b,c,a]);
  assert jsonb_array_length(gl->'groups')=1 and jsonb_array_length(gl->'groups'->0->'members')=3, gl::text;
  -- Rules: only my friends, names 1-20, limits, ownership.
  begin perform public.friend_group_save(me,null,'x',array[s]); assert false, 'stranger member';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  begin perform public.friend_group_save(me,null,'   ',array[a]); assert false, 'empty name';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.friend_group_save(me,null,repeat('ا',21),array[a]); assert false, 'long name';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.friend_group_save(s,gid,'سرقة',array[]::uuid[]); assert false, 'not mine';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  for i in 2..10 loop perform public.friend_group_save(me,null,'g'||i,array[a]); end loop;
  begin perform public.friend_group_save(me,null,'g11',array[a]); assert false, 'eleventh group';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  -- Fifteen members at most.
  declare many uuid[] := '{}'; k uuid;
  begin
    for i in 1..16 loop
      k := pg_temp.fg_user('grp_m'||i); perform pg_temp.fg_friends(me,k); many := many || k;
    end loop;
    begin perform public.friend_group_save(me,gid,'كبيرة',many); assert false, '16 members';
    exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
    perform public.friend_group_save(me,gid,'كبيرة',many[1:15]);
  end;
  gl := public.friend_group_save(me,gid,'الشلة',array[a,b,c]);
  assert jsonb_array_length((select x->'members' from jsonb_array_elements(gl->'groups') x
    where x->>'id'=gid::text))=3;
  -- A delete of someone else's group does nothing; mine goes.
  perform public.friend_group_delete(s,gid);
  assert exists(select 1 from public.friend_groups where id=gid);

  -- Invite: through room_invite_send, fresh ids returned for the pushes.
  room := (public.create_room_atomic('GRPWAQ',me,'Me','male',5,'{}'::jsonb)->>'roomId')::uuid;
  r := public.friend_group_invite(me,gid,room);
  assert (r->>'invited')::int=3 and jsonb_array_length(r->'inviteIds')=3, r::text;
  assert (select count(*) from public.room_invites where room_id=room and from_user=me)=3;
  -- Again: still invited, but nothing fresh to ring.
  r := public.friend_group_invite(me,gid,room);
  assert (r->>'invited')::int=3 and jsonb_array_length(r->'inviteIds')=0, r::text;
  -- A member already seated is skipped; a block drops the member out of everything.
  insert into public.room_players(room_id,user_id,name,gender,seat) values(room,a,'A','male',1);
  delete from public.room_invites where room_id=room;
  r := public.friend_group_invite(me,gid,room);
  assert (r->>'invited')::int=2, r::text;
  insert into public.player_blocks(blocker_id,blocked_id) values(c,me);  -- ends the friendship
  gl := public.friend_groups_list(me);
  assert not exists(select 1 from jsonb_array_elements(gl->'groups') x, jsonb_array_elements(x->'members') mm
    where (mm->>'userId')::uuid=c), gl::text;
  delete from public.room_invites where room_id=room;
  r := public.friend_group_invite(me,gid,room);
  assert (r->>'invited')::int=1, r::text;
  -- Not mine / not seated.
  begin perform public.friend_group_invite(s,gid,room); assert false, 'not my group';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  begin perform public.friend_group_invite(me,gid,gen_random_uuid()); assert false, 'not seated there';
  exception when others then assert sqlerrm in ('NOT_A_MEMBER') or sqlerrm='NOT_ALLOWED', sqlerrm; end;
  -- Deleting a group removes its members; the new count prop is accepted.
  perform public.friend_group_delete(me,gid);
  assert not exists(select 1 from public.friend_group_members where group_id=gid);
  perform public.metric_record(me,'friend','group_invite',gen_random_uuid());
  perform public.metric_record(me,'friend','ping',gen_random_uuid());
  begin perform public.metric_record(me,'friend','gossip',gen_random_uuid()); assert false, 'unknown prop';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  assert not has_function_privilege('authenticated','public.friend_group_save(uuid,uuid,text,uuid[])','execute');
  assert not has_table_privilege('authenticated','public.friend_groups','select');
  raise notice 'friend_groups PASS';
end $$;
rollback;
