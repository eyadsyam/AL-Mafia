import { fail, handler, ok } from "../_shared/api.ts";

const kinds = new Set(["roles", "online", "store", "look", "idea", "problem"]);
const platforms = new Set(["android", "web", "ios"]);

Deno.serve(handler(async (req, userId, db) => {
  const input = await req.json();
  const kind = input?.kind;
  const body = input?.body;
  const build = input?.build;
  const platform = input?.platform;
  if (typeof kind !== "string" || !kinds.has(kind) ||
      typeof body !== "string" || body.trim().length < 2 || body.trim().length > 500 ||
      !Number.isInteger(build) || build < 0 ||
      typeof platform !== "string" || !platforms.has(platform)) {
    return fail("BAD_REQUEST", "invalid feedback");
  }
  const { data, error } = await db.rpc("submit_feedback", {
    p_user: userId, p_kind: kind, p_body: body.trim(),
    p_build: build, p_platform: platform,
  });
  if (error) {
    if (error.message.includes("RATE_LIMITED")) return fail("RATE_LIMITED", "try later", 429);
    if (error.message.includes("BAD_REQUEST")) return fail("BAD_REQUEST", "invalid feedback");
    throw error;
  }
  return ok({ id: data });
}));
