-- Contract for 20261119002100_friend_activity. Rolled back.
begin;

create function pg_temp.fa_user(p_handle text) returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  insert into public.player_directory(user_id,handle,handle_norm,display_name,name_norm)
    values(u,p_handle,public.directory_norm(p_handle),p_handle,public.directory_norm(p_handle));
  return u;
end $$;

create function pg_temp.fa_friends(a uuid, b uuid) returns void language sql as $$
  insert into public.friend_links(user_lo,user_hi,requested_by,accepted_at)
    values(least(a,b),greatest(a,b),a,now())
$$;

create function pg_temp.fa_record(p_user uuid, p_room uuid, p_won boolean, p_team text, p_age interval)
returns void language sql as $$
  insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,reunion,created_at)
    values(p_user,p_room,now()-p_age,current_date,'w',p_team,p_won,false,false,now()-p_age)
$$;

do $$
declare me uuid := pg_temp.fa_user('act_me');
  f uuid := pg_temp.fa_user('act_friend');
  g uuid := pg_temp.fa_user('act_quiet');
  s uuid := pg_temp.fa_user('act_stranger');
  r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid(); r3 uuid := gen_random_uuid();
  r4 uuid := gen_random_uuid();
  feed jsonb; item jsonb; id1 bigint; p jsonb; n int;
