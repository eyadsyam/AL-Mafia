-- Independent adversarial regressions for 20260925000300_council_life
-- (docs/PHASE-107-SECURITY-REVIEW.md). Rolled back.
--
-- Every gate runs in its own subtransaction and is rolled back on exit, so a
-- failing gate never masks or feeds the next. Failures are collected and
-- reported together at the end. Assertions encode the required behaviour;
-- they are not loosened to match an implementation.
--
-- Single connection (PGlite): proves logic, idempotency, guards and
-- conservation, NOT hosted lock ordering under concurrency.
begin;

-- Hosted auth.users has created_at; the local harness does not.
alter table auth.users add column if not exists created_at timestamptz not null default now();

create temp table cs_results(gate text primary key, ok boolean not null, detail text);

create function pg_temp.cs_record(p_gate text, p_err text) returns void
language sql as $$
  insert into cs_results values(p_gate, p_err='GATE_OK', nullif(p_err,'GATE_OK'))
$$;

create function pg_temp.cs_user(p_age interval default '1 hour') returns uuid
language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous,created_at)
    values(u, u::text||'@example.test', now(), false, now()-p_age);
  return u;
end $$;

create function pg_temp.cs_code() returns text language plpgsql as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; c text := ''; i int;
begin
  for i in 1..6 loop c := c || substr(a, public.secure_random_below(32)+1, 1); end loop;
  return c;
end $$;

-- A room: finished with p_outcome at p_ended, or 'playing' when p_outcome is
-- null and p_status is null. Rewards are synced through the real path.
create function pg_temp.cs_room(p_host uuid, p_players uuid[], p_roles text[],
  p_outcome text, p_ended timestamptz default now(), p_names text[] default null,
  p_status text default null) returns uuid language plpgsql as $$
declare r uuid := gen_random_uuid(); i int;
  st text := coalesce(p_status, case when p_outcome is null then 'playing' else 'finished' end);
begin
  insert into rooms(id,code,host_id,status,ended_at,match_seed)
    values(r,pg_temp.cs_code(),p_host,st,case when st='finished' then p_ended end,1);
  for i in 1..array_length(p_players,1) loop
    insert into room_players(room_id,user_id,seat,name,role,kicked)
      values(r,p_players[i],i-1,coalesce(p_names[i],'Player '||i),p_roles[i],false);
  end loop;
  insert into room_state(room_id,phase,phase_number,public_data)
    values(r,case when st='finished' then 'result' else 'night' end,1,
      case when p_outcome is null then '{}'::jsonb else jsonb_build_object('outcome',p_outcome) end);
  if st='finished' then
    for i in 1..array_length(p_players,1) loop
      perform public.sync_player_rewards(p_players[i]);
    end loop;
  end if;
  return r;
end $$;

-- One finished town win, hosted by p_user alone.
create function pg_temp.cs_match(p_user uuid, p_ended timestamptz default now()) returns uuid
language sql as $$
  select pg_temp.cs_room(p_user, array[p_user], array['citizen'], 'town', p_ended)
$$;

create function pg_temp.cs_enable() returns void language sql as $$
  update economy_config set council_contracts_enabled=true, council_rank_enabled=true,
    council_leaderboard_enabled=true, council_invites_enabled=true, starter_bundle_enabled=true,
    ad_steps_enabled=true, daily_enabled=true, daily_ad_enabled=true;
$$;

create function pg_temp.cs_delete(p_user uuid) returns void language plpgsql as $$
declare req uuid;
begin
  insert into data_deletion_requests(user_id) values(p_user) returning id into req;
  perform public.complete_data_deletion(req);
end $$;

create function pg_temp.cs_ledger(p_user uuid, p_kind text) returns bigint
language sql as $$
  select coalesce(sum(amount),0)::bigint from wallet_ledger where user_id=p_user and kind=p_kind
$$;

