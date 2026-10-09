"""Live roles/tools regressions, using e2e_match's in-memory session pool.

Run through run_live_suite.py (loads dart_defines internally, never logs keys).
No deploys, deletes, or privileged match mutations. The sole SQL setup grants
coins to the exact anonymous bot IDs already authenticated by this process.
Reports store labels/codes only. Realtime messages remain in memory.
"""
import concurrent.futures
import datetime as dt
import json
import os
from pathlib import Path
import subprocess
import threading
import time
import uuid
import e2e_match as h

ROOT = Path(__file__).resolve().parents[2]
RESULTS, BOTS = {}, []
SETTINGS = dict(openingRoundEnabled=False, confrontationEnabled=False,
                whisperEnabled=False, traceEnabled=False, abstainAllowed=True,
                discussionMode='structured', discussionSeconds=180, maxPlayers=15)
ACTIVE = []


def record(label, good, detail=None):
    # Only predetermined labels and error codes are persisted.
    RESULTS[label] = {'status': 'PASS' if good else 'FAIL', 'code': detail}
    h.check(label, good)
    (ROOT / 'build/new_roles_tools_results.json').write_text(json.dumps(RESULTS, indent=2), encoding='utf-8')
    return good


def eco(p, action, **kw):
    return h.fn('economy', dict(action=action, **kw), p)


def accepted(label, response):
    status, data = response
    record(label, status == 200 and not data.get('error'), data.get('error'))
    return data


def refused(label, response, allowed):
    status, data = response
    return record(label, status >= 400 and data.get('error') in allowed, data.get('error'))


class Watch:
    """One authenticated Realtime socket per bot; no payloads logged."""
    def __init__(self, match, player):
        self.match, self.player = match, player
        self.events, self.joined, self.problem = 0, False, None
        self.ws = None
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.loop, daemon=True)
        self.thread.start()

    def loop(self):
        try:
            import websocket
            self.ws = websocket.create_connection(h.URL.replace('https:', 'wss:') +
                '/realtime/v1/websocket?apikey=' + h.KEY + '&vsn=1.0.0', timeout=2)
            topic = 'realtime:live-' + self.match.id + '-' + str(self.player['seat'])
            # Match the application's publication subscriptions. Subscribing
            # unpublished private tables in this channel disables delivery.
            tables = ['room_state', 'room_players', 'rooms', 'whisper_meta']
            self.ws.send(json.dumps(dict(topic=topic, event='phx_join', ref='1', payload={
                'access_token': self.player['token'], 'config': {
                    'broadcast': {'self': False}, 'presence': {'key': ''},
                    'postgres_changes': [dict(event='*', schema='public', table=t,
                        filter=('id' if t == 'rooms' else 'room_id') + '=eq.' + self.match.id) for t in tables]}})))
            last = time.monotonic()
            while not self.stop.is_set():
                try:
                    message = json.loads(self.ws.recv())
                    if message.get('event') == 'phx_reply' and message.get('ref') == '1':
                        self.joined = message.get('payload', {}).get('status') == 'ok'
                    if message.get('event') == 'postgres_changes':
                        self.events += 1
                        payload = message.get('payload', {}).get('data', {})
                        self.match.inspect(payload.get('record', {}), self.player, 'realtime:' + payload.get('table', ''))
                except websocket.WebSocketTimeoutException:
                    pass
                if time.monotonic() - last > 20:
                    self.ws.send(json.dumps(dict(topic='phoenix', event='heartbeat', payload={}, ref='2')))
                    last = time.monotonic()
        except Exception as e:
            self.problem = type(e).__name__
        finally:
            if self.ws:
                self.ws.close()

    def close(self):
        self.stop.set()
        self.thread.join(timeout=3)


