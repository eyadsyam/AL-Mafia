"""Live checks for the 2026-10-23 server fixes, in bot-owned rooms only.

Run through run_live_suite.py --only=fairness_match. No deploys, no SQL, no
privileged writes: every call is a bot's own request.

  * N8: two Mafiosi, one picks the victim and the other never acts. At the
    night's expiry the absent one contributes nothing, so the victim is always
    the active one's choice (it used to be a coin toss).
  * A host's kick that decides the match mid-day opens the result straight
    from the discussion.
  * A finished room refuses a kick (PHASE_CLOSED): it can no longer take a
    late player's rewards.
"""
import datetime as dt
import time
import urllib.error
import e2e_match as h
import new_roles_tools_match as n


def wait_for_deadline(m, offset):
    """Sleeps until the server's clock has passed this phase's deadline."""
    for _ in range(40):
        state = m.state()
        end = state.get('phase_ends_at')
        if not end:
            return state
        deadline = dt.datetime.fromisoformat(end.replace('Z', '+00:00')).timestamp()
        delay = deadline - (time.time() + offset) + 2
        if delay <= 0:
            return state
        time.sleep(min(delay, 15))
    return m.state()


def idle_mafioso_match():
    m = n.Match('idle mafioso', dict(mafia=2, doctor=1, citizen=3))
    m.start()
    m.reveal()
    offset = n.server_offset()
    mafiosi = [p for p in m.players if p['role'] == 'mafia']
    citizens = [p for p in m.players if p['role'] == 'citizen']
    doctor = m.role('doctor')
    victim, spared = citizens[0], citizens[1]
    n.accepted('idle mafioso: the active one picks', m.call(
        'submit_night_action', mafiosi[0], action='kill', targetSeat=victim['seat'],
        useBullet=False, actionId=h.aid()))
    n.accepted('idle mafioso: the doctor covers someone else', m.call(
        'submit_night_action', doctor, action='protect', targetSeat=spared['seat'],
        useBullet=False, actionId=h.aid()))
    m.last_protect = spared['seat']
    wait_for_deadline(m, offset)
    guest = citizens[2]
    for _ in range(4):
        response = m.call('advance_phase', guest)
        if response[0] == 200:
            break
        time.sleep(2)
    n.record('idle mafioso: expiry defaults applied', response[0] == 200,
             response[1].get('error'))
    n.accepted('idle mafioso: the night resolves', m.call('resolve_night', guest))
    alive = {p['seat'] for p in m.alive()}
    n.record('idle mafioso: the active choice is the victim', victim['seat'] not in alive)
    n.record('idle mafioso: nobody else died',
             all(p['seat'] in alive for p in m.players if p is not victim))
    m.discuss()
    m.finish_town()
    n.refused('a finished room refuses a kick',
              m.call('kick_player', seat=citizens[2]['seat']), ['PHASE_CLOSED'])
    m.close()
    return m.id


def deciding_kick_match():
    m = n.Match('deciding kick', dict(mafia=1, doctor=1, citizen=3))
    m.start()
    m.reveal()
    mafia = m.role('mafia')
    citizens = [p for p in m.players if p['role'] == 'citizen']
    m.night(kill=citizens[0]['seat'], protect=citizens[1]['seat'])
    m.discuss()
    status, removal = m.call('kick_player', seat=mafia['seat'])
    n.record('deciding kick: the host removes the last Mafioso', status == 200,
             removal.get('error'))
    state = m.state()
    n.record('deciding kick: the town has won',
             (state.get('public_data') or {}).get('outcome') == 'town')
    n.accepted('deciding kick: the result opens from the discussion',
               m.call('open_phase', phase='result'))
    reached = [m.state(p)['phase'] == 'result' for p in m.players if p is not mafia]
    n.record('deciding kick: every seat reaches the result', all(reached))
    m.close()
    return m.id


def main():
    h._POOL_TAKEN[0] = 0
    n.BOTS = [h.anon_session('LiveBot%d' % i) for i in range(6)]
    rooms = {}
    for name, scenario in (('idle mafioso', idle_mafioso_match),
                           ('deciding kick', deciding_kick_match)):
        try:
            rooms[name] = scenario()
        except (urllib.error.URLError, RuntimeError, KeyError, StopIteration) as e:
            n.record(name + ': scenario interrupted', False, type(e).__name__)
    # Room ids only, for the read-only reward checks that follow.
    (n.ROOT / 'build/fairness_rooms.json').write_text(
        __import__('json').dumps(rooms), encoding='utf-8')
