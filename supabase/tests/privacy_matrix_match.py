"""Live: no seat learns another seat's role or a secret tool before the rules say so.

Run through run_live_suite.py --only=privacy_matrix_match. Bot-owned rooms
only; every call is a bot's own request with its own token.

Rows E2, E3, T22 of docs/specs/18-scenario-matrix.md (rule: doc 05 s2, s5):
  E2   one match, read at every phase by a living citizen and a living Mafioso:
       only their own role (the Mafioso also its teammate), the eliminated
       seat's role after a verdict, no standings before the result, every
       dealt role (kicked seat included) at the result.
  E3   the dead witness sees the table, whisper bodies only when the setting
       allows; the living and the removed are refused.
  T22  with realtime observers, secret tools leave no owner, target or answer
       in anything an observer can read; the private answer is the buyer's.
The raw JSON text of every payload is searched, not one field.
"""
import time
import json
import uuid
import e2e_match as h
import new_roles_tools_match as n
import remaining_conflicts_match as rc

ROLES = {'mafia', 'silencer', 'doctor', 'detective', 'citizen', 'sniper', 'elder'}
SEVEN = dict(mafia=2, doctor=1, detective=1, citizen=3)
EIGHT = dict(mafia=2, doctor=1, citizen=5)
BODY = 'privacy-matrix-whisper-body-' + uuid.uuid4().hex[:12]
TABLES = ['room_players', 'room_players_public', 'room_state', 'rooms_public',
          'whisper_meta', 'whisper_content', 'night_actions', 'votes']
SECRET = ('camouflage', 'impersonate', 'anon_note')


class PM(n.Match):
    """The harness Match that also keeps every payload a bot was given."""
    def __init__(self, *a, **k):
        self.cap, self.cur = [], 0
        super().__init__(*a, **k)

    def inspect(self, data, p, source):
        self.cap.append((source, p['id'], data))
        super().inspect(data, p, source)


def text(obj):
    return json.dumps(obj, sort_keys=True, default=str, ensure_ascii=False)


