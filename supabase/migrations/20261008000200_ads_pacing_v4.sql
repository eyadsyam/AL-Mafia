-- Ads pacing v4 (owner, 2026-10-08): more full-screen moments outside a match.
-- App-open on a return after 15 minutes away (20 between them, 10 a day);
-- interstitials up to 60 a day, 60 seconds apart; the menu interstitial after
-- 3 minutes; 2 minutes of quiet after a rewarded ad. Never inside a match.
alter table public.economy_config
  drop constraint if exists economy_config_app_open_gap_seconds_check,
  drop constraint if exists economy_config_app_open_max_per_day_check,
  drop constraint if exists economy_config_app_open_resume_after_seconds_check,
  drop constraint if exists economy_config_full_screen_max_per_day_check,
  drop constraint if exists economy_config_full_screen_min_gap_seconds_check,
  drop constraint if exists economy_config_session_interstitial_after_seconds_check;
alter table public.economy_config
  add constraint economy_config_app_open_gap_seconds_check check (app_open_gap_seconds >= 1200),
  add constraint economy_config_app_open_max_per_day_check check (app_open_max_per_day between 0 and 10),
  add constraint economy_config_app_open_resume_after_seconds_check check (app_open_resume_after_seconds >= 900),
  add constraint economy_config_full_screen_max_per_day_check check (full_screen_max_per_day between 0 and 60),
  add constraint economy_config_full_screen_min_gap_seconds_check check (full_screen_min_gap_seconds between 60 and 86400),
  add constraint economy_config_session_interstitial_after_seconds_check check (session_interstitial_after_seconds between 180 and 86400);
alter table public.economy_config
  drop constraint if exists economy_config_interstitial_after_reward_seconds_check;
alter table public.economy_config
  add constraint economy_config_interstitial_after_reward_seconds_check check (interstitial_after_reward_seconds >= 120);
update public.economy_config set
  app_open_gap_seconds = 1200, app_open_max_per_day = 10, app_open_resume_after_seconds = 900,
  full_screen_max_per_day = 60, full_screen_min_gap_seconds = 60,
  session_interstitial_after_seconds = 180, interstitial_after_reward_seconds = 120;
