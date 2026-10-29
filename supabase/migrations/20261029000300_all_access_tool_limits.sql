-- Owner, 2026-10-29: «الحد عندي براحتي». An all-access account is not held
-- to the per-match counts (4 a match, 2 heavy, each tool's own cap). Every
-- other rule still holds for it: the tool's phase, its targets, its note, and
-- one of each kind per phase, so two charges never stack on the same beat.
-- The body is the live one with only that block changed.
create or replace function public.use_table_tool(p_user uuid, p_room uuid, p_tool text, p_targets integer[], p_note text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  t public.table_tools;
  me public.room_players;
  st public.room_state;
  used_all int; used_heavy int; used_this int; living int; ans boolean;
  room_mode text;
  targets int[] := coalesce(p_targets,'{}');
  unlimited boolean := public.has_all_access(p_user);
begin
  perform pg_advisory_xact_lock(hashtextextended('tools:'||p_room::text||p_user::text,7));
  select * into t from public.table_tools where code=p_tool and active;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  -- Match transitions lock room then state. Hold the same locks before
  -- reading membership so a concurrent death/phase close cannot spend a tool.
  select coalesce(settings->>'discussionMode','structured') into room_mode
    from public.rooms where id=p_room and status='playing' for update;
  if not found then raise exception 'NOT_PLAYING'; end if;
  select * into st from public.room_state where room_id=p_room for update;
  if not found then raise exception 'NOT_PLAYING'; end if;
  select * into me from public.room_players
   where room_id=p_room and user_id=p_user and not kicked;
  if not found then raise exception 'NOT_A_MEMBER'; end if;

  -- RL14 / D24: more time and an objection are floor tools. In free talk there
  -- is no floor to add seconds to, so the charge is not spent.
  if p_tool in ('extra_minute','objection') and room_mode='free' then
    raise exception 'NOT_THIS_ROOM';
  end if;

  if t.phase='dead' then
    if me.alive then raise exception 'ALIVE'; end if;
    if p_tool='grave_vote' and st.phase not in ('discuss','defense','vote') then
      raise exception 'WRONG_PHASE';
    end if;
  else
    if not me.alive then raise exception 'NOT_ALIVE'; end if;
    if t.phase='discuss' and st.phase not in ('discuss','opening','confront','defense','morning') then
      raise exception 'WRONG_PHASE';
    end if;
    if t.phase='vote' and st.phase not in ('vote','discuss','defense') then raise exception 'WRONG_PHASE'; end if;
    if t.phase='night' and st.phase <> 'night' then raise exception 'WRONG_PHASE'; end if;
  end if;

  if p_tool in ('revote','grave_vote') and
     coalesce((st.public_data #>> '{revote,round}')::integer,1) >= 2 then
    raise exception 'WRONG_PHASE';
  end if;
  if p_tool in ('double_vote','grave_vote') and
     st.public_data #>> '{morning,silencedSeat}' = me.seat::text then
    raise exception 'SILENCED';
  end if;
  if p_tool='spotlight' then
    if st.phase not in ('opening','confront','discuss','defense') then
      raise exception 'WRONG_PHASE';
    end if;
    if st.public_data #>> '{morning,silencedSeat}' = targets[1]::text then
      raise exception 'BAD_TARGETS';
    end if;
  end if;
  if p_tool='last_will' and st.phase='night' then raise exception 'WRONG_PHASE'; end if;

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

  if not unlimited then
    select count(*), count(*) filter (where tt.tier='heavy'), count(*) filter (where u.tool_code=p_tool)
      into used_all, used_heavy, used_this
      from public.room_tool_uses u join public.table_tools tt on tt.code=u.tool_code
     where u.room_id=p_room and u.user_id=p_user
       and u.created_at >= coalesce((select started_at from public.rooms where id=p_room), '-infinity');
    if used_all >= 4 then raise exception 'LIMIT_MATCH'; end if;
    if t.tier='heavy' and used_heavy >= 2 then raise exception 'LIMIT_HEAVY'; end if;
    if used_this >= t.per_match then raise exception 'LIMIT_TOOL'; end if;
  end if;
  -- One of each kind per phase, so two charges never stack on the same beat.
  if exists(select 1 from public.room_tool_uses where room_id=p_room and user_id=p_user
             and tool_code=p_tool and phase_number=st.phase_number) then
    raise exception 'LIMIT_PHASE';
  end if;

  if not unlimited then
    update public.player_tool_charges set charges=charges-1, updated_at=now()
     where user_id=p_user and tool_code=p_tool and charges>0;
    if not found then raise exception 'NO_CHARGES'; end if;
  end if;

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
end $function$;
