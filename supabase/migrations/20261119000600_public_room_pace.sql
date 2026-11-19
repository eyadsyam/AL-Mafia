-- O3 (owner 2026-11-19): public rooms the SERVER makes discuss for 180 s instead of 300 s.
--
-- Server-made public rooms are the system waiting rooms (system_pool is set) and the
-- quick-match rooms quick_match_atomic builds (visibility public, title «لعب سريع»,
-- a host id). Rather than re-copy those long functions to change one number, a
-- BEFORE INSERT trigger rewrites discussionSeconds on exactly those rows.
-- Rooms a host makes through create_room keep the host's choice. Thursday Night
-- rooms carry the title «ليلة الخميس» and keep thursday_preset() untouched, so the
-- Thursday scenario fingerprint is unchanged. Queue rooms (match_queue) set 180 themselves.

create or replace function public.public_room_pace()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.visibility = 'public'
     and (new.system_pool is not null or coalesce(new.title, '') = 'لعب سريع')
     and new.settings ? 'discussionSeconds' then
    new.settings := jsonb_set(new.settings, '{discussionSeconds}', '180'::jsonb);
  end if;
  return new;
end $$;
revoke all on function public.public_room_pace() from public, anon, authenticated;

drop trigger if exists rooms_public_pace on public.rooms;
create trigger rooms_public_pace before insert on public.rooms
  for each row execute function public.public_room_pace();

-- Rooms of that kind still waiting in the lobby take the new pace now.
update public.rooms r
   set settings = jsonb_set(r.settings, '{discussionSeconds}', '180'::jsonb)
 where r.status = 'lobby'
   and r.visibility = 'public'
   and (r.system_pool is not null or coalesce(r.title, '') = 'لعب سريع')
   and r.settings ? 'discussionSeconds';
