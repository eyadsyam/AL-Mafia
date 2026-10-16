-- RL15 / D21 — «ركّز عليه» (spotlight) and «آخر كلمة» (last word) do something.
--
-- Both used to be a line on the table's tool log and nothing else. In talk by
-- turns the floor is first come, first served, so "the chosen player speaks
-- next" is an ordering rule in the one place that grants the floor:
-- `claim_floor_with_tools`, under the row lock it already holds.
--
--  * spotlight (seat S on seat T, this phase_number): when the floor is free,
--    only T's claim is granted until T takes it, or `hold` seconds pass.
--    Granting T consumes the use (`consumed_at`, as the floor bonus does), and
--    so does the hold running out: a spotlight is one turn, once, and a player
--    who is away cannot hold the table for every turn that follows.
--  * last word (seat S on seat T, bought in the vote window): the ballot that
--    voted S out leaves `public_data.lastWordFloor = {seat, target, day}`
--    (written by `resolve_vote` in the same commit as the elimination, so it
--    exists only when S was really voted out). T has the first floor of the
--    next day's discussion, with the same hold, and the key is removed once
--    T speaks or the hold runs out.
--
-- A last word comes before a spotlight (it is the first floor of the day).
-- Free discussion is untouched: nothing here runs unless the room talks by
-- turns, and `claim_floor` never reaches this function in an open room. A
-- player who cannot take the floor (dead, removed, silenced) holds nothing.
-- The hold is measured from the moment the floor is free: the previous
-- speaker's deadline, or the release / phase change (`updated_at`), and never
-- before the spotlight itself was used.

create or replace function public.claim_floor_with_tools(
  p_room uuid, p_user uuid, p_seconds int, p_phase text, p_number int
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state; me public.room_players; extra int; owner_seat int;
  silenced int; structured boolean; free_at timestamptz;
  priority_seat int; priority_kind text; priority_since timestamptz;
  hold constant interval := interval '20 seconds';
begin
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>p_phase or s.phase_number<>p_number
      or s.phase not in ('opening','confront','discuss','defense') then return false; end if;
  select * into me from public.room_players where room_id=p_room and user_id=p_user;
  if not found or not me.alive or me.kicked then return false; end if;
  silenced := (s.public_data #>> '{morning,silencedSeat}')::int;
  if silenced = me.seat then return false; end if;
  owner_seat := case s.phase
    when 'opening' then (s.public_data->>'openingSeat')::int
    when 'confront' then (s.public_data #>> '{confrontation,targetSeat}')::int
    when 'defense' then (s.public_data #>> '{confrontation,targetSeat}')::int
    else null end;
  if owner_seat is not null and owner_seat<>me.seat then return false; end if;
  if s.active_speaker is not null and s.speaker_until>now() then
    return s.active_speaker=p_user;
  end if;

  -- The floor is free. In talk by turns a last word or a spotlight may name
  -- who takes it.
  if s.phase='discuss' then
    select coalesce(r.settings->>'discussionMode','structured')='structured'
      into structured from public.rooms r where r.id=p_room;
    if structured then
      free_at := case when s.active_speaker is not null
                       then coalesce(s.speaker_until, s.updated_at) else s.updated_at end;
      if (s.public_data #>> '{lastWordFloor,day}')::int = p_number - 1 then
        priority_seat := (s.public_data #>> '{lastWordFloor,target}')::int;
        if exists(select 1 from public.room_players t where t.room_id=p_room
            and t.seat=priority_seat and t.alive and not t.kicked)
           and priority_seat is distinct from silenced then
          priority_kind := 'last_word';
          priority_since := free_at;
        else
          priority_seat := null;
        end if;
      end if;
      if priority_seat is null then
        select u.target_seats[1], greatest(u.created_at, free_at)
          into priority_seat, priority_since
          from public.room_tool_uses u
          join public.room_players t on t.room_id=u.room_id and t.seat=u.target_seats[1]
         where u.room_id=p_room and u.tool_code='spotlight' and u.phase_number=p_number
           and u.consumed_at is null and t.alive and not t.kicked
           and t.seat is distinct from silenced
         order by u.id limit 1;
        if priority_seat is not null then priority_kind := 'spotlight'; end if;
      end if;
      if priority_seat is not null then
        if priority_seat<>me.seat and now() < priority_since + hold then
          return false;   -- the floor is held for the player the table chose
        end if;
        -- Taken by him, or the hold ran out: either way the turn is spent.
        if priority_kind='last_word' then
          update public.room_state set public_data=public_data - 'lastWordFloor'
            where room_id=p_room;
        else
          update public.room_tool_uses set consumed_at=now()
            where room_id=p_room and tool_code='spotlight' and phase_number=p_number
              and consumed_at is null and target_seats[1]=priority_seat;
        end if;
      end if;
    end if;
  end if;

  select coalesce(sum(case tool_code when 'extra_minute' then 45 else 30 end),0)
    into extra from public.room_tool_uses where room_id=p_room and user_id=p_user
      and phase_number=p_number and tool_code in ('extra_minute','objection')
      and consumed_at is null;
  update public.room_state set active_speaker=p_user,
    speaker_until=now()+make_interval(secs=>greatest(p_seconds,1)+extra),updated_at=now()
    where room_id=p_room;
  update public.room_tool_uses set consumed_at=now() where room_id=p_room and user_id=p_user
    and phase_number=p_number and tool_code in ('extra_minute','objection')
    and consumed_at is null;
  return true;
end $$;
revoke all on function public.claim_floor_with_tools(uuid,uuid,int,text,int) from public,anon,authenticated;
grant execute on function public.claim_floor_with_tools(uuid,uuid,int,text,int) to service_role;