-- L1. Invite cap survives the invitee's account deletion --------------------
-- Design: "the inviter is paid at most 20 times". Deleting a paid invitee
-- must not give the inviter the slot back.
do $$
declare i uuid; n1 uuid; n2 uuid; code text;
begin
  begin
    perform pg_temp.cs_enable();
    update economy_config set council_invite_cap=1;
    i := pg_temp.cs_user('30 days'); n1 := pg_temp.cs_user(); n2 := pg_temp.cs_user();
    code := public.council_invite(i)->>'code';
    perform public.redeem_council_invite(n1, code);
    perform pg_temp.cs_match(n1);
    perform public.council_invite(n1);
    assert pg_temp.cs_ledger(i,'council_invite_inviter')=100, 'fixture: first invite not paid';
    perform pg_temp.cs_delete(n1);
    begin perform public.redeem_council_invite(n2, code); exception when others then null; end;
    begin
      perform pg_temp.cs_match(n2);
      perform public.council_invite(n2);
      perform public.council_invite(i);
    exception when others then null; end;
    assert pg_temp.cs_ledger(i,'council_invite_inviter')=100,
      'inviter paid past cap after invitee deletion: '||pg_temp.cs_ledger(i,'council_invite_inviter');
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L1 invite cap survives invitee deletion', sqlerrm);
  end;
end $$;

-- L2. Invite cap survives orphan purge -----------------------------------------
do $$
declare i uuid; n1 uuid; n2 uuid; code text;
begin
  begin
    perform pg_temp.cs_enable();
    update economy_config set council_invite_cap=1;
    i := pg_temp.cs_user('30 days'); n1 := pg_temp.cs_user(); n2 := pg_temp.cs_user();
    code := public.council_invite(i)->>'code';
    perform public.redeem_council_invite(n1, code);
    perform pg_temp.cs_match(n1);
    perform public.council_invite(n1);
    delete from rooms where id in (select room_id from room_players where user_id=n1);
    delete from auth.users where id=n1;
    perform public.purge_orphan_economy();
    begin perform public.redeem_council_invite(n2, code); exception when others then null; end;
    begin
      perform pg_temp.cs_match(n2);
      perform public.council_invite(n2);
    exception when others then null; end;
    assert pg_temp.cs_ledger(i,'council_invite_inviter')=100,
      'inviter paid past cap after orphan purge: '||pg_temp.cs_ledger(i,'council_invite_inviter');
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L2 invite cap survives orphan purge', sqlerrm);
  end;
end $$;

-- L3. Invite guards, replay and code guessing ---------------------------------
do $$
declare i uuid; j uuid; n1 uuid; n4 uuid; n5 uuid; n6 uuid; old uuid; played uuid;
  code text; jcode text; s jsonb; k int;
begin
  begin
    perform pg_temp.cs_enable();
    i := pg_temp.cs_user('30 days'); j := pg_temp.cs_user('30 days');
    n1 := pg_temp.cs_user(); n4 := pg_temp.cs_user(); n5 := pg_temp.cs_user();
    n6 := pg_temp.cs_user(); old := pg_temp.cs_user('8 days'); played := pg_temp.cs_user();
    code := public.council_invite(i)->>'code'; jcode := public.council_invite(j)->>'code';

    begin perform public.redeem_council_invite(n1, public.council_invite(n1)->>'code');
      assert false, 'own code accepted';
    exception when others then assert sqlerrm='INVITE_SELF', 'self: '||sqlerrm; end;
    begin perform public.redeem_council_invite(old, code); assert false, 'old account accepted';
    exception when others then assert sqlerrm='INVITE_EXPIRED', 'old: '||sqlerrm; end;
    perform pg_temp.cs_match(played);
    begin perform public.redeem_council_invite(played, code); assert false, 'played account accepted';
    exception when others then assert sqlerrm='INVITE_NOT_NEW', 'played: '||sqlerrm; end;

    s := public.redeem_council_invite(n1, code);
    assert s->>'status'='redeemed', s::text;
    s := public.redeem_council_invite(n1, lower(code));  -- retry
    assert s->>'status'='redeemed', 'retry: '||s::text;
    begin perform public.redeem_council_invite(n1, jcode); assert false, 'second code accepted';
    exception when others then assert sqlerrm='INVITE_ALREADY', 'second: '||sqlerrm; end;

    -- Nobody is paid before the invitee finishes a match.
    perform public.council_invite(i); perform public.council_invite(n1);
    assert pg_temp.cs_ledger(i,'council_invite_inviter')=0 and pg_temp.cs_ledger(n1,'council_invite_invitee')=0,
      'paid before invitee match';
    perform pg_temp.cs_match(n1);
    perform public.council_invite(n1); perform public.council_invite(i);
    perform public.council_contracts(i); perform public.council_rank(n1);
    assert pg_temp.cs_ledger(i,'council_invite_inviter')=100, 'inviter not paid exactly once';
    assert pg_temp.cs_ledger(n1,'council_invite_invitee')=50, 'invitee not paid exactly once';

    -- Mutual invites between two new accounts.
    perform public.redeem_council_invite(n4, public.council_invite(n5)->>'code');
    begin perform public.redeem_council_invite(n5, public.council_invite(n4)->>'code');
      assert false, 'invite loop accepted';
    exception when others then assert sqlerrm='INVITE_LOOP', 'loop: '||sqlerrm; end;

    -- Guessing: ten unknown codes, then even a real code is refused today.
    for k in 1..10 loop
      s := public.redeem_council_invite(n6, 'Q'||lpad(k::text,6,'X'));
      assert s->>'status'='not_found', 'guess '||k||': '||s::text;
    end loop;
    begin perform public.redeem_council_invite(n6, code); assert false, 'rate limit bypassed';
    exception when others then assert sqlerrm='INVITE_RATE_LIMIT', 'rate: '||sqlerrm; end;
    assert not exists(select 1 from council_invite_redemptions where invitee=n6), 'rate-limited redemption stored';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L3 invite guards, replay, guessing', sqlerrm);
  end;
