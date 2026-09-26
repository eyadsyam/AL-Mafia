import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 108: the banner lives on waiting surfaces only. This fails if the
/// banner widget (or the raw banner slot) appears in any other file — above
/// all a gameplay screen, a pass-the-phone screen or a dialog.
void main() {
  const allowed = {
    'lib/ui/economy/waiting_banner.dart',
    'lib/ui/screens/online/lobby_screen.dart',
    'lib/ui/screens/online/online_entry_screen.dart',
    'lib/ui/screens/postgame/history_screen.dart',
    'lib/ui/screens/setup/coin_store.dart',
    'lib/ui/screens/setup/profile_screen.dart',
  };

  // Screens a banner must never touch, whatever the allowlist says later.
  const gameplay = [
    'lib/ui/screens/distribution/',
    'lib/ui/screens/night/',
    'lib/ui/screens/day/',
    'lib/ui/screens/match_flow.dart',
    'lib/ui/screens/match_route.dart',
    'lib/ui/screens/online/online_table_flow.dart',
    'lib/ui/screens/online/table/',
    'lib/ui/screens/online/witness/',
    'lib/ui/screens/online/council/',
    'lib/ui/screens/postgame/result_screen.dart',
    'lib/ui/widgets/pass_screen.dart',
    'lib/ui/widgets/turn_shell.dart',
    'lib/ui/widgets/role_card.dart',
    'lib/ui/widgets/hold_pad.dart',
  ];

  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String rel(File f) => f.path.replaceAll('\\', '/');

  test('WaitingBanner is used only on allowlisted waiting surfaces', () {
    final offenders = <String>[];
    for (final file in dartFiles()) {
      final path = rel(file);
      final text = file.readAsStringSync();
      if (text.contains('WaitingBanner(') && !allowed.contains(path)) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty, reason: 'banner outside its allowlist');
  });

  test('no gameplay screen is on the allowlist or uses a banner', () {
    for (final path in allowed) {
      for (final prefix in gameplay) {
        expect(path.startsWith(prefix), isFalse, reason: path);
      }
    }
    for (final file in dartFiles()) {
      final path = rel(file);
      if (!gameplay.any(path.startsWith)) continue;
      final text = file.readAsStringSync();
      expect(text.contains('WaitingBanner'), isFalse, reason: path);
      expect(text.contains('bannerAdsProvider'), isFalse, reason: path);
      expect(text.contains('BannerAd('), isFalse, reason: path);
    }
  });

  test('the raw banner is built only behind WaitingBanner', () {
    for (final file in dartFiles()) {
      final path = rel(file);
      final text = file.readAsStringSync();
      if (text.contains('bannerAdsProvider')) {
        expect(
          path,
          anyOf(
            'lib/ui/economy/waiting_banner.dart',
            'lib/platform/monetization/ad_formats.dart',
          ),
        );
      }
      if (text.contains('BannerAd(')) {
        expect(path, 'lib/platform/monetization/rewarded_ads_mobile.dart');
      }
    }
  });

  test('never inside a dialog or a bottom sheet builder', () {
    for (final path in allowed.skip(1)) {
      final text = File(path).readAsStringSync();
      final at = text.indexOf('WaitingBanner(');
      expect(at, greaterThan(0), reason: '$path lost its banner');
      final before = text.substring(0, at);
      final dialog = before.lastIndexOf(
        RegExp(r'show(Dialog|ModalBottomSheet|GeneralDialog)\b'),
      );
      // Any dialog or sheet call before the banner belongs to an earlier
      // method: the banner sits in a build method that starts after it.
      final build = before.lastIndexOf('Widget build(');
      expect(
        build,
        greaterThan(dialog),
        reason: '$path: banner inside a dialog',
      );
    }
  });
}
