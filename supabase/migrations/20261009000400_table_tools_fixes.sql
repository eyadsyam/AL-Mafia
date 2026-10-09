-- Table tools fixes.
--  * grave_vote takes no target (the ballot is the dead player's own; the
--    target that was logged was ignored by the count).
--  * the answer of `sense` / `narrator_whisper` is stored on the use row and
--    readable again through my_tool_answers(user, room) via the economy function (own rows, current match).
--  * extra_minute / objection are consumed by the first granted floor claim.
--  * buy_table_tool accepts an optional request id: a repeat is a no-op.

alter table public.room_tool_uses add column if not exists answer boolean;
-- Set when a one-shot effect (the floor bonus) has been spent.
alter table public.room_tool_uses add column if not exists consumed_at timestamptz;

update public.table_tools set targets=0 where code='grave_vote';

create or replace function public.use_table_tool(
  p_user uuid, p_room uuid, p_tool text, p_targets int[], p_note text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  t public.table_tools;
  me public.room_players;
  st public.room_state;
  used_all int; used_heavy int; used_this int; living int; ans boolean;
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

  -- The narrator's private answer: is a mafioso (Silencer included) among the
  -- chosen seats? Stored with the use so the caller can read it again.
  ans := case when p_tool in ('narrator_whisper','sense') then
    exists(select 1 from public.room_players x where x.room_id=p_room
      and x.seat = any(targets) and public.is_mafia_team(x.role))
    else null end;

  insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number,target_seats,note,answer)
    values(p_room,p_user,me.seat,p_tool,st.phase,st.phase_number,targets,
           case when p_note is null then null else left(btrim(p_note),140) end,ans);

  -- The table hears it: who (or «someone» for a secret tool), which tool,
  -- and on whom. The note of a secret tool (the chosen face) never goes here.
  update public.room_state set public_data = jsonb_set(coalesce(public_data,'{}'::jsonb),
      '{toolLog}', coalesce(public_data->'toolLog','[]'::jsonb) || jsonb_build_array(jsonb_build_object(
        'tool', p_tool,
        'seat', case when t.secret then null else me.seat end,
        'targets', case when t.secret or p_tool in ('narrator_whisper','sense') then '[]'::jsonb else to_jsonb(targets) end,
        'note', case when p_tool in ('anon_note','last_will') then left(btrim(p_note),140) else null end,
        'phaseNumber', st.phase_number)))
   where room_id=p_room;

  -- The narrator's private answer, to the user's own request only (like the
  -- Detective's): is a mafioso among the chosen seats?
  return jsonb_build_object('tool',p_tool,'seat',me.seat,'phaseNumber',st.phase_number,
    'answer', ans,
    'secret',t.secret,'charges',(select charges from public.player_tool_charges
       where user_id=p_user and tool_code=p_tool));
end $$;

create or replace function public.my_tool_answers(p_user uuid, p_room uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object('answers', coalesce(jsonb_agg(jsonb_build_object(
      'tool', u.tool_code, 'phaseNumber', u.phase_number,
      'targets', to_jsonb(u.target_seats), 'answer', u.answer, 'at', u.created_at)
    order by u.id), '[]'::jsonb))
  from public.room_tool_uses u join public.rooms r on r.id=u.room_id
  where u.room_id=p_room and u.user_id=p_user and u.answer is not null
    and u.created_at >= coalesce(r.started_at, '-infinity')
$$;
revoke all on function public.my_tool_answers(uuid, uuid) from public, anon, authenticated;
grant execute on function public.my_tool_answers(uuid, uuid) to service_role;

create table if not exists public.tool_purchase_requests (
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  tool_code text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, request_id)
);
alter table public.tool_purchase_requests enable row level security;
revoke all on public.tool_purchase_requests from anon, authenticated;
grant all on public.tool_purchase_requests to service_role;

drop function if exists public.buy_table_tool(uuid,text,int);
create function public.buy_table_tool(p_user uuid, p_tool text, p_pack int, p_request uuid default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.table_tools; charge bigint; fresh int;
begin
  if p_pack not in (1,3,7) then raise exception 'BAD_PACK'; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into t from public.table_tools where code=p_tool and active;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  if p_request is not null then
    insert into public.tool_purchase_requests(user_id,request_id,tool_code)
      values(p_user,p_request,p_tool) on conflict do nothing;
    get diagnostics fresh = row_count;
    if fresh = 0 then return public.table_tools_snapshot(p_user); end if;
  end if;
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
revoke all on function public.buy_table_tool(uuid,text,int,uuid) from public, anon, authenticated;
grant execute on function public.buy_table_tool(uuid,text,int,uuid) to service_role;
