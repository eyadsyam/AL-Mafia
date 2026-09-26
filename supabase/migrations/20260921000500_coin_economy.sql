-- Earned-only launch economy. Balances are server authoritative and cannot
-- change match state. No cash value, transfer or random paid reward exists.
create table public.wallet_accounts (
  user_id uuid primary key,
  balance bigint not null default 0 check(balance>=0),
  lifetime_earned bigint not null default 0 check(lifetime_earned>=0),
  lifetime_spent bigint not null default 0 check(lifetime_spent>=0),
  updated_at timestamptz not null default now()
);
create table public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  kind text not null check(kind in ('match_completion','match_win','catalog_spend','operator_adjustment','ad_reward','purchase')),
  amount bigint not null check(amount<>0),
  source_room uuid,
  item_code text,
  created_at timestamptz not null default now()
);
create unique index wallet_match_reward_once on public.wallet_ledger(user_id,kind,source_room)
  where source_room is not null;
create index wallet_ledger_user_time on public.wallet_ledger(user_id,created_at desc);

create table public.reward_catalog (
  code text primary key check(code~'^[a-z0-9_]{3,40}$'),
  coin_price bigint not null check(coin_price>0),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create table public.player_inventory (
  user_id uuid not null,
  item_code text not null references public.reward_catalog(code),
  acquired_at timestamptz not null default now(),
  primary key(user_id,item_code)
);

alter table public.wallet_accounts enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.reward_catalog enable row level security;
alter table public.player_inventory enable row level security;
revoke all on public.wallet_accounts,public.wallet_ledger,public.reward_catalog,public.player_inventory from public,anon,authenticated;
grant all on public.wallet_accounts,public.wallet_ledger,public.reward_catalog,public.player_inventory to service_role;

insert into public.reward_catalog(code,coin_price,sort_order)
values('mastermind_guide',400,10) on conflict(code) do update
set coin_price=excluded.coin_price,active=true,sort_order=excluded.sort_order;

create or replace function public.wallet_snapshot(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare amount bigint; items jsonb; owned jsonb;
begin
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  select balance into amount from public.wallet_accounts where user_id=p_user;
  select coalesce(jsonb_agg(jsonb_build_object('code',code,'price',coin_price) order by sort_order,code),'[]')
    into items from public.reward_catalog where active;
  select coalesce(jsonb_agg(item_code order by item_code),'[]') into owned
    from public.player_inventory where user_id=p_user;
  return jsonb_build_object('balance',amount,'catalog',items,'owned',owned);
end $$;
revoke all on function public.wallet_snapshot(uuid) from public,anon,authenticated;
grant execute on function public.wallet_snapshot(uuid) to service_role;

create or replace function public.sync_player_rewards(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare candidate record; inserted_count integer; reward bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  for candidate in
    select r.id,r.ended_at,p.role,s.public_data->>'outcome' as outcome
    from public.rooms r join public.room_players p on p.room_id=r.id
      join public.room_state s on s.room_id=r.id
    where p.user_id=p_user and not p.kicked and p.role is not null
      and r.status='finished' and r.ended_at is not null
      and s.public_data->>'outcome' in ('mafia','town')
  loop
    insert into public.wallet_ledger(user_id,kind,amount,source_room)
      values(p_user,'match_completion',100,candidate.id) on conflict do nothing;
    get diagnostics inserted_count=row_count;
    if inserted_count=1 then
      update public.wallet_accounts set balance=balance+100,lifetime_earned=lifetime_earned+100,updated_at=now()
        where user_id=p_user;
    end if;
    reward:=case when (candidate.role='mafia' and candidate.outcome='mafia') or
      (candidate.role<>'mafia' and candidate.outcome='town') then 25 else 0 end;
    if reward>0 then
      insert into public.wallet_ledger(user_id,kind,amount,source_room)
        values(p_user,'match_win',reward,candidate.id) on conflict do nothing;
      get diagnostics inserted_count=row_count;
      if inserted_count=1 then
        update public.wallet_accounts set balance=balance+reward,lifetime_earned=lifetime_earned+reward,updated_at=now()
          where user_id=p_user;
      end if;
    end if;
  end loop;
  return public.wallet_snapshot(p_user);
end $$;
revoke all on function public.sync_player_rewards(uuid) from public,anon,authenticated;
grant execute on function public.sync_player_rewards(uuid) to service_role;

create or replace function public.buy_reward_item(p_user uuid,p_item text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare price bigint; inserted_count integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  if exists(select 1 from public.player_inventory where user_id=p_user and item_code=p_item) then
    return public.wallet_snapshot(p_user);
  end if;
  select coin_price into price from public.reward_catalog where code=p_item and active for update;
  if price is null then raise exception 'ITEM_NOT_FOUND'; end if;
  update public.wallet_accounts set balance=balance-price,lifetime_spent=lifetime_spent+price,updated_at=now()
    where user_id=p_user and balance>=price;
  if not found then raise exception 'INSUFFICIENT_COINS'; end if;
  insert into public.player_inventory(user_id,item_code) values(p_user,p_item);
  insert into public.wallet_ledger(user_id,kind,amount,item_code)
    values(p_user,'catalog_spend',-price,p_item);
  return public.wallet_snapshot(p_user);
end $$;
revoke all on function public.buy_reward_item(uuid,text) from public,anon,authenticated;
grant execute on function public.buy_reward_item(uuid,text) to service_role;

-- The existing deletion receipt now covers the persistent economy as promised
-- by the in-app policy. Active rooms still block deletion first.
create or replace function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests where id=p_request and completed_at is null for update;
  if who is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  if exists(select 1 from public.rooms r join public.room_players p on p.room_id=r.id
    where p.user_id=who and r.status<>'finished') then raise exception 'ACTIVE_ROOM'; end if;
  delete from public.rooms where id in (select room_id from public.room_players where user_id=who);
  delete from public.player_blocks where blocker_id=who or blocked_id=who;
  delete from public.player_inventory where user_id=who;
  delete from public.wallet_ledger where user_id=who;
  delete from public.wallet_accounts where user_id=who;
  delete from auth.users where id=who;
  update public.data_deletion_requests set completed_at=now() where id=p_request;
end $$;
revoke all on function public.complete_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
