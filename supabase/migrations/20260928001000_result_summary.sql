-- D7 — one call when a match ends, not four from every seat at once.
--
-- The result screen used to fire `sync`, then `contracts_get` and `rank_get`,
-- then the Casebook hub: four Edge calls per player, forty-odd from a ten-seat
-- room in the same second. `result_summary` does the same work in one
-- transaction and returns what the screen reads. Every part is the existing,
-- idempotent function, so a retried summary records nothing twice.

create function public.result_summary(p_user uuid) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare contracts jsonb; rank jsonb; hub jsonb;
begin
  perform public.sync_player_rewards(p_user);
  contracts := case when public.council_on('contracts')
    then public.council_contracts(p_user) else jsonb_build_object('enabled',false) end;
  rank := case when public.council_on('rank')
    then public.council_rank(p_user) else jsonb_build_object('enabled',false) end;
  hub := public.mission_hub(p_user);
  return jsonb_build_object('ok',true,'contracts',contracts,'rank',rank,'hub',hub);
end $$;
revoke all on function public.result_summary(uuid) from public,anon,authenticated;
grant execute on function public.result_summary(uuid) to service_role;
