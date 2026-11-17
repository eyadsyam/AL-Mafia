-- pg_cron writes one row to cron.job_run_details for every run and never
-- deletes it. With two jobs every 5 seconds and two every 30 seconds that is
-- about 41,000 rows a day; by 2026-11-17 the table held 2.27 million rows,
-- 370 MB of a 399 MB database on a plan capped at 500 MB. Keep two days of
-- history (enough to read a failure) and drop the rest every night.
--
-- The one-time cleanup of the old rows ran by hand on 2026-11-17 (kept the
-- last two days, truncated the rest); this file only adds the nightly job.

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'purge-cron-history',
      '47 3 * * *',
      $cron$ delete from cron.job_run_details where end_time < now() - interval '2 days'; $cron$
    );
  end if;
end $$;
