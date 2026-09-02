/**
 * The three attacks doc 10 §10 and doc 11 O16–O18 require to be **proven** to
 * fail, plus the ones next to them.
 *
 * ```
 * supabase start
 * deno test --allow-net --allow-env supabase/tests/anticheat.test.ts
 * ```
 *
 * ## Why these are integration tests and not unit tests
 *
 * Every one of them is an assertion about a *deployed policy*. A unit test can
 * say the handler checks a role; only a real request against a real database
 * can say the role table is unreachable when somebody skips the handler
 * entirely and talks to PostgREST — which is what an attacker would do.
 *
 * So this suite is deliberately hostile: it authenticates as two ordinary
 * anonymous players and then tries, as a client, everything the design says a
 * client cannot do. **A passing run is one where every attack is refused.**
 *
 * Doc 11's release gate reads "Automated attempt to read another player's role
 * **fails**" — the test passing means the attack failed, and that inversion is
 * worth keeping in mind when reading the assertions below.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

if (!ANON || !SERVICE) {
  console.error(
    "Set SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY " +
      "(`supabase status` prints both).",
  );
  Deno.exit(2);
}

interface Player {
  client: SupabaseClient;
  id: string;
  token: string;
}

async function anonPlayer(): Promise<Player> {
  const client = createClient(URL, ANON, { auth: { persistSession: false } });
  const { data, error } = await client.auth.signInAnonymously();
  if (error || !data.session) throw error ?? new Error("no session");
  return {
    client,
    id: data.session.user.id,
    token: data.session.access_token,
  };
}

async function call(
  player: Player,
  fn: string,
  body: unknown,
): Promise<{ status: number; json: Record<string, unknown> }> {
  const res = await fetch(`${URL}/functions/v1/${fn}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${player.token}`,
      apikey: ANON,
    },
    body: JSON.stringify(body),
  });
  return { status: res.status, json: await res.json().catch(() => ({})) };
}

/** A started five-player match, with two of the seats under our control. */
async function startedRoom() {
  const host = await anonPlayer();
  const guest = await anonPlayer();

  const created = await call(host, "create_room", { name: "Host" });
  const roomId = created.json.roomId as string;
  const code = created.json.code as string;

  await call(guest, "join_room", { code, name: "Guest" });

  // Three more seats, so the roster reaches the five-player minimum.
  const filler: Player[] = [];
  for (let i = 0; i < 3; i++) {
    const p = await anonPlayer();
    await call(p, "join_room", { code, name: `Filler ${i}` });
    filler.push(p);
  }

  await call(host, "start_match", {
    roomId,
    roles: { mafia: 1, doctor: 1, detective: 1, citizen: 2 },
  });

  return { host, guest, filler, roomId, code };
}

const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });

// ─────────────────────────────────────────────────────────────────────────
// O16 — a client must not be able to read another player's role.
// ─────────────────────────────────────────────────────────────────────────

Deno.test("O16 — the role table itself is unreachable", async () => {
  const { guest, roomId } = await startedRoom();

  // The base table, directly. RLS grants a select on rows in your own room —
  // but the *grant* is revoked, so PostgREST refuses before RLS is consulted.
  const { data, error } = await guest.client
    .from("room_players")
    .select("user_id, role")
    .eq("room_id", roomId);

  assert(
    error !== null || (data ?? []).length === 0,
    "room_players must not be readable by a client",
  );
});

Deno.test("O16 — the view returns only the caller's own role", async () => {
  const { host, guest, roomId } = await startedRoom();

  const { data, error } = await guest.client
    .from("room_players_public")
    .select("user_id, seat, name, role")
    .eq("room_id", roomId);

  assertEquals(error, null, "the public view must be readable");
  const rows = data ?? [];
  assert(rows.length >= 5, "the whole roster is public except for roles");

  for (const row of rows) {
    if (row.user_id === guest.id) {
      assert(row.role !== null, "a player must be able to read their own role");
    } else {
      assertEquals(
        row.role,
        null,
        `seat ${row.seat}'s role leaked to another player`,
      );
    }
  }

  // And specifically the host's, which is the row an attacker would want.
  const hostRow = rows.find((r) => r.user_id === host.id);
  assertEquals(hostRow?.role, null);
});

