-- F21a — Witness v2: whisper contents for the dead (owner, 2026-09-28).
--
-- The dead see the whole game, including who whispered what to whom. The only
-- path is `witness_whispers`, called by the `witness_view` Edge Function after
-- it has established, from committed rows, that the caller is a current,
-- non-removed member whose authoritative `alive` is false in a room that is
-- playing. Clients never assert their own death, and whisper content never
-- enters the snapshot, Realtime, error bodies or analytics.
--
-- Off unless both switches say on: the global flag `witness_whispers_enabled`
-- and the room's immutable witness setting (`settings.witnessKnowledge`, which
-- defaults to on — F21; an explicit false turns the whole witness view down to
-- public state).
--
-- A sender the dead viewer has blocked is masked for that viewer only. A
-- reported whisper is preserved as evidence in the report itself.

alter table public.economy_config
  add column if not exists witness_whispers_enabled boolean not null default false;

create or replace function public.witness_whispers_on(p_room uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select witness_whispers_enabled from public.economy_config limit 1), false)
     and coalesce((select (r.settings->>'witnessKnowledge') is distinct from 'false'
                     from public.rooms r where r.id=p_room), false)
$$;
revoke all on function public.witness_whispers_on(uuid) from public,anon,authenticated;
grant execute on function public.witness_whispers_on(uuid) to service_role;

-- A current, dead, non-removed member of a room in play. The one door.
create or replace function public.witness_member(p_room uuid, p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.room_players p join public.rooms r on r.id=p.room_id
    where p.room_id=p_room and p.user_id=p_user and not p.kicked and not p.alive
      and p.role is not null and r.status='playing')
$$;
revoke all on function public.witness_member(uuid,uuid) from public,anon,authenticated;
grant execute on function public.witness_member(uuid,uuid) to service_role;

-- Every delivered whisper of the room, oldest first, as seats. Voided whispers
-- (the recipient died before reading) were never delivered and are left out.
-- Null when the caller is not a witness or the switches are off.
create or replace function public.witness_whispers(p_room uuid, p_viewer uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.witness_member(p_room,p_viewer) or not public.witness_whispers_on(p_room) then
    return null;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', m.id, 'day', m.day, 'fromSeat', f.seat, 'toSeat', t.seat,
        'masked', b.blocker_id is not null,
        'text', case when b.blocker_id is null then c.body end)
      order by m.day, m.created_at, m.id)
      from public.whisper_meta m
      join public.whisper_content c on c.whisper_id=m.id
      join public.room_players f on f.room_id=m.room_id and f.user_id=m.from_id
      join public.room_players t on t.room_id=m.room_id and t.user_id=m.to_id
      left join public.player_blocks b on b.blocker_id=p_viewer and b.blocked_id=m.from_id
     where m.room_id=p_room and not m.voided), '[]'::jsonb);
end $$;
revoke all on function public.witness_whispers(uuid,uuid) from public,anon,authenticated;
grant execute on function public.witness_whispers(uuid,uuid) to service_role;

-- A dead viewer reports a witnessed whisper by its id. The text is copied into
-- the report as evidence, so it outlives the room; nothing is resubmitted by
-- the client. Replayed by request id; one report per viewer and whisper.
create or replace function public.witness_report(
  p_user uuid, p_room uuid, p_whisper uuid, p_category text, p_request uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare m public.whisper_meta; body text; prior uuid; receipt uuid; r public.rooms;
begin
  if p_request is null or p_category not in
     ('harassment','hate','sexual','threat','spam','cheating','inappropriate_name','other') then
    raise exception 'BAD_REQUEST';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 73));
  select id into prior from public.safety_reports where reporter_id=p_user and request_id=p_request;
  if prior is not null then return jsonb_build_object('receipt',prior,'replayed',true); end if;
  if not public.witness_member(p_room,p_user) or not public.witness_whispers_on(p_room) then
    raise exception 'WITNESS_ONLY';
  end if;
  select * into m from public.whisper_meta where id=p_whisper and room_id=p_room and not voided;
  if m.id is null then raise exception 'BAD_REQUEST'; end if;
  insert into public.whisper_reports(whisper_id,reporter_id) values(m.id,p_user) on conflict do nothing;
  if not found then
    select id into prior from public.safety_reports
     where reporter_id=p_user and evidence->>'whisperId'=m.id::text limit 1;
    if prior is not null then return jsonb_build_object('receipt',prior,'deduplicated',true); end if;
  end if;
  select c.body into body from public.whisper_content c where c.whisper_id=m.id;
  select * into r from public.rooms where id=p_room;
  insert into public.safety_reports(reporter_id,room_id,target_id,reason,details,context,evidence,request_id)
    values(p_user,p_room,m.from_id,p_category,'','match',
      jsonb_build_object('context','match','roomCode',r.code,'whisperId',m.id,'day',m.day,
        'fromSeat',(select seat from public.room_players where room_id=p_room and user_id=m.from_id),
        'toSeat',(select seat from public.room_players where room_id=p_room and user_id=m.to_id),
        'whisperText',body),
      p_request)
    returning id into receipt;
  return jsonb_build_object('receipt',receipt);
end $$;
revoke all on function public.witness_report(uuid,uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.witness_report(uuid,uuid,uuid,text,uuid) to service_role;

-- The client learns only that whispers are witnessed (for the disclosure line).
alter function public.economy_capabilities(uuid)
  rename to economy_capabilities_pre_witness;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.economy_capabilities_pre_witness(p_user);
  return base||jsonb_build_object('witness',jsonb_build_object('whispers',
    coalesce((select witness_whispers_enabled from public.economy_config limit 1),false)));
end $$;
revoke all on function public.economy_capabilities_pre_witness(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_witness(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
