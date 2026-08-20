import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/night/night_action_screen.dart';

import '../support/localized.dart';

/// L-05, stated as a rule about the copy rather than about pixels.
///
/// `luminance_budget_test` measures the rendered consequence; this states the
/// cause. Both exist because the pixel test is the real guarantee but a failure
/// there is hard to read — a copy edit shows up as "citizen is 3.2% off the
/// mean", which does not obviously mean "your new question is four letters
/// too short". This test says so directly.
void main() {
  /// Glyphs that actually emit light. Whitespace advances the layout without
  /// putting anything on screen, so it cannot brighten the phone.
  int inkLength(String s) =>
      s.replaceAll(RegExp(r'\s+'), '').runes.length;

  group('night prompt luminance balance', () {
    test('every role\'s prompt inks exactly the same number of glyphs', () {
      final lengths = {
        for (final role in Role.values) role: inkLength(EngineCopy.nightPrompt(arStrings, role)),
      };

      for (final entry in lengths.entries) {
        expect(
          entry.value,
          equals(nightPromptInkLength),
          reason: 'the ${entry.key.name} prompt inks ${entry.value} glyphs, not '
              '$nightPromptInkLength — a longer or shorter question makes that '
              'role\'s turn measurably brighter or dimmer than the others. '
              'Rewrite it to length, do not relax this number. All prompts: '
              '$lengths',
        );
      }
    });

    test('the prompts are still four distinct questions', () {
      // Equal length must not have been achieved by making them all the same
      // sentence: the player has to be asked the question their role answers.
      final prompts = {for (final role in Role.values) EngineCopy.nightPrompt(arStrings, role)};
      expect(prompts, hasLength(Role.values.length));
    });

    test('no prompt names any role', () {
      // Two reasons, and the second is the strict one:
      //   * "Who does the Doctor protect?" is readable over a shoulder;
      //   * a screen reader says it out loud, to the whole table
      //     (Constitution VII, and `accessibility_test`).
      // There is no exception for the Mafia prompt — "the Mafia's target" is
      // just as identifying as "the Doctor".
      const roleWords = ['مافيا', 'دكتور', 'طبيب', 'محقق', 'مواطن'];
      for (final role in Role.values) {
        final prompt = EngineCopy.nightPrompt(arStrings, role);
        for (final word in roleWords) {
          expect(prompt.contains(word), isFalse,
              reason: 'the ${role.name} prompt contains the role word "$word"');
        }
      }
    });
  });
}
