#!/usr/bin/env python3
"""Four server-side players, so a real phone can be the fifth.

`e2e_match.py` plays all five seats itself, which proves the Edge Functions.
This proves the *app*: it joins a room the phone created, plays the four seats
the phone is not, and lets the phone host — so every phase transition, every
snapshot decode and every screen in doc 15 is exercised against the real
server by the real client.

Usage
-----
    SUPABASE_URL=… SUPABASE_ANON_KEY=… python supabase/tests/play_with_app.py ROOMCODE

The phone creates the room, reads its code off the lobby, and is seat 0 — so
it is the host, and the host is the one that drives the phases. This script
never calls `start_match`, `open_phase` or `advance_phase`: those are taps on
the phone, and the point is to watch the phone make them.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import e2e_match as h  # noqa: E402


def state(player, room_id):
    status, rows = h.rest(
        "room_state?select=phase,phase_number,active_speaker&room_id=eq." + room_id,
        player,
    )
    return rows[0] if status == 200 and rows else {}


def seats(player, room_id):
    status, rows = h.rest(
        "room_players_public?select=user_id,seat,name,alive&room_id=eq."
        + room_id
        + "&order=seat",
        player,
    )
    return rows if status == 200 else []


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: play_with_app.py ROOMCODE")
    code = sys.argv[1].strip().upper()
    if not h.KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")

    names = ["Bassem", "Camelia", "Dawoud", "Enas"]
    players = [h.anon_session(n) for n in names]
    print("four sessions ready")

    room_id = None
    for i, p in enumerate(players):
        status, joined = h.fn("join_room", {"code": code, "name": names[i]}, p)
        if status != 200:
            raise SystemExit("join failed for %s: %s %s" % (names[i], status, joined))
        p["seat"] = joined.get("seat")
        room_id = joined.get("roomId") or room_id
        print("  %-8s seat %s" % (names[i], p["seat"]))

    if room_id is None:
        raise SystemExit("no roomId came back from join_room")

    print("room %s — waiting for the phone to start the match" % room_id)

    seen = None
    acted = set()
    deadline = time.time() + 900
    while time.time() < deadline:
        row = state(players[0], room_id)
        phase, number = row.get("phase"), row.get("phase_number")
        key = (phase, number)
        if key != seen:
            seen = key
            print("  phase -> %s %s" % (phase, number))
            acted = set()

        alive = [s for s in seats(players[0], room_id) if s["alive"]]
        mine = {p["seat"]: p for p in players}

        if phase == "night":
            # Every seat submits; the server decides which submissions mean
            # anything, because only it knows the roles.
            for s in alive:
                p = mine.get(s["seat"])
                if p is None or s["seat"] in acted:
                    continue
                target = next(
                    (o for o in alive if o["seat"] != s["seat"]), None
                )
                if target is None:
                    continue
                status, out = h.fn(
                    "submit_night_action",
                    {
                        "roomId": room_id,
                        "targetSeat": target["seat"],
                        "actionId": h.aid(),
                    },
                    p,
                )
                acted.add(s["seat"])
                print("    seat %s night -> %s (%s)" % (s["seat"], target["seat"], status))

        elif phase == "opening":
            for s in alive:
                p = mine.get(s["seat"])
                if p is None or s["seat"] in acted:
                    continue
                target = next((o for o in alive if o["seat"] != s["seat"]), None)
                if target is None:
                    continue
                status, _ = h.fn(
                    "submit_accusation",
                    {"roomId": room_id, "targetSeat": target["seat"], "actionId": h.aid()},
                    p,
                )
                acted.add(s["seat"])
                print("    seat %s accuses %s (%s)" % (s["seat"], target["seat"], status))

        elif phase == "discuss":
            # Doc 15 §1.4 resolved: a claim that is refused leaves a raised
            # hand behind, and this is what puts three of them on the phone's
            # screen at once.
            for s in alive:
                p = mine.get(s["seat"])
                if p is None or s["seat"] in acted:
                    continue
                status, out = h.fn("claim_floor", {"roomId": room_id}, p)
                acted.add(s["seat"])
                print("    seat %s claims the floor -> %s" % (s["seat"], out))

        elif phase == "vote":
            for s in alive:
                p = mine.get(s["seat"])
                if p is None or s["seat"] in acted:
                    continue
                target = next((o for o in alive if o["seat"] != s["seat"]), None)
                if target is None:
                    continue
                status, _ = h.fn(
                    "submit_vote",
                    {"roomId": room_id, "targetSeat": target["seat"], "actionId": h.aid()},
                    p,
                )
                acted.add(s["seat"])
                print("    seat %s votes %s (%s)" % (s["seat"], target["seat"], status))

        elif phase in ("result", "finished"):
            print("match over: %s" % phase)
            return 0

        time.sleep(2)

    print("timed out waiting on the phone")
    return 1


if __name__ == "__main__":
    try:
        code = main()
    finally:
        h.drop_minted_users()
    sys.exit(code)
