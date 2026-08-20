import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/cinematic_text.dart';

import '../support/localized.dart';

/// The six phase announcements are the same length as each other, every time.
///
/// # Why length is the thing under test
///
/// These are on-table moments; everyone can see them, so their *content* is not
/// leakage-critical. Their *rhythm* is. A table learns a game's timings within a
/// couple of rounds, and if the morning-with-a-death announcement took a beat
/// longer to arrive than the quiet one, the room would start reading the pause
/// before the words appeared — which hands the outcome to whoever is paying
/// attention rather than to the reveal.
///
/// So the assertion is not "it is three seconds". It is "they are all the same,
/// whatever the token says, including under Reduce Motion", which survives
/// somebody deciding three seconds is too long.
void main() {
  const lines = <String>[
    'الضلمة نزلت على البلد… كله يغمّض',
    'الصبح جه… والبلد صحيت على خبر وحش',
    'الصبح جه… ومحدش مات النهارده',
    'الشعب هيقرر… ومفيش رجوع',
    'المافيا خلصت على البلد',
    'الشعب انتصر',
  ];

  var mounts = 0;

  /// Mounts one announcement and returns how long it stayed on screen.
  ///
  /// A fresh key per mount, so re-measuring the same line under a different
  /// setting really does start a new announcement rather than inheriting the
  /// finished state of the last one — which is what the match flow does too.
  Future<Duration> lifetime(
    WidgetTester tester,
    String line, {
    bool reduceMotion = false,
  }) async {
    var done = false;
    var started = false;

    await tester.pumpWidget(
      localizedApp(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: CinematicText(
            key: ValueKey('moment-${mounts++}'),
            text: line,
            onStart: () => started = true,
            onComplete: () => done = true,
          ),
        ),
      ),
    );
    // MaterialApp's localisation delegates resolve a frame late, so `home` is
    // not built by `pumpWidget` alone. A zero-duration pump builds it without
    // moving the clock the measurement below depends on.
    await tester.pump();

    expect(started, isTrue,
        reason: 'the narrator hook did not fire — a recorded line for this '
            'moment would never play');

    // Stepped rather than settled: `pumpAndSettle` would report how long the
    // *animations* took, and the hold between them is a timer, not an
    // animation.
    const step = Duration(milliseconds: 50);
    var waited = Duration.zero;
    const limit = Duration(seconds: 20);
    while (!done && waited < limit) {
      await tester.pump(step);
      waited += step;
    }
    expect(done, isTrue, reason: 'the announcement "$line" never finished');
    return waited;
  }

  group('phase announcements', () {
    testWidgets('all six run for exactly the same length', (tester) async {
      final measured = <String, Duration>{};
      for (final line in lines) {
        measured[line] = await lifetime(tester, line);
      }

      final reference = measured[lines.first]!;
      for (final entry in measured.entries) {
        expect(entry.value, equals(reference),
            reason: '"${entry.key}" was on screen for ${entry.value} while '
                '"${lines.first}" took $reference. The table will learn to read '
                'the difference.');
      }

      // And it is a real pause, not an instant one.
      expect(reference, greaterThanOrEqualTo(MafiaTiming.defaults.phaseHold));
    });

    testWidgets('Reduce Motion changes the fade, not the duration',
        (tester) async {
      // An accessibility setting that made the game faster would be a signal in
      // its own right — and would quietly hand an advantage to whoever turned
      // it on.
      final normal = await lifetime(tester, lines.first);
      final reduced = await lifetime(tester, lines.first, reduceMotion: true);

      // Not exact equality, unlike the six lines above. Those all run the same
      // code path, so they match to the sample. These two run *different* paths
      // — one waits on an animation controller, the other on a single timer —
      // and the controller signals completion a frame or two after its duration
      // elapses. The slack is the width of that difference, well under the
      // threshold at which a table would notice one mode running quicker.
      final slack = (reduced - normal).abs();
      expect(slack, lessThan(const Duration(milliseconds: 150)),
          reason: 'Reduce Motion changed how long a phase announcement lasts, '
              'by $slack. An accessibility setting that speeds the game up is '
              'a signal in its own right.');
    });

    testWidgets('the line is legible while it is held', (tester) async {
      await tester.pumpWidget(
        localizedApp(CinematicText(text: lines.first, onComplete: () {})),
      );
      await tester.pump(); // build `home`; the fade starts on this frame
      await tester.pump(MafiaMotion.defaults.dramatic);

      final fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byType(CinematicText),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, closeTo(1.0, 0.01),
          reason: 'the announcement never reaches full opacity, so the line is '
              'never actually readable');
    });

    testWidgets('an announcement disposed mid-flight does not fire onComplete',
        (tester) async {
      // The completion callback advances the match. If a host ended the game
      // while an announcement was fading, a late callback would step an engine
      // that had already been torn down.
      var completions = 0;
      await tester.pumpWidget(
        localizedApp(
          CinematicText(text: lines.first, onComplete: () => completions++),
        ),
      );
      await tester.pump();
      await tester.pump(MafiaMotion.defaults.dramatic);

      await tester.pumpWidget(localizedApp(const SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 10));

      expect(completions, isZero);
    });
  });
}
