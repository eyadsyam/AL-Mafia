"""Five reused anonymous bots: live tool interactions, vote ties, parity.

Run with run_live_suite.py --conflicts. No credentials reach output or files.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import e2e_match as h
import new_roles_tools_match as n


def fund(bots):
    # Exact authenticated anonymous bot IDs. Existing admin ledger path.
    ids = [h.uuid.UUID(p['id']) for p in bots]
    run_id = h.uuid.uuid4().hex
    sql = 'begin; do $$ declare u uuid; bal bigint; begin foreach u in array array['
    sql += ','.join("'%s'::uuid" % uid for uid in ids)
    sql += "] loop if not exists(select 1 from auth.users where id=u and is_anonymous) then raise exception 'NOT_TEST_ANON'; end if; "
    sql += "perform pg_advisory_xact_lock(hashtextextended('wallet:'||u::text,91)); "
    sql += "select balance into bal from public.wallet_accounts where user_id=u; "
    sql += "if coalesce(bal,0) < 30000 then "
    sql += "perform public.credit_earned(u,'operator_adjustment',50000,null,'live-topup-'||u::text||'-%s'); " % run_id
    sql += 'end if; end loop; end $$; commit;'
    path = n.ROOT / 'build/live_conflict_bot_coin_setup.sql'
    path.write_text(sql, encoding='utf-8')
    cmd = ['npx.cmd' if os.name == 'nt' else 'npx', 'supabase', 'db', 'query', '--linked', '-f', str(path)]
    proc = subprocess.run(cmd, cwd=n.ROOT, capture_output=True, timeout=120)
    return n.record('conflicts bot coin setup', proc.returncode == 0, 'CLI_FAILED' if proc.returncode else None)


def use(m, p, code, targets=None, note=None):
    return n.accepted('conflict use ' + code, m.call('economy', p, action='toolUse', tool=code,
                                                     targets=targets or [], note=note))


def charges(p, code):
    tools = n.accepted('read charges ' + code, n.eco(p, 'toolsGet')).get('tools', [])
    return next((t.get('charges') for t in tools if t.get('code') == code), None)


def buy(p, code):
    key = h.aid()
    before = n.accepted('conflict buy ' + code, n.eco(p, 'toolBuy', tool=code, pack=3, requestId=key))
    after = n.accepted('conflict replay buy ' + code, n.eco(p, 'toolBuy', tool=code, pack=3, requestId=key))
    n.record('conflict idempotent buy ' + code,
             before.get('balance') == after.get('balance') and before.get('tools') == after.get('tools'))


def played_match():
    m = n.Match('interactions', dict(mafia=1, doctor=1, citizen=3), realtime=True)
    m.start()
    mafia = m.role('mafia')
    town = [p for p in m.players if p['role'] == 'citizen']
    speaker, shielded, accused = town
    for p, code in [(speaker, 'lock_door'), (speaker, 'extra_minute'),
                    (shielded, 'vote_shield'), (mafia, 'revote'), (accused, 'appeal')]:
        buy(p, code)
    m.reveal()
    m.night()
    m.discuss()
    use(m, speaker, 'extra_minute')
    use(m, speaker, 'lock_door')
    use(m, shielded, 'vote_shield')
    kept = charges(mafia, 'revote')
    use(m, mafia, 'revote')
    use(m, accused, 'appeal')
    n.accepted('conflict floor bonus claim', m.call('claim_floor', speaker))
    first = m.state().get('speaker_until')
    m.call('release_floor', speaker)
    n.accepted('conflict floor ordinary claim', m.call('claim_floor', speaker))
    second = m.state().get('speaker_until')
    n.record('extra minute spent once beside lock door', bool(first and second) and first > second)
    m.call('release_floor', speaker)

    n.accepted('interaction ballot opens', m.call('open_phase', phase='vote'))
    n.record('interaction phase before ballot', m.state()['phase'] == 'vote', m.state()['phase'])
    # Four votes for the appellant except their own ballot. A purchased revote
    # forces a second round despite a clear winner.
    for p in m.alive():
        target = accused['seat'] if p != accused else mafia['seat']
        n.accepted('first ballot ' + str(p['seat']), m.call('submit_vote', p,
            targetSeat=target, round=1, actionId=h.aid()))
    verdict = n.accepted('revote + appeal first tally', m.call('resolve_vote'))
    state = m.state()
    n.record('revote forced second ballot', state['phase'] == 'vote' and
             (state['public_data'].get('revote') or {}).get('round') == 2)
    # It did open the second round, so the charge stays spent.
    n.record('a revote that worked keeps its charge spent',
             kept is not None and charges(mafia, 'revote') == kept - 1)
    # Two votes to confirm, two abstain; the appellant's own vote is excluded.
    voters = [p for p in m.alive() if p != accused]
    for i, p in enumerate(voters):
        target = accused['seat'] if i < 2 else None
        n.accepted('appeal ballot ' + str(p['seat']), m.call('submit_vote', p,
            targetSeat=target, round=2, actionId=h.aid()))
    n.accepted('appellant abstains', m.call('submit_vote', accused, targetSeat=None,
        round=2, actionId=h.aid()))
    appealed = n.accepted('resolve appealed revote', m.call('resolve_vote'))
    n.record('appeal blocks a weak majority', appealed.get('eliminatedSeat') is None)
    n.accepted('interaction second night opens', m.call('open_phase', phase='night'))
    # Both tools cover the next night: nobody may reach the locked speaker.
    doctor = m.role('doctor')
    n.accepted('mafia targets locked door', m.call('submit_night_action', mafia,
        action='kill', targetSeat=speaker['seat'], actionId=h.aid()))
    n.accepted('doctor protects elsewhere', m.call('submit_night_action', doctor,
        action='protect', targetSeat=shielded['seat'], actionId=h.aid()))
    morning = n.accepted('resolve locked night', m.call('resolve_night'))
    n.record('lock door blocks kill despite extra minute', morning.get('victimSeat') is None)
    m.discuss()
    m.vote(mafia['seat'])
    m.finish_town()
    m.close()


def tied_match():
    m = n.Match('natural_tie', dict(mafia=1, doctor=1, citizen=3),
                flags={'dayTieRule': 'revote'}, realtime=True)
    m.start()
    mafia = m.role('mafia')
    decoy = m.role('citizen')
    # A revote bought on a ballot the room's own rule sends to a second round
    # anyway changes nothing, so its charge comes back.
    buyer = next(p for p in m.players if p['role'] == 'citizen' and p != decoy)
    buy(buyer, 'revote')
    m.reveal(); m.night(); m.discuss()
    kept = charges(buyer, 'revote')
    use(m, buyer, 'revote')
    n.accepted('natural tie ballot opens', m.call('open_phase', phase='vote'))
    voters = m.alive()
    # 2-2-1 abstention. A voter cannot vote for themselves.
    plan = {mafia['seat']: decoy['seat'], decoy['seat']: mafia['seat']}
    rest = [x for x in voters if x != mafia and x != decoy]
    for i, x in enumerate(rest):
        plan[x['seat']] = (mafia['seat'], decoy['seat'])[i] if i < 2 else None
    for p in voters:
        target = plan[p['seat']]
        p['_target'] = target
        n.accepted('tie ballot ' + str(p['seat']), m.call('submit_vote', p,
            targetSeat=target, round=1, actionId=h.aid()))
    n.accepted('resolve natural tie', m.call('resolve_vote'))
    state = m.state()
    tied = (state['public_data'].get('revote') or {}).get('tiedSeats', [])
    n.record('natural tie opens two-candidate revote', state['phase'] == 'vote' and
             set(tied) == {mafia['seat'], decoy['seat']})
    n.record('a revote the tie rule made pointless is refunded',
             kept is not None and charges(buyer, 'revote') == kept)
    for p in voters:
        target = mafia['seat'] if p != mafia else decoy['seat']
        n.accepted('tie second ballot ' + str(p['seat']), m.call('submit_vote', p,
            targetSeat=target, round=2, actionId=h.aid()))
    verdict = n.accepted('resolve natural revote', m.call('resolve_vote'))
    n.record('natural revote removes mafia', verdict.get('eliminatedSeat') == mafia['seat'])
    m.finish_town(); m.close()


def unanimous_match():
    m = n.Match('unanimous_revote', dict(mafia=1, doctor=1, citizen=3),
                flags={'abstainAllowed': True}, realtime=False)
    m.start()
    mafia = m.role('mafia')
    buyer = next(p for p in m.players if p['role'] == 'citizen')
    buy(buyer, 'revote')
    m.reveal(); m.night(); m.discuss()
    kept = charges(buyer, 'revote')
    use(m, buyer, 'revote')
    # One candidate only: nothing to narrow to, the Mafioso goes in round one.
    verdict = m.vote(mafia['seat'])
    n.record('a unanimous ballot ignores a bought revote',
             verdict.get('eliminatedSeat') == mafia['seat'], verdict.get('error'))
    n.record('the unused revote charge comes back',
             kept is not None and charges(buyer, 'revote') == kept)
    m.finish_town(); m.close()


def race_match():
    """X11/T21: four identical requests at once spend or charge exactly once."""
    m = n.Match('tool_race', dict(mafia=1, doctor=1, citizen=3), realtime=False)
    m.start()
    racer = next(p for p in m.players if p['role'] == 'citizen')
    before = n.accepted('race balance read', n.eco(racer, 'toolsGet')).get('balance')
    key = h.aid()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        buys = list(pool.map(lambda _: n.eco(racer, 'toolBuy', tool='extra_minute', pack=3,
                                             requestId=key), range(4)))
    n.record('four racing buys with one request id all answer',
             all(status == 200 for status, _ in buys), [status for status, _ in buys])
    after = n.accepted('race balance after buys', n.eco(racer, 'toolsGet')).get('balance')
    prices = {d.get('balance') for _, d in buys}
    n.record('one request id is charged once', len(prices) == 1 and after in prices
             and before is not None and after < before, sorted(p for p in prices if p is not None))
    m.reveal(); m.night(); m.discuss()
    kept = charges(racer, 'extra_minute')
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        uses = list(pool.map(lambda _: m.call('economy', racer, action='toolUse',
                                              tool='extra_minute', targets=[]), range(4)))
    won = [d for status, d in uses if status == 200 and not d.get('error')]
    lost = [d.get('error') for status, d in uses if status != 200]
    n.record('one of four racing uses wins', len(won) == 1, lost)
    n.record('the losers are told the limit',
             all(code in ('LIMIT_TOOL', 'LIMIT_PHASE', 'LIMIT_MATCH', 'RATE_LIMITED') for code in lost),
             lost)
    n.record('a racing use spends one charge', kept is not None and charges(racer, 'extra_minute') == kept - 1)
    m.vote(m.role('mafia')['seat'])
    m.finish_town(); m.close()


def main():
    h._POOL_TAKEN[0] = 0
    n.BOTS = [h.anon_session('ConflictBot%d' % i) for i in range(5)]
    if not fund(n.BOTS):
        return
    scenarios = [('interactions_retry', played_match)] if os.environ.get('LIVE_ONLY_INTERACTION') == '1' else [('interactions', played_match), ('natural_tie', tied_match), ('unanimous_revote', unanimous_match), ('tool_race', race_match)]
    for label, scenario in scenarios:
        try:
            scenario()
        except Exception as e:
            n.record(label + ': interrupted', False, type(e).__name__)
        finally:
            for m in n.ACTIVE:
                if m.label == label:
                    for w in m.watches:
                        w.close()
