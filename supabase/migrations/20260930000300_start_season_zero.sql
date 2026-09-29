-- Release 1.1: Season Zero must be live when Missions is enabled. The earlier
-- migration deliberately left it asleep for staged rollout; this release
-- migration is the idempotent 100% activation step.
do $$
declare launched_at timestamptz := clock_timestamp();
begin
  update public.mission_seasons s
     set starts_at = launched_at,
         ends_at = launched_at + interval '28 days',
         active = true
   where s.code = 'season_zero'
     and not s.active
     and not exists (
       select 1 from public.season_xp_events e where e.season_id = s.id
     );
end $$;
