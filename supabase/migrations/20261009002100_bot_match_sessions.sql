create table public.bot_match_sessions(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  consumed_at timestamptz
);
alter table public.bot_match_sessions enable row level security;
revoke all on public.bot_match_sessions from public,anon,authenticated;
grant select,insert,update on public.bot_match_sessions to service_role;

create function public.start_bot_match(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare session_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('bot_win:' || p_user::text));
  delete from public.bot_match_sessions where user_id=p_user;
  insert into public.bot_match_sessions(user_id) values(p_user) returning id into session_id;
  return jsonb_build_object('sessionId',session_id);
end $$;

create function public.claim_bot_win(p_user uuid,p_session uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := (now() at time zone 'utc')::date; k int; coins int := 25;
  session_row public.bot_match_sessions;
begin
  perform pg_advisory_xact_lock(hashtext('bot_win:' || p_user::text));
  select * into session_row from public.bot_match_sessions
    where id=p_session and user_id=p_user for update;
  -- One-phone bot discussions can be skipped; five minutes would deny quick wins.
  if not found or session_row.consumed_at is not null
      or session_row.started_at > now()-interval '1 minute' then
    return jsonb_build_object('granted',0,'balance',
      (select balance from public.wallet_accounts where user_id=p_user));
  end if;
  update public.bot_match_sessions set consumed_at=now() where id=p_session;
  select coalesce(max(n),0)+1 into k from public.bot_wins where user_id=p_user and day=today;
  if k>5 then
    return jsonb_build_object('granted',0,'left',0,
      'balance',(select balance from public.wallet_accounts where user_id=p_user));
  end if;
  insert into public.bot_wins(user_id,day,n) values(p_user,today,k);
  perform public.credit_earned(p_user,'bot_win',coins,null,'bot:'||today||':'||k);
  return jsonb_build_object('granted',coins,'left',5-k,
    'balance',(select balance from public.wallet_accounts where user_id=p_user));
end $$;
revoke all on function public.start_bot_match(uuid) from public,anon,authenticated;
grant execute on function public.start_bot_match(uuid) to service_role;
revoke all on function public.claim_bot_win(uuid,uuid) from public,anon,authenticated;
grant execute on function public.claim_bot_win(uuid,uuid) to service_role;
revoke all on function public.claim_bot_win(uuid) from public,anon,authenticated,service_role;
drop function public.claim_bot_win(uuid);