end $$;

-- L4. Daily contracts: replay and day boundary --------------------------------
do $$
declare u uuid; v uuid; today date := public.economy_today(); s jsonb; bal bigint; k int;
begin
  begin
    perform pg_temp.cs_enable();
    -- Three groups a single hosted town win completes.
    update council_contract_catalog set active = code in ('finish_1','finish_town','host_1');
    u := pg_temp.cs_user(); v := pg_temp.cs_user();
    perform public.council_contracts(u);
    begin perform public.claim_council_contract(u,null,0); assert false, 'null day';
    exception when others then assert sqlerrm='DAY_REQUIRED', 'null day: '||sqlerrm; end;
    begin perform public.claim_council_contract(u,today-1,0); assert false, 'yesterday';
    exception when others then assert sqlerrm='DAY_CHANGED', 'yesterday: '||sqlerrm; end;
    begin perform public.claim_council_contract(u,today+1,0); assert false, 'tomorrow';
    exception when others then assert sqlerrm='DAY_CHANGED', 'tomorrow: '||sqlerrm; end;
    begin perform public.claim_council_contract(u,today,3); assert false, 'slot 3';
    exception when others then assert sqlerrm='BAD_REQUEST', 'slot: '||sqlerrm; end;
    begin perform public.claim_council_contract(u,today,0); assert false, 'claimed before any match';
    exception when others then assert sqlerrm='CONTRACT_INCOMPLETE', 'incomplete: '||sqlerrm; end;

    perform pg_temp.cs_match(u);
    bal := (select balance from wallet_accounts where user_id=u);
    for k in 0..2 loop
      perform public.claim_council_contract(u,today,k);
      s := public.claim_council_contract(u,today,k);
      assert (s->>'granted')::bigint=0 and (s->>'bonusGranted')::bigint=0, 'replay paid: '||s::text;
    end loop;
    assert (select count(*) from wallet_ledger where user_id=u and kind='council_contract')=3, 'contract rows';
    assert (select count(*) from wallet_ledger where user_id=u and kind='council_contract_bonus')=1, 'bonus rows';
    assert (select balance from wallet_accounts where user_id=u)=bal+15+25+25+30,
      'contract coins: '||((select balance from wallet_accounts where user_id=u)-bal);

    -- A match that ended yesterday does not complete today's contract.
    perform pg_temp.cs_match(v, now()-interval '1 day');
    begin perform public.claim_council_contract(v,today,0); assert false, 'yesterday match counted';
    exception when others then assert sqlerrm='CONTRACT_INCOMPLETE', 'yesterday match: '||sqlerrm; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L4 contracts replay + day boundary', sqlerrm);
  end;
