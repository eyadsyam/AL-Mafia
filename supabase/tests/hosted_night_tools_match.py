"""Live: bought night tools together, the Sniper's two deaths, the double vote,
and the night and day that publish nothing they did not earn.

Run through run_live_suite.py --only=hosted_night_tools_match. Bot-owned rooms
only; every call is a bot's own request. Private answers are read with the
buyer's own token and never written down (labels and codes only).

Rows of docs/specs/18-scenario-matrix.md:
  T25, T8, T12, T13, T14  one hosted pair of nights with doors, faces, shot,
       silence, kill, sense and narrator_whisper at once: lock_door beats
       half_door, a door beats camouflage and impersonate beats camouflage for
       the Detective, half_door stops silence and investigation but not the
       kill or the shot, sense and narrator_whisper answer from the true role.
  N57, N58, W6  a Sniper who shoots a town seat: both die, the morning names
       both and gives no reason, and parity is judged after both deaths.
  T9   double_vote is weight 2 and stacks with a revealed Elder's x3 to 6.
  N53, N54, D3  a Citizen has no night move and no default row at expiry; an
       Elder has no night move and gets one skip row with no target at expiry;
       a quiet night has no trace and a day with no eligible evidence has no
       confrontation.
"""
import json
import os
import subprocess
import time
import uuid
import e2e_match as h
import new_roles_tools_match as n

# Words a morning may not use to say why somebody died or why nobody did.
WHY = ('sniper', 'citizen', 'mafia', 'doctor', 'detective', 'elder', 'silencer', 'missed',
       'miss', 'shot', 'bullet', 'suspect', 'tool', 'lock', 'door', 'camouflage',
       'impersonate', 'sense', 'whisper')
SPENT = ('LIMIT_TOOL', 'LIMIT_PHASE', 'LIMIT_MATCH', 'NO_CHARGES')


def fund(bots):
    # Exact authenticated anonymous bot ids; a fresh ledger key per run.
    key = 'nt-' + uuid.uuid4().hex[:12]
    ids = [str(uuid.UUID(p['id'])) for p in bots]
    sql = 'begin; do $$ declare u uuid; begin foreach u in array array['
    sql += ','.join("'%s'::uuid" % x for x in ids)
    sql += "] loop if not exists(select 1 from auth.users where id=u and is_anonymous) then raise exception 'NOT_TEST_ANON'; end if; "
    sql += "perform pg_advisory_xact_lock(hashtextextended('wallet:'||u::text,91)); "
    sql += "perform public.credit_earned(u,'operator_adjustment',50000,null,'%s'); " % key
    sql += 'end loop; end $$; commit;'
    path = n.ROOT / 'build/live_night_tools_coin_setup.sql'
    path.write_text(sql, encoding='utf-8')
    cmd = ['npx.cmd' if os.name == 'nt' else 'npx', 'supabase', 'db', 'query', '--linked', '-f', str(path)]
    proc = subprocess.run(cmd, cwd=n.ROOT, capture_output=True, timeout=120)
    return n.record('night tools bot coin setup', proc.returncode == 0,
                    'CLI_FAILED' if proc.returncode else None)


def why_leaks(obj):
    text = json.dumps(obj, sort_keys=True, ensure_ascii=False).lower()
    return [w for w in WHY if w in text]


def seats(players):
    return sorted(p['seat'] for p in players)


def move(m, p, action, target=None, bullet=False):
    return m.call('submit_night_action', p, action=action, targetSeat=target,
                  useBullet=bullet, actionId=h.aid())


def buy(p, code, tag):
    return n.accepted(tag + ' buy ' + code, n.eco(p, 'toolBuy', tool=code, pack=1, requestId=h.aid()))


def use(m, p, code, tag, targets=None, note=None):
    return n.accepted(tag + ' use ' + code + ' ' + str(p['seat']), m.call(
        'economy', p, action='toolUse', tool=code, targets=targets or [], note=note))


