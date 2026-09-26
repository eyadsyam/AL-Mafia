begin;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid();
  d uuid:=gen_random_uuid(); e uuid:=gen_random_uuid(); n int;
begin
  insert into auth.users(id) values(a),(b),(c),(d),(e);

  -- Purchase, then restore on new identities: allowed three times in 30 days.
  perform public.commit_play_purchase(a,'token-0001','mafia_scenario_mastermind','GPA.1','active',now());
  assert public.user_owns_entitlement(a,'scenario_shadows');
  perform public.commit_play_purchase(b,'token-0001','mafia_scenario_mastermind','GPA.1','active',now());
  assert not public.user_owns_entitlement(a,'scenario_shadows'), 'moved, not duplicated';
  assert public.user_owns_entitlement(b,'scenario_shadows');
  perform public.commit_play_purchase(c,'token-0001','mafia_scenario_mastermind','GPA.1','active',now());
  perform public.commit_play_purchase(d,'token-0001','mafia_scenario_mastermind','GPA.1','active',now());
  -- Same owner re-verifying never counts as a move.
  perform public.commit_play_purchase(d,'token-0001','mafia_scenario_mastermind','GPA.1','active',now());
  begin
    perform public.commit_play_purchase(e,'token-0001','mafia_scenario_mastermind','GPA.1','active',now());
    assert false, 'a fourth move in 30 days must be refused';
  exception when others then
    assert sqlerrm like '%REBIND_LIMIT%', sqlerrm;
  end;
  assert public.user_owns_entitlement(d,'scenario_shadows');

  -- After the window the counter starts again.
  update public.play_purchases set last_rebound_at=now()-interval '31 days' where purchase_token='token-0001';
  perform public.commit_play_purchase(e,'token-0001','mafia_scenario_mastermind','GPA.1','active',now());
  assert public.user_owns_entitlement(e,'scenario_shadows');

  -- A refund found by the voided sync revokes without the player's help.
  n:=public.revoke_voided_play_purchases(array['nope'],array['GPA.1']);
  assert n=1, n::text;
  assert not public.user_owns_entitlement(e,'scenario_shadows');
  assert (select state from public.play_purchases where purchase_token='token-0001')='revoked';
  -- Idempotent.
  assert public.revoke_voided_play_purchases(array['token-0001'],null)=0;

  assert not has_function_privilege('authenticated','public.revoke_voided_play_purchases(text[],text[])','execute');
end $$;
rollback;
