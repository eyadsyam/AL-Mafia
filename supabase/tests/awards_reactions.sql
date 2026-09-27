-- Contract for 20260925000600_awards_reactions. Rolled back.
--
-- Every gate runs in its own subtransaction and is rolled back on exit, so a
-- failing gate never masks or feeds the next. Failures are collected and
-- reported together at the end.
--
-- Single connection (PGlite): proves logic, idempotency and guards, NOT
-- hosted lock ordering or Realtime delivery.
begin;

alter table auth.users add column if not exists created_at timestamptz not null default now();

create temp table ar_results(gate text primary key, ok boolean not null, detail text);

create function pg_temp.ar_record(p_gate text, p_err text) returns void
language sql as $$
  insert into ar_results values(p_gate, p_err='GATE_OK', nullif(p_err,'GATE_OK'))
$$;

create function pg_temp.ar_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u, u::text||'@example.test', now(), false);
  return u;
end $$;

create function pg_temp.ar_code() returns text language plpgsql as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; c text := ''; i int;
begin
  for i in 1..6 loop c := c || substr(a, public.secure_random_below(32)+1, 1); end loop;
  return c;
end $$;

-- A room in p_status/p_phase with players in seat order.
create function pg_temp.ar_room(p_players uuid[], p_roles text[], p_status text,
  p_phase text, p_public jsonb default '{}') returns uuid language plpgsql as $$
declare r uuid := gen_random_uuid(); i int;
begin
  insert into rooms(id,code,host_id,status,ended_at,match_seed)
    values(r,pg_temp.ar_code(),p_players[1],p_status,
      case when p_status='finished' then now() end,1);
  for i in 1..array_length(p_players,1) loop
    insert into room_players(room_id,user_id,seat,name,role,kicked)
      values(r,p_players[i],i-1,'Player '||i,p_roles[i],false);
  end loop;
  insert into room_state(room_id,phase,phase_number,public_data) values(r,p_phase,1,p_public);
  return r;
end $$;

create function pg_temp.ar_vote(p_room uuid, p_day int, p_round int, p_voter uuid,
  p_target uuid, p_sec int) returns void language sql as $$
  -- The phase guard admits a ballot only into its own day and round.
  update room_state set phase='vote', phase_number=p_day,
    public_data=jsonb_build_object('revote',jsonb_build_object('round',p_round,
      'tiedSeats',(select jsonb_agg(seat) from room_players where room_id=p_room)))
   where room_id=p_room;
  insert into votes(room_id,day,voter_id,target_id,round,created_at)
    values(p_room,p_day,p_voter,p_target,p_round,
      timestamptz '2026-09-20 12:00:00+00' + make_interval(secs => p_sec))
$$;

create function pg_temp.ar_awardees(p_room uuid, p_award text) returns uuid[]
language sql as $$
  select coalesce(array_agg(user_id order by seat),'{}') from match_awards
   where room_id=p_room and award=p_award
$$;

create function pg_temp.ar_balance(p_user uuid) returns bigint language sql as $$
  select coalesce((select balance from wallet_accounts where user_id=p_user),0)
$$;

