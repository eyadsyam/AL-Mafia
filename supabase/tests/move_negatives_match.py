"""Live: every night move and ballot a player may not make is refused.

Run through run_live_suite.py --only=move_negatives_match. Bot-owned rooms
only; every call is a bot's own request.

Rows N59, N48, N32, N37 of docs/specs/18-scenario-matrix.md: self, a
teammate, a dead seat, a removed seat, a missing seat, the wrong role, a
second investigation, the same cover twice; then the ballot's own: the dead,
the removed, oneself, a dead or removed target. Each refusal must leave the
room as it was: the night still resolves with the moves that were allowed.
"""
import e2e_match as h
import new_roles_tools_match as n

SEVEN = dict(mafia=2, doctor=1, detective=1, citizen=3)


def night_move(m, p, action, target=None, bullet=False):
    return m.call('submit_night_action', p, action=action, targetSeat=target,
                  useBullet=bullet, actionId=h.aid())


def quiet(m, label, p, action, target, bullet=False):
    """A Citizen has no night move online: the call is answered 200 and no row is kept."""
    status, data = night_move(m, p, action, target, bullet)
    n.record(label + ': accepted', status == 200 and not data.get('error'), data.get('error'))
    status, rows = h.rest('night_actions?select=night,action&room_id=eq.%s' % m.id, p)
    n.record(label + ': no night row', status == 200 and rows == [], status)


