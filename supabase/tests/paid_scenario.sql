begin;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); snap jsonb;
begin
  insert into auth.users(id) values(a),(b);
  snap:=public.commit_play_purchase(a,'token-active-123','mafia_scenario_mastermind','order-1','active',now());
  assert snap->'owned' ? 'scenario_shadows';
  assert public.user_owns_entitlement(a,'scenario_shadows');
  snap:=public.commit_play_purchase(b,'token-active-123','mafia_scenario_mastermind','order-1','active',now());
  assert not public.user_owns_entitlement(a,'scenario_shadows');
  assert public.user_owns_entitlement(b,'scenario_shadows');
  snap:=public.commit_play_purchase(b,'token-active-123','mafia_scenario_mastermind','order-1','revoked',now());
  assert not public.user_owns_entitlement(b,'scenario_shadows');
end $$;
rollback;