-- The six-player town win used by several gates. Returns the room; the
-- players are m1,m2 (mafia), doc, det, c1, c2 in seats 0..5.
create function pg_temp.ar_town_win(p uuid[]) returns uuid language plpgsql as $$
declare r uuid;
begin
  r := pg_temp.ar_room(p, array['mafia','mafia','doctor','detective','citizen','citizen'],
    'playing','vote');
  -- Night 1: the doctor covers c1, whom the Mafia shot. Saved.
  update room_state set phase='night', phase_number=1 where room_id=r;
  insert into night_actions(room_id,night,actor_id,action,target_id)
    values(r,1,p[3],'protect',p[5]),(r,1,p[1],'kill',p[5]);
  insert into night_resolution_private(room_id,night,saved_seat) values(r,1,4);
  -- Day 1 (one round): det, c1, doc on m1; c2 on det; the Mafia on c2.
  perform pg_temp.ar_vote(r,1,1,p[4],p[1],1);
  perform pg_temp.ar_vote(r,1,1,p[5],p[1],2);
  perform pg_temp.ar_vote(r,1,1,p[3],p[1],3);
  perform pg_temp.ar_vote(r,1,1,p[6],p[4],4);
  perform pg_temp.ar_vote(r,1,1,p[1],p[6],5);
  perform pg_temp.ar_vote(r,1,1,p[2],p[6],6);
  -- Day 2: round 1 tied and is ignored; round 2 takes m2.
  perform pg_temp.ar_vote(r,2,1,p[4],p[5],7);
  perform pg_temp.ar_vote(r,2,2,p[6],p[2],9);
  perform pg_temp.ar_vote(r,2,2,p[5],p[2],10);
  perform pg_temp.ar_vote(r,2,2,p[4],p[2],11);
  perform pg_temp.ar_vote(r,2,2,p[2],p[4],12);
  update room_players set alive=false where room_id=r and user_id in (p[1],p[2]);
  update room_state set phase='vote', phase_number=2, public_data=jsonb_build_object('eliminations',
    jsonb_build_object('0',jsonb_build_object('phase','day','number',1),
                       '1',jsonb_build_object('phase','day','number',2)),
    'outcome','town') where room_id=r;
  return r;
end $$;

create function pg_temp.ar_six() returns uuid[] language plpgsql as $$
declare p uuid[] := '{}'; i int;
begin
  for i in 1..6 loop p := p || pg_temp.ar_user(); end loop;
  return p;
end $$;

-- A1. Ships off; a missing config row reads as off ---------------------------
do $$
declare p uuid[]; r uuid; s jsonb;
begin
  begin
    assert (select not awards_enabled and not reactions_enabled and not founder_enabled
      and founder_window_start is null from economy_config), 'defaults not off';
    p := pg_temp.ar_six();
    s := public.economy_capabilities(p[1]);
    assert (s->'fun') - 'characterBonds'='{"awards":false,"reactions":false,"founder":false}'::jsonb, s::text;
    -- Earlier answers survive the composition.
    assert (s->>'version')::int=2 and s ? 'council' and s ? 'adSteps', s::text;
    r := pg_temp.ar_town_win(p);
    update rooms set status='finished', ended_at=now() where id=r;
    update room_state set phase='result' where room_id=r;
    assert not exists(select 1 from match_awards_computed where room_id=r), 'computed while off';
    assert public.match_awards_get(p[1],r)='{"enabled":false}'::jsonb, 'read while off';
    begin perform public.send_room_reaction(p[1],r,'laugh'); assert false, 'reacted while off';
    exception when others then assert sqlerrm='FEATURE_OFF', 'react: '||sqlerrm; end;
    assert public.fun_profile(p[1])->'badges'='[]'::jsonb, 'badge while off';
    assert pg_temp.ar_balance(p[4])=0, 'coins while off';
    delete from economy_config;
    s := public.economy_capabilities(p[1]);
    assert s->'fun'->'awards'='false'::jsonb and s->'fun'->'reactions'='false'::jsonb, s::text;
    assert public.match_awards_get(p[1],r)='{"enabled":false}'::jsonb, 'no config';
    insert into economy_config default values;
    begin update economy_config set award_mvp_coins=500; assert false, 'mvp cap loosened';
    exception when check_violation then null; end;
    begin update economy_config set award_coins=50; assert false, 'award cap loosened';
    exception when check_violation then null; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A1 ships off', sqlerrm);
  end;
end $$;

