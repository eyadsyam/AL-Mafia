"""Live rows D6, D11, X8, D29, T6, D33, T4.

Run through run_live_suite.py --only=silence_floor_match. Bot-owned rooms only.
"""
import os
import datetime as dt
import time

import e2e_match as h
import new_roles_tools_match as n
import remaining_conflicts_match as c


SILENCER = dict(mafia=1, silencer=1, doctor=1, citizen=4)
PLAIN = dict(mafia=1, doctor=1, citizen=5)


def deadline(m):
    end = m.state()['phase_ends_at']
    due = dt.datetime.fromisoformat(end.replace('Z', '+00:00')).timestamp()
    while time.time() < due + 1:
        time.sleep(min(10, due + 1 - time.time()))


def expire(m, phase):
    deadline(m)
    guest = m.players[1]
    for _ in range(4):
        status, data = m.call('advance_phase', guest)
        if status == 200:
            n.record(m.label + ': ' + phase + ' expiry', True)
            return data
        if data.get('error') != 'PHASE_CLOSED' or 'not expired' not in data.get('message', ''):
            break
        time.sleep(2)
    n.record(m.label + ': ' + phase + ' expiry', False, data.get('error'))
    raise RuntimeError('EXPIRY_FAILED')


def rows(m):
    day = m.state()['phase_number']
    status, votes = h.rest('votes?select=voter_id,target_id,round&room_id=eq.' + m.id +
                           '&day=eq.' + str(day) + '&round=eq.1', m.host)
    if status != 200:
        raise RuntimeError('VOTES_UNAVAILABLE')
    return {v['voter_id']: v['target_id'] for v in votes}


def cast(m, p, target):
    return m.call('submit_vote', p, targetSeat=target['seat'], round=1,
                  actionId=h.aid())


def use(m, buyer, tool, target):
    return m.call('economy', buyer, action='toolUse', tool=tool,
                  targets=[target['seat']])


def no_kill(m, silence=None, protect=None):
    m.reveal()
    m.night(silence=silence, protect=protect)
    m.discuss()


def confrontation_silence():
    m = n.Match('D6', SILENCER, flags={'silencerEnabled': True,
        'confrontationEnabled': True, 'survivorConfrontationEnabled': True,
        'confrontationSeconds': 30, 'quietNightEnabled': False})
    try:
        m.start()
        target = m.role('citizen')
        # C11 names a save from an earlier night only (doc 09: >=1 day later),
        # so night one saves `target` and night two silences them.
        other = next(p for p in m.players if p is not target and p['role'] != 'doctor')
        m.reveal()
        m.night(kill=target['seat'], protect=target['seat'])
        m.discuss()
        n.accepted('D6: first vote opens', m.call('open_phase', phase='vote'))
        n.accepted('D6: first ballot resolves', m.call('resolve_vote'))
        n.accepted('D6: second night opens', m.call('open_phase', phase='night'))
        m.night(silence=target['seat'], protect=other['seat'])
        n.record('D6: saved target lives and is silenced', target in m.alive() and
                 m.state()['public_data'].get('morning', {}).get('silencedSeat') == target['seat'])
        chosen = n.accepted('D6: generate confrontation', m.call('generate_confrontation'))
        n.record('D6: silenced seat confronted', m.state()['phase'] == 'confront' and
                 (chosen.get('confrontation') or {}).get('targetSeat') == target['seat'],
                 m.state()['phase'])
        if m.state()['phase'] != 'confront':
            raise RuntimeError('NO_CONFRONTATION')
        status, claim = m.call('claim_floor', target)
        n.record('D6: silenced target cannot claim floor', status == 200 and
                 claim.get('granted') is False and claim.get('reason') == 'silenced')
        expire(m, 'confront')
        state = m.state()
        n.record('D6: clock records silence and moves to discuss',
                 state['phase'] == 'discuss' and
                 state['public_data'].get('confrontationSilent') is True,
                 state['phase'])
    finally:
        m.close()


