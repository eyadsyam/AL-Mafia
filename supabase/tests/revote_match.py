#!/usr/bin/env python3
"""A tied ballot and the revote it opens, played against a real server.

`revote_candidates.sql` proves the table refuses a revote ballot for a seat
that did not tie. This proves the whole path a phone takes: five sessions, a
night where nobody dies, a 2–2 split with one abstention, and a revote in which
only the two tied seats can be chosen — by the Edge Function and, underneath
it, by the database when a client skips the function entirely.

It also reads the server-owned waiting-room listing, then races two bot joins
against a bot-owned lobby. A shared waiting room may contain real users and is
not safe for this live test to mutate.

Usage
-----
    SUPABASE_URL=https://xxxx.supabase.co SUPABASE_ANON_KEY=sb_publishable_… \
        python supabase/tests/revote_match.py

Exit code 0 means every assertion held.
"""

import os
import sys
import threading

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import e2e_match as h  # noqa: E402

fn, rest, check, aid = h.fn, h.rest, h.check, h.aid


def room_state(room_id, viewer):
    status, rows = rest(
        "room_state?select=phase,phase_number,public_data&room_id=eq." + room_id, viewer)
    return rows[0] if status == 200 and rows else {}


def revote_section():
    names = ["Rana", "Sherif", "Tamer", "Yara", "Ziad"]
    players = [h.anon_session(n) for n in names]

    status, room = fn("create_room", {"name": names[0]}, players[0])
    check("create_room", status == 200 and "roomId" in room, room)
    room_id, code = room["roomId"], room["code"]
    players[0]["seat"] = 0
    for i, p in enumerate(players[1:], start=1):
        status, joined = fn("join_room", {"code": code, "name": names[i]}, p)
        check("join seat %d" % i, status == 200, joined)
        p["seat"] = joined.get("seat")

    settings = {
        "abstainAllowed": True, "dayTieRule": "revote",
        "openingRoundEnabled": True, "traceEnabled": False,
        "confrontationEnabled": False, "whisperEnabled": False,
    }
    roles = {"mafia": 1, "doctor": 1, "detective": 1, "citizen": 2}
    h.ready_lobby(room_id, players)
    status, started = fn("start_match", {"roomId": room_id, "roles": roles, "settings": settings}, players[0])
    check("start_match with the revote rule", status == 200 and started.get("started") is True, started)

    for p in players:
        _, mine = fn("my_team", {"roomId": room_id}, p)
        p["role"] = mine.get("role")
    by_role = {}
    for p in players:
        by_role.setdefault(p["role"], []).append(p)
    mafia, doctor, detective = by_role["mafia"][0], by_role["doctor"][0], by_role["detective"][0]
    citizens = by_role["citizen"]

    for p in players:
        fn("saw_role", {"roomId": room_id}, p)
    status, opened = fn("open_phase", {"roomId": room_id, "phase": "night"}, players[0])
    check("open night", status == 200, opened)

    # Nobody dies: the Doctor protects the Mafia's target, so all five vote.
    target = citizens[0]
    fn("submit_night_action", {"roomId": room_id, "action": "kill",
                               "targetSeat": target["seat"], "actionId": aid()}, mafia)
    fn("submit_night_action", {"roomId": room_id, "action": "protect",
                               "targetSeat": target["seat"], "actionId": aid()}, doctor)
    fn("submit_night_action", {"roomId": room_id, "action": "investigate",
                               "targetSeat": mafia["seat"], "actionId": aid()}, detective)
    for c in citizens:
        fn("submit_night_action", {"roomId": room_id, "action": "suspect",
                                   "targetSeat": mafia["seat"], "actionId": aid()}, c)
    status, morning = fn("resolve_night", {"roomId": room_id}, players[0])
    check("resolve_night", status == 200, morning)
    check("the protected player lived", morning.get("victimSeat") is None, morning)

    fn("open_phase", {"roomId": room_id, "phase": "opening"}, players[0])
    for p in sorted(players, key=lambda q: q["seat"]):
        fn("submit_accusation", {"roomId": room_id, "targetSeat": mafia["seat"]}, p)
    fn("open_phase", {"roomId": room_id, "phase": "discuss"}, players[0])
    status, vote = fn("open_phase", {"roomId": room_id, "phase": "vote"}, players[0])
    check("open the ballot", status == 200, vote)

    # A 2–2 split with one abstention. The two tied seats are x and y; nobody
    # votes for themselves, so each side is filled from the other three.
    x, y = citizens[0], citizens[1]
    others = [p for p in players if p is not x and p is not y]
    ballots = [(x, y["seat"]), (others[0], y["seat"]),
               (y, x["seat"]), (others[1], x["seat"]),
               (others[2], None)]
    for voter, seat in ballots:
        status, _ = fn("submit_vote", {"roomId": room_id, "targetSeat": seat,
                                       "round": 1, "actionId": aid()}, voter)
        check("round-1 ballot from seat %d" % voter["seat"], status == 200, _)

    status, tie = fn("resolve_vote", {"roomId": room_id}, players[0])
    tied = sorted([x["seat"], y["seat"]])
    check("the split is a tie, not an elimination",
          status == 200 and tie.get("tie") is True and tie.get("round") == 2, tie)
    check("the server names exactly the tied seats", tie.get("tiedSeats") == tied, tie)
    state = room_state(room_id, players[0])
    revote = (state.get("public_data") or {}).get("revote") or {}
    check("the room is still balloting, in round two",
          state.get("phase") == "vote" and revote.get("round") == 2
          and sorted(revote.get("tiedSeats") or []) == tied, state)

    outsider = others[0]
    status, refused = fn("submit_vote", {"roomId": room_id, "targetSeat": others[1]["seat"],
                                         "round": 2, "actionId": aid()}, outsider)
    check("a revote ballot for an untied seat is refused",
          status == 400 and refused.get("error") == "BAD_REQUEST", refused)

    status, stale = fn("submit_vote", {"roomId": room_id, "targetSeat": x["seat"],
                                       "round": 1, "actionId": aid()}, outsider)
    check("a ballot for the finished round is refused",
          stale.get("error") == "PHASE_CLOSED", stale)

    # Skipping the Edge Function: the client surface has no write on votes.
    status, direct = h._request(
        "/rest/v1/votes", {"room_id": room_id, "day": 1, "voter_id": outsider["id"],
                           "target_id": others[1]["id"], "round": 2},
        outsider["token"])
    check("a direct write to votes is refused", status >= 400, (status, direct))

    # Round two: x takes three of the tied seats' votes; y and x cannot vote
    # for themselves, so they vote for each other.
    round2 = [(others[0], x["seat"]), (others[1], x["seat"]), (others[2], x["seat"]),
              (x, y["seat"]), (y, x["seat"])]
    for voter, seat in round2:
        status, _ = fn("submit_vote", {"roomId": room_id, "targetSeat": seat,
                                       "round": 2, "actionId": aid()}, voter)
        check("round-2 ballot from seat %d" % voter["seat"], status == 200, _)

    status, verdict = fn("resolve_vote", {"roomId": room_id}, players[0])
    check("the revote resolves", status == 200, verdict)
    check("the revote eliminates the seat it chose",
          verdict.get("eliminatedSeat") == x["seat"], verdict)
    state = room_state(room_id, players[0])
    check("the ballot resolves into the verdict and the revote is cleared",
          state.get("phase") == "verdict"
          and not (state.get("public_data") or {}).get("revote"), state)

    status, again = fn("resolve_vote", {"roomId": room_id}, players[0])
    check("resolving twice is refused or a no-op, never a second elimination",
          again.get("error") == "PHASE_CLOSED"
          or (status == 200 and again.get("eliminatedSeat") in (None, x["seat"])), again)
    status, roster = rest("room_players_public?select=seat,alive&room_id=eq." + room_id, players[0])
    dead = sorted(r["seat"] for r in roster if not r["alive"]) if status == 200 else roster
    check("exactly one player is dead after the day", dead == [x["seat"]], dead)

    fn("close_room", {"roomId": room_id}, players[0])
    return players[:3]


