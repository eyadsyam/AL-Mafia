#!/usr/bin/env python3
"""Drive four real Supabase clients while a phone supplies the fifth player."""

import json
import os
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid


URL = os.environ["SUPABASE_URL"].rstrip("/")
KEY = os.environ["SUPABASE_ANON_KEY"]


def request(path, payload=None, token=None, method="POST"):
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(URL + path, data=body, method=method)
    req.add_header("apikey", KEY)
    req.add_header("Authorization", "Bearer " + (token or KEY))
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.loads(response.read() or b"null")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"null")


def call(name, payload, player):
    return request("/functions/v1/" + name, payload, player["token"])


def rest(path, player):
    return request("/rest/v1/" + path, None, player["token"], "GET")


def session(name):
    status, data = request("/auth/v1/signup", {})
    if status != 200 or not data.get("access_token"):
        raise RuntimeError("anonymous sign-in failed: %s" % data)
    return {"name": name, "token": data["access_token"], "id": data["user"]["id"]}


def action_id():
    return str(uuid.uuid4())


def must(label, response):
    status, data = response
    if status != 200:
        raise RuntimeError("%s failed (%s): %s" % (label, status, data))
    return data


def main():
    bots = [session(name) for name in ("Amina", "Bassem", "Camelia", "Dawoud")]
    room = must("create_room", call("create_room", {"name": bots[0]["name"], "gender": "female"}, bots[0]))
    room_id, code = room["roomId"], room["code"]
    bots[0]["seat"] = 0

    def keep_host_alive():
        while True:
            call("heartbeat", {"roomId": room_id}, bots[0])
            time.sleep(10)

    threading.Thread(target=keep_host_alive, daemon=True).start()
    for index, bot in enumerate(bots[1:], 1):
        joined = must("join_room", call("join_room", {"code": code, "name": bot["name"], "gender": "male"}, bot))
        bot["seat"] = joined["seat"]

    print("ROOM_CODE=" + code, flush=True)
    heartbeat_at = 0.0
    while True:
        if time.time() >= heartbeat_at:
            call("heartbeat", {"roomId": room_id}, bots[0])
            heartbeat_at = time.time() + 10
        _, roster = rest("room_players_public?select=seat,name,alive&room_id=eq." + room_id, bots[0])
        if len(roster) >= 5:
            break
        time.sleep(1)

    print("PHONE_JOINED; starting in 8 seconds", flush=True)
    for _ in range(2):
        call("heartbeat", {"roomId": room_id}, bots[0])
        time.sleep(4)

    roles = {"mafia": 1, "doctor": 1, "detective": 1, "citizen": 2}
    settings = {
        "speechSeconds": 10,
        "confrontationSeconds": 10,
        "abstainAllowed": True,
        "whisperEnabled": False,
        "traceEnabled": True,
        "confrontationEnabled": False,
        "openingRoundEnabled": False,
        "survivorConfrontationEnabled": False,
        "dayTieRule": "noElimination",
    }
    must("start_match", call("start_match", {"roomId": room_id, "roles": roles, "settings": settings}, bots[0]))
    for bot in bots:
        mine = must("my_team", call("my_team", {"roomId": room_id}, bot))
        bot["role"] = mine["role"]

    all_seats = sorted(row["seat"] for row in roster)
    known_mafia = next((bot["seat"] for bot in bots if bot["role"] == "mafia"), None)
    phone_role = next(role for role, count in roles.items() if sum(bot["role"] == role for bot in bots) < count)
    phone_seat = next(seat for seat in all_seats if seat not in {bot["seat"] for bot in bots})
    mafia_seat = phone_seat if phone_role == "mafia" else known_mafia
    print("STARTED PHONE_ROLE=%s PHONE_SEAT=%s MAFIA_SEAT=%s" % (phone_role, phone_seat, mafia_seat), flush=True)

    alive = set(all_seats)
    for line in sys.stdin:
        command = line.strip().lower()
        if command == "night":
            must("open night", call("open_phase", {"roomId": room_id, "phase": "night"}, bots[0]))
            for bot in bots:
                if bot["seat"] not in alive:
                    continue
                others = sorted(alive - {bot["seat"]})
                if bot["role"] == "mafia":
                    targets = [seat for seat in others if seat != mafia_seat]
                    action, target = "kill", targets[0]
                elif bot["role"] == "doctor":
                    action, target = "protect", others[-1]
                elif bot["role"] == "detective":
                    action, target = "investigate", mafia_seat
                else:
                    action, target = "suspect", mafia_seat
                must("night action", call("submit_night_action", {
                    "roomId": room_id, "action": action, "targetSeat": target,
                    "actionId": action_id(), "note": "demo",
                }, bot))
            print("NIGHT_READY", flush=True)
        elif command == "morning":
            result = must("resolve night", call("resolve_night", {"roomId": room_id}, bots[0]))
            victim = result.get("victimSeat")
            if victim is not None:
                alive.discard(victim)
            print("MORNING victim=%s" % victim, flush=True)
        elif command == "discussion":
            must("open discussion", call("open_phase", {"roomId": room_id, "phase": "discuss"}, bots[0]))
            print("DISCUSSION", flush=True)
        elif command == "vote":
            must("open vote", call("open_phase", {"roomId": room_id, "phase": "vote"}, bots[0]))
            for bot in bots:
                if bot["seat"] not in alive:
                    continue
                target = mafia_seat if bot["seat"] != mafia_seat else next(seat for seat in sorted(alive) if seat != mafia_seat)
                must("vote", call("submit_vote", {
                    "roomId": room_id, "targetSeat": target, "round": 1,
                    "actionId": action_id(),
                }, bot))
            print("VOTE_READY target=%s" % mafia_seat, flush=True)
        elif command == "result":
            result = must("resolve vote", call("resolve_vote", {"roomId": room_id}, bots[0]))
            print("RESULT=" + json.dumps(result, separators=(",", ":")), flush=True)
        elif command == "state":
            _, state = rest("room_state?select=phase,phase_number,public_data&room_id=eq." + room_id, bots[0])
            print("STATE=" + json.dumps(state, separators=(",", ":")), flush=True)
        elif command == "quit":
            return 0
        else:
            print("COMMANDS=night,morning,discussion,vote,result,state,quit", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
