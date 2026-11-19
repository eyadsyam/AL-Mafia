-- Contract for 20261119002000_friend_suggestions. Rolled back.
begin;

create function pg_temp.fs_user(p_handle text) returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  insert into public.player_directory(user_id,handle,handle_norm,display_name,name_norm)
    values(u,p_handle,public.directory_norm(p_handle),p_handle,public.directory_norm(p_handle));
  return u;
end $$;

create function pg_temp.fs_friends(a uuid, b uuid) returns void language sql as $$
  insert into public.friend_links(user_lo,user_hi,requested_by,accepted_at)
    values(least(a,b),greatest(a,b),a,now())
$$;

create function pg_temp.fs_match(p_a uuid, p_b uuid) returns void language plpgsql as $$
declare r uuid := gen_random_uuid();
begin
  insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,reunion)
    values(p_a,r,now(),current_date,'w','town',true,false,false),
          (p_b,r,now(),current_date,'w','mafia',false,false,false);
end $$;

do $$
declare me uuid := pg_temp.fs_user('sug_me');
  f1 uuid := pg_temp.fs_user('sug_f1'); f2 uuid := pg_temp.fs_user('sug_f2');
  t uuid := pg_temp.fs_user('sug_tbl');   -- twice at my table
  once uuid := pg_temp.fs_user('sug_once'); -- only once: no suggestion
  m uuid := pg_temp.fs_user('sug_mutual'); -- friend of both my friends
  h uuid := pg_temp.fs_user('sug_hidden');
  nb uuid := pg_temp.fs_user('sug_nobody');
  bl uuid := pg_temp.fs_user('sug_blocked');
  pend uuid := pg_temp.fs_user('sug_pending');
  s jsonb; row_t jsonb; row_m jsonb;
begin
  update public.economy_config set friends_enabled=true;
  perform pg_temp.fs_friends(me,f1); perform pg_temp.fs_friends(me,f2);
  perform pg_temp.fs_friends(m,f1);  perform pg_temp.fs_friends(m,f2);
  perform pg_temp.fs_friends(h,f1);  perform pg_temp.fs_friends(h,f2);
  perform pg_temp.fs_friends(nb,f1); perform pg_temp.fs_friends(nb,f2);
  perform pg_temp.fs_friends(bl,f1); perform pg_temp.fs_friends(bl,f2);
  perform pg_temp.fs_friends(pend,f1); perform pg_temp.fs_friends(pend,f2);
  -- Two shared matches with t, one with once.
  perform pg_temp.fs_match(me,t); perform pg_temp.fs_match(me,t); perform pg_temp.fs_match(me,once);
  update public.player_directory set searchable=false where user_id=h;
  update public.player_directory set who_can_add='nobody' where user_id=nb;
  insert into public.player_blocks(blocker_id,blocked_id) values(bl,me);
  -- (the block ends bl's friendships with me only; bl stays a friend of f1/f2)
  insert into public.friend_links(user_lo,user_hi,requested_by)
    values(least(me,pend),greatest(me,pend),me);

  s := public.friend_suggestions(me);
  select x into row_t from jsonb_array_elements(s->'rows') x where (x->>'userId')::uuid=t;
  select x into row_m from jsonb_array_elements(s->'rows') x where (x->>'userId')::uuid=m;
  assert row_t is not null and (row_t->>'matchesTogether')::int=2, s::text;
  assert row_t->>'handle'='sug_tbl' and row_t ? 'gender' and row_t ? 'name', s::text;
  assert row_m is not null and (row_m->>'mutualFriends')::int=2
     and row_m->'matchesTogether'='null'::jsonb, s::text;
  assert jsonb_array_length(s->'rows')=2, 'only t and m: '||s::text;
  assert not exists(select 1 from jsonb_array_elements(s->'rows') x
     where (x->>'userId')::uuid in (once,h,nb,bl,pend,f1,f2,me)), s::text;
  -- A blocked pair never shows on either side.
  assert not exists(select 1 from jsonb_array_elements(public.friend_suggestions(bl)->'rows') x
     where (x->>'userId')::uuid=me);
  -- Old matches do not count (60 days).
  update public.council_match_records set ended_at=now()-interval '61 days' where user_id in (me,t);
  assert jsonb_array_length(public.friend_suggestions(me)->'rows')=1;
  -- A player with the feature off, or clients: no.
  update public.economy_config set friends_enabled=false;
  begin perform public.friend_suggestions(me); assert false, 'answered while off';
  exception when others then assert sqlerrm='FEATURE_OFF', sqlerrm; end;
  assert not has_function_privilege('authenticated','public.friend_suggestions(uuid)','execute');
  raise notice 'friend_suggestions PASS';
end $$;
rollback;
