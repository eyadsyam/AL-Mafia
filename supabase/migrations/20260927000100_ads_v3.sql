-- Phase 110 "Ads v3": ads per match, never inside a match phase.
--
-- Additive over 20260925000100 / 000500 (neither deployed yet):
-- * Global pacing for every full-screen ad (app-open and interstitials): a
--   safety cap per device per day (default 40, never above 40) and a minimum
--   gap (default 90 s, never below 90 s). The older per-format caps
--   (interstitial_max_per_day / _gap_seconds, app_open_max_per_day /
--   _gap_seconds) stay in the table with their checks but are no longer read
--   by a v3 client; capabilities report the global numbers in their place.
-- * Three new placements, each OFF by default and missing config = off:
--   pre-match (Create / Join / rematch, before the lobby), pass-and-play
--   (before the deal and after the result) and the session interstitial
--   (after >= 5 minutes on menus, only on a navigation between menus).
-- * The post-match rewarded offer becomes "double, then triple": ad 1 adds
--   100% of the match's completion coins (x2 total), optional ad 2 adds
--   another 100% (x3 total). Same table, same `s2:` SSV route, same ledger
--   kinds (ad_step_1 / ad_step_2), same ordering and idempotency; only the
--   amount of a NEW step claim changes. The 1.0.0 one-ad claim
--   (create_ad_claim / commit_ad_reward) is untouched.
-- Nothing here reads or writes match state.

-- 0. Configuration -----------------------------------------------------------
alter table public.economy_config
  add column if not exists full_screen_max_per_day int not null default 40
    check (full_screen_max_per_day between 0 and 40),
  add column if not exists full_screen_min_gap_seconds int not null default 90
    check (full_screen_min_gap_seconds between 90 and 86400),
  add column if not exists pre_match_interstitial_enabled boolean not null default false,
  add column if not exists pass_and_play_interstitial_enabled boolean not null default false,
  add column if not exists session_interstitial_enabled boolean not null default false,
  add column if not exists session_interstitial_after_seconds int not null default 300
    check (session_interstitial_after_seconds between 300 and 86400);

-- 1. Post-match reward: x2 then x3 ------------------------------------------
-- Each step is worth the whole base. A step row created earlier keeps its
-- own immutable amount (ad_claim_immutable); only new rows use the new rule.
create or replace function public.ad_steps_status_v2(p_user uuid, p_room uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare legacy public.ad_reward_claims; base bigint; steps jsonb;
begin
  select * into legacy from public.ad_reward_claims where user_id=p_user and room_id=p_room;
  if legacy.id is not null then
    -- A 1.0.0 claim already decides this match: resume it as one ad.
    return jsonb_build_object('scheme','v1','claimId',legacy.id,'state',legacy.state,
      'amount',legacy.base_amount);
  end if;
  select amount into base from public.wallet_ledger
   where user_id=p_user and source_room=p_room and kind='match_completion';
  base := coalesce(base, 100);
  select jsonb_agg(jsonb_build_object(
      'step', n,
      'amount', coalesce(c.amount, base),
      'multiplier', n+1,
      'totalAfter', base*(n+1),
      'state', coalesce(c.state,'available'),
      'claimId', c.id) order by n)
    into steps
    from (values (1),(2)) v(n)
    left join public.ad_step_claims c on c.user_id=p_user and c.room_id=p_room and c.step=v.n;
  return jsonb_build_object('scheme','steps','mode','multiply','base',base,'total',base,
    'double',base*2,'triple',base*3,'steps',steps);
end $$;

create or replace function public.create_ad_step_claim_v2(p_user uuid, p_room uuid, p_step int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare base bigint; claim public.ad_step_claims;
begin
  if p_step not in (1,2) then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  -- A missing config row reads as off, never on.
  if not coalesce((select ad_steps_enabled from public.economy_config), false) then
    raise exception 'FEATURE_OFF';
  end if;
  if exists(select 1 from public.ad_reward_claims where user_id=p_user and room_id=p_room) then
    return public.ad_steps_status_v2(p_user,p_room);
  end if;
  if not public.ad_reward_eligible(p_user,p_room) then raise exception 'REWARD_NOT_ELIGIBLE'; end if;
  select amount into base from public.wallet_ledger
   where user_id=p_user and source_room=p_room and kind='match_completion';
  if base is null then raise exception 'REWARD_NOT_SYNCED'; end if;
  if p_step=2 and not exists(select 1 from public.ad_step_claims
      where user_id=p_user and room_id=p_room and step=1 and state='awarded') then
    raise exception 'STEP_ORDER';
  end if;
  insert into public.ad_step_claims(user_id,room_id,step,base_amount,amount)
    values(p_user,p_room,p_step,base,base)
    on conflict (user_id,room_id,step) do nothing;
  select * into claim from public.ad_step_claims
   where user_id=p_user and room_id=p_room and step=p_step;
  return public.ad_steps_status_v2(p_user,p_room)
    || jsonb_build_object('claimId',claim.id,'step',claim.step,'claimState',claim.state);
end $$;

-- 2. Capabilities --------------------------------------------------------------
-- `interstitial` now carries every automatic placement plus the global
-- pacing; `ads.fullScreen` repeats the pacing for the app-open ad.
alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_v3;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; base jsonb; pacing jsonb;
begin
  select * into cfg from public.economy_config;
  base := public.economy_capabilities_pre_v3(p_user);
  pacing := jsonb_build_object(
    'maxPerDay', coalesce(cfg.full_screen_max_per_day, 0),
    'gapSeconds', coalesce(cfg.full_screen_min_gap_seconds, 90));
  return base || jsonb_build_object(
    'adStepsMode', 'multiply',
    'interstitial', pacing || jsonb_build_object(
      'version', 3,
      'enabled', coalesce(cfg.interstitial_enabled, false),
      'preMatch', coalesce(cfg.pre_match_interstitial_enabled, false),
      'passAndPlay', coalesce(cfg.pass_and_play_interstitial_enabled, false),
      'session', coalesce(cfg.session_interstitial_enabled, false),
      'sessionAfterSeconds', coalesce(cfg.session_interstitial_after_seconds, 300),
      'afterRewardSeconds', coalesce(cfg.interstitial_after_reward_seconds, 180),
      'graceMatches', coalesce(cfg.interstitial_grace_matches, 1)),
    'ads', coalesce(base->'ads', '{}'::jsonb) || jsonb_build_object(
      'fullScreen', pacing,
      'appOpen', jsonb_build_object('enabled', coalesce(cfg.app_open_enabled, false),
        'resumeAfterSeconds', coalesce(cfg.app_open_resume_after_seconds, 14400))));
end $$;

revoke all on function public.economy_capabilities_pre_v3(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities_pre_v3(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
revoke all on function public.ad_steps_status_v2(uuid,uuid) from public, anon, authenticated;
grant execute on function public.ad_steps_status_v2(uuid,uuid) to service_role;
revoke all on function public.create_ad_step_claim_v2(uuid,uuid,int) from public, anon, authenticated;
grant execute on function public.create_ad_step_claim_v2(uuid,uuid,int) to service_role;
