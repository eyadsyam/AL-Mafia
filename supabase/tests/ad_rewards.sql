begin;
do $$
declare u uuid:=gen_random_uuid(); r uuid:=gen_random_uuid(); c jsonb; before_balance bigint;
begin
  insert into auth.users(id) values(u);
  insert into rooms(id,code,host_id,status,ended_at,match_seed)
    values(r,'ADTEST',u,'finished',now(),1);
  insert into room_players(room_id,user_id,seat,name,role,kicked) values(r,u,0,'A','citizen',false);
  insert into room_state(room_id,phase,phase_number,public_data)
    values(r,'result',1,jsonb_build_object('outcome','town'));
  perform public.sync_player_rewards(u);
  select balance into before_balance from wallet_accounts where user_id=u;
  c:=public.create_ad_reward_claim(u,r);
  assert c->>'state'='pending';
  perform public.commit_ad_reward((c->>'claimId')::uuid,'transaction-123','unit',1,u);
  assert (select balance from wallet_accounts where user_id=u)=before_balance+100;
  perform public.commit_ad_reward((c->>'claimId')::uuid,'transaction-123','unit',1,u);
  assert (select balance from wallet_accounts where user_id=u)=before_balance+100;
  begin
    perform public.commit_ad_reward((c->>'claimId')::uuid,'transaction-other','unit',1,u);
    raise exception 'expected replay refusal';
  exception when others then
    assert sqlerrm='CLAIM_ALREADY_USED';
  end;
end $$;
rollback;
