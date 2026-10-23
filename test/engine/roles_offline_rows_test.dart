import 'package:flutter/widgets.dart'
    show MediaQuery, MediaQueryData, SizedBox, Size, Text, ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/legal_moves.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:mafia_master/engine/presets.dart';
import 'package:mafia_master/engine/win_check.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_flow.dart';
import 'package:mafia_master/ui/screens/night/night_action_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/optional_roles.dart';
import 'package:mafia_master/ui/screens/setup/role_rows.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/artwork.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Offline rows of `docs/plans/audit/M2-roles.md` that had no proof: M2-17,
/// M2-65, M2-73, M2-91, M2-101 and M2-113.
///
/// Engine rows drive [MatchEngine] the way `roles_offline_gaps_test` does.
/// Screen rows drive the real [MatchController] and then pump [MatchFlow] on
/// the phase the table would be looking at, so the morning and the vote reveal
/// are what the shipped screens print. Every sentence is taken from the app's
/// own l10n lookups (`arStrings`, `EngineCopy`), never typed here.
///
/// Doc 05: the night death of a role is hidden unless the host chose the fast
/// preset (`revealNightVictimRole`); a day elimination always names its role.
const _plain = MatchSettings(
  quietNightEnabled: false,
  traceEnabled: false,
  confrontationEnabled: false,
  abstainAllowed: true,
);
final _sniperOn = _plain.copyWith(sniperEnabled: true);
final _elderAndSniperOn = _plain.copyWith(
  elderEnabled: true,
  sniperEnabled: true,
);

/// The «سريعة» preset (the one that tells a night victim's role), with the
/// layers this file does not exercise switched off and the Sniper on.
final _fastSniper = MatchPreset.fast.settings.copyWith(
  quietNightEnabled: false,
  traceEnabled: false,
  confrontationEnabled: false,
  whisperEnabled: false,
  sniperEnabled: true,
);

const _withSniper = {
  Role.mafia: 2,
  Role.doctor: 1,
  Role.sniper: 1,
  Role.citizen: 3,
};

typedef _Move = (NightActionKind, int, bool);

// -----------------------------------------------------------------------------
// Engine helpers
// -----------------------------------------------------------------------------

MatchEngine _start(
  Map<Role, int> counts,
  MatchSettings settings, {
  int seed = 3,
}) {
  final n = counts.values.fold<int>(0, (sum, count) => sum + count);
  final e = MatchEngine(clock: Clocks.monotonic());
  e.start(
    names: [for (var i = 0; i < n; i++) 'P$i'],
    roleCounts: counts,
    settings: settings,
    seed: seed,
  );
  for (var i = 0; i < n; i++) {
    e.revealFor(i);
    e.confirmRevealed();
  }
  return e;
}

List<int> _seats(MatchEngine e, Role role) => [
  for (final p in e.match.players)
    if (p.role == role) p.seat,
];
int _seat(MatchEngine e, Role role) => _seats(e, role).first;

/// One night. [choice] answers per seat; a seat it answers null for skips,
/// except the Doctor, who (having no skip) covers the first other living seat.
/// Every scenario that has a Mafia kill names the Doctor's cover itself.
void _night(MatchEngine e, _Move? Function(int seat, Role role) choice) {
  e.beginNight();
  while (e.match.currentActorSeat != null) {
    final actor = e.match.currentActorSeat!;
    final role = e.match.players[actor].role;
    final move = choice(actor, role);
    if (move != null) {
      e.submitNightAction(
        seat: actor,
        kind: move.$1,
        targetSeat: move.$2,
        useBullet: move.$3,
      );
    } else if (role == Role.doctor) {
      final target = e.match.players
          .firstWhere(
            (p) => p.status == PlayerStatus.alive && p.seat != actor,
          )
          .seat;
      e.submitNightAction(
        seat: actor,
        kind: NightActionKind.protect,
        targetSeat: target,
      );
    } else {
      e.skipNightAction(seat: actor);
    }
  }
}

void _toVoting(MatchEngine e) {
  e.beginDay();
  while (e.match.phase == GamePhase.openingRound) {
    final actor = e.match.currentActorSeat!;
    final target = e.match.players
        .firstWhere((p) => p.status == PlayerStatus.alive && p.seat != actor)
        .seat;
    e.submitOpeningAccusation(seat: actor, targetSeat: target);
  }
  if (e.match.phase == GamePhase.confrontation) e.endConfrontation();
  e.beginVoting();
}

/// Everybody votes for [target]; the target themselves abstains.
void _ballot(MatchEngine e, int? target) {
  while (e.match.phase == GamePhase.voting) {
    final actor = e.match.currentActorSeat!;
    e.submitVote(
      seat: actor,
      voterSeat: actor,
      targetSeat: actor == target ? null : target,
    );
  }
}

