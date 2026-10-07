-- «أدوات القعدة» — consumable in-match tools (docs/plans/STORE-ROLES-STORIES-PLAN.md, v3).
--
-- A tool is bought in charges (packs of 1, 3 or 7) and spent inside an online
-- match. The server owns everything: the price, the charge, the per-match
-- limits and the record of every use. The match functions read
-- `room_tool_uses` to apply an effect; nothing a client sends decides one.

create table if not exists public.table_tools (
  code text primary key,
  tier text not null check (tier in ('light','medium','heavy')),
  coin_price bigint not null check (coin_price > 0),
  -- Uses of this one tool a single player may make in one match.
  per_match int not null check (per_match between 1 and 2),
  -- Announced without the user's name (the table hears that *someone* used it).
  secret boolean not null default false,
  -- Which phase the tool is used in.
  phase text not null check (phase in ('discuss','vote','night','dead')),
  -- How many target seats the tool takes.
  targets int not null default 0 check (targets between 0 and 3),
  sort_order int not null default 0,
  active boolean not null default true
);

insert into public.table_tools(code,tier,coin_price,per_match,secret,phase,targets,sort_order) values
  ('extra_minute',  'light', 150,2,false,'discuss',0,10),
  ('anon_note',     'light', 180,2,false,'discuss',0,20),
  ('last_will',     'light', 180,1,false,'dead',   0,30),
  ('spotlight',     'light', 200,2,false,'discuss',1,40),
  ('objection',     'light', 200,2,false,'discuss',0,50),
  ('last_word',     'light', 220,1,false,'vote',   1,60),
  ('vote_shield',   'medium',500,1,false,'discuss',0,110),
  ('half_door',     'medium',600,1,false,'night',  0,120),
  ('double_vote',   'medium',700,1,false,'discuss',0,130),
  ('camouflage',    'medium',750,1,true, 'night',  0,140),
  ('revote',        'medium',800,1,false,'vote',   0,150),
  ('grave_vote',    'medium',850,1,false,'dead',   1,160),
  ('sense',         'medium',900,1,false,'night',  3,170),
  ('impersonate',   'heavy',1800,1,true, 'night',  0,210),
  ('narrator_whisper','heavy',2400,1,false,'night',2,220),
  ('lock_door',     'heavy',2800,1,false,'night',  0,230),
  ('appeal',        'heavy',3000,1,false,'vote',   0,240)
on conflict (code) do update set tier=excluded.tier, coin_price=excluded.coin_price,
  per_match=excluded.per_match, secret=excluded.secret, phase=excluded.phase,
  targets=excluded.targets, sort_order=excluded.sort_order;

create table if not exists public.player_tool_charges (
  user_id uuid not null references auth.users(id) on delete cascade,
  tool_code text not null references public.table_tools(code),
  charges int not null default 0 check (charges >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, tool_code)
);

create table if not exists public.room_tool_uses (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null,
  seat int not null,
  tool_code text not null references public.table_tools(code),
  phase text not null,
  phase_number int not null,
  target_seats int[] not null default '{}',
  -- Free text for the note tools, and the chosen face for `impersonate`.
  note text,
  created_at timestamptz not null default now()
);
create index if not exists room_tool_uses_room on public.room_tool_uses(room_id, phase_number);

alter table public.table_tools enable row level security;
alter table public.player_tool_charges enable row level security;
alter table public.room_tool_uses enable row level security;
revoke all on public.table_tools, public.player_tool_charges, public.room_tool_uses from anon, authenticated;
grant all on public.table_tools, public.player_tool_charges, public.room_tool_uses to service_role;

-- Pack price: a small discount for 3 and 7, rounded to tens.
create or replace function public.tool_pack_price(p_price bigint, p_pack int)
returns bigint language sql immutable as $$
  select case p_pack
    when 1 then p_price
    when 3 then (round(p_price * 2.8 / 10.0) * 10)::bigint
    when 7 then (round(p_price * 6.3 / 10.0) * 10)::bigint
  end
$$;

