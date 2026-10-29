-- Fast room reactions. The original membership, phase and feature gates stay
-- authoritative; safety_v11 filters blocked senders in the SELECT policy.
create or replace function public.send_room_reaction(p_user uuid, p_room uuid, p_kind text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_seat int; n int;
begin
  if not public.fun_on('reactions') then raise exception 'FEATURE_OFF'; end if;
  if p_kind is null or p_kind not in ('laugh','shock','suspicious','applause','rose',
      'skull','coffee','crown') then
    raise exception 'REACTION_UNKNOWN';
  end if;
  select seat into v_seat from public.room_players
   where room_id=p_room and user_id=p_user and not kicked;
  if not found then raise exception 'NOT_MEMBER'; end if;
  if not exists(select 1 from public.rooms r join public.room_state s on s.room_id=r.id
      where r.id=p_room and ((r.status='lobby' and s.phase='lobby')
        or (r.status='finished' and s.phase='result'
            and s.public_data->>'outcome' in ('mafia','town')))) then
    raise exception 'REACTION_CLOSED';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('react:'||p_room::text||':'||p_user::text,93));
  select count(*) into n from public.room_reactions
   where room_id=p_room and user_id=p_user and created_at > now() - interval '1 minute';
  if n >= 600 then return jsonb_build_object('ok',true,'dropped',true); end if;
  insert into public.room_reactions(room_id,user_id,seat,kind) values(p_room,p_user,v_seat,p_kind);
  delete from public.room_reactions where room_id=p_room and created_at < now() - interval '10 minutes';
  return jsonb_build_object('ok',true,'seat',v_seat,'kind',p_kind);
end $$;
