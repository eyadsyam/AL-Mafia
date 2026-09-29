-- Row 6: Economy v3 authority. One immutable receipt per eligible seat; caps
-- 6/day and 3/roster fingerprint; faucet amounts; old payments preserved;
-- invite settlement stages, conditions, caps, unlocks and notices; flag off is
-- exactly the old behaviour.
begin;

create function pg_temp.ev_user(p_age interval default interval '30 days') returns uuid
language plpgsql as $$
declare u uuid:=gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u,u::text||'@economy-v3.test',now(),false);
  -- The harness's auth.users has no created_at; account age is read through
  -- council_account_created, which the test overrides below when needed.
  return u;
end $$;

create function pg_temp.ev_code() returns text language sql as $$
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',1+floor(random()*32)::int,1),'')
    from generate_series(1,6)
$$;

-- A finished room. p_seats[1] hosts; p_mafia sits as mafia; everyone else is a
-- citizen. p_kicked seats are kicked. Returns the room id.
create function pg_temp.ev_room(p_seats uuid[],p_mafia uuid,p_outcome text,p_ended timestamptz,
  p_kicked uuid[] default '{}') returns uuid language plpgsql as $$
declare rid uuid:=gen_random_uuid(); i int;
begin
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(rid,pg_temp.ev_code(),p_seats[1],'finished',1,p_ended-interval '20 minutes',p_ended);
  for i in 1..cardinality(p_seats) loop
    insert into public.room_players(room_id,user_id,seat,name,role,kicked)
      values(rid,p_seats[i],i-1,'Seat'||i,
        case when p_seats[i]=p_mafia then 'mafia' else 'citizen' end,
        p_seats[i]=any(p_kicked));
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(rid,'result',jsonb_build_object('outcome',p_outcome));
  return rid;
end $$;

create function pg_temp.ev_balance(p_user uuid) returns bigint language sql as $$
  select coalesce((select balance from public.wallet_accounts where user_id=p_user),0)
$$;

do $$
declare
  a uuid; b uuid; c uuid; d uuid; e uuid; f uuid; g uuid; h uuid; x uuid;
  seats uuid[]; others uuid[]; rid uuid; r1 uuid; r2 uuid; r3 uuid; r4 uuid;
  bal bigint; bal2 bigint; rec public.match_receipts; snap jsonb; cap jsonb;
  today date:=(now() at time zone 'utc')::date; t0 timestamptz; i int; n int;
  fp1 text; fp2 text; season bigint;
