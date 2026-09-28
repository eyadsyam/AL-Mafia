/**
 * `create_room` — mints a room, a code and the match seed (doc 10 §5).
 *
 * The seed is generated here and **never returned**. Doc 10 §10: with it a
 * client could predict every tie-break in the match, including tonight's Mafia
 * target resolution and tomorrow's trace.
 */
import { fail, generateCode, handler, newMatchSeed, ok } from "../_shared/api.ts";
import { roomConfiguration } from "../_shared/room_configuration.ts";
import { ensureCosmeticAccess, ensureScenarioAccess } from "../_shared/purchase_access.ts";

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json().catch(() => ({}));
  const name = String(body.name ?? "").trim();
  if (!name) return fail("BAD_REQUEST", "a display name is required");
  if (name.length > 20) return fail("BAD_REQUEST", "display name too long");
  let configuration;
  try { configuration = roomConfiguration(body); }
  catch { return fail("BAD_REQUEST", "invalid room configuration"); }
  if (!await ensureScenarioAccess(db, userId, configuration.settings)) {
    return fail("PURCHASE_REQUIRED", "scenario is not owned", 403);
  }
  if (!await ensureCosmeticAccess(db, userId, configuration.settings)) {
    return fail("PURCHASE_REQUIRED", "presentation pack is not owned", 403);
  }

  // O13 — a duplicate code must be impossible, not merely unlikely. The unique
  // index decides; this loop just retries the collision. Checking first and
  // then inserting would be a race with exactly the outcome the check was for.
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = generateCode();
    const { data, error } = await db.rpc("create_room_atomic", {
      p_code: code, p_host: userId, p_name: name,
      p_gender: ["male", "female"].includes(body.gender) ? body.gender : "unspecified",
      p_seed: newMatchSeed(), p_configuration: configuration,
    });

    if (error) {
      if (error.code === "23505") continue;
      if (error.message?.includes("NEW_ROOMS_PAUSED")) {
        return fail("NEW_ROOMS_PAUSED", "new rooms are temporarily paused", 503);
      }
      if (error.message?.includes("ACCOUNT_RESTRICTED")) {
        return fail("ACCOUNT_RESTRICTED", "this account cannot open this table now", 403);
      }
      if (error.message?.includes("NAME_NOT_ALLOWED")) {
        return fail("NAME_NOT_ALLOWED", "that name is not allowed");
      }
      throw error;
    }

    return ok(data);
  }
  return fail("BAD_REQUEST", "could not allocate a room code");
}));
