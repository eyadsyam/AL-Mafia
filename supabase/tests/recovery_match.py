"""Recovery against the hosted functions — the server half of section B.

A client that restarts holds a room id and a code and nothing else. Whether it
gets its seat back is the server's decision, and these are the answers the
server must give:

  * a refresh in the lobby and a refresh mid-match come back to the same seat
  * a player who left a running match can return to their seat
  * a removed player is refused, on rejoin and on a fresh join alike
  * a room the host closed refuses everybody, and says it is finished
  * a room that reached its result refuses everybody, and says it is finished

    SUPABASE_URL=... SUPABASE_ANON_KEY=... python supabase/tests/recovery_match.py
"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0] if "/" in __file__ else __file__.rsplit("\\", 1)[0])
from concurrency_match import ROLES, SETTINGS, deal, make_room, parallel, state_of  # noqa: E402
from e2e_match import KEY, URL, PASS, FAIL, aid, anon_session, check, drop_minted_users, fn, rest  # noqa: E402


def seat_row(room_id, player):
    status, rows = rest("room_players_public?select=seat,status,connected,alive&room_id=eq." + room_id + "&user_id=eq." + player["id"], player)
    return rows[0] if status == 200 and rows else {}


def main():
    if not KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")
    print("server: " + URL)

    # Every session first: a lobby silent for ninety seconds is given up, and
    # a sign-in that waits out the hosted rate limit takes longer than that.
    sub = anon_session("Farah")
    stranger = anon_session("Ghali")
    players, room_id, code = make_room(["Amina", "Bassem", "Camelia", "Dawoud", "Enas"])

    # ── lobby refresh ────────────────────────────────────────────────────
    status, again = fn("join_room", {"code": code, "name": "Camelia"}, players[2])
    check("lobby refresh: same seat", status == 200 and again.get("rejoined") is True and again.get("seat") == 2, again)

    # ── removed in the lobby ─────────────────────────────────────────────
    status, kicked = fn("kick_player", {"roomId": room_id, "seat": 4}, players[0])
    check("host removes seat 4", status == 200, kicked)
    status, back = fn("join_room", {"code": code, "name": "Enas"}, players[4])
    check("a removed player is refused on rejoin", back.get("error") == "NOT_A_MEMBER", back)
    status, back = fn("join_room", {"code": code, "name": "Enas again"}, players[4])
    check("...and on a fresh join under another name", back.get("error") == "NOT_A_MEMBER", back)
    status, joined = fn("join_room", {"code": code, "name": "Farah"}, sub)
    check("the freed seat is open to somebody else", status == 200, joined)
    players[4] = sub
    players[4]["seat"] = joined.get("seat")

    # ── mid-match refresh and return ─────────────────────────────────────
    deal(players, room_id)
    parallel([lambda p=p: fn("open_phase", {"roomId": room_id, "phase": "night"}, p) for p in players[:2]])
    s = state_of(room_id, players[0])
    check("the match is running", s.get("phase") == "night", s)

    status, again = fn("join_room", {"code": code, "name": "Bassem"}, players[1])
    check("mid-match refresh: same seat", status == 200 and again.get("rejoined") is True and again.get("seat") == 1, again)
    row = seat_row(room_id, players[1])
    check("...and connected", row.get("status") == "connected" and row.get("connected") is True, row)

    status, gone = fn("leave_room", {"roomId": room_id}, players[3])
    check("a player leaves the running match", status == 200 and gone.get("result") == "disconnected", gone)
    row = seat_row(room_id, players[3])
    check("the seat is kept and marked left", row.get("seat") == 3 and row.get("status") == "left", row)
    status, again = fn("join_room", {"code": code, "name": "Dawoud"}, players[3])
    check("...and they can return to it", status == 200 and again.get("rejoined") is True and again.get("seat") == 3, again)
    row = seat_row(room_id, players[3])
    check("...connected again", row.get("status") == "connected", row)

    status, refused = fn("join_room", {"code": code, "name": "Ghali"}, stranger)
    check("a stranger cannot join a running match", refused.get("error") == "PHASE_CLOSED", refused)

    # ── removed mid-match ────────────────────────────────────────────────
    # A dealt seat the host removes is out of the match, neutrally (migration
    # `kick_eliminates`). A citizen, so the win check has nothing to say and
    # the closed-room check below still sees a room nobody won.
    gone = next(p for p in players[1:] if p["role"] == "citizen")
    status, kicked = fn("kick_player", {"roomId": room_id, "seat": gone["seat"]}, players[0])
    check("host removes a seat mid-match", status == 200, kicked)
    status, back = fn("join_room", {"code": code, "name": gone["label"]}, gone)
    check("a player removed mid-match is refused", back.get("error") == "NOT_A_MEMBER", back)
    row = seat_row(room_id, gone)
    check("...and the seat is out of the match, its role unnamed", row.get("alive") is False, row)
    s = state_of(room_id, players[0])
    elim = ((s.get("public_data") or {}).get("eliminations") or {}).get(str(gone["seat"]))
    check("...recorded as a neutral elimination in the current phase", elim == {"phase": "night", "number": 1}, elim)
    check("...with no outcome, four living and one Mafia among them", (s.get("public_data") or {}).get("outcome") is None, s)

    # ── the host closes the room ─────────────────────────────────────────
    status, closed = fn("close_room", {"roomId": room_id}, players[0])
    check("the host closes the room", status == 200, closed)
    status, room = rest("rooms_public?select=status&id=eq." + room_id, players[1])
    check("a closed room is finished", status == 200 and room and room[0]["status"] == "finished", room)
    s = state_of(room_id, players[1])
    check("...with no outcome invented", (s.get("public_data") or {}).get("outcome") is None, s)
    status, back = fn("join_room", {"code": code, "name": "Bassem"}, players[1])
    check("a closed room refuses a returning player as finished", back.get("error") == "ROOM_FINISHED", back)
    status, back = fn("join_room", {"code": code, "name": "Ghali"}, stranger)
    check("...and a stranger the same way", back.get("error") == "ROOM_FINISHED", back)

    # ── a match that reached its result ──────────────────────────────────
    players2, room2, code2 = make_room(["Hala", "Ibrahim", "Jana", "Karim", "Lina"])
    deal(players2, room2)
    parallel([lambda p=p: fn("open_phase", {"roomId": room2, "phase": "night"}, p) for p in players2[:2]])
    by_role = {}
    for p in players2:
        by_role.setdefault(p["role"], []).append(p)
    mafia, doctor, detective = by_role["mafia"][0], by_role["doctor"][0], by_role["detective"][0]
    citizens = by_role["citizen"]
    fn("submit_night_action", {"roomId": room2, "action": "kill", "targetSeat": citizens[0]["seat"], "actionId": aid()}, mafia)
    fn("submit_night_action", {"roomId": room2, "action": "protect", "targetSeat": citizens[1]["seat"], "actionId": aid()}, doctor)
    fn("submit_night_action", {"roomId": room2, "action": "investigate", "targetSeat": mafia["seat"], "actionId": aid()}, detective)
    for c in citizens:
        fn("submit_night_action", {"roomId": room2, "action": "suspect", "targetSeat": mafia["seat"], "actionId": aid()}, c)
    status, morning = fn("resolve_night", {"roomId": room2}, players2[0])
    check("night one resolves", status == 200, morning)
    fn("open_phase", {"roomId": room2, "phase": "opening"}, players2[0])
    status, roster = rest("room_players_public?select=seat,alive&room_id=eq." + room2, players2[0])
    living = sorted(r["seat"] for r in roster if r["alive"])
    for seat in living:
        p = next(x for x in players2 if x["seat"] == seat)
        t = next(x for x in living if x != seat)
        fn("submit_accusation", {"roomId": room2, "targetSeat": t}, p)
    fn("open_phase", {"roomId": room2, "phase": "vote"}, players2[0])
    for p in players2:
        if p["seat"] in living and p is not mafia:
            fn("submit_vote", {"roomId": room2, "targetSeat": mafia["seat"], "round": 1, "actionId": aid()}, p)
    status, verdict = fn("resolve_vote", {"roomId": room2}, players2[0])
    check("the town votes the Mafia out", status == 200 and verdict.get("outcome") == "town", verdict)
    status, result = fn("open_phase", {"roomId": room2, "phase": "result"}, players2[0])
    check("the result opens", status == 200, result)

    status, back = fn("join_room", {"code": code2, "name": "Jana"}, players2[2])
    check("a finished match refuses a returning player as finished", back.get("error") == "ROOM_FINISHED", back)
    s = state_of(room2, players2[2])
    check("...while its result and standings stay readable to members",
          s.get("phase") == "result" and len((s.get("public_data") or {}).get("standings") or []) == 5, s)

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
