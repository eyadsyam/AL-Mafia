-- Publish the graph and private content in the same transaction. Realtime must
-- never announce a graph row whose body has not committed yet.
create function public.commit_whisper(p_room uuid, p_sender uuid, p_seat integer, p_day integer, p_body text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; s public.room_state%rowtype;
        sender public.room_players%rowtype; target public.room_players%rowtype; result uuid;
begin
  select * into r from public.rooms where id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  select * into sender from public.room_players where room_id=p_room and user_id=p_sender;
  if not found or sender.kicked then raise exception 'NOT_A_MEMBER'; end if;
  if not sender.alive then raise exception 'NOT_ALIVE'; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or r.status<>'playing' or s.phase not in ('opening','discuss','confrontation')
     or s.phase_number<>p_day or r.settings->>'whisperEnabled'='false' then
    raise exception 'PHASE_CLOSED';
  end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 120 then raise exception 'BAD_REQUEST'; end if;
  select * into target from public.room_players where room_id=p_room and seat=p_seat;
  if not found or target.kicked or not target.alive or target.user_id=p_sender then raise exception 'BAD_REQUEST'; end if;
  insert into public.whisper_meta(room_id,day,from_id,to_id)
    values(p_room,p_day,p_sender,target.user_id) returning id into result;
  insert into public.whisper_content(whisper_id,body) values(result,btrim(p_body));
  return result;
end $$;
revoke all on function public.commit_whisper(uuid,uuid,integer,integer,text) from public,anon,authenticated;
grant execute on function public.commit_whisper(uuid,uuid,integer,integer,text) to service_role;