// -----------------------------------------------------------------------------
// Screen helpers (the real controller and the real MatchFlow)
// -----------------------------------------------------------------------------

/// Starts and deals a match through the controller, stopping at the lobby the
/// first night opens from.
Future<MatchController> _dealt(
  ProviderContainer container, {
  required Map<Role, int> counts,
  required MatchSettings settings,
  int seed = 3,
}) async {
  final c = container.read(matchControllerProvider.notifier);
  final n = counts.values.fold<int>(0, (sum, count) => sum + count);
  c.startMatch(
    names: [for (var i = 0; i < n; i++) 'P$i'],
    roleCounts: counts,
    settings: settings,
    seed: seed,
  );
  while (c.snapshot.currentActorSeat != null) {
    await c.revealCurrentRole();
    c.confirmRevealed();
  }
  return c;
}

/// A whole night through the controller's transport, ending on the morning
/// report (`controller.resolveNight`), exactly where the table would be.
Future<void> _nightVia(
  MatchController c,
  _Move? Function(int seat, Role role) choice,
) async {
  c.beginNight();
  while (c.engine.match.currentActorSeat != null) {
    final seat = c.engine.match.currentActorSeat!;
    final role = c.engine.match.players[seat].role;
    final move = choice(seat, role);
    if (move != null) {
      await c.transport.submitNightAction(
        seat: seat,
        kind: move.$1,
        targetSeat: move.$2,
        useBullet: move.$3,
      );
    } else if (role == Role.doctor) {
      final target = c.engine.match.players
          .firstWhere(
            (p) => p.status == PlayerStatus.alive && p.seat != seat,
          )
          .seat;
      await c.transport.submitNightAction(
        seat: seat,
        kind: NightActionKind.protect,
        targetSeat: target,
      );
    } else {
      await c.transport.submitNightAction(
        seat: seat,
        kind: nightActionFor(role),
        targetSeat: null,
      );
    }
  }
  c.resolveNight();
}

/// The day, up to and including the tally: [target] is voted out.
Future<void> _voteVia(MatchController c, int target) async {
  c.beginDay();
  c.beginVoting();
  while (c.engine.match.phase == GamePhase.voting) {
    final actor = c.engine.match.currentActorSeat!;
    await c.transport.submitVote(
      seat: actor,
      targetSeat: actor == target ? null : target,
    );
  }
  c.resolveDayVote();
}

Future<void> _pumpFlow(WidgetTester tester, ProviderContainer container) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MatchFlow(onExit: () {}, onAnalytics: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

String _roleName(Role role) => EngineCopy.roleName(arStrings, role);

/// The sentence the morning screen prints for its dead.
String _morningFact(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('morning_fact')))
    .data!;

/// No role is named for any of [names] on the morning screen: the whole
/// «{name} كان {role}» line is absent for every role there is.
void _expectNoNightRole(Iterable<String> names) {
  for (final name in names) {
    for (final role in Role.values) {
      expect(
        find.text(arStrings.victimWasRole(name, _roleName(role))),
        findsNothing,
        reason: '$name must not be named as ${role.name} by a night death',
      );
    }
  }
}

ProviderContainer _table() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// `testWidgets`, with the tree always taken down before the container goes.
///
/// A failing expectation leaves the pumped tree mounted. The container's own
/// teardown then disposes the providers first, and the next test's first
/// frame unmounts `MatchFlow`, whose post-frame privacy reset writes to a
/// disposed provider: one real failure would surface as errors in the tests
/// that come after it. Unmounting here keeps a failure where it happened.
void _screenTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}

