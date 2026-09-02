-- The «اسم واحد» opening round, and the two accumulating parts of the public
-- payload it shares with the rest of the day (doc 09 §2.2).
--
-- ## Why `opening` was missing
--
-- The first schema wrote the day as `confront | discuss | defense | vote`,
-- which is doc 10's list. Doc 09 §2.2 then adds a phase in front of all of
-- them on Day 1: every living player, in seating order, ten seconds each, one
-- name, no explanations. It has a *current actor* — the room is pointed at one
-- seat at a time — and that is exactly what separates it from `discuss`, so it
-- cannot be folded into it. The offline engine already models it as its own
-- `GamePhase.openingRound`; this is the same phase reaching the server.

alter table public.room_state
  drop constraint if exists room_state_phase_valid;

alter table public.room_state
  add constraint room_state_phase_valid check (phase in (
    'lobby', 'reveal', 'night', 'morning', 'opening', 'confront',
    'discuss', 'defense', 'vote', 'result'
  ));

-- ── the public payload, written safely ───────────────────────────────────
--
-- `public_data` accumulates across a whole match: the resolved nights, the
-- opening accusations, the confrontation archive and the floor time are all
-- read back by `buildHistory`, which is what feeds the trace and confrontation
-- generators. Two things follow.
--
-- **It must never be replaced.** A handler that writes `public_data: { x }`
-- silently drops every fact the generators depend on, and the symptom is not a
-- crash — it is a match that stops finding anything to say. Everything below
-- merges.
--
-- **The merge must be one statement.** Read-modify-write from an Edge Function
-- races: two accusations landing together, or a heartbeat overlapping a
-- resolve, and one of them is gone. A single `update ... set public_data =
-- public_data || patch` is atomic against the row, so it cannot interleave.
--
-- `security definer`, granted only to the service role: these bypass RLS by
-- construction and no client may call them.

create or replace function public.merge_public_data(
  p_room  uuid,
  p_patch jsonb
) returns void
language sql
security definer
set search_path = public
as $$
  update public.room_state
     set public_data = public_data || p_patch,
         updated_at  = now()
   where room_id = p_room;
$$;

-- Writes one value at a path, creating the intermediate objects. Used for the
-- archives, where the key is a day or a night number and merging at the top
-- level would overwrite the sibling entries.
create or replace function public.set_public_path(
  p_room  uuid,
  p_path  text[],
  p_value jsonb
) returns void
language sql
security definer
set search_path = public
as $$
  update public.room_state
     set public_data = jsonb_set(
           case
             when public_data #> p_path[1:array_length(p_path, 1) - 1] is null
               then jsonb_set(
                      public_data,
                      p_path[1:array_length(p_path, 1) - 1],
                      '{}'::jsonb,
                      true)
             else public_data
           end,
           p_path,
           p_value,
           true),
         updated_at = now()
   where room_id = p_room;
$$;

-- Floor time, accumulated. A player who speaks three times in a day has spoken
-- for the sum of the three, and `C3` («لسه ماتكلمش») reads the total — so this
-- adds rather than sets.
create or replace function public.add_speaking_seconds(
  p_room    uuid,
  p_day     int,
  p_seat    int,
  p_seconds int
) returns void
language sql
security definer
set search_path = public
as $$
  update public.room_state
     set public_data = jsonb_set(
           jsonb_set(
             public_data,
             array['speakingSeconds'],
             coalesce(public_data -> 'speakingSeconds', '{}'::jsonb),
             true),
           array['speakingSeconds', p_day::text, p_seat::text],
           to_jsonb(
             coalesce(
               (public_data #>> array['speakingSeconds', p_day::text, p_seat::text])::int,
               0) + p_seconds),
           true),
         updated_at = now()
   where room_id = p_room;
$$;

revoke all on function public.merge_public_data(uuid, jsonb)      from anon, authenticated;
revoke all on function public.set_public_path(uuid, text[], jsonb) from anon, authenticated;
revoke all on function public.add_speaking_seconds(uuid, int, int, int) from anon, authenticated;