Deno.test("O16 — night actions name a role, and are readable only by their actor",
  async () => {
    const { host, guest, roomId } = await startedRoom();
    await admin.from("room_state").update({ phase: "night", phase_number: 1 })
      .eq("room_id", roomId);

    // The host takes their turn, whatever it is.
    const { data: hostRole } = await admin.from("room_players")
      .select("role").eq("room_id", roomId).eq("user_id", host.id).single();
    const action = {
      mafia: "kill",
      doctor: "protect",
      detective: "investigate",
      citizen: "suspect",
    }[hostRole!.role as string]!;
    const { data: other } = await admin.from("room_players")
      .select("seat").eq("room_id", roomId).eq("user_id", guest.id).single();
    await call(host, "submit_night_action", {
      roomId,
      action,
      targetSeat: other!.seat,
    });

    // Now the guest goes looking. `action` would name the host's role outright.
    const { data } = await guest.client
      .from("night_actions")
      .select("actor_id, action, target_id")
      .eq("room_id", roomId);
    const foreign = (data ?? []).filter((r) => r.actor_id !== guest.id);
    assertEquals(foreign.length, 0, "another player's night action leaked");
  });

// ─────────────────────────────────────────────────────────────────────────
// O17 — a client must not be able to vote as somebody else.
// ─────────────────────────────────────────────────────────────────────────

Deno.test("O17 — a direct insert into votes is refused", async () => {
  const { host, guest, roomId } = await startedRoom();
  await admin.from("room_state").update({ phase: "vote", phase_number: 1 })
    .eq("room_id", roomId);

  const { error } = await guest.client.from("votes").insert({
    room_id: roomId,
    day: 1,
    voter_id: host.id, // somebody else's ballot
    target_id: guest.id,
    round: 1,
  });
  assert(error !== null, "a client wrote directly to votes");

  const { count } = await admin.from("votes")
    .select("*", { count: "exact", head: true })
    .eq("room_id", roomId);
  assertEquals(count, 0, "the forged ballot landed");
});

Deno.test("O17 — the function takes the voter from the token, not the body",
  async () => {
    const { host, guest, roomId } = await startedRoom();
    await admin.from("room_state").update({ phase: "vote", phase_number: 1 })
      .eq("room_id", roomId);

    const { data: hostSeat } = await admin.from("room_players")
      .select("seat").eq("room_id", roomId).eq("user_id", host.id).single();

    // The guest submits, and tries to claim the host's identity in the payload.
    await call(guest, "submit_vote", {
      roomId,
      targetSeat: hostSeat!.seat,
      voter_id: host.id,
      voterSeat: hostSeat!.seat,
      userId: host.id,
    });

    const { data: rows } = await admin.from("votes")
      .select("voter_id").eq("room_id", roomId);
    assertEquals(rows?.length, 1);
    assertEquals(
      rows![0].voter_id,
      guest.id,
      "the body was allowed to name the voter",
    );
  });

// ─────────────────────────────────────────────────────────────────────────
// O18 — a client must not be able to act with a role it does not have.
// ─────────────────────────────────────────────────────────────────────────

Deno.test("O18 — an action the caller's role does not perform is refused",
  async () => {
    const { host, guest, roomId } = await startedRoom();
    await admin.from("room_state").update({ phase: "night", phase_number: 1 })
      .eq("room_id", roomId);

    const { data: me } = await admin.from("room_players")
      .select("role").eq("room_id", roomId).eq("user_id", guest.id).single();
    const mine = {
      mafia: "kill",
      doctor: "protect",
      detective: "investigate",
      citizen: "suspect",
    }[me!.role as string]!;

    const { data: hostSeat } = await admin.from("room_players")
      .select("seat").eq("room_id", roomId).eq("user_id", host.id).single();

    for (const action of ["kill", "protect", "investigate", "suspect"]) {
      if (action === mine) continue;
      const res = await call(guest, "submit_night_action", {
        roomId,
        action,
        targetSeat: hostSeat!.seat,
      });
      assertEquals(
        res.json.error,
        "WRONG_ROLE",
        `"${action}" was accepted from a ${me!.role}`,
      );
    }
  });

