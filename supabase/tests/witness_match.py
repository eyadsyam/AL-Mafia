#!/usr/bin/env python3
"""The open table for the dead, against a real server (owner decision
2026-09-23, doc 12 §4.1): `witness_view` answers an eliminated player with
every role and every night choice, and refuses every living one identically.

Usage: SUPABASE_URL=… SUPABASE_ANON_KEY=… python supabase/tests/witness_match.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import e2e_match as h  # noqa: E402

fn, check, aid = h.fn, h.check, h.aid


def main():
    if not h.KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")
    names = ["Wael", "Xena", "Yousef", "Zeina", "Adel"]
    players = [h.anon_session(n) for n in names]
    status, room = fn("create_room", {"name": names[0]}, players[0])
    check("create_room", status == 200, room)
    room_id, code = room["roomId"], room["code"]
    players[0]["seat"] = 0
    for i, p in enumerate(players[1:], start=1):
        status, joined = fn("join_room", {"code": code, "name": names[i]}, p)
        check("join seat %d" % i, status == 200, joined)
        p["seat"] = joined.get("seat")

    status, early = fn("witness_view", {"roomId": room_id}, players[1])
    check("refused in the lobby", status == 403, (status, early))

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
    fn("open_phase", {"roomId": room_id, "phase": "night"}, players[0])

    victim = citizens[0] if citizens[0] is not players[0] else citizens[1]
    fn("submit_night_action", {"roomId": room_id, "action": "kill", "targetSeat": victim["seat"], "actionId": aid()}, mafia)
    fn("submit_night_action", {"roomId": room_id, "action": "protect", "targetSeat": mafia["seat"], "actionId": aid()}, doctor)
    fn("submit_night_action", {"roomId": room_id, "action": "investigate", "targetSeat": mafia["seat"], "actionId": aid()}, detective)
    for c in citizens:
        fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": mafia["seat"], "actionId": aid()}, c)

    status, alive_view = fn("witness_view", {"roomId": room_id}, mafia)
    check("a living Mafia is refused mid-night", status == 403 and alive_view.get("error") == "WITNESS_ONLY", alive_view)
    status, alive_view2 = fn("witness_view", {"roomId": room_id}, citizens[-1] if citizens[-1] is not victim else citizens[0])
    check("a living Citizen gets the identical refusal", status == 403 and alive_view2.get("error") == "WITNESS_ONLY", alive_view2)

    status, morning = fn("resolve_night", {"roomId": room_id}, players[0])
    check("the victim died", status == 200 and morning.get("victimSeat") == victim["seat"], morning)

    status, view = fn("witness_view", {"roomId": room_id}, victim)
    check("the dead get the open table", status == 200, (status, view))
    got = {r["seat"]: r["role"] for r in view.get("roles", [])}
    check("every dealt seat and its true role", got == {p["seat"]: p["role"] for p in players}, got)
    acts = {(a["seat"], a["action"], a["targetSeat"]) for a in view.get("actions", []) if a["night"] == 1}
    check("the kill is shown", (mafia["seat"], "kill", victim["seat"]) in acts, acts)
    check("the save is shown", (doctor["seat"], "protect", mafia["seat"]) in acts, acts)
    check("the check is shown", (detective["seat"], "investigate", mafia["seat"]) in acts, acts)

    status, still = fn("witness_view", {"roomId": room_id}, mafia)
    check("the living are still refused after a death", status == 403, still)

    fn("close_room", {"roomId": room_id}, players[0])
    print("%d passed, %d failed" % (len(h.PASS), len(h.FAIL)))
    sys.exit(1 if h.FAIL else 0)


if __name__ == "__main__":
    main()
