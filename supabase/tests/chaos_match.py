#!/usr/bin/env python3
"""Whole online matches on the real server, played by unpredictable people.

Each match is drawn from a seed: 5 to 10 players from the bot pool, a legal
deal over every role the server knows, random room settings, and at every
moment each player may do the right thing, the wrong thing, the same thing
twice, nothing (the real clock then decides), act while dead or removed, act
in the wrong phase, send garbage, leave, or be kicked. After every step the
invariants are checked through each bot's own client view.

  I1  no call answers 5xx
  I2  the dead, the removed and strangers are refused every game move
  I3  a client never reads another seat's role before the result
  I4  my_team names teammates to the Mafia team only, and only the Mafia team
  I5  every match reaches its result
  I6  the outcome agrees with who is alive
  I7  the result's standings name every dealt seat

Run through the controller (bot-owned rooms only, sessions in memory):
  python supabase/tests/run_live_suite.py --only=chaos_match
  CHAOS_MATCHES=6 CHAOS_SEED=11 python supabase/tests/run_live_suite.py --only=chaos_match
"""
import os
import random
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import e2e_match as h  # noqa: E402

fn, rest, check, aid = h.fn, h.rest, h.check, h.aid
MATCHES = int(os.environ.get('CHAOS_MATCHES', '4'))
SEED = int(os.environ.get('CHAOS_SEED', '20261109'))
MAX_STEPS = 120
TEAM = {'mafia', 'silencer'}
MOVE = {'mafia': 'kill', 'silencer': 'silence', 'doctor': 'protect',
        'detective': 'investigate', 'sniper': 'suspect'}