def abstain_day(m):
    # Everyone abstains: no elimination, the night follows.
    m.vote(None, ballots={})
    n.accepted(m.label + ': night opens', m.call('open_phase', phase='night'))


def night_tool(m, p, code, targets, expect, tag, other):
    """Use a night tool; its answer is the buyer's alone and follows the true role."""
    r = use(m, p, code, tag, targets)
    m.answer_owner[(code, r.get('phaseNumber'), tuple(targets))] = p['id']
    n.record(tag + ' ' + code + ' answers from the true role', r.get('answer') is expect)
    own = m.call('economy', p, action='toolAnswers')[1].get('answers', [])
    n.record(tag + ' ' + code + ' readback is the same', any(
        a.get('tool') == code and a.get('answer') is expect for a in own))
    rows = m.call('economy', other, action='toolAnswers')[1].get('answers', [])
    n.record(tag + ' ' + code + ' answer is not visible to seat ' + str(other['seat']),
             not any(a.get('tool') == code for a in rows))


# ── T9 ──────────────────────────────────────────────────────────────────
def double_vote_match():
    """A revealed Elder with a double vote counts 6; a Citizen's double vote counts 2."""
    m = n.Match('T9 weights', dict(mafia=2, elder=1, citizen=5), flags={'elderEnabled': True})
    m.start()
    elder, mafia = m.role('elder'), [p for p in m.players if p['role'] == 'mafia']
    citizen = next(p for p in m.players if p['role'] == 'citizen')
    for p in (elder, citizen):
        buy(p, 'double_vote', 'T9')
    m.reveal()
    m.night()
    m.discuss()
    n.accepted('T9 elder reveals', m.call('reveal_elder', elder))
    use(m, elder, 'double_vote', 'T9')
    use(m, citizen, 'double_vote', 'T9')
    n.refused('T9 one double vote per match', m.call('economy', elder, action='toolUse',
              tool='double_vote', targets=[]), list(SPENT))
    verdict = m.vote(None, ballots={elder['seat']: mafia[0]['seat'], citizen['seat']: mafia[1]['seat']})
    tally = {int(k): v for k, v in (verdict.get('tally') or {}).items()}
    n.record('T9 the verdict reports 6 for the Elder and 2 for the Citizen',
             tally == {mafia[0]['seat']: 6, mafia[1]['seat']: 2}, sorted(tally.items()))
    n.record('T9 the heavier side is eliminated', verdict.get('eliminatedSeat') == mafia[0]['seat'],
             verdict.get('eliminatedSeat'))
    shown = (m.state()['public_data'].get('lastVote') or {}).get('tally') or {}
    n.record('T9 the room state shows the same tally',
             {int(k): v for k, v in shown.items()} == tally)
    m.close()


# ── N57, N58, W6 ────────────────────────────────────────────────────────
def sniper_match(label, rows, counts, victim_role, parity):
    m = n.Match(label, counts, flags={'sniperEnabled': True})
    m.start()
    m.reveal()
    sniper = m.role('sniper')
    target = next(p for p in m.players if p['role'] == victim_role)
    n.record(label + ': no outcome before the night', m.state()['public_data'].get('outcome') is None)
    shot = target['seat']
    morning = m.night(shot=shot, protect=shot)
    both = sorted([shot, sniper['seat']])
    n.record(label + ': the morning names both deaths', morning.get('victimSeats') == both, both)
    gone = seats([p for p in m.players if p not in m.alive()])
    n.record(label + ': the target and the Sniper are both out', gone == both, gone)
    published = m.state()['public_data'].get('morning') or {}
    n.record(label + ': the public morning gives no reason',
             not why_leaks(published) and not why_leaks({k: v for k, v in morning.items() if k != 'outcome'}),
             why_leaks(published))
    after = m.state()
    outcome = after['public_data'].get('outcome')
    if parity:
        n.record(label + ': parity after both deaths gives the Mafia the match',
                 outcome == 'mafia' and morning.get('outcome') == 'mafia', outcome)
        n.record(label + ': it shows in a morning, not yet a result', after['phase'] == 'morning', after['phase'])
        n.accepted(label + ': the morning opens the result', m.call('open_phase', phase='result'))
        n.record(label + ': then the result', m.state()['phase'] == 'result')
    else:
        n.record(label + ': no parity, the match goes on', outcome is None and after['phase'] == 'morning', outcome)
        m.discuss()
        n.record(label + ': the day opens', m.state()['phase'] == 'discuss')
    m.close()