end $$;

-- L5. Weekly contract: replay and week boundary --------------------------------
do $$
declare u uuid; wk text := public.council_week(public.economy_today()); s jsonb;
begin
  begin
    perform pg_temp.cs_enable();
    update economy_config set council_weekly_target=1;
    u := pg_temp.cs_user();
    begin perform public.claim_council_weekly(u,null); assert false, 'null week';
    exception when others then assert sqlerrm='WEEK_REQUIRED', 'null week: '||sqlerrm; end;
    begin perform public.claim_council_weekly(u,public.council_week(public.economy_today()-7));
      assert false, 'last week';
    exception when others then assert sqlerrm='WEEK_CHANGED', 'last week: '||sqlerrm; end;
    begin perform public.claim_council_weekly(u,wk); assert false, 'weekly before match';
    exception when others then assert sqlerrm='CONTRACT_INCOMPLETE', 'incomplete: '||sqlerrm; end;
    perform pg_temp.cs_match(u);
    s := public.claim_council_weekly(u,wk);
    assert (s->>'granted')::bigint=150 and (s->>'xpGranted')::int=150, s::text;
    s := public.claim_council_weekly(u,wk);
    assert (s->>'granted')::bigint=0 and (s->>'xpGranted')::int=0, 'weekly replay: '||s::text;
    assert (select count(*) from wallet_ledger where user_id=u and kind='council_weekly')=1, 'weekly rows';
    assert (select count(*) from council_xp_events where user_id=u and source_key like 'weekly:%')=1, 'weekly xp rows';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L5 weekly replay + week boundary', sqlerrm);
  end;
end $$;

-- L6. XP is granted once per match, capped per day; level coins once ----------
do $$
declare u uuid; u2 uuid; u3 uuid; k int;
begin
  begin
    perform pg_temp.cs_enable();
    u := pg_temp.cs_user(); u2 := pg_temp.cs_user(); u3 := pg_temp.cs_user();
    perform pg_temp.cs_match(u); perform pg_temp.cs_match(u);
    for k in 1..3 loop
      perform public.council_sync(u); perform public.sync_player_rewards(u);
      perform public.council_rank(u); perform public.council_contracts(u);
    end loop;
    assert (public.council_rank(u)->>'xp')::bigint=100, 'xp: '||(public.council_rank(u)->>'xp');
    assert (select count(*) from wallet_ledger where user_id=u and kind='council_level')=1
       and pg_temp.cs_ledger(u,'council_level')=25, 'level coins not exactly once';

    -- A record pruned after 21 days is never re-granted while its room lives.
    perform pg_temp.cs_match(u2, now()-interval '30 days');
    for k in 1..3 loop perform public.council_sync(u2); perform public.council_rank(u2); end loop;
    assert (select count(*) from council_xp_events where user_id=u2)<=1, 'old match xp twice';
    assert coalesce((select sum(xp) from council_xp_events where user_id=u2),0)<=50, 'old match xp > one grant';

    update economy_config set council_xp_daily_matches=1;
    perform pg_temp.cs_match(u3); perform pg_temp.cs_match(u3);
    perform public.council_sync(u3);
    assert (public.council_rank(u3)->>'xp')::bigint=50, 'daily xp cap: '||(public.council_rank(u3)->>'xp');
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L6 xp once, capped, level coins once', sqlerrm);
  end;
end $$;

-- L7. Live, kicked, abandoned and outcome-less rooms never count ---------------
do $$
declare u uuid; o uuid; r uuid;
begin
  begin
    perform pg_temp.cs_enable();
    u := pg_temp.cs_user(); o := pg_temp.cs_user();
    perform pg_temp.cs_room(u, array[u,o], array['citizen','mafia'], null);            -- live
    perform pg_temp.cs_room(u, array[u], array['citizen'], null, now(), null, 'finished'); -- no outcome
    perform pg_temp.cs_room(u, array[u], array['citizen'], 'abandoned');
    r := gen_random_uuid();
    insert into rooms(id,code,host_id,status,ended_at,match_seed) values(r,pg_temp.cs_code(),o,'finished',now(),1);
    insert into room_players(room_id,user_id,seat,name,role,kicked) values
      (r,o,0,'O','mafia',false),(r,u,1,'U','citizen',true);
    insert into room_state(room_id,phase,phase_number,public_data)
      values(r,'result',1,jsonb_build_object('outcome','town'));
    perform public.sync_player_rewards(u);
    perform public.council_contracts(u); perform public.council_rank(u);
    perform public.council_leaderboard(u); perform public.council_sync(u);
    assert not exists(select 1 from council_match_records where user_id=u), 'ineligible room recorded';
    assert not exists(select 1 from council_xp_events where user_id=u), 'ineligible room gave xp';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L7 ineligible rooms never count', sqlerrm);
  end;