def draw_roles(r, n):
    team = r.randint(1, max(1, min(3, (n + 1) // 2 - 1)))
    silencer = 1 if team >= 2 and r.random() < 0.5 else 0
    roles = {'mafia': team - silencer, 'silencer': silencer}
    left = n - team
    for role in ('doctor', 'detective', 'elder', 'sniper'):
        if (role == 'elder' and n < 6) or (role == 'sniper' and n < 7):
            continue  # the server's own minimum tables
        if left > 1 and r.random() < (0.85 if role in ('doctor', 'detective') else 0.45):
            roles[role] = 1
            left -= 1
    roles['citizen'] = left
    return {k: v for k, v in roles.items() if v}


class Chaos:
    def __init__(self, seed, bots):
        self.r = random.Random(seed)
        self.seed = seed
        n = self.r.randint(5, min(10, len(bots)))
        self.players = [dict(b) for b in self.r.sample(bots, n)]
        self.problems, self.trace, self.steps = [], [], 0
        self.settings = {'openingRoundEnabled': self.r.random() < 0.5,
                         'discussionSeconds': 180, 'confrontationEnabled': False}
        self.roles = draw_roles(self.r, n)
        # A special role is dealt only when its switch is on (start_match).
        self.settings.update({'silencerEnabled': 'silencer' in self.roles, 'elderEnabled': 'elder' in self.roles,
                              'sniperEnabled': 'sniper' in self.roles})

    # ── calls ────────────────────────────────────────────────────────────────
    def call(self, name, p, **body):
        status, data = fn(name, dict(roomId=self.room, **body), p)
        code = data.get('error') if isinstance(data, dict) else None
        self.trace = (self.trace + ['%s seat %s -> %s %s' % (name, p.get('seat'), status, code or '')])[-40:]
        if status >= 500:
            self.problems.append('I1 %s answered %s %s' % (name, status, code))
        return status, data

    def state(self):
        status, rows = rest('room_state?select=phase,phase_number,phase_ends_at,public_data,active_speaker&room_id=eq.' + self.room, self.host)
        return rows[0] if status == 200 and rows else {}

    def seats(self):
        status, rows = rest('room_players_public?select=seat,alive,kicked,user_id&room_id=eq.' + self.room, self.host)
        return rows if status == 200 else []

    def living(self):
        alive = {x['seat'] for x in self.seats() if x['alive'] and not x.get('kicked')}
        return [p for p in self.players if p.get('seat') in alive and not p.get('gone')]

    def wild_seat(self):
        live = self.living()
        if live and self.r.random() < 0.65:
            return self.r.choice(live)['seat']
        return self.r.choice([p['seat'] for p in self.players] + [-1, 42, None])

    def wait_clock(self):
        """Let the real clock run out, then ask the server to move on."""
        st = self.state()
        ends = st.get('phase_ends_at')
        if ends:
            import calendar
            deadline = calendar.timegm(time.strptime(ends[:19], '%Y-%m-%dT%H:%M:%S'))
            pause = max(0, min(130, deadline - time.time() + 8))  # this laptop's clock runs ~5 s ahead
            time.sleep(pause)
        self.call('advance_phase', self.r.choice(self.living() or self.players))

    # ── setup ────────────────────────────────────────────────────────────────
    def start(self):
        self.host = self.players[0]
        status, room = fn('create_room', {'name': 'Chaos', 'visibility': 'private',
                                          'settings': dict(self.settings, maxPlayers=15)}, self.host)
        if status == 403 and isinstance(room, dict) and room.get('error') == 'PURCHASE_REQUIRED':
            # The bots own no paid role (the server is right to refuse): the
            # same table with the base roles. Paid roles are covered by the
            # new_roles / hosted_night_tools suites with an owning account.
            extra = sum(self.roles.pop(k, 0) for k in ('elder', 'sniper'))
            self.roles['mafia'] = self.roles.get('mafia', 0) + self.roles.pop('silencer', 0)
            self.roles['citizen'] = self.roles.get('citizen', 0) + extra
            self.settings.update({'silencerEnabled': False, 'elderEnabled': False, 'sniperEnabled': False})
            status, room = fn('create_room', {'name': 'Chaos', 'visibility': 'private',
                                              'settings': dict(self.settings, maxPlayers=15)}, self.host)
        check('chaos %d: create' % self.seed, status == 200, room)
        self.room, code = room['roomId'], room['code']
        self.host['seat'] = 0
        self.stop = threading.Event()

        def beats():
            while not self.stop.wait(15):
                for p in list(self.players):
                    if p.get('seat') is not None and not p.get('gone'):
                        fn('heartbeat', {'roomId': self.room}, p)
        threading.Thread(target=beats, daemon=True).start()
        for p in self.players[1:]:
            status, joined = fn('join_room', {'code': code, 'name': 'Bot'}, p)
            check('chaos %d: join' % self.seed, status == 200, joined)
            p['seat'] = joined.get('seat')
        h.ready_lobby(self.room, self.players)
        status, started = self.call('start_match', self.host, roles=self.roles, settings=self.settings)
        check('chaos %d: start %s' % (self.seed, self.roles), status == 200, started)
        for p in self.players:
            p['role'] = self.call('my_team', p)[1].get('role')

    # ── disruptions ──────────────────────────────────────────────────────────
    def disrupt(self):
        r = self.r
        live = self.living()
        # Out by the server's roster (dead or removed). A seat that walked out
        # keeps its chair for 90 s so it can come back (owner rule 2026-10-30),
        # so 'gone' alone does not make it out.
        seated = {x['seat'] for x in self.seats() if x['alive'] and not x.get('kicked')}
        out = [p for p in self.players if p.get('seat') not in seated]
        if out and r.random() < 0.3:
            ghost = r.choice(out)
            name, body = r.choice([
                ('submit_vote', {'targetSeat': self.wild_seat(), 'round': 1, 'actionId': aid()}),
                ('submit_night_action', {'action': 'kill', 'targetSeat': self.wild_seat(), 'actionId': aid()}),
                ('submit_accusation', {'targetSeat': self.wild_seat()}),
            ])
            status, _ = self.call(name, ghost, **body)
            if status == 200:
                self.problems.append('I2 %s accepted from seat %s, who is out' % (name, ghost['seat']))
        if r.random() < 0.08 and live:
            self.call(r.choice(['submit_vote', 'submit_night_action', 'open_phase', 'resolve_vote']),
                      r.choice(live), **r.choice([{}, {'targetSeat': 'x'}, {'phase': 'nowhere'}]))
        if len(live) > 4 and r.random() < 0.03:
            victim = r.choice([p for p in live if p is not self.host])
            if r.random() < 0.5:
                self.call('leave_room', victim)
            else:
                self.call('kick_player', self.host, seat=victim['seat'])
            victim['gone'] = True

    # ── one step ─────────────────────────────────────────────────────────────
    def step(self):
        r = self.r
        st = self.state()
        phase = st.get('phase')
        live = self.living()
        anyone = lambda: r.choice(live or self.players)  # noqa: E731
        self.disrupt()
        if phase == 'reveal':
            for p in self.players:
                if r.random() < 0.92:
                    self.call('saw_role', p)
            if self.call('open_phase', self.host, phase='night')[0] != 200:
                self.wait_clock()
        elif phase == 'night':
            for p in live:
                if r.random() > 0.9:
                    continue  # this one never answers: the clock decides
                move = MOVE.get(p['role'], 'suspect') if r.random() < 0.9 else r.choice(['kill', 'protect', 'skip'])
                body = {'action': move, 'targetSeat': self.wild_seat(), 'actionId': aid()}
                if p['role'] == 'sniper' and r.random() < 0.3:
                    body['useBullet'] = True
                self.call('submit_night_action', p, **body)
                if r.random() < 0.1:
                    self.call('submit_night_action', p, **body)
            if self.call('resolve_night', anyone())[0] != 200:
                self.wait_clock()
                self.call('resolve_night', anyone())
        elif phase == 'morning':
            nxt = 'result' if (st.get('public_data') or {}).get('outcome') else r.choice(['opening', 'discuss'])
            if self.call('open_phase', self.host, phase=nxt)[0] != 200:
                self.wait_clock()
        elif phase == 'opening':
            # The round's floor is public_data.openingSeat, not active_speaker.
            floor = (st.get('public_data') or {}).get('openingSeat')
            speaker = next((p for p in live if p['seat'] == floor), None)
            if speaker and r.random() < 0.8:
                self.call('submit_accusation', speaker, targetSeat=self.wild_seat())
            else:
                self.wait_clock()
        elif phase == 'discuss':
            everyone = r.random() < 0.75
            for p in live:
                if everyone or r.random() < 0.5:
                    self.call('ready_to_vote', p, ready=True)
            if r.random() < 0.15 and len(live) > 1:
                a, b = r.sample(live, 2)
                self.call('send_whisper', a, toSeat=b['seat'], body='انا شاكك فيه')
            if self.state().get('phase') == 'discuss':
                self.wait_clock()
        elif phase == 'vote':
            rnd = int(((st.get('public_data') or {}).get('revote') or {}).get('round') or 1)
            for p in live:
                if r.random() > 0.9:
                    continue
                body = {'targetSeat': self.wild_seat(), 'round': rnd, 'actionId': aid()}
                self.call('submit_vote', p, **body)
                if r.random() < 0.1:
                    self.call('submit_vote', p, **body)
            if self.call('resolve_vote', anyone())[0] != 200:
                self.wait_clock()
                self.call('resolve_vote', anyone())
        elif phase == 'verdict':
            nxt = 'result' if (st.get('public_data') or {}).get('outcome') else 'night'
            if self.call('open_phase', self.host, phase=nxt)[0] != 200:
                self.wait_clock()
        else:
            self.wait_clock()

    # ── invariants ───────────────────────────────────────────────────────────
    def check_privacy(self, st):
        if st.get('phase') == 'result':
            return
        viewer = self.r.choice(self.players)
        status, rows = rest('room_players?select=seat,role&room_id=eq.' + self.room, viewer)
        if status == 200 and any(x.get('role') and x.get('seat') != viewer.get('seat') for x in rows or []):
            self.problems.append('I3 seat %s read another role in %s' % (viewer['seat'], st.get('phase')))
        payload = str(st.get('public_data') or {})
        if "'standings'" in payload:
            self.problems.append('I3 standings published in %s' % st.get('phase'))
        if self.r.random() < 0.25:
            p = self.r.choice(self.players)
            status, mine = self.call('my_team', p)
            if status == 200:
                mates = mine.get('teammates') or []
                if mine.get('role') not in TEAM and mates:
                    self.problems.append('I4 teammates told to a %s' % mine.get('role'))

    def check_outcome(self, st):
        outcome = (st.get('public_data') or {}).get('outcome')
        if not outcome:
            return
        live = self.living()
        team = sum(1 for p in live if p['role'] in TEAM)
        rest_ = len(live) - team
        if outcome == 'town' and team > 0:
            self.problems.append('I6 town won with %d Mafia alive' % team)
        if outcome == 'mafia' and team < rest_:
            self.problems.append('I6 Mafia won while outnumbered %d:%d' % (team, rest_))

    def play(self):
        self.start()
        try:
            st = self.state()
            while st.get('phase') != 'result' and self.steps < MAX_STEPS and not self.problems:
                self.steps += 1
                self.step()
                st = self.state()
                self.check_privacy(st)
                self.check_outcome(st)
            if st.get('phase') != 'result':
                self.problems.append('I5 no result after %d steps (in %s %s)' % (self.steps, st.get('phase'), st.get('phase_number')))
            else:
                standings = (st.get('public_data') or {}).get('standings') or []
                dealt = sum(self.roles.values())
                if standings and len(standings) != dealt:
                    self.problems.append('I7 standings name %d of %d' % (len(standings), dealt))
        finally:
            self.stop.set()
        return st


def main():
    bots = [h.anon_session('LiveBot%d' % i) for i in range(12)]
    for i in range(MATCHES):
        seed = SEED + i
        game = Chaos(seed, bots)
        st = game.play()
        label = 'chaos %d (%d players, %s, opening=%s): ' % (
            seed, len(game.players), game.roles, game.settings['openingRoundEnabled'])
        check(label + 'clean in %d steps, outcome %s' % (game.steps, (st.get('public_data') or {}).get('outcome')),
              not game.problems, game.problems + game.trace[-15:])
        for problem in game.problems:
            check(label + problem, False)


if __name__ == '__main__':
    main()
