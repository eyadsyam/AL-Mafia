-- RL5 / D6 — one investigation a night, held by the database.
--
-- Offline the Detective looks once a night. Online the row key is
-- (room, night, actor) and every upsert used to be a fresh question, so a
-- Detective could ask about the whole table in one night (and a modified client
-- could do it silently). `submit_night_action` now refuses a second, different
-- question with RATE_LIMITED, but a read-then-write is exactly the race this
-- repo has met before: two requests that both read "no investigation yet" would
-- both write, and the second upsert would overwrite the first.
--
-- The rule lives under the row lock the update already holds. Once the night's
-- row says the Detective looked at somebody, no later write to that row can
-- change what he looked at, or give the look up. The same target again is the
-- same request arriving twice (a lost response, retried) and is allowed. The
-- insert path is not touched: a first write has nothing to protect, and the
-- timer default (`on conflict do nothing`) never reaches this trigger.

create or replace function public.guard_one_investigation() returns trigger
language plpgsql set search_path=public,pg_temp as $$
begin
  if old.action = 'investigate' and old.target_id is not null
     and (new.action <> 'investigate' or new.target_id is distinct from old.target_id) then
    raise exception 'ALREADY_INVESTIGATED' using errcode='P0001';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_one_investigation() from public,anon,authenticated;
drop trigger if exists night_action_one_investigation on public.night_actions;
create trigger night_action_one_investigation
  before update on public.night_actions
  for each row execute function public.guard_one_investigation();
