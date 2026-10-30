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
  // Every read is checked. A history assembled from a query that failed is
  // an empty history, and an empty history is not "nothing happened" — it is
  // a generator handed a false record and a trace or confrontation chosen
  // from it. The caller gets the error and the room keeps its phase.
  const { data: players, error: playersError } = await db
    .from("room_players")
    .select("user_id, seat, alive")
    .eq("room_id", roomId)
    .order("seat");
  if (playersError) throw playersError;
  const roster = players ?? [];
  const seatOf = new Map<string, number>(
    roster.map((p) => [p.user_id, p.seat]),
  );
  const alive = roster.filter((p) => p.alive).map((p) => p.seat);

  const { data: actions, error: actionsError } = await db
    .from("night_actions")
    .select("night, actor_id, action, target_id")
    .eq("room_id", roomId)
    .order("night");
  if (actionsError) throw actionsError;

  const { data: votes, error: votesError } = await db
    .from("votes")
    .select("day, voter_id, target_id, round")
    .eq("room_id", roomId)
    .order("day");
  if (votesError) throw votesError;

  const { data: whispers, error: whispersError } = await db
    .from("whisper_meta")
    .select("day, from_id, to_id")
    .eq("room_id", roomId)
    .order("day");
  if (whispersError) throw whispersError;

  const { data: state, error: stateError } = await db
    .from("room_state")
    .select("public_data")
    .eq("room_id", roomId)
    .maybeSingle();
  if (stateError) throw stateError;

  const { data: privateNights, error: privateError } = await db
    .from("night_resolution_private")
    .select("night, saved_seat")
    .eq("room_id", roomId);
  if (privateError) throw privateError;
  const savedByNight = new Map<number, number | null>(
    (privateNights ?? []).map((row) => [row.night, row.saved_seat]),
  );

  // The published history the server keeps alongside the tables: which trace
  // went out on which morning, which confrontation was issued on which day,
  // and the floor time the discussion screen reported. All of it is public and
  // all of it is already in `public_data`, which is the payload the room reads.
  const archive = (state?.public_data ?? {}) as {
    resolvedNights?: Record<string, {
      victimSeat: number | null;
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
    /** Day -> who was voted out and whether the card shown was the Mafia's. */
    dayResults?: Record<string, { seat: number; mafia: boolean }>;
  };

  // ── nights ──────────────────────────────────────────────────────────────
  const nightNumbers = new Set<number>();
  for (const a of actions ?? []) nightNumbers.add(a.night);
  for (const key of Object.keys(archive.resolvedNights ?? {})) {
    nightNumbers.add(Number(key));
  }

  const nights: NightRecord[] = [];
  for (const n of [...nightNumbers].sort((a, b) => a - b)) {
    // Online a Citizen has no night move (owner, 2026-10-01), so there is no
    // suspicion record to read. A Mafia or Detective skip is not one either:
    // counting those would be counting roles. Every generator that reads
    // suspicions therefore finds none online and stays silent.
    const suspicions: Record<number, number | null> = {};
    const resolved = archive.resolvedNights?.[String(n)];
    nights.push({
      nightNumber: n,
      suspicions,
      victim: resolved?.victimSeat ?? null,
      saveOccurred: savedByNight.get(n) != null,
      savedSeat: savedByNight.get(n) ?? null,
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
  for (const key of Object.keys(archive.dayResults ?? {})) {
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
      // Public: a day elimination always shows the card (FR-019).
      eliminated: archive.dayResults?.[String(d)]?.seat ?? null,
      eliminatedWasMafia: archive.dayResults?.[String(d)]?.mafia ?? null,
    });
  }

  return { nights, days, alive };
}
