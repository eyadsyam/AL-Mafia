-- Contract for 20261119001000_friends_v2. Rolled back.
begin;

create function pg_temp.f2_user(p_handle text) returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  if p_handle is not null then
    insert into public.player_directory(user_id,handle,handle_norm,display_name,name_norm)
      values(u,p_handle,public.directory_norm(p_handle),p_handle,public.directory_norm(p_handle));
  end if;
  return u;
end $$;

do $$
declare a uuid := pg_temp.f2_user('amira_t');
  b uuid := pg_temp.f2_user('basem_t');
  c uuid := pg_temp.f2_user('carma_t');
  n uuid := pg_temp.f2_user(null);
  s jsonb; p jsonb; r uuid; ping jsonb;
begin
  update public.economy_config set friends_enabled=true;

  -- S6 defaults and the privacy row.
  p := public.directory_privacy(a,null,null,null);
  assert p->>'whoCanAdd'='everyone' and (p->>'showOnline')::boolean, p::text;
  begin perform public.directory_privacy(a,'strangers',null,null); assert false, 'bad rule kept';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;

  -- S2: everyone (the default) may be asked without a shared table.
  s := public.friend_request(a,b);
  assert jsonb_array_length(s->'outgoing')=1, s::text;
  -- 'nobody' refuses, by id and by handle alike; unknown handles too.
  perform public.directory_privacy(c,'nobody',null,null);
  begin perform public.friend_request(a,c); assert false, 'nobody asked';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  begin perform public.friend_request_by_handle(a,'carma_t'); assert false, 'nobody by handle';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  begin perform public.friend_request_by_handle(a,'no_such_handle_x'); assert false, 'ghost handle';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  -- 'tablemates' keeps the 30-day rule; a player with no directory row too.
  perform public.directory_privacy(c,'tablemates',null,null);
  begin perform public.friend_request(a,c); assert false, 'tablemates rule skipped';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  begin perform public.friend_request(a,n); assert false, 'no-row player asked';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  -- A waiting request is always mine to accept, whatever my own rule.
  perform public.directory_privacy(a,'nobody',null,null);
  s := public.friend_request_by_handle(b,'@amira_t');
  assert jsonb_array_length(s->'friends')=1, s::text;
  assert (s->>'target')::uuid = a, s::text;
  perform public.directory_privacy(a,'everyone',null,null);

  -- Presence honours «أصحابي يشوفوني أونلاين».
  update public.player_directory set last_seen_at=now() where user_id=b;
  assert public.directory_state(b)='online';
  perform public.directory_privacy(b,null,false,null);
  assert public.directory_state(b)='away';
  r := (public.create_room_atomic('FVTWAQ',b,'B','male',3,'{}'::jsonb)->>'roomId')::uuid;
  assert public.friends_presence(b)->>'state'='away', public.friends_presence(b)::text;
  perform public.directory_privacy(b,null,true,null);
  assert public.friends_presence(b)->>'state'='lobby', public.friends_presence(b)::text;

  -- S3 pings: friends only, 3 «يلا نلعب؟» a day, replies only to one.
  begin perform public.friend_ping(a,c,'lets_play'); assert false, 'pinged a non-friend';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  begin perform public.friend_ping(b,a,'coming'); assert false, 'reply with no invitation';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  ping := public.friend_ping(a,b,'lets_play');
  assert (ping->>'pingId') is not null, ping::text;
  assert jsonb_array_length(public.friend_pings_inbox(b))=1;
  assert public.friend_pings_inbox(b)->0->>'kind'='lets_play';
  assert public.friend_ping_push_targets((ping->>'pingId')::bigint)->>'kind' in ('friend_ping')
      or public.friend_ping_push_targets((ping->>'pingId')::bigint)->>'enabled'='false';
  perform public.friend_ping(b,a,'coming');
  perform public.friend_ping(b,a,'five_min');
  assert jsonb_array_length(public.friend_pings_inbox(a))=1, public.friend_pings_inbox(a)::text;
  assert public.friend_pings_inbox(a)->0->>'kind'='five_min';
  perform public.friend_ping(a,b,'lets_play');
  perform public.friend_ping(a,b,'lets_play');
  begin perform public.friend_ping(a,b,'lets_play'); assert false, 'fourth ping';
  exception when others then assert sqlerrm='RATE_LIMITED', sqlerrm; end;
  -- A block: answered ok, nothing stored, inbox empty.
  insert into public.player_blocks(blocker_id,blocked_id) values(b,a);
  ping := public.friend_ping(a,b,'not_now');
  assert ping->>'pingId' is null, ping::text;
  assert jsonb_array_length(public.friend_pings_inbox(b))=0;
  begin perform public.friend_profile(a,b); assert false, 'profile across a block';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  delete from public.player_blocks where blocker_id=b and blocked_id=a;
  -- A block may end the friendship; make it again for the profile checks.
  if not public.directory_is_friend(a,b) then
    perform public.friend_request(a,b);
    perform public.friend_request(b,a);
  end if;
  assert public.directory_is_friend(a,b);

  -- S4: numbers from finished records only.
  r := gen_random_uuid();
  insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,reunion)
    values(a,r,now(),current_date,'w','town',false,false,false),
          (b,r,now(),current_date,'w','mafia',true,false,false);
  p := public.friend_profile(a,b);
  assert (p->>'matchesTogether')::int=1 and (p->>'fooledMe')::int=1
     and (p->>'wonTogether')::int=0, p::text;
  assert p->'mafiaShare' = 'null'::jsonb, p::text;
  begin perform public.friend_profile(a,c); assert false, 'profile of a non-friend';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;

  -- Old pending requests go.
  perform public.friend_request(c,a);
  update public.friend_links set created_at=now()-interval '31 days'
   where accepted_at is null;
  assert public.friend_requests_purge() >= 1;

  -- Clients cannot call any of it.
  assert not has_function_privilege('anon','public.friend_ping(uuid,uuid,text)','execute');
  assert not has_function_privilege('authenticated','public.friend_profile(uuid,uuid)','execute');
  assert not has_function_privilege('authenticated','public.directory_privacy(uuid,text,boolean,boolean)','execute');
  assert not has_table_privilege('authenticated','public.friend_pings','select');
  raise notice 'friends_v2 PASS';
end $$;
rollback;
