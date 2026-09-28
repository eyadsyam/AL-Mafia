import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations_ar.dart';
import 'package:mafia_master/app/l10n/app_localizations_en.dart';
import 'package:mafia_master/ui/economy/council.dart';
import 'package:mafia_master/ui/economy/council_hub.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';

/// Row 6: the client reads `economy.version` and the v3 invite block, and
/// with the server's switch off reads exactly what it read before.
void main() {
  group('economy.version', () {
    test('absent is the older table', () {
      final caps = EconomyCapabilities.fromJson({'version': 2});
      expect(caps.economyVersion, 0);
      expect(caps.economyV3, isFalse);
    });

    test('version 3 is read from the economy root', () {
      final caps = EconomyCapabilities.fromJson({
        'version': 2,
        'economy': {'version': 3},
      });
      expect(caps.economyV3, isTrue);
    });

    test('a pre-v2 answer stays all off even with the key', () {
      final caps = EconomyCapabilities.fromJson({
        'version': 1,
        'economy': {'version': 3},
      });
      expect(caps.economyV3, isFalse);
    });
  });

  group('invite v3', () {
    final old = {
      'enabled': true,
      'code': 'ABCDEFG',
      'inviterCoins': 100,
      'inviteeCoins': 50,
      'cap': 20,
      'rewarded': 2,
      'pending': 1,
      'canRedeem': false,
    };

    test('switch off: no v3 block, no notices, the old counter', () {
      final status = InviteStatus.fromJson(old);
      expect(status.v3, isFalse);
      expect(status.notices, isEmpty);
      expect(status.rewarded, 2);
    });

    test('settled counts, caps, unlocks and known notices only', () {
      final status = InviteStatus.fromJson({
        ...old,
        'v3': {
          'caps': {'season': 10, 'lifetime': 40},
          'settledSeason': 3,
          'settledLifetime': 4,
          'unlocks': ['title_kabir_elshella'],
          'notices': [
            {'id': 1, 'kind': 'first_match', 'name': 'نور', 'progress': 0, 'coins': 25},
            {'id': 2, 'kind': 'progress', 'name': 'نور', 'progress': 1, 'coins': 0},
            {'id': 3, 'kind': 'role_hint', 'name': 'x'},
          ],
        },
      });
      expect(status.v3, isTrue);
      expect(status.settledSeason, 3);
      expect(status.lifetimeCap, 40);
      expect(status.unlocks, ['title_kabir_elshella']);
      expect(status.notices.map((n) => n.id), [1, 2]);
    });

    test('the two spec lines, in both languages', () {
      final ar = AppLocalizationsAr();
      final en = AppLocalizationsEn();
      const first = InviteNotice(
        id: 1, kind: 'first_match', name: 'نور', progress: 0, coins: 25);
      const progress = InviteNotice(
        id: 2, kind: 'progress', name: 'نور', progress: 1, coins: 0);
      expect(inviteNoticeLine(ar, first), 'نور لعب أول ماتش — خدت 25 عملة');
      expect(inviteNoticeLine(ar, progress), 'صاحبك لعب 1 من 3');
      expect(inviteNoticeLine(en, progress), 'Your friend played 1 of 3');
      const nameless = InviteNotice(
        id: 3, kind: 'first_match', name: ' ', progress: 0, coins: 25);
      expect(inviteNoticeLine(ar, nameless), startsWith('صاحبك'));
    });
  });
}
