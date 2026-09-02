#!/usr/bin/env python3
"""A whole online match, played by five clients against a real server.

The Dart transport tests prove the *client* behaves; `anticheat.sql` proves the
*database* refuses. Neither of them runs an Edge Function, and the Edge
Functions are where the phase machine lives — so this is the third leg: five
anonymous sessions, eighteen deployed functions, and a match played from an
empty lobby to a win condition.

It is deliberately rude where doc 11 §6 says it should be:

  * O17 — a Doctor tries to submit a kill;
  * O16 — a Citizen asks who the Mafia are;
  * O19 — the same action id is replayed and must not count twice;
  * O7  — an action arrives after its phase closed and must be told so;
  * NOT_HOST — a guest tries to drive the phase.

Usage
-----
    # against the local stack (`supabase start`)
    python supabase/tests/e2e_match.py

    # against any project whose functions are deployed
    SUPABASE_URL=https://xxxx.supabase.co SUPABASE_ANON_KEY=sb_publishable_… \
        python supabase/tests/e2e_match.py

Exit code 0 means the match completed and every assertion held.
"""

import json
import os
import time
import uuid
import sys
import urllib.error
import urllib.request

URL = os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321").rstrip("/")
KEY = os.environ.get("SUPABASE_ANON_KEY", "")
# Only used when anonymous sign-ins are switched off on the project: the
# harness then mints its own confirmed users through the admin API rather than
# skipping the run. The app itself still has exactly one way in (doc 10 s10).
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")

PASS, FAIL = [], []


def aid():
    """An idempotency key. `action_id` is a uuid column, so this is not a label."""
    return str(uuid.uuid4())


def _request(path, payload, token=None, method="POST"):
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(URL + path, data=body, method=method)
    req.add_header("apikey", KEY)
    req.add_header("Authorization", "Bearer " + (token or KEY))
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw or b"null")
        except json.JSONDecodeError:
            return e.code, {"error": "NON_JSON", "message": raw.decode("utf8", "replace")}


def fn(name, payload, player):
    """Calls an Edge Function as `player`."""
    return _request("/functions/v1/" + name, payload, player["token"])


def rest(path, player):
    return _request("/rest/v1/" + path, None, player["token"], method="GET")


def check(name, condition, detail=""):
    (PASS if condition else FAIL).append(name)
    print(("  ok   " if condition else "  FAIL ") + name + (("  — " + str(detail)) if detail and not condition else ""))
    return condition


def _admin_request(path, payload, method="POST"):
    """A call made as the service role. Only the user-minting path uses it."""
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(URL + path, data=body, method=method)
    req.add_header("apikey", SERVICE_KEY)
    req.add_header("Authorization", "Bearer " + SERVICE_KEY)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw or b"null")
        except json.JSONDecodeError:
            return e.code, {"error": "NON_JSON", "message": raw.decode("utf8", "replace")}


MINTED = []


def password_session(label):
    """A throwaway confirmed user, for a project with anonymous sign-ins off.

    The five players only need *a* session; nothing under test reads the
    identity provider. This keeps the suite runnable against a project whose
    anonymous provider has not been switched on yet, and it is the harness's
    own back door — the app still has none.
    """
    email = "e2e-%s@example.com" % uuid.uuid4().hex
    password = uuid.uuid4().hex + "Aa1!"
    status, created = _admin_request(
        "/auth/v1/admin/users",
        {"email": email, "password": password, "email_confirm": True},
    )
    if status not in (200, 201) or not created.get("id"):
        raise SystemExit("could not create a test user (%s): %s" % (status, created))
    status, data = _request(
        "/auth/v1/token?grant_type=password",
        {"email": email, "password": password},
    )
    if status != 200 or not data.get("access_token"):
        raise SystemExit("could not sign the test user in (%s): %s" % (status, data))
    MINTED.append(created["id"])
    return {"label": label, "token": data["access_token"], "id": created["id"]}


def drop_minted_users():
    """Deletes the users this harness created. Anonymous sessions are purged by
    the project itself; the ones minted above would otherwise pile up."""
    for user_id in MINTED:
        _admin_request("/auth/v1/admin/users/" + user_id, None, method="DELETE")


def anon_session(label):
    status, data = _request("/auth/v1/signup", {})
    if status == 200 and data.get("access_token"):
        return {"label": label, "token": data["access_token"], "id": data["user"]["id"]}
    if SERVICE_KEY:
        return password_session(label)
    raise SystemExit(
        "anonymous sign-in failed (%s): %s\n"
        "Enable it: Authentication -> Sign In / Providers -> Anonymous sign-ins.\n"
        "Or set SUPABASE_SERVICE_KEY to let this harness mint its own users."
        % (status, data)
    )