-- A2. Nothing before the public end ---------------------------------------------
do $$
declare p uuid[]; r uuid; s jsonb;
begin
  begin
    update economy_config set awards_enabled=true;
    p := pg_temp.ar_six();
    r := pg_temp.ar_town_win(p);
    -- Live: the room is still playing with every ballot and save on file.
    s := public.match_awards_get(p[4],r);
    assert s->'ready'='false'::jsonb and s->'awards'='[]'::jsonb, 'live: '||s::text;
    assert not public.compute_match_awards(r), 'computed live';
    -- Finished but still on the verdict: the result has not flipped the cards.
    update rooms set status='finished', ended_at=now() where id=r;
    assert not exists(select 1 from match_awards_computed where room_id=r), 'computed on verdict';
    s := public.match_awards_get(p[4],r);
    assert s->'ready'='false'::jsonb and s->'awards'='[]'::jsonb, 'verdict: '||s::text;
    assert not exists(select 1 from match_awards where room_id=r), 'rows before result';
    assert pg_temp.ar_balance(p[4])=0, 'coins before result';
    -- The result: computed by the trigger on the phase change.
    update room_state set phase='result' where room_id=r;
    assert exists(select 1 from match_awards_computed where room_id=r), 'trigger did not compute';
    -- A non-member reads nothing.
    s := public.match_awards_get(pg_temp.ar_user(),r);
    assert s->'ready'='false'::jsonb and s->'awards'='[]'::jsonb, 'stranger: '||s::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A2 nothing before end', sqlerrm);
  end;
end $$;

-- A3. Definitions on a town win ----------------------------------------------------
do $$
declare p uuid[]; r uuid;
begin
  begin
    update economy_config set awards_enabled=true;
    p := pg_temp.ar_six();
    r := pg_temp.ar_town_win(p);
    update rooms set status='finished', ended_at=now() where id=r;
    update room_state set phase='result' where room_id=r;
    assert pg_temp.ar_awardees(r,'sharp_eye')=array[p[4]], 'sharp_eye';
    assert pg_temp.ar_awardees(r,'first_blood')=array[p[4]], 'first_blood';
    assert pg_temp.ar_awardees(r,'silver_tongue')=array[p[4]], 'silver_tongue';
    assert pg_temp.ar_awardees(r,'lifesaver')=array[p[3]], 'lifesaver';
    assert pg_temp.ar_awardees(r,'perfect_crime')='{}', 'perfect_crime on a town win';
    assert pg_temp.ar_awardees(r,'survivor')=array[p[3],p[4],p[5],p[6]], 'survivor';
    -- doc, det and c1 tie on 8; the lowest seat (doc) wins.
    assert pg_temp.ar_awardees(r,'mvp')=array[p[3]], 'mvp';
    assert not exists(select 1 from match_awards where room_id=r and user_id in (p[1],p[2])),
      'the losing Mafia was awarded';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A3 town-win definitions', sqlerrm);
  end;
end $$;

-- A4. Perfect crime; kicked players are never awarded ----------------------------
do $$
declare p uuid[]; r uuid;
begin
  begin
    update economy_config set awards_enabled=true;
    p := pg_temp.ar_six();
    r := pg_temp.ar_room(p, array['mafia','mafia','doctor','detective','citizen','citizen'],
      'playing','vote');
    perform pg_temp.ar_vote(r,1,1,p[1],p[5],1);
    perform pg_temp.ar_vote(r,1,1,p[2],p[5],2);
    perform pg_temp.ar_vote(r,1,1,p[6],p[5],3);
    update room_players set alive=false where room_id=r and user_id in (p[4],p[5]);
    update room_players set alive=false, kicked=true where room_id=r and user_id=p[6];
    update room_state set public_data=jsonb_build_object('eliminations',
      jsonb_build_object('4',jsonb_build_object('phase','day','number',1),
                         '3',jsonb_build_object('phase','night','number',2)),
      'outcome','mafia') where room_id=r;
    update rooms set status='finished', ended_at=now() where id=r;
    update room_state set phase='result' where room_id=r;
    assert pg_temp.ar_awardees(r,'perfect_crime')=array[p[1],p[2]], 'perfect_crime';
    assert pg_temp.ar_awardees(r,'survivor')=array[p[1],p[2]], 'survivor';
    -- Both 2 (alive) + 2 (voted out c1): the lower seat.
    assert pg_temp.ar_awardees(r,'mvp')=array[p[1]], 'mvp';
    assert pg_temp.ar_awardees(r,'sharp_eye')='{}' and pg_temp.ar_awardees(r,'first_blood')='{}',
      'no correct ballots';
    assert not exists(select 1 from match_awards where room_id=r and user_id=p[6]), 'kicked awarded';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A4 perfect crime', sqlerrm);
  end;
