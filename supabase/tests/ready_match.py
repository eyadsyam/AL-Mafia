#!/usr/bin/env python3
"""«جاهزين للتصويت» against a real server (owner, 2026-09-24).

Every living player says they are ready and the ballot opens on the last one —
not before, not twice. Readiness can be taken back, two taps in the same
instant are both counted (the row lock in `mark_ready_to_vote`), and the dead
have no say.

Usage: SUPABASE_URL=… SUPABASE_ANON_KEY=… python supabase/tests/ready_match.py
"""
import os
import sys
import threading

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import e2e_match as h  # noqa: E402

fn, rest, check, aid = h.fn, h.rest, h.check, h.aid


def phase_of(room_id, viewer):
    status, rows = rest("room_state?select=phase,public_data&room_id=eq." + room_id, viewer)
    return (rows[0] if status == 200 and rows else {})


def main():
    if not h.KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")
    names = ["Rami", "Salma", "Taha", "Uday", "Wafa"]
    players = [h.anon_session(n) for n in names]
    status, room = fn("create_room", {"name": names[0]}, players[0])
    check("create_room", status == 200, room)
    room_id, code = room["roomId"], room["code"]
    players[0]["seat"] = 0
    for i, p in enumerate(players[1:], start=1):
        status, joined = fn("join_room", {"code": code, "name": names[i]}, p)
        check("join seat %d" % i, status == 200, joined)
        p["seat"] = joined.get("seat")

    settings = {"openingRoundEnabled": False, "traceEnabled": False,
                "confrontationEnabled": False, "whisperEnabled": False}
    roles = {"mafia": 1, "doctor": 1, "detective": 1, "citizen": 2}
    h.ready_lobby(room_id, players)
    status, started = fn("start_match", {"roomId": room_id, "roles": roles, "settings": settings}, players[0])
    check("start_match", status == 200, started)
    for p in players:
        p["role"] = fn("my_team", {"roomId": room_id}, p)[1].get("role")
        fn("saw_role", {"roomId": room_id}, p)
    by = {}
    for p in players:
        by.setdefault(p["role"], []).append(p)
    mafia, doctor, detective, citizens = by["mafia"][0], by["doctor"][0], by["detective"][0], by["citizen"]

    status, early = fn("ready_to_vote", {"roomId": room_id}, players[0])
    check("refused outside a discussion", status != 200, (status, early))

    fn("open_phase", {"roomId": room_id, "phase": "night"}, players[0])
    victim = citizens[0]
    fn("submit_night_action", {"roomId": room_id, "action": "kill", "targetSeat": victim["seat"], "actionId": aid()}, mafia)
    fn("submit_night_action", {"roomId": room_id, "action": "protect", "targetSeat": mafia["seat"], "actionId": aid()}, doctor)
    fn("submit_night_action", {"roomId": room_id, "action": "investigate", "targetSeat": mafia["seat"], "actionId": aid()}, detective)
    for c in citizens:
        fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": mafia["seat"], "actionId": aid()}, c)
    status, morning = fn("resolve_night", {"roomId": room_id}, players[0])
    check("a citizen died", status == 200 and morning.get("victimSeat") == victim["seat"], morning)
    status, opened = fn("open_phase", {"roomId": room_id, "phase": "discuss"}, players[0])
    if status != 200:
        status, opened = fn("open_phase", {"roomId": room_id, "phase": "opening"}, players[0])
        fn("open_phase", {"roomId": room_id, "phase": "discuss"}, players[0])
    check("the discussion is open", phase_of(room_id, players[0]).get("phase") == "discuss", opened)

    living = [p for p in players if p is not victim]

    status, dead = fn("ready_to_vote", {"roomId": room_id}, victim)
    check("the dead have no say", status == 403 and dead.get("error") == "NOT_ALIVE", dead)

    # Two at the same instant: both must count.
    results = {}

    def tap(p):
        results[p["seat"]] = fn("ready_to_vote", {"roomId": room_id, "ready": True}, p)

    pair = living[:2]
    threads = [threading.Thread(target=tap, args=(p,)) for p in pair]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    check("both simultaneous taps answered", all(r[0] == 200 for r in results.values()), results)
    ready = (phase_of(room_id, players[0]).get("public_data") or {}).get("readyToVote") or {}
    check("both simultaneous taps counted", sorted(ready.get("seats") or []) == sorted(p["seat"] for p in pair), ready)

    # A change of mind.
    status, back = fn("ready_to_vote", {"roomId": room_id, "ready": False}, pair[0])
    check("taking it back is honoured", status == 200 and pair[0]["seat"] not in back.get("readySeats", []), back)
    fn("ready_to_vote", {"roomId": room_id, "ready": True}, pair[0])

    for p in living[2:-1]:
        status, out = fn("ready_to_vote", {"roomId": room_id}, p)
        check("seat %d ready, ballot still closed" % p["seat"], status == 200 and out.get("ballotOpened") is False, out)
    check("still discussing before the last living player",
          phase_of(room_id, players[0]).get("phase") == "discuss")

    status, last = fn("ready_to_vote", {"roomId": room_id}, living[-1])
    check("the last living player opens the ballot", status == 200 and last.get("ballotOpened") is True, last)
    check("the room is balloting", phase_of(room_id, players[0]).get("phase") == "vote")

    status, late = fn("ready_to_vote", {"roomId": room_id}, living[0])
    check("a late tap is refused, never a second opening", late.get("error") == "PHASE_CLOSED", late)

    fn("close_room", {"roomId": room_id}, players[0])
    print("%d passed, %d failed" % (len(h.PASS), len(h.FAIL)))
    sys.exit(1 if h.FAIL else 0)


if __name__ == "__main__":
    main()
