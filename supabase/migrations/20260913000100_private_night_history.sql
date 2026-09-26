-- Private resolution inputs must never enter the room's SELECT/Realtime surface.
create table public.night_resolution_private (
  room_id uuid not null references public.rooms(id) on delete cascade,
  night integer not null,
  saved_seat integer,
  primary key (room_id, night)
);
alter table public.night_resolution_private enable row level security;
revoke all on public.night_resolution_private from public, anon, authenticated;
grant select, insert, update, delete on public.night_resolution_private to service_role;

-- Protect rolling deployments too: old Edge Functions still write savedSeat
-- through set_public_path. Split it BEFORE the row is stored or published.
create function public.protect_night_history()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare entry record;
begin
  if jsonb_typeof(new.public_data->'resolvedNights') = 'object' then
    for entry in select key, value from jsonb_each(new.public_data->'resolvedNights') loop
      if entry.value ? 'savedSeat' then
        insert into public.night_resolution_private(room_id, night, saved_seat)
          values (new.room_id, entry.key::integer, (entry.value->>'savedSeat')::integer)
          on conflict (room_id, night) do update set saved_seat = excluded.saved_seat;
        new.public_data = jsonb_set(new.public_data,
          array['resolvedNights', entry.key], entry.value - 'savedSeat');
      end if;
    end loop;
  end if;
  return new;
end;
$$;
revoke all on function public.protect_night_history() from public, anon, authenticated;
create trigger protect_night_history
before insert or update of public_data on public.room_state
for each row execute function public.protect_night_history();

-- Backfill and scrub in the same transaction; unrelated public history stays.
update public.room_state set public_data = public_data
where jsonb_path_exists(public_data, '$.resolvedNights.*.savedSeat');

create function public.record_night_resolution(
  p_room uuid, p_night integer, p_saved_seat integer, p_public jsonb
) returns void language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  perform 1 from public.room_state where room_id = p_room for update;
  if not found then raise exception 'room state missing'; end if;
  insert into public.night_resolution_private(room_id, night, saved_seat)
    values (p_room, p_night, p_saved_seat)
    on conflict (room_id, night) do update set saved_seat = excluded.saved_seat;
  perform public.set_public_path(p_room, array['resolvedNights', p_night::text],
    jsonb_build_object('victimSeat', p_public->'victimSeat', 'trace', p_public->'trace'));
end;
$$;
revoke all on function public.record_night_resolution(uuid, integer, integer, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_night_resolution(uuid, integer, integer, jsonb)
  to service_role;