class Match:
    def __init__(self, label, counts, host=None, flags=None, realtime=False):
        self.label, self.counts = label, counts
        self.players = [dict(p, seat=i) for i, p in enumerate(BOTS[:sum(counts.values())])]
        if host:
            self.players[0] = dict(host, seat=0)
        self.host = self.players[0]
        self.settings = dict(SETTINGS, **(flags or {}))
        self.leaks, self.responses, self.finished = set(), 0, False
        data = accepted(label + ': create', h.fn('create_room', {'name': 'LiveBot', 'visibility': 'private', 'settings': {'maxPlayers': 15}}, self.host))
        self.id, self.code = data['roomId'], data['code']
        ACTIVE.append(self)
        for p in self.players[1:]:
            data = accepted(label + ': join ' + str(p['seat']), h.fn('join_room', {'code': self.code, 'name': 'Bot' + str(p['seat'])}, p))
            p['seat'] = data['seat']
        self.watches = [Watch(self, p) for p in self.players] if realtime else []
        self.beat_stop = threading.Event()
        def beats():
            while not self.beat_stop.wait(20):
                with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
                    list(pool.map(lambda p: self.call('heartbeat', p), self.players))
        self.beat_thread = threading.Thread(target=beats, daemon=True)
        self.beat_thread.start()

    def inspect(self, data, p, source):
        self.responses += 1
        if isinstance(data, dict) and data.get('phase') == 'result':
            self.finished = True
        if self.finished:
            return
        def walk(obj, path):
            if isinstance(obj, dict):
                for key, value in obj.items():
                    if value is not None and key in ('role', 'revealedRole', 'eliminatedRole', 'victimRole'):
                        own = source == 'my_team' and key == 'role' and path == ''
                        if not own:
                            self.leaks.add(source + ':' + path + key)
                    if key == 'teammates' and value:
                        self.leaks.add(source + ':teammates')
                    if key == 'answer' and value is not None:
                        if source not in ('economy',) and obj.get('user_id') != p['id']:
                            self.leaks.add(source + ':privateAnswer')
                    walk(value, path + key + '.')
            elif isinstance(obj, list):
                for v in obj:
                    walk(v, path)
        walk(data, '')

    def call(self, name, p=None, **kw):
        p = p or self.host
        response = h.fn(name, dict(roomId=self.id, **kw), p)
        self.inspect(response[1], p, name)
        return response

    def state(self, p=None):
        p = p or self.host
        status, rows = h.rest('room_state?select=*&room_id=eq.' + self.id, p)
        if status != 200 or not rows:
            raise RuntimeError('STATE_UNAVAILABLE')
        self.inspect(rows[0], p, 'state')
        return rows[0]

    def alive(self):
        status, rows = h.rest('room_players_public?select=seat,alive&room_id=eq.' + self.id, self.host)
        seats = {r['seat'] for r in rows if r['alive']} if status == 200 else set()
        return [p for p in self.players if p['seat'] in seats]

    def start(self):
        h.ready_lobby(self.id, self.players)
        data = accepted(self.label + ': start', self.call('start_match', roles=self.counts, settings=self.settings))
        if not data.get('started'):
            raise RuntimeError('START_FAILED')
        for p in self.players:
            data = self.call('my_team', p)[1]
            p['role'] = data.get('role')
        record(self.label + ': correct deal', sorted(p['role'] for p in self.players) ==
               sorted(role for role, n in self.counts.items() for _ in range(n)))

    def reveal(self):
        for p in self.players:
            self.call('saw_role', p)
        self.call('open_phase', phase='night')

    def role(self, role):
        return next(p for p in self.players if p.get('role') == role)

    def night(self, kill=None, silence=None, shot=None, protect=None):
        alive = self.alive()
        for p in alive:
            role = p['role']
            action, target, bullet = 'skip', None, False
            if role == 'mafia' and kill is not None:
                action, target = 'kill', kill
            elif role == 'silencer' and silence is not None:
                action, target = 'silence', silence
            elif role == 'sniper' and shot is not None:
                action, target, bullet = 'suspect', shot, True
            elif role == 'doctor':
                action, target = 'protect', protect if protect is not None else next(x['seat'] for x in alive if x != p)
                bullet = target == p['seat']
            if role not in ('elder', 'citizen'):
                accepted(self.label + ': night action ' + str(self.state()['phase_number']) + ':' + role,
                    self.call('submit_night_action', p, action=action, targetSeat=target, useBullet=bullet, actionId=h.aid()))
        return accepted(self.label + ': resolve night ' + str(self.state()['phase_number']), self.call('resolve_night'))

    def discuss(self):
        self.call('open_phase', phase='discuss')

    def vote(self, target, ballots=None):
        self.call('open_phase', phase='vote')
        alive = self.alive()
        for p in alive:
            seat = ballots.get(p['seat']) if ballots is not None else (target if p['seat'] != target else None)
            self.call('submit_vote', p, targetSeat=seat, round=1, actionId=h.aid())
        return self.call('resolve_vote')[1]

    def finish_town(self):
        for _ in range(18):
            state = self.state()
            phase = state['phase']
            if phase == 'result':
                break
            if phase == 'verdict':
                if (state['public_data'].get('lastVote') or {}).get('outcome'):
                    self.call('open_phase', phase='result')
                else:
                    self.call('open_phase', phase='night')
            elif phase == 'morning':
                status, data = self.call('open_phase', phase='result')
                if status != 200:
                    self.discuss()
            elif phase == 'night':
                self.night()
            elif phase == 'discuss':
                enemies = [p for p in self.alive() if p['role'] in ('mafia', 'silencer')]
                if enemies:
                    self.vote(enemies[0]['seat'])
            else:
                break
        # More than one enemy can need more than five transitions.
        if self.state()['phase'] == 'verdict':
            self.call('open_phase', phase='result')
        reached = [self.state(p)['phase'] == 'result' for p in self.players]
        record(self.label + ': everyone reaches result', all(reached))

    def close(self):
        self.beat_stop.set()
        for w in self.watches:
            w.close()
        if self.watches:
            record(self.label + ': realtime delivered to every bot', all(w.joined and w.events for w in self.watches),
                   [{'seat': w.player['seat'], 'joined': w.joined, 'events': w.events, 'error': w.problem} for w in self.watches])
        record(self.label + ': strict pre-result role privacy', not self.leaks, sorted(self.leaks))
        self.call('close_room')