def dicts(obj):
    if isinstance(obj, dict):
        yield obj
        for v in obj.values():
            yield from dicts(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from dicts(v)


def strip(obj):
    if isinstance(obj, dict):
        return {k: strip(v) for k, v in obj.items() if k != 'outcome'}
    if isinstance(obj, list):
        return [strip(v) for v in obj]
    return obj


def role_leaks(objs, p, public):
    """Sources where p could read a role it may not know."""
    forbidden = ROLES - {p['role']} - set(public.values())
    bad = set()
    for name, data in objs:
        data = strip(data)
        t = text(data)
        if any('"%s"' % w in t for w in forbidden):
            bad.add(name)
        for d in dicts(data):
            r, s = d.get('role'), d.get('seat')
            if isinstance(r, str) and s is not None and s != p['seat'] and s not in public:
                bad.add(name + ':row')
    return sorted(bad)


def snapshot(m, p, alive):
    """Everything this bot's own token can read about the room."""
    out = []
    for t in TABLES:
        path = t + '?select=*' + ('' if t == 'whisper_content' else '&room_id=eq.' + m.id)
        status, data = h.rest(path, p)
        out.append(('rest:' + t, data if status == 200 else {'status': status}))
    out.append(('state', m.state(p)))
    out.append(('economy:matchWhispers', m.call('economy', p, action='matchWhispers')[1]))
    if p['seat'] in alive:
        out.append(('witness_view', m.call('witness_view', p)[1]))
    return out


def realtime_new(m, p):
    out = []
    for source, pid, data in m.cap[m.cur:]:
        if pid == p['id'] and source.startswith('realtime:') and isinstance(data, dict) \
                and data.get('phase') != 'result':
            out.append((source, data))
    return out


def checkpoint(m, tag, watchers, public):
    time.sleep(1.5)
    alive = {p['seat'] for p in m.alive()}
    for p in watchers:
        objs = snapshot(m, p, alive) + realtime_new(m, p)
        bad = role_leaks(objs, p, public)
        n.record('E2 %s: %s sees only its own role' % (tag, p['role']), not bad, bad)
        state = next(d for name, d in objs if name == 'state')
        n.record('E2 %s: %s sees no standings yet' % (tag, p['role']),
                 not (state.get('public_data') or {}).get('standings'))
    m.cur = len(m.cap)


def witness_flag(p):
    data = n.eco(p, 'capabilities')[1]
    for d in dicts(data):
        w = d.get('witness')
        if isinstance(w, dict) and 'whispers' in w:
            return bool(w['whispers'])
    return None


def e2_e3_match():
    m = PM('privacy', SEVEN, flags=dict(whisperEnabled=True), realtime=True)
    m.start()
    m0, m1 = [p for p in m.players if p['role'] == 'mafia']
    doctor, detective = m.role('doctor'), m.role('detective')
    citizens = [p for p in m.players if p['role'] == 'citizen']
    kicked = next(p for p in citizens if p is not m.host)
    victim, obs = [p for p in citizens if p is not kicked]
    watchers = [obs, m1]
    public = {}

    checkpoint(m, 'after the deal', watchers, public)
    team = m.call('my_team', m1)[1].get('teammates') or []
    status, roster = h.rest('room_players_public?select=seat,name&room_id=eq.' + m.id, m1)
    mate = next((r.get('name') for r in roster if r.get('seat') == m0['seat']), None) if status == 200 else None
    n.record('E2 deal: the Mafioso sees its teammate and no town seat',
             mate is not None and team == [mate] and not any(w in text(team) for w in ROLES),
             len(team))
    n.record('E2 deal: a citizen has no teammates', not m.call('my_team', obs)[1].get('teammates'))

    m.reveal()
    checkpoint(m, 'night opens', watchers, public)
    m.night(kill=victim['seat'], protect=m0['seat'])
    n.record('E2 night one kills the victim only', victim['seat'] not in [p['seat'] for p in m.alive()])
    checkpoint(m, 'morning', watchers, public)

    m.discuss()
    sent = m.call('send_whisper', m1, toSeat=doctor['seat'], body=BODY)
    n.record('E3 setup: a living seat whispers to another', sent[0] == 200, sent[1].get('error'))
    n.accepted('E2 host removes a citizen by day', m.call('kick_player', seat=kicked['seat']))
    witness_checks(m, victim, kicked, obs, [obs, detective, m1, doctor], sent[0] == 200)
    checkpoint(m, 'discuss', watchers, public)

    n.accepted('E2 ballot opens', m.call('open_phase', phase='vote'))
    checkpoint(m, 'vote', watchers, public)
    verdict = m.vote(m0['seat'])
    n.record('E2 the ballot removes the Mafioso', verdict.get('eliminatedSeat') == m0['seat'], verdict.get('error'))
    public[m0['seat']] = m0['role']
    revealed = [d['eliminatedRole'] for d in dicts(m.state(obs)) if d.get('eliminatedRole')]
    n.record('E2 verdict: only the eliminated seat role is public',
             bool(revealed) and set(revealed) <= {m0['role']}, len(revealed))
    checkpoint(m, 'right after the verdict', watchers, public)

    n.accepted('E2 night two opens', m.call('open_phase', phase='night'))
    m.night(kill=doctor['seat'], protect=m1['seat'])
    m.discuss()
    verdict = m.vote(m1['seat'])
    public[m1['seat']] = m1['role']
    n.record('E2 last Mafioso removed, outcome set', (m.state(obs).get('public_data') or {}).get('outcome') == 'town',
             verdict.get('error'))
    n.record('E2 the room is still on the verdict, not the result', m.state(obs)['phase'] != 'result')
    checkpoint(m, 'just before the outcome', [obs], public)

    n.accepted('E2 result opens', m.call('open_phase', phase='result'))
    dealt = {p['seat']: p['role'] for p in m.players}
    for p in (obs, m1):
        rows = {x['seat']: x for x in ((m.state(p).get('public_data') or {}).get('standings') or [])}
        n.record('E2 result: %s sees every dealt role, the removed seat included' % p['role'],
                 {s: x.get('role') for s, x in rows.items()} == dealt, sorted(rows))
    m.close()


def witness_checks(m, dead, removed, obs, living, whispered):
    dealt = {p['seat']: p['role'] for p in m.players if p is not removed}
    status, view = m.call('witness_view', dead)
    got = {r['seat']: r['role'] for r in view.get('roles', [])} if status == 200 else {}
    n.record('E3 the dead see the open table', status == 200 and got == dealt, status)
    flag = witness_flag(dead)
    if flag is None:
        n.skip('E3 whisper bodies follow the setting', 'FLAG_NOT_READABLE')
    else:
        shown = [w for w in view.get('whispers', []) if w.get('text') == BODY]
        if flag and whispered:
            n.record('E3 setting on: the dead read the whisper body', len(shown) == 1)
        else:
            n.record('E3 setting off: no whisper body and no whispers key for the dead',
                     BODY not in text(view) and 'whispers' not in view)
    n.skip('E3 room setting witnessKnowledge off', 'NOT_SETTABLE_THROUGH_THE_API')
    status, rows = h.rest('whisper_content?select=*', dead)
    n.record('E3 the dead read no whisper body directly', BODY not in text(rows), status)
    codes = set()
    for p in living:
        status, data = m.call('witness_view', p)
        codes.add(data.get('error'))
        n.record('E3 a living seat is refused (seat %d)' % p['seat'],
                 status == 403 and data.get('error') in ('WITNESS_ONLY', 'NOT_ALIVE'), data.get('error'))
        n.record('E3 the refusal carries no role or whisper (seat %d)' % p['seat'],
                 'roles' not in data and BODY not in text(data))
    n.record('E3 every living seat gets the same refusal', len(codes) == 1, sorted(str(c) for c in codes))
    n.refused('E3 the removed seat is refused', m.call('witness_view', removed),
              ['NOT_A_MEMBER', 'WITNESS_ONLY', 'NOT_ALIVE'])
    for p in (obs,):
        reads = [d for name, d in snapshot(m, p, set())]
        n.record('E3 a living seat reads no whisper body anywhere', BODY not in text(reads))


def tool_scan(m, tag, observers, owners, expected):
    time.sleep(1.5)
    ids = {p['id'] for p in observers}
    for p in observers:
        m.state(p)
        rows = m.call('economy', p, action='toolAnswers')[1].get('answers', [])
        n.record('T22 %s: seat %d has no tool answer of its own' % (tag, p['seat']), not rows)
        status, uses = h.rest('room_tool_uses?select=*&room_id=eq.' + m.id, p)
        n.record('T22 %s: seat %d cannot read the use rows' % (tag, p['seat']),
                 status >= 400 or uses == [], status)
    bad, info, logged, live = set(), set(), set(), set()
    for source, pid, data in m.cap[m.cur:]:
        if pid not in ids:
            continue
        t = text(data)
        for key in ('"answer"', 'target_seats', 'targetSeats'):
            if key in t:
                bad.add(source + ':' + key.strip('"'))
        if source in ('state', 'realtime:room_state'):
            for code, owner in owners.items():
                if owner['id'] in t:
                    bad.add(source + ':owner id ' + code)
        for d in dicts(data):
            for e in d.get('toolLog') or []:
                tool = e.get('tool')
                logged.add(tool)
                if source.startswith('realtime:'):
                    live.add(tool)
                if tool in SECRET and (e.get('seat') is not None or e.get('targets')
                                       or (e.get('note') is not None and tool != 'anon_note')):
                    bad.add('toolLog:' + str(tool))
                if tool in ('sense', 'narrator_whisper') and (e.get('targets') or e.get('note') is not None):
                    bad.add('toolLog:' + str(tool))
                if tool in ('impersonate', 'camouflage') and ('"mafia"' in text(e) or '"citizen"' in text(e)):
                    bad.add('toolLog:face ' + str(tool))
                if tool not in SECRET and e.get('seat') is not None:
                    info.add(tool)
    m.cur = len(m.cap)
    n.record('T22 %s: no owner, target or answer reaches the observers' % tag, not bad, sorted(bad))
    n.record('T22 %s: the public log shows every use' % tag, set(expected) <= logged, sorted(expected))
    if set(expected) <= live:
        n.record('T22 %s: realtime carried the tool log' % tag, True)
    else:
        n.skip('T22 %s: realtime carried the tool log' % tag, 'NO_TOOLLOG_IN_REALTIME')
    if info:
        n.skip('T22 %s: owner seat shown for non-secret tools' % tag, 'BY_DESIGN_SEE_DOC17_5.0')


def tools_match():
    if not rc.fund(n.BOTS):
        n.skip('T22 tools scenario', 'NO_COIN_SETUP')
        return
    m = PM('privacy-tools', EIGHT, realtime=True)
    m.start()
    mafia = [p for p in m.players if p['role'] == 'mafia']
    doctor = m.role('doctor')
    a, b, c, d, obs = [p for p in m.players if p['role'] == 'citizen']
    observers = [obs, doctor]
    owners = {'sense': a, 'narrator_whisper': a, 'impersonate': b, 'camouflage': b,
              'half_door': c, 'lock_door': c, 'anon_note': d}
    for code, p in owners.items():
        n.accepted('T22 buy ' + code, n.eco(p, 'toolBuy', tool=code, pack=1, requestId=h.aid()))
    m.reveal()

    sense = n.accepted('T22 use sense', m.call('economy', a, action='toolUse', tool='sense',
                       targets=[mafia[0]['seat'], obs['seat'], doctor['seat']]))
    whisper = n.accepted('T22 use narrator_whisper', m.call('economy', a, action='toolUse',
                         tool='narrator_whisper', targets=[obs['seat'], doctor['seat']]))
    own = m.call('economy', a, action='toolAnswers')[1].get('answers', [])
    n.record('T22 the buyer reads both private answers',
             any(x.get('tool') == 'sense' and x.get('answer') is True for x in own)
             and any(x.get('tool') == 'narrator_whisper' and x.get('answer') is False for x in own)
             and sense.get('answer') is True and whisper.get('answer') is False)
    tool_scan(m, 'night tools', observers, owners, ['sense', 'narrator_whisper'])

    m.night()
    m.discuss()
    for code, note in (('impersonate', 'mafia'), ('camouflage', None), ('half_door', None),
                       ('lock_door', None), ('anon_note', 'privacy-matrix-note')):
        n.accepted('T22 use ' + code, m.call('economy', owners[code], action='toolUse', tool=code,
                                             targets=[], note=note))
    tool_scan(m, 'day tools', observers, owners, ['impersonate', 'camouflage', 'half_door', 'lock_door', 'anon_note'])
    m.finish_town()
    m.close()


def main():
    h._POOL_TAKEN[0] = 0
    n.BOTS = [h.anon_session('LiveBot%d' % i) for i in range(8)]
    for name, scenario in (('E2/E3', e2_e3_match), ('T22', tools_match)):
        try:
            scenario()
        except Exception as e:
            n.record(name + ': scenario interrupted', False, type(e).__name__)
        finally:
            # A match that died while seating players has no watches yet.
            for m in n.ACTIVE:
                if hasattr(m, 'beat_stop'):
                    m.beat_stop.set()
                for w in getattr(m, 'watches', []):
                    try:
                        w.close()
                    except Exception:
                        pass
