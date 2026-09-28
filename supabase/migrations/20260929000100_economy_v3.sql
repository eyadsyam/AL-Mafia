-- Row 6: Economy v3 authority (spec §3 "Economy v3 authority", "Complete
-- faucet table", "Invite settlement"). Everything is dark behind
-- `economy_v11_enabled`; with the switch off every function below hands the
-- call to the function it wraps, unchanged.
--
-- One immutable receipt per eligible seat drives coins, Season XP, Council XP,
-- missions (through the eligible Council record), Thursday and invites. An
-- eligible match: a finished online room with a public outcome, played from a
-- non-kicked seat, with at least five eligible humans. Caps: six receipts per
-- account per UTC day, and at most three per normalized full eligible-human
-- roster fingerprint (sorted stable ids, HMACed with a day salt) per day.
--
-- Existing balances, inventory, entitlements and Council rank are untouched.
-- A room already paid under the old amounts keeps them (the amount recorded
-- when it was offered); v3 never re-pays or claws back.
--
-- Zero leakage (Doc 05): receipts are written only after `status='finished'`
-- with a public outcome; they keep the owner's own win flag, never a role, and
-- no read returns another player's receipt, id or seat.
--
-- Lock order: the invite wallet set (sorted) first, then this caller's wallet
-- (already inside that set), then rows; the same order Council Life uses.

-- 0. Switch and ledger kinds ---------------------------------------------------
alter table public.economy_config
  add column if not exists economy_v11_enabled boolean not null default false;

create function public.economy_v3_on() returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select economy_v11_enabled from public.economy_config where id=true),false)
$$;