def setup_coins():
    ids = [str(uuid.UUID(p['id'])) for p in BOTS[:-1]]
    sql = "begin;\ndo $$ declare u uuid; begin\n"
    sql += "foreach u in array array[" + ','.join("'%s'::uuid" % x for x in ids) + "] loop\n"
    sql += "if not exists(select 1 from auth.users where id=u and is_anonymous) then raise exception 'NOT_TEST_ANON'; end if;\n"
    sql += "perform pg_advisory_xact_lock(hashtextextended('wallet:'||u::text,91));\n"
    sql += "perform public.credit_earned(u,'operator_adjustment',100000,null,'live-bots-20261009');\n"
    sql += "end loop; end $$;\ncommit;\n"
    path = ROOT / 'build/live_bot_coin_setup.sql'
    path.write_text(sql, encoding='utf-8')
    # Capture CLI output privately: never echo credentials or connection strings.
    cmd = ['npx.cmd' if os.name == 'nt' else 'npx', 'supabase', 'db', 'query', '--linked', '-f', str(path)]
    done = subprocess.run(cmd, cwd=ROOT, capture_output=True, timeout=120)
    record('coin setup via linked SQL', done.returncode == 0, None if done.returncode == 0 else 'CLI_FAILED')
    return done.returncode == 0


