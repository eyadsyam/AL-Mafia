-- RL1 / D1 — the quiet night is the Mafia team's one bullet.
--
-- Doc 13 and the offline engine (`Bullets.isSpentFor`): the first Mafioso who
-- arms «مش هقتل الليلة» spends it for the team, for the match, and that night
-- the Mafia kill nobody. Online each Mafioso had a bullet of his own — the
-- unique index (`night_actions_one_bullet_per_player`) is per player — so a
-- table of three Mafiosi had three quiet nights.
--
-- `submit_night_action` refuses a second Mafioso with RATE_LIMITED and
-- `resolve_night` cancels the kill; this is the line the database holds so two
-- Mafiosi who send the bullet in the same instant cannot both have it. The
-- check reads other rows, which a unique index cannot express, so the room's
-- bullet is serialised on an advisory lock: the second writer waits for the
-- first to commit and then sees its row.
--
-- Only role exactly `mafia` holds the bullet (the Silencer is on the team but
-- holds none). The per-player index and the keep-bullet trigger stay as they
-- were. Trigger names sort after `night_action_keep_bullet` and
-- `night_action_phase_guard`, so a stale write is refused as PHASE_CLOSED first.

create or replace function public.guard_team_bullet() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not new.used_bullet then return new; end if;
  if not exists(select 1 from public.room_players p
      where p.room_id=new.room_id and p.user_id=new.actor_id and p.role='mafia') then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('team_bullet:'||new.room_id::text, 41));
  if exists(select 1 from public.night_actions a
      join public.room_players p on p.room_id=a.room_id and p.user_id=a.actor_id
     where a.room_id=new.room_id and a.used_bullet and a.actor_id<>new.actor_id
       and p.role='mafia') then
    raise exception 'BULLET_SPENT' using errcode='P0001';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_team_bullet() from public,anon,authenticated;
drop trigger if exists night_action_team_bullet on public.night_actions;
create trigger night_action_team_bullet
  before insert or update on public.night_actions
  for each row execute function public.guard_team_bullet();
