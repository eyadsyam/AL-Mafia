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
      (mafia: 1, others: 1, result: Alignment.mafia, note: 'parity — a 1v1 vote always ties'),
      (mafia: 2, others: 1, result: Alignment.mafia, note: 'majority'),
      (mafia: 1, others: 2, result: null, note: 'decided in practice, but play it out'),
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
          WinChecker.outcomeFor(
              roster(mafia: 1, others: 3, otherRoles: roles)),
          isNull,
          reason: 'a match with $roles alive resolved differently from one '
              'with the same number of plain citizens — ${WinChecker.outcomeIsRoleBlind}',
        );
        expect(
          WinChecker.outcomeFor(
              roster(mafia: 2, others: 2, otherRoles: roles)),
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
      expect(WinChecker.outcomeFor(roster(mafia: 0, others: 0, deadOthers: 4)),
          equals(Alignment.town));
    });
  });

  group('the property the table is an instance of', () {
    test('every valid state matches the parity rule', () {
      // Hand-written cases miss off-by-ones; this does not.
      final rng = Random(20260803);
      for (var i = 0; i < 500; i++) {
        final mafia = rng.nextInt(6);
        final others = rng.nextInt(9);
        final deadMafia = rng.nextInt(4);
        final deadOthers = rng.nextInt(4);
        final players = roster(
          mafia: mafia,
          others: others,
          deadMafia: deadMafia,
          deadOthers: deadOthers,
          otherRoles: const [Role.citizen, Role.doctor, Role.detective],
        );

        final expected = mafia == 0
            ? Alignment.town
            : (mafia >= others ? Alignment.mafia : null);

        expect(WinChecker.outcomeFor(players), equals(expected),
            reason: '$mafia mafia vs $others non-mafia '
                '(plus $deadMafia + $deadOthers dead)');
      }
    });
  });

  group('one source of truth', () {
    test('nothing outside win_check.dart re-implements the parity check', () {
      // Doc 06 §8: "no inline parity checks anywhere else". A second copy of
      // the rule is a second thing to get wrong, and the two would disagree
      // only in the states that decide a match.
      final offenders = <String>[];
      for (final file in Directory('lib')
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
      expect(offenders, isEmpty,
          reason: 'these files count living mafia for themselves: $offenders. '
              'Call WinChecker.outcomeFor instead.');
    });

    test('the scan is not vacuous', () {
      expect(File('lib/engine/win_check.dart').readAsStringSync(),
          contains('mafiaCount >= nonMafiaCount'));
    });
  });
}