end $$;

-- L8. Doc 05: dealing roles in a live room changes no Council read -------------
do $$
declare a uuid; b uuid; c uuid; live uuid; before_a jsonb; before_b jsonb; after_a jsonb; after_b jsonb;
begin
  begin
    perform pg_temp.cs_enable();
    a := pg_temp.cs_user(); b := pg_temp.cs_user(); c := pg_temp.cs_user();
    perform pg_temp.cs_room(a, array[a,b,c], array['citizen','mafia','citizen'], 'town');
    live := pg_temp.cs_room(a, array[a,b,c], array[null,null,null]::text[], null);
    create function pg_temp.cs_reads(p uuid) returns jsonb language sql as $f$
      select jsonb_build_object('c',public.council_contracts(p),'r',public.council_rank(p),
        'l',public.council_leaderboard(p),'i',public.council_invite(p),
        'cap',public.economy_capabilities(p))
    $f$;
    perform pg_temp.cs_reads(a); perform pg_temp.cs_reads(b);   -- warm-up (invite codes)
    before_a := pg_temp.cs_reads(a); before_b := pg_temp.cs_reads(b);
    update room_players set role = case seat when 1 then 'mafia' else 'citizen' end where room_id=live;
    after_a := pg_temp.cs_reads(a); after_b := pg_temp.cs_reads(b);
    assert before_a=after_a, 'reads changed for a town player when roles were dealt';
    assert before_b=after_b, 'reads changed for the mafia player when roles were dealt';
    assert not exists(select 1 from council_match_records where room_id=live), 'live room recorded';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L8 Doc 05 live-room reads invariant', sqlerrm);
  end;
end $$;

-- L9. Leaderboard carries no ids, roles or teams; blocks hide both ways -------
do $$
declare a uuid; b uuid; c uuid; s jsonb; t text; e jsonb; k text;
begin
  begin
    perform pg_temp.cs_enable();
    a := pg_temp.cs_user(); b := pg_temp.cs_user(); c := pg_temp.cs_user();
    perform pg_temp.cs_room(a, array[a,b,c], array['citizen','mafia','doctor'], 'mafia', now(),
      array['Alpha','Bravo','Charlie']);
    perform public.council_sync(a); perform public.council_sync(b); perform public.council_sync(c);
    s := public.council_leaderboard(a); t := s::text;
    assert jsonb_array_length(s->'entries')=3, 'fixture: board size '||t;
    assert t !~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 'uuid in leaderboard';
    for e in select * from jsonb_array_elements(s->'entries') loop
      for k in select jsonb_object_keys(e) loop
        assert k in ('position','xp','name','gender','frame','me','level','tier','titleAr','titleEn'),
          'unexpected leaderboard key '||k;
      end loop;
    end loop;
    assert t !~* '"(role|team|won|room|userId|user_id|mafia|doctor|citizen|town)"', 'role/team in leaderboard: '||t;
    insert into player_blocks(blocker_id,blocked_id) values(a,b);
    assert not public.council_leaderboard(a)::text like '%Bravo%', 'blocked player visible to blocker';
    assert not public.council_leaderboard(b)::text like '%Alpha%', 'blocker visible to blocked player';
    assert public.council_leaderboard(c)::text like '%Alpha%', 'third party lost a row';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L9 leaderboard shape and blocks', sqlerrm);
  end;
end $$;