void main() {
  // ---------------------------------------------------------------------------
  // M2-17: one night, two deaths
  // ---------------------------------------------------------------------------
  group('M2-17', () {
    /// Both Mafia kill a citizen; the Sniper shoots the second Mafioso. Two
    /// deaths, the Sniper (a correct shot) survives.
    _Move? Function(int, Role) killAndShot(MatchEngine e) {
      final mafia = _seats(e, Role.mafia);
      final citizen = _seats(e, Role.citizen).first;
      return (seat, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, citizen, false),
        Role.sniper => (NightActionKind.suspect, mafia.last, true),
        Role.doctor => (NightActionKind.protect, mafia.first, false),
        _ => null,
      };
    }

    test('a kill and a sniper shot in one night: the report and the log '
        'carry every death', () {
      final e = _start(_withSniper, _sniperOn);
      final mafia = _seats(e, Role.mafia);
      final citizen = _seats(e, Role.citizen).first;
      final sniper = _seat(e, Role.sniper);
      _night(e, killAndShot(e));

      final report = e.resolveNight();
      final dead = [citizen, mafia.last]..sort();
      expect(report.victimSeats, dead);
      expect(report.victimSeat, dead.first);
      expect(e.match.eventLog.whereType<NightResolved>().last.victimSeats, dead);
      for (final seat in dead) {
        expect(e.match.players[seat].status, PlayerStatus.dead);
      }
      expect(e.match.players[sniper].status, PlayerStatus.alive);
      expect(e.match.phase, GamePhase.morning);
    });

    test('parity is decided after every death of the night, not after the '
        'first', () {
      // Alive going in: the lone Mafioso, the Sniper and one citizen. The
      // Mafia kill alone would leave Mafia 1 against Sniper 1 (parity, a
      // Mafia win). The Sniper shoots the Mafioso the same night, so after all
      // the deaths no Mafia is left and the town wins.
      final counts = {Role.mafia: 1, Role.sniper: 1, Role.citizen: 5};
      MatchEngine table() {
        final e = _start(counts, _sniperOn);
        final citizens = _seats(e, Role.citizen);
        for (final seat in citizens.take(4)) {
          e.removePlayer(seat);
        }
        expect(e.match.outcome, isNull);
        return e;
      }

      final both = table();
      final mafia = _seat(both, Role.mafia);
      final last = _seats(both, Role.citizen).firstWhere(
        (s) => both.match.players[s].status == PlayerStatus.alive,
      );
      _night(
        both,
        (seat, role) => switch (role) {
          Role.mafia => (NightActionKind.mafiaVote, last, false),
          Role.sniper => (NightActionKind.suspect, mafia, true),
          _ => null,
        },
      );
      expect(both.resolveNight().victimSeats, containsAll([last, mafia]));
      expect(both.outcomeAfterNight(), Alignment.town);
      expect(both.concludeAfterNight(), Alignment.town);
      expect(both.match.outcome?.winner, Alignment.town);

      // The same kill with no shot: parity, so the Mafia win.
      final killOnly = table();
      _night(
        killOnly,
        (seat, role) => role == Role.mafia
            ? (
                NightActionKind.mafiaVote,
                _seats(killOnly, Role.citizen).firstWhere(
                  (s) => killOnly.match.players[s].status == PlayerStatus.alive,
                ),
                false,
              )
            : null,
      );
      killOnly.resolveNight();
      expect(killOnly.concludeAfterNight(), Alignment.mafia);
    });

    test('a night with two deaths does not end the match before the morning '
        'is read', () {
      // Nobody is removed ahead of time: two deaths from seven leave play on.
      final e = _start(_withSniper, _sniperOn);
      _night(e, killAndShot(e));
      e.resolveNight();
      expect(e.match.phase, GamePhase.morning);
      expect(e.match.outcome, isNull);
      expect(e.outcomeAfterNight(), isNull);
    });

    _screenTest('classic: the morning lists both deaths and names no role', (
      tester,
    ) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(container, counts: _withSniper, settings: _sniperOn);
      await _nightVia(c, killAndShot(c.engine));
      final mafia = _seats(c.engine, Role.mafia);
      final citizen = _seats(c.engine, Role.citizen).first;
      final dead = [citizen, mafia.last]..sort();

      await _pumpFlow(tester, container);

      expect(
        _morningFact(tester),
        arStrings.lostPlayerLastNight([for (final s in dead) 'P$s'].join(' · ')),
      );
      _expectNoNightRole([for (final s in dead) 'P$s']);
    });

    _screenTest('fast preset: both deaths are listed and the first death is '
        'told with its role', (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(
        container,
        counts: _withSniper,
        settings: _fastSniper,
      );
      expect(c.settings.revealNightVictimRole, isTrue);
      await _nightVia(c, killAndShot(c.engine));
      final mafia = _seats(c.engine, Role.mafia);
      final citizen = _seats(c.engine, Role.citizen).first;
      final dead = [citizen, mafia.last]..sort();

      await _pumpFlow(tester, container);

      expect(
        _morningFact(tester),
        arStrings.lostPlayerLastNight([for (final s in dead) 'P$s'].join(' · ')),
      );
      final first = dead.first;
      expect(
        find.text(
          arStrings.victimWasRole(
            'P$first',
            _roleName(c.engine.match.players[first].role),
          ),
        ),
        findsOneWidget,
      );
    });

    // `testWidgets` takes a bool for `skip`; `group` takes the reason string.
    group('fast preset, second death', () {
      _screenTest(
        'the role of every night death is told, not only the first',
        (tester) async {
          await loadArtwork(tester);
          final container = _table();
          final c = await _dealt(
            container,
            counts: _withSniper,
            settings: _fastSniper,
          );
          await _nightVia(c, killAndShot(c.engine));
          final mafia = _seats(c.engine, Role.mafia);
          final citizen = _seats(c.engine, Role.citizen).first;
          final dead = [citizen, mafia.last]..sort();

          await _pumpFlow(tester, container);

          for (final seat in dead) {
            expect(
              find.text(
                arStrings.victimWasRole(
                  'P$seat',
                  _roleName(c.engine.match.players[seat].role),
                ),
              ),
              findsOneWidget,
              reason:
                  'the fast preset tells a night death its role (seat $seat)',
            );
          }
        },
      );
    });
  });

  // ---------------------------------------------------------------------------
  // M2-65: the Detective's death
  // ---------------------------------------------------------------------------
  group('M2-65', () {
    const counts = {Role.mafia: 1, Role.detective: 1, Role.citizen: 3};

    test('the Detective is a town body in win_check: his night death brings '
        'the Mafia to parity', () {
      final e = _start(counts, _plain);
      final citizens = _seats(e, Role.citizen);
      final detective = _seat(e, Role.detective);
      e.removePlayer(citizens[0]);
      e.removePlayer(citizens[1]);

      // Alive: Mafia, Detective, one citizen. The Detective keeps the town
      // ahead, and taking him out of the count is what flips the result.
      expect(WinChecker.checkWin(e.match), isNull);
      expect(
        WinChecker.outcomeFor([
          for (final p in e.match.players)
            p.seat == detective ? p.copyWith(status: PlayerStatus.dead) : p,
        ]),
        Alignment.mafia,
      );

      _night(
        e,
        (seat, role) => role == Role.mafia
            ? (NightActionKind.mafiaVote, detective, false)
            : null,
      );
      expect(e.resolveNight().victimSeats, [detective]);
      expect(e.concludeAfterNight(), Alignment.mafia);
      expect(e.match.outcome?.winner, Alignment.mafia);
    });

    test('a vote death reveals the Detective and the match plays on', () {
      final e = _start(counts, _plain);
      final detective = _seat(e, Role.detective);
      _night(e, (_, _) => null);
      e.resolveNight();
      _toVoting(e);
      _ballot(e, detective);
      final result = e.resolveDayVote();
      expect(result.eliminatedSeat, detective);
      expect(result.eliminatedRole, Role.detective);
      expect(e.winCheck(), isNull);
    });

    _screenTest('classic: a night death of the Detective is not named by role '
        'on the morning screen', (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(container, counts: counts, settings: _plain);
      final detective = _seat(c.engine, Role.detective);
      await _nightVia(
        c,
        (seat, role) => role == Role.mafia
            ? (NightActionKind.mafiaVote, detective, false)
            : null,
      );
      expect(c.settings.revealNightVictimRole, isFalse);

      await _pumpFlow(tester, container);

      expect(_morningFact(tester), arStrings.lostPlayerLastNight('P$detective'));
      _expectNoNightRole(['P$detective']);
    });

    _screenTest('a vote death of the Detective shows the role on the reveal '
        'screen', (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(container, counts: counts, settings: _plain);
      final detective = _seat(c.engine, Role.detective);
      await _nightVia(c, (_, _) => null);
      await _voteVia(c, detective);
      expect(c.engine.match.phase, GamePhase.reveal);

      await _pumpFlow(tester, container);

      expect(
        find.text(arStrings.wasRole(_roleName(Role.detective))),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // M2-73: the Elder
  // ---------------------------------------------------------------------------
  group('M2-73', () {
    const counts = {
      Role.mafia: 2,
      Role.elder: 1,
      Role.sniper: 1,
      Role.citizen: 3,
    };

    _screenTest('the Elder\'s reveal is public: the shared snapshot lists the '
        'seat, the ballot weighs three, nothing shows it earlier', (
      tester,
    ) async {
      final container = _table();
      final c = await _dealt(
        container,
        counts: counts,
        settings: _elderAndSniperOn,
      );
      final elder = _seat(c.engine, Role.elder);
      expect(c.snapshot.revealedElderSeats, isEmpty);

      // Not at night, in either mode.
      c.beginNight();
      expect(() => c.engine.revealElder(elder), throwsStateError);
      while (c.engine.match.currentActorSeat != null) {
        final seat = c.engine.match.currentActorSeat!;
        await c.transport.submitNightAction(
          seat: seat,
          kind: nightActionFor(c.engine.match.players[seat].role),
          targetSeat: null,
        );
      }
      c.resolveNight();
      c.beginDay();
      expect(c.snapshot.revealedElderSeats, isEmpty);
      expect(c.engine.voteWeightFor(elder), 1);

      await c.revealElder(elder);
      expect(c.snapshot.revealedElderSeats, {elder});
      expect(c.engine.voteWeightFor(elder), 3);

      // Once only: a second tap adds nothing.
      await c.revealElder(elder);
      expect(c.engine.match.eventLog.whereType<ElderRevealed>(), hasLength(1));
      expect(c.snapshot.revealedElderSeats, {elder});
    });

    test('the Sniper shooting the Elder kills both (rule_matrix C62)', () {
      final e = _start(counts, _elderAndSniperOn);
      final elder = _seat(e, Role.elder);
      final sniper = _seat(e, Role.sniper);
      _night(
        e,
        (seat, role) => role == Role.sniper
            ? (NightActionKind.suspect, elder, true)
            : null,
      );
      final report = e.resolveNight();
      expect(report.victimSeats, containsAll([elder, sniper]));
      expect(report.victimSeats, hasLength(2));
      expect(e.match.players[elder].status, PlayerStatus.dead);
      expect(e.match.players[sniper].status, PlayerStatus.dead);
    });

    test('a vote death reveals the Elder', () {
      final e = _start(counts, _elderAndSniperOn);
      final elder = _seat(e, Role.elder);
      _night(e, (_, _) => null);
      e.resolveNight();
      _toVoting(e);
      _ballot(e, elder);
      final result = e.resolveDayVote();
      expect(result.eliminatedSeat, elder);
      expect(result.eliminatedRole, Role.elder);
    });

    _screenTest('classic: a night death of the Elder is not named by role', (
      tester,
    ) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(
        container,
        counts: counts,
        settings: _elderAndSniperOn,
      );
      final elder = _seat(c.engine, Role.elder);
      await _nightVia(
        c,
        (seat, role) => role == Role.mafia
            ? (NightActionKind.mafiaVote, elder, false)
            : null,
      );

      await _pumpFlow(tester, container);

      expect(_morningFact(tester), arStrings.lostPlayerLastNight('P$elder'));
      _expectNoNightRole(['P$elder']);
    });

    _screenTest('classic: the morning after the Sniper shoots the Elder lists '
        'both deaths and names no role', (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(
        container,
        counts: counts,
        settings: _elderAndSniperOn,
      );
      final elder = _seat(c.engine, Role.elder);
      final sniper = _seat(c.engine, Role.sniper);
      await _nightVia(
        c,
        (seat, role) => role == Role.sniper
            ? (NightActionKind.suspect, elder, true)
            : null,
      );
      final dead = [elder, sniper]..sort();

      await _pumpFlow(tester, container);

      expect(
        _morningFact(tester),
        arStrings.lostPlayerLastNight([for (final s in dead) 'P$s'].join(' · ')),
      );
      _expectNoNightRole([for (final s in dead) 'P$s']);
    });

    _screenTest('a vote death of the Elder shows the role on the reveal screen',
        (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(
        container,
        counts: counts,
        settings: _elderAndSniperOn,
      );
      final elder = _seat(c.engine, Role.elder);
      await _nightVia(c, (_, _) => null);
      await _voteVia(c, elder);
      expect(c.engine.match.phase, GamePhase.reveal);

      await _pumpFlow(tester, container);

      expect(
        find.text(arStrings.wasRole(_roleName(Role.elder))),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // M2-91: the Sniper's death
  // ---------------------------------------------------------------------------
  group('M2-91', () {
    _Move? Function(int, Role) mafiaKills(MatchEngine e, int victim) {
      final mafia = _seats(e, Role.mafia);
      return (seat, role) => switch (role) {
        Role.mafia => (NightActionKind.mafiaVote, victim, false),
        Role.doctor => (NightActionKind.protect, mafia.first, false),
        _ => null,
      };
    }

    _screenTest('classic: the Mafia kill the Sniper at night, the morning '
        'names the seat and no role', (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(container, counts: _withSniper, settings: _sniperOn);
      final sniper = _seat(c.engine, Role.sniper);
      await _nightVia(c, mafiaKills(c.engine, sniper));

      await _pumpFlow(tester, container);

      expect(_morningFact(tester), arStrings.lostPlayerLastNight('P$sniper'));
      _expectNoNightRole(['P$sniper']);
    });

    _screenTest('classic: a missed shot kills the Sniper and the target; both '
        'are named, neither by role', (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(container, counts: _withSniper, settings: _sniperOn);
      final sniper = _seat(c.engine, Role.sniper);
      final citizen = _seats(c.engine, Role.citizen).first;
      await _nightVia(
        c,
        (seat, role) => role == Role.sniper
            ? (NightActionKind.suspect, citizen, true)
            : null,
      );
      final dead = [sniper, citizen]..sort();

      await _pumpFlow(tester, container);

      expect(
        _morningFact(tester),
        arStrings.lostPlayerLastNight([for (final s in dead) 'P$s'].join(' · ')),
      );
      _expectNoNightRole([for (final s in dead) 'P$s']);
    });

    _screenTest('fast preset: the Sniper\'s night death is told with its role',
        (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(
        container,
        counts: _withSniper,
        settings: _fastSniper,
      );
      final sniper = _seat(c.engine, Role.sniper);
      await _nightVia(c, mafiaKills(c.engine, sniper));

      await _pumpFlow(tester, container);

      expect(_morningFact(tester), arStrings.lostPlayerLastNight('P$sniper'));
      expect(
        find.text(arStrings.victimWasRole('P$sniper', _roleName(Role.sniper))),
        findsOneWidget,
      );
    });

    test('a vote death reveals the Sniper', () {
      final e = _start(_withSniper, _sniperOn);
      final sniper = _seat(e, Role.sniper);
      _night(e, (_, _) => null);
      e.resolveNight();
      _toVoting(e);
      _ballot(e, sniper);
      final result = e.resolveDayVote();
      expect(result.eliminatedSeat, sniper);
      expect(result.eliminatedRole, Role.sniper);
    });

    _screenTest('a vote death of the Sniper shows the role on the reveal '
        'screen', (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(container, counts: _withSniper, settings: _sniperOn);
      final sniper = _seat(c.engine, Role.sniper);
      await _nightVia(c, (_, _) => null);
      await _voteVia(c, sniper);
      expect(c.engine.match.phase, GamePhase.reveal);

      await _pumpFlow(tester, container);

      expect(
        find.text(arStrings.wasRole(_roleName(Role.sniper))),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // M2-101: the Citizen
  // ---------------------------------------------------------------------------
  group('M2-101', () {
    const counts = {Role.mafia: 1, Role.citizen: 4};

    test('the Citizen has an explicit skip, which is recorded, and no bullet',
        () {
      final e = _start(counts, _plain);
      final citizen = _seat(e, Role.citizen);
      e.beginNight();
      while (e.match.currentActorSeat != citizen) {
        e.skipNightAction(seat: e.match.currentActorSeat!);
      }
      expect(
        legalMoves(e.match).whereType<SkipNightActionMove>().where(
          (move) => move.seat == citizen,
        ),
        isNotEmpty,
      );
      expect(e.canArmBullet(citizen), isFalse);
      e.skipNightAction(seat: citizen);
      expect(
        e.match.eventLog.whereType<NightActionSkipped>().any(
          (event) => event.actorSeat == citizen,
        ),
        isTrue,
      );
      expect(e.match.eventLog.whereType<BulletSpent>(), isEmpty);
    });

    test('a vote death reveals the Citizen', () {
      final e = _start(counts, _plain);
      final citizen = _seat(e, Role.citizen);
      _night(e, (_, _) => null);
      e.resolveNight();
      _toVoting(e);
      _ballot(e, citizen);
      final result = e.resolveDayVote();
      expect(result.eliminatedSeat, citizen);
      expect(result.eliminatedRole, Role.citizen);
    });

    _screenTest('classic: a night death of a Citizen is not named by role', (
      tester,
    ) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(container, counts: counts, settings: _plain);
      final citizen = _seat(c.engine, Role.citizen);
      await _nightVia(
        c,
        (seat, role) => role == Role.mafia
            ? (NightActionKind.mafiaVote, citizen, false)
            : null,
      );

      await _pumpFlow(tester, container);

      expect(_morningFact(tester), arStrings.lostPlayerLastNight('P$citizen'));
      _expectNoNightRole(['P$citizen']);
    });

    _screenTest('a vote death of a Citizen shows the role on the reveal '
        'screen', (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(container, counts: counts, settings: _plain);
      final citizen = _seat(c.engine, Role.citizen);
      await _nightVia(c, (_, _) => null);
      await _voteVia(c, citizen);
      expect(c.engine.match.phase, GamePhase.reveal);

      await _pumpFlow(tester, container);

      expect(
        find.text(arStrings.wasRole(_roleName(Role.citizen))),
        findsOneWidget,
      );
    });

    _screenTest('the Citizen\'s night turn has no timer: it waits however '
        'long the player takes, and the skip tile ends it', (tester) async {
      await loadArtwork(tester);
      final container = _table();
      final c = await _dealt(container, counts: counts, settings: _plain);
      final citizen = _seat(c.engine, Role.citizen);

      // Walk the phone to the Citizen: everyone before them takes a turn.
      c.beginNight();
      while (c.engine.match.currentActorSeat != citizen) {
        await c.openActorTurn();
        await c.skipNightAction();
        c.passTurn();
      }
      await c.openActorTurn();
      expect(c.state?.actorTurn?.actorRole, Role.citizen);

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: NightActionScreen(onNightComplete: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pad = find.byKey(TurnShell.holdPad);
      final gesture = await tester.startGesture(tester.getCenter(pad));
      await tester.pump();
      await tester.pump(MafiaTiming.defaults.holdToReveal);
      await gesture.up();
      await tester.pumpAndSettle();

      Finder skipTile() => find.byWidgetPredicate(
        (w) => w is NightGridTile && w.choice.isSkip,
      );
      expect(skipTile(), findsOneWidget);
      expect(
        tester.widget<NightGridTile>(skipTile()).choice.label,
        EngineCopy.nightSpecial(arStrings, Role.citizen),
      );

      // Half an hour at the table: nothing expires, nobody is moved on.
      await tester.pump(const Duration(minutes: 30));
      expect(c.engine.match.phase, GamePhase.night);
      expect(c.engine.match.currentActorSeat, citizen);
      expect(
        c.engine.match.eventLog.whereType<NightActionSkipped>().any(
          (event) => event.actorSeat == citizen,
        ),
        isFalse,
      );
      expect(tester.widget<NightGridTile>(skipTile()).onTap, isNotNull);

      // The explicit skip is the way out, and it is recorded as a skip.
      await tester.tap(skipTile());
      await tester.pump();
      await tester.pump(MafiaTiming.defaults.dwellGate);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pumpAndSettle();
      expect(
        c.engine.match.eventLog.whereType<NightActionSkipped>().any(
          (event) => event.actorSeat == citizen,
        ),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // M2-113: the sold-role switches and the deal
  // ---------------------------------------------------------------------------
  group('M2-113', () {
    Map<Role, int> dealtCounts(MatchEngine e) => {
      for (final role in Role.values)
        if (_seats(e, role).isNotEmpty) role: _seats(e, role).length,
    };

    /// Starts the engine the way the router does with what the screen handed
    /// over: the split from `onNext`, the flags from `OptionalRole.flags`.
    MatchEngine dealWith(Map<Role, int> counts, Set<OptionalRole> on) {
      final e = MatchEngine(clock: Clocks.monotonic());
      final n = counts.values.fold<int>(0, (a, b) => a + b);
      e.start(
        names: [for (var i = 0; i < n; i++) 'P$i'],
        roleCounts: counts,
        settings: OptionalRole.flags(_plain, on),
        seed: 5,
      );
      return e;
    }

    void expectDealMatches(
      Map<Role, int> counts,
      Set<OptionalRole> on,
      MatchEngine e,
    ) {
      expect(dealtCounts(e), {
        for (final entry in counts.entries)
          if (entry.value > 0) entry.key: entry.value,
      });
      for (final r in OptionalRole.values) {
        final dealt = _seats(e, r.role).length;
        expect(
          dealt,
          on.contains(r) ? 1 : 0,
          reason: '${r.name} is dealt exactly when it is switched on',
        );
        expect(
          switch (r) {
            OptionalRole.silencer => e.match.settings.silencerEnabled,
            OptionalRole.elder => e.match.settings.elderEnabled,
            OptionalRole.sniper => e.match.settings.sniperEnabled,
          },
          on.contains(r),
        );
      }
    }

    test('every subset of the three roles, at a table that offers them all, '
        'is dealt exactly as switched', () {
      const base = {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 4,
      };
      for (var mask = 0; mask < 8; mask++) {
        final wanted = {
          for (final r in OptionalRole.values)
            if (mask & (1 << r.index) != 0) r,
        };
        final on = OptionalRole.usable(
          wanted,
          players: 8,
          mafia: 2,
          citizens: 4,
        );
        expect(on, wanted, reason: 'eight players offer every sold role');
        final counts = OptionalRole.apply(base, on);
        expect(counts.values.fold<int>(0, (a, b) => a + b), 8);
        expectDealMatches(counts, on, dealWith(counts, on));
      }
    });

    test('a role the table is too small for is never dealt, even if wanted',
        () {
      const base = {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 1,
      };
      final on = OptionalRole.usable(
        OptionalRole.values.toSet(),
        players: 5,
        mafia: 2,
        citizens: 1,
      );
      expect(on, {OptionalRole.silencer});
      final counts = OptionalRole.apply(base, on);
      expectDealMatches(counts, on, dealWith(counts, on));
    });

    test('the engine refuses a deal whose roles and switches disagree', () {
      MatchEngine engine() => MatchEngine(clock: Clocks.monotonic());
      List<String> names(int n) => [for (var i = 0; i < n; i++) 'P$i'];
      // A sold role dealt with its switch off.
      expect(
        () => engine().start(
          names: names(8),
          roleCounts: const {
            Role.mafia: 1,
            Role.silencer: 1,
            Role.doctor: 1,
            Role.detective: 1,
            Role.citizen: 4,
          },
          settings: _plain,
          seed: 5,
        ),
        throwsArgumentError,
      );
      expect(
        () => engine().start(
          names: names(8),
          roleCounts: const {
            Role.mafia: 2,
            Role.elder: 1,
            Role.doctor: 1,
            Role.detective: 1,
            Role.citizen: 3,
          },
          settings: _plain,
          seed: 5,
        ),
        throwsArgumentError,
      );
      expect(
        () => engine().start(
          names: names(8),
          roleCounts: const {
            Role.mafia: 2,
            Role.sniper: 1,
            Role.doctor: 1,
            Role.detective: 1,
            Role.citizen: 3,
          },
          settings: _plain,
          seed: 5,
        ),
        throwsArgumentError,
      );
      // A switch on with no such role in the split.
      expect(
        () => engine().start(
          names: names(8),
          roleCounts: const {
            Role.mafia: 2,
            Role.doctor: 1,
            Role.detective: 1,
            Role.citizen: 4,
          },
          settings: _plain.copyWith(elderEnabled: true),
          seed: 5,
        ),
        throwsArgumentError,
      );
    });

    // The owned-role fakes of test/widget/store_roles_everywhere_test.dart.
    group('the roles screen with a wallet', () {
      void phone(WidgetTester tester) {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      /// Pumps [RolesScreen] for eight players, tells the test what the host
      /// walks away with: the split and the switches.
      Future<({Map<Role, int> counts, Set<OptionalRole> on})> walkAway(
        WidgetTester tester, {
        required Set<String> owns,
        Set<OptionalRole> switchOn = const {},
        Map<Role, int>? initialCounts,
      }) async {
        await loadArtwork(tester);
        phone(tester);
        Map<Role, int>? counts;
        Set<OptionalRole>? on;
        final container = ProviderContainer(
          overrides: [
            walletProvider.overrideWith(() => _Owns(owns)),
            onlineBackendFactoryProvider.overrideWithValue(
              () async => FakeBackend(
                roomId: 'room',
                state: roomState(phase: 'lobby'),
                players: roster(5),
              ),
            ),
            audioDirectorProvider.overrideWithValue(AudioDirector()),
            paymentCapabilitiesProvider.overrideWithValue(
              const PaymentCapabilities(transfer: false),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedApp(
              RolesScreen(
                playerCount: 8,
                onBack: () {},
                initialCounts: initialCounts,
                onNext: (c) => counts = c,
                onOptionalRoles: (s) => on = s,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final r in switchOn) {
          final sw = find.byKey(OptionalRoleRows.switchKey(r));
          await tester.ensureVisible(sw);
          await tester.tap(sw);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.byKey(RolesScreen.nextButton));
        await tester.tap(find.byKey(RolesScreen.nextButton));
        await tester.pump();
        return (counts: counts!, on: on!);
      }

      _screenTest('owned and switched on: dealt once each, with the flags', (
        tester,
      ) async {
        final out = await walkAway(
          tester,
          owns: const {'role_silencer', 'role_elder', 'role_sniper'},
          switchOn: OptionalRole.values.toSet(),
        );
        expect(out.on, OptionalRole.values.toSet());
        expect(out.counts[Role.silencer], 1);
        expect(out.counts[Role.elder], 1);
        expect(out.counts[Role.sniper], 1);
        expect(out.counts.values.fold<int>(0, (a, b) => a + b), 8);
        expectDealMatches(out.counts, out.on, dealWith(out.counts, out.on));
      });

      _screenTest('owned but only one switched on: only that role is dealt', (
        tester,
      ) async {
        final out = await walkAway(
          tester,
          owns: const {'role_silencer', 'role_elder', 'role_sniper'},
          switchOn: {OptionalRole.elder},
        );
        expect(out.on, {OptionalRole.elder});
        expect(out.counts.containsKey(Role.silencer), isFalse);
        expect(out.counts.containsKey(Role.sniper), isFalse);
        expectDealMatches(out.counts, out.on, dealWith(out.counts, out.on));
      });

      _screenTest('not owned: no switch exists and nothing sold is dealt', (
        tester,
      ) async {
        final out = await walkAway(tester, owns: const {});
        for (final r in OptionalRole.values) {
          expect(find.byKey(OptionalRoleRows.switchKey(r)), findsNothing);
          expect(find.byKey(OptionalRoleRows.lockKey(r)), findsOneWidget);
        }
        expect(out.on, isEmpty);
        for (final r in OptionalRole.values) {
          expect(out.counts.containsKey(r.role), isFalse);
        }
        expectDealMatches(out.counts, out.on, dealWith(out.counts, out.on));
      });

      _screenTest('a role left in the draft but not owned is dropped before '
          'the deal', (tester) async {
        final out = await walkAway(
          tester,
          owns: const {'role_elder'},
          initialCounts: const {
            Role.mafia: 2,
            Role.doctor: 1,
            Role.detective: 1,
            Role.elder: 1,
            Role.sniper: 1,
            Role.citizen: 2,
          },
        );
        expect(out.on, {OptionalRole.elder});
        expect(out.counts[Role.elder], 1);
        expect(out.counts.containsKey(Role.sniper), isFalse);
        expect(out.counts.containsKey(Role.silencer), isFalse);
        expect(out.counts.values.fold<int>(0, (a, b) => a + b), 8);
        expectDealMatches(out.counts, out.on, dealWith(out.counts, out.on));
      });
    });
  });
}

/// A wallet that owns exactly [codes] (store_roles_everywhere_test's fake).
class _Owns extends WalletController {
  final Set<String> codes;
  _Owns(this.codes);

  @override
  Future<WalletState?> build() async => WalletState(
    balance: 0,
    catalog: const [],
    owned: codes,
    equipped: const {},
    history: const [],
  );
}