def ownership():
    poor = BOTS[-1]
    refused('insufficient coins', eco(poor, 'toolBuy', tool='appeal', pack=7, requestId=h.aid()), ['INSUFFICIENT_COINS'])
    m = Match('nonowner', dict(mafia=1, elder=1, citizen=4), host=poor)
    refused('nonowner room settings role', m.call('room_settings', settings={'elderEnabled': True}), ['PURCHASE_REQUIRED'])
    h.ready_lobby(m.id, m.players)
    refused('nonowner start body role', m.call('start_match', roles=m.counts,
            settings=dict(SETTINGS, elderEnabled=True)), ['PURCHASE_REQUIRED'])
    m.close()


def role_match(kind):
    counts = dict(mafia=1, doctor=1, detective=1, citizen=4)
    if kind == 'all':
        counts.update(silencer=1, elder=1, sniper=1)
    else:
        counts[kind] = 1
        if kind == 'sniper':
            counts['mafia'] = 2
    flags = {r + 'Enabled': True for r in ('silencer', 'elder', 'sniper') if counts.get(r)}
    m = Match(kind, counts, flags=flags, realtime=True)
    m.start()
    m.reveal()
    if counts.get('elder'):
        refused(kind + ': elder night reveal refused', m.call('reveal_elder', m.role('elder')), ['PHASE_CLOSED'])
    silenced = m.role('citizen')['seat'] if counts.get('silencer') else None
    shot = m.role('mafia')['seat'] if counts.get('sniper') else None
    m.night(silence=silenced, shot=shot, protect=shot)
    if shot is not None:
        record(kind + ': doctor cannot block sniper', shot not in [p['seat'] for p in m.alive()])
    m.discuss()
    if counts.get('elder'):
        elder = m.role('elder')
        accepted(kind + ': elder reveal', m.call('reveal_elder', elder))
        refused(kind + ': citizen cannot reveal elder', m.call('reveal_elder', m.role('citizen')), ['WRONG_ROLE'])
    if silenced is not None:
        p = next(p for p in m.players if p['seat'] == silenced)
        data = m.call('claim_floor', p)[1]
        record(kind + ': silenced cannot speak', data.get('granted') is False and data.get('reason') == 'silenced')
        m.call('open_phase', phase='vote')
        refused(kind + ': silenced cannot vote', m.call('submit_vote', p, targetSeat=m.role('doctor')['seat'], round=1, actionId=h.aid()), ['WRONG_ROLE'])
        voter = next(x for x in m.alive() if x['seat'] not in (0, silenced))
        accepted(kind + ': silenced can be voted', m.call('submit_vote', voter, targetSeat=silenced, round=1, actionId=h.aid()))
        # Overwrite that ballot, then eliminate the killer so the Silencer inherits.
        mafia = next((x for x in m.alive() if x['role'] == 'mafia'), None)
        target = mafia['seat'] if mafia else silenced
        m.vote(target)
    else:
        m.vote(next(p['seat'] for p in m.alive() if p['role'] == 'mafia'))
    m.call('open_phase', phase='night')
    if m.state()['phase'] == 'night':
        if counts.get('sniper'):
            sniper = m.role('sniper')
            target = next(p['seat'] for p in m.alive() if p != sniper)
            refused(kind + ': sniper bullet once per match', m.call('submit_night_action', sniper,
                action='suspect', targetSeat=target, useBullet=True, actionId=h.aid()), ['RATE_LIMITED'])
        if counts.get('silencer') and not any(p['role'] == 'mafia' for p in m.alive()):
            victim = next(p for p in m.alive() if p['role'] == 'citizen')
            morning = m.night(silence=victim['seat'], protect=m.role('silencer')['seat'])
            record(kind + ': lone silencer inherits kill', victim['seat'] not in [p['seat'] for p in m.alive()])
        else:
            m.night()
    m.finish_town()
    m.close()