Deno.test("O18 — a direct insert into night_actions is refused", async () => {
  const { guest, roomId } = await startedRoom();
  const { error } = await guest.client.from("night_actions").insert({
    room_id: roomId,
    night: 1,
    actor_id: guest.id,
    action: "kill",
    target_id: guest.id,
  });
  assert(error !== null, "a client wrote directly to night_actions");
});

// ─────────────────────────────────────────────────────────────────────────
// The seed, and the whisper bodies.
// ─────────────────────────────────────────────────────────────────────────

Deno.test("the match seed never reaches a client", async () => {
  const { guest, roomId } = await startedRoom();

  const { data: direct } = await guest.client
    .from("rooms").select("match_seed").eq("id", roomId);
  assert(
    (direct ?? []).length === 0,
    "rooms is directly readable, and it carries the seed",
  );

  const { data: view } = await guest.client
    .from("rooms_public").select("*").eq("id", roomId);
  for (const row of view ?? []) {
    assert(
      !("match_seed" in row),
      "the public room view exposes the seed — every tie-break becomes " +
        "predictable (doc 10 §10)",
    );
  }
});

Deno.test("a whisper body is readable only by its two parties", async () => {
  const { host, guest, filler, roomId } = await startedRoom();
  await admin.from("room_state").update({ phase: "discuss", phase_number: 1 })
    .eq("room_id", roomId);
  await admin.from("rooms")
    .update({ settings: { whisperEnabled: true } }).eq("id", roomId);

  const { data: guestSeat } = await admin.from("room_players")
    .select("seat").eq("room_id", roomId).eq("user_id", guest.id).single();

  const sent = await call(host, "send_whisper", {
    roomId,
    toSeat: guestSeat!.seat,
    body: "the-body-that-must-not-travel",
  });
  assertEquals(sent.status, 200);

  // The recipient may read it.
  const { data: mine } = await guest.client
    .from("whisper_content").select("body");
  assertEquals(mine?.length, 1);

  // A third player may not, and may still see the edge — that asymmetry is the
  // whole layer (doc 09 §3.1).
  const bystander = filler[0];
  const { data: theirs } = await bystander.client
    .from("whisper_content").select("body");
  assertEquals(theirs?.length ?? 0, 0, "a whisper body leaked to the table");

  const { data: graph } = await bystander.client
    .from("whisper_meta").select("from_id, to_id, day").eq("room_id", roomId);
  assertEquals(graph?.length, 1, "the graph must be public");
});

Deno.test("H-E1 — the second whisper of the day is refused server-side",
  async () => {
    const { host, guest, filler, roomId } = await startedRoom();
    await admin.from("room_state").update({ phase: "discuss", phase_number: 1 })
      .eq("room_id", roomId);
    await admin.from("rooms")
      .update({ settings: { whisperEnabled: true } }).eq("id", roomId);

    const { data: a } = await admin.from("room_players")
      .select("seat").eq("room_id", roomId).eq("user_id", guest.id).single();
    const { data: b } = await admin.from("room_players")
      .select("seat").eq("room_id", roomId).eq("user_id", filler[0].id).single();

    const first = await call(host, "send_whisper", {
      roomId, toSeat: a!.seat, body: "one",
    });
    assertEquals(first.status, 200);

    const second = await call(host, "send_whisper", {
      roomId, toSeat: b!.seat, body: "two",
    });
    assertEquals(second.json.error, "RATE_LIMITED");
  });

Deno.test("a non-member cannot act on a room at all", async () => {
  const { roomId } = await startedRoom();
  const stranger = await anonPlayer();

  const vote = await call(stranger, "submit_vote", { roomId, targetSeat: 0 });
  assertEquals(vote.json.error, "NOT_A_MEMBER");

  const night = await call(stranger, "submit_night_action", {
    roomId, action: "kill", targetSeat: 0,
  });
  assertEquals(night.json.error, "NOT_A_MEMBER");

  const { data } = await stranger.client
    .from("room_players_public").select("*").eq("room_id", roomId);
  assertEquals(data?.length ?? 0, 0, "a stranger read the roster");
});

Deno.test("an unauthenticated call is refused", async () => {
  const { roomId } = await startedRoom();
  const res = await fetch(`${URL}/functions/v1/submit_vote`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON },
    body: JSON.stringify({ roomId, targetSeat: 0 }),
  });
  assertEquals(res.status, 401);
  await res.body?.cancel();
});