begin
  a:=pg_temp.ev_user(); b:=pg_temp.ev_user(); c:=pg_temp.ev_user(); d:=pg_temp.ev_user();
  e:=pg_temp.ev_user(); f:=pg_temp.ev_user(); g:=pg_temp.ev_user(); h:=pg_temp.ev_user();
  seats:=array[a,b,c,d,e];
  t0:=date_trunc('day',now() at time zone 'utc') at time zone 'utc' + interval '1 hour';
  if t0>now() then t0:=now()-interval '1 minute'; end if;

  -- ── Flag off: exactly the old sync (100 + 25 on a win), no receipt, no key.
  assert not public.economy_v3_on(),'the switch ships off';
  cap:=public.economy_capabilities(a);
  assert not (cap ? 'economy'),'no economy key while off: '||cap::text;
  rid:=pg_temp.ev_room(seats,b,'town',t0);
  perform public.sync_player_rewards(a);
  assert pg_temp.ev_balance(a)=125,'flag off pays the old amounts: '||pg_temp.ev_balance(a);
  assert not exists(select 1 from public.match_receipts),'flag off writes no receipt';

  -- ── On: capability and a room paid before the switch keeps its payment.
  update public.economy_config set economy_v11_enabled=true;
  cap:=public.economy_capabilities(a);
  assert (cap->'economy'->>'version')::int=3,'economy.version=3: '||cap::text;
  perform public.sync_player_rewards(a);
  assert pg_temp.ev_balance(a)=125,'a room paid under v1 is not re-paid';
  assert not exists(select 1 from public.match_receipts where room_id=rid),
    'no receipt for a room already paid';

  -- ── Faucet amounts: first eligible of the day (loss) = 25 + 25 first-of-day.
  --    Use a fresh account so the day's first is observable.
  x:=pg_temp.ev_user();
  others:=array[x,b,c,d,e];
  r1:=pg_temp.ev_room(others,b,'mafia',t0+interval '1 minute');
  perform public.sync_player_rewards(x);
  select * into rec from public.match_receipts where user_id=x and room_id=r1;
  assert rec.user_id is not null,'eligible match wrote a receipt';
  assert rec.completion_coins=25 and rec.win_coins=0 and rec.first_day_coins=25
    and rec.season_xp=5 and rec.council_xp=30 and rec.day_ordinal=1 and rec.roster_ordinal=1
    and not rec.won and rec.human_count=5,row_to_json(rec)::text;
  assert pg_temp.ev_balance(x)=50,'loss + first of day = 50: '||pg_temp.ev_balance(x);
  assert rec.roster_fingerprint ~ '^[0-9a-f]{64}$','HMAC fingerprint shape';
  assert not (rec.roster_fingerprint like '%'||replace(x::text,'-','')||'%'),'no raw id inside';

  -- Win, second of the day: 25 + 10, no first-of-day.
  r2:=pg_temp.ev_room(others,b,'town',t0+interval '2 minutes');
  perform public.sync_player_rewards(x);
  select * into rec from public.match_receipts where user_id=x and room_id=r2;
  assert rec.won and rec.win_coins=10 and rec.first_day_coins=0 and rec.season_xp=10
    and rec.council_xp=50 and rec.day_ordinal=2 and rec.roster_ordinal=2,row_to_json(rec)::text;
  assert pg_temp.ev_balance(x)=85,'85 after a win: '||pg_temp.ev_balance(x);

  -- ── Replay: syncing again, and issuing directly, change nothing.
  perform public.sync_player_rewards(x);
  perform public.sync_player_rewards(x);
  rec:=public.economy_v3_issue_receipt(x,r2);
  assert rec.day_ordinal=2,'replay returns the same receipt';
  assert public.economy_v3_settle_receipt(x,r2)=0,'a settled receipt pays nothing twice';
  assert pg_temp.ev_balance(x)=85,'replay paid again';
  assert (select count(*) from public.wallet_ledger where user_id=x and kind='match_first_of_day')=1;

  -- ── Immutable.
  begin
    update public.match_receipts set completion_coins=100 where user_id=x and room_id=r2;
    raise exception 'receipt was updated';
  exception when others then
    assert sqlerrm='RECEIPT_IMMUTABLE',sqlerrm;
  end;

  -- ── Roster fingerprint cap: a third same-roster match pays; the fourth not.
  r3:=pg_temp.ev_room(others,c,'town',t0+interval '3 minutes');
  r4:=pg_temp.ev_room(others,c,'town',t0+interval '4 minutes');
  perform public.sync_player_rewards(x);
  assert exists(select 1 from public.match_receipts where user_id=x and room_id=r3
    and roster_ordinal=3),'third same-roster receipt';
  assert not exists(select 1 from public.match_receipts where user_id=x and room_id=r4),
    'fourth same-roster match earns no receipt';
  assert not exists(select 1 from public.wallet_ledger where user_id=x and source_room=r4),
    'and no coins';
  -- Seat order and duplicate seats do not change the normalized fingerprint.
  fp1:=public.economy_roster_fingerprint(r3,today);
  fp2:=public.economy_roster_fingerprint(pg_temp.ev_room(array[e,d,c,b,x],c,'town',
    t0+interval '5 minutes'),today);
  assert fp1=fp2,'fingerprint is order-independent';
  -- A kicked seat is not part of the eligible roster, so kicking a sixth
  -- player does not create a new fingerprint to farm with.
  fp2:=public.economy_roster_fingerprint(pg_temp.ev_room(array[x,b,c,d,e,f],c,'town',
    t0+interval '6 minutes',array[f]),today);
  assert fp1=fp2,'kicked seat is outside the roster';
  -- Another day's salt gives another fingerprint for the same roster.
  assert fp1<>public.economy_roster_fingerprint(r3,today-1),'per-day salt';
  -- A different sixth human is a different roster (collision guard).
  fp2:=public.economy_roster_fingerprint(pg_temp.ev_room(array[x,b,c,d,e,f],c,'town',
    t0+interval '7 minutes'),today);
  assert fp1<>fp2,'a different full roster is a different fingerprint';

  -- ── Daily cap: six receipts per UTC day, whatever the rosters.
  perform public.sync_player_rewards(x);
  select count(*) into n from public.match_receipts where user_id=x and day=today;
  assert n=4,'receipts so far: '||n;   -- r1,r2,r3 + the six-player (f) room
  for i in 1..3 loop
    perform pg_temp.ev_room(array[x,b,c,d,g,h],b,'town',t0+make_interval(mins=>10+i),
      case when i=1 then '{}'::uuid[] else '{}'::uuid[] end);
  end loop;
  -- Three more with rosters [x,b,c,d,g,h]: two fit under the daily six; the
  -- third is refused by the day cap (its roster count would only be 3).
  perform public.sync_player_rewards(x);
  select count(*) into n from public.match_receipts where user_id=x and day=today;
  assert n=6,'daily cap is six: '||n;
  assert (select max(day_ordinal) from public.match_receipts where user_id=x and day=today)=6;

  -- ── Concurrency: two writers racing past the lock cannot mint a 7th or a
  --    4th same-roster receipt; the unique ordinals refuse it.
  begin
    insert into public.match_receipts(user_id,room_id,day,week,ended_at,won,human_count,
        roster_fingerprint,day_ordinal,roster_ordinal,completion_coins,win_coins,
        first_day_coins,season_xp,council_xp)
      select user_id,gen_random_uuid(),day,week,ended_at,won,human_count,roster_fingerprint,
        day_ordinal,4-roster_ordinal,25,0,0,5,30
        from public.match_receipts where user_id=x and day_ordinal=6;
    raise exception 'duplicate day ordinal accepted';
  exception when unique_violation then null;
  end;
  begin
    insert into public.match_receipts(user_id,room_id,day,week,ended_at,won,human_count,
        roster_fingerprint,day_ordinal,roster_ordinal,completion_coins,win_coins,
        first_day_coins,season_xp,council_xp)
      values(x,gen_random_uuid(),today,'x',now(),false,5,repeat('a',64),7,1,25,0,0,5,30);
    raise exception 'seventh ordinal accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.match_receipts(user_id,room_id,day,week,ended_at,won,human_count,
        roster_fingerprint,day_ordinal,roster_ordinal,completion_coins,win_coins,
        first_day_coins,season_xp,council_xp)
      values(x,gen_random_uuid(),today-5,'x',now(),false,5,fp1,1,4,25,0,0,5,30);
    raise exception 'fourth roster ordinal accepted';
  exception when check_violation then null;
  end;
  -- The same seat issued twice in one transaction (a racing retry) is one row.
  rid:=pg_temp.ev_room(array[b,c,d,e,f],c,'town',t0+interval '30 minutes');
  rec:=public.economy_v3_issue_receipt(b,rid);
  assert (public.economy_v3_issue_receipt(b,rid)).created_at=rec.created_at;
  assert (select count(*) from public.match_receipts where user_id=b and room_id=rid)=1;

  -- ── Ineligible: four humans, a kicked seat, no public outcome.
  rid:=pg_temp.ev_room(array[g,b,c,d],b,'town',t0+interval '31 minutes');
  assert (public.economy_v3_issue_receipt(g,rid)).user_id is null,'four humans are not eligible';
  rid:=pg_temp.ev_room(array[g,b,c,d,e,f],b,'town',t0+interval '32 minutes',array[g]);
  assert (public.economy_v3_issue_receipt(g,rid)).user_id is null,'kicked seat is not eligible';
  rid:=pg_temp.ev_room(array[g,b,c,d,e],b,'town',t0+interval '33 minutes');
  update public.room_state set public_data='{}' where room_id=rid;
  assert (public.economy_v3_issue_receipt(g,rid)).user_id is null,'no public outcome';
  update public.rooms set status='playing' where id=rid;
  update public.room_state set public_data='{"outcome":"town"}' where room_id=rid;
  assert (public.economy_v3_issue_receipt(g,rid)).user_id is null,'live room';
  -- Flag off again: issuance stops, existing receipts stay readable.
  update public.economy_config set economy_v11_enabled=false;
  update public.rooms set status='finished' where id=rid;
  assert (public.economy_v3_issue_receipt(g,rid)).user_id is null,'no issuance while off';
  assert (public.economy_v3_issue_receipt(x,r1)).room_id=r1,'receipts persist';
  update public.economy_config set economy_v11_enabled=true;

  -- ── Receipt drives Council XP and Season XP.
  select id into season from public.mission_seasons where code='season_zero';
  update public.mission_seasons set active=true,starts_at=now()-interval '1 day',
    ends_at=now()+interval '27 days' where id=season;
  update public.economy_config set council_rank_enabled=true,missions_enabled=true;
  x:=pg_temp.ev_user();
  rid:=pg_temp.ev_room(array[x,b,c,d,e],b,'town',now()-interval '1 minute');
  perform public.sync_player_rewards(x);
  assert (select xp from public.council_xp_events where user_id=x and source_key='match:'||rid)=50,
    'council XP from receipt';
  assert (select xp from public.season_xp_events where user_id=x and source_key='match:'||rid)=10,
    'season XP from receipt (not the old 30)';
  assert (select eligible from public.council_match_records where user_id=x and room_id=rid),
    'council record eligibility follows the receipt';
  -- A four-human room is recorded as ineligible and earns no Council XP.
  rid:=pg_temp.ev_room(array[x,b,c,d],b,'town',now()-interval '30 seconds');
  perform public.council_sync(x);
  assert not (select eligible from public.council_match_records where user_id=x and room_id=rid);
  assert coalesce((select xp from public.council_xp_events where user_id=x
    and source_key='match:'||rid),0)=0,'no XP without a receipt';
  assert not exists(select 1 from public.season_xp_events where user_id=x
    and source_key='match:'||rid),'no season XP without a receipt';
