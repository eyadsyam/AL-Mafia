"""Concurrent drivers against the hosted functions.

`e2e_match.py` plays a match sequentially and proves each refusal in turn. This
one fires the same requests *at the same time* — five clients opening one
phase, one seat double-tapping a name, three copies of the resolver, a ballot
landing while the tally runs — and proves the invariants that only hold if the
compare-and-set and the phase guards are real:

  * exactly one of N simultaneous drivers moves a phase; the rest are told
    PHASE_CLOSED and the clock is set once
  * a seat's simultaneous double tap records one name and hands the floor on
    exactly one step
  * a move acknowledged with 200 exists in the table for the phase it was made
    in, and a move refused with PHASE_CLOSED does not — never a lost move
  * the host leaving mid-match hands the room to the lowest connected seat and
    the match keeps going under the new host
  * the last player leaving a lobby leaves no room behind
  * a user racing two joins ends up seated in exactly one room

    SUPABASE_URL=... SUPABASE_ANON_KEY=... python supabase/tests/concurrency_match.py
"""
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, __file__.rsplit("/", 1)[0] if "/" in __file__ else __file__.rsplit("\\", 1)[0])
from e2e_match import (  # noqa: E402
    KEY, URL, PASS, FAIL, aid, anon_session, check, drop_minted_users, fn, rest,
    ready_lobby,
)

SETTINGS = {
    "speechSeconds": 60, "confrontationSeconds": 30, "abstainAllowed": True,
    "whisperEnabled": True, "traceEnabled": True, "confrontationEnabled": True,
    "openingRoundEnabled": True, "survivorConfrontationEnabled": True,
    "dayTieRule": "noElimination",
}
ROLES = {"mafia": 1, "doctor": 1, "detective": 1, "citizen": 2}


def parallel(calls):
    """Runs `calls` — a list of zero-argument callables — at once."""
    with ThreadPoolExecutor(max_workers=max(2, len(calls))) as pool:
        return list(pool.map(lambda c: c(), calls))


def state_of(room_id, player):
    status, rows = rest("room_state?select=phase,phase_number,phase_ends_at,public_data&room_id=eq." + room_id, player)
    return rows[0] if status == 200 and rows else {}


def make_room(names):
    players = [anon_session(n) for n in names]
    status, room = fn("create_room", {"name": names[0]}, players[0])
    check("create_room", status == 200 and "roomId" in room, room)
    room_id, code = room["roomId"], room["code"]
    players[0]["seat"] = 0
    for i, p in enumerate(players[1:], start=1):
        status, joined = fn("join_room", {"code": code, "name": names[i]}, p)
        check("join seat %d" % i, status == 200, joined)
        p["seat"] = joined.get("seat")
    return players, room_id, code


def deal(players, room_id):
    ready_lobby(room_id, players)
    status, started = fn("start_match", {"roomId": room_id, "roles": ROLES, "settings": SETTINGS}, players[0])
    check("start_match", status == 200 and started.get("started") is True, started)
    for p in players:
        status, mine = fn("my_team", {"roomId": room_id}, p)
        p["role"] = mine.get("role")
    for p in players:
        fn("saw_role", {"roomId": room_id}, p)


def one_winner(label, results, winner_status=200):
    """Exactly one 200; every other driver refused cleanly.

    A loser that read the room *before* the move sees the compare-and-set fail
    and is told PHASE_CLOSED. A loser that read it *after* the move sees a room
    that is no longer where it was asked to move from — a guest then fails the
    host check (NOT_HOST) and the host fails the transition table
    (PHASE_CLOSED). Both are refusals with a code the client resyncs on; neither
    is a second move or a 500.
    """
    wins = [r for r in results if r[0] == winner_status]
    refused = [r for r in results if r[1].get("error") in ("PHASE_CLOSED", "NOT_HOST")]
    check(label + ": exactly one driver moved the room", len(wins) == 1, results)
    check(label + ": every other driver was refused with a resync code", len(refused) == len(results) - 1, results)
    return wins[0][1] if wins else {}