begin
  update public.economy_config set friends_enabled=true;
  perform pg_temp.fa_friends(me,f); perform pg_temp.fa_friends(me,g);

  -- win_streak: the third win in a row, once; a loss resets.
  perform pg_temp.fa_record(f,r1,true,'town','3 hours');
  perform pg_temp.fa_record(f,r2,true,'mafia','2 hours');
  assert (select count(*) from public.friend_activity where user_id=f)=0, 'two wins announced';
  perform pg_temp.fa_record(f,r3,true,'town','1 hour');
  assert (select count(*) from public.friend_activity where user_id=f and kind='win_streak')=1;
  perform pg_temp.fa_record(f,r4,true,'town','30 minutes');
  assert (select count(*) from public.friend_activity where user_id=f and kind='win_streak')=1,
    'a fourth win must not repeat the streak';
  -- Sharing off: nothing is written for g.
  update public.player_directory set share_activity=false where user_id=g;
  perform pg_temp.fa_record(g,gen_random_uuid(),true,'town','3 hours');
  perform pg_temp.fa_record(g,gen_random_uuid(),true,'town','2 hours');
  perform pg_temp.fa_record(g,gen_random_uuid(),true,'town','1 hour');
  assert (select count(*) from public.friend_activity where user_id=g)=0, 'activity written while off';
  update public.player_directory set share_activity=true where user_id=g;

  -- rank_up: an XP grant that crosses a tier (level 6 needs 100*5+10*5*4=700).
  insert into public.council_xp_events(user_id,source_key,xp,week) values(f,'t1',50,'w');
  assert (select count(*) from public.friend_activity where user_id=f and kind='rank_up')=0;
  insert into public.council_xp_events(user_id,source_key,xp,week) values(f,'t2',700,'w');
  select data into item from public.friend_activity where user_id=f and kind='rank_up';
  assert item->>'title' = (select title_ar from public.council_rank_tiers where tier=2), item::text;

  -- The feed: my friend's two items, newest first, with 3 reaction counters.
  feed := public.friend_feed(me);
  assert jsonb_array_length(feed->'items')=2, feed::text;
  item := feed->'items'->0;
  assert item->>'name'='act_friend' and item->'reactions' ? '👏' and item->'reactions' ? '🔥'
     and item->'reactions' ? '😂' and item->'mine'='null'::jsonb, item::text;
  assert (item->>'userId')::uuid=f, item::text;
  -- Doc 05: items carry a kind, a count or a title: no role, no team, no room.
  assert not (feed::text like '%"team"%' or feed::text like '%"role"%' or feed::text like '%room%'), feed::text;

  -- Reactions: set, change, count, take back; strangers and bad emoji refused.
  id1 := (item->>'id')::bigint;
  perform public.friend_react(me,id1,'👏');
  perform public.friend_react(me,id1,'🔥');
  feed := public.friend_feed(me);
  select x into item from jsonb_array_elements(feed->'items') x where (x->>'id')::bigint=id1;
  assert item->>'mine'='🔥' and (item->'reactions'->>'🔥')::int=1 and (item->'reactions'->>'👏')::int=0, item::text;
  perform public.friend_react(me,id1,null);
  assert (select count(*) from public.friend_activity_reactions)=0;
  begin perform public.friend_react(me,id1,'💩'); assert false, 'bad emoji';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.friend_react(s,id1,'👏'); assert false, 'stranger reacted';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;

  -- Sharing off hides what already exists; a block hides too.
  update public.player_directory set share_activity=false where user_id=f;
  assert jsonb_array_length(public.friend_feed(me)->'items')=0;
  update public.player_directory set share_activity=true where user_id=f;
  assert jsonb_array_length(public.friend_feed(me)->'items')=2;
  insert into public.player_blocks(blocker_id,blocked_id) values(me,f);
  assert jsonb_array_length(public.friend_feed(me)->'items')=0;
  assert jsonb_array_length(public.friend_feed(f)->'items')=0;
  delete from public.player_blocks where blocker_id=me and blocked_id=f;
  perform pg_temp.fa_friends(me,f);  -- the block cleanup ended the friendship; remake it

  -- Weekly: my matches / wins / mafia games and the friend I played with most.
  perform pg_temp.fa_record(me,r3,true,'mafia','1 hour');
  perform pg_temp.fa_record(me,r4,false,'town','30 minutes');
  feed := public.friend_feed(me);
  p := feed->'weekly';
  -- (rows may fall before this Saturday's start when run on a Saturday morning)
  assert (p->>'matches')::int in (0,2) and (p->>'mafia')::int in (0,1), p::text;
  if (p->>'matches')::int = 2 then
    assert (p->>'wins')::int=1 and p->'topFriend'->>'name'='act_friend'
       and (p->'topFriend'->>'count')::int=2, p::text;
    -- Board: me and my sharing friends, wins this week; both with their wins.
    assert exists(select 1 from jsonb_array_elements(feed->'board') x
      where (x->>'me')::boolean and (x->>'wins')::int=1), feed->>'board';
    assert exists(select 1 from jsonb_array_elements(feed->'board') x
      where (x->>'userId')::uuid=f and (x->>'wins')::int>=1), feed->>'board';
  end if;
  -- A friend who does not share is off the board; I am always on it.
  update public.player_directory set share_activity=false where user_id=f;
  feed := public.friend_feed(me);
  assert not exists(select 1 from jsonb_array_elements(feed->'board') x where (x->>'userId')::uuid=f), feed->>'board';
  assert exists(select 1 from jsonb_array_elements(feed->'board') x where (x->>'me')::boolean), feed->>'board';
  assert feed->'weekly' ? 'topFriend';

  -- The privacy row: the new switch, and the 4-argument form still works.
  p := public.directory_privacy(me,null,null,null,false);
  assert (p->>'shareActivity')::boolean = false, p::text;
  p := public.directory_privacy(me,null,null,null);
  assert (p->>'shareActivity')::boolean = false and p->>'whoCanAdd'='everyone', p::text;

  -- Purge, and clients cannot call any of it.
  update public.friend_activity set created_at=now()-interval '15 days' where user_id=f;
  assert public.friend_activity_purge() >= 1;
  assert not has_function_privilege('authenticated','public.friend_feed(uuid)','execute');
  assert not has_function_privilege('authenticated','public.friend_react(uuid,bigint,text)','execute');
  assert not has_table_privilege('authenticated','public.friend_activity','select');
  raise notice 'friend_activity PASS';
end $$;
rollback;
