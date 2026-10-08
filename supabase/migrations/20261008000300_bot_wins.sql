-- «العب ضد البوتات»: a win against bots pays 25 coins, five times a UTC day.
-- The match is played on the device, so the server can only cap it.
create table if not exists public.bot_wins(
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  n int not null check (n between 1 and 5),
  at timestamptz not null default now(),
  primary key (user_id, day, n)
);
alter table public.bot_wins enable row level security;

do $$
declare kinds text[];
begin
  select coalesce(array_agg(distinct m[1]), '{}') into kinds
    from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z0-9_]+)''', 'g') m
   where c.conname='wallet_ledger_kind_check' and c.conrelid='public.wallet_ledger'::regclass;
  select array_agg(distinct k order by k) into kinds from unnest(kinds || array['bot_win']) k;
  alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
  execute format('alter table public.wallet_ledger add constraint wallet_ledger_kind_check '
    'check (kind in (%s))', (select string_agg(quote_literal(k), ',' order by k) from unnest(kinds) k));
end $$;

create or replace function public.claim_bot_win(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := (now() at time zone 'utc')::date; k int; coins int := 25;
begin
  perform pg_advisory_xact_lock(hashtext('bot_win:' || p_user::text));
  select coalesce(max(n), 0) + 1 into k from public.bot_wins where user_id = p_user and day = today;
  if k > 5 then
    return jsonb_build_object('granted', 0, 'left', 0,
      'balance', (select balance from public.wallet_accounts where user_id = p_user));
  end if;
  insert into public.bot_wins(user_id, day, n) values (p_user, today, k);
  perform public.credit_earned(p_user, 'bot_win', coins, null, 'bot:' || today || ':' || k);
  return jsonb_build_object('granted', coins, 'left', 5 - k,
    'balance', (select balance from public.wallet_accounts where user_id = p_user));
end $$;
revoke all on function public.claim_bot_win(uuid) from public, anon, authenticated;
grant execute on function public.claim_bot_win(uuid) to service_role;
