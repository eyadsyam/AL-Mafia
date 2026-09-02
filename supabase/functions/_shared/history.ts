/**
 * Builds a `GameHistory` from the server's tables — the TypeScript counterpart
 * of `buildHistory` in `lib/engine/information/game_history.dart`.
 *
 * ## What it deliberately does not read
 *
 * Roles. Neither generator consults one, and a helper that fetched them anyway
 * would put the role table one careless `console.log` away from a function's
 * stderr. The night actions are read for *what was done*, never for *who could
 * do it*.
 *
 * ## Seats, not user ids
 *
 * Everything downstream of here is seat-numbered, exactly like the offline
 * engine, so the generators are literally the same functions. The mapping is
 * built once, here, at the boundary.
 */
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type {
  ConfrontationType,
  DayRecord,
  GameHistory,
  NightRecord,
  TraceType,
} from "./records.ts";

export async function buildHistory(
  db: SupabaseClient,
  roomId: string,
): Promise<GameHistory> {
  const { data: players } = await db
    .from("room_players")
    .select("user_id, seat, alive")
    .eq("room_id", roomId)
    .order("seat");
  const roster = players ?? [];
  const seatOf = new Map<string, number>(
    roster.map((p) => [p.user_id, p.seat]),
  );
  const alive = roster.filter((p) => p.alive).map((p) => p.seat);

  const { data: actions } = await db
    .from("night_actions")
    .select("night, actor_id, action, target_id")
    .eq("room_id", roomId)
    .order("night");

  const { data: votes } = await db
    .from("votes")
    .select("day, voter_id, target_id, round")
    .eq("room_id", roomId)
    .order("day");

  const { data: whispers } = await db
    .from("whisper_meta")
    .select("day, from_id, to_id")
    .eq("room_id", roomId)
    .order("day");

  const { data: state } = await db
    .from("room_state")
    .select("public_data")
    .eq("room_id", roomId)
    .maybeSingle();

  // The published history the server keeps alongside the tables: which trace
  // went out on which morning, which confrontation was issued on which day,
  // and the floor time the discussion screen reported. All of it is public and
  // all of it is already in `public_data`, which is the payload the room reads.
  const archive = (state?.public_data ?? {}) as {
    resolvedNights?: Record<string, {
      victimSeat: number | null;
      savedSeat: number | null;
      trace: TraceType | null;
    }>;
    openingAccusations?: Record<string, number>;
    confrontations?: Record<string, {
      type: ConfrontationType;
      targetSeat: number;
      evidenceSeat: number | null;
      evidenceSeat2: number | null;
      evidenceDay: number | null;
      count: number | null;
    }>;
    speakingSeconds?: Record<string, Record<string, number>>;
  };

  // ── nights ──────────────────────────────────────────────────────────────
  const nightNumbers = new Set<number>();
  for (const a of actions ?? []) nightNumbers.add(a.night);
  for (const key of Object.keys(archive.resolvedNights ?? {})) {
    nightNumbers.add(Number(key));
  }

  const nights: NightRecord[] = [];
  for (const n of [...nightNumbers].sort((a, b) => a - b)) {
    const suspicions: Record<number, number | null> = {};
    for (const a of actions ?? []) {
      if (a.night !== n) continue;
      const seat = seatOf.get(a.actor_id);
      if (seat === undefined) continue;
      if (a.action === "suspect") {
        suspicions[seat] = seatOf.get(a.target_id ?? "") ?? null;
      } else if (a.action === "skip") {
        // A skip is a recorded choice, not a missing row — `T6` and `C10` both
        // read the difference.
        suspicions[seat] = null;
      }
    }
    const resolved = archive.resolvedNights?.[String(n)];
    nights.push({
      nightNumber: n,
      suspicions,
      victim: resolved?.victimSeat ?? null,
      saveOccurred: resolved?.savedSeat != null,
      savedSeat: resolved?.savedSeat ?? null,
      revealedTrace: resolved?.trace ?? null,
      resolved: resolved !== undefined,
    });
  }

  // ── days ────────────────────────────────────────────────────────────────
  const dayNumbers = new Set<number>();
  for (const v of votes ?? []) dayNumbers.add(v.day);
  for (const w of whispers ?? []) dayNumbers.add(w.day);
  for (const key of Object.keys(archive.confrontations ?? {})) {
    dayNumbers.add(Number(key));
  }
  if (Object.keys(archive.openingAccusations ?? {}).length > 0) dayNumbers.add(1);

  const days: DayRecord[] = [];
  for (const d of [...dayNumbers].sort((a, b) => a - b)) {
    // Only the final round counts. A revote narrows the ballot, so counting an
    // earlier round would tally the ballot that tied on top of the one that
    // broke it (FR-020).
    let lastRound = 1;
    for (const v of votes ?? []) {
      if (v.day === d && v.round > lastRound) lastRound = v.round;
    }
    const dayVotes: Record<number, number | null> = {};
    for (const v of votes ?? []) {
      if (v.day !== d || v.round !== lastRound) continue;
      const seat = seatOf.get(v.voter_id);
      if (seat === undefined) continue;
      dayVotes[seat] = v.target_id === null
        ? null
        : seatOf.get(v.target_id) ?? null;
    }

    days.push({
      dayNumber: d,
      openingAccusations: d === 1
        ? Object.fromEntries(
          Object.entries(archive.openingAccusations ?? {}).map(
            ([seat, target]) => [Number(seat), target],
          ),
        )
        : {},
      confrontation: archive.confrontations?.[String(d)] ?? null,
      votes: dayVotes,
      speakingSeconds: Object.fromEntries(
        Object.entries(archive.speakingSeconds?.[String(d)] ?? {}).map(
          ([seat, seconds]) => [Number(seat), seconds],
        ),
      ),
      whispers: (whispers ?? [])
        .filter((w) => w.day === d)
        .map((w) => ({
          day: w.day,
          fromSeat: seatOf.get(w.from_id) ?? -1,
          toSeat: seatOf.get(w.to_id) ?? -1,
        }))
        .filter((w) => w.fromSeat >= 0 && w.toSeat >= 0),
    });
  }

  return { nights, days, alive };
}
