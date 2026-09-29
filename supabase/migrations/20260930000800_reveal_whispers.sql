-- Doc 09 §7: «كشف محتوى الهمسات بعد المباراة», default OFF, graph always
-- revealed. A host switch on the room (`settings.revealWhisperContent`, set in
-- the lobby only and locked with every other rule at the deal), shown to every
-- seat in the lobby and on the whisper composer, so a whisper is never written
-- under one promise and read under another.
--
-- Once the match is over and public (`room_at_public_end`), every seated
-- member of that room — alive or dead at the end — reads every delivered
-- whisper with its text. Voided whispers were never read and stay hidden; a
-- sender the viewer blocked comes back masked. Before the public end, or in a
-- room that did not switch it on, `whispers` is null: nothing about any
-- whisper's text leaves the two parties (Doc 05).
create or replace function public.match_whispers_revealed(p_user uuid, p_room uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.room_at_public_end(p_room)
     or not exists(select 1 from public.rooms r where r.id=p_room
                   and (r.settings->>'revealWhisperContent')='true')
     or not exists(select 1 from public.room_players p where p.room_id=p_room
                   and p.user_id=p_user and not p.kicked and p.role is not null) then
    return jsonb_build_object('whispers',null);
  end if;
  return jsonb_build_object('whispers',coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', m.id, 'day', m.day, 'fromSeat', f.seat, 'toSeat', t.seat,
        'masked', b.blocker_id is not null,
        'text', case when b.blocker_id is null then c.body end)
      order by m.day, m.created_at, m.id)
      from public.whisper_meta m
      join public.whisper_content c on c.whisper_id=m.id
      join public.room_players f on f.room_id=m.room_id and f.user_id=m.from_id
      join public.room_players t on t.room_id=m.room_id and t.user_id=m.to_id
      left join public.player_blocks b on b.blocker_id=p_user and b.blocked_id=m.from_id
     where m.room_id=p_room and not m.voided), '[]'::jsonb));
end $$;
revoke all on function public.match_whispers_revealed(uuid,uuid) from public,anon,authenticated;
grant execute on function public.match_whispers_revealed(uuid,uuid) to service_role;