create or replace function public.table_tools_snapshot(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object(
    'tools', coalesce((select jsonb_agg(jsonb_build_object(
        'code', t.code, 'tier', t.tier, 'price', t.coin_price,
        'packs', jsonb_build_object('1', public.tool_pack_price(t.coin_price,1),
                                    '3', public.tool_pack_price(t.coin_price,3),
                                    '7', public.tool_pack_price(t.coin_price,7)),
        'perMatch', t.per_match, 'phase', t.phase, 'targets', t.targets,
        'charges', coalesce(c.charges,0)) order by t.sort_order)
      from public.table_tools t
      left join public.player_tool_charges c on c.tool_code=t.code and c.user_id=p_user
      where t.active), '[]'::jsonb),
    'limits', jsonb_build_object('perMatch', 4, 'heavyPerMatch', 2),
    'balance', coalesce((select balance from public.wallet_accounts where user_id=p_user), 0))
$$;

create or replace function public.buy_table_tool(p_user uuid, p_tool text, p_pack int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.table_tools; charge bigint;
begin
  if p_pack not in (1,3,7) then raise exception 'BAD_PACK'; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into t from public.table_tools where code=p_tool and active;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  charge := public.tool_pack_price(t.coin_price, p_pack);
  update public.wallet_accounts set balance=balance-charge,
    purchased_balance=greatest(0,purchased_balance-charge),
    lifetime_spent=lifetime_spent+charge, updated_at=now()
   where user_id=p_user and balance>=charge;
  if not found then raise exception 'INSUFFICIENT_COINS'; end if;
  insert into public.wallet_ledger(user_id,kind,amount,item_code)
    values(p_user,'tool_spend',-charge,p_tool);
  insert into public.player_tool_charges(user_id,tool_code,charges)
    values(p_user,p_tool,p_pack)
  on conflict (user_id,tool_code) do update
    set charges=player_tool_charges.charges+p_pack, updated_at=now();
  return public.table_tools_snapshot(p_user);
end $$;

-- Spends one charge inside a live match. Every rule a client could bend is
-- checked here: membership, phase, alive/dead, the per-tool, per-player and
-- heavy limits, the targets, and the charge itself.
create or replace function public.use_table_tool(
  p_user uuid, p_room uuid, p_tool text, p_targets int[], p_note text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  t public.table_tools;
  me public.room_players;
  st public.room_state;
  used_all int; used_heavy int; used_this int; living int;
  targets int[] := coalesce(p_targets,'{}');
begin
  perform pg_advisory_xact_lock(hashtextextended('tools:'||p_room::text||p_user::text,7));
  select * into t from public.table_tools where code=p_tool and active;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  select * into me from public.room_players
   where room_id=p_room and user_id=p_user and not kicked;
  if not found then raise exception 'NOT_A_MEMBER'; end if;
  select * into st from public.room_state where room_id=p_room;
  if not found or (select status from public.rooms where id=p_room) <> 'playing' then
    raise exception 'NOT_PLAYING';
  end if;

  if t.phase='dead' then
    if me.alive then raise exception 'ALIVE'; end if;
  else
    if not me.alive then raise exception 'NOT_ALIVE'; end if;
    if t.phase='discuss' and st.phase not in ('discuss','opening','confront','defense','morning') then
      raise exception 'WRONG_PHASE';
    end if;
    if t.phase='vote' and st.phase not in ('vote','discuss','defense') then raise exception 'WRONG_PHASE'; end if;
    if t.phase='night' and st.phase <> 'night' then raise exception 'WRONG_PHASE'; end if;
  end if;

  if coalesce(array_length(targets,1),0) <> t.targets then raise exception 'BAD_TARGETS'; end if;
  if t.targets > 0 then
    select count(*) into living from public.room_players
     where room_id=p_room and alive and not kicked and seat = any(targets) and seat <> me.seat;
    if living <> t.targets or (select count(distinct x) from unnest(targets) x) <> t.targets then
      raise exception 'BAD_TARGETS';
    end if;
  end if;
  if p_tool in ('anon_note','last_will') and
     (p_note is null or length(btrim(p_note)) = 0 or length(p_note) > 140) then
    raise exception 'BAD_NOTE';
  end if;
  if p_tool='impersonate' and coalesce(p_note,'') not in ('citizen','mafia') then
    raise exception 'BAD_NOTE';
  end if;

  select count(*), count(*) filter (where tt.tier='heavy'), count(*) filter (where u.tool_code=p_tool)
    into used_all, used_heavy, used_this
    from public.room_tool_uses u join public.table_tools tt on tt.code=u.tool_code
   where u.room_id=p_room and u.user_id=p_user
     and u.created_at >= coalesce((select started_at from public.rooms where id=p_room), '-infinity');
  if used_all >= 4 then raise exception 'LIMIT_MATCH'; end if;
  if t.tier='heavy' and used_heavy >= 2 then raise exception 'LIMIT_HEAVY'; end if;
  if used_this >= t.per_match then raise exception 'LIMIT_TOOL'; end if;
  -- One of each kind per phase, so two charges never stack on the same beat.
  if exists(select 1 from public.room_tool_uses where room_id=p_room and user_id=p_user
             and tool_code=p_tool and phase_number=st.phase_number) then
    raise exception 'LIMIT_PHASE';
  end if;

  update public.player_tool_charges set charges=charges-1, updated_at=now()
   where user_id=p_user and tool_code=p_tool and charges>0;
  if not found then raise exception 'NO_CHARGES'; end if;

  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats,note)
    values(p_room,p_user,me.seat,p_tool,st.phase,st.phase_number,targets,
           case when p_note is null then null else left(btrim(p_note),140) end);

  return jsonb_build_object('tool',p_tool,'seat',me.seat,'phaseNumber',st.phase_number,
    'secret',t.secret,'charges',(select charges from public.player_tool_charges
       where user_id=p_user and tool_code=p_tool));
end $$;

revoke all on function public.tool_pack_price(bigint,int) from public, anon, authenticated;
revoke all on function public.table_tools_snapshot(uuid) from public, anon, authenticated;
revoke all on function public.buy_table_tool(uuid,text,int) from public, anon, authenticated;
revoke all on function public.use_table_tool(uuid,uuid,text,int[],text) from public, anon, authenticated;
grant execute on function public.tool_pack_price(bigint,int) to service_role;
grant execute on function public.table_tools_snapshot(uuid) to service_role;
grant execute on function public.buy_table_tool(uuid,text,int) to service_role;
grant execute on function public.use_table_tool(uuid,uuid,text,int[],text) to service_role;
