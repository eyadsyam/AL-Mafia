"""Removals timed against the resolvers, against the hosted functions.

  * a seat removed in the night, after it moved and before the resolution:
    the resolver counts the population it finds, the removed seat's move is
    void, the kill lands on the living target, the morning opens once
  * a seat removed during an open ballot, after it voted: its ballot is void
    (a ballot the removed seat cast would have tied the table), the verdict
    is the living seats', the removed seat cannot vote again
  * one user asking for two rooms at once: both answered, one seat held, the
    lobby the user did not stay in is gone
  * the result names every dealt seat, with the removals recorded in the
    phase they happened in

    SUPABASE_URL=... SUPABASE_ANON_KEY=... python supabase/tests/kick_timing_match.py
"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0] if "/" in __file__ else __file__.rsplit("\\", 1)[0])
from concurrency_match import SETTINGS, make_room, parallel, state_of  # noqa: E402
from e2e_match import KEY, URL, PASS, FAIL, aid, anon_session, check, drop_minted_users, fn, rest, ready_lobby  # noqa: E402
from roster_match import roster  # noqa: E402

ROLES_SIX = {"mafia": 1, "doctor": 1, "detective": 1, "citizen": 3}


def public_data(room_id, player):
    return state_of(room_id, player).get("public_data") or {}


def main():
    if not KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")
    print("server: " + URL)

    # Every session first: a lobby silent for ninety seconds is given up, and
    # a sign-in that waits out the hosted rate limit takes longer than that.
    twin = anon_session("Twin")
    players, room_id, code = make_room(["Ghada", "Hani", "Ibrahim", "Jumana", "Karim", "Laila"])
    host = players[0]

    # ── 1. one user, two rooms at once ───────────────────────────────────
    (s1, a), (s2, b) = parallel([
        lambda: fn("create_room", {"name": "Twin"}, twin),
        lambda: fn("create_room", {"name": "Twin"}, twin),
    ])
    check("two create requests at once are both answered", s1 == 200 and s2 == 200, (a, b))
    status, seats = rest("room_players_public?select=room_id&user_id=eq." + twin["id"], twin)
    check("the user holds exactly one seat", status == 200 and len(seats) == 1, seats)
    ids = {a.get("roomId"), b.get("roomId")} - {None}
    status, rooms = rest("rooms_public?select=id&id=in.(" + ",".join(ids) + ")", twin)
    kept = {r["id"] for r in rooms} if status == 200 else set()
    check("exactly one of the two rooms exists, the one the seat is in",
          len(ids) == 2 and len(kept) == 1 and seats and seats[0]["room_id"] in kept, (ids, kept, seats))
    fn("leave_room", {"roomId": seats[0]["room_id"]}, twin) if seats else None

    # ── the deal ─────────────────────────────────────────────────────────
    ready_lobby(room_id, players)
    status, started = fn("start_match", {"roomId": room_id, "roles": ROLES_SIX, "settings": SETTINGS}, host)
    check("six seats start", status == 200 and started.get("started") is True, started)
    for p in players:
        status, mine = fn("my_team", {"roomId": room_id}, p)
        p["role"] = mine.get("role")
        fn("saw_role", {"roomId": room_id}, p)
    by_role = {}
    for p in players:
        by_role.setdefault(p["role"], []).append(p)
    check("six roles dealt", sorted(len(v) for v in by_role.values()) == [1, 1, 1, 3], {k: len(v) for k, v in by_role.items()})
    mafia, doctor, detective = by_role["mafia"][0], by_role["doctor"][0], by_role["detective"][0]
    # The three seats that go before the verdict: the night's victim, the seat
    # removed in the night, the seat removed in the ballot. Town, never the
    # host (a host cannot remove itself), citizens first so the doctor and
    # the detective keep their moves as long as possible.
    town = [p for p in players if p["role"] != "mafia" and p is not host]
    town.sort(key=lambda p: 0 if p["role"] == "citizen" else 1)
    victim, k_night, k_vote = town[0], town[1], town[2]

    # ── 2. night one: a removal after the moves, before the resolution ──
    status, opened = fn("open_phase", {"roomId": room_id, "phase": "night"}, host)
    check("the night opens", status == 200, opened)
    fn("submit_night_action", {"roomId": room_id, "action": "kill", "targetSeat": victim["seat"], "actionId": aid()}, mafia)
    protect_target = next(p for p in players if p is not doctor and p is not victim and p["role"] != "mafia")
    fn("submit_night_action", {"roomId": room_id, "action": "protect", "targetSeat": protect_target["seat"], "actionId": aid()}, doctor)
    fn("submit_night_action", {"roomId": room_id, "action": "investigate", "targetSeat": mafia["seat"], "actionId": aid()}, detective)
    for p in players:
        if p["role"] == "citizen":
            status, move = fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": mafia["seat"], "actionId": aid()}, p)
            check("citizen seat %d moves" % p["seat"], status == 200, move)
    status, removal = fn("kick_player", {"roomId": room_id, "seat": k_night["seat"]}, host)
    check("the host removes a seat that already moved, before the resolution", status == 200, removal)
    status, beat = fn("heartbeat", {"roomId": room_id}, k_night)
    check("the removed seat is no longer a member", beat.get("error") == "NOT_A_MEMBER", beat)
    status, late = fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": doctor["seat"], "actionId": aid()}, k_night)
    check("...and cannot move again", late.get("error") in ("NOT_A_MEMBER", "NOT_ALIVE", "PHASE_CLOSED"), late)
    status, morning = fn("resolve_night", {"roomId": room_id}, host)
    check("the night resolves on the population it finds", status == 200, morning)
    check("the kill landed on the living target", morning.get("victimSeat") == victim["seat"], morning)
    status, again = fn("resolve_night", {"roomId": room_id}, host)
    check("a second resolver is refused, not counted twice", status != 200 or state_of(room_id, host).get("phase") == "morning", again)
    pd = public_data(room_id, host)
    elim = pd.get("eliminations") or {}
    check("the removal is a neutral night-1 record", elim.get(str(k_night["seat"])) == {"phase": "night", "number": 1}, elim)
    rows = roster(room_id, host)
    living = sorted(r["seat"] for r in rows if r["alive"])
    check("four living, the victim and the removed seat out", len(living) == 4 and victim["seat"] not in living and k_night["seat"] not in living, living)
    check("no outcome with one Mafia and three town", pd.get("outcome") is None, pd.get("outcome"))

    # ── day one ──────────────────────────────────────────────────────────
    status, opened = fn("open_phase", {"roomId": room_id, "phase": "opening"}, host)
    check("the opening round opens", status == 200, opened)
    for seat in living:
        p = next(x for x in players if x["seat"] == seat)
        t = next(x for x in living if x != seat)
        fn("submit_accusation", {"roomId": room_id, "targetSeat": t}, p)
    check("the round closes into the discussion", state_of(room_id, host).get("phase") == "discuss", state_of(room_id, host).get("phase"))

    # ── 3. the ballot: a removal after a ballot is cast ──────────────────
    status, opened = fn("open_phase", {"roomId": room_id, "phase": "vote"}, host)
    check("the ballot opens", status == 200, opened)
    decoy = next(p for p in players if p["seat"] in living and p is not k_vote and p is not mafia)
    status, ballot = fn("submit_vote", {"roomId": room_id, "targetSeat": decoy["seat"], "round": 1, "actionId": aid()}, k_vote)
    check("the seat about to be removed casts a ballot", status == 200, ballot)
    status, ballot = fn("submit_vote", {"roomId": room_id, "targetSeat": decoy["seat"], "round": 1, "actionId": aid()}, mafia)
    check("the Mafia votes with it", status == 200, ballot)
    for p in players:
        if p["seat"] in living and p is not k_vote and p is not mafia:
            status, ballot = fn("submit_vote", {"roomId": room_id, "targetSeat": mafia["seat"], "round": 1, "actionId": aid()}, p)
            check("seat %d votes the Mafia" % p["seat"], status == 200, ballot)
    status, removal = fn("kick_player", {"roomId": room_id, "seat": k_vote["seat"]}, host)
    check("the host removes the seat during the open ballot", status == 200, removal)
    status, twice = fn("submit_vote", {"roomId": room_id, "targetSeat": mafia["seat"], "round": 1, "actionId": aid()}, k_vote)
    check("the removed seat cannot vote again", twice.get("error") in ("NOT_A_MEMBER", "NOT_ALIVE", "PHASE_CLOSED"), twice)
    pd = public_data(room_id, host)
    check("three living, one Mafia: no outcome invented by the removal", pd.get("outcome") is None, pd.get("outcome"))
    status, verdict = fn("resolve_vote", {"roomId": room_id}, host)
    check("the ballot resolves", status == 200, verdict)
    tally = verdict.get("tally") or {}
    check("the removed seat's ballot is void: two on the Mafia, one on the decoy, no tie",
          verdict.get("eliminatedSeat") == mafia["seat"] and tally.get(str(mafia["seat"])) == 2
          and tally.get(str(decoy["seat"])) == 1 and not verdict.get("tie"), verdict)
    check("the town wins on the living seats' ballots", verdict.get("outcome") == "town", verdict)
    status, result = fn("open_phase", {"roomId": room_id, "phase": "result"}, host)
    check("the result opens", status == 200, result)
    pd = public_data(room_id, host)
    standings = pd.get("standings") or []
    check("standings name all six dealt seats", sorted(x["seat"] for x in standings) == sorted(p["seat"] for p in players), [x.get("seat") for x in standings])
    for p, phase, number in ((victim, "night", 1), (k_night, "night", 1), (k_vote, "day", 1), (mafia, "day", 1)):
        row = next((x for x in standings if x["seat"] == p["seat"]), None)
        check("seat %d stands with role %s, out on %s %d" % (p["seat"], p["role"], phase, number),
              row is not None and row.get("role") == p["role"] and row.get("eliminatedPhase") == phase and row.get("eliminatedNumber") == number, row)
    for p in (k_night, k_vote):
        status, back = fn("join_room", {"code": code, "name": p["label"]}, p)
        check("removed seat %d stays barred" % p["seat"], back.get("error") in ("NOT_A_MEMBER", "ROOM_FINISHED"), back)

    print("\n%d passed, %d failed" % (len(PASS), len(FAIL)))
    if FAIL:
        print("failed: " + ", ".join(FAIL))
    return 1 if FAIL else 0


if __name__ == "__main__":
    try:
        code = main()
    finally:
        drop_minted_users()
    sys.exit(code)
