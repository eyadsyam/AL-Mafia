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


def _seconds_left(token):
    """Seconds until a JWT expires, or 0 when it cannot be read."""
    import base64
    import json
    try:
        body = token.split(".")[1]
        body += "=" * (-len(body) % 4)
        exp = json.loads(base64.urlsafe_b64decode(body))["exp"]
        return exp - time.time()
    except (IndexError, KeyError, ValueError):
        return 0


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: play_with_app.py ROOMCODE")
    code = sys.argv[1].strip().upper()
    if not h.KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")

    names = ["Bassem", "Camelia", "Dawoud", "Enas"]
    # Reuse the last run's sessions when they are still valid: the hosted
    # anonymous sign-up limit is small, and a restart should not spend it.
    import json
    cache = os.environ.get("PLAY_SESSIONS", "build/play_with_app.sessions.json")
    players = []
    try:
        with open(cache, encoding="utf-8") as f:
            cached = json.load(f)
        for c in cached:
            # A token that is valid now can still expire half-way through a
            # match — every call then fails, heartbeats included, and the server
            # rightly marks all four seats as gone. Reuse only a session with
            # well over a match's length left on it.
            if _seconds_left(c["token"]) < 40 * 60:
                continue
            status, _ = h._request("/auth/v1/user", None, c["token"], method="GET")
            if status == 200:
                players.append(c)
    except (OSError, ValueError):
        pass
    for n in names[len(players):]:
        players.append(h.anon_session(n))
    for p, n in zip(players, names):
        p["label"] = n
    with open(cache, "w", encoding="utf-8") as f:
        json.dump([{"label": p["label"], "token": p["token"], "id": p["id"]} for p in players], f)
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

    # The phone owns its own ready tap. The four bot seats announce readiness
    # immediately so the host can start as soon as the phone is ready too.
    h.ready_lobby(room_id, players)

    print("room %s — waiting for the phone to start the match" % room_id)

    seen = None
    acted = set()
    roles = {}
    night_action = {"mafia": "kill", "doctor": "protect",
                    "detective": "investigate", "citizen": "suspect"}
    deadline = time.time() + 900
    last_beat = 0.0
    while time.time() < deadline:
        # The app reports presence every ten seconds; seats that stay silent
        # read as away, and the host cannot start or move the room past them.
        if time.time() - last_beat > 8:
            for p in players:
                h.fn("heartbeat", {"roomId": room_id}, p)
            last_beat = time.time()
        row = state(players[0], room_id)
        phase, number = row.get("phase"), row.get("phase_number")
        key = (phase, number)
        if key != seen:
            seen = key
            print("  phase -> %s %s" % (phase, number))
            acted = set()

        alive = [s for s in seats(players[0], room_id) if s["alive"]]
        mine = {p["seat"]: p for p in players}

        if phase == "reveal":
            for p in players:
                if p["seat"] in acted:
                    continue
                _, team = h.fn("my_team", {"roomId": room_id}, p)
                roles[p["seat"]] = team.get("role")
                status, _ = h.fn("saw_role", {"roomId": room_id}, p)
                acted.add(p["seat"])
                print("    seat %s is %s, card dismissed (%s)" % (p["seat"], roles[p["seat"]], status))

        if phase not in (None, "lobby", "reveal") and len(roles) < len(players):
            for p in players:
                _, team = h.fn("my_team", {"roomId": room_id}, p)
                roles[p["seat"]] = team.get("role")

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
                # PLAY_KILL_PHONE=1: the Doctor protects somebody other than
                # the phone, so the Mafia's kill on seat 0 lands and the phone
                # sees what a night victim sees.
                if os.environ.get("PLAY_KILL_PHONE") and roles.get(s["seat"]) == "doctor":
                    target = next((o for o in alive if o["seat"] not in (0, s["seat"])), target)
                if target is None:
                    continue
                status, out = h.fn(
                    "submit_night_action",
                    {
                        "roomId": room_id,
                        "action": night_action.get(roles.get(s["seat"]), "skip"),
                        "targetSeat": target["seat"],
                        "actionId": h.aid(),
                    },
                    p,
                )
                acted.add(s["seat"])
                print("    seat %s night %s -> %s (%s %s)" % (
                    s["seat"], roles.get(s["seat"]), target["seat"], status,
                    out if status != 200 else ""))

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
                # The opening round is taken in seat order; a refusal before
                # this seat's turn is expected, so it asks again next poll.
                if status == 200:
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
                # «جاهزين للتصويت»: the bots are ready at once, so the ballot
                # opens the moment the phone says it is ready too.
                status, out = h.fn("ready_to_vote", {"roomId": room_id}, p)
                print("    seat %s is ready to vote -> %s %s" % (s["seat"], status, out))

        elif phase == "vote":
            full = h.rest("room_state?select=public_data&room_id=eq." + room_id, players[0])[1]
            revote = ((full[0].get("public_data") or {}).get("revote") or {}) if full else {}
            ballot = revote.get("round", 1)
            tied = revote.get("tiedSeats")
            key_round = ("vote", ballot)
            if key_round != getattr(main, "_round", None):
                main._round = key_round
                acted = set()
            for s in alive:
                p = mine.get(s["seat"])
                if p is None or s["seat"] in acted:
                    continue
                target = next((o for o in alive if o["seat"] != s["seat"]
                               and (not tied or o["seat"] in tied)), None)
                if target is None:
                    continue
                status, _ = h.fn(
                    "submit_vote",
                    {"roomId": room_id, "targetSeat": target["seat"], "round": ballot,
                     "actionId": h.aid()},
                    p,
                )
                acted.add(s["seat"])
                print("    seat %s votes %s in round %s (%s)" % (s["seat"], target["seat"], ballot, status))

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
