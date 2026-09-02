/**
 * `my_team` — the fellow Mafia, by name, to the Mafia and to nobody else.
 *
 * ## Why this cannot be a view
 *
 * It is also where a player learns their **own** role. That used to come from
 * `room_players_public`, which returned it for `auth.uid()` and nulled it for
 * everyone else — correct, but it left the column one policy edit away from
 * the room. It is off the client surface now (no column privilege for any
 * client role), so this function answers both halves of the same question.
 *
 * Every other secret in the schema belongs to exactly one row and can be
 * redacted by comparing `user_id` to `auth.uid()` — which is what
 * `room_players_public` does with `role`. A teammate list is the opposite
 * shape: it is *other people's* roles, and the only thing that entitles the
 * caller to them is a fact about the caller's own row. A view expressing that
 * would have to read the role column for rows it does not own, which is the
 * one thing doc 10 §4.1 does not let anything do.
 *
 * So it runs here, as the service role, and answers exactly one question:
 * "if — and only if — you are Mafia, who else is?" A Citizen asking gets an
 * empty list, which is the same answer a lone Mafioso gets, so the response
 * shape tells nobody anything either.
 *
 * ## Why names and not seats
 *
 * The reveal card names teammates the way the offline one does («معاك:
 * ...»), and a seat number would be a second thing to look up while holding a
 * card you are about to hide.
 */

import { fail, handler, loadMembership, ok } from "../_shared/api.ts";

Deno.serve(handler(async (req, userId, db) => {
  const { roomId } = await req.json();
  if (!roomId) return fail("BAD_REQUEST", "roomId required");

  const me = await loadMembership(db, roomId, userId);
  if (!me) return fail("NOT_A_MEMBER", "you are not in that room", 403);

  // The caller's own role travels with the teammate list because there is
  // nowhere else for it to travel: `role` is not on the client surface at all
  // — no client role holds a column privilege for it — so this call is the
  // whole of how a player learns what they are. Null until `start_match` deals.
  if (me.role !== "mafia") return ok({ role: me.role ?? null, teammates: [] });

  const { data } = await db
    .from("room_players")
    .select("name, seat")
    .eq("room_id", roomId)
    .eq("role", "mafia")
    .neq("user_id", userId)
    .order("seat");

  return ok({ role: "mafia", teammates: (data ?? []).map((p) => p.name) });
}));
