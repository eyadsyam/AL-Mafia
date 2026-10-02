import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/win_check.dart';

/// The win rule, tested exhaustively — doc 06 §7.
///
/// The function is pure and its input space is tiny, so there is no excuse for
/// sampling it. Everything below is a direct transcription of the state table
/// in doc 06 §2, plus the properties that table is an instance of.
void main() {
  Player _player(int seat, Role role, {bool alive = true}) => Player(
    seat: seat,
    name: 'P$seat',
    role: role,
    status: alive ? PlayerStatus.alive : PlayerStatus.dead,
    eliminatedOn: null,
  );

  /// A roster with [mafia] living mafia and [others] living non-mafia, plus any
  /// [deadMafia] and [deadOthers] that must be ignored.
  List<Player> roster({
    required int mafia,
    required int others,
    int deadMafia = 0,
    int deadOthers = 0,
    List<Role> otherRoles = const [Role.citizen],
  }) {
    var seat = 0;
    return [
      for (var i = 0; i < mafia; i++) _player(seat++, Role.mafia),
      for (var i = 0; i < others; i++)
        _player(seat++, otherRoles[i % otherRoles.length]),
      for (var i = 0; i < deadMafia; i++)
        _player(seat++, Role.mafia, alive: false),
      for (var i = 0; i < deadOthers; i++)
        _player(seat++, Role.citizen, alive: false),
    ];
  }

  group('the state table in doc 06 §2', () {
    const table = <({int mafia, int others, Alignment? result, String note})>[
      (
        mafia: 1,
        others: 1,
        result: Alignment.mafia,
        note: 'parity — a 1v1 vote always ties',
      ),
      (mafia: 2, others: 1, result: Alignment.mafia, note: 'majority'),
      (
        mafia: 1,
        others: 2,
        result: null,
        note: 'decided in practice, but play it out',
      ),
      (mafia: 2, others: 2, result: Alignment.mafia, note: 'parity'),
      (mafia: 1, others: 3, result: null, note: ''),
      (mafia: 2, others: 3, result: null, note: ''),
      (mafia: 3, others: 3, result: Alignment.mafia, note: 'parity'),
      (mafia: 3, others: 4, result: null, note: 'just below parity'),
      (mafia: 2, others: 5, result: null, note: 'typical opening state'),
      (mafia: 0, others: 1, result: Alignment.town, note: ''),
      (mafia: 0, others: 5, result: Alignment.town, note: ''),
    ];

    for (final row in table) {
      final label = '${row.mafia} mafia vs ${row.others} non-mafia';
      test('$label -> ${row.result?.name ?? 'in progress'}', () {
        expect(
          WinChecker.outcomeFor(roster(mafia: row.mafia, others: row.others)),
          equals(row.result),
          reason: row.note.isEmpty ? null : row.note,
        );
      });
    }
  });

  group('the rule sees only the alive set', () {
    test('dead mafia are not counted', () {
      // Three mafia on the roster, two of them dead: the living one is
      // outnumbered 1 to 3 and the match continues.
      expect(
        WinChecker.outcomeFor(roster(mafia: 1, others: 3, deadMafia: 2)),
        isNull,
      );
      // And with the last one dead, the town has won regardless of how many
      // mafia the match started with.
      expect(
        WinChecker.outcomeFor(roster(mafia: 0, others: 3, deadMafia: 3)),
        equals(Alignment.town),
      );
    });

    test('dead non-mafia are not counted', () {
      // One mafia against one living citizen is parity, whatever the graveyard
      // looks like.
      expect(
        WinChecker.outcomeFor(roster(mafia: 1, others: 1, deadOthers: 5)),
        equals(Alignment.mafia),
      );
    });

    test('doctor and detective do not affect the outcome', () {
      // Same counts, every arrangement of the non-mafia roles.
      const arrangements = <List<Role>>[
        [Role.citizen],
        [Role.doctor],
        [Role.detective],
        [Role.doctor, Role.detective],
        [Role.detective, Role.citizen, Role.doctor],
      ];
      for (final roles in arrangements) {
        expect(
          WinChecker.outcomeFor(roster(mafia: 1, others: 3, otherRoles: roles)),
          isNull,
          reason:
              'a match with $roles alive resolved differently from one '
              'with the same number of plain citizens — ${WinChecker.outcomeIsRoleBlind}',
        );
        expect(
          WinChecker.outcomeFor(roster(mafia: 2, others: 2, otherRoles: roles)),
          equals(Alignment.mafia),
        );
      }
    });
  });

  group('defensive', () {
    test('an empty alive set does not throw', () {
      // Unreachable in the MVP. It must not crash the result screen at the end
      // of somebody's evening, which is the only thing this guarantees.
      expect(() => WinChecker.outcomeFor(const []), returnsNormally);
      expect(
        WinChecker.outcomeFor(roster(mafia: 0, others: 0, deadOthers: 4)),
        equals(Alignment.town),
      );
    });
  });

  group('the property the table is an instance of', () {
    // Doc 11 §10 asks for this over 100,000 pairs. Drawing 100,000 samples out
    // of a space a few hundred states wide would be 99% repetition dressed up
    // as coverage, so the sweep is **exhaustive** and the count falls out of
    // the bounds rather than being chosen to hit a number:
    //
    //     64 alive mafia × 64 alive others × 5 dead mafia × 5 dead others
    //       = 102,400 states, no two of them the same.
    //
    // Sixty-three living mafia is far past anything the game permits — S1 caps
    // a match at fifteen players — and that is the point. The rule is
    // arithmetic on two counts; if it has an off-by-one it is at a boundary,
    // and a sweep that stops at the largest legal roster never reaches the
    // boundaries a later rule change might move.
    const aliveCeiling = 64;
    const deadCeiling = 5;

    test('every state matches the parity rule, over 100,000 of them', () {
      var checked = 0;
      for (var mafia = 0; mafia < aliveCeiling; mafia++) {
        for (var others = 0; others < aliveCeiling; others++) {
          // No mafia left: the town has won, whatever else is on the table.
          // Otherwise the mafia win the moment they stop being outnumbered.
          final expected = mafia == 0
              ? Alignment.town
              : (mafia >= others ? Alignment.mafia : null);

          for (var deadMafia = 0; deadMafia < deadCeiling; deadMafia++) {
            for (var deadOthers = 0; deadOthers < deadCeiling; deadOthers++) {
              final actual = WinChecker.outcomeFor(
                roster(
                  mafia: mafia,
                  others: others,
                  deadMafia: deadMafia,
                  deadOthers: deadOthers,
                  otherRoles: const [Role.citizen, Role.doctor, Role.detective],
                ),
              );

              // `expect` inside a loop this size spends most of its time in the
              // matcher machinery, so the comparison is done by hand and only a
              // failure pays for a report.
              if (actual != expected) {
                fail(
                  '$mafia mafia vs $others non-mafia '
                  '(plus $deadMafia + $deadOthers dead) gave '
                  '${actual?.name ?? 'in progress'}, expected '
                  '${expected?.name ?? 'in progress'}',
                );
              }
              checked++;
            }
          }
        }
      }

      expect(
        checked,
        greaterThanOrEqualTo(100000),
        reason: 'doc 11 §10 puts the floor at 100,000 states',
      );
    });

    test('the dead never change the answer', () {
      // The same property from the other side: whatever the rule says about a
      // living roster, adding corpses to it may not move the answer. Stated
      // separately because it is the one a future "graveyard reveals" feature
      // would break, and it would break it silently.
      final rng = Random(20260902);
      for (var i = 0; i < 2000; i++) {
        final mafia = rng.nextInt(8);
        final others = rng.nextInt(12);
        final bare = WinChecker.outcomeFor(
          roster(mafia: mafia, others: others),
        );
        final buried = WinChecker.outcomeFor(
          roster(
            mafia: mafia,
            others: others,
            deadMafia: rng.nextInt(9),
            deadOthers: rng.nextInt(9),
          ),
        );
        expect(
          buried,
          equals(bare),
          reason: '$mafia vs $others changed answer once the dead were added',
        );
      }
    });
  });

  group('one source of truth', () {
    test('nothing outside win_check.dart re-implements the parity check', () {
      // Doc 06 §8: "no inline parity checks anywhere else". A second copy of
      // the rule is a second thing to get wrong, and the two would disagree
      // only in the states that decide a match.
      final offenders = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final path = file.path.replaceAll(r'\', '/');
        if (path.endsWith('win_check.dart')) continue;
        final source = file.readAsStringSync();
        // The shape of the rule: counting living mafia against the rest.
        if (RegExp(r'aliveMafia|mafiaAlive').hasMatch(source)) {
          offenders.add(path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'these files count living mafia for themselves: $offenders. '
            'Call WinChecker.outcomeFor instead.',
      );
    });

    test('the scan is not vacuous', () {
      expect(
        File('lib/engine/win_check.dart').readAsStringSync(),
        contains('mafiaCount >= nonMafiaCount'),
      );
    });
  });
}
