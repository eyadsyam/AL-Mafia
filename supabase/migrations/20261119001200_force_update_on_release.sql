-- Force update the moment the build is actually on Play (owner 2026-11-19:
-- «اول لما التحديث ينزل اجبر الكل علي التحديث»).
--
-- Raising min_build_android at upload time would lock every player out while
-- Google reviews the build. Instead the release sets
-- pending_min_build_android; play_release_watch raises latest_build_android
-- when Play publishes the build (app_update_announce), and this trigger then
-- moves min_build_android up to the pending value and clears it.
alter table public.app_config
  add column if not exists pending_min_build_android integer
    check (pending_min_build_android is null or pending_min_build_android > 0);

create or replace function public.app_config_force_on_release()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.pending_min_build_android is not null
     and coalesce(new.latest_build_android, 0) >= new.pending_min_build_android then
    new.min_build_android := greatest(coalesce(new.min_build_android, 0),
                                      new.pending_min_build_android);
    new.pending_min_build_android := null;
  end if;
  return new;
end $$;
revoke all on function public.app_config_force_on_release() from public, anon, authenticated;

drop trigger if exists app_config_force_on_release on public.app_config;
create trigger app_config_force_on_release before update on public.app_config
  for each row execute function public.app_config_force_on_release();
