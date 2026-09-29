-- Launch audit: Season Zero runs 28 days and nothing started the next one, so
-- the Casebook would go empty again four weeks after launch.
--
-- `season_roll()` starts the next season the moment the current one is over:
-- `season_01`, `season_02`, … each 28 days, back to back with the one before
-- (if the roll runs late, the new season still starts on the 28-day grid, so
-- "now" falls inside it). The reward track copies the last season's coins;
-- the titles stay Season Zero's own, so the levels that gave a title give
-- 50 coins instead. It never starts the very first season: a Casebook the
-- operator has not started (no season ever active) stays asleep.
--
-- It runs hourly from pg_cron where available and on every Casebook open
-- (`casebook_sync`), and is idempotent.
create or replace function public.season_roll()
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare last public.mission_seasons; n int; starts timestamptz; next_code text; sid bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended('season_roll',7));
  if exists(select 1 from public.mission_seasons
      where active and now()>=starts_at and now()<ends_at) then
    return null;
  end if;
  select * into last from public.mission_seasons
   where active order by ends_at desc limit 1;
  if last.id is null or last.ends_at>now() then return null; end if;
  starts:=last.ends_at + floor(extract(epoch from now()-last.ends_at)
    / extract(epoch from interval '28 days')) * interval '28 days';
  select count(*) into n from public.mission_seasons s where s.code ~ '^season_[0-9]{2,}$';
  next_code:='season_'||lpad((n+1)::text,2,'0');
  while exists(select 1 from public.mission_seasons s where s.code=next_code) loop
    n:=n+1; next_code:='season_'||lpad((n+1)::text,2,'0');
  end loop;
  insert into public.mission_seasons(code,starts_at,ends_at,active)
    values(next_code,starts,starts+interval '28 days',true) returning id into sid;
  insert into public.season_reward_catalog(season_id,level,coins,item_code,title_code)
  select sid,r.level,
         case when r.title_code is not null and r.coins=0 then 50 else r.coins end,
         null,null
    from public.season_reward_catalog r where r.season_id=last.id;
  return next_code;
end $$;
revoke all on function public.season_roll() from public,anon,authenticated;
grant execute on function public.season_roll() to service_role;

create or replace function public.casebook_sync(p_user uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare rid uuid;
begin
  perform public.season_roll();
  perform public.council_sync(p_user);
  for rid in select room_id from public.council_match_records
    where user_id=p_user and eligible order by ended_at loop
    perform public.casebook_record_match(p_user,rid);
  end loop;
end $$;

do $$ begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.unschedule('season-roll') where exists(select 1 from cron.job where jobname='season-roll');
    perform cron.schedule('season-roll','3 * * * *',$cron$select public.season_roll();$cron$);
  end if;
end $$;
