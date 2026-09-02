-- Host migration and leaving (doc 10 §8.1, doc 11 O1–O3).
--
-- ## The rule
--
-- *"Host drops → automatic host migration to the lowest-seat connected player.
-- Never end the match."* O2 adds: if the heir has gone too, it cascades down
-- the seat order.
--
-- ## Why it is one SQL function and not a handful of client checks
--
-- Every client can see the same roster and can therefore compute the same
-- heir — that is what makes the migration *automatic* rather than a menu item.
-- But every client computing it means several of them may ask at once, and
-- "the lowest-seat connected player" evaluated twice against a moving roster
-- can produce two answers. Deciding it inside one statement, against one
-- snapshot of the table, is what makes the race harmless: the losers are told
-- the room already has a host, which is all they wanted to know.

create or replace function public.migrate_host(
  p_room     uuid,
  p_claimant uuid,
  p_timeout  interval default interval '30 seconds'
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_host uuid;
  host_live    boolean;
  heir         uuid;
begin
  select host_id into current_host
    from public.rooms
   where id = p_room
     and status <> 'finished'
   for update;

  if current_host is null then
    return null;
  end if;

  -- The host answering is the end of it. A claim is not a vote of no
  -- confidence: it is a report that nobody is home.
  select (connected and last_seen > now() - p_timeout)
    into host_live
    from public.room_players
   where room_id = p_room and user_id = current_host;

  if coalesce(host_live, false) then
    return current_host;
  end if;

  -- The cascade of O2 is not special-cased: "lowest connected seat" evaluated
  -- after the heir has also gone simply returns the next one down.
  select user_id into heir
    from public.room_players
   where room_id = p_room
     and connected
     and last_seen > now() - p_timeout
   order by seat
   limit 1;

  if heir is null then
    -- Everybody is gone. O3 handles this on a longer clock; the room keeps the
    -- host it has rather than being handed to somebody who is not there.
    return current_host;
  end if;

  if heir <> p_claimant then
    return heir;
  end if;

  update public.rooms set host_id = heir where id = p_room;
  return heir;
end;
$$;

-- Leaving, and what it means in each phase.
--
-- In the lobby a departure is a real departure and the seats re-pack: seat
-- order is the night pass and the «اسم واحد» order, and a hole in it would put
-- an empty chair in both. Mid-match it is only a disconnection — the seat is
-- the identity claim (O5), the role is dealt against it, and a player who
-- closed the app by accident must be able to come back to the same one (O4).
create or replace function public.leave_room(
  p_room uuid,
  p_user uuid
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  room_status text;
  left_seat   int;
begin
  select status into room_status from public.rooms where id = p_room;
  if room_status is null then
    return 'ROOM_NOT_FOUND';
  end if;

  if room_status <> 'lobby' then
    update public.room_players
       set connected = false, last_seen = now()
     where room_id = p_room and user_id = p_user;
    return 'disconnected';
  end if;

  select seat into left_seat
    from public.room_players
   where room_id = p_room and user_id = p_user;
  if left_seat is null then
    return 'NOT_A_MEMBER';
  end if;

  delete from public.room_players
   where room_id = p_room and user_id = p_user;

  update public.room_players
     set seat = seat - 1
   where room_id = p_room and seat > left_seat;

  -- The host leaving its own lobby hands the room to the new seat 0 rather
  -- than closing it: the other players are already in it.
  update public.rooms r
     set host_id = coalesce(
           (select user_id from public.room_players
             where room_id = p_room order by seat limit 1),
           r.host_id)
   where r.id = p_room and r.host_id = p_user;

  return 'left';
end;
$$;

revoke all on function public.migrate_host(uuid, uuid, interval) from anon, authenticated;
revoke all on function public.leave_room(uuid, uuid)             from anon, authenticated;