def silenced_ballot(early):
    label = 'D11-early' if early else 'D11-expiry'
    m = n.Match(label, SILENCER, flags={'silencerEnabled': True})
    try:
        m.start()
        silent = m.role('citizen')
        no_kill(m, silence=silent['seat'])
        n.accepted(label + ': vote opens', m.call('open_phase', phase='vote'))
        other = next(p for p in m.alive() if p != silent)
        n.refused(label + ': silenced ballot refused', cast(m, silent, other), ['WRONG_ROLE'])
        eligible = [p for p in m.alive() if p != silent]
        if early:
            # Avoid eliminating anybody: split the living voters across targets.
            for i, p in enumerate(eligible):
                target = next(x for x in eligible if x != p and
                              x['seat'] == eligible[(i + 1) % len(eligible)]['seat'])
                n.accepted(label + ': eligible ballot ' + str(p['seat']), cast(m, p, target))
            end = dt.datetime.fromisoformat(m.state()['phase_ends_at'].replace('Z', '+00:00'))
            n.record(label + ': all eligible votes close clock',
                     end.timestamp() <= time.time() + 3)
            n.record(label + ': no silenced ballot before expiry', silent['id'] not in rows(m))
            n.accepted(label + ': ballot resolves', m.call('resolve_vote'))
        else:
            first = eligible[0]
            n.accepted(label + ': one eligible ballot', cast(m, first, eligible[1]))
            expire(m, 'vote')
            n.accepted(label + ': ballot resolves', m.call('resolve_vote'))
            # votes_read shows a member only their own ballot while the phase is
            # `vote`, so the room's rows are read once it has left `vote`.
            written = rows(m)
            expected = {p['id'] for p in eligible if p != first}
            n.record(label + ': defaults only for eligible non-voters',
                     {uid for uid, target in written.items() if target is None} == expected
                     and silent['id'] not in written)
        n.record(label + ': verdict reached', m.state()['phase'] == 'verdict',
                 m.state()['phase'])
    finally:
        m.close()


def abstain_disabled():
    m = n.Match('X8', PLAIN, flags={'abstainAllowed': False})
    try:
        m.start()
        no_kill(m)
        n.accepted('X8: vote opens', m.call('open_phase', phase='vote'))
        voter, target = m.alive()[:2]
        n.refused('X8: chosen abstention refused',
                  m.call('submit_vote', voter, targetSeat=None, round=1,
                         actionId=h.aid()), ['BAD_REQUEST'])
        n.accepted('X8: one chosen target', cast(m, voter, target))
        expected = {p['id'] for p in m.alive() if p != voter}
        expire(m, 'vote')
        result = n.accepted('X8: expired ballot resolves', m.call('resolve_vote'))
        # votes_read shows a member only their own ballot while the phase is
        # `vote`, so the room's rows are read once it has left `vote`.
        written = rows(m)
        n.record('X8: exact null defaults despite abstain off',
                 set(written) == expected | {voter['id']} and
                 {uid for uid, choice in written.items() if choice is None} == expected and
                 written[voter['id']] == target['id'])
        n.record('X8: only chosen seat eliminated', result.get('eliminatedSeat') ==
                 target['seat'] and m.state()['phase'] == 'verdict',
                 result.get('eliminatedSeat'))
    finally:
        m.close()