end $$;

-- A5. The bonus: once per award, the caller's own only ---------------------------
do $$
declare p uuid[]; r uuid; s jsonb; bal bigint;
begin
  begin
    update economy_config set awards_enabled=true, award_mvp_coins=15, award_coins=5;
    p := pg_temp.ar_six();
    r := pg_temp.ar_town_win(p);
    update rooms set status='finished', ended_at=now() where id=r;
    update room_state set phase='result' where room_id=r;
    bal := pg_temp.ar_balance(p[4]);
    s := public.match_awards_get(p[4],r);
    assert s->'ready'='true'::jsonb and (s->>'granted')::int=20, 'det: '||s::text;
    assert s->'mine'='["first_blood","sharp_eye","silver_tongue","survivor"]'::jsonb, s::text;
    assert jsonb_array_length(s->'awards')=6, 'award groups: '||s::text;
    assert s->'awards'->0->>'code'='mvp' and s->'awards'->0->'seats'='[2]'::jsonb, s::text;
    assert pg_temp.ar_balance(p[4])=bal+20, 'balance';
    s := public.match_awards_get(p[4],r);
    assert (s->>'granted')::int=0 and pg_temp.ar_balance(p[4])=bal+20, 'replay paid again';
    s := public.match_awards_get(p[3],r);
    assert (s->>'granted')::int=25, 'doc: '||s::text;
    -- Reading pays nobody else.
    assert pg_temp.ar_balance(p[5])=0, 'c1 paid by others reading';
    assert (select count(*) from wallet_ledger where kind='match_award' and source_room=r)=2,
      'ledger rows';
    -- Coins set to zero pay nothing, and the awards still show.
    update economy_config set award_coins=0;
    s := public.match_awards_get(p[6],r);
    assert (s->>'granted')::int=0 and s->'mine'='["survivor"]'::jsonb, 'zero coins: '||s::text;
    -- Off again: the read says so; nothing more is paid.
    update economy_config set awards_enabled=false, award_coins=5;
    assert public.match_awards_get(p[5],r)='{"enabled":false}'::jsonb, 'read after off';
    assert pg_temp.ar_balance(p[5])=0, 'paid while off';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A5 idempotent bonus', sqlerrm);
  end;
end $$;

