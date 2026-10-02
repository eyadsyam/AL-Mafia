-- Browse must report the same lobby population as admission and role dealing.
create or replace function public.public_rooms()
returns table (code text, title text, players int, voice boolean)
language sql security definer set search_path=public,pg_temp stable as $$
  select r.code, r.title,
    (select count(*) from public.room_players p where p.room_id=r.id and not p.kicked)::int,
    coalesce((r.settings->>'voice')::boolean,true)
  from public.rooms r
  where r.visibility='public' and r.status='lobby'
  order by r.created_at desc limit 50;
$$;
revoke all on function public.public_rooms() from public,anon,authenticated;
grant execute on function public.public_rooms() to service_role;