def tools_match():
    m = Match('tools', dict(mafia=2, doctor=1, citizen=7), realtime=True)
    m.start()
    catalog = accepted('17-tool catalog', eco(m.host, 'toolsGet')).get('tools', [])
    record('all 17 tools listed', len(catalog) == 17)
    # Assign at most four tools and at most two heavy tools to each owner.
    allocations = {}
    live_owners = m.players[1:7]
    victim = next(p for p in m.players[7:] if p['role'] == 'citizen')
    i = 0
    for tool in catalog:
        p = victim if tool['phase'] == 'dead' else live_owners[i % len(live_owners)]
        if tool['phase'] != 'dead':
            i += 1
        code = tool['code']
        allocations[code] = (p, tool)
        request = h.aid()
        first = accepted('buy ' + code, eco(p, 'toolBuy', tool=code, pack=3, requestId=request))
        second = accepted('buy replay ' + code, eco(p, 'toolBuy', tool=code, pack=3, requestId=request))
        record('idempotent purchase ' + code, first.get('balance') == second.get('balance') and first.get('tools') == second.get('tools'))
        refused('wrong phase ' + code, m.call('economy', p, action='toolUse', tool=code,
                targets=[], note='bot test'), ['WRONG_PHASE', 'ALIVE'])
    m.reveal()
    for code, (p, tool) in allocations.items():
        if tool['phase'] == 'night':
            targets = [x['seat'] for x in m.players if x != p][:tool['targets']]
            refused('bad targets ' + code, m.call('economy', p, action='toolUse', tool=code, targets=[p['seat']] * tool['targets']), ['BAD_TARGETS'])
            result = accepted('use ' + code, m.call('economy', p, action='toolUse', tool=code, targets=targets))
            expected = any(x['role'] in ('mafia', 'silencer') and x['seat'] in targets for x in m.players)
            record('truthful answer ' + code, result.get('answer') is expected)
            own = m.call('economy', p, action='toolAnswers')[1].get('answers', [])
            record('answer readback ' + code, any(a.get('tool') == code and a.get('answer') is expected for a in own))
            for other in m.players:
                if other != p:
                    rows = m.call('economy', other, action='toolAnswers')[1].get('answers', [])
                    record('answer isolated ' + code + ':' + str(other['seat']), not any(a.get('tool') == code for a in rows))
            refused('repeat phase ' + code, m.call('economy', p, action='toolUse', tool=code, targets=targets), ['LIMIT_TOOL', 'LIMIT_PHASE'])
    m.night(kill=victim['seat'], protect=m.role('mafia')['seat'])
    record('tools victim dead', victim['seat'] not in [p['seat'] for p in m.alive()])
    # The old witness contract deliberately exposes roles; strict audit catches it.
    m.call('witness_view', victim)
    m.discuss()
    for code, (p, tool) in allocations.items():
        if tool['phase'] == 'night':
            continue
        targets = [x['seat'] for x in m.alive() if x != p][:tool['targets']]
        note = 'citizen' if code == 'impersonate' else 'automated bot note'
        if tool['phase'] != 'dead':
            refused('dead use ' + code, m.call('economy', victim, action='toolUse', tool=code, targets=targets, note=note), ['NOT_ALIVE'])
        bad = [39] if not targets else [p['seat']] * len(targets)
        refused('bad targets ' + code, m.call('economy', p, action='toolUse', tool=code, targets=bad, note=note), ['BAD_TARGETS'])
        accepted('use ' + code, m.call('economy', p, action='toolUse', tool=code, targets=targets, note=note))
        refused('repeat phase ' + code, m.call('economy', p, action='toolUse', tool=code, targets=targets, note=note), ['LIMIT_TOOL', 'LIMIT_PHASE', 'LIMIT_MATCH'])
        if code in ('extra_minute', 'objection'):
            accepted('floor bonus claim ' + code, m.call('claim_floor', p))
            first = m.state().get('speaker_until')
            m.call('release_floor', p)
            m.call('claim_floor', p)
            second = m.state().get('speaker_until')
            record('floor bonus once ' + code, bool(first and second) and first > second)
            m.call('release_floor', p)
    m.call('open_phase', phase='vote')
    target = m.role('mafia')['seat']
    first_id = h.aid()
    accepted('grave first ballot', m.call('submit_vote', victim, targetSeat=target, round=1, actionId=first_id))
    refused('grave once per day', m.call('submit_vote', victim, targetSeat=target, round=1, actionId=h.aid()), ['RATE_LIMITED'])
    verdict = m.vote(target)
    record('revote tool with vote shield', verdict.get('revote') is True or m.state()['phase'] == 'vote')
    if m.state()['phase'] == 'vote':
        state = m.state()['public_data'].get('revote') or {}
        for p in m.alive():
            choice = next((s for s in state.get('tiedSeats', []) if s != p['seat']), None)
            m.call('submit_vote', p, targetSeat=choice, round=2, actionId=h.aid())
        m.call('resolve_vote')
    m.finish_town()
    m.close()


