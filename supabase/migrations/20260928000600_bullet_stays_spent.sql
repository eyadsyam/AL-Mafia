-- M5 — a bullet committed tonight stays spent tonight.
--
-- `night_actions` is keyed (room, night, actor), so every resubmission of the
-- same night's move lands on the same row. That is what makes a retry safe —
-- and it was also what made a refund possible: a move that spent the bullet
-- and lost its response on a weak network could be followed by a resubmit
-- without the bullet, and the upsert wrote `used_bullet = false` over the
-- spent one. The move changed, the bullet came back, and the once-per-match
-- rule quietly became twice.
--
-- The Edge Function could read the row first and OR the flag itself, but a
-- read-then-write is exactly the race the partial unique index exists to
-- close. The rule lives here instead, under the row lock the update already
-- holds: once this night's row says the bullet is spent, no later write to
-- that row can unsay it. A different night is a different row, and the
-- unique index still refuses the second bullet there.

create function public.keep_night_bullet_spent() returns trigger
language plpgsql set search_path=public,pg_temp as $$
begin
  new.used_bullet := old.used_bullet or new.used_bullet;
  return new;
end;
$$;
revoke all on function public.keep_night_bullet_spent() from public,anon,authenticated;
drop trigger if exists night_action_keep_bullet on public.night_actions;
create trigger night_action_keep_bullet
  before update on public.night_actions
  for each row execute function public.keep_night_bullet_spent();