end $$;

-- ── Invite settlement ─────────────────────────────────────────────────────────
create table pg_temp.ev_ages(u uuid primary key, created timestamptz);
create function pg_temp.ev_age(p_user uuid,p_age interval) returns void language sql as $$
  insert into pg_temp.ev_ages values(p_user,now()-p_age)
    on conflict(u) do update set created=excluded.created
$$;
-- Account age is read through this one function; the harness has no column.
create or replace function public.council_account_created(p_user uuid)
returns timestamptz language sql stable security definer set search_path=public,pg_temp as $$
  select created from pg_temp.ev_ages where u=p_user
$$;

do $$
declare
  v_inviter uuid; v_invitee uuid; pool uuid[]; i int; r uuid; st jsonb; t timestamptz;
  bal_inviter bigint; bal_invitee bigint; v_code text; v uuid;
  y timestamptz:=date_trunc('day',now() at time zone 'utc') at time zone 'utc' - interval '12 hours';
  z timestamptz:=now()-interval '1 minute';
begin
  update public.economy_config set economy_v11_enabled=true,council_invites_enabled=true;
  v_inviter:=pg_temp.ev_user(); v_invitee:=pg_temp.ev_user();
  perform pg_temp.ev_age(v_inviter,interval '90 days');
  perform pg_temp.ev_age(v_invitee,interval '3 days');
  pool:=array[]::uuid[];
  for i in 1..8 loop pool:=pool||pg_temp.ev_user(); end loop;
  insert into public.council_identity(user_id,name) values(v_invitee,'Nour');

  v_code:=(public.council_invite(v_inviter))->>'code';
  assert v_code is not null,'v_inviter has a v_code';
  st:=public.redeem_council_invite(v_invitee,v_code);
  assert st->>'status'='redeemed',st::text;

  -- Match 1 (yesterday, with the v_inviter): the room-link promise settles
  -- exactly once now: v_invitee 50 and v_inviter 100.
  r:=pg_temp.ev_room(array[v_invitee,v_inviter,pool[1],pool[2],pool[3]],pool[1],'town',y);
  perform public.sync_player_rewards(v_invitee);
  assert exists(select 1 from public.wallet_ledger where user_id=v_invitee
    and kind='council_invite_invitee' and amount=50),'v_invitee got 50';
  assert exists(select 1 from public.wallet_ledger where user_id=v_inviter
    and kind='invite_inviter_stage' and amount=100 and source_key=v_invitee::text),'v_inviter got 100';
  assert (select count(*) from public.invite_notices where user_id=v_inviter
    and kind='first_match' and name='Seat1' and coins=100)=1,'first-match notice carries the name last sat down with';
  assert (select count(*) from public.invite_notices where user_id=v_inviter
    and kind='progress' and progress=1)=1,'progress 1 of 3 notice';
  -- Replay pays nothing twice.
  perform public.sync_player_rewards(v_invitee);
  perform public.council_invite(v_inviter);
  assert (select count(*) from public.wallet_ledger where user_id=v_inviter
    and kind='invite_inviter_stage')=1,'stage 1 once';
  assert (select count(*) from public.wallet_ledger where user_id=v_invitee
    and kind='council_invite_invitee')=1,'v_invitee 50 once';

  -- Match 2 (yesterday, with v_inviter), match 3 (today, with v_inviter): three
  -- matches over two days but never without the v_inviter → not settled.
  perform pg_temp.ev_room(array[v_invitee,v_inviter,pool[2],pool[3],pool[4]],pool[2],'town',
    y+interval '5 minutes');
  perform pg_temp.ev_room(array[v_invitee,v_inviter,pool[3],pool[4],pool[1]],pool[3],'town',z);
  perform public.sync_player_rewards(v_invitee);
  assert (select settled_at from public.council_invite_redemptions where invitee=v_invitee
    and inviter=v_inviter) is null,'no match without the v_inviter yet';
  assert (select count(*) from public.invite_notices where user_id=v_inviter and kind='progress')=3;

  -- Match 4 today without the v_inviter, but only four distinct co-players so
  -- far outside the v_inviter (pool 1..4)... plus pool[5] makes five.
  perform pg_temp.ev_room(array[v_invitee,pool[1],pool[2],pool[3],pool[4]],pool[1],'town',
    z+interval '10 seconds');
  perform public.sync_player_rewards(v_invitee);
  assert (select settled_at from public.council_invite_redemptions where invitee=v_invitee) is null,
    'four distinct co-players is not five';
  perform pg_temp.ev_room(array[v_invitee,pool[1],pool[2],pool[3],pool[5]],pool[1],'town',
    z+interval '20 seconds');
  -- Account younger than 48h holds settlement.
  perform pg_temp.ev_age(v_invitee,interval '47 hours');
  perform public.sync_player_rewards(v_invitee);
  assert (select settled_at from public.council_invite_redemptions where invitee=v_invitee) is null,
    'account age under 48h holds settlement';
  perform pg_temp.ev_age(v_invitee,interval '49 hours');
  bal_inviter:=pg_temp.ev_balance(v_inviter);
  perform public.sync_player_rewards(v_invitee);
  assert (select settled_at is not null from public.council_invite_redemptions where invitee=v_invitee),
    'settled';
  assert pg_temp.ev_balance(v_inviter)=bal_inviter,'new referrals were already paid in full';
  assert exists(select 1 from public.invite_notices where user_id=v_inviter and kind='settled');
  perform public.sync_player_rewards(v_invitee);
  perform public.council_invite(v_inviter);
  assert not exists(select 1 from public.wallet_ledger where user_id=v_inviter
    and kind='invite_inviter_settlement'),'new referral was not paid twice';

  -- Inviter's read shows v3 progress and notices; ack clears them.
  st:=public.council_invite(v_inviter);
  assert (st->'v3'->>'settledLifetime')::int=1,st::text;
  assert jsonb_array_length(st->'v3'->'notices')>=4,st::text;
  assert not (st::text like '%'||v_invitee::text||'%'),'invite read never names the v_invitee id';
  perform public.invite_notices_ack(v_inviter,(select array_agg(id) from public.invite_notices
    where user_id=v_inviter));
  assert jsonb_array_length((public.council_invite(v_inviter))->'v3'->'notices')=0,'acked';
  assert (public.council_invite(v_inviter))->'v3'->'unlocks'='[]'::jsonb,'no unlock at one';

  -- Unlock thresholds and caps, exercised on settled rows directly.
  for i in 1..9 loop
    v:=pg_temp.ev_user();
    insert into public.council_invite_redemptions(invitee,inviter,code,rewarded_at,stage1_at,
        settled_at,settled_season)
      values(v,v_inviter,v_code,now(),now(),now(),public.invite_v3_season());
  end loop;
  -- A new v_invitee who meets every condition is still not settled at ten this
  -- season: the season cap holds, and stage 1 is withheld too.
  v:=pg_temp.ev_user();
  perform pg_temp.ev_age(v,interval '10 days');
  insert into public.council_invite_redemptions(invitee,inviter,code) values(v,v_inviter,v_code);
  perform pg_temp.ev_room(array[v,pool[1],pool[2],pool[3],pool[4]],pool[1],'town',y+interval '1 minute');
  perform pg_temp.ev_room(array[v,pool[5],pool[6],pool[7],pool[8]],pool[5],'town',z+interval '1 second');
  perform pg_temp.ev_room(array[v,pool[1],pool[6],pool[7],pool[8]],pool[6],'town',z+interval '2 seconds');
  perform public.sync_player_rewards(v);
  assert (select settled_at from public.council_invite_redemptions where invitee=v) is null,
    'season cap of ten';
  assert not exists(select 1 from public.wallet_ledger where user_id=v_inviter
    and kind='invite_inviter_stage' and source_key=v::text),'no stage-1 over the cap';
  assert exists(select 1 from public.wallet_ledger where user_id=v
    and kind='council_invite_invitee'),'the v_invitee still gets 50';
  -- Unlocks: settle logic grants at 3 and 10; force one re-evaluation by a
  -- fresh settlement under a raised season (next season, same lifetime).
  update public.council_invite_redemptions set settled_season=-1
   where inviter=v_inviter and settled_at is not null and invitee<>v_invitee;
  perform public.sync_player_rewards(v);
  assert (select settled_at is not null from public.council_invite_redemptions where invitee=v),
    'settles once the season has room';
  assert (select array_agg(code order by code) from public.invite_unlocks where user_id=v_inviter)
    =array['frame_invite','title_kabir_elshella'],'three → title, ten → frame';
  assert exists(select 1 from public.player_inventory
    where user_id=v_inviter and item_code='frame_invite'),'invite frame enters inventory';
  perform public.equip_reward_item(v_inviter,'frame','frame_invite');
  assert (select item_code from public.player_equipment
    where user_id=v_inviter and slot='frame')='frame_invite','invite frame equips';
  -- Lifetime cap forty.
  for i in 1..29 loop
    insert into public.council_invite_redemptions(invitee,inviter,code,rewarded_at,stage1_at,
        settled_at,settled_season)
      values(pg_temp.ev_user(),v_inviter,v_code,now(),now(),now(),-2);
  end loop;
  assert (select count(*) from public.council_invite_redemptions where inviter=v_inviter
    and settled_at is not null)=40;
  v:=pg_temp.ev_user();
  perform pg_temp.ev_age(v,interval '10 days');
  insert into public.council_invite_redemptions(invitee,inviter,code) values(v,v_inviter,v_code);
  perform pg_temp.ev_room(array[v,pool[1],pool[2],pool[3],pool[4]],pool[1],'town',y+interval '2 minutes');
  perform pg_temp.ev_room(array[v,pool[5],pool[6],pool[7],pool[8]],pool[5],'town',z+interval '3 seconds');
  perform pg_temp.ev_room(array[v,pool[1],pool[6],pool[7],pool[8]],pool[6],'town',z+interval '4 seconds');
  perform public.sync_player_rewards(v);
  assert (select settled_at from public.council_invite_redemptions where invitee=v) is null,
    'lifetime cap of forty';

  -- A redemption the old scheme already paid is left exactly as it was.
  v:=pg_temp.ev_user();
  insert into public.council_invite_redemptions(invitee,inviter,code,rewarded_at,inviter_paid)
    values(v,pool[8],'OLDPAY',now(),true);
  perform pg_temp.ev_room(array[v,pool[1],pool[2],pool[3],pool[4]],pool[1],'town',z+interval '5 seconds');
  perform public.sync_player_rewards(v);
  assert (select stage1_at from public.council_invite_redemptions where invitee=v) is null,
    'v1-paid redemption untouched';

  -- Flag off: council_invite is the old function's answer (no v3 key).
  update public.economy_config set economy_v11_enabled=false;
  assert not ((public.council_invite(v_inviter)) ? 'v3'),'no v3 block while off';

  -- Deletion removes receipts, notices and unlocks.
  insert into public.data_deletion_requests(id,user_id) values(gen_random_uuid(),v_inviter);
  perform public.complete_data_deletion((select id from public.data_deletion_requests
    where user_id=v_inviter));
  assert not exists(select 1 from public.invite_notices where user_id=v_inviter);
  assert not exists(select 1 from public.invite_unlocks where user_id=v_inviter);
  assert not exists(select 1 from public.match_receipts where user_id=v_inviter);
end $$;
rollback;