-- L10. Starter Bundle: once per account, void-final, debt-conserving ----------
do $$
declare u uuid; v uuid; x uuid; y uuid; tag text; s jsonb; w public.wallet_accounts; bal bigint;
begin
  begin
    perform pg_temp.cs_enable();
    u := pg_temp.cs_user(); v := pg_temp.cs_user(); x := pg_temp.cs_user(); y := pg_temp.cs_user();
    tag := public.account_tag(u);
    begin perform public.commit_play_product(u,'cs-l10-untagged','mm_starter_bundle','GPA.L10N','active',now(),1,null);
    exception when others then null; end;
    assert not exists(select 1 from player_inventory where user_id=u and item_code='frame_council_seal'),
      'untagged bundle granted';
    s := public.commit_play_product(u,'cs-l10-token-1','mm_starter_bundle','GPA.L10.1','active',now(),1,tag);
    assert (s->>'credited')::bigint=600, 'bundle credit: '||s::text;
    bal := (select balance from wallet_accounts where user_id=u);
    perform public.commit_play_product(u,'cs-l10-token-1','mm_starter_bundle','GPA.L10.1','active',now(),1,tag);
    s := public.commit_play_product(u,'cs-l10-token-2','mm_starter_bundle','GPA.L10.2','active',now(),1,tag);
    assert coalesce((s->>'alreadyOwned')::boolean,false) and not coalesce((s->>'needsAcknowledge')::boolean,false),
      'second bundle not refused: '||s::text;
    assert (select balance from wallet_accounts where user_id=u)=bal, 'bundle paid twice';
    assert (select count(*) from wallet_ledger where user_id=u and kind='play_coin_purchase')=1, 'two bundle ledgers';
    begin perform public.buy_reward_item(u,'frame_council_seal'); assert false, 'bundle frame sold for coins';
    exception when assert_failure then raise; when others then null; end;

    -- Debt conservation and cosmetic removal (v): debt 500, bundle 600 ->
    -- offset 500 credit 100; void -> takes 100, debt back to 500, frame gone.
    perform public.commit_play_product(v,'cs-l10-coins-v','mm_coins_500','GPA.L10.V1','active',now(),1,public.account_tag(v));
    update wallet_accounts set balance=balance-500, purchased_balance=purchased_balance-500 where user_id=v;
    perform public.revoke_voided_play_purchases(array['cs-l10-coins-v'],null);
    assert (select purchase_debt from wallet_accounts where user_id=v)=500, 'fixture debt';
    s := public.commit_play_product(v,'cs-l10-bundle-v','mm_starter_bundle','GPA.L10.V2','active',now(),1,public.account_tag(v));
    w := (select a from wallet_accounts a where user_id=v);
    assert (s->>'credited')::bigint=100 and w.purchase_debt=0 and w.purchased_balance=100, 'bundle offset: '||row_to_json(w)::text;
    insert into player_equipment(user_id,slot,item_code) values(v,'frame','frame_council_seal');
    perform public.revoke_voided_play_purchases(array['cs-l10-bundle-v'],null);
    w := (select a from wallet_accounts a where user_id=v);
    assert w.purchase_debt=500 and w.purchased_balance=0, 'bundle refund debt: '||row_to_json(w)::text;
    assert not exists(select 1 from player_inventory where user_id=v and item_code='frame_council_seal'), 'frame kept after void';
    assert not exists(select 1 from player_equipment where user_id=v and item_code='frame_council_seal'), 'frame still equipped';
    perform public.commit_play_product(v,'cs-l10-bundle-v','mm_starter_bundle','GPA.L10.V2','active',now(),1,public.account_tag(v));
    assert not exists(select 1 from player_inventory where user_id=v and item_code='frame_council_seal'), 'voided bundle regranted';
    assert (select purchase_debt from wallet_accounts where user_id=v)=500, 'voided bundle replay moved debt';

    -- pending -> void -> active, and void before first verify.
    perform public.commit_play_product(x,'cs-l10-pending-x','mm_starter_bundle','GPA.L10.X','pending',now(),1,public.account_tag(x));
    perform public.revoke_voided_play_purchases(array['cs-l10-pending-x'],null);
    perform public.commit_play_product(x,'cs-l10-pending-x','mm_starter_bundle','GPA.L10.X','active',now(),1,public.account_tag(x));
    perform public.revoke_voided_play_purchases(array['cs-l10-early-y'],null);
    perform public.commit_play_product(y,'cs-l10-early-y','mm_starter_bundle','GPA.L10.Y','active',now(),1,public.account_tag(y));
    assert not exists(select 1 from player_inventory where user_id in (x,y) and item_code='frame_council_seal'),
      'voided bundle granted';
    assert coalesce((select sum(balance) from wallet_accounts where user_id in (x,y)),0)=0, 'voided bundle credited';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L10 starter bundle', sqlerrm);
  end;
