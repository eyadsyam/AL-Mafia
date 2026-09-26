-- Conservative proxy for the Free-plan 2M monthly Realtime message quota.
-- Architecture testing estimated about 600 messages per ten-player match;
-- 3,000 matches leaves a safety margin. The provider dashboard remains the
-- billing source of truth because room shape and reconnects change traffic.
insert into public.usage_thresholds(metric,monthly_limit,updated_at)
values('matches_started',3000,now())
on conflict(metric) do update set monthly_limit=excluded.monthly_limit,updated_at=now();

