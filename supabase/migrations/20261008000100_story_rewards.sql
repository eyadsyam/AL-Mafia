-- «قصص»: the first solve of each story pays coins and season XP, once per
-- player per story. Amounts live here, by difficulty; the client only names
-- the story it solved.

create table if not exists public.story_rewards(
  story_id text primary key,
  coins int not null check (coins > 0),
  xp int not null check (xp >= 0)
);
alter table public.story_rewards enable row level security;

create table if not exists public.story_solves(
  user_id uuid not null references auth.users(id) on delete cascade,
  story_id text not null references public.story_rewards(story_id),
  solved_at timestamptz not null default now(),
  primary key (user_id, story_id)
);
alter table public.story_solves enable row level security;

-- Difficulty 3 = 60 coins / 40 XP, 4 = 120 / 80, 5 = 250 / 150.
insert into public.story_rewards(story_id, coins, xp) values
  ('2asr_garden_city',250,150),('beit_el_3eila',250,150),('cinema_rivoli',120,80),
  ('el_akh_el_taw2am',250,150),('el_arousa',60,40),('el_asansir',120,80),
  ('el_atr_el_akheer',60,40),('el_gareema_elly_ma7asaletsh',120,80),('el_gazzar',60,40),
  ('el_madina_el_gam3eya',60,40),('el_oda_el_mafoola',250,150),('el_shahed_el_a3ma',120,80),
  ('el_sheikh_el_mo3aleg',60,40),('farah_el_sotouh',60,40),('fondo2_shepheard',120,80),
  ('khaznet_el_bank',250,150),('mahal_el_dahab',60,40),('mat7af_el_zamalek',120,80),
  ('matba3et_el_gornal',120,80),('mazad_el_3arabeyat',60,40),('qahwet_el_moallem',60,40),
  ('sayyad_el_borollos',60,40),('shoqaq_el_tamleek',60,40),('waraqet_el_yanaseeb',60,40)
on conflict (story_id) do update set coins = excluded.coins, xp = excluded.xp;

do $$
declare kinds text[];
begin
  select coalesce(array_agg(distinct m[1]), '{}') into kinds
    from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z0-9_]+)''', 'g') m
   where c.conname='wallet_ledger_kind_check' and c.conrelid='public.wallet_ledger'::regclass;
  select array_agg(distinct k order by k) into kinds from unnest(kinds || array['story_first_solve']) k;
  alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
  execute format('alter table public.wallet_ledger add constraint wallet_ledger_kind_check '
    'check (kind in (%s))', (select string_agg(quote_literal(k), ',' order by k) from unnest(kinds) k));
end $$;

create or replace function public.claim_story_reward(p_user uuid, p_story text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.story_rewards; n int; xp int := 0;
begin
  select * into r from public.story_rewards where story_id = p_story;
  if not found then raise exception 'NOT_FOUND'; end if;
  insert into public.story_solves(user_id, story_id) values (p_user, p_story)
    on conflict do nothing;
  get diagnostics n = row_count;
  if n = 1 then
    perform public.credit_earned(p_user, 'story_first_solve', r.coins, null, 'story:' || p_story);
    xp := public.casebook_grant_season_xp(p_user, 'story:' || p_story, r.xp);
  end if;
  return jsonb_build_object(
    'granted', case when n = 1 then r.coins else 0 end,
    'xpGranted', xp,
    'balance', (select balance from public.wallet_accounts where user_id = p_user));
end $$;

revoke all on function public.claim_story_reward(uuid,text) from public, anon, authenticated;
grant execute on function public.claim_story_reward(uuid,text) to service_role;
