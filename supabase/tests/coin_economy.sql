begin;
do $$ declare u uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); r uuid; deletion uuid; first jsonb; second jsonb; reward text; price bigint;
begin
  -- Runs before and after the guide retires; exercise an actual active item.
  select code,coin_price into strict reward,price from public.reward_catalog
    where active and coin_price>125 order by coin_price,code limit 1;
  insert into public.rooms(code,host_id,match_seed,status,started_at,ended_at)
    values('C2N5A7',u,9,'finished',now()-interval '5 minutes',now()) returning id into r;
  insert into public.room_state(room_id,phase,public_data) values(r,'result','{"outcome":"town"}');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,kicked) values
    (r,u,'Dead citizen',0,'citizen',false,false),(r,other,'Mafia',1,'mafia',true,false);
  first:=public.sync_player_rewards(u);
  second:=public.sync_player_rewards(u);
  if (first->>'balance')::bigint<>125 or second<>first then raise exception 'reward idempotency failed'; end if;
  if (select count(*)<>2 from public.wallet_ledger where user_id=u) then raise exception 'ledger duplicate'; end if;
  begin
    perform public.buy_reward_item(u,reward);
    raise exception 'insufficient purchase accepted';
  exception when others then if sqlerrm<>'INSUFFICIENT_COINS' then raise; end if; end;
  update public.wallet_accounts set balance=price,lifetime_earned=price where user_id=u;
  first:=public.buy_reward_item(u,reward);
  second:=public.buy_reward_item(u,reward);
  if (first->>'balance')::bigint<>0 or second<>first then raise exception 'purchase idempotency failed'; end if;
  if (select count(*)<>1 from public.player_inventory where user_id=u) then raise exception 'inventory duplicate'; end if;
  insert into public.data_deletion_requests(user_id) values(u) returning id into deletion;
  perform public.complete_data_deletion(deletion);
  if exists(select 1 from public.wallet_accounts where user_id=u) or
     exists(select 1 from public.wallet_ledger where user_id=u) or
     exists(select 1 from public.player_inventory where user_id=u) then
    raise exception 'economy data survived deletion';
  end if;
end $$;
rollback;
