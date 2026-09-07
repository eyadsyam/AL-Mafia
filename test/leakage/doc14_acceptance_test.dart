/// Doc 14 Part 7's checklist, as far as it can be executed.
///
/// # What is covered elsewhere, so this file does not repeat it
///
/// * the grid's geometry, its column table and the special tile's rect across
///   all four roles → `golden/night_grid_symmetry_test`
/// * one tap to confirm, and the special tile confirming through the same
///   button → the same file
/// * no whisper anywhere offline, and the confirmation screen's contents →
///   `golden/leakage/offline_whisper_absence_test`
/// * the settings screen's five groups, its online-only marks and the
///   round-trip that proves it drops no field → `widget/settings_presets_test`
/// * the four special tiles inking the same number of glyphs and naming no
///   role → `widget/night_prompt_balance_test`
/// * ±2% luminance across roles in every turn state → `golden/leakage/
///   luminance_budget_test`
///
/// # What is *not* met, stated rather than left off the list
///
/// **Doc 14 §1.4's "no name" is not honoured, and doc 05 is why.** Removing
/// the picked seat from the confirmation screen puts the Detective 2.26% off
/// the set mean in the `confirmed` state, because three screens then carry
/// nothing in the detail slot and one carries a verdict. The budget did not
/// move. See `TurnShell._detailSlot`.
///
/// **«كشف دور المُقصى» is not a switch.** Doc 14 Part 5 lists one; FR-019
/// makes a day elimination public by rule, so it could never be turned off,
/// and a control that cannot be operated is the thing Part 5 exists to delete.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role, RoleBullet;
import 'package:mafia_master/engine/models/match_settings.dart';

import 'package:mafia_master/ui/screens/night/morning_screen.dart';


import '../support/localized.dart';

void main() {
  group('doc 14 §1.5 — the morning is the victim and the trace', () {
    testWidgets('a quiet night reads the same whoever made it quiet',
        (tester) async {
      // The Doctor blocking a kill and «الليلة الهادية» produce the same
      // sentence, and the engine-level proof that they produce the same
      // *report* is in `doc13_acceptance_test`. This is the screen half.
      await tester.pumpWidget(localizedApp(MorningScreen(
        dayNumber: 2,
        victimName: null,
        someoneSavedUnnamed: true,
        onContinue: () {},
      )));
      await tester.pump();

      expect(find.text(arStrings.quietNight), findsOneWidget);
      expect(find.text(arStrings.someoneSavedBody), findsOneWidget);
    });

    testWidgets('nothing a bullet published appears here any more',
        (tester) async {
      // Doc 14 §4.1 removed «فتح الملف» and deferred «الشهادة», which were the
      // only two things that ever wrote a line into this screen. There is no
      // parameter left to pass them through.
      await tester.pumpWidget(localizedApp(MorningScreen(
        dayNumber: 2,
        victimName: 'خالد',
        someoneSavedUnnamed: false,
        traceText: 'حد كان بيبص ناحية «سارة»',
        onContinue: () {},
      )));
      await tester.pump();

      expect(find.text(arStrings.traceLabel), findsOneWidget);
      expect(find.textContaining('الملف'), findsNothing);
      expect(find.textContaining('شهادة'), findsNothing);
    });
  });

  group('doc 14 §4.2 — the defaults doc 14 changed', () {
    test('«اسم واحد» is off, and the two abilities that survive are on', () {
      const s = MatchSettings();
      expect(s.openingRoundEnabled, isFalse);
      expect(s.quietNightEnabled, isTrue);
      expect(s.selfProtectEnabled, isTrue);
    });

    test('whispers are off offline, which is the only mode this default sees',
        () {
      // Doc 14 §3.1. The online transport turns the layer on for itself; the
      // offline flow no longer reads this flag at all, and the field survives
      // for the transport and the codec.
      expect(const MatchSettings().whisperEnabled, isFalse);
    });

    test('two roles hold an ability and two hold none', () {
      // Doc 14 §4.1 and §4.2. Asserted on the type rather than on a count, so
      // adding a role cannot quietly re-open the question.
      expect(Role.mafia.bullet, isNotNull);
      expect(Role.doctor.bullet, isNotNull);
      expect(Role.detective.bullet, isNull);
      expect(Role.citizen.bullet, isNull);
    });
  });
}