def waiting_room_section(players):
    first, second, third = players
    status, listing = fn("browse_rooms", {}, first)
    check("browse_rooms answers", status == 200 and isinstance(listing.get("rooms"), list), listing)
    waiting = [r for r in listing.get("rooms", []) if r.get("waiting")]
    check("a server-owned waiting room is offered", len(waiting) >= 1, listing)

    status, own = fn("create_room", {"name": "Bot join race", "visibility": "private"}, first)
    if not check("bot-owned join race lobby created", status == 200 and bool(own.get("roomId")), own):
        return
    room_id, code = own["roomId"], own["code"]

    results = {}

    def tap(player, name):
        results[name] = fn("join_room", {"code": code, "name": name}, player)

    threads = [threading.Thread(target=tap, args=(second, "W2")),
               threading.Thread(target=tap, args=(third, "W3"))]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    statuses = sorted(r[0] for r in results.values())
    check("both simultaneous taps are admitted", statuses == [200, 200], results)
    seats = [r[1].get("seat") for r in results.values() if r[0] == 200]
    check("two different seats, none shared", len(seats) == 2 and len(set(seats)) == 2, seats)
    hosts = [name for name, r in results.items() if r[1].get("host") is True]
    check("neither guest claims the host", not hosts, results)
    status, rooms = rest("rooms_public?select=host_id&id=eq." + str(room_id), first)
    row = rooms[0] if status == 200 and rooms else {}
    check("the bot host remains the host", row.get("host_id") == first["id"], (status, rooms))

    fn("close_room", {"roomId": room_id}, first)


def main():
    if not h.KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")
    print("server: " + h.URL)
    print("── revote ──")
    players = revote_section()
    print("── server-owned waiting room ──")
    waiting_room_section(players)
    print("%d passed, %d failed" % (len(h.PASS), len(h.FAIL)))
    sys.exit(1 if h.FAIL else 0)


if __name__ == "__main__":
    main()