end $$;

-- L11. No client execute; definer functions pin search_path; tables closed ----
do $$
declare f record; t record; bad text := '';
begin
  begin
    for f in
      select p.oid::regprocedure::text as sig, p.prosecdef, p.proconfig
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and (p.proname like 'council\_%' or p.proname like '%\_base' or p.proname in (
         'redeem_council_invite','claim_council_contract','claim_council_weekly',
         'owns_starter_bundle','reverse_play_bundle','commit_play_bundle','commit_play_product',
         'revoke_voided_play_purchases','economy_capabilities','complete_data_deletion',
         'purge_orphan_economy','reverse_play_coins','play_is_voided','credit_earned'))
    loop
      if has_function_privilege('anon',f.sig,'execute')
         or has_function_privilege('authenticated',f.sig,'execute') then
        bad := bad||' exec:'||f.sig;
      end if;
      if f.prosecdef and not exists(select 1 from unnest(coalesce(f.proconfig,'{}')) c
                                     where c like 'search_path=%') then
        bad := bad||' search_path:'||f.sig;
      end if;
    end loop;
    for t in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
              where n.nspname='public' and c.relkind='r' and c.relname like 'council\_%' loop
      if has_table_privilege('anon','public.'||t.relname,'select,insert,update,delete')
         or has_table_privilege('authenticated','public.'||t.relname,'select,insert,update,delete') then
        bad := bad||' table:'||t.relname;
      end if;
      if not (select relrowsecurity from pg_class where oid=('public.'||t.relname)::regclass) then
        bad := bad||' rls:'||t.relname;
      end if;
    end loop;
    assert bad='', 'exposed:'||bad;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L11 grants, search_path, RLS', sqlerrm);
  end;
end $$;

-- L12. Every earlier ledger kind still writes; unknown kinds still refused -----
do $$
declare u uuid := gen_random_uuid(); k text; bad text := '';
begin
  begin
    foreach k in array array['match_completion','match_win','catalog_spend','operator_adjustment',
        'ad_reward','purchase','catalog_refund','coin_purchase','coin_purchase_reversal',
        'ad_step_1','ad_step_2','daily_coffer','daily_wheel','daily_week_bonus','daily_ad',
        'play_coin_purchase','play_coin_reversal','council_contract','council_contract_bonus',
        'council_weekly','council_level','council_invite_inviter','council_invite_invitee'] loop
      begin
        insert into wallet_ledger(user_id,kind,amount,source_key) values(u,k,1,'cs-l12-'||k);
      exception when others then bad := bad||' '||k||'('||sqlerrm||')'; end;
    end loop;
    assert bad='', 'kinds refused:'||bad;
    begin insert into wallet_ledger(user_id,kind,amount) values(u,'free_money',1); assert false, 'unknown kind accepted';
    exception when check_violation then null; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L12 ledger kinds preserved', sqlerrm);
  end;
end $$;

-- L13. Deletion keeps every earlier behaviour and covers the new records -----
do $$
declare w uuid; o uuid; n uuid; admin uuid; a uuid; b uuid; r1 uuid; r2 uuid; s jsonb;
  ord uuid; tombs int; today date := public.economy_today(); t text; bad text := ''; left_over boolean;
