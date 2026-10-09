begin;
do $$
declare old_user uuid:=gen_random_uuid(); old_peer uuid:=gen_random_uuid();
  new_user uuid:=gen_random_uuid();
  anon_user uuid:=gen_random_uuid(); today date:=public.economy_today();
begin
  insert into auth.users(id,created_at,is_anonymous) values
    (old_user,now()-interval '3 days',false),
    (old_peer,now()-interval '3 days',false),
    (new_user,now(),false),
    (anon_user,now()-interval '3 days',true);
  assert public.economy_global_cap_member(old_user),'mature account counts';
  assert not public.economy_global_cap_member(new_user),'new account excluded';
  assert not public.economy_global_cap_member(anon_user),'anonymous account excluded';
  update public.economy_config set daily_enabled=true,daily_global_cap=1;
  insert into public.daily_claims(user_id,day,kind,amount)
    values(new_user,today,'coffer',1),(anon_user,today,'coffer',1);
  assert public.daily_guard(old_user,today,'coffer')=today,'excluded accounts do not exhaust cap';
  insert into public.daily_claims(user_id,day,kind,amount)
    values(old_user,today,'coffer',1);
  begin
    perform public.daily_guard(old_user,today,'coffer');
    raise exception 'mature cap ignored';
  exception when others then
    assert sqlerrm='DAILY_PAUSED',sqlerrm;
  end;
  assert public.daily_guard(new_user,today,'coffer')=today,'new account retains own allowance';
  update public.economy_config set ad_extras_enabled=true;
  insert into public.daily_claims(user_id,day,kind,amount)
    values(old_peer,today,'coffer',1);
  perform public.create_ad_extra_claim(new_user,today,'coffer');
  perform public.create_ad_extra_claim(anon_user,today,'coffer');
  perform public.create_ad_extra_claim(old_user,today,'coffer');
  begin
    perform public.create_ad_extra_claim(old_peer,today,'coffer');
    raise exception 'ad extra cap ignored';
  exception when others then
    assert sqlerrm='DAILY_PAUSED',sqlerrm;
  end;
end $$;
rollback;