def last_word(eliminate, remove_target=False):
    label = ('D33-last-word' if remove_target else
             'D29-no-elimination' if eliminate is None else
             'D29-eliminated' if eliminate else 'D29-survives')
    m = n.Match(label, PLAIN)
    try:
        m.start()
        buyer, target = [p for p in m.players if p['role'] == 'citizen'][:2]
        c.buy(buyer, 'last_word')
        no_kill(m)
        n.accepted(label + ': vote opens', m.call('open_phase', phase='vote'))
        before = c.charges(buyer, 'last_word')
        n.refused(label + ': self target refused', use(m, buyer, 'last_word', buyer), ['BAD_TARGETS'])
        n.record(label + ': refusal keeps charge', c.charges(buyer, 'last_word') == before)
        n.accepted(label + ': live target used', use(m, buyer, 'last_word', target))
        n.record(label + ': use spends charge', c.charges(buyer, 'last_word') == before - 1)
        if remove_target:
            n.accepted(label + ': target kicked after use', m.call('kick_player', seat=target['seat']))
            n.refused(label + ': kicked target refused', use(m, buyer, 'last_word', target),
                      ['BAD_TARGETS'])
        if eliminate is not None:
            victim = buyer if eliminate else target
            for p in m.alive():
                if p != victim:
                    n.accepted(label + ': ballot ' + str(p['seat']), cast(m, p, victim))
        result = n.accepted(label + ': ballot resolves', m.call('resolve_vote'))
        expected = {'seat': buyer['seat'], 'target': target['seat']}
        n.record(label + ': last word belongs to eliminated owner only',
                 (result.get('lastWord') == expected) is (eliminate is True))
        if eliminate:
            n.record(label + ': next-day floor cue stored',
                     m.state()['public_data'].get('lastWordFloor') ==
                     dict(expected, day=m.state()['phase_number']))
        else:
            n.record(label + ': survivor has no floor cue',
                     m.state()['public_data'].get('lastWordFloor') is None)
        n.accepted(label + ': next night', m.call('open_phase', phase='night'))
        m.night()
        m.discuss()
        if eliminate and not remove_target:
            status, held = m.call('claim_floor', m.role('mafia'))
            n.record(label + ': target holds first turn', status == 200 and
                     held.get('granted') is False)
            status, granted = m.call('claim_floor', target)
            n.record(label + ': target speaks first', status == 200 and
                     granted.get('granted') is True)
        else:
            claimant = next(p for p in m.alive() if p != target and p != buyer)
            status, granted = m.call('claim_floor', claimant)
            n.record(label + ': no forced target floor', status == 200 and
                     granted.get('granted') is True)
            if remove_target:
                n.record(label + ': removed target charge stays spent',
                         c.charges(buyer, 'last_word') == before - 1)
    finally:
        m.close()


def spotlight_removed():
    m = n.Match('D33-spotlight', PLAIN)
    try:
        m.start()
        buyer, target, removed = [p for p in m.players if p['role'] == 'citizen'][:3]
        c.buy(buyer, 'spotlight')
        no_kill(m)
        before = c.charges(buyer, 'spotlight')
        n.refused('T4: self target refused', use(m, buyer, 'spotlight', buyer), ['BAD_TARGETS'])
        n.record('T4: self refusal keeps charge', c.charges(buyer, 'spotlight') == before)
        n.accepted('T4: spotlight on living seat', use(m, buyer, 'spotlight', target))
        n.record('T4: spotlight charge spent on use', c.charges(buyer, 'spotlight') == before - 1)
        n.accepted('T4: target kicked before floor', m.call('kick_player', seat=target['seat']))
        n.refused('T4: kicked target refused', use(m, buyer, 'spotlight', target),
                  ['BAD_TARGETS'])
        status, denied = m.call('claim_floor', target)
        n.record('T4: kicked target cannot speak', status >= 400 and
                 denied.get('error') in ('NOT_A_MEMBER', 'NOT_ALIVE'), denied.get('error'))
        status, granted = m.call('claim_floor', removed)
        n.record('T4: living seat takes unheld floor', status == 200 and
                 granted.get('granted') is True)
        n.record('T4: removed target charge stays spent',
                 c.charges(buyer, 'spotlight') == before - 1)
    finally:
        m.close()


def main():
    h._POOL_TAKEN[0] = 0
    n.BOTS = [h.anon_session('LiveBot%d' % i) for i in range(7)]
    if not c.fund(n.BOTS):
        n.record('silence/floor bot funding', False, 'NO_PRIVILEGED_SETUP')
        return
    n.accepted('silence/floor host owns silencer', n.eco(n.BOTS[0], 'buy', item='role_silencer'))
    scenarios = [confrontation_silence, lambda: silenced_ballot(True),
                 lambda: silenced_ballot(False), abstain_disabled,
                 lambda: last_word(True), lambda: last_word(False),
                 lambda: last_word(None), lambda: last_word(True, True),
                 spotlight_removed]
    names = ['D6', 'D11-early', 'D11-expiry', 'X8', 'D29-eliminated',
             'D29-survives', 'D29-no-elimination', 'D33-last-word',
             'D33-spotlight']
    pick = os.environ.get('LIVE_SCENARIOS')
    for label, scenario in zip(names, scenarios):
        if pick and label not in pick.split(','):
            continue
        try:
            scenario()
        except Exception as error:
            n.record(label + ': interrupted', False, type(error).__name__)
        finally:
            for match in n.ACTIVE:
                if match.label == label and not match.beat_stop.is_set():
                    match.close()


if __name__ == '__main__':
    main()