-- A6. Reactions: lobby and result only ------------------------------------------
do $$
declare p uuid[]; r uuid; ph text; s jsonb; stranger uuid;
begin
  begin
    update economy_config set reactions_enabled=true;
    p := pg_temp.ar_six();
    r := pg_temp.ar_room(p, array[null,null,null,null,null,null]::text[], 'lobby','lobby');
    s := public.send_room_reaction(p[2],r,'rose');
    assert s->>'seat'='1' and s->>'kind'='rose', s::text;
    update rooms set status='playing' where id=r;
    foreach ph in array array['reveal','night','morning','confront','discuss','defense','vote'] loop
      update room_state set phase=ph where room_id=r;
      begin perform public.send_room_reaction(p[3],r,'laugh'); assert false, 'reacted in '||ph;
      exception when others then assert sqlerrm='REACTION_CLOSED', ph||': '||sqlerrm; end;
    end loop;
    -- Finished, but the cards have not flipped yet.
    update rooms set status='finished', ended_at=now() where id=r;
    update room_state set phase='vote', public_data='{"outcome":"town"}' where room_id=r;
    begin perform public.send_room_reaction(p[3],r,'laugh'); assert false, 'before result';
    exception when others then assert sqlerrm='REACTION_CLOSED', 'pre-result: '||sqlerrm; end;
    update room_state set phase='result' where room_id=r;
    perform public.send_room_reaction(p[3],r,'crown');
    stranger := pg_temp.ar_user();
    begin perform public.send_room_reaction(stranger,r,'laugh'); assert false, 'stranger';
    exception when others then assert sqlerrm='NOT_MEMBER', 'stranger: '||sqlerrm; end;
    update room_players set kicked=true where room_id=r and user_id=p[6];
    begin perform public.send_room_reaction(p[6],r,'laugh'); assert false, 'kicked';
    exception when others then assert sqlerrm='NOT_MEMBER', 'kicked: '||sqlerrm; end;
    begin perform public.send_room_reaction(p[3],r,'fireworks'); assert false, 'unknown kind';
    exception when others then assert sqlerrm='REACTION_UNKNOWN', 'kind: '||sqlerrm; end;
    assert (select count(*) from room_reactions where room_id=r)=2, 'rows';
    -- Clients read seats, never user ids.
    assert not has_column_privilege('authenticated','public.room_reactions','user_id','select'),
      'user_id readable';
    assert not has_table_privilege('authenticated','public.room_reactions','insert'), 'insertable';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A6 reactions gated', sqlerrm);
  end;
end $$;

-- A7. Reaction rate limit ------------------------------------------------------------
do $$
declare p uuid[]; r uuid;
begin
  begin
    update economy_config set reactions_enabled=true;
    p := pg_temp.ar_six();
    r := pg_temp.ar_room(p, array[null,null,null,null,null,null]::text[], 'lobby','lobby');
    perform public.send_room_reaction(p[1],r,'laugh');
    perform public.send_room_reaction(p[1],r,'shock');
    perform public.send_room_reaction(p[1],r,'skull');
    begin perform public.send_room_reaction(p[1],r,'coffee'); assert false, 'burst of 4';
    exception when others then assert sqlerrm='REACTION_RATE_LIMIT', 'limit: '||sqlerrm; end;
    -- Another player is not limited by the first.
    perform public.send_room_reaction(p[2],r,'applause');
    -- Once the window has passed, the first may react again.
    update room_reactions set created_at=created_at - interval '5 seconds'
     where room_id=r and user_id=p[1];
    perform public.send_room_reaction(p[1],r,'coffee');
    assert (select count(*) from room_reactions where room_id=r and user_id=p[1])=4, 'count';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A7 rate limit', sqlerrm);
  end;
end $$;

-- A8. Founder badge window ------------------------------------------------------------
do $$
declare p uuid[]; r uuid; q uuid; s jsonb;
begin
  begin
    p := pg_temp.ar_six();
    r := pg_temp.ar_room(p, array['mafia','mafia','doctor','detective','citizen','citizen'],
      'finished','result','{"outcome":"town"}');
    -- Flag on without a window start: still off.
    update economy_config set founder_enabled=true;
    assert public.fun_profile(p[1])->'badges'='[]'::jsonb, 'no window start';
    -- A window that starts after the match.
    update economy_config set founder_window_start=now() + interval '1 day';
    assert public.fun_profile(p[1])->'badges'='[]'::jsonb, 'future window';
    -- A window that closed before the match.
    update economy_config set founder_window_start=now() - interval '40 days', founder_window_days=30;
    assert public.fun_profile(p[1])->'badges'='[]'::jsonb, 'closed window';
    -- Inside the window.
    update economy_config set founder_window_start=now() - interval '1 day';
    s := public.fun_profile(p[1]);
    assert s->'badges'='["founder"]'::jsonb and s->'founder'->'enabled'='true'::jsonb, s::text;
    -- Live matches do not count.
    q := pg_temp.ar_user();
    perform pg_temp.ar_room(array[q], array['citizen'], 'playing','night');
    assert public.fun_profile(q)->'badges'='[]'::jsonb, 'live match counted';
    -- The badge is permanent: it outlives the flag.
    update economy_config set founder_enabled=false;
    assert public.fun_profile(p[1])->'badges'='["founder"]'::jsonb, 'badge lost';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A8 founder window', sqlerrm);
  end;
