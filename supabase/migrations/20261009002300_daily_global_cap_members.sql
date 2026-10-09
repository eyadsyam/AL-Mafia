create function public.economy_global_cap_member(p_user uuid)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
  select coalesce((select not u.is_anonymous and u.created_at<=now()-interval '48 hours'
    from auth.users u where u.id=p_user),false)
$$;
revoke all on function public.economy_global_cap_member(uuid) from public,anon,authenticated;
grant execute on function public.economy_global_cap_member(uuid) to service_role;

create or replace function public.daily_guard(p_user uuid,p_day date,p_kind text)
returns date language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := public.economy_today(); cfg public.economy_config;
begin
  select * into cfg from public.economy_config;
  if not coalesce(cfg.daily_enabled,false) then raise exception 'FEATURE_OFF'; end if;
  if p_day is null then raise exception 'DAY_REQUIRED'; end if;
  if p_day<>today then raise exception 'DAY_CHANGED'; end if;
  if public.economy_global_cap_member(p_user) and
      (select count(*) from public.daily_claims c where c.day=today and c.kind=p_kind
        and public.economy_global_cap_member(c.user_id))>=cfg.daily_global_cap then
    raise exception 'DAILY_PAUSED';
  end if;
  return today;
end $$;

create or replace function public.claim_council_contract_pre_casebook(p_user uuid,p_day date,p_slot int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; today date := public.economy_today(); c public.council_daily_contracts;
  granted bigint := 0; bonus bigint := 0;
begin
  if p_slot is null or p_slot not between 0 and 2 then raise exception 'BAD_REQUEST'; end if;
  perform public.council_settle_invites(p_user);
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  if not public.council_on('contracts') then raise exception 'FEATURE_OFF'; end if;
  select * into cfg from public.economy_config;
  if p_day is null then raise exception 'DAY_REQUIRED'; end if;
  if p_day<>today then raise exception 'DAY_CHANGED'; end if;
  perform public.council_sync(p_user);
  perform public.council_draw_contracts(p_user,today);
  select * into c from public.council_daily_contracts
   where user_id=p_user and day=today and slot=p_slot for update;
  if c.user_id is null then raise exception 'BAD_REQUEST'; end if;
  if c.claimed_at is null then
    if public.council_metric(p_user,today,c.metric)<c.target then
      raise exception 'CONTRACT_INCOMPLETE';
    end if;
    if public.economy_global_cap_member(p_user) and
        (select count(*) from public.council_daily_contracts d
          where d.day=today and d.claimed_at is not null
            and public.economy_global_cap_member(d.user_id))>=cfg.daily_global_cap*3 then
      raise exception 'DAILY_PAUSED';
    end if;
    update public.council_daily_contracts set claimed_at=now()
     where user_id=p_user and day=today and slot=p_slot;
    if public.credit_earned(p_user,'council_contract',c.coins,null,today::text||':'||p_slot) then
      granted:=c.coins;
    end if;
    if cfg.council_contract_bonus>0 and (select count(*) from public.council_daily_contracts
        where user_id=p_user and day=today and claimed_at is not null)=3 then
      if public.credit_earned(p_user,'council_contract_bonus',cfg.council_contract_bonus,null,today::text) then
        bonus:=cfg.council_contract_bonus;
      end if;
    end if;
  end if;
  return public.council_contracts_status(p_user)||jsonb_build_object('granted',granted,
    'bonusGranted',bonus,'balance',(select balance from public.wallet_accounts where user_id=p_user));
end $$;
revoke all on function public.claim_council_contract_pre_casebook(uuid,date,int) from public,anon,authenticated;
grant execute on function public.claim_council_contract_pre_casebook(uuid,date,int) to service_role;

create or replace function public.create_ad_extra_claim(p_user uuid,p_day date,
  p_kind text,p_slot int default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := public.economy_today(); cfg public.economy_config;
  claim public.ad_extra_claims; box public.daily_claims; amount_ bigint := 0;
  current_row public.council_daily_contracts;
begin
  if p_kind is null or p_kind not in ('spin','coffer','swap') then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into cfg from public.economy_config;
  if not public.ad_extras_on(p_kind) then raise exception 'FEATURE_OFF'; end if;
  if p_day is null then raise exception 'DAY_REQUIRED'; end if;
  if p_day<>today then raise exception 'DAY_CHANGED'; end if;
  if exists(select 1 from public.room_players p join public.rooms r on r.id=p.room_id
      where p.user_id=p_user and not p.kicked and r.status<>'finished') then
    raise exception 'IN_MATCH';
  end if;
  select * into claim from public.ad_extra_claims
   where user_id=p_user and day=today and kind=p_kind for update;
  if claim.id is not null and claim.state='awarded' then
    return jsonb_build_object('claimId',claim.id,'state',claim.state,'kind',claim.kind,
      'amount',claim.amount,'slot',claim.slot,'day',claim.day);
  end if;
  if p_kind='spin' then
    if not exists(select 1 from public.daily_claims where user_id=p_user and day=today
        and kind='wheel') then raise exception 'EXTRA_NOT_READY'; end if;
  elsif p_kind='coffer' then
    select * into box from public.daily_claims where user_id=p_user and day=today and kind='coffer';
    if box.user_id is null then raise exception 'EXTRA_NOT_READY'; end if;
    amount_:=box.amount;
  else
    if p_slot is null or p_slot not between 0 and 2 then raise exception 'BAD_REQUEST'; end if;
    perform public.council_draw_contracts(p_user,today);
    select * into current_row from public.council_daily_contracts
     where user_id=p_user and day=today and slot=p_slot;
    if current_row.user_id is null or current_row.claimed_at is not null
       or (public.ad_swap_candidate(p_user,today,p_slot)).code is null then
      raise exception 'EXTRA_NOT_READY';
    end if;
  end if;
  if claim.id is null then
    if public.economy_global_cap_member(p_user) and
        (select count(*) from public.ad_extra_claims c where c.day=today and c.kind=p_kind
          and public.economy_global_cap_member(c.user_id))>=cfg.daily_global_cap then
      raise exception 'DAILY_PAUSED';
    end if;
    insert into public.ad_extra_claims(user_id,day,kind,slot,amount)
      values(p_user,today,p_kind,case when p_kind='swap' then p_slot end,amount_)
      on conflict(user_id,day,kind) do nothing;
    select * into claim from public.ad_extra_claims
     where user_id=p_user and day=today and kind=p_kind;
  elsif p_kind='swap' and claim.slot is distinct from p_slot then
    update public.ad_extra_claims set slot=p_slot where id=claim.id returning * into claim;
  end if;
  return jsonb_build_object('claimId',claim.id,'state',claim.state,'kind',claim.kind,
    'amount',claim.amount,'slot',claim.slot,'day',claim.day);
end $$;
