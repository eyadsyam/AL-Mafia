/**
 * `generate_confrontation` — runs `selectConfrontation` over server-held
 * history and publishes the result (doc 10 §5).
 *
 * The client renders what this returns and never runs the generator itself: it
 * does not have the history and must not have the seed. The Dart generator is
 * the reference implementation and what offline mode plays on; the golden
 * vectors keep the two in step.
 *
 * It is the way a morning ends from day two onward, so it is bound by the same
 * rules as `open_phase`: only from the morning, by the host — or by anyone
 * once the morning's own clock has run out, because a match must not stop
 * for one phone that went to sleep — and as one compare-and-set on the phase,
 * day and deadline this caller read. Two drivers asking in the same instant
 * publish one confrontation, not two.
 */
import { fail, handler, loadMembership, ok } from "../_shared/api.ts";
import { buildHistory } from "../_shared/history.ts";
import { deadlineFor } from "../_shared/phases.ts";
import { selectConfrontation } from "../_shared/confrontation.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);
  if (me.phase !== "morning") {
    return fail("PHASE_CLOSED", "the day opens from the morning");
  }
  const expired = !!me.phaseEndsAt && new Date(me.phaseEndsAt) <= new Date();
  if (me.hostId !== userId && !expired) {
    return fail("NOT_HOST", "the host advances the day", 403);
  }

  const history = await buildHistory(db, roomId);
  const confrontation = selectConfrontation({
    history,
    dayNumber: me.phaseNumber,
    matchSeed: me.matchSeed,
    settings: {
      whisperEnabled: me.settings.whisperEnabled !== false,
      survivorConfrontationEnabled:
        me.settings.survivorConfrontationEnabled === true,
    },
  });

  const phase = confrontation ? "confront" : "discuss";

  const { data: moved, error } = await db.rpc("commit_confrontation", {
    p_room: roomId,
    p_number: me.phaseNumber,
    p_expected_deadline: me.phaseEndsAt,
    p_confrontation: confrontation,
    p_next: phase,
    p_deadline: deadlineFor(phase, me.settings),
  });
  if (error) throw error;
  if (!moved) return fail("PHASE_CLOSED", "the day has already opened");

  return ok({ confrontation });
}));
