-- Keep explicit online events immediate while giving browser heartbeat timers
-- enough slack to avoid false `away` states during ordinary rendering stalls.
-- A background/resume/exit still reaches set_presence directly; this function
-- only classifies clients that stopped reporting without a clean lifecycle
-- event.
create or replace function public.age_presence()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  changed integer;
begin
  update public.room_players p
     set status = 'away'
    from public.rooms r
   where r.id = p.room_id
     and r.status <> 'finished'
     and p.status = 'connected'
     and p.last_seen < now() - interval '25 seconds';

  with gone as (
    update public.room_players p
       set status = 'left', connected = false
      from public.rooms r
     where r.id = p.room_id
       and r.status <> 'finished'
       and p.status <> 'left'
       and p.last_seen < now() - interval '90 seconds'
    returning 1
  )
  select count(*) into changed from gone;

  return changed;
end;
$$;

revoke all on function public.age_presence() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema extensions;
    perform cron.unschedule('age-presence')
      where exists (select 1 from cron.job where jobname = 'age-presence');
    perform cron.schedule(
      'age-presence',
      '5 seconds',
      $cron$ select public.age_presence(); $cron$
    );
  end if;
end
$$;
