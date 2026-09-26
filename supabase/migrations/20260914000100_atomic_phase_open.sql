-- Every phase move that does not resolve anything goes through one
-- compare-and-set. The public payload and the phase are written in the same
-- statement, under the room lock, and only after the phase, day number and
-- deadline the caller read are proven to still be the row's. Two drivers asking
-- for the same move in the same instant: the first moves the room, the second
-- matches nothing and is told so. A payload that carries the roles is refused
-- outright unless the move is into `result`, which is the one moment the roles
-- become public (doc 05).
create function public.commit_phase_open(
  p_room uuid, p_expected text, p_number integer, p_expected_deadline timestamptz,
  p_next text, p_next_number integer, p_deadline timestamptz, p_patch jsonb,
  p_require_all_seen boolean default false
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  if p_next <> 'result' and p_patch ? 'standings' then
    raise exception 'standings may only be published with the result';
  end if;
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>p_expected or s.phase_number<>p_number or
    s.phase_ends_at is distinct from p_expected_deadline then return false; end if;
  -- The deal's gate, read under the same lock that publishes the night: no
  -- seat can be waved through by a check that ran before it was kicked in,
  -- and no client's word for "everybody saw their card" is taken.
  if p_require_all_seen and exists (
    select 1 from public.room_players where room_id=p_room and not saw_role
  ) then return false; end if;
  update public.room_state set phase=p_next,phase_number=p_next_number,
    phase_ends_at=p_deadline,public_data=public_data || p_patch,
    active_speaker=null,updated_at=now() where room_id=p_room;
  if p_next='result' then
    update public.rooms set status='finished',ended_at=coalesce(ended_at,now()) where id=p_room;
  end if;
  return true;
end;
$$;
revoke all on function public.commit_phase_open(uuid,text,integer,timestamptz,text,integer,timestamptz,jsonb,boolean)
  from public,anon,authenticated;
grant execute on function public.commit_phase_open(uuid,text,integer,timestamptz,text,integer,timestamptz,jsonb,boolean)
  to service_role;

-- The morning of day two onward opens on the confrontation the server chose,
-- or on the discussion when the record supports none. The archive entry, the
-- live payload and the phase land together, and only from the morning the
-- driver actually read.
create function public.commit_confrontation(
  p_room uuid, p_number integer, p_expected_deadline timestamptz,
  p_confrontation jsonb, p_next text, p_deadline timestamptz
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  if p_next not in ('confront','discuss') then
    raise exception 'a morning opens on a confrontation or a discussion';
  end if;
  if (p_next='confront') <> (p_confrontation is not null and jsonb_typeof(p_confrontation)='object') then
    raise exception 'confrontation payload does not match the phase';
  end if;
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>'morning' or s.phase_number<>p_number or
    s.phase_ends_at is distinct from p_expected_deadline then return false; end if;
  if p_next='confront' then
    perform public.set_public_path(p_room, array['confrontations', p_number::text], p_confrontation);
  end if;
  update public.room_state set phase=p_next, phase_ends_at=p_deadline, active_speaker=null,
    public_data=public_data || jsonb_build_object('confrontation', case when p_next='confront' then p_confrontation else 'null'::jsonb end,
                                                  'confrontationSilent', null),
    updated_at=now() where room_id=p_room;
  return true;
end;
$$;
revoke all on function public.commit_confrontation(uuid,integer,timestamptz,jsonb,text,timestamptz)
  from public,anon,authenticated;
grant execute on function public.commit_confrontation(uuid,integer,timestamptz,jsonb,text,timestamptz)
  to service_role;

-- One name from one seat, recorded only while the floor is that seat's, and the
-- floor handed on (or the round closed) in the same statement. A double tap or
-- a retry that lands after the floor moved matches nothing and changes nothing.
create function public.commit_accusation(
  p_room uuid, p_number integer, p_seat integer, p_target integer,
  p_next_seat integer, p_next_deadline timestamptz, p_discuss_deadline timestamptz
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>'opening' or s.phase_number<>p_number or
    (s.public_data->>'openingSeat')::integer is distinct from p_seat then return false; end if;
  perform public.set_public_path(p_room, array['openingAccusations', p_seat::text], to_jsonb(p_target));
  if p_next_seat is not null then
    update public.room_state set public_data=public_data || jsonb_build_object('openingSeat', p_next_seat),
      phase_ends_at=p_next_deadline, updated_at=now() where room_id=p_room;
  else
    update public.room_state set public_data=public_data || jsonb_build_object('openingSeat', null),
      phase='discuss', phase_ends_at=p_discuss_deadline, active_speaker=null, updated_at=now()
      where room_id=p_room;
  end if;
  return true;
end;
$$;
revoke all on function public.commit_accusation(uuid,integer,integer,integer,integer,timestamptz,timestamptz)
  from public,anon,authenticated;
grant execute on function public.commit_accusation(uuid,integer,integer,integer,integer,timestamptz,timestamptz)
  to service_role;
