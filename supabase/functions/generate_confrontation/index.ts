/**
 * `generate_confrontation` — runs `selectConfrontation` over server-held
 * history and publishes the result (doc 10 §5).
 *
 * The client renders what this returns and never runs the generator itself: it
 * does not have the history and must not have the seed. The Dart generator is
 * the reference implementation and what offline mode plays on; the golden
 * vectors keep the two in step.
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
  if (me.hostId !== userId) return fail("NOT_HOST", "the host advances the day", 403);

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

  // C-E2 — no candidate is a normal outcome. The day goes straight to free
  // discussion and the app says nothing, because it has nothing true to say.
  const phase = confrontation ? "confront" : "discuss";

  // Two writes with different lifetimes. `confrontation` is *today's*, and the
  // screens read it until the day ends; `confrontations[day]` is the archive
  // the fairness factor reads on every later day ("no player twice in a
  // match") and must outlive it. Replacing `public_data` here — which this
  // handler used to do — emptied both archives and the resolved nights with
  // them.
  if (confrontation) {
    await db.rpc("set_public_path", {
      p_room: roomId,
      p_path: ["confrontations", String(me.phaseNumber)],
      p_value: confrontation,
    });
  }
  await db.rpc("merge_public_data", {
    p_room: roomId,
    p_patch: { confrontation, confrontationSilent: null },
  });

  await db.from("room_state").update({
    phase,
    phase_ends_at: deadlineFor(phase, me.settings),
    active_speaker: null,
    updated_at: new Date().toISOString(),
  }).eq("room_id", roomId);

  return ok({ confrontation });
}));
