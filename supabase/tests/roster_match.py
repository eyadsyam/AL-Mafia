"""Seats, capacity and standings against the hosted functions — the roster
half of section B and the settings gap of section C.

What a removed seat is, from every angle that counts seats:

  * a lobby kick keeps the row (the removed client still needs its message)
    but the row is not a seat: the door, the public list, the deal and the
    result all ignore it, and they all agree with each other
  * kick and join can repeat; the replacement takes a fresh seat number
  * a join racing a start ends in one of two consistent worlds, never a third
  * room settings are refused by the host check, the lobby check and the
    seated population, and a settings write merges instead of replacing
  * a match that had a pre-deal removal reaches its result with standings that
    name the dealt players only, while a participant removed after the deal
    keeps the role history the result is entitled to show

    SUPABASE_URL=... SUPABASE_ANON_KEY=... python supabase/tests/roster_match.py
"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0] if "/" in __file__ else __file__.rsplit("\\", 1)[0])
from concurrency_match import ROLES, SETTINGS, deal, make_room, parallel, state_of  # noqa: E402
from e2e_match import KEY, URL, PASS, FAIL, aid, anon_session, check, drop_minted_users, fn, rest  # noqa: E402


def roster(room_id, player):
    status, rows = rest("room_players_public?select=seat,name,status,alive,kicked&room_id=eq." + room_id + "&order=seat", player)
    return rows if status == 200 else []


def seated(room_id, player):
    return [r for r in roster(room_id, player) if not r["kicked"]]


def public_count(code, player):
    status, listing = fn("browse_rooms", {}, player)
    for row in (listing or {}).get("rooms", []):
        if row.get("code") == code:
            return row.get("players")
    return None


def room_settings(room_id, player):
    status, rows = rest("rooms_public?select=settings,visibility,title,status&id=eq." + room_id, player)
    return rows[0] if status == 200 and rows else {}


def play_to_result(players, room_id, kick_after_deal=None):
    """Night 1 kills a citizen, day 1 votes the Mafia out; returns standings."""
    parallel([lambda p=p: fn("open_phase", {"roomId": room_id, "phase": "night"}, p) for p in players[:2]])
    by_role = {}
    for p in players:
        by_role.setdefault(p["role"], []).append(p)
    mafia, doctor, detective = by_role["mafia"][0], by_role["doctor"][0], by_role["detective"][0]
    citizens = by_role["citizen"]
    fn("submit_night_action", {"roomId": room_id, "action": "kill", "targetSeat": citizens[0]["seat"], "actionId": aid()}, mafia)
    fn("submit_night_action", {"roomId": room_id, "action": "protect", "targetSeat": citizens[1]["seat"], "actionId": aid()}, doctor)
    fn("submit_night_action", {"roomId": room_id, "action": "investigate", "targetSeat": mafia["seat"], "actionId": aid()}, detective)
    for c in citizens:
        fn("submit_night_action", {"roomId": room_id, "action": "suspect", "targetSeat": mafia["seat"], "actionId": aid()}, c)
    status, morning = fn("resolve_night", {"roomId": room_id}, players[0])
    check("night one resolves", status == 200, morning)
    if kick_after_deal is not None:
        status, kicked = fn("kick_player", {"roomId": room_id, "seat": kick_after_deal["seat"]}, players[0])
        check("host removes a dealt participant mid-match", status == 200, kicked)
    fn("open_phase", {"roomId": room_id, "phase": "opening"}, players[0])
    living = sorted(r["seat"] for r in roster(room_id, players[0]) if r["alive"])
    for seat in living:
        p = next(x for x in players if x["seat"] == seat)
        t = next(x for x in living if x != seat)
        fn("submit_accusation", {"roomId": room_id, "targetSeat": t}, p)
    fn("open_phase", {"roomId": room_id, "phase": "vote"}, players[0])
    for p in players:
        if p["seat"] in living and p is not mafia:
            status, ballot = fn("submit_vote", {"roomId": room_id, "targetSeat": mafia["seat"], "round": 1, "actionId": aid()}, p)
            if p is kick_after_deal:
                check("a participant removed mid-match cannot vote", status != 200, ballot)
    status, verdict = fn("resolve_vote", {"roomId": room_id}, players[0])
    check("the town votes the Mafia out", status == 200 and verdict.get("outcome") == "town", verdict)
    status, result = fn("open_phase", {"roomId": room_id, "phase": "result"}, players[0])
    check("the result opens", status == 200, result)
    s = state_of(room_id, players[0])
    return (s.get("public_data") or {}), mafia, living


def main():
    if not KEY:
        raise SystemExit("set SUPABASE_ANON_KEY")
    print("server: " + URL)

    # ── settings under the lock ──────────────────────────────────────────
    # Every later session is minted here, before the room exists: a lobby
    # whose members have all been silent for ninety seconds is given up
    # (`lobby_departures`), and a sign-in that waits out the hosted rate
    # limit takes longer than that.
    sixth = anon_session("Farah")
    ghali = anon_session("Ghali")
    newcomers = [anon_session("Cycle%d" % cycle) for cycle in range(2)]
    racer = anon_session("Racer")
    players, room_id, code = make_room(["Amina", "Bassem", "Camelia", "Dawoud", "Enas"])
    host = players[0]
    status, refused = fn("room_settings", {"roomId": room_id, "visibility": "public"}, players[1])
    check("a guest cannot change the room", refused.get("error") == "NOT_HOST", refused)
    status, changed = fn("room_settings", {"roomId": room_id, "visibility": "public", "settings": {"voice": False}}, host)
    check("the host makes it public and turns voice off", status == 200 and changed.get("changed") is True, changed)
    status, changed = fn("room_settings", {"roomId": room_id, "settings": {"maxPlayers": 5}}, host)
    check("capacity 5 with five seated is accepted", status == 200, changed)
    cfg = room_settings(room_id, host)
    check("a settings write merges: voice stayed off when capacity changed",
          cfg.get("visibility") == "public" and (cfg.get("settings") or {}).get("voice") is False
          and (cfg.get("settings") or {}).get("maxPlayers") == 5, cfg)
    status, refused = fn("room_settings", {"roomId": room_id, "settings": {"maxPlayers": 7}}, host)
    check("an off-list capacity is refused", refused.get("error") == "BAD_REQUEST", refused)
    status, full = fn("join_room", {"code": code, "name": "Farah"}, sixth)
    check("a sixth join hits the capacity", full.get("error") == "ROOM_FULL", full)
    check("the public list counts five", public_count(code, sixth) == 5, public_count(code, sixth))

    # ── kick / join cycles keep every count in step ──────────────────────
    status, kicked = fn("kick_player", {"roomId": room_id, "seat": 4}, host)
    check("host removes seat 4 in the lobby", status == 200, kicked)
    rows = roster(room_id, host)
    check("the removed row stays for its own client, marked", any(r["seat"] == 4 and r["kicked"] for r in rows), rows)
    check("...but the seated population is four", len(seated(room_id, host)) == 4, rows)
    check("...and the public list says four", public_count(code, sixth) == 4, public_count(code, sixth))
    status, refused = fn("room_settings", {"roomId": room_id, "settings": {"maxPlayers": 5}}, host)
    check("capacity 5 with four seated (one removed) is accepted", status == 200, refused)
    status, joined = fn("join_room", {"code": code, "name": "Farah"}, sixth)
    check("the freed capacity admits somebody else", status == 200, joined)
    check("...on a fresh seat number, not the removed one", joined.get("seat") not in (None, 4), joined)
    sixth["seat"] = joined.get("seat")
    players[4] = sixth
    check("seated population is five again", len(seated(room_id, host)) == 5, roster(room_id, host))
    status, full = fn("join_room", {"code": code, "name": "Ghali"}, ghali)
    check("...and the door is shut at five, removed row not counted", full.get("error") == "ROOM_FULL", full)
    for cycle in range(2):
        seat = players[4]["seat"]
        status, kicked = fn("kick_player", {"roomId": room_id, "seat": seat}, host)
        newcomer = newcomers[cycle]
        status, joined = fn("join_room", {"code": code, "name": "Cycle%d" % cycle}, newcomer)
        ok = status == 200 and joined.get("seat") not in {r["seat"] for r in roster(room_id, host) if r["kicked"]}
        check("cycle %d: kick then join lands on a fresh seat" % cycle, ok, joined)
        newcomer["seat"] = joined.get("seat")
        players[4] = newcomer
    rows = roster(room_id, host)
    check("after the cycles: three removed rows, five seated, list says five",
          sum(1 for r in rows if r["kicked"]) == 3 and len(seated(room_id, host)) == 5 and public_count(code, host) == 5, rows)
    status, refused = fn("room_settings", {"roomId": room_id, "settings": {"maxPlayers": 5}}, host)
    check("capacity 5 still accepted with three removed rows present", status == 200, refused)

    # ── join racing start ────────────────────────────────────────────────
    status, changed = fn("room_settings", {"roomId": room_id, "settings": {"maxPlayers": 8}}, host)
    check("capacity raised to 8 for the race", status == 200, changed)
    results = parallel([
        lambda: fn("start_match", {"roomId": room_id, "roles": ROLES, "settings": SETTINGS}, host),
        lambda: fn("join_room", {"code": code, "name": "Racer"}, racer),
    ])
    (s_status, started), (j_status, joined) = results
    worlds = {
        "start won": s_status == 200 and joined.get("error") == "PHASE_CLOSED",
        "join won": j_status == 200 and started.get("error") == "BAD_REQUEST",
    }
    check("start vs join ends in exactly one consistent world: " + (next((k for k, v in worlds.items() if v), "neither")),
          sum(worlds.values()) == 1, (started, joined))
    if worlds["join won"]:
        # six seated now; the roles must sum to six for the start to go
        racer["seat"] = joined.get("seat")
        players.append(racer)
        roles = dict(ROLES, citizen=3)
    else:
        roles = ROLES
    if worlds["join won"]:
        status, started = fn("start_match", {"roomId": room_id, "roles": roles, "settings": SETTINGS}, host)
        check("start with the roster that raced in", status == 200, started)
    before = room_settings(room_id, host).get("settings")
    status, refused = fn("room_settings", {"roomId": room_id, "settings": {"voice": True}}, host)
    check("settings are refused once the cards are out", refused.get("error") == "PHASE_CLOSED", refused)
    check("...and nothing changed under the refusal", room_settings(room_id, host).get("settings") == before)
    s = state_of(room_id, host)
    dealt = sorted((s.get("public_data") or {}).get("rosterSeats") or [])
    check("rosterSeats is the seated population, no removed seat",
          dealt == sorted(p["seat"] for p in players) and 4 not in dealt, (dealt, [p["seat"] for p in players]))
    for p in players:
        status, mine = fn("my_team", {"roomId": room_id}, p)
        p["role"] = mine.get("role")
        fn("saw_role", {"roomId": room_id}, p)
    check("every seated player holds a role", all(p["role"] in ROLES for p in players), [p.get("role") for p in players])
    rows = roster(room_id, host)
    check("removed rows are not alive after the deal", all(not r["alive"] for r in rows if r["kicked"]), rows)
    check("seated rows are alive after the deal", all(r["alive"] for r in rows if not r["kicked"]), rows)

    # ── through to the result, with a mid-match removal ──────────────────
    victim_candidates = [p for p in players if p["role"] == "citizen"]
    archive, mafia, living = play_to_result(players, room_id, kick_after_deal=victim_candidates[-1])
    standings = archive.get("standings") or []
    seats_in_standings = sorted(x["seat"] for x in standings)
    check("standings name the dealt players and nobody removed before the deal",
          seats_in_standings == sorted(p["seat"] for p in players), (seats_in_standings, [p["seat"] for p in players]))
    check("every standing carries a real role", all(x.get("role") in ROLES for x in standings), standings)
    removed_after_deal = next((x for x in standings if x["seat"] == victim_candidates[-1]["seat"]), None)
    check("a participant removed after the deal keeps its role in the standings",
          removed_after_deal is not None and removed_after_deal.get("role") == "citizen", removed_after_deal)
    check("the outcome is the town's", archive.get("outcome") == "town", archive.get("outcome"))
    check("the living population at the vote excluded the night's victim and the removed seat, nobody else",
          len(living) == len(players) - 2 and victim_candidates[-1]["seat"] not in living, living)
    check("...the removal is recorded as a neutral day-1 elimination, no role in the record",
          removed_after_deal is not None and removed_after_deal.get("eliminatedPhase") == "day"
          and removed_after_deal.get("eliminatedNumber") == 1, removed_after_deal)
    elim = (archive.get("eliminations") or {}).get(str(victim_candidates[-1]["seat"]))
    check("...and the elimination record carries phase and number only", elim == {"phase": "day", "number": 1}, elim)
    status, beat = fn("heartbeat", {"roomId": room_id}, victim_candidates[-1])
    check("a removed participant's heartbeat is refused", beat.get("error") == "NOT_A_MEMBER", beat)
    rows = roster(room_id, host)
    check("the mid-match removal is marked, banned, and still listed on the roster",
          any(r["seat"] == victim_candidates[-1]["seat"] and r["kicked"] for r in rows), rows)
    status, back = fn("join_room", {"code": code, "name": "again"}, victim_candidates[-1])
    check("...and refused at the door", back.get("error") in ("NOT_A_MEMBER", "ROOM_FINISHED"), back)

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