def main():
    if not KEY:
        raise SystemExit("set SUPABASE_ANON_KEY (or SUPABASE_PUBLISHABLE_KEY)")

    print("server: " + URL)

    names = ["Amina", "Bassem", "Camelia", "Dawoud", "Enas"]
    players = [anon_session(n) for n in names]
    print("five sessions (anonymous, or minted by the harness if that is off)")

    # ── the lobby ────────────────────────────────────────────────────────
    status, room = fn("create_room", {"name": names[0]}, players[0])
    check("create_room", status == 200 and "roomId" in room, room)
    room_id, code = room["roomId"], room["code"]
    check("code shape", len(code) == 6 and all(c in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" for c in code), code)
    players[0]["seat"] = 0

    for i, p in enumerate(players[1:], start=1):
        status, joined = fn("join_room", {"code": code, "name": names[i]}, p)
        check("join seat %d" % i, status == 200 and joined.get("seat") == i, joined)
        p["seat"] = joined.get("seat")

    # O4 — rejoining is not a second seat.
    status, again = fn("join_room", {"code": code, "name": names[1]}, players[1])
    check("O4 rejoin keeps the seat", status == 200 and again.get("rejoined") is True and again.get("seat") == 1, again)

    # NOT_HOST — a guest may not deal.
    status, refused = fn("start_match", {"roomId": room_id, "roles": {"citizen": 5}, "settings": {}}, players[1])
    check("a guest cannot start", refused.get("error") == "NOT_HOST", refused)

    # ── the deal ─────────────────────────────────────────────────────────
    settings = {
        "speechSeconds": 60, "confrontationSeconds": 30, "abstainAllowed": True,
        "whisperEnabled": True, "traceEnabled": True, "confrontationEnabled": True,
        "openingRoundEnabled": True, "survivorConfrontationEnabled": True,
        "dayTieRule": "noElimination",
    }
    roles = {"mafia": 1, "doctor": 1, "detective": 1, "citizen": 2}
    status, started = fn("start_match", {"roomId": room_id, "roles": roles, "settings": settings}, players[0])
    check("start_match", status == 200 and started.get("started") is True, started)
    check("start_match says nothing about roles", "roles" not in started and "dealt" not in started, started)

    for p in players:
        status, mine = fn("my_team", {"roomId": room_id}, p)
        p["role"] = mine.get("role")
        p["teammates"] = mine.get("teammates", [])
    dealt = sorted(p["role"] for p in players)
    check("the deal matches the request", dealt == sorted(["mafia", "doctor", "detective", "citizen", "citizen"]), dealt)

    by_role = {}
    for p in players:
        by_role.setdefault(p["role"], []).append(p)
    mafia = by_role["mafia"][0]
    doctor = by_role["doctor"][0]
    detective = by_role["detective"][0]
    citizens = by_role["citizen"]

    # O16 — the role table, asked for directly, by somebody who is in the room.
    status, leaked = rest("room_players?select=role&room_id=eq." + room_id, citizens[0])
    check("O16 role column is not on the surface", status != 200, leaked)
    status, roster = rest("room_players_public?select=seat,name,alive&room_id=eq." + room_id, citizens[0])
    check("the roster is readable", status == 200 and len(roster) == 5, roster)
    check("the roster carries no role", all("role" not in row for row in roster), roster)
    status, seed = rest("rooms?select=match_seed&id=eq." + room_id, citizens[0])
    check("the seed is not on the surface", status != 200, seed)
    check("a Citizen has no teammates", citizens[0]["teammates"] == [], citizens[0]["teammates"])

    # ── night one ────────────────────────────────────────────────────────
    status, opened = fn("open_phase", {"roomId": room_id, "phase": "night"}, players[0])
    check("open night", status == 200 and opened.get("phase") == "night", opened)

    victim = citizens[0]
    saved = citizens[1]
    kill_id = aid()  # reused once, deliberately, to prove O19

    status, refused = fn(
        "submit_night_action",
        {"roomId": room_id, "action": "kill", "targetSeat": mafia["seat"], "actionId": aid()},
        doctor,
    )
    check("O18 a Doctor cannot kill", refused.get("error") == "WRONG_ROLE", refused)

    status, _ = fn("submit_night_action",
                   {"roomId": room_id, "action": "kill", "targetSeat": victim["seat"], "actionId": kill_id}, mafia)
    check("the Mafia acts", status == 200, _)
    status, _ = fn("submit_night_action",
                   {"roomId": room_id, "action": "protect", "targetSeat": saved["seat"], "actionId": aid()}, doctor)
    check("the Doctor acts", status == 200, _)
    status, found = fn("submit_night_action",
                       {"roomId": room_id, "action": "investigate", "targetSeat": mafia["seat"], "actionId": aid()},
                       detective)
    check("the Detective learns the exact role", found.get("revealedRole") == "mafia", found)
    for c in citizens:
        fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": mafia["seat"],
                                   "note": "hesitated", "actionId": aid()}, c)

    # O19 — a replayed action id is the same action, not a second one.
    status, replay = fn("submit_night_action",
                        {"roomId": room_id, "action": "kill", "targetSeat": victim["seat"], "actionId": kill_id}, mafia)
    check("O19 replay is idempotent", status == 200, replay)
    status, actions = rest("night_actions?select=action&room_id=eq." + room_id, mafia)
    check("O19 one row, not two", status == 200 and len(actions) == 1, actions)

    status, morning = fn("resolve_night", {"roomId": room_id}, players[0])
    check("resolve_night", status == 200, morning)
    check("the protected player lived", morning.get("victimSeat") != saved["seat"], morning)

    # V6 — the night is hard muted for everyone, no exceptions. The refusal is
    # a 200 with `granted: false`, not an error: a player who tapped at the
    # wrong moment has not done anything wrong (doc 10 s6.3).
    status, floor = fn("claim_floor", {"roomId": room_id}, mafia)
    check("V6 the night grants no floor",
          status == 200 and floor.get("granted") is False and floor.get("policy") == "muted",
          floor)

    # V9 — a match already in progress is not joinable. Rejoin only.
    intruder = anon_session("intruder")
    status, refused = fn("join_room", {"code": code, "name": "Late"}, intruder)
    check("V9 no joining a match in progress",
          status != 200 and refused.get("error") in ("ROOM_FINISHED", "PHASE_CLOSED", "ROOM_FULL", "BAD_REQUEST"),
          refused)

    # O7 — an action that arrives after its phase closed.
    status, late = fn("submit_night_action",
                      {"roomId": room_id, "action": "kill", "targetSeat": saved["seat"], "actionId": aid()}, mafia)
    check("O7 a late action is refused with PHASE_CLOSED", late.get("error") == "PHASE_CLOSED", late)

    # ── O1 / O2 — the host leaves, and the match does not ───────────
    #
    # Doc 11 §10 asks for this "verified by force-quitting the host mid-night".
    # A harness cannot force-quit a phone and does not need to: what a dead
    # phone *is*, to this server, is a `last_seen` that stopped moving.
    # Backdating it is the same fact with none of the theatre, and it is the
    # only way to reach the 30-second staleness window inside a run that takes
    # eight seconds.
    #
    # It needs the service key because nothing on the client surface may write
    # `room_players` at all — which is the point of doc 10 s4.1, and the reason
    # this block is the one thing in the file a player could not do.
    if SERVICE_KEY:
        def go_quiet(player, seconds=300):
            when = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - seconds))
            return _admin_request(
                "/rest/v1/room_players?room_id=eq.%s&user_id=eq.%s" % (room_id, player["id"]),
                {"last_seen": when},
                method="PATCH",
            )

        def host_now():
            _, rows = _admin_request(
                "/rest/v1/rooms?select=host_id&id=eq." + room_id, None, method="GET")
            return rows[0]["host_id"] if rows else None

        _, before = rest("room_state?select=phase,phase_number&room_id=eq." + room_id, players[0])
        phase_before = before[0] if before else {}

        # A claim is not a vote of no confidence. While the host is answering,
        # asking to take over is answered with "the room already has one".
        #
        # The heartbeat first is not scene-setting. Nothing else in a match
        # touches `last_seen` — an Edge Function call is not a sign of life,
        # deliberately, because a client can be making requests while its
        # player has walked off — so by this point in the run the host has been
        # quiet for longer than the 30-second window and would lose the room
        # without ever having left. That is the correct behaviour and it makes
        # a poor fixture, so the host does here what the app does every ten
        # seconds.
        status, beat = fn("heartbeat", {"roomId": room_id}, players[0])
        check("the host is answering", status == 200, beat)

        status, held = fn("claim_host", {"roomId": room_id}, players[1])
        check("O1 a host who is answering keeps the room",
              status == 200 and held.get("claimed") is False
              and held.get("hostId") == players[0]["id"], held)

        go_quiet(players[0])
        status, took = fn("claim_host", {"roomId": room_id}, players[1])
        check("O1 the lowest connected seat inherits",
              status == 200 and took.get("claimed") is True
              and took.get("hostId") == players[1]["id"], took)
        check("the room agrees who the host is", host_now() == players[1]["id"])

        # A migration is not a state change in the game: the new host inherits
        # the same next step the old one was about to take.
        _, after = rest("room_state?select=phase,phase_number&room_id=eq." + room_id, players[0])
        check("the phase did not move", bool(after) and after[0] == phase_before,
              (phase_before, after))

        # The loser of a race is told who won, not handed an error.
        status, late = fn("claim_host", {"roomId": room_id}, players[2])
        check("O1 a beaten claimant is told who holds it",
              status == 200 and late.get("claimed") is False
              and late.get("hostId") == players[1]["id"], late)

        # O2 — the cascade. The heir goes quiet too, and the next live seat
        # takes it. Nothing special-cases this; "lowest connected seat"
        # evaluated again is the whole of the mechanism.
        go_quiet(players[1])
        status, back = fn("claim_host", {"roomId": room_id}, players[0])
        check("O2 the cascade reaches the next living seat",
              status == 200 and back.get("claimed") is True
              and back.get("hostId") == players[0]["id"], back)
        check("the original host is driving again", host_now() == players[0]["id"])
    else:
        print("  skip host migration (set SUPABASE_SERVICE_KEY to run it)")

    # ── day one ──────────────────────────────────────────────────────────
    status, state = rest("room_state?select=phase,phase_number,public_data&room_id=eq." + room_id, players[0])
    check("the morning is public", status == 200 and len(state) == 1, state)
    public = state[0]["public_data"] if state else {}
    check("the archive survived the resolve", "nights" in public or "morning" in public, sorted(public.keys()))

    living = [p for p in players if p["seat"] != morning.get("victimSeat")]

    fn("open_phase", {"roomId": room_id, "phase": "opening"}, players[0])
    for p in sorted(living, key=lambda q: q["seat"]):
        fn("submit_accusation", {"roomId": room_id, "targetSeat": mafia["seat"]}, p)

    fn("open_phase", {"roomId": room_id, "phase": "discuss"}, players[0])
    for p in living:
        fn("record_speaking", {"roomId": room_id, "seconds": 20}, p)

    # ── the floor (doc 10 s6.1) ──────────────────────────────────────────
    #
    # One microphone at a time, decided here and not by the device that would
    # like it. Everything below is a 200 either way; what changes is `granted`.
    first, second = living[0], living[1]

    status, taken = fn("claim_floor", {"roomId": room_id}, first)
    check("a structured discussion grants the floor",
          status == 200 and taken.get("granted") is True, taken)

    # V4 — the second claimant is refused while the first still holds it. The
    # server does not ask them to be polite about it.
    status, denied = fn("claim_floor", {"roomId": room_id}, second)
    check("V4 only one seat holds the floor",
          status == 200 and denied.get("granted") is False, denied)

    status, live = rest("room_state?select=active_speaker,speaker_until&room_id=eq." + room_id, second)
    check("the whole room can see whose microphone is live",
          status == 200 and live and live[0]["active_speaker"] == first["id"], live)
    check("V5 the grant carries a deadline",
          status == 200 and live and live[0]["speaker_until"] is not None, live)

    # And giving it back lets the next player have it.
    status, _ = fn("release_floor", {"roomId": room_id}, first)
    check("release_floor", status == 200, _)
    status, passed = fn("claim_floor", {"roomId": room_id}, second)
    check("the floor passes once it is given back",
          status == 200 and passed.get("granted") is True, passed)

    # A client that has already lost the floor cannot clear the holder's grant.
    fn("release_floor", {"roomId": room_id}, first)
    status, still = rest("room_state?select=active_speaker&room_id=eq." + room_id, first)
    check("a stale holder cannot release somebody else's floor",
          status == 200 and still and still[0]["active_speaker"] == second["id"], still)

    fn("open_phase", {"roomId": room_id, "phase": "vote"}, players[0])
    for p in living:
        # Nobody may name themselves, so the Mafioso spends their ballot
        # elsewhere — which is also what a Mafioso would actually do.
        target = saved["seat"] if p is mafia else mafia["seat"]
        status, _ = fn("submit_vote", {"roomId": room_id, "targetSeat": target,
                                       "round": 1, "actionId": aid()}, p)
        check("ballot from seat %d" % p["seat"], status == 200, _)

    # The ballot is hard muted too, and opening the phase took the floor away.
    status, ballot_floor = fn("claim_floor", {"roomId": room_id}, living[0])
    check("the ballot grants no floor",
          status == 200 and ballot_floor.get("granted") is False
          and ballot_floor.get("policy") == "muted",
          ballot_floor)

    # A running tally during an open ballot is a channel the table game lacks.
    status, peek = rest("votes?select=voter_id&room_id=eq." + room_id, citizens[1] if citizens[1] in living else living[0])
    check("no running tally during an open ballot", status == 200 and len(peek) <= 1, peek)

    status, verdict = fn("resolve_vote", {"roomId": room_id}, players[0])
    check("resolve_vote", status == 200, verdict)
    check("the room voted out the Mafia", verdict.get("eliminatedSeat") == mafia["seat"], verdict)
    check("the town wins", verdict.get("outcome") == "town", verdict.get("outcome"))

    status, finished = rest("rooms_public?select=status&id=eq." + room_id, players[0])
    check("the room is finished", status == 200 and finished and finished[0]["status"] == "finished", finished)

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
