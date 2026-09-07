/**
 * `browse_rooms` — the «أوض عامة» list (task 10).
 *
 * A thin wrapper over `public.public_rooms()`, which is where the decision
 * actually lives: `rooms` has RLS and a browser is by definition not a member
 * of the rooms they are browsing, so the list has to come from a security
 * definer function whose shape is fixed in a migration rather than from a
 * policy that would widen the table for every other query as well.
 *
 * Authenticated, like every other function here. An anonymous browse would be
 * a public directory of live rooms, which is not a growth loop — it is a list
 * for somebody writing a script.
 *
 * No polling. The client refreshes this when a person pulls the list down and
 * at no other time (doc 12: the lobby is the only place that streams).
 */
import { handler, ok } from "../_shared/api.ts";

Deno.serve(handler(async (_req, _userId, db) => {
  const { data, error } = await db.rpc("public_rooms");
  if (error) throw error;
  return ok({ rooms: data ?? [] });
}));
