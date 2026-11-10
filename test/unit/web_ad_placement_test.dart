import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web banner is mounted only on public screens', () {
    final files = [
      'lib/ui/screens/setup/home_screen.dart',
      'lib/ui/screens/setup/settings_screen.dart',
      'lib/ui/screens/postgame/result_screen.dart',
      'lib/ui/screens/online/lobby_screen.dart',
      'lib/ui/economy/waiting_banner.dart',
    ];
    for (final file in files) {
      expect(
        File(file).readAsStringSync(),
        contains('WebAdBanner'),
        reason: file,
      );
    }
    expect(
      File('lib/ui/screens/online/lobby_screen.dart').readAsStringSync(),
      contains('bottomNavigationBar: kIsWeb ? const WebAdBanner() : null'),
    );
    // The online result hand is too short for a pinned banner, and inside its
    // scroll the page overlay would draw past the clip (real match, 2026-11-10).
    expect(
      File('lib/ui/screens/online/online_table_flow.dart').readAsStringSync(),
      isNot(contains('const WebAdBanner()')),
    );
    for (final folder in [
      'lib/ui/screens/night',
      'lib/ui/screens/day',
      'lib/ui/screens/distribution',
    ]) {
      for (final file in Directory(folder).listSync().whereType<File>()) {
        expect(
          file.readAsStringSync(),
          isNot(contains('WebAdBanner')),
          reason: file.path,
        );
      }
    }
  });
}
