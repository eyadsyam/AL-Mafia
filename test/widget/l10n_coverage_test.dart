import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/balance_guard.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/l10n_ext.dart';

import '../support/localized.dart';

/// T073 — the two locales stay in step, and no engine code goes unlabelled.
///
/// ## Why this test exists
///
/// A missing translation does not fail to compile: `AppLocalizations` falls back
/// to the template locale, so the app quietly shows English inside an Arabic UI
/// and nobody notices until a player does. Likewise, [EngineCopy] falls back to
/// returning the raw snake_case code rather than throwing, which keeps the app
/// running but puts `two_detectives_low_player_count` on screen. Both failure
/// modes are silent at runtime, so they are caught here instead.
void main() {
  Map<String, dynamic> loadArb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  /// Message keys only — `@@locale` and the `@key` metadata entries are not
  /// translatable strings.
  Set<String> messageKeys(Map<String, dynamic> arb) => arb.keys
      .where((k) => !k.startsWith('@'))
      .toSet();

  group('locale parity', () {
    late Map<String, dynamic> ar;
    late Map<String, dynamic> en;

    setUp(() {
      ar = loadArb('lib/app/l10n/app_ar.arb');
      en = loadArb('lib/app/l10n/app_en.arb');
    });

    test('every English key has an Arabic translation', () {
      final missing = messageKeys(en).difference(messageKeys(ar));
      expect(missing, isEmpty,
          reason: 'untranslated keys would silently render in English inside '
              'an Arabic UI: $missing');
    });

    test('Arabic has no keys English does not', () {
      // English is the template. An extra Arabic key is a leftover from a
      // deleted string, or a typo that is not actually reaching the app.
      final extra = messageKeys(ar).difference(messageKeys(en));
      expect(extra, isEmpty, reason: 'orphaned Arabic keys: $extra');
    });

    test('no translation is left empty', () {
      for (final arb in {'ar': ar, 'en': en}.entries) {
        for (final key in messageKeys(arb.value)) {
          expect((arb.value[key] as String).trim(), isNotEmpty,
              reason: '${arb.key}/$key is blank');
        }
      }
    });

    test('placeholders match between locales', () {
      final placeholder = RegExp(r'\{(\w+)\}');
      for (final key in messageKeys(en)) {
        final enSlots =
            placeholder.allMatches(en[key] as String).map((m) => m.group(1)).toSet();
        final arSlots =
            placeholder.allMatches(ar[key] as String).map((m) => m.group(1)).toSet();
        expect(arSlots, equals(enSlots),
            reason: 'placeholders differ for "$key": en=$enSlots ar=$arSlots');
      }
    });
  });

  group('engine codes all have copy', () {
    test('every balance issue code resolves to a real message', () {
      // Drive the guard through configurations that trigger each rule, rather
      // than hardcoding the code list — a new rule then shows up here without
      // anyone having to remember to add it.
      final reports = <BalanceReport>[
        BalanceGuard.evaluate(playerCount: 3, roleCounts: const {Role.mafia: 1, Role.citizen: 2}),
        BalanceGuard.evaluate(playerCount: 25, roleCounts: const {Role.mafia: 3, Role.citizen: 22}),
        BalanceGuard.evaluate(playerCount: 7, roleCounts: const {Role.mafia: 1, Role.citizen: 3}),
        BalanceGuard.evaluate(playerCount: 7, roleCounts: const {Role.mafia: 0, Role.citizen: 7}),
        BalanceGuard.evaluate(playerCount: 6, roleCounts: const {Role.mafia: 3, Role.citizen: 3}),
        BalanceGuard.evaluate(playerCount: 7, roleCounts: const {Role.mafia: -1, Role.citizen: 8}),
        BalanceGuard.evaluate(
            playerCount: 9,
            roleCounts: const {Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 5}),
        BalanceGuard.evaluate(
            playerCount: 9,
            roleCounts: const {Role.mafia: 3, Role.doctor: 1, Role.detective: 2, Role.citizen: 3}),
      ];

      final codes = {
        for (final report in reports)
          for (final issue in report.issues) issue.code,
      };
      expect(codes, isNotEmpty, reason: 'no balance issues were triggered');

      for (final code in codes) {
        final issue = BalanceIssue(code: code, blocking: true);
        for (final strings in [arStrings, enStrings]) {
          expect(EngineCopy.balanceIssue(strings, issue), isNot(equals(code)),
              reason: 'balance code "$code" has no copy — it would appear on '
                  'the roles screen verbatim');
        }
      }
    });

    test('every achievement code resolves to a title and a description', () {
      // These are the codes `AnalyticsBuilder` can emit.
      const codes = [
        'sharpest_eye',
        'untouchable',
        'guardian',
        'first_blood',
        'survivors',
      ];

      for (final code in codes) {
        for (final strings in [arStrings, enStrings]) {
          expect(EngineCopy.achievementTitle(strings, code), isNot(equals(code)),
              reason: 'achievement "$code" has no title');
          expect(EngineCopy.achievementDescription(strings, code),
              isNot(equals(code)),
              reason: 'achievement "$code" has no description');
        }
      }
    });

    test('every role has a name, a description and a night prompt', () {
      for (final role in Role.values) {
        for (final strings in [arStrings, enStrings]) {
          expect(EngineCopy.roleName(strings, role), isNotEmpty);
          expect(EngineCopy.roleDescription(strings, role), isNotEmpty);
          expect(EngineCopy.nightPrompt(strings, role), isNotEmpty);
        }
      }
    });

    test('an unknown code degrades to the code itself rather than throwing', () {
      // The fallback is deliberate: an unlabelled rule should look obviously
      // wrong in review, not crash a match in progress.
      expect(
        EngineCopy.balanceIssue(
            arStrings, const BalanceIssue(code: 'not_a_real_code', blocking: false)),
        equals('not_a_real_code'),
      );
      expect(EngineCopy.achievementTitle(arStrings, 'nope'), equals('nope'));
    });
  });

  group('no UI string is left hardcoded', () {
    test('screens and widgets contain no literal Arabic', () {
      // Every user-facing string now comes from the ARB files. A stray literal
      // is a string that cannot be translated and will not show up in the
      // parity checks above.
      final arabic = RegExp(r'''['"][^'"]*[؀-ۿ][^'"]*['"]''');
      final offenders = <String>[];

      for (final file in Directory('lib/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          // `screens/dev/` is debug-only scaffolding that never ships. The type
          // specimen in particular *must* carry fixed Arabic and Latin sample
          // text side by side, in one frame, whatever the active locale is —
          // that is the entire point of a specimen. Routing it through the ARB
          // files would show one script at a time and make the comparison the
          // screen exists for impossible.
          .where((f) => !f.path.replaceAll(r'\', '/').contains('/screens/dev/'))) {
        for (final line in file.readAsLinesSync()) {
          final code = line.trim();
          // Doc comments legitimately quote Arabic copy when explaining it.
          if (code.startsWith('//') || code.startsWith('///') || code.startsWith('*')) {
            continue;
          }
          if (arabic.hasMatch(code)) {
            offenders.add('${file.path.replaceAll(r'\', '/')}: $code');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'hardcoded Arabic found:\n${offenders.join('\n')}');
    });

    test('the engine holds no display copy at all', () {
      // `lib/engine` is pure Dart and language-agnostic (L-16). Copy there
      // could never be translated, and would drag a locale into the domain
      // layer.
      final arabic = RegExp(r'[؀-ۿ]');
      final offenders = <String>[];

      for (final file in Directory('lib/engine')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (arabic.hasMatch(file.readAsStringSync())) {
          offenders.add(file.path.replaceAll(r'\', '/'));
        }
      }

      expect(offenders, isEmpty,
          reason: 'these engine files carry display copy: $offenders');
    });
  });
}
