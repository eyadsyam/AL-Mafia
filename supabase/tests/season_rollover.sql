-- Contract for 20260930000700_season_rollover. Rolled back by the harness.
begin;
do $$
declare zero public.mission_seasons; one public.mission_seasons; rolled text; n int;
begin
  -- Asleep: nothing ever active, nothing rolls.
  update public.mission_seasons set active=false;
  assert public.season_roll() is null,'a sleeping Casebook stays asleep';
  assert (select count(*) from public.mission_seasons)=1;

  -- Season Zero running: nothing rolls.
  update public.mission_seasons set active=true,starts_at=now()-interval '10 days',
    ends_at=now()+interval '18 days' where code='season_zero';
  assert public.season_roll() is null,'no roll while a season runs';

  -- Season Zero over two hours ago: season_01 starts where it ended.
  update public.mission_seasons set starts_at=now()-interval '28 days 2 hours',
    ends_at=now()-interval '2 hours' where code='season_zero';
  select * into zero from public.mission_seasons where code='season_zero';
  rolled:=public.season_roll();
  assert rolled='season_01',coalesce(rolled,'null');
  select * into one from public.mission_seasons where code='season_01';
  assert one.active and one.starts_at=zero.ends_at,'back to back';
  assert one.ends_at=one.starts_at+interval '28 days';
  assert now()>=one.starts_at and now()<one.ends_at,'now is inside it';
  assert public.season_roll() is null,'idempotent';
  -- The track: twenty levels, the same coins, titles become 50 coins.
  assert (select count(*) from public.season_reward_catalog where season_id=one.id)=20;
  assert not exists(select 1 from public.season_reward_catalog
    where season_id=one.id and title_code is not null),'titles stay Season Zero''s';
  assert (select coins from public.season_reward_catalog where season_id=one.id and level=10)=50;
  assert (select coins from public.season_reward_catalog where season_id=one.id and level=2)=25;
  -- The Casebook reads it as the current season.
  assert public.invite_v3_season()=one.id,'current season';

  -- A roll that runs weeks late lands on the 28-day grid around now.
  update public.mission_seasons set starts_at=now()-interval '108 days',
    ends_at=now()-interval '80 days' where code='season_zero';
  update public.mission_seasons set starts_at=now()-interval '80 days',
    ends_at=now()-interval '52 days' where code='season_01';
  rolled:=public.season_roll();
  assert rolled='season_02',coalesce(rolled,'null');
  select * into one from public.mission_seasons where code='season_02';
  assert now()>=one.starts_at and now()<one.ends_at,'late roll still covers now';
  assert abs(extract(epoch from one.starts_at-(now()-interval '24 days')))<1,'on the grid';

  -- Opening the Casebook rolls too.
  update public.mission_seasons set starts_at=now()-interval '29 days',
    ends_at=now()-interval '1 day' where code='season_02';
  perform public.casebook_sync(gen_random_uuid());
  assert exists(select 1 from public.mission_seasons where code='season_03' and active);
  assert exists(select 1 from cron.job where jobname='season-roll') or
    not exists(select 1 from pg_extension where extname='pg_cron');
end $$;
rollback;