begin
  begin
    perform pg_temp.cs_enable();
    w := pg_temp.cs_user('30 days'); o := pg_temp.cs_user(); n := pg_temp.cs_user();
    admin := pg_temp.cs_user(); a := pg_temp.cs_user(); b := pg_temp.cs_user();
    insert into commerce_admins(user_id) values(admin);
    update coin_packs set price_piastres=5000, active=true where code='coins_500';

    r1 := pg_temp.cs_room(w, array[w,o], array['citizen','mafia'], 'town');
    r2 := pg_temp.cs_match(w);
    s := public.create_ad_step_claim_v2(w,r1,1);
    perform public.commit_ad_step_v2((s->>'claimId')::uuid,'cs-l13-tx-0001','unit',1,w);
    perform public.create_ad_reward_claim(w,r2);
    perform public.claim_daily_coffer(w,today);
    perform public.create_daily_ad_claim(w,today);
    perform public.commit_play_product(w,'cs-l13-coins','mm_coins_500','GPA.L13.C','active',now(),1,public.account_tag(w));
    perform public.commit_play_product(w,'cs-l13-pass','mm_remove_interruptions','GPA.L13.P','active',now(),1,public.account_tag(w));
    perform public.revoke_voided_play_purchases(array['cs-l13-voided'],null);
    ord := (public.create_coin_order(w,'coins_500','instapay')->'order'->>'id')::uuid;
    perform public.admin_review_coin_order(admin,ord,'approve','CS-L13-T',5000,null);
    perform public.redeem_council_invite(n, public.council_invite(w)->>'code');
    perform public.redeem_council_invite(w, 'QQQQQQQ');   -- an attempt row
    perform public.council_contracts(w); perform public.council_rank(w);
    assert exists(select 1 from council_match_records where user_id=o and w=any(co_players)), 'fixture co_players';
    tombs := (select count(*) from play_void_tombstones);

    perform pg_temp.cs_delete(w);

    foreach t in array array['ad_step_claims','ad_reward_claims','daily_claims','daily_ad_claims',
        'player_entitlements','player_inventory','player_equipment','wallet_ledger','wallet_accounts',
        'council_match_records','council_xp_events','council_identity','council_daily_contracts',
        'council_invite_codes','council_invite_attempts','play_purchases','coin_orders',
        'ad_ssv_transactions'] loop
      execute format('select exists(select 1 from public.%I where user_id=$1)', t) using w into left_over;
      if left_over then bad := bad||' '||t; end if;
    end loop;
    if exists(select 1 from auth.users where id=w) then bad := bad||' auth.users'; end if;
    assert bad='', 'rows left for deleted user:'||bad;
    assert exists(select 1 from play_purchases where purchase_token='cs-l13-coins' and user_id is null),
      'play purchase record not kept';
    assert exists(select 1 from coin_orders where id=ord and user_id is null), 'coin order not kept';
    assert exists(select 1 from ad_ssv_transactions where transaction_id='cs-l13-tx-0001' and user_id is null),
      'ssv registry not kept (replay would reopen)';
    assert (select count(*) from play_void_tombstones)=tombs, 'void tombstones removed';
    assert exists(select 1 from council_invite_redemptions where invitee=n and inviter is null), 'invitee row';
    assert not exists(select 1 from council_match_records where w=any(co_players)), 'deleted id in co_players';
    assert exists(select 1 from council_match_records where user_id=o), 'co-player history dropped';

    -- The guards 20260925000100 had still refuse.
    perform pg_temp.cs_room(a, array[a], array['citizen'], null);
    begin perform pg_temp.cs_delete(a); assert false, 'deleted mid-match';
    exception when others then assert sqlerrm='ACTIVE_ROOM', 'active: '||sqlerrm; end;
    ord := (public.create_coin_order(b,'coins_500','instapay')->'order'->>'id')::uuid;
    perform public.claim_coin_order(b,ord,'REF-12345');
    begin perform pg_temp.cs_delete(b); assert false, 'deleted under review';
    exception when others then assert sqlerrm='ORDER_UNDER_REVIEW', 'review: '||sqlerrm; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cs_record('L13 deletion superset + guards', sqlerrm);
  end;
end $$;

-- Report ----------------------------------------------------------------
do $$
declare failed text;
begin
  select string_agg(gate||' => '||detail, ' | ' order by gate) into failed
    from cs_results where not ok;
  if (select count(*) from cs_results) <> 13 then
    raise exception 'COUNCIL GATES INCOMPLETE: % recorded', (select count(*) from cs_results);
  end if;
  if failed is not null then raise exception 'COUNCIL GATES FAILED: %', failed; end if;
end $$;
rollback;
