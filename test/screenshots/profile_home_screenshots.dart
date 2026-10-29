/// Renders the update 1.5 profile, friends and account screens (WP7) for the
/// owner to look at. **Not a test** (no `_test` suffix, asserts only that
/// each screen renders without an exception).
///
///     flutter test test/screenshots/profile_home_screenshots.dart
///
/// Writes to `build/profile_home/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart'
    show accountsAvailableProvider;
import 'package:mafia_master/ui/account/profile_panels.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/social/friends.dart';
import 'package:mafia_master/ui/social/titles_partner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

const _long = 'عبد الرحمن محمد السيد الجمال';

final _sample = FriendsState.fromJson({
  'friends': [
    {
      'id': 'a',
      'name': 'سيف',
      'presence': {'state': 'lobby', 'code': 'K7M2QP', 'players': 4},
    },
    {
      'id': 'b',
      'name': 'هبة الله أحمد',
      'gender': 'female',
      'presence': {'state': 'playing'},
    },
    {'id': 'c', 'name': _long},
  ],
  'incoming': [
    {'id': 'r1', 'name': _long},
    {'id': 'r2', 'name': 'منى', 'gender': 'female'},
  ],
  'recent': [
    {'id': 'e', 'name': 'نور', 'matches': 1},
  ],
  'me': {'handle': 'karim', 'searchable': true, 'strangerInvites': true},
});

class _Friends extends FriendsController {
  @override
  Future<FriendsState?> build() async => _sample;
  @override
  Future<void> refresh() async {}
}

class _Wallet extends WalletController {
  @override
  Future<WalletState?> build() async => WalletState.fromJson({'balance': 340});
}

class _Hub extends TitleHubController {
  @override
  Future<TitleHub> build() async => TitleHub.fromJson({
    'enabled': true,
    'equipped': 'kabir_elshella',
    'titles': [
      {
        'code': 'kabir_elshella',
        'source': 'invite',
        'nameAr': 'الشبح',
        'nameEn': 'The Ghost',
        'owned': true,
      },
      {
        'code': 'season_zero_casekeeper',
        'source': 'season',
        'nameAr': 'حافظ القضايا',
        'nameEn': 'Casekeeper',
        'owned': true,
      },
    ],
  });
}

class _Asked extends ConsumerWidget {
  final Widget child;
  const _Asked({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(economyCapabilitiesProvider);
    ref.watch(friendsProvider);
    ref.watch(titleHubProvider);
    return child;
  }
}

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

void main() {
  final out = Directory('build/profile_home')..createSync(recursive: true);

  Future<void> capture(WidgetTester tester, String name) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage(
            (element.widget as Image).image,
            element,
          ).timeout(const Duration(seconds: 2), onTimeout: () {});
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 400));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 1);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
    expect(tester.takeException(), isNull, reason: '$name must render cleanly');
  }

  Future<void> open(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: '{"name":"كريم","gender":"male"}',
    });
    await tester.runAsync(_fonts);
    await loadArtwork(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [
            accountsAvailableProvider.overrideWithValue(true),
            accountProfileProvider.overrideWith(
              (ref) => Stream.value(AccountProfile.guest),
            ),
            economyCapabilitiesProvider.overrideWith(
              (ref) async =>
                  const EconomyCapabilities(friends: true, titles: true),
            ),
            friendsProvider.overrideWith(_Friends.new),
            walletProvider.overrideWith(_Wallet.new),
            titleHubProvider.overrideWith(_Hub.new),
            profileStatsProvider.overrideWith((ref) async => (12, 5)),
            profileLastMatchProvider.overrideWith(
              (ref) async => DateTime(2026, 10, 28, 20),
            ),
            profileClockProvider.overrideWithValue(
              () => DateTime(2026, 10, 29, 12),
            ),
          ],
          child: localizedApp(
            _Asked(
              child: ProfileScreen(
                onBack: () {},
                onSaved: () {},
                onHistory: () {},
                onJoinRoom: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (tag, size) in const [
    ('phone', Size(390, 844)),
    ('small', Size(360, 640)),
    ('landscape', Size(640, 360)),
  ]) {
    testWidgets('profile $tag', (tester) async {
      await open(tester, size);
      await capture(tester, '${tag}_1_profile');
    });
    testWidgets('friends sheet $tag', (tester) async {
      await open(tester, size);
      await tester.tap(find.byKey(ProfileScreen.friendsKey));
      await tester.pumpAndSettle();
      await capture(tester, '${tag}_2_friends');
      await tester.tap(find.byKey(FriendsSheetKeys.search));
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * 0.4);
      await tester.pumpAndSettle();
      await capture(tester, '${tag}_3_friends_keyboard');
    });
    testWidgets('account sheet $tag', (tester) async {
      await open(tester, size);
      await tester.tap(find.byKey(AccountCard.cardKey));
      await tester.pumpAndSettle();
      await capture(tester, '${tag}_4_account');
    });
    testWidgets('titles sheet $tag', (tester) async {
      await open(tester, size);
      await tester.tap(find.byKey(ProfileScreen.titlesKey));
      await tester.pumpAndSettle();
      await capture(tester, '${tag}_5_titles');
    });
    testWidgets('identity sheet $tag', (tester) async {
      await open(tester, size);
      await tester.tap(find.byKey(ProfileIdentityHeader.headerKey));
      await tester.pumpAndSettle();
      await capture(tester, '${tag}_6_identity');
    });
  }
}
