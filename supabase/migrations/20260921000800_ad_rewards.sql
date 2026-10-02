-- Rewarded ads double only the verified 100-coin completion reward. The
-- client can request a claim, but only a signed AdMob SSV callback can settle
-- it. One claim and one ledger credit exist per player/match.
create table public.ad_reward_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  room_id uuid not null references public.rooms(id) on delete cascade,
  base_amount bigint not null check(base_amount > 0),
  state text not null default 'pending' check(state in ('pending','awarded')),
  transaction_id text unique,
  ad_unit text,
  reward_amount bigint,
  created_at timestamptz not null default now(),
  awarded_at timestamptz,
  unique(user_id,room_id)
);
create index ad_reward_claim_user_time on public.ad_reward_claims(user_id,created_at desc);
alter table public.ad_reward_claims enable row level security;
revoke all on public.ad_reward_claims from public,anon,authenticated;
grant all on public.ad_reward_claims to service_role;

create or replace function public.create_ad_reward_claim(p_user uuid,p_room uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare base bigint; claim public.ad_reward_claims;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  if not exists(
    select 1 from public.rooms r
    join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
    where r.id=p_room and p.user_id=p_user and not p.kicked and p.role is not null
      and r.status='finished' and r.ended_at is not null
      and s.public_data->>'outcome' in ('mafia','town')
  ) then raise exception 'REWARD_NOT_ELIGIBLE'; end if;

  select amount into base from public.wallet_ledger
    where user_id=p_user and source_room=p_room and kind='match_completion';
  if base is null then raise exception 'REWARD_NOT_SYNCED'; end if;

  insert into public.ad_reward_claims(user_id,room_id,base_amount)
    values(p_user,p_room,base)
    on conflict(user_id,room_id) do update set user_id=excluded.user_id
    returning * into claim;
  return jsonb_build_object(
    'claimId',claim.id,'state',claim.state,'amount',claim.base_amount
  );
end $$;
revoke all on function public.create_ad_reward_claim(uuid,uuid) from public,anon,authenticated;
grant execute on function public.create_ad_reward_claim(uuid,uuid) to service_role;

create or replace function public.ad_reward_status(p_user uuid,p_room uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((
    select jsonb_build_object('claimId',id,'state',state,'amount',base_amount)
    from public.ad_reward_claims where user_id=p_user and room_id=p_room
  ),jsonb_build_object('state','available','amount',100))
$$;
revoke all on function public.ad_reward_status(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ad_reward_status(uuid,uuid) to service_role;

create or replace function public.commit_ad_reward(
  p_claim uuid,p_transaction text,p_ad_unit text,p_reward_amount bigint,p_ssv_user uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare claim public.ad_reward_claims; inserted_count integer;
begin
  if p_transaction is null or length(p_transaction)<8 or p_reward_amount<=0 then
    raise exception 'BAD_SSV';
  end if;
  select * into claim from public.ad_reward_claims where id=p_claim for update;
  if claim.id is null or claim.user_id<>p_ssv_user then raise exception 'CLAIM_NOT_FOUND'; end if;
  if claim.state='awarded' then
    if claim.transaction_id<>p_transaction then raise exception 'CLAIM_ALREADY_USED'; end if;
    return jsonb_build_object('state','awarded','amount',claim.base_amount);
  end if;
  if exists(select 1 from public.ad_reward_claims where transaction_id=p_transaction and id<>p_claim) then
    raise exception 'TRANSACTION_ALREADY_USED';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('wallet:'||claim.user_id::text,91));
  insert into public.wallet_ledger(user_id,kind,amount,source_room)
    values(claim.user_id,'ad_reward',claim.base_amount,claim.room_id)
    on conflict do nothing;
  get diagnostics inserted_count=row_count;
  if inserted_count=1 then
    update public.wallet_accounts
      set balance=balance+claim.base_amount,
          lifetime_earned=lifetime_earned+claim.base_amount,updated_at=now()
      where user_id=claim.user_id;
  end if;
  update public.ad_reward_claims set state='awarded',transaction_id=p_transaction,
    ad_unit=p_ad_unit,reward_amount=p_reward_amount,awarded_at=now()
    where id=claim.id;
  return jsonb_build_object('state','awarded','amount',claim.base_amount);
end $$;
revoke all on function public.commit_ad_reward(uuid,text,text,bigint,uuid) from public,anon,authenticated;
grant execute on function public.commit_ad_reward(uuid,text,text,bigint,uuid) to service_role;

create or replace function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests where id=p_request and completed_at is null for update;
  if who is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  if exists(select 1 from public.rooms r join public.room_players p on p.room_id=r.id
    where p.user_id=who and r.status<>'finished') then raise exception 'ACTIVE_ROOM'; end if;
  delete from public.ad_reward_claims where user_id=who;
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
