/**
 * `tester_admin` — the owner's tester page (saidalmafia.com/admin/testers/,
 * a static page outside the game that signs in with the same account).
 *
 *   list    {}                          visits to /beta and every sign-up
 *   set     { ids: number[], status }   new | added | active | problem | removed
 *   note    { id, note }                a private note, up to 300 characters
 *   delete  { ids: number[] }           erase sign-ups (a deletion request)
 *
 * Every action is refused by the database to anyone outside `commerce_admins`.
 */

import { fail, handler, ok } from "../_shared/api.ts";

const STATUSES = new Set(["new", "added", "active", "problem", "removed"]);

function ids(value: unknown): number[] | null {
  if (!Array.isArray(value) || value.length < 1 || value.length > 5000) return null;
  return value.every((v) => Number.isInteger(v) && v > 0) ? value as number[] : null;
}

Deno.serve(handler(async (req, userId, db) => {
  const body = await req.json();
  let call: { fn: string; args: Record<string, unknown> } | null = null;
  switch (body?.action) {
    case "list":
      call = { fn: "admin_testers", args: {} };
      break;
    case "set": {
      const list = ids(body.ids);
      if (!list || !STATUSES.has(body.status)) break;
      call = { fn: "admin_tester_set", args: { p_ids: list, p_status: body.status } };
      break;
    }
    case "note":
      if (!Number.isInteger(body.id) || typeof body.note !== "string" || body.note.length > 300) break;
      call = { fn: "admin_tester_note", args: { p_id: body.id, p_note: body.note } };
      break;
    case "delete": {
      const list = ids(body.ids);
      if (!list) break;
      call = { fn: "admin_tester_delete", args: { p_ids: list } };
      break;
    }
  }
  if (!call) return fail("BAD_REQUEST", "invalid tester request");
  const { data, error } = await db.rpc(call.fn, { p_admin: userId, ...call.args });
  if (error) {
    if (error.message === "NOT_ADMIN") return fail("NOT_ADMIN", "not an administrator", 403);
    if (error.message === "BAD_REQUEST") return fail("BAD_REQUEST", "invalid tester request");
    throw error;
  }
  return ok(body.action === "list" ? data : { ok: true, count: data ?? 0 });
}));
