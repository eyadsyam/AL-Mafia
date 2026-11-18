import { fail, handler, ok } from "../_shared/api.ts";

const kinds = new Set(["roles", "online", "store", "look", "idea", "problem"]);
const platforms = new Set(["android", "web", "ios"]);

Deno.serve(handler(async (req, userId, db) => {
  const input = await req.json();
  // The star rating after a finished match: its own validation and table.
  if (input?.action === "rating") {
    const stars = input?.stars;
    const note = input?.body;
    if (!Number.isInteger(stars) || stars < 1 || stars > 5 ||
        (note != null && (typeof note !== "string" || note.trim().length > 500)) ||
        !Number.isInteger(input?.build) || input.build < 0 ||
        typeof input?.platform !== "string" || !platforms.has(input.platform)) {
      return fail("BAD_REQUEST", "invalid rating");
    }
    const { data, error } = await db.rpc("submit_rating", {
      p_user: userId, p_stars: stars, p_body: typeof note === "string" ? note.trim() : null,
      p_build: input.build, p_platform: input.platform,
    });
    if (error) {
      if (error.message.includes("RATE_LIMITED")) return fail("RATE_LIMITED", "try later", 429);
      if (error.message.includes("BAD_REQUEST")) return fail("BAD_REQUEST", "invalid rating");
      throw error;
    }
    return ok({ id: data?.id ?? null });
  }
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
    if (error.message.includes("SIGN_IN_REQUIRED")) {
      return fail("SIGN_IN_REQUIRED", "sign in first", 403);
    }
    if (error.message.includes("TOO_SHORT")) return fail("TOO_SHORT", "write a full sentence");
    if (error.message.includes("BAD_REQUEST"))return fail("BAD_REQUEST", "invalid feedback");
    throw error;
  }
  return ok({ id: data });
}));
