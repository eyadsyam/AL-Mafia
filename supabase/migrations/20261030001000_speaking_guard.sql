-- One committed report per client id, or per server second for legacy callers.
create table public.speaking_reports (
  room_id uuid not null references public.rooms(id) on delete cascade,
  report_id uuid not null,
  user_id uuid not null,
  seat integer not null,
  day integer not null,
  second_bucket timestamptz,
  seconds integer not null,
  primary key (room_id, report_id)
);
create unique index speaking_reports_legacy_bucket on public.speaking_reports
  (room_id, seat, day, second_bucket) where second_bucket is not null;
alter table public.speaking_reports enable row level security;
revoke all on public.speaking_reports from public, anon, authenticated;
grant all on public.speaking_reports to service_role;

-- The user id comes from the authenticated Edge handler, never its request body.
create or replace function public.add_speaking_seconds(
  p_room uuid, p_day integer, p_seat integer, p_seconds integer,
  p_user uuid, p_report_id uuid default null
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state; r public.rooms; cap integer; accepted integer;
        bucket timestamptz;
begin
  select * into r from public.rooms where id=p_room for update;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or r.status <> 'playing' or s.phase not in ('opening','confront','discuss','defense')
     or s.phase_number <> p_day or (s.phase_ends_at is not null and now()>s.phase_ends_at)
  then raise exception 'PHASE_CLOSED'; end if;
  if not exists(select 1 from public.room_players where room_id=p_room and user_id=p_user
      and seat=p_seat and alive and not kicked) then raise exception 'NOT_A_MEMBER'; end if;
  if s.phase in ('opening','confront','defense') and
     (case when s.phase='opening' then (s.public_data->>'openingSeat')::integer
       else (s.public_data #>> '{confrontation,targetSeat}')::integer end) is distinct from p_seat
  then raise exception 'NOT_FLOOR_HOLDER'; end if;
  if s.phase='discuss' and coalesce(r.settings->>'discussionMode','') <> 'free'
     and (s.active_speaker is distinct from p_user or s.speaker_until is null
       or s.speaker_until<=now()) then raise exception 'NOT_FLOOR_HOLDER'; end if;
  if s.phase='discuss' and (s.public_data #>> '{morning,silencedSeat}')::integer = p_seat
  then raise exception 'NOT_FLOOR_HOLDER'; end if;
  if p_seconds is null or p_seconds < 0 then raise exception 'BAD_REQUEST'; end if;
  cap := case s.phase when 'opening' then 10
    when 'confront' then coalesce((r.settings->>'confrontationSeconds')::integer,45)
    when 'defense' then coalesce((r.settings->>'confrontationSeconds')::integer,45)
    else coalesce((r.settings->>'discussionSeconds')::integer,300) end;
  accepted := least(p_seconds,greatest(cap,0));
  bucket := case when p_report_id is null then date_trunc('second',clock_timestamp()) else null end;
  insert into public.speaking_reports(room_id,report_id,user_id,seat,day,second_bucket,seconds)
    values(p_room,coalesce(p_report_id,gen_random_uuid()),p_user,p_seat,p_day,bucket,accepted)
    on conflict do nothing;
  if not found then return; end if;
  update public.room_state set public_data=jsonb_set(
      jsonb_set(jsonb_set(public_data,'{speakingSeconds}',
        coalesce(public_data->'speakingSeconds','{}'::jsonb),true),
        array['speakingSeconds',p_day::text],
        coalesce(public_data #> array['speakingSeconds',p_day::text],'{}'::jsonb),true),
      array['speakingSeconds',p_day::text,p_seat::text],
      to_jsonb(coalesce((public_data #>> array['speakingSeconds',p_day::text,p_seat::text])::integer,0)+accepted),true),
      updated_at=now() where room_id=p_room;
end $$;
-- Retire the unsafe four-argument entry point.
revoke all on function public.add_speaking_seconds(uuid,int,int,int) from public,anon,authenticated,service_role;
revoke all on function public.add_speaking_seconds(uuid,integer,integer,integer,uuid,uuid) from public,anon,authenticated;
grant execute on function public.add_speaking_seconds(uuid,integer,integer,integer,uuid,uuid) to service_role;
