-- The verdict — the beat between the ballot and the night that follows it.
--
-- ## Why it was missing
--
-- The day was written as `opening | confront | discuss | defense | vote`, and
-- `resolve_vote` went straight from `vote` to `night`. Offline that beat has
-- always existed: `GamePhase.reveal`, where the eliminated player's card rises
-- and turns over (doc 15 §S-O12). Online there was no phase for it to be, so
-- `phaseFromServer` could never produce it, the card and the «فلان كان ...»
-- band were unreachable code, and a player cast a vote and arrived at a dark
-- table with no idea what had happened.
--
-- ## The failure mode this constraint has, and why it is worth naming
--
-- `resolve_vote` wrote `phase: 'verdict'` before this migration existed. The
-- write was refused by the constraint, the handler was not checking the error,
-- and the function answered 200 with a correct tally while the room stayed on
-- the ballot forever. The handler now reads that error. The lesson is the one
-- doc 10 §10 keeps making: a write whose failure nobody reads is not a write.
alter table public.room_state
  drop constraint if exists room_state_phase_valid;

alter table public.room_state
  add constraint room_state_phase_valid check (phase in (
    'lobby', 'reveal', 'night', 'morning', 'opening', 'confront',
    'discuss', 'defense', 'vote', 'verdict', 'result'
  ));
