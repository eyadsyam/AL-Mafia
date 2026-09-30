import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web banner is mounted only on public screens', () {
    final files = [
      'lib/ui/screens/setup/home_screen.dart',
      'lib/ui/screens/setup/settings_screen.dart',
      'lib/ui/screens/postgame/result_screen.dart',
      'lib/ui/screens/online/online_table_flow.dart',
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