# ── T25, T8, T12, T13, T14 ──────────────────────────────────────────────
def doors_match():
    m = n.Match('T25 doors', dict(mafia=1, silencer=1, detective=1, sniper=1, doctor=1, citizen=5),
                flags={'silencerEnabled': True, 'sniperEnabled': True})
    m.start()
    mf, sl, de = m.role('mafia'), m.role('silencer'), m.role('detective')
    sn, dr = m.role('sniper'), m.role('doctor')
    keep, shot, killed, face, last = [p for p in m.players if p['role'] == 'citizen']
    m.reveal()
    m.night(protect=keep['seat'])
    m.discuss()
    tag = 'T25 day 1'
    # Covers night 2: a lock+half+camouflage seat, two half-door seats, a disguised Mafioso.
    for code in ('lock_door', 'half_door', 'camouflage'):
        buy(keep, code, tag)
    buy(shot, 'half_door', tag)
    buy(killed, 'half_door', tag)
    buy(mf, 'impersonate', tag)
    buy(mf, 'camouflage', tag)
    buy(dr, 'sense', tag)
    buy(dr, 'narrator_whisper', tag)
    buy(face, 'narrator_whisper', tag)
    for code in ('lock_door', 'half_door', 'camouflage'):
        use(m, keep, code, tag)
    use(m, shot, 'half_door', tag)
    use(m, killed, 'half_door', tag)
    use(m, mf, 'impersonate', tag, note='citizen')
    use(m, mf, 'camouflage', tag)
    abstain_day(m)

    # Night 2: sense and narrator first, then the moves.
    tag = 'T25 night 2'
    night_tool(m, dr, 'sense', [mf['seat'], keep['seat'], killed['seat']], True, 'T12 ' + tag, last)
    night_tool(m, face, 'narrator_whisper', [keep['seat'], shot['seat']], False, 'T14 ' + tag, last)
    n.accepted(tag + ': mafia kills a half-door seat', move(m, mf, 'kill', killed['seat']))
    n.accepted(tag + ': silencer silences the locked seat', move(m, sl, 'silence', keep['seat']))
    n.accepted(tag + ': sniper shoots a half-door seat', move(m, sn, 'suspect', shot['seat'], True))
    n.accepted(tag + ': doctor covers the detective', move(m, dr, 'protect', de['seat']))
    seen = n.accepted(tag + ': detective looks at the locked, half-door, camouflaged seat',
                      move(m, de, 'investigate', keep['seat']))
    n.record('T25 door beats camouflage for the Detective, lock over half-door',
             seen.get('revealedRole') == 'unreachable')
    morning = n.accepted(tag + ': resolve', m.call('resolve_night'))
    n.record('T8 half_door does not stop the kill', killed['seat'] in morning.get('victimSeats', []),
             morning.get('victimSeats'))
    n.record('T8 half_door does not stop the Sniper shot: seat and Sniper both die',
             shot['seat'] in morning.get('victimSeats', []) and sn['seat'] in morning.get('victimSeats', []),
             morning.get('victimSeats'))
    n.record('T8 half_door and lock_door stop the silence', morning.get('silencedSeat') is None,
             morning.get('silencedSeat'))
    n.record('T8 the locked seat lives', keep['seat'] in seats(m.alive()))
    published = m.state()['public_data'].get('morning') or {}
    n.record('T25 the public morning gives no reason', not why_leaks(published), why_leaks(published))

    # Night 3: a face over camouflage, a lock over a kill, a silence nothing stops.
    m.discuss()
    tag = 'T25 day 2'
    buy(last, 'lock_door', tag)
    buy(last, 'half_door', tag)
    buy(face, 'impersonate', tag)
    buy(face, 'camouflage', tag)
    use(m, last, 'lock_door', tag)
    use(m, last, 'half_door', tag)
    use(m, face, 'impersonate', tag, note='mafia')
    use(m, face, 'camouflage', tag)
    abstain_day(m)
    tag = 'T25 night 3'
    night_tool(m, dr, 'narrator_whisper', [face['seat'], last['seat']], False, 'T14 ' + tag, keep)
    n.accepted(tag + ': mafia kills the locked seat', move(m, mf, 'kill', last['seat']))
    n.accepted(tag + ': silencer silences the faced seat', move(m, sl, 'silence', face['seat']))
    n.accepted(tag + ': doctor covers someone else', move(m, dr, 'protect', keep['seat']))
    seen = n.accepted(tag + ': detective looks at the faced, camouflaged seat',
                      move(m, de, 'investigate', face['seat']))
    n.record('T13 impersonate beats camouflage: the Detective is told the chosen face',
             seen.get('revealedRole') == 'mafia')
    morning = n.accepted(tag + ': resolve', m.call('resolve_night'))
    n.record('T8 lock_door stops the kill, half_door beside it or not', morning.get('victimSeat') is None
             and morning.get('victimSeats') == [], morning.get('victimSeats'))
    n.record('T8 a silence on an unprotected seat lands', morning.get('silencedSeat') == face['seat'],
             morning.get('silencedSeat'))
    n.record('T13 the narrator still says the faced seat is town',
             face['seat'] in seats(m.alive()) and last['seat'] in seats(m.alive()))
    m.close()