def main():
    global BOTS
    h._POOL_TAKEN[0] = 0
    BOTS = [h.anon_session('LiveBot%d' % i) for i in range(12)]
    ownership()
    if not setup_coins():
        record('roles/tools scenarios blocked by coin setup', False, 'NO_PRIVILEGED_SETUP')
        return
    for role in ('silencer', 'elder', 'sniper'):
        accepted('host buys ' + role, eco(BOTS[0], 'buy', item='role_' + role))
    for name, scenario in [('silencer', lambda: role_match('silencer')),
                           ('elder', lambda: role_match('elder')),
                           ('sniper', lambda: role_match('sniper')),
                           ('all', lambda: role_match('all')), ('tools', tools_match),
                           ('edges', edge_match), ('timers', timer_match)]:
        try:
            scenario()
        except Exception as e:
            record(name + ': scenario interrupted', False, type(e).__name__)
        finally:
            for m in ACTIVE:
                if m.label == name and hasattr(m, 'watches'):
                    for w in m.watches:
                        w.close()


def edge_match():
    m = Match('edges', dict(mafia=1, silencer=1, doctor=1, citizen=5),
              flags={'silencerEnabled': True}, realtime=True)
    m.start()
    m.reveal()
    dropped = m.role('citizen')
    before = m.call('my_team', dropped)[1]
    accepted('drop mid-night', m.call('set_presence', dropped, status='away'))
    data = accepted('reconnect mid-night', h.fn('join_room', {'code': m.code, 'name': 'RejoinedBot'}, dropped))
    record('reconnect retains seat and role', data.get('seat') == dropped['seat'] and m.call('my_team', dropped)[1].get('role') == before.get('role'))
    mafia = m.role('mafia')
    action = h.aid()
    first = m.call('submit_night_action', mafia, action='skip', actionId=action)
    second = m.call('submit_night_action', mafia, action='skip', actionId=action)
    record('replayed night action id', first[0] == second[0] == 200 and first[1].get('bulletSpent') == second[1].get('bulletSpent'))
    m.night()
    refused('night action after phase close', m.call('submit_night_action', mafia,
            action='skip', actionId=h.aid()), ['PHASE_CLOSED'])
    m.discuss()
    # Genuine mid-match departure, then restoration. No direct row mutations.
    old_host = m.host
    m.call('leave_room', old_host)
    status, rows = h.rest('rooms_public?select=host_id&id=eq.' + m.id, m.players[1])
    heir = next((p for p in m.players if rows and p['id'] == rows[0]['host_id']), None)
    record('host leaves mid-match and migrates', status == 200 and heir is not None and heir != old_host)
    if heir:
        m.host = heir
    h.fn('join_room', {'code': m.code, 'name': 'ReturnedHost'}, old_host)
    # Kick a town seat during discussion, preserving the special roles.
    kicked = next(p for p in m.players if p['role'] == 'citizen' and p != m.host)
    accepted('kick mid-day', m.call('kick_player', seat=kicked['seat']))
    refused('kicked cannot vote', m.call('submit_vote', kicked, targetSeat=mafia['seat'], actionId=h.aid()), ['NOT_A_MEMBER', 'PHASE_CLOSED'])
    m.call('open_phase', phase='vote')
    leaving = next(p for p in m.alive() if p['role'] == 'citizen' and p != m.host)
    accepted('player leaves during vote', m.call('leave_room', leaving))
    accepted('player returns during vote', h.fn('join_room', {'code': m.code, 'name': 'ReturnVote'}, leaving))
    m.vote(mafia['seat'])
    m.call('open_phase', phase='night')
    # Let the lone Silencer kill and vote down town until the last two.
    for _ in range(18):
        state = m.state()
        if state['phase'] == 'night':
            victims = [p for p in m.alive() if p['role'] not in ('mafia', 'silencer')]
            victim = next((p for p in victims if p['role'] == 'doctor'), victims[0])
            m.night(silence=victim['seat'], protect=m.role('silencer')['seat'])
        elif state['phase'] == 'morning':
            if state['public_data'].get('outcome'):
                m.call('open_phase', phase='result')
                break
            m.discuss()
        elif state['phase'] == 'discuss':
            victim = next(p for p in m.alive() if p['role'] not in ('mafia', 'silencer'))
            m.vote(victim['seat'])
        elif state['phase'] == 'verdict':
            if state['public_data'].get('outcome'):
                m.call('open_phase', phase='result')
                break
            m.call('open_phase', phase='night')
    state = m.state()
    record('mafia parity win', state['public_data'].get('outcome') == 'mafia')
    record('last two alive', len(m.alive()) == 2)
    silencer = m.role('silencer')
    data = accepted('silencer wallet result receipt', m.call('economy', silencer,
        action='resultSummary', requestId=h.aid()))
    # Read only this bot's own receipt, through its authenticated RLS surface.
    status, rows = h.rest('match_receipts?select=won,win_coins&room_id=eq.' + m.id + '&user_id=eq.' + silencer['id'], silencer)
    record('silencer receipt counts mafia win', status == 200 and bool(rows) and rows[0].get('won') is True,
           'RECEIPT_ABSENT_OR_NOT_READABLE' if not rows or status != 200 else None)
    record('remaining clients reach result', all(m.state(p)['phase'] == 'result' for p in m.players if p != kicked))
    m.close()


