import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/turn_shell_harness.dart';

/// **The doc 11 §8 zero-leakage regressions, L1–L10, as one suite.**
///
/// # Why this file exists when the tests already did
///
/// Eight of the ten rows in doc 11 §8 were already pinned somewhere in this
/// repo — and none of them said so. The suite grew its own numbering (L-01 to
/// L-16, from doc 05) which overlaps the spec's numbering without matching it:
/// doc 11's L5 is the dwell gate, which this repo files under **L-07**; doc
/// 11's L6 is audio and haptics, filed under **L-10**. Two vocabularies, no
/// dictionary, and a release gate that says *"all L1–L10 leakage tests pass"*
/// with no way to check the claim except by reading every test file and
/// deciding.
///
/// So this is the dictionary, and it is executable. The map below ties each
/// spec row to the tests that actually pin it, and the first three groups make
/// that map impossible to falsify quietly:
///
///   * the spec's table is parsed from disk and compared against the map, so a
///     row added, renumbered or reworded in doc 11 fails here until somebody
///     assigns it a test;
///   * every named file and group must exist, so deleting or renaming a
///     ship-blocking suite fails here rather than silently reducing coverage;
///   * no named file may carry a test-level skip, because a skipped leakage
///     test is worse than a missing one — it reports green.
///
/// # And two rows that nothing pinned
///
/// L3 (step count) and L4 (tap count) had no test anywhere. They do now, at the
/// bottom of this file. They are the cheapest leak in the game to introduce and
/// the easiest to spot from across a table: nobody needs to see a screen to
/// count how many times the person holding the phone touched it.
void main() {
  // ───────────────────────────────────────────────────────────────────────
  // The map. `test` and `criterion` are the spec's own words and are compared
  // against the document; `pins` is this repo's answer.
  // ───────────────────────────────────────────────────────────────────────

  const rows =
      <int, ({String test, String criterion, Map<String, List<String>> pins})>{
        1: (
          test: 'Golden: all four roles, night action screen',
          criterion: 'Structurally identical trees and dimensions',
          pins: {
            'test/golden/turn_shell_symmetry_test.dart': [
              'L-01 pixel symmetry across roles',
              'L-01/L-02 structural symmetry with role-natural copy',
              'L-02 reserved detail slot',
            ],
            'test/golden/reveal_symmetry_test.dart': <String>[],
            'test/golden/voting_symmetry_test.dart': <String>[],
          },
        ),
        2: (
          test: 'Luminance across night screens',
          criterion: 'Within ±2%, measured after textures',
          pins: {
            'test/golden/leakage/luminance_budget_test.dart': <String>[],
            'test/golden/leakage/role_accent_parity_test.dart': <String>[],
          },
        ),
        3: (
          test: 'Step count per role',
          criterion: 'Exactly 2 for every role',
          pins: {
            'test/leakage/doc11_regressions_test.dart': [
              'L3 — two steps, and only two',
            ],
          },
        ),
        4: (
          test: 'Tap count per role',
          criterion: 'Identical',
          pins: {
            'test/leakage/doc11_regressions_test.dart': [
              'L4 — the same taps, in the same order',
            ],
          },
        ),
        5: (
          test: 'Minimum dwell before Confirm',
          criterion: '8s for every role',
          pins: {
            'test/widget/turn_shell_timing_parity_test.dart': [
              'L-07 dwell gate',
            ],
          },
        ),
        6: (
          test: 'Audio/haptic events during a private turn',
          criterion: '**Zero**',
          pins: {
            'test/platform/haptics_call_site_test.dart': [
              'L-10 haptic call sites',
            ],
            'test/platform/audio_backend_isolation_test.dart': <String>[],
          },
        ),
        7: (
          test: 'Whisper card shown on every turn',
          criterion: 'Including the empty state',
          pins: {
            // Doc 14 §3.1 inverts this row rather than dropping it. The card
            // was unconditional so that the *number of screens* in a turn could
            // not say who had received a whisper; the layer is online-only now,
            // so offline there is no card for anybody and nothing to count.
            'test/golden/leakage/offline_whisper_absence_test.dart': [
              'doc 14 §3.1 — offline has no whisper layer',
            ],
          },
        ),
        8: (
          test: 'Card letterbox bars',
          criterion: "Within 12 levels of each painting's outer edge",
          pins: {
            'test/platform/card_ground_matches_surface_test.dart': <String>[],
          },
        ),
        9: (
          test: 'Route transition durations per role',
          criterion: 'Identical to the millisecond',
          pins: {
            'test/widget/turn_shell_timing_parity_test.dart': [
              'L-09 no per-role timing path exists at all',
              'L-08 pass gate',
            ],
            'test/widget/phase_transition_test.dart': <String>[],
          },
        ),
        10: (
          test: 'Resume after kill during a private turn',
          criterion: 'Lands on the pass screen',
          pins: {
            'test/integration/crash_resume_test.dart': [
              'L-13 resume lands on a neutral surface',
            ],
          },
        ),
      };

  String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  // ───────────────────────────────────────────────────────────────────────

  group('the map matches the spec', () {
    test('doc 11 §8 has exactly the ten rows this file claims', () {
      final doc = File('docs/11-edge-cases-and-tests.md').readAsStringSync();
      final section = doc.split('# 8. Zero-leakage regression (offline)');
      expect(
        section.length,
        greaterThan(1),
        reason: 'doc 11 no longer has a §8 — the release gate lost its table',
      );

      final table = section[1].split('# 9.').first;
      final parsed = <int, (String, String)>{};
      for (final line in table.split('\n')) {
        final m = RegExp(
          r'^\|\s*L(\d+)\s*\|(.+?)\|(.+?)\|\s*$',
        ).firstMatch(line);
        if (m == null) continue;
        parsed[int.parse(m.group(1)!)] = (
          squash(m.group(2)!),
          squash(m.group(3)!),
        );
      }

      expect(
        parsed.keys.toSet(),
        equals(rows.keys.toSet()),
        reason:
            'doc 11 §8 and this file disagree about which rows exist. '
            'A new row needs a test before it needs a number.',
      );

      for (final entry in parsed.entries) {
        final mine = rows[entry.key]!;
        expect(
          entry.value.$1,
          equals(squash(mine.test)),
          reason: 'L${entry.key}: the spec renamed the test',
        );
        expect(
          entry.value.$2,
          equals(squash(mine.criterion)),
          reason:
              'L${entry.key}: the spec changed the pass criterion — the '
              'test pinned to it may no longer measure the right thing',
        );
      }
    });
  });

  group('every row is pinned by a live test', () {
    for (final entry in rows.entries) {
      test('L${entry.key} — ${entry.value.test}', () {
        expect(
          entry.value.pins,
          isNotEmpty,
          reason: 'L${entry.key} has no test',
        );

        for (final pin in entry.value.pins.entries) {
          final file = File(pin.key);
          expect(
            file.existsSync(),
            isTrue,
            reason: 'L${entry.key} points at ${pin.key}, which is gone',
          );

          final source = file.readAsStringSync();
          for (final name in pin.value) {
            expect(
              source.contains(name),
              isTrue,
              reason:
                  'L${entry.key}: ${pin.key} no longer declares a group '
                  'named "$name"',
            );
          }

          // A skipped leakage test reports green, which is the one outcome
          // worse than not having written it.
          //
          // The pattern is spliced rather than written whole because this file
          // is one of the files it scans: a literal would match itself and
          // report L3 and L4 as disabled.
          expect(
            RegExp(
              r'\b'
              'skip'
              r'\s*:',
            ).hasMatch(source),
            isFalse,
            reason: 'L${entry.key}: ${pin.key} contains a skip',
          );
        }
      });
    }
  });

  group('the numbers doc 11 states out loud are still the numbers in force', () {
    // The spec writes three tolerances as prose. Each one lives somewhere as a
    // literal, and widening a literal is the quiet way a leakage test starts
    // passing. They are checked here, beside the sentence they come from,
    // rather than only inside the suite whose result they decide.

    test('L2 — the luminance budget is still ±2%', () {
      final source = File(
        'test/golden/leakage/luminance_budget_test.dart',
      ).readAsStringSync();
      expect(
        source.contains('double budget = 0.02'),
        isTrue,
        reason: 'the ±2% budget of doc 11 §8 L2 has moved',
      );
    });

    test('L5 — the dwell gate is still 8 seconds', () {
      expect(
        MafiaTiming.defaults.dwellGate,
        equals(const Duration(seconds: 8)),
        reason: 'doc 11 §8 L5 fixes the minimum dwell at 8s for every role',
      );
    });

    test('L8 — the letterbox budget is still 12 levels', () {
      final source = File(
        'test/platform/card_ground_matches_surface_test.dart',
      ).readAsStringSync();
      expect(
        source.contains('budget = 12.0'),
        isTrue,
        reason: 'the 12-level budget of doc 11 §8 L8 has moved',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // L3 and L4 — the two rows nothing else covered.
  //
  // A turn is two steps: choose, then confirm. That is the whole of it, for
  // every role, and it has to be, because the table watches the *hand* holding
  // the phone. A detective who taps three times and a citizen who taps once
  // have told the room their roles without either screen being seen.
  // ───────────────────────────────────────────────────────────────────────

  /// Plays one night turn to completion and returns the taps it cost, in order.
  ///
  /// The turn is driven blind — the same finder sequence for every role, with
  /// no branch on which role is in hand. A role needing a different sequence
  /// fails here by not completing, rather than by being counted differently.
  Future<List<String>> playTurn(WidgetTester tester, Role role) async {
    const timing = MafiaTiming.defaults;
    final confirmed = <int>[];

    await TurnShellHarness.pump(
      tester,
      role: role,
      prompt: TurnShellHarness.naturalPrompt(role),
      onConfirmed: confirmed.add,
    );
    await TurnShellHarness.completeHold(tester); // t = 0

    // Past the dwell gate before anything is touched, so what follows measures
    // the number of steps and never the clock.
    await tester.pump(timing.dwellGate);
    await tester.pump();

    final tiles = find.byType(NightGridTile);
    expect(
      tiles.evaluate().length,
      equals(TurnShellHarness.targets.length),
      reason: '${role.name} is offered a different number of targets',
    );

    // Nothing is confirmable yet — for anybody. A role whose Confirm was live
    // before a choice was made would be a one-step turn.
    expect(
      TurnShellHarness.actionEnabled(tester),
      isFalse,
      reason: 'LEAK: ${role.name} could confirm without choosing',
    );

    final taps = <String>[];

    // Step 1.
    await tester.tap(
      find.byKey(NightGrid.tile(TurnShellHarness.targets[1].seat)),
    );
    await tester.pump();
    taps.add('target');
    expect(
      confirmed,
      isEmpty,
      reason: 'LEAK: ${role.name} ended the turn on the first tap',
    );

    // Step 2.
    expect(
      TurnShellHarness.actionEnabled(tester),
      isTrue,
      reason: '${role.name} cannot confirm after choosing',
    );
    await tester.tap(find.byKey(TurnShell.actionButton));
    await tester.pump();
    taps.add('confirm');

    expect(
      confirmed,
      equals([TurnShellHarness.targets[1].seat]),
      reason: '${role.name} did not confirm the seat it was given',
    );

    return taps;
  }

  group('L3 — two steps, and only two', () {
    for (final role in Role.values) {
      testWidgets('${role.name} confirms in exactly two steps', (tester) async {
        expect(await playTurn(tester, role), hasLength(2));
      });
    }
  });

  group('L4 — the same taps, in the same order', () {
    testWidgets('all four roles walk an identical tap sequence', (
      tester,
    ) async {
      final sequences = <Role, List<String>>{};
      for (final role in Role.values) {
        sequences[role] = await playTurn(tester, role);
      }

      final reference = sequences[Role.mafia]!;
      for (final role in Role.values) {
        expect(
          sequences[role],
          orderedEquals(reference),
          reason:
              'LEAK: ${role.name} takes a different path through a turn '
              'than mafia: ${sequences[role]} vs $reference',
        );
      }
    });
  });
}