# ── N53, N54, D3 ────────────────────────────────────────────────────────
def wait_for_deadline(m):
    offset = n.server_offset()
    end = m.state().get('phase_ends_at')
    stamp = n.dt.datetime.fromisoformat(end.replace('Z', '+00:00')).timestamp()
    while True:
        left = stamp - (time.time() + offset) + 2
        if left <= 0:
            return
        time.sleep(min(left, 15))


def quiet_night(m):
    """Every acting seat answers; the Mafia skip, so nobody is killed."""
    for p in m.alive():
        role = p['role']
        if role in ('citizen', 'elder'):
            continue
        if role == 'doctor':
            # Never last night's cover again (RL3): take the first seat that is accepted.
            for x in m.alive():
                if x != p and move(m, p, 'protect', x['seat'])[0] == 200:
                    break
        else:
            n.accepted('D3 quiet night ' + role, move(m, p, 'skip'))
    return n.accepted('D3 quiet night resolves', m.call('resolve_night'))


def expiry_match():
    m = n.Match('N53 expiry', dict(mafia=2, doctor=1, detective=1, elder=1, citizen=2),
                flags={'elderEnabled': True})
    m.start()
    m.reveal()
    night = m.state()['phase_number']
    elder = m.role('elder')
    citizens = [p for p in m.players if p['role'] == 'citizen']
    acting = [p for p in m.players if p['role'] in ('mafia', 'doctor', 'detective')]
    quiet = [elder] + citizens
    aim = acting[0]['seat']
    for p in quiet:
        status, data = move(m, p, 'suspect', aim)
        n.record('N53 seat %d: a legacy night move is answered and nothing is kept' % p['seat'],
                 status == 200 and not data.get('error') and data.get('bulletSpent') is False,
                 data.get('error'))

    def rows(p):
        status, got = h.rest('night_actions?select=night,action&room_id=eq.%s&night=eq.%d' % (m.id, night), p)
        return got if status == 200 else None

    n.record('N53 Citizen and Elder hold no night row before expiry',
             all(rows(p) == [] for p in quiet))
    wait_for_deadline(m)
    guest = m.players[1]
    for _ in range(6):
        status, data = m.call('advance_phase', guest)
        if status == 200 or 'not expired' not in str(data.get('message', '')):
            break
        time.sleep(3)
    n.record('N53 the night expires into defaults', status == 200 and data.get('applied') == 'night-defaults',
             data.get('error'))
    # N54 (doc 18; 17 C61, D5): the Elder has no night move online, and expiry
    # writes one skip row with no target. Read with the Elder's own token, as
    # every other row read here is (night_actions_own_read).
    status, elder_rows = h.rest(
        'night_actions?select=night,action,target_id&room_id=eq.%s&night=eq.%d' % (m.id, night), elder)
    n.record('N54 the Elder gets one skip row on expiry',
             status == 200 and len(elder_rows) == 1 and elder_rows[0].get('action') == 'skip'
             and elder_rows[0].get('target_id') is None and elder_rows[0].get('night') == night,
             elder_rows if status == 200 else status)
    n.record('N53 no Citizen gets a default row', all(rows(p) == [] for p in citizens))
    n.record('N53 each acting seat has exactly one default row',
             all(len(rows(p) or []) == 1 for p in acting), [p['seat'] for p in acting])
    n.accepted('N53 the expired night resolves', m.call('resolve_night', guest))
    m.discuss()
    abstain_day(m)

    # A quiet second night: no kill, no save, so no trace to publish.
    morning = quiet_night(m)
    published = m.state()['public_data'].get('morning') or {}
    trace = published.get('trace')
    n.record('D3 a quiet night kills and saves nobody', morning.get('victimSeat') is None
             and morning.get('victimSeats') == [] and morning.get('someoneSavedUnnamed') is False)
    n.record('N53 a quiet night publishes no trace',
             trace is None or (trace.get('type') == 't0' and trace.get('subjectSeat') is None
                               and trace.get('targetSeat') is None and trace.get('count') is None),
             None if trace is None else trace.get('type'))
    # Day two with no vote history of substance and no whisper: nothing to confront.
    data = n.accepted('D3 the day opens through the confrontation call', m.call('generate_confrontation'))
    after = m.state()
    n.record('D3 no eligible evidence publishes no confrontation', data.get('confrontation') is None
             and not after['public_data'].get('confrontation'), after['phase'])
    n.record('D3 the day goes straight to discussion', after['phase'] == 'discuss', after['phase'])
    m.close()