def main():
    if not KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")
    print("server: " + URL)

    # ── 1. five drivers open the night at once ───────────────────────────
    players, room_id, code = make_room(["Amina", "Bassem", "Camelia", "Dawoud", "Enas"])
    deal(players, room_id)
    results = parallel([lambda p=p: fn("open_phase", {"roomId": room_id, "phase": "night"}, p) for p in players])
    opened = one_winner("reveal -> night x5", results)
    s = state_of(room_id, players[0])
    check("the night is open once, with the winner's clock",
          s.get("phase") == "night" and s.get("phase_number") == 1 and
          s.get("phase_ends_at", "").replace("+00:00", "Z")[:19] == (opened.get("phaseEndsAt") or "")[:19], (s, opened))

    by_role = {}
    for p in players:
        by_role.setdefault(p["role"], []).append(p)
    mafia, doctor, detective = by_role["mafia"][0], by_role["doctor"][0], by_role["detective"][0]
    citizens = by_role["citizen"]

    # ── 2. the night: a double-tapped move and the tally racing a late move ─
    # The Mafia taps two different targets at the same instant. Last write per
    # (night, actor) wins, so exactly one row exists and it names one of them.
    targets = [c["seat"] for c in citizens]
    results = parallel([
        lambda t=t: fn("submit_night_action", {"roomId": room_id, "action": "kill", "targetSeat": t, "actionId": aid()}, mafia)
        for t in targets
    ])
    check("double-tapped kill: both requests acknowledged", all(r[0] == 200 for r in results), results)
    status, mine = rest("night_actions?select=night,action,target_id&room_id=eq." + room_id, mafia)
    check("double-tapped kill: one row for the actor", status == 200 and len(mine) == 1 and mine[0]["action"] == "kill", mine)

    fn("submit_night_action", {"roomId": room_id, "action": "protect", "targetSeat": citizens[0]["seat"], "actionId": aid()}, doctor)
    fn("submit_night_action", {"roomId": room_id, "action": "investigate", "targetSeat": mafia["seat"], "actionId": aid()}, detective)
    fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": mafia["seat"], "actionId": aid()}, citizens[0])

    # Three copies of the resolver and one late citizen move, all at once.
    # Whatever interleaving the server saw, the invariants hold: one morning,
    # and the late move is either in the table for night 1 (it was counted —
    # the guard only admits it while the night is open, and the fingerprint
    # makes the resolver re-tally it) or refused with PHASE_CLOSED. Never a
    # 200 for a move that is not there.
    late = citizens[1]
    results = parallel([
        lambda: fn("resolve_night", {"roomId": room_id}, players[0]),
        lambda: fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": doctor["seat"], "actionId": aid()}, late),
        lambda: fn("resolve_night", {"roomId": room_id}, players[0]),
        lambda: fn("resolve_night", {"roomId": room_id}, players[0]),
    ])
    resolves = [results[0], results[2], results[3]]
    move = results[1]
    one_winner("resolve_night x3", resolves)
    status, rows = rest("night_actions?select=night,action&room_id=eq." + room_id, late)
    present = status == 200 and any(r["night"] == 1 for r in rows)
    check("late move: acknowledged iff it is in the table for night 1",
          (move[0] == 200) == present, (move, rows))
    check("late move: refused only as PHASE_CLOSED", move[0] == 200 or move[1].get("error") == "PHASE_CLOSED", move)
    s = state_of(room_id, players[0])
    check("one morning", s.get("phase") == "morning", s)
    # A move after the night closed is refused and leaves nothing behind.
    status, after = fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": mafia["seat"], "actionId": aid()}, citizens[0] if late is not citizens[0] else citizens[1])
    check("a move after the morning is PHASE_CLOSED", after.get("error") == "PHASE_CLOSED", after)

    # ── 3. the opening round: one seat double-taps ──────────────────────
    results = parallel([lambda p=p: fn("open_phase", {"roomId": room_id, "phase": "opening"}, p) for p in players[:3]])
    one_winner("morning -> opening x3", results)
    status, roster = rest("room_players_public?select=seat,alive&room_id=eq." + room_id, players[0])
    living = sorted(r["seat"] for r in roster if r["alive"])
    first = living[0]
    speaker = next(p for p in players if p["seat"] == first)
    others = [x for x in living if x != first]
    results = parallel([
        lambda t=t: fn("submit_accusation", {"roomId": room_id, "targetSeat": t}, speaker)
        for t in others[:2]
    ])
    wins = [r for r in results if r[0] == 200]
    check("double-tapped name: exactly one recorded", len(wins) == 1, results)
    check("double-tapped name: the other is PHASE_CLOSED", any(r[1].get("error") == "PHASE_CLOSED" for r in results), results)
    s = state_of(room_id, players[0])
    pd = s.get("public_data") or {}
    check("the floor moved exactly one seat", pd.get("openingSeat") == living[1], pd.get("openingSeat"))
    check("one name on record for the seat", str(first) in (pd.get("openingAccusations") or {}) and
          len(pd.get("openingAccusations") or {}) == 1, pd.get("openingAccusations"))

    # ── 4. the host leaves mid-match; the match goes on under the new host ─
    # Finish the round quickly, reach the ballot, then drop the host.
    for seat in living[1:]:
        p = next(x for x in players if x["seat"] == seat)
        t = next(x for x in living if x != seat)
        fn("submit_accusation", {"roomId": room_id, "targetSeat": t}, p)
    s = state_of(room_id, players[0])
    check("the round closed into the discussion", s.get("phase") == "discuss", s)
    results = parallel([lambda p=p: fn("open_phase", {"roomId": room_id, "phase": "vote"}, p) for p in players[:3]])
    one_winner("discuss -> vote x3", results)

    # Everybody votes at once — the ballot is a simultaneous write by design.
    # The Mafia (if still standing) abstains; everybody else names the Mafia.
    target = mafia["seat"]
    voters = [p for p in players if p["seat"] in living and p is not mafia]
    calls = [
        lambda p=p: fn("submit_vote", {"roomId": room_id, "targetSeat": target, "round": 1, "actionId": aid()}, p)
        for p in voters
    ]
    if mafia["seat"] in living:
        calls.append(lambda: fn("submit_vote", {"roomId": room_id, "targetSeat": None, "round": 1, "actionId": aid()}, mafia))
    results = parallel(calls)
    check("simultaneous ballots all acknowledged", all(r[0] == 200 for r in results), results)

    # The handover is presence-aware (a seat heard from in the last thirty
    # seconds), so the other seats report in the way the app's heartbeat does.
    parallel([lambda p=p: fn("heartbeat", {"roomId": room_id}, p) for p in players[1:]])
    status, gone = fn("leave_room", {"roomId": room_id}, players[0])
    check("the host leaves the running match", status == 200, gone)
    status, room = rest("rooms_public?select=host_id,status&id=eq." + room_id, players[1])
    heir = min(players[1:], key=lambda p: p["seat"])
    check("the room passed to the lowest connected seat", status == 200 and room and room[0]["host_id"] == heir["id"], (room, heir["seat"]))
    check("the room is still playing", room and room[0]["status"] == "playing", room)

    # Three copies of the new host's resolver, plus a late duplicate ballot with
    # the SAME action id (a retry) — the retry is either the same row or refused.
    retry_voter = voters[0]
    results = parallel([
        lambda: fn("resolve_vote", {"roomId": room_id}, heir),
        lambda: fn("submit_vote", {"roomId": room_id, "targetSeat": target, "round": 1, "actionId": aid()}, retry_voter),
        lambda: fn("resolve_vote", {"roomId": room_id}, heir),
        lambda: fn("resolve_vote", {"roomId": room_id}, heir),
    ])
    resolves = [results[0], results[2], results[3]]
    verdict = one_winner("resolve_vote x3 under the new host", resolves)
    retry = results[1]
    check("a retried ballot is acknowledged or PHASE_CLOSED, never lost",
          retry[0] == 200 or retry[1].get("error") == "PHASE_CLOSED", retry)
    check("the ballot eliminated the Mafia", verdict.get("eliminatedSeat") == mafia["seat"], verdict)
    s = state_of(room_id, players[1])
    check("verdict published once", s.get("phase") == "verdict", s)
    status, again = fn("submit_vote", {"roomId": room_id, "targetSeat": target, "round": 1, "actionId": aid()}, retry_voter)
    check("a ballot after the verdict is PHASE_CLOSED", again.get("error") == "PHASE_CLOSED", again)

    # The departed host cannot drive from outside; the heir closes the match.
    status, refused = fn("open_phase", {"roomId": room_id, "phase": "result"}, players[0])
    check("the departed host still holds a seat but not the room", refused.get("error") in ("NOT_HOST", "PHASE_CLOSED"), refused)
    results = parallel([lambda p=p: fn("open_phase", {"roomId": room_id, "phase": "result"}, p) for p in [heir, heir]])
    one_winner("verdict -> result x2", results)
    s = state_of(room_id, players[1])
    check("the match ended on the result", s.get("phase") == "result", s)
    standings = (s.get("public_data") or {}).get("standings") or []
    check("standings are published with the result only", len(standings) == 5 and all("role" in x for x in standings), standings)

    # ── 5. a user racing two joins sits in exactly one room ─────────────
    # Every session first, then the rooms: a lobby whose host has been silent
    # for ninety seconds is given up (`lobby_departures`), and a sign-in that
    # waits out the hosted rate limit takes longer than that.
    hosts = [anon_session("HostA"), anon_session("HostB")]
    wanderer = anon_session("Wanderer")
    status, a = fn("create_room", {"name": "HostA"}, hosts[0])
    status, b = fn("create_room", {"name": "HostB"}, hosts[1])
    results = parallel([
        lambda: fn("join_room", {"code": a["code"], "name": "Wanderer"}, wanderer),
        lambda: fn("join_room", {"code": b["code"], "name": "Wanderer"}, wanderer),
    ])
    check("both joins answered", all(r[0] == 200 for r in results), results)
    status, seats = rest("room_players_public?select=room_id&user_id=eq." + wanderer["id"], wanderer)
    check("the wanderer holds exactly one seat", status == 200 and len(seats) == 1, seats)
    # and joining the other room afterwards moves the seat, it does not copy it
    other = b if seats and seats[0]["room_id"] == a["roomId"] else a
    status, moved = fn("join_room", {"code": other["code"], "name": "Wanderer"}, wanderer)
    status, seats = rest("room_players_public?select=room_id&user_id=eq." + wanderer["id"], wanderer)
    check("joining elsewhere moves the seat", status == 200 and len(seats) == 1 and seats[0]["room_id"] == other["roomId"], seats)

    # ── 6. the last player leaving a lobby leaves no room ───────────────
    fn("leave_room", {"roomId": other["roomId"]}, wanderer)
    status, gone = fn("leave_room", {"roomId": a["roomId"]}, hosts[0])
    status, rooms = rest("rooms_public?select=id&id=eq." + a["roomId"], hosts[0])
    check("an emptied lobby is gone", status == 200 and rooms == [], rooms)
    status, joined = fn("join_room", {"code": a["code"], "name": "Late"}, hosts[0])
    check("its code no longer opens anything", joined.get("error") == "ROOM_NOT_FOUND", joined)
    fn("leave_room", {"roomId": b["roomId"]}, hosts[1])

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
