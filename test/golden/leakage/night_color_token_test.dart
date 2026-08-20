import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T043 / L-06 — no warm or role-bound colour token reaches a night or in-hand
/// surface.
///
/// From the design system, §2.3: *"Red must NEVER appear on night screens — a
/// red glow reflected on a player's face signals they saw something
/// dangerous."* And §2.4: role colours appear **only** in the private reveal and
/// the post-game screens.
///
/// This is a static scan rather than a rendering test on purpose. A pixel test
/// can only catch a warm colour that happens to be on screen in the states it
/// samples; reading the source catches one that appears in a rarely-hit branch —
/// an error state, a long-press highlight — which is precisely where a stray
/// crimson survives review.
void main() {
  /// Colour tokens that must not be referenced from an in-hand surface.
  ///
  /// `accentGold` is deliberately absent: it is the single primary-action
  /// colour for the whole app (§5.1) and is used identically by every role, so
  /// it carries no information. What must not appear is anything red, and
  /// anything bound to a role.
  const forbidden = <String, String>{
    'accentCrimson': 'red is banned on night screens (design system §2.3)',
    'roleMafia': 'role colours are reveal/post-game only (§2.4)',
    'roleDoctor': 'role colours are reveal/post-game only (§2.4)',
    'roleDetective': 'role colours are reveal/post-game only (§2.4)',
    'roleCitizen': 'role colours are reveal/post-game only (§2.4)',
  };

  /// Every surface that can be on screen while the phone is in one player's
  /// hand, or on the table during the night.
  ///
  /// `role_card.dart` used to be exempt here, on the grounds that the card front
  /// is the one place a role colour belongs and only its owner is looking at it.
  /// That stopped being true: the card's border and emblem are `borderSubtle`
  /// and `textPrimary` for every role now, so parity on the card is structural
  /// and the exemption was only preserving a hole. It is scanned like the rest.
  ///
  /// This list is a floor, not the whole story — it is hand-maintained, so a
  /// widget extracted into a new file tomorrow would not be on it.
  /// `handoff_purity_test.dart` walks the import graph instead and catches
  /// exactly that case; the two are meant to overlap.
  const inHandSources = <String>[
    'lib/ui/widgets/role_card.dart',
    'lib/ui/widgets/turn_shell.dart',
    'lib/ui/widgets/hold_pad.dart',
    'lib/ui/widgets/player_tile.dart',
    'lib/ui/widgets/pass_screen.dart',
    'lib/ui/screens/night/night_action_screen.dart',
    'lib/ui/screens/night/morning_screen.dart',
    'lib/ui/screens/distribution/pre_night_lobby_screen.dart',
    'lib/ui/screens/day/voting_screen.dart',
  ];

  group('L-06 night colour tokens', () {
    for (final path in inHandSources) {
      test('$path uses no warm or role-bound token', () {
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: '$path is listed as an in-hand surface but does not exist. '
                'If it was renamed, update this list — silently dropping a '
                'surface from the scan is how a leak gets in.');

        final source = file.readAsStringSync();
        for (final entry in forbidden.entries) {
          // Qualifier-aware: `AppIcons.roleMafia` is the parity-matched emblem
          // asset and `l10n.roleMafia` is the word "Mafia", which the card must
          // be able to say to its own owner. Only `<MafiaColors>.roleMafia`, the
          // colour, is a tell. A bare `contains` cannot tell the three apart and
          // was the reason role_card.dart carried a blanket exemption instead of
          // being scanned.
          final pattern = RegExp('(?<!AppIcons\\.)(?<!l10n\\.)\\b${entry.key}\\b');
          expect(
            pattern.hasMatch(source),
            isFalse,
            reason: 'LEAK: $path references `${entry.key}` — ${entry.value}',
          );
        }
      });
    }

    test('the scan covers every night and in-hand source file', () {
      // A new screen added under night/ would otherwise never be checked.
      final nightDir = Directory('lib/ui/screens/night');
      final onDisk = nightDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('.dart'))
          .toSet();

      final covered = inHandSources.toSet();
      final missed = onDisk.difference(covered);
      expect(missed, isEmpty,
          reason: 'these night screens are not in the colour scan: $missed');
    });

    test('the scan is not vacuous', () {
      // If the token names were ever renamed, every `contains` above would
      // return false and the suite would pass while checking nothing. Prove the
      // names still exist where they are legitimately used.
      final tokens = File('lib/ui/theme/design_tokens.dart').readAsStringSync();
      for (final name in forbidden.keys) {
        expect(tokens.contains(name), isTrue,
            reason: '`$name` is no longer a token; the scan list is stale');
      }

      // The scan's whole subtlety is the qualifier: `colors.roleMafia` is a
      // tell, `l10n.roleMafia` is the word "Mafia" and `AppIcons.roleMafia` is a
      // bone-white emblem. So prove both halves on files that genuinely contain
      // each spelling — a regex that stopped firing, and a lookbehind that
      // stopped excluding, are both silent failures otherwise.
      //
      // role_card.dart used to be the positive anchor. It is not any more: the
      // card shows painted artwork and pulls its own name from the ARB, so it
      // legitimately references no role colour at all.
      final pattern = RegExp(r'(?<!AppIcons\.)(?<!l10n\.)\broleMafia\b');

      final postGame =
          File('lib/ui/screens/postgame/result_screen.dart').readAsStringSync();
      expect(pattern.hasMatch(postGame), isTrue,
          reason: 'result_screen.dart is post-game and legitimately paints with '
              '`colors.roleMafia`. If the pattern no longer matches there, it '
              'is matching on a name nothing uses and every check above is '
              'passing on nothing.');

      final strings = File('lib/ui/l10n_ext.dart').readAsStringSync();
      expect(strings.contains('l10n.roleMafia'), isTrue,
          reason: 'l10n_ext.dart no longer maps the role to its ARB string; '
              'the negative anchor below is testing nothing');
      expect(pattern.hasMatch(strings), isFalse,
          reason: 'the `l10n.` lookbehind has stopped excluding string getters, '
              'so the scan would now report the word "Mafia" as a colour leak');
    });
  });
}
