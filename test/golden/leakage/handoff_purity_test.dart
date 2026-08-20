import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// L-06 / L-16 — nothing role-conditional is reachable from a private surface.
///
/// # SHIP-BLOCKING
///
/// ## What this adds over `night_color_token_test.dart`
///
/// That test scans a hand-maintained list of files. It is precise and it is
/// exactly as complete as somebody remembered to make it: a widget extracted out
/// of `turn_shell.dart` into a new file tomorrow is not on the list, is never
/// scanned, and may reference whatever it likes. The list even carries a comment
/// exempting `role_card.dart` on the grounds that "the card front is the one
/// place a role colour belongs" — which stopped being true when the card's border
/// and emblem became `borderSubtle`/`textPrimary` for every role.
///
/// This test does not take a list. It starts from the handoff entry points and
/// **walks the import graph**, so the set it checks is whatever the code actually
/// pulls in. Adding a file cannot quietly remove it from the scan; the only way
/// out of the closure is to genuinely not be reachable from a private surface.
///
/// ## What is forbidden inside the closure, and why
///
///   * **the four role accent colours** — a role-conditional colour is a role
///     tell. Someone opposite the holder cannot read the screen but can see that
///     tonight's card glows differently from last night's. These are legitimate
///     on the result screen and post-game analytics, where the role has just been
///     made public to everyone at once.
///
///   * **the tier-2 gallery art** — full-colour, full-art role paintings. They
///     are deliberately not luminance-matched to each other (that is the entire
///     point of splitting them out from the in-match faces), so one showing up on
///     an in-hand surface would leak brightness *and* colour at once, and would
///     do it while sailing past `luminance_budget_test.dart`, which only measures
///     `card_face_*`.
///
/// ## The distinction this test rests on
///
/// `AppIcons.roleMafia` is an emblem asset and is fine — the four emblems are ink
/// parity-matched to 27.00% ± 0.234% coverage and drawn in `textPrimary`. It is
/// `MafiaColors.roleMafia`, the *colour*, that leaks. Both spell `roleMafia`, so
/// the scan matches on the qualifier rather than the bare identifier. If that
/// looks fragile, it is: it is also why the failure message below names the
/// distinction rather than just pointing at a line.
void main() {
  /// Every surface that is on screen while the phone is in one player's hand and
  /// nobody else may see it.
  ///
  /// These are roots, not the scan set — the scan set is everything they reach.
  const handoffRoots = <String>[
    'lib/ui/widgets/pass_screen.dart',
    'lib/ui/widgets/turn_shell.dart',
    'lib/ui/widgets/role_card.dart',
    'lib/ui/screens/night/night_action_screen.dart',
    'lib/ui/screens/distribution/role_reveal_screen.dart',
  ];

  /// The token definitions themselves, and the generated asset table.
  ///
  /// Both name every role colour and every gallery path by construction — that is
  /// their job. Excluding them is not a loophole: neither is a widget, and
  /// nothing they contain renders on its own.
  const declarationSites = <String>{
    'lib/ui/theme/design_tokens.dart',
    'lib/app/asset_constants.dart',
  };

  /// The generated localisation tables.
  ///
  /// `AppLocalizations.roleMafia` is the *word* "Mafia" — the card has to be able
  /// to tell its owner what they are, and the ARB getter is spelled identically
  /// to the colour token. These files declare hundreds of role-named getters and
  /// would drown the scan in false positives.
  ///
  /// This is not a hole a colour could hide in: every member of these files is a
  /// `String`, and the test below re-checks that rather than trusting it. A
  /// generated string table cannot carry a `Color` without the generator
  /// changing, and if the generator ever changes, this stops passing.
  const stringTables = <String>{
    'lib/app/l10n/app_localizations.dart',
    'lib/app/l10n/app_localizations_ar.dart',
    'lib/app/l10n/app_localizations_en.dart',
  };

  String normalise(String path) => path.replaceAll(r'\', '/');

  /// Resolves one import directive to a repo-relative path, or null if it points
  /// outside this package (`package:flutter/...`, `dart:ui`, and so on).
  String? resolveImport(String directive, String fromPath) {
    if (directive.startsWith('package:mafia_master/')) {
      return 'lib/${directive.substring('package:mafia_master/'.length)}';
    }
    if (directive.startsWith('package:') || directive.startsWith('dart:')) {
      return null;
    }
    // Relative import, resolved against the importing file's directory.
    final dir = fromPath.substring(0, fromPath.lastIndexOf('/'));
    final segments = <String>[...dir.split('/'), ...directive.split('/')];
    final stack = <String>[];
    for (final segment in segments) {
      if (segment == '.' || segment.isEmpty) continue;
      if (segment == '..') {
        if (stack.isNotEmpty) stack.removeLast();
        continue;
      }
      stack.add(segment);
    }
    return stack.join('/');
  }

  final importPattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''',
      multiLine: true);

  /// Transitive closure of `handoffRoots` over this package's own imports.
  Set<String> reachable() {
    final seen = <String>{};
    final queue = <String>[...handoffRoots];

    while (queue.isNotEmpty) {
      final path = queue.removeLast();
      if (!seen.add(path)) continue;

      final file = File(path);
      if (!file.existsSync()) continue;

      for (final match in importPattern.allMatches(file.readAsStringSync())) {
        final target = resolveImport(match.group(1)!, path);
        if (target != null && !seen.contains(target)) queue.add(target);
      }
    }
    return seen;
  }

  /// `MafiaColors.roleMafia` leaks; `AppIcons.roleMafia` does not. The negative
  /// lookbehind is what separates them.
  final forbidden = <RegExp, String>{
    RegExp(r'(?<!AppIcons\.)(?<!l10n\.)\brole(Mafia|Doctor|Detective|Citizen)\b'):
        'a role accent colour — role-conditional colour is a role tell. '
            'If you meant the emblem asset, qualify it as `AppIcons.roleX`; if '
            'you meant the colour, this surface may not have it (§2.4).',
    // Matches the generated constant class, the raw paths, and the old
    // `AppImages.gallery*` spelling the generator used before the gallery moved
    // into its own directory. A leak must not be able to sneak in through a
    // rename.
    RegExp(r'assets/images/gallery/|\bAppGallery\b|\bAppImages\.gallery'):
        'tier-2 gallery art — full-colour and deliberately NOT '
            'luminance-matched across roles, so it leaks brightness and hue at '
            'once and does it without tripping luminance_budget_test.dart, '
            'which only measures card_face_*. Gallery art is post-game only.',
  };

  group('L-16 handoff purity', () {
    final closure = reachable()
        .where((p) => !declarationSites.contains(p) && !stringTables.contains(p))
        .toList()
      ..sort();

    test('every handoff root exists', () {
      // A renamed root would otherwise shrink the closure to nothing and leave
      // this whole file passing vacuously.
      for (final root in handoffRoots) {
        expect(File(root).existsSync(), isTrue,
            reason: '$root is a handoff entry point but does not exist. It was '
                'probably renamed — update handoffRoots. Dropping a root '
                'silently removes everything under it from the scan.');
      }
    });

    test('the closure is larger than the roots', () {
      // Proves the import walk actually walked. If `resolveImport` broke, the
      // closure would collapse to the roots and every check below would pass by
      // examining almost nothing.
      expect(closure.length, greaterThan(handoffRoots.length),
          reason: 'the import walk found no transitive dependencies, which '
              'cannot be right — the checks below would be nearly vacuous. '
              'Closure: $closure');
    });

    test('the closure reaches the shared widgets, not just the roots', () {
      expect(closure, contains('lib/ui/widgets/hold_pad.dart'),
          reason: 'hold_pad.dart is pulled in by turn_shell.dart and must be '
              'inside the closure; if it is not, the walk is not following '
              'imports correctly and the scan is much narrower than it looks.');
    });

    for (final entry in forbidden.entries) {
      test('no handoff-reachable file references ${entry.key.pattern}', () {
        final offenders = <String>[];
        for (final path in closure) {
          final file = File(path);
          if (!file.existsSync()) continue;
          final source = file.readAsStringSync();
          for (final match in entry.key.allMatches(source)) {
            final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
            offenders.add('${normalise(path)}:$line — `${match.group(0)}`');
          }
        }

        expect(offenders, isEmpty,
            reason: 'LEAK: ${entry.value}\n'
                'Reachable from a private surface:\n  '
                '${offenders.join('\n  ')}');
      });
    }

    test('the excluded localisation tables really are strings only', () {
      // The one exclusion that could hide a colour. It cannot today because the
      // generator emits `String get` and nothing else, but "cannot today" is
      // exactly the kind of claim that needs a test under it.
      for (final path in stringTables) {
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: '$path is excluded from the role-colour scan but does not '
                'exist. Remove the stale exclusion rather than leaving a hole '
                'pointed at nothing.');

        expect(RegExp(r'\bColor\b').hasMatch(file.readAsStringSync()), isFalse,
            reason: '$path is excluded from the handoff colour scan on the '
                'grounds that a generated string table cannot carry a Color. It '
                'now mentions one. Either the generator changed or the file was '
                'hand-edited — do not simply drop the exclusion, work out which.');
      }
    });

    test('the ban is not vacuous — the result screen uses both', () {
      // If the forbidden patterns stopped matching anything anywhere, the tests
      // above would pass no matter what the handoff surfaces did. The result
      // screen is where role colour *and* gallery art are both legitimate — the
      // match is over and every role is already public — so it is the control
      // for both patterns.
      final source = File('lib/ui/screens/postgame/result_screen.dart')
          .readAsStringSync();

      for (final pattern in forbidden.keys) {
        expect(pattern.hasMatch(source), isTrue,
            reason: 'result_screen.dart no longer matches `${pattern.pattern}`, '
                'so that pattern is no longer known to match anything at all '
                'and the handoff checks using it are asserting nothing. Either '
                'the post-game screen stopped doing the thing (fine — pick a '
                'different control) or the regex has rotted (not fine).');
      }
      expect(closure, isNot(contains('lib/ui/screens/postgame/result_screen.dart')),
          reason: 'the control file is inside the handoff closure, which means '
              'a private surface can reach the post-game result screen. That is '
              'a bigger problem than the colour.');
    });
  });
}