end $$;

-- A9. Clients cannot reach the new surface directly -----------------------------------
do $$
begin
  begin
    assert not has_function_privilege('authenticated','public.match_awards_get(uuid,uuid)','execute'), 'awards rpc';
    assert not has_function_privilege('anon','public.send_room_reaction(uuid,uuid,text)','execute'), 'react rpc';
    assert not has_function_privilege('authenticated','public.compute_match_awards(uuid)','execute'), 'compute rpc';
    assert not has_function_privilege('authenticated','public.fun_profile(uuid)','execute'), 'profile rpc';
    assert not has_table_privilege('authenticated','public.match_awards','select'), 'awards table';
    assert not has_table_privilege('authenticated','public.player_badges','select'), 'badges table';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A9 grants', sqlerrm);
  end;
end $$;

-- A10. Reactions do not outlive their sender, or a day ---------------------------
do $$
declare p uuid[]; r uuid; req uuid; ghost uuid := gen_random_uuid(); n int;
begin
  begin
    update economy_config set reactions_enabled=true;
    p := pg_temp.ar_six();
    r := pg_temp.ar_room(p, array[null,null,null,null,null,null]::text[], 'lobby','lobby');
    perform public.send_room_reaction(p[1],r,'laugh');
    perform public.send_room_reaction(p[2],r,'rose');
    -- p[1] leaves the lobby: the room (and its reactions) stays for the rest.
    delete from room_players where room_id=r and user_id=p[1];
    insert into player_badges(user_id,badge) values(p[1],'founder');
    insert into data_deletion_requests(user_id) values(p[1]) returning id into req;
    perform public.complete_data_deletion(req);
    assert not exists(select 1 from room_reactions where user_id=p[1]), 'reaction survived deletion';
    assert not exists(select 1 from player_badges where user_id=p[1]), 'badge survived deletion';
    assert exists(select 1 from room_reactions where user_id=p[2]), 'deletion took another one';
    assert (select completed_at is not null from data_deletion_requests where id=req), 'not completed';
    -- An orphaned identity's reactions go with the orphan purge.
    insert into room_reactions(room_id,user_id,seat,kind) values(r,ghost,5,'skull');
    perform public.purge_orphan_economy();
    assert not exists(select 1 from room_reactions where user_id=ghost), 'orphan kept';
    assert exists(select 1 from room_reactions where user_id=p[2]), 'orphan purge took a live one';
    -- The periodic purge: older than a day only.
    -- (Sent first: every send trims its own room to ten minutes.)
    perform public.send_room_reaction(p[3],r,'crown');
    update room_reactions set created_at=now() - interval '25 hours' where user_id=p[2];
    n := public.purge_room_reactions();
    assert n=1, 'purged '||n;
    assert not exists(select 1 from room_reactions where user_id=p[2]), 'day-old kept';
    assert exists(select 1 from room_reactions where user_id=p[3]), 'fresh purged';
    assert not has_function_privilege('authenticated','public.purge_room_reactions()','execute'), 'purge rpc';
    assert not has_function_privilege('anon','public.purge_room_reactions()','execute'), 'purge rpc anon';
    assert has_function_privilege('service_role','public.purge_room_reactions()','execute'), 'purge service';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.ar_record('A10 reaction retention', sqlerrm);
  end;
end $$;

-- Report ----------------------------------------------------------------
do $$
declare failed text;
begin
  select string_agg(gate||' => '||detail, ' | ' order by gate) into failed
    from ar_results where not ok;
  if (select count(*) from ar_results) <> 10 then
    raise exception 'AWARDS GATES INCOMPLETE: % recorded', (select count(*) from ar_results);
  end if;
  if failed is not null then raise exception 'AWARDS GATES FAILED: %', failed; end if;
end $$;
rollback;
