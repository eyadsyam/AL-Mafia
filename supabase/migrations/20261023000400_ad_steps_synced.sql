-- The post-match ad multiplies the match's own reward. Before that reward is
-- on the wallet (not synced yet, or a match that earns none) the offer used to
-- read "100 / 200 / 300" and the claim then failed. `synced` says which it is;
-- the amounts are unchanged for every caller that does not read it.
create or replace function public.ad_steps_status_v2(p_user uuid, p_room uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare legacy public.ad_reward_claims; base bigint; steps jsonb; synced boolean;
begin
  select * into legacy from public.ad_reward_claims where user_id=p_user and room_id=p_room;
  if legacy.id is not null then
    -- A 1.0.0 claim already decides this match: resume it as one ad.
    return jsonb_build_object('scheme','v1','claimId',legacy.id,'state',legacy.state,
      'amount',legacy.base_amount);
  end if;
  select amount into base from public.wallet_ledger
   where user_id=p_user and source_room=p_room and kind='match_completion';
  synced := base is not null;
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
    'double',base*2,'triple',base*3,'steps',steps,'synced',synced);
end $$;
revoke all on function public.ad_steps_status_v2(uuid,uuid) from public, anon, authenticated;
grant execute on function public.ad_steps_status_v2(uuid,uuid) to service_role;
