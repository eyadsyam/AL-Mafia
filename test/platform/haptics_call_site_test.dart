import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T042 / L-10 — no haptic originates anywhere except the shared helper.
///
/// ## Why a buzz is a leak
///
/// A phone on a table is audible. If the Detective's confirm buzzed and a
/// Citizen's did not, the table would learn to count buzzes; if a haptic fired
/// when a Mafioso's teammate indicator appeared, the timing alone would give it
/// away. The rule is therefore blunt: `HapticFeedback` is reachable from exactly
/// one file, `platform/haptics.dart`, which exposes two role-blind calls
/// (`select` and `confirm`). Everything else must go through it, so there is a
/// single place to audit — and a single place to switch the whole app silent.
void main() {
  const helper = 'lib/ui/../platform/haptics.dart';

  List<File> dartFilesUnder(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String normalise(String path) => path.replaceAll(r'\', '/');

  group('L-10 haptic call sites', () {
    test('only platform/haptics.dart touches HapticFeedback', () {
      final offenders = <String>[];

      for (final file in [...dartFilesUnder('lib/ui'), ...dartFilesUnder('lib/platform')]) {
        final path = normalise(file.path);
        if (path.endsWith('platform/haptics.dart')) continue;

        final source = file.readAsStringSync();
        if (source.contains('HapticFeedback') ||
            source.contains('package:flutter/services.dart')) {
          // services.dart is the only import that makes HapticFeedback
          // reachable, so importing it at all is the thing to flag.
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'LEAK: these files can fire a haptic directly instead of '
              'going through platform/haptics.dart: $offenders');
    });

    test('the in-hand shell emits no haptic at all', () {
      // TurnShell is by definition an in-hand surface. Even the sanctioned
      // helper has no business being called from it: the whole turn has to be
      // silent, or the neighbours can hear a selection being made.
      final shell = File('lib/ui/widgets/turn_shell.dart').readAsStringSync();
      expect(shell.contains('Haptics'), isFalse,
          reason: 'turn_shell.dart calls the haptics helper; an in-hand turn '
              'must be completely silent');

      final pad = File('lib/ui/widgets/hold_pad.dart').readAsStringSync();
      expect(pad.contains('Haptics'), isFalse,
          reason: 'hold_pad.dart calls the haptics helper; the identity gate '
              'must not announce that someone has taken the phone');

      final pass = File('lib/ui/widgets/pass_screen.dart').readAsStringSync();
      expect(pass.contains('Haptics'), isFalse,
          reason: 'pass_screen.dart calls the haptics helper; opening the pass '
              'screen must be silent');
    });

    test('the helper exposes exactly the two sanctioned calls', () {
      final source = File('lib/platform/haptics.dart').readAsStringSync();
      expect(source.contains('static void select()'), isTrue);
      expect(source.contains('static void confirm()'), isTrue);

      // Any further public method is a new, unaudited way to make noise.
      final publicMethods = RegExp(r'static\s+\w+\s+(\w+)\s*\(')
          .allMatches(source)
          .map((m) => m.group(1)!)
          .where((name) => !name.startsWith('_'))
          .toSet();
      expect(publicMethods, equals({'select', 'confirm'}),
          reason: 'unexpected public haptic entry points: $publicMethods');
    });

    test('the scan is not vacuous', () {
      // Prove the string being searched for is the one the helper really uses.
      expect(File('lib/platform/haptics.dart').readAsStringSync(),
          contains('HapticFeedback'));
      expect(helper, isNotEmpty);
    });
  });
}
