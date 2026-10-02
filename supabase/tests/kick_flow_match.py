"""One match, start to finish, with every kind of removal in it — the whole
case section C asks for, against the hosted functions.

  * a lobby kick, then a replacement on a fresh seat, then the start
  * the host's saved settings survive a start payload that disagrees
  * a removal racing the night's resolution: the resolver's tally is refused
    by `commit_resolution` when the population moved under it and counted
    again — from the outside, one 200 and one of exactly two consistent worlds
  * a seat struck for silence after the deal (`remove_player`) stays a
    participant, is out, has its whisper voided, is recorded once, and the
    win check is not invented from it
  * the result's standings name the dealt seats and nobody removed before
    the deal; the pre-deal removal never touches the outcome

    SUPABASE_URL=... SUPABASE_ANON_KEY=... python supabase/tests/kick_flow_match.py
"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0] if "/" in __file__ else __file__.rsplit("\\", 1)[0])
from concurrency_match import ROLES, SETTINGS, make_room, parallel, state_of  # noqa: E402
from e2e_match import KEY, URL, PASS, FAIL, aid, anon_session, check, drop_minted_users, fn, rest  # noqa: E402
from roster_match import room_settings, roster  # noqa: E402


def public_data(room_id, player):
    return state_of(room_id, player).get("public_data") or {}


def whispers_to(room_id, player, user_id):
    status, rows = rest("whisper_meta?select=day,from_id,to_id,voided&room_id=eq." + room_id + "&to_id=eq." + user_id, player)
    return rows if status == 200 else []


def main():
    if not KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")
    print("server: " + URL)

    # ── lobby: a removal, a replacement, saved settings ─────────────────
    # The replacement's session first: a lobby whose members have all been
    # silent for ninety seconds is given up, and a sign-in that waits out the
    # hosted rate limit can take longer than that.
    farah = anon_session("Farah")
    players, room_id, code = make_room(["Amina", "Bassem", "Camelia", "Dawoud", "Enas"])
    host, enas = players[0], players[4]
    status, changed = fn("room_settings", {"roomId": room_id, "settings": {"voice": False, "maxPlayers": 5}}, host)
    check("the host saves voice off at capacity five", status == 200, changed)
    status, kicked = fn("kick_player", {"roomId": room_id, "seat": 4}, host)
    check("the host removes seat 4 in the lobby", status == 200, kicked)
    status, beat = fn("heartbeat", {"roomId": room_id}, enas)
    check("the removed player is no longer a member", beat.get("error") == "NOT_A_MEMBER", beat)
    status, back = fn("join_room", {"code": code, "name": "Enas"}, enas)
    check("...and is refused at the door", back.get("error") == "NOT_A_MEMBER", back)
    status, joined = fn("join_room", {"code": code, "name": "Farah"}, farah)
    check("a replacement is admitted at capacity five with the removed row present", status == 200, joined)
    check("...on a fresh seat", joined.get("seat") == 5, joined)
    farah["seat"] = joined.get("seat")
    players = players[:4] + [farah]

    # ── the start: the payload disagrees with the saved settings ─────────
    status, started = fn("start_match", {"roomId": room_id, "roles": ROLES, "settings": dict(SETTINGS, voice=True)}, host)
    check("the match starts with the five seated", status == 200 and started.get("started") is True, started)
    saved = room_settings(room_id, host).get("settings") or {}
    check("the saved settings win over the start payload", saved.get("voice") is False and saved.get("maxPlayers") == 5, saved)
    check("...and the start payload's other keys were kept", saved.get("dayTieRule") == "noElimination", saved)
    check("rosterSeats is the dealt population, no seat 4", public_data(room_id, host).get("rosterSeats") == [0, 1, 2, 3, 5],
          public_data(room_id, host).get("rosterSeats"))
    rows = roster(room_id, host)
    check("the pre-deal removal is marked and not alive", any(r["seat"] == 4 and r["kicked"] and not r["alive"] for r in rows), rows)
    for p in players:
        status, mine = fn("my_team", {"roomId": room_id}, p)
        p["role"] = mine.get("role")
        status, seen = fn("saw_role", {"roomId": room_id}, p)
        check("seat %d sees its card" % p["seat"], status == 200, seen)
    status, seen = fn("saw_role", {"roomId": room_id}, enas)
    check("the removed seat cannot acknowledge a card it never got", seen.get("error") == "NOT_A_MEMBER", seen)
    by_role = {}
    for p in players:
        by_role.setdefault(p["role"], []).append(p)
    check("five roles dealt", sorted(len(v) for v in by_role.values()) == [1, 1, 1, 2], {k: len(v) for k, v in by_role.items()})
    mafia, doctor, detective = by_role["mafia"][0], by_role["doctor"][0], by_role["detective"][0]
    # The two seats that go: the night's kill target and the day's struck seat.
    # Town, never the host (a host cannot remove itself), citizens first so
    # the doctor and the detective keep their moves.
    town = [p for p in players if p["role"] != "mafia" and p is not host]
    town.sort(key=lambda p: 0 if p["role"] == "citizen" else 1)
    c2 = town[0]
    # The detective is the one who whispers to c1, so c1 is never the detective.
    c1 = next(p for p in town[1:] if p is not detective)

    # ── night one: a removal racing the resolution ───────────────────────
    status, opened = fn("open_phase", {"roomId": room_id, "phase": "night"}, host)
    check("the reveal gate opens the night", status == 200, opened)
    fn("submit_night_action", {"roomId": room_id, "action": "kill", "targetSeat": c2["seat"], "actionId": aid()}, mafia)
    fn("submit_night_action", {"roomId": room_id, "action": "protect", "targetSeat": c1["seat"], "actionId": aid()}, doctor)
    fn("submit_night_action", {"roomId": room_id, "action": "investigate", "targetSeat": mafia["seat"], "actionId": aid()}, detective)
    fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": mafia["seat"], "actionId": aid()}, c1)
    status, move = fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": mafia["seat"], "actionId": aid()}, c2)
    check("the last night move lands", status == 200, move)
    (r_status, morning), (k_status, removal) = parallel([
        lambda: fn("resolve_night", {"roomId": room_id}, host),
        lambda: fn("kick_player", {"roomId": room_id, "seat": c2["seat"]}, host),
    ])
    check("the night resolves while the host removes the kill target", r_status == 200 and k_status == 200, (morning, removal))
    pd = public_data(room_id, host)
    elim = (pd.get("eliminations") or {}).get(str(c2["seat"]))
    worlds = {
        "removal first: the tally was recounted without the dead target, nobody was killed":
            morning.get("victimSeat") is None and elim == {"phase": "night", "number": 1},
        "resolution first: the kill landed, the removal of a dead seat banned and nothing more":
            morning.get("victimSeat") == c2["seat"] and elim == {"phase": "night", "number": 1},
    }
    check("exactly one consistent world: " + next((k for k, v in worlds.items() if v), "neither"),
          sum(worlds.values()) == 1, (morning, elim))
    check("the room is on the morning", state_of(room_id, host).get("phase") == "morning", state_of(room_id, host).get("phase"))
    rows = roster(room_id, host)
    check("the removed target is out, once", sum(1 for r in rows if r["seat"] == c2["seat"] and not r["alive"] and r["kicked"]) == 1, rows)
    check("four living: no outcome invented", pd.get("outcome") is None and sum(1 for r in rows if r["alive"]) == 4, (pd.get("outcome"), rows))
    check("the saved settings are untouched by the night", (room_settings(room_id, host).get("settings") or {}).get("voice") is False)

    # ── day one: a whisper, then the whispered-to seat is removed ────────
    status, opened = fn("open_phase", {"roomId": room_id, "phase": "opening"}, host)
    check("the opening round opens", status == 200, opened)
    living = sorted(r["seat"] for r in roster(room_id, host) if r["alive"])
    for seat in living:
        p = next(x for x in players if x["seat"] == seat)
        t = next(x for x in living if x != seat)
        fn("submit_accusation", {"roomId": room_id, "targetSeat": t}, p)
    check("the round closes into the discussion", state_of(room_id, host).get("phase") == "discuss", state_of(room_id, host).get("phase"))
    status, whispered = fn("send_whisper", {"roomId": room_id, "toSeat": c1["seat"], "body": "شكلك بريء"}, detective)
    check("the detective whispers to a seat", status == 200, whispered)
    before = whispers_to(room_id, detective, c1["id"])
    check("the whisper is on the graph, live", len(before) == 1 and before[0]["voided"] is False, before)
    status, beat = fn("heartbeat", {"roomId": room_id}, c1)
    check("the whispered-to seat is beating", status == 200, beat)
    status, refused = fn("remove_player", {"roomId": room_id, "seat": c1["seat"]}, host)
    check("a seat still beating cannot be struck for silence", refused.get("error") == "BAD_REQUEST", refused)
    status, refused = fn("remove_player", {"roomId": room_id, "seat": host["seat"]}, host)
    check("the host cannot strike itself", refused.get("error") == "BAD_REQUEST", refused)
    status, refused = fn("remove_player", {"roomId": room_id, "seat": c1["seat"]}, detective)
    check("...and only the host strikes", refused.get("error") == "NOT_HOST", refused)
    status, gone = fn("set_presence", {"roomId": room_id, "status": "left"}, c1)
    check("the whispered-to seat leaves", status == 200, gone)
    status, removal = fn("remove_player", {"roomId": room_id, "seat": c1["seat"]}, host)
    check("the host strikes the absent seat mid-day", status == 200 and removal.get("removed") == c1["seat"]
          and removal.get("outcome") is None, removal)
    status, twice = fn("remove_player", {"roomId": room_id, "seat": c1["seat"]}, host)
    check("...never twice", twice.get("error") == "BAD_REQUEST", twice)
    after = whispers_to(room_id, detective, c1["id"])
    check("the whisper to the removed seat is voided", len(after) == 1 and after[0]["voided"] is True, after)
    pd = public_data(room_id, host)
    check("the removal is a neutral day-1 elimination", (pd.get("eliminations") or {}).get(str(c1["seat"])) == {"phase": "day", "number": 1},
          pd.get("eliminations"))
    check("three living, one Mafia: no outcome invented", pd.get("outcome") is None, pd.get("outcome"))
    status, ballot = fn("submit_vote", {"roomId": room_id, "targetSeat": mafia["seat"], "round": 1, "actionId": aid()}, c1)
    check("the struck seat cannot vote", ballot.get("error") in ("NOT_ALIVE", "PHASE_CLOSED"), ballot)

    # ── the ballot and the result ────────────────────────────────────────
    status, opened = fn("open_phase", {"roomId": room_id, "phase": "vote"}, host)
    check("the ballot opens", status == 200, opened)
    # The host can be a citizen, so c1 above can be the doctor. Vote with the
    # actual survivors, not roles assumed to have survived a random deal.
    alive_seats = {row["seat"] for row in roster(room_id, host) if row["alive"]}
    town_voters = [p for p in players if p["seat"] in alive_seats and p["role"] != "mafia"]
    check("the ballot has exactly two living town voters", len(town_voters) == 2, alive_seats)
    for p in town_voters:
        status, ballot = fn("submit_vote", {"roomId": room_id, "targetSeat": mafia["seat"], "round": 1, "actionId": aid()}, p)
        check("seat %d votes" % p["seat"], status == 200, ballot)
    status, ballot = fn("submit_vote", {"roomId": room_id, "targetSeat": town_voters[0]["seat"], "round": 1, "actionId": aid()}, mafia)
    check("the Mafia votes", status == 200, ballot)
    status, verdict = fn("resolve_vote", {"roomId": room_id}, host)
    check("the town votes the Mafia out and wins", status == 200 and verdict.get("outcome") == "town", verdict)
    status, result = fn("open_phase", {"roomId": room_id, "phase": "result"}, host)
    check("the result opens", status == 200, result)
    pd = public_data(room_id, host)
    standings = pd.get("standings") or []
    check("standings name the five dealt seats and not seat 4", sorted(x["seat"] for x in standings) == [0, 1, 2, 3, 5],
          [x.get("seat") for x in standings])
    for p, phase, number in ((c2, "night", 1), (c1, "day", 1), (mafia, "day", 1)):
        row = next((x for x in standings if x["seat"] == p["seat"]), None)
        check("seat %d stands with role %s, out on %s %d" % (p["seat"], p["role"], phase, number),
              row is not None and row.get("role") == p["role"] and row.get("eliminatedPhase") == phase and row.get("eliminatedNumber") == number, row)
    check("the pre-deal removal has no elimination record and no standing", str(4) not in (pd.get("eliminations") or {}) and
          not any(x["seat"] == 4 for x in standings), (pd.get("eliminations"), standings))
    check("the outcome is the town's, computed from the dealt population", pd.get("outcome") == "town", pd.get("outcome"))
    check("the saved settings survived the whole match", (room_settings(room_id, host).get("settings") or {}).get("voice") is False)
    status, back = fn("join_room", {"code": code, "name": "Enas"}, enas)
    check("the pre-deal removal stays barred after the result", back.get("error") in ("NOT_A_MEMBER", "ROOM_FINISHED"), back)

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
