-- Owner B2 decision: public match awards still pay coins under Economy v3.
begin;

create function pg_temp.lb_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u, u::text||'@launch-audit-b.test', now(), false);
  return u;
end $$;

do $$
declare p uuid[] := array[pg_temp.lb_user(),pg_temp.lb_user(),pg_temp.lb_user(),
    pg_temp.lb_user(),pg_temp.lb_user()];
  r uuid := gen_random_uuid(); i int; s jsonb; before_balance bigint;
begin
  update public.economy_config set economy_v11_enabled=true,
    awards_enabled=true, award_mvp_coins=15, award_coins=5;
  insert into public.rooms(id,code,host_id,status,ended_at,match_seed)
    values(r,'LB2PAY',p[1],'finished',now(),1);
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role,kicked,alive)
      values(r,p[i],i-1,'Player '||i,
        case when i=1 then 'mafia' when i=2 then 'doctor'
             when i=3 then 'detective' else 'citizen' end,false,i>1);
  end loop;
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r,'result',1,jsonb_build_object('outcome','town'));
  select coalesce(balance,0) into before_balance
    from public.wallet_accounts where user_id=p[4];
  before_balance := coalesce(before_balance,0);
  s := public.match_awards_get(p[4],r);
  assert s->>'ready'='true' and (s->>'granted')::int>0, s::text;
  assert exists(select 1 from jsonb_array_elements(s->'awards') a
      where (a->>'coins')::int>0), s::text;
  assert (select balance from public.wallet_accounts where user_id=p[4])
    = before_balance+(s->>'granted')::int, 'award balance';
  assert exists(select 1 from public.wallet_ledger where user_id=p[4]
      and kind='match_award' and source_room=r), 'award ledger';
  s := public.match_awards_get(p[4],r);
  assert (s->>'granted')::int=0, 'award replay credited twice';
  assert (select count(*) from public.wallet_ledger where user_id=p[4]
      and kind='match_award' and source_room=r)=1, 'duplicate ledger';
end $$;
rollback;
