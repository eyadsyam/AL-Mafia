"""Live: a host's removal in every active phase, deciding the match or not.

Run through run_live_suite.py --only=removal_matrix_match. Bot-owned rooms
only; every call is a bot's own request.

For each phase the room can be in when a seat is removed, two cases: removing
a seat that does not decide the match (it plays on, without that seat), and
removing the one that does (the outcome is written once, nothing later can
overwrite it, and the result opens from where the room stands). Parity is
reached by removals too.
"""
import e2e_match as h
import new_roles_tools_match as n

FIVE = dict(mafia=1, doctor=1, citizen=3)


def outcome(m):
    return (m.state().get('public_data') or {}).get('outcome')


def deal(label, decides):
    # The host is seat 0 and can never be removed (kick_player refuses its own
    # seat), so a removal that decides the match needs a Mafioso who is not the
    # host: deal again, up to four times, rather than fail on the deal.
    for _ in range(4):
        m = n.Match(label, FIVE)
        m.start()
        if not decides or m.role('mafia') is not m.host:
            return m
        if m.leaks:
            n.record(label + ': a dealt-away match kept roles private', False,
                     sorted(m.leaks))
        m.close()
    n.skip(label + ': a Mafioso other than the host is dealt', 'HOST_DEALT_MAFIA')
    return None


def citizens_of(m):
    # A citizen host is listed first, so every later citizen can be removed.
    found = [p for p in m.players if p['role'] == 'citizen']
    return sorted(found, key=lambda p: p is not m.host)


def kick(m, label, p):
    status, data = m.call('kick_player', seat=p['seat'])
    n.record(label + ': the host removes seat ' + str(p['seat']), status == 200,
             data.get('error'))


def to_result(m, label):
    n.accepted(label + ': the result opens', m.call('open_phase', phase='result'))
    n.record(label + ': every seated player reaches the result',
             all(m.state(p)['phase'] == 'result' for p in m.alive()))


def at_night(decides):
    label = 'night kick ' + ('decides' if decides else 'plays on')
    m = deal(label, decides)
    if m is None:
        return
    m.reveal()
    mafia = m.role('mafia')
    citizens = citizens_of(m)
    removed = mafia if decides else citizens[1]
    # The Mafia has already chosen; the removal lands before the resolution.
    n.accepted(label + ': the Mafia picks', m.call(
        'submit_night_action', mafia, action='kill', targetSeat=citizens[0]['seat'],
        useBullet=False, actionId=h.aid()))
    kick(m, label, removed)
    n.record(label + ': outcome after the removal',
             outcome(m) == ('town' if decides else None), outcome(m))
    if decides:
        # Whoever resolves the night now finds the match decided: no death.
        status, morning = m.call('resolve_night')
        n.record(label + ': a late resolution keeps the decided outcome',
                 status in (200, 400) and outcome(m) == 'town', morning.get('error'))
        n.record(label + ': nobody dies after the match was decided',
                 citizens[0] in m.alive())
        to_result(m, label)
    else:
        m.night(kill=citizens[0]['seat'], protect=citizens[2]['seat'])
        n.record(label + ': the night resolves without the removed seat',
                 citizens[0] not in m.alive() and removed not in m.alive())
        m.discuss()
        m.vote(mafia['seat'])
        m.finish_town()
    m.close()


def by_day(phase, decides):
    label = phase + ' kick ' + ('decides' if decides else 'plays on')
    m = deal(label, decides)
    if m is None:
        return
    m.reveal()
    mafia = m.role('mafia')
    citizens = citizens_of(m)
    m.night(kill=citizens[0]['seat'], protect=citizens[1]['seat'])
    m.discuss()
    if phase == 'vote':
        n.accepted(label + ': the ballot opens', m.call('open_phase', phase='vote'))
        # One ballot already in before the removal.
        m.call('submit_vote', citizens[1], targetSeat=mafia['seat'], round=1,
               actionId=h.aid())
    kick(m, label, mafia if decides else citizens[2])
    n.record(label + ': outcome after the removal',
             outcome(m) == ('town' if decides else None), outcome(m))
    if decides:
        if phase == 'vote':
            status, verdict = m.call('resolve_vote')
            n.record(label + ': the ballot keeps the decided outcome',
                     status == 200 and verdict.get('outcome') == 'town'
                     and verdict.get('eliminatedSeat') is None, verdict)
        to_result(m, label)
    else:
        m.vote(mafia['seat'])
        m.finish_town()
    m.close()


def parity_by_removal():
    label = 'parity by removal'
    m = n.Match(label, FIVE)
    m.start()
    m.reveal()
    mafia = m.role('mafia')
    town = [p for p in m.players if p['role'] != 'mafia' and p is not m.host]
    m.night(kill=town[0]['seat'], protect=town[1]['seat'])
    m.discuss()
    # The host is never a target: it stays alive, as town or as the Mafioso.
    # Four alive: the Mafioso and three town. One removal leaves 1 v 2 (plays
    # on), the second leaves 1 v 1 (the Mafia wins).
    kick(m, label, town[1])
    n.record(label + ': one removal does not decide it', outcome(m) is None, outcome(m))
    kick(m, label, town[2])
    n.record(label + ': the second reaches parity for the Mafia', outcome(m) == 'mafia',
             outcome(m))
    to_result(m, label)
    m.close()


def main():
    h._POOL_TAKEN[0] = 0
    n.BOTS = [h.anon_session('LiveBot%d' % i) for i in range(5)]
    scenarios = [
        ('night kick plays on', lambda: at_night(False)),
        ('night kick decides', lambda: at_night(True)),
        ('discuss kick plays on', lambda: by_day('discuss', False)),
        ('discuss kick decides', lambda: by_day('discuss', True)),
        ('vote kick plays on', lambda: by_day('vote', False)),
        ('vote kick decides', lambda: by_day('vote', True)),
        ('parity by removal', parity_by_removal),
    ]
    for name, scenario in scenarios:
        try:
            scenario()
        except Exception as e:
            n.record(name + ': scenario interrupted', False, type(e).__name__)
