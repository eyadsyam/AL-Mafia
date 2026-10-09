"""Live confrontation deadline using five existing cached bots, no new signup."""
import datetime as dt
import time
import e2e_match as h
import new_roles_tools_match as n


def main():
    h._POOL_TAKEN[0] = 1
    n.BOTS = [h.anon_session('CachedBot%d' % i) for i in range(5)]
    m = n.Match('confront_timer', dict(mafia=1, doctor=1, detective=1, citizen=2),
                flags={'openingRoundEnabled': True, 'confrontationEnabled': True,
                       'traceEnabled': True}, realtime=True)
    m.start(); m.reveal(); m.night()
    n.accepted('confront first opening', m.call('open_phase', phase='opening'))
    mafia = m.role('mafia')
    while m.state()['phase'] == 'opening':
        actor_seat = m.state()['public_data']['openingSeat']
        actor = next(p for p in m.players if p['seat'] == actor_seat)
        target = mafia['seat'] if actor != mafia else m.role('citizen')['seat']
        n.accepted('confront accusation ' + str(actor_seat), m.call('submit_accusation', actor,
            targetSeat=target))
    decoy = m.role('citizen')
    m.vote(decoy['seat'])
    n.accepted('confront second night', m.call('open_phase', phase='night'))
    m.night()
    n.accepted('choose supported confrontation', m.call('generate_confrontation'))
    phase = m.state()['phase']
    n.record('eligible confrontation generated', phase == 'confront', phase)
    if phase == 'confront':
        end = m.state()['phase_ends_at']
        deadline = dt.datetime.fromisoformat(end.replace('Z', '+00:00')).timestamp()
        while time.time() < deadline + 1:
            time.sleep(min(15, deadline + 1 - time.time()))
        guest = next(p for p in m.players if p != m.host)
        n.accepted('confrontation expires to discussion', m.call('advance_phase', guest))
        n.record('confrontation default records silence and moves on',
                 m.state()['phase'] == 'discuss' and
                 m.state()['public_data'].get('confrontationSilent') is True)
    m.close()
