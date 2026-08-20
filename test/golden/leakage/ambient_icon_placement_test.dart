import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The four corner icons are atmosphere. They are never a role indicator.
///
/// # The failure this prevents
///
/// The pistol, cross, lens and spade are painted into the corners of the four
/// cards, so the table already associates each one with a role. That is fine
/// where they belong — drifting like ash behind a home screen, four at a time,
/// meaning nothing.
///
/// It stops being fine the moment one of them appears near a person. An icon
/// beside a name in the player grid, or on a tile during a handoff, is a role
/// label in a costume; it does not matter that the code picked it at random,
/// because nobody watching can tell that it did.
///
/// So the placement rule is structural: [FallingIcons] is the only public way to
/// draw them, it always draws all four, and it may only be mounted by surfaces
/// on this list. Anything else importing the painters is a build failure.
void main() {
  /// The only files allowed to draw a corner icon.
  ///
  /// Adding to this list is a decision about whether the surface can ever be on
  /// screen while one player is holding the phone. All three of these are
  /// on-table by construction: nobody is mid-turn on the home screen, and a
  /// phase announcement covers the whole screen between turns.
  const allowed = <String>{
    'lib/ui/widgets/falling_icons.dart',
    'lib/ui/widgets/icon_painters.dart',
    'lib/ui/screens/setup/home_screen.dart',
    'lib/ui/widgets/cinematic_text.dart',
  };

  /// Surfaces that show people. An icon must never reach one of these.
  const nearAPerson = <String>[
    'lib/ui/widgets/player_tile.dart',
    'lib/ui/widgets/pass_screen.dart',
    'lib/ui/widgets/role_card.dart',
    'lib/ui/widgets/turn_shell.dart',
    'lib/ui/screens/setup/add_players_screen.dart',
    'lib/ui/screens/night/night_action_screen.dart',
    'lib/ui/screens/day/voting_screen.dart',
  ];

  String rel(File f) => f.path.replaceAll(r'\', '/');

  List<File> libSources() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('ambient icons stay ambient', () {
    test('only the allowed surfaces reference the icon layer', () {
      final offenders = <String>[];
      for (final file in libSources()) {
        final path = rel(file);
        if (allowed.contains(path)) continue;
        final source = file.readAsStringSync();
        if (source.contains('FallingIcons') ||
            source.contains('icon_painters.dart') ||
            source.contains('PistolPainter') ||
            source.contains('CrossPainter') ||
            source.contains('LensPainter') ||
            source.contains('SpadePainter')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'these surfaces reach the corner icons: $offenders.\n\n'
              'The icons are the ones painted on the card corners, so any of '
              'them shown near a player reads as that player\'s role whether '
              'it was chosen that way or not. If the surface genuinely is '
              'on-table for its whole life, add it to `allowed` and say why.');
    });

    test('no surface that shows a person can reach them', () {
      // A narrower restatement of the check above, spelled out by file so the
      // failure names the specific screen rather than a diff.
      for (final path in nearAPerson) {
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: '$path has moved; this scan is now checking nothing');
        expect(file.readAsStringSync().contains('FallingIcons'), isFalse,
            reason: 'LEAK: $path draws the ambient icons, and it is a surface '
                'that shows players by name.');
      }
    });

    test('the drift always carries all four icons', () {
      // One icon type per particle is fine; a *field* that happened to contain
      // only spades is not, and the difference is a single line in the
      // generator. `iconType: i % 4` is what keeps the mix even.
      final source =
          File('lib/ui/widgets/falling_icons.dart').readAsStringSync();
      expect(source, contains('% 4'),
          reason: 'the particle field no longer guarantees an even mix of all '
              'four icons, so a run of one kind could read as a hint');
    });

    test('the scan is not vacuous', () {
      final home =
          File('lib/ui/screens/setup/home_screen.dart').readAsStringSync();
      expect(home, contains('FallingIcons'),
          reason: 'the home screen no longer shows the drift, so the allow '
              'list is protecting nothing and this whole file is inert');
    });
  });
}