def timer_match():
    m = Match('timers', dict(mafia=1, doctor=1, citizen=3),
              flags={'openingRoundEnabled': True})
    m.start()
    seen = set()
    # No role acknowledgements, actions or votes. Only the recovery driver acts
    # after real server deadlines; no privileged clock manipulation.
    until = time.monotonic() + 850
    while time.monotonic() < until:
        state = m.state()
        phase = state['phase']
        end = state.get('phase_ends_at')
        if not end:
            record('timer has deadline ' + phase, False, 'NO_DEADLINE')
            break
        deadline = dt.datetime.fromisoformat(end.replace('Z', '+00:00')).timestamp()
        delay = deadline - time.time() + 1
        if delay > 0:
            time.sleep(min(delay, 15))
            continue
        guest = m.players[1]
        if phase in ('reveal', 'verdict'):
            response = m.call('open_phase', guest, phase='night')
        elif phase == 'morning':
            response = m.call('open_phase', guest, phase='opening')
        else:
            response = m.call('advance_phase', guest)
        record('timer expiry ' + phase, response[0] == 200, response[1].get('error'))
        seen.add(phase)
        if {'reveal', 'night', 'morning', 'opening', 'discuss', 'vote', 'verdict'} <= seen:
            break
    record('everyone AFK default cycle', {'reveal', 'night', 'morning', 'opening', 'discuss', 'vote', 'verdict'} <= seen)
    m.close()


if __name__ == '__main__':
    raise SystemExit('Use run_live_suite.py so all scenarios share sessions safely.')