def main():
    h._POOL_TAKEN[0] = 0
    n.BOTS = [h.anon_session('LiveBot%d' % i) for i in range(10)]
    if not fund(n.BOTS):
        return
    # The host unlocks the new roles; a repeat purchase is not a failure here,
    # a missing unlock shows as a refused start.
    for item in ('role_silencer', 'role_sniper', 'role_elder'):
        n.eco(n.BOTS[0], 'buy', item=item)
    scenarios = [
        ('T9', double_vote_match),
        ('W6', lambda: sniper_match('W6 N57 sniper shoots a citizen', 'W6', dict(mafia=3, sniper=1, citizen=4),
                                    'citizen', True)),
        ('N58 doctor', lambda: sniper_match('N58 sniper shoots the doctor', 'N58',
                                            dict(mafia=2, sniper=1, doctor=1, detective=1, citizen=2),
                                            'doctor', False)),
        ('N58 detective', lambda: sniper_match('N58 sniper shoots the detective', 'N58',
                                               dict(mafia=2, sniper=1, doctor=1, detective=1, citizen=2),
                                               'detective', False)),
        ('T25', doors_match),
        ('N53', expiry_match),
    ]
    for name, scenario in scenarios:
        try:
            scenario()
        except Exception as e:
            n.record(name + ': scenario interrupted', False, type(e).__name__)
        finally:
            for m in n.ACTIVE:
                if not m.beat_stop.is_set():
                    m.beat_stop.set()
                    try:
                        m.call('close_room')
                    except Exception:
                        pass
                for w in m.watches:
                    w.close()
