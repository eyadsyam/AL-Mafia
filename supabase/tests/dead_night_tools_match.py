"""Exercise both night-only table tools from a dead owner in a live match."""
import e2e_match as h
import new_roles_tools_match as n


def main():
    h._POOL_TAKEN[0] = 1
    n.BOTS = [h.anon_session('CachedBot%d' % i) for i in range(5)]
    m = n.Match('dead_night_tools', dict(mafia=1, doctor=1, citizen=3), realtime=True)
    m.start()
    victim = m.role('citizen')
    for code in ('sense', 'narrator_whisper'):
        n.accepted('dead night buy ' + code, n.eco(victim, 'toolBuy', tool=code,
                   pack=3, requestId=h.aid()))
    m.reveal()
    m.night(kill=victim['seat'], protect=m.role('mafia')['seat'])
    n.record('night-tool owner dies', victim not in m.alive())
    m.discuss()
    n.accepted('dead night ballot opens', m.call('open_phase', phase='vote'))
    for p in m.alive():
        n.accepted('dead night abstain ' + str(p['seat']), m.call('submit_vote', p,
                   targetSeat=None, round=1, actionId=h.aid()))
    n.accepted('dead night abstention verdict', m.call('resolve_vote'))
    n.accepted('dead night second night opens', m.call('open_phase', phase='night'))
    for code, targets in (('sense', [m.role('mafia')['seat']]),
                          ('narrator_whisper', [m.role('doctor')['seat']])):
        n.refused('dead night use ' + code, m.call('economy', victim,
                  action='toolUse', tool=code, targets=targets), ['NOT_ALIVE'])
    m.night(protect=m.role('mafia')['seat'])
    m.discuss()
    m.vote(m.role('mafia')['seat'])
    m.finish_town()
    m.close()