do $$
declare kinds text[];
begin
  select coalesce(array_agg(distinct m[1]), '{}') into kinds
    from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z0-9_]+)''', 'g') m
   where c.conname='wallet_ledger_kind_check' and c.conrelid='public.wallet_ledger'::regclass;
  select array_agg(distinct k order by k) into kinds from unnest(kinds || array[
    'match_first_of_day','invite_inviter_stage','invite_inviter_settlement']) k;
  alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
  execute format('alter table public.wallet_ledger add constraint wallet_ledger_kind_check '
    'check (kind in (%s))', (select string_agg(quote_literal(k), ',' order by k) from unnest(kinds) k));
end $$;

-- 1. Roster fingerprint ----------------------------------------------------------
-- The cap compares rosters inside one UTC day only, so a per-day salt is
-- enough and old salts are purged like the metrics salts (48 h).
create table public.economy_roster_salts(
  day date primary key,
  salt bytea not null check (octet_length(salt)=32)
);
alter table public.economy_roster_salts enable row level security;
revoke all on public.economy_roster_salts from public,anon,authenticated;
grant select,insert,update,delete on public.economy_roster_salts to service_role;

create function public.economy_roster_fingerprint(p_room uuid,p_day date)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare s bytea; roster text;
begin
  select string_agg(distinct user_id::text, ',' order by user_id::text) into roster
    from public.room_players where room_id=p_room and not kicked and role is not null;
  if roster is null then return null; end if;
  insert into public.economy_roster_salts(day,salt)
    values(p_day,decode(replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-',''),'hex'))
    on conflict(day) do nothing;
  select salt into strict s from public.economy_roster_salts where day=p_day;
  return encode(public.metric_hmac_sha256(s,convert_to(roster,'UTF8')),'hex');
end $$;

create function public.purge_economy_roster_salts() returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
begin
  delete from public.economy_roster_salts
   where day<(now() at time zone 'utc'-interval '48 hours')::date;
  get diagnostics n=row_count;
  return n;
end $$;

-- 2. The receipt -------------------------------------------------------------------
-- Amounts are copied in when the receipt is written; later settlement pays
-- exactly these numbers even if a product rule changes in between. The two
-- unique ordinals make both caps hold even if two writers ever raced past the
-- wallet lock: the seventh (or fourth same-roster) insert cannot exist.
create table public.match_receipts(
  user_id uuid not null,
  room_id uuid not null,
  day date not null,
  week text not null,
  ended_at timestamptz not null,
  won boolean not null,
  human_count int not null check (human_count between 5 and 20),
  roster_fingerprint text not null check (roster_fingerprint ~ '^[0-9a-f]{64}$'),
  day_ordinal smallint not null check (day_ordinal between 1 and 6),
  roster_ordinal smallint not null check (roster_ordinal between 1 and 3),
  co_players uuid[] not null default '{}',
  completion_coins int not null check (completion_coins between 0 and 100),
  win_coins int not null check (win_coins between 0 and 100),
  first_day_coins int not null check (first_day_coins between 0 and 100),
  season_xp int not null check (season_xp between 0 and 100),
  council_xp int not null check (council_xp between 0 and 100),
  economy_version smallint not null default 3 check (economy_version=3),
  created_at timestamptz not null default now(),
  primary key(user_id,room_id),
  unique(user_id,day,day_ordinal),
  unique(user_id,day,roster_fingerprint,roster_ordinal)
);
create index match_receipts_day on public.match_receipts(user_id,day);
alter table public.match_receipts enable row level security;
revoke all on public.match_receipts from public,anon,authenticated;
grant select,insert,delete on public.match_receipts to service_role;

-- Immutable once written. Deleting the owner's account removes it.
create function public.match_receipt_immutable() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  raise exception 'RECEIPT_IMMUTABLE';
end $$;
create trigger match_receipts_immutable before update on public.match_receipts
  for each row execute function public.match_receipt_immutable();

-- The faucet table's match rows (spec §3): completion 25 coins / 5 Season XP
-- / 30 Council XP; a win adds 10 / 5 / 20; the first eligible match of the
-- UTC day adds 25 coins.
create function public.economy_v3_issue_receipt(p_user uuid,p_room uuid)
returns public.match_receipts language plpgsql security definer set search_path=public,pg_temp as $$
declare rec public.match_receipts; m record; humans int; mates uuid[]; d date; fp text;
  day_used int; fp_used int; v_won boolean;
begin
  select * into rec from public.match_receipts where user_id=p_user and room_id=p_room;
  if found then return rec; end if;
  if not public.economy_v3_on() then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into rec from public.match_receipts where user_id=p_user and room_id=p_room;
  if found then return rec; end if;

  select r.ended_at,p.role,s.public_data->>'outcome' as outcome into m
    from public.rooms r join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
   where r.id=p_room and p.user_id=p_user and not p.kicked and p.role is not null
     and r.status='finished' and r.ended_at is not null
     and s.public_data->>'outcome' in ('mafia','town');
  if not found then return null; end if;

  select count(distinct user_id)::int,
      coalesce(array_agg(distinct user_id) filter (where user_id<>p_user),'{}')
    into humans,mates
    from public.room_players where room_id=p_room and not kicked and role is not null;
  if humans<5 then return null; end if;

  d:=(m.ended_at at time zone 'utc')::date;
  select count(*)::int into day_used from public.match_receipts where user_id=p_user and day=d;
  if day_used>=6 then return null; end if;
  fp:=public.economy_roster_fingerprint(p_room,d);
  select count(*)::int into fp_used from public.match_receipts
   where user_id=p_user and day=d and roster_fingerprint=fp;
  if fp_used>=3 then return null; end if;

  v_won:=(m.role='mafia')=(m.outcome='mafia');
  insert into public.match_receipts(user_id,room_id,day,week,ended_at,won,human_count,
      roster_fingerprint,day_ordinal,roster_ordinal,co_players,completion_coins,win_coins,
      first_day_coins,season_xp,council_xp)
    values(p_user,p_room,d,public.council_week(d),m.ended_at,v_won,humans,fp,day_used+1,
      fp_used+1,mates,25,case when v_won then 10 else 0 end,case when day_used=0 then 25 else 0 end,
      5+case when v_won then 5 else 0 end,30+case when v_won then 20 else 0 end)
    returning * into rec;
  return rec;
end $$;

-- Pays a receipt. Idempotent through the ledger's unique keys; the caller
-- holds the wallet lock. Inserting `match_completion` also fires the Council
-- recorder trigger, exactly as the old sync did.
create function public.economy_v3_settle_receipt(p_user uuid,p_room uuid)
returns bigint language plpgsql security definer set search_path=public,pg_temp as $$
declare rec public.match_receipts; paid bigint:=0;
begin
  select * into rec from public.match_receipts where user_id=p_user and room_id=p_room;
  if not found then return 0; end if;
  if public.credit_earned(p_user,'match_completion',rec.completion_coins,p_room,null) then
    paid:=paid+rec.completion_coins;
  end if;
  if rec.win_coins>0 and public.credit_earned(p_user,'match_win',rec.win_coins,p_room,null) then
    paid:=paid+rec.win_coins;
  end if;
  if rec.first_day_coins>0 and public.credit_earned(p_user,'match_first_of_day',
      rec.first_day_coins,null,rec.day::text) then
    paid:=paid+rec.first_day_coins;
  end if;
  return paid;
end $$;

-- 3. Invite settlement ----------------------------------------------------------------
alter table public.council_invite_redemptions
  add column if not exists stage1_at timestamptz,
  add column if not exists settled_at timestamptz,
  add column if not exists settled_season bigint;
create index council_redemptions_settled on public.council_invite_redemptions(inviter,settled_at)
  where settled_at is not null;

-- What the inviter sees: «{name} لعب أول ماتش — خدت ٢٥ عملة» and «صاحبك لعب ١ من ٣».
-- The client owns the copy; the server keeps the kind, the display name the
-- invitee last sat down with, and the count. The invitee id is kept only to
-- make each line unique and is never returned.
create table public.invite_notices(
  id bigint generated always as identity primary key,
  user_id uuid not null,
  invitee uuid not null,
  kind text not null check (kind in ('first_match','progress','settled')),
  name text not null default '' check (char_length(name)<=40),
  progress smallint not null default 0 check (progress between 0 and 3),
  coins int not null default 0 check (coins between 0 and 100),
  created_at timestamptz not null default now(),
  seen_at timestamptz,
  unique(user_id,invitee,kind,progress)
);
create index invite_notices_unseen on public.invite_notices(user_id) where seen_at is null;

-- Three settled invites unlock «كبير الشلة»; ten unlock the invite frame.
create table public.invite_unlocks(
  user_id uuid not null,
  code text not null check (code in ('title_kabir_elshella','frame_invite')),
  unlocked_at timestamptz not null default now(),
  primary key(user_id,code)
);
alter table public.invite_notices enable row level security;
alter table public.invite_unlocks enable row level security;
revoke all on public.invite_notices,public.invite_unlocks from public,anon,authenticated;
grant select,insert,update,delete on public.invite_notices,public.invite_unlocks to service_role;

create function public.invite_v3_season() returns bigint
language sql stable security definer set search_path=public,pg_temp as $$
  select id from public.mission_seasons
   where active and now()>=starts_at and now()<ends_at order by starts_at desc limit 1
$$;

-- Every wallet an invite settlement for this caller could touch, sorted.
create function public.invite_v3_wallets(p_user uuid) returns uuid[]
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(array_agg(distinct x order by x),'{}') from (
    select p_user as x
    union select inviter from public.council_invite_redemptions
      where invitee=p_user and inviter is not null and not detached and settled_at is null
    union select invitee from public.council_invite_redemptions
      where inviter=p_user and not detached and settled_at is null) s
$$;

create function public.invite_v3_lock(p_user uuid) returns uuid[]
language plpgsql security definer set search_path=public,pg_temp as $$
declare users uuid[]:=public.invite_v3_wallets(p_user); u uuid;
begin
  foreach u in array users loop
    perform pg_advisory_xact_lock(hashtextextended('wallet:'||u::text,91));
  end loop;
  return users;
end $$;

-- Settles every open redemption on either side of [p_user] whose wallets are
-- all inside [p_locked] (taken by invite_v3_lock first in the transaction).
create function public.invite_v3_settle(p_user uuid,p_locked uuid[])
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.council_invite_redemptions; n int; days int; apart int; mates int;
  season bigint:=public.invite_v3_season(); settled_season_n int; settled_life int;
  who text; created timestamptz; under_caps boolean; p int;
begin
  if not public.economy_v3_on() or not public.council_on('invites') then return; end if;
  for r in select * from public.council_invite_redemptions
      where not detached and inviter is not null and settled_at is null
        and (invitee=p_user or inviter=p_user)
        -- A redemption the old scheme already paid stays paid as it was.
        and (rewarded_at is null or stage1_at is not null)
      order by redeemed_at limit 50 for update loop
    continue when not (r.invitee=any(p_locked) and r.inviter=any(p_locked));
    select count(*)::int,count(distinct day)::int,
        count(*) filter (where not (r.inviter=any(co_players)))::int
      into n,days,apart from public.match_receipts where user_id=r.invitee;
    continue when n=0;
    select count(distinct mate)::int into mates
      from public.match_receipts x, unnest(x.co_players) mate
     where x.user_id=r.invitee and mate<>r.inviter;
    select count(*) filter (where settled_season is not distinct from season)::int,count(*)::int
      into settled_season_n,settled_life
      from public.council_invite_redemptions where inviter=r.inviter and settled_at is not null;
    under_caps:=settled_season_n<10 and settled_life<40;
    select left(btrim(name),40) into who from public.council_identity where user_id=r.invitee;
    who:=coalesce(who,'');

    if r.stage1_at is null then
      perform public.credit_earned(r.invitee,'council_invite_invitee',50,null,'invitee');
      if under_caps and public.credit_earned(r.inviter,'invite_inviter_stage',25,null,r.invitee::text) then
        insert into public.invite_notices(user_id,invitee,kind,name,progress,coins)
          values(r.inviter,r.invitee,'first_match',who,0,25) on conflict do nothing;
      end if;
      update public.council_invite_redemptions
         set stage1_at=now(),rewarded_at=coalesce(rewarded_at,now())
       where invitee=r.invitee;
    end if;
    for p in 1..least(n,3) loop
      insert into public.invite_notices(user_id,invitee,kind,name,progress)
        values(r.inviter,r.invitee,'progress',who,p) on conflict do nothing;
    end loop;

    created:=public.council_account_created(r.invitee);
    if n>=3 and days>=2 and apart>=1 and mates>=5 and under_caps
       and created is not null and created<=now()-interval '48 hours' then
      if public.credit_earned(r.inviter,'invite_inviter_settlement',75,null,r.invitee::text) then
        insert into public.invite_notices(user_id,invitee,kind,name,progress,coins)
          values(r.inviter,r.invitee,'settled',who,3,75) on conflict do nothing;
      end if;
      update public.council_invite_redemptions set settled_at=now(),settled_season=season
       where invitee=r.invitee;
      settled_life:=settled_life+1;
      if settled_life>=3 then
        insert into public.invite_unlocks(user_id,code) values(r.inviter,'title_kabir_elshella')
          on conflict do nothing;
      end if;
      if settled_life>=10 then
        insert into public.invite_unlocks(user_id,code) values(r.inviter,'frame_invite')
          on conflict do nothing;
      end if;
    end if;
  end loop;
end $$;

create function public.invite_notices_ack(p_user uuid,p_ids bigint[])
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare n int;
begin
  if p_ids is null or cardinality(p_ids)>50 then raise exception 'BAD_REQUEST'; end if;
  update public.invite_notices set seen_at=now()
   where user_id=p_user and id=any(p_ids) and seen_at is null;
  get diagnostics n=row_count;
  return jsonb_build_object('ok',true,'acknowledged',n);
end $$;

-- 4. Wrapping the existing chain -------------------------------------------------------
alter function public.sync_player_rewards(uuid) rename to sync_player_rewards_pre_v3;
create function public.sync_player_rewards(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare locked uuid[]; room uuid; rec public.match_receipts;
begin
  if not public.economy_v3_on() then return public.sync_player_rewards_pre_v3(p_user); end if;
  locked:=public.invite_v3_lock(p_user);
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  for room in
    select r.id from public.rooms r join public.room_players p on p.room_id=r.id
      join public.room_state s on s.room_id=r.id
     where p.user_id=p_user and not p.kicked and p.role is not null
       and r.status='finished' and r.ended_at is not null
       and s.public_data->>'outcome' in ('mafia','town')
     order by r.ended_at,r.id
  loop
    -- Paid under the previous amounts: that payment is the recorded offer.
    continue when not exists(select 1 from public.match_receipts
        where user_id=p_user and room_id=room)
      and exists(select 1 from public.wallet_ledger
        where user_id=p_user and source_room=room and kind='match_completion');
    rec:=public.economy_v3_issue_receipt(p_user,room);
    if rec.user_id is not null then perform public.economy_v3_settle_receipt(p_user,room); end if;
  end loop;
  perform public.invite_v3_settle(p_user,locked);
  return public.wallet_snapshot(p_user);
end $$;

-- The Council record's eligibility is the receipt's, so missions, Thursday and
-- reunion credit all follow the one decision. Same body as the Casebook
-- recorder otherwise.
alter function public.council_record_match(uuid,uuid) rename to council_record_match_pre_v3;
create function public.council_record_match(p_user uuid,p_room uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare m record; v_team text; mates uuid[]; n int; humans int; rec public.match_receipts;
  d date; wk text; reunion_credit boolean;
begin
  if not public.economy_v3_on() then return public.council_record_match_pre_v3(p_user,p_room); end if;
  if not public.council_on('any') and not public.missions_on() then return false; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  perform pg_advisory_xact_lock(hashtextextended('casebook:'||p_user::text,93));
  select r.id,r.ended_at,r.host_id,p.role,p.name,p.gender,
      s.public_data->>'outcome' as outcome into m
    from public.rooms r join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
   where r.id=p_room and p.user_id=p_user and not p.kicked and p.role is not null
     and r.status='finished' and r.ended_at is not null
     and s.public_data->>'outcome' in ('mafia','town');
  if not found then return false; end if;
  rec:=public.economy_v3_issue_receipt(p_user,p_room);

  d:=(m.ended_at at time zone 'utc')::date;
  wk:=public.council_week(d);
  v_team:=case when m.role='mafia' then 'mafia' else 'town' end;
  select coalesce(array_agg(user_id order by user_id) filter(where user_id<>p_user),'{}'),
      count(distinct user_id)
    into mates,humans from public.room_players
   where room_id=p_room and not kicked and role is not null;
  select exists(
    select 1 from unnest(mates) mate
     where exists(select 1 from public.council_match_records old
       where old.user_id=p_user and old.ended_at<m.ended_at
         and old.ended_at>m.ended_at-interval '7 days' and mate=any(old.co_players))
       and not exists(select 1 from public.council_match_records used
         where used.user_id=p_user and used.week=wk and used.reunion
           and mate=any(used.co_players))) into reunion_credit;

  insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,
      reunion,co_players,eligible,human_count,group_fingerprint)
    values(p_user,p_room,m.ended_at,d,wk,v_team,v_team=m.outcome,
      m.host_id is not distinct from p_user,reunion_credit,mates,
      rec.user_id is not null,least(humans,20),coalesce(left(rec.roster_fingerprint,32),''))
    on conflict do nothing;
  get diagnostics n=row_count;
  if n=0 then return false; end if;
  insert into public.council_identity(user_id,name,gender,updated_at)
    values(p_user,left(btrim(m.name),40),coalesce(m.gender,'unspecified'),now())
    on conflict(user_id) do update set name=excluded.name,gender=excluded.gender,
      updated_at=now() where council_identity.updated_at<=excluded.updated_at;
  perform public.casebook_record_match(p_user,p_room);
  return true;
end $$;

-- Council XP comes from the receipt (30, +20 on a win); a record without a
-- receipt is not eligible and earns none.
alter function public.council_grant_xp(uuid) rename to council_grant_xp_pre_v3;
create function public.council_grant_xp(p_user uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare rec public.council_match_records; earned int;
begin
  if not public.economy_v3_on() then perform public.council_grant_xp_pre_v3(p_user); return; end if;
  if not public.council_on('rank') then return; end if;
  for rec in select * from public.council_match_records
      where user_id=p_user and xp is null order by ended_at,room_id loop
    select council_xp into earned from public.match_receipts
     where user_id=p_user and room_id=rec.room_id;
    earned:=coalesce(earned,0);
    insert into public.council_xp_events(user_id,source_key,xp,week)
      values(p_user,'match:'||rec.room_id,earned,rec.week) on conflict do nothing;
    update public.council_match_records set xp=earned
     where user_id=p_user and room_id=rec.room_id;
  end loop;
end $$;

-- Season XP comes from the receipt (5, +5 on a win). Written before the older
-- recorder, whose own 20/30 row then meets the primary key and does nothing.
alter function public.casebook_record_match(uuid,uuid) rename to casebook_record_match_pre_v3;
create function public.casebook_record_match(p_user uuid,p_room uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare rec public.match_receipts; season bigint;
begin
  if public.economy_v3_on() then
    select * into rec from public.match_receipts where user_id=p_user and room_id=p_room;
    if found then
      select id into season from public.mission_seasons
       where active and rec.ended_at>=starts_at and rec.ended_at<ends_at
       order by starts_at desc limit 1;
      if season is not null then
        insert into public.season_xp_events(user_id,season_id,source_key,xp,created_at)
          values(p_user,season,'match:'||p_room,rec.season_xp,rec.ended_at)
          on conflict do nothing;
      end if;
    end if;
  end if;
  perform public.casebook_record_match_pre_v3(p_user,p_room);
end $$;

-- Invite reads settle first (both wallets locked), then report v3 progress.
alter function public.council_invite(uuid) rename to council_invite_pre_v3;
create function public.council_invite(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare base jsonb; locked uuid[]; season bigint;
begin
  if not public.economy_v3_on() then return public.council_invite_pre_v3(p_user); end if;
  locked:=public.invite_v3_lock(p_user);
  perform public.sync_player_rewards(p_user);
  perform public.invite_v3_settle(p_user,locked);
  perform public.council_sync(p_user);
  base:=public.council_invite_status(p_user);
  if not coalesce((base->>'enabled')::boolean,false) then return base; end if;
  season:=public.invite_v3_season();
  return base||jsonb_build_object(
    'inviterCoins',100,'inviteeCoins',50,
    'v3',jsonb_build_object(
      'stages',jsonb_build_object('invitee',50,'first',25,'settlement',75),
      'caps',jsonb_build_object('season',10,'lifetime',40),
      'settledSeason',(select count(*) from public.council_invite_redemptions
        where inviter=p_user and settled_at is not null
          and settled_season is not distinct from season),
      'settledLifetime',(select count(*) from public.council_invite_redemptions
        where inviter=p_user and settled_at is not null),
      'unlocks',coalesce((select jsonb_agg(code order by code) from public.invite_unlocks
        where user_id=p_user),'[]'::jsonb),
      'notices',coalesce((select jsonb_agg(jsonb_build_object('id',id,'kind',kind,'name',name,
          'progress',progress,'coins',coins) order by id)
        from (select * from public.invite_notices where user_id=p_user and seen_at is null
          order by id limit 20) n),'[]'::jsonb)));
end $$;

-- 5. Capability, deletion ------------------------------------------------------------
alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_economy_v3;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.economy_capabilities_pre_economy_v3(p_user);
  if not public.economy_v3_on() then return base; end if;
  return base||jsonb_build_object('economy',
    coalesce(base->'economy','{}'::jsonb)||jsonb_build_object('version',3));
end $$;

alter function public.complete_data_deletion(uuid) rename to complete_data_deletion_pre_economy_v3;
create function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests
   where id=p_request and completed_at is null;
  perform public.complete_data_deletion_pre_economy_v3(p_request);
  if who is not null then
    delete from public.match_receipts where user_id=who;
    delete from public.invite_notices where user_id=who or invitee=who;
    delete from public.invite_unlocks where user_id=who;
  end if;
end $$;

alter function public.purge_orphan_economy() rename to purge_orphan_economy_pre_economy_v3;
create function public.purge_orphan_economy()
returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  delete from public.match_receipts d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.invite_notices d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.invite_unlocks d where not exists(select 1 from auth.users u where u.id=d.user_id);
  perform public.purge_economy_roster_salts();
  return public.purge_orphan_economy_pre_economy_v3();
end $$;

-- 6. Grants ----------------------------------------------------------------------------
revoke all on function public.economy_v3_on() from public,anon,authenticated;
grant execute on function public.economy_v3_on() to service_role;
revoke all on function public.economy_roster_fingerprint(uuid,date) from public,anon,authenticated;
grant execute on function public.economy_roster_fingerprint(uuid,date) to service_role;
revoke all on function public.purge_economy_roster_salts() from public,anon,authenticated;
grant execute on function public.purge_economy_roster_salts() to service_role;
revoke all on function public.match_receipt_immutable() from public,anon,authenticated;
grant execute on function public.match_receipt_immutable() to service_role;
revoke all on function public.economy_v3_issue_receipt(uuid,uuid) from public,anon,authenticated;
grant execute on function public.economy_v3_issue_receipt(uuid,uuid) to service_role;
revoke all on function public.economy_v3_settle_receipt(uuid,uuid) from public,anon,authenticated;
grant execute on function public.economy_v3_settle_receipt(uuid,uuid) to service_role;
revoke all on function public.invite_v3_season() from public,anon,authenticated;
grant execute on function public.invite_v3_season() to service_role;
revoke all on function public.invite_v3_wallets(uuid) from public,anon,authenticated;
grant execute on function public.invite_v3_wallets(uuid) to service_role;
revoke all on function public.invite_v3_lock(uuid) from public,anon,authenticated;
grant execute on function public.invite_v3_lock(uuid) to service_role;
revoke all on function public.invite_v3_settle(uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.invite_v3_settle(uuid,uuid[]) to service_role;
revoke all on function public.invite_notices_ack(uuid,bigint[]) from public,anon,authenticated;
grant execute on function public.invite_notices_ack(uuid,bigint[]) to service_role;
revoke all on function public.sync_player_rewards_pre_v3(uuid) from public,anon,authenticated;
grant execute on function public.sync_player_rewards_pre_v3(uuid) to service_role;
revoke all on function public.sync_player_rewards(uuid) from public,anon,authenticated;
grant execute on function public.sync_player_rewards(uuid) to service_role;
revoke all on function public.council_record_match_pre_v3(uuid,uuid) from public,anon,authenticated;
grant execute on function public.council_record_match_pre_v3(uuid,uuid) to service_role;
revoke all on function public.council_record_match(uuid,uuid) from public,anon,authenticated;
grant execute on function public.council_record_match(uuid,uuid) to service_role;
revoke all on function public.council_grant_xp_pre_v3(uuid) from public,anon,authenticated;
grant execute on function public.council_grant_xp_pre_v3(uuid) to service_role;
revoke all on function public.council_grant_xp(uuid) from public,anon,authenticated;
grant execute on function public.council_grant_xp(uuid) to service_role;
revoke all on function public.casebook_record_match_pre_v3(uuid,uuid) from public,anon,authenticated;
grant execute on function public.casebook_record_match_pre_v3(uuid,uuid) to service_role;
revoke all on function public.casebook_record_match(uuid,uuid) from public,anon,authenticated;
grant execute on function public.casebook_record_match(uuid,uuid) to service_role;
revoke all on function public.council_invite_pre_v3(uuid) from public,anon,authenticated;
grant execute on function public.council_invite_pre_v3(uuid) to service_role;
revoke all on function public.council_invite(uuid) from public,anon,authenticated;
grant execute on function public.council_invite(uuid) to service_role;
revoke all on function public.economy_capabilities_pre_economy_v3(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_economy_v3(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
revoke all on function public.complete_data_deletion_pre_economy_v3(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion_pre_economy_v3(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
revoke all on function public.purge_orphan_economy_pre_economy_v3() from public,anon,authenticated;
grant execute on function public.purge_orphan_economy_pre_economy_v3() to service_role;
revoke all on function public.purge_orphan_economy() from public,anon,authenticated;
grant execute on function public.purge_orphan_economy() to service_role;