def main():
    h._POOL_TAKEN[0] = 0
    n.BOTS = [h.anon_session('LiveBot%d' % i) for i in range(7)]
    m = n.Match('negatives', SEVEN)
    m.start()
    m.reveal()
    mafia = [p for p in m.players if p['role'] == 'mafia']
    doctor, detective = m.role('doctor'), m.role('detective')
    citizens = [p for p in m.players if p['role'] == 'citizen']
    victim, removed, bystander = citizens

    # Night one: everything a seat may not choose.
    n.refused('mafia cannot kill itself', night_move(m, mafia[0], 'kill', mafia[0]['seat']),
              ['BAD_REQUEST'])
    n.refused('mafia cannot kill a teammate', night_move(m, mafia[0], 'kill', mafia[1]['seat']),
              ['BAD_REQUEST'])
    n.refused('a kill needs a target', night_move(m, mafia[0], 'kill'), ['BAD_REQUEST'])
    n.refused('no such seat', night_move(m, mafia[0], 'kill', 39), ['BAD_REQUEST'])
    quiet(m, 'a citizen kill is answered and stores nothing', victim, 'kill', bystander['seat'])
    quiet(m, 'a citizen protect is answered and stores nothing', victim, 'protect', bystander['seat'])
    n.refused('the doctor cannot kill', night_move(m, doctor, 'kill', victim['seat']),
              ['WRONG_ROLE'])
    n.refused('the doctor must protect someone', night_move(m, doctor, 'skip'), ['BAD_REQUEST'])
    n.refused('the detective cannot investigate itself',
              night_move(m, detective, 'investigate', detective['seat']), ['BAD_REQUEST'])
    n.refused('the detective cannot kill', night_move(m, detective, 'kill', victim['seat']),
              ['WRONG_ROLE'])
    quiet(m, 'a citizen bullet move is answered and stores nothing', victim, 'suspect',
          mafia[0]['seat'], True)

    # The allowed moves, then the night's own limits.
    n.accepted('mafia kills a citizen', night_move(m, mafia[0], 'kill', victim['seat']))
    n.accepted('second mafioso agrees', night_move(m, mafia[1], 'kill', victim['seat']))
    n.accepted('doctor covers a bystander', night_move(m, doctor, 'protect', bystander['seat']))
    first = n.accepted('detective investigates', night_move(m, detective, 'investigate',
                                                           mafia[0]['seat']))
    n.record('investigation answers the truth', first.get('revealedRole') in ('mafia', 'silencer'),
             first.get('error'))
    n.refused('one investigation a night',
              night_move(m, detective, 'investigate', bystander['seat']), ['RATE_LIMITED'])
    morning = n.accepted('night one resolves after the refusals', m.call('resolve_night'))
    n.record('only the allowed kill happened', morning.get('victimSeat') == victim['seat']
             and victim not in m.alive(), morning.get('victimSeat'))

    # Day one: the dead and a removed seat.
    m.discuss()
    n.accepted('host removes a citizen by day', m.call('kick_player', seat=removed['seat']))
    n.accepted('ballot opens', m.call('open_phase', phase='vote'))
    n.refused('the dead do not vote', m.call('submit_vote', victim, targetSeat=mafia[0]['seat'],
              round=1, actionId=h.aid()), ['NOT_ALIVE'])
    n.refused('a removed seat does not vote', m.call('submit_vote', removed,
              targetSeat=mafia[0]['seat'], round=1, actionId=h.aid()), ['NOT_A_MEMBER'])
    n.refused('nobody votes for themselves', m.call('submit_vote', bystander,
              targetSeat=bystander['seat'], round=1, actionId=h.aid()), ['BAD_REQUEST'])
    n.refused('no ballot for a dead seat', m.call('submit_vote', bystander,
              targetSeat=victim['seat'], round=1, actionId=h.aid()), ['BAD_REQUEST'])
    n.refused('no ballot for a removed seat', m.call('submit_vote', bystander,
              targetSeat=removed['seat'], round=1, actionId=h.aid()), ['BAD_REQUEST'])
    n.refused('no ballot for another round', m.call('submit_vote', bystander,
              targetSeat=mafia[0]['seat'], round=2, actionId=h.aid()), ['PHASE_CLOSED'])
    # Mafia 2, town 3 (doctor, detective, bystander): one Mafioso goes, play on.
    living = m.alive()
    verdict = m.vote(mafia[0]['seat'], ballots={
        p['seat']: (mafia[0]['seat'] if p != mafia[0] else bystander['seat']) for p in living})
    n.record('the ballot counts only the living', verdict.get('eliminatedSeat') == mafia[0]['seat'],
             verdict.get('error'))
    n.accepted('night two opens', m.call('open_phase', phase='night'))

    # Night two: the dead, the removed and last night's cover.
    n.refused('the dead take no part in the night', night_move(m, victim, 'skip'), ['NOT_ALIVE'])
    n.refused('a removed seat takes no part', night_move(m, removed, 'skip'), ['NOT_A_MEMBER'])
    n.refused('no kill on a dead seat', night_move(m, mafia[1], 'kill', victim['seat']),
              ['BAD_REQUEST'])
    n.refused('no kill on a removed seat', night_move(m, mafia[1], 'kill', removed['seat']),
              ['BAD_REQUEST'])
    n.refused('no cover for a dead seat', night_move(m, doctor, 'protect', mafia[0]['seat']),
              ['BAD_REQUEST'])
    n.refused('not the same cover two nights running',
              night_move(m, doctor, 'protect', bystander['seat']), ['SAME_PROTECT'])
    n.refused('no investigation of a removed seat',
              night_move(m, detective, 'investigate', removed['seat']), ['BAD_REQUEST'])
    n.accepted('mafia kills the bystander', night_move(m, mafia[1], 'kill', bystander['seat']))
    n.accepted('doctor covers the detective', night_move(m, doctor, 'protect', detective['seat']))
    n.accepted('detective investigates the doctor',
               night_move(m, detective, 'investigate', doctor['seat']))
    morning = n.accepted('night two resolves after the refusals', m.call('resolve_night'))
    n.record('night two kills the bystander only', morning.get('victimSeat') == bystander['seat'],
             morning.get('victimSeat'))
    m.discuss()
    m.vote(mafia[1]['seat'])
    m.finish_town()
    n.record('the match ends for the town', (m.state().get('public_data') or {}).get('outcome') == 'town')
    m.close()
