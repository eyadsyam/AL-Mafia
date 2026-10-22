import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/ui/economy/cosmetic_paint.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/widgets/player_avatar.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';

import '../support/localized.dart';

class _Profile extends PlayerProfileController {
  @override
  Future<PlayerProfile?> build() async =>
      const PlayerProfile(name: 'سلمى', gender: PlayerGender.female);
}

class _Wallet extends WalletController {
  @override
  Future<WalletState?> build() async => const WalletState(
    balance: 100,
    catalog: [],
    owned: {'frame_crimson', 'plate_ember'},
    equipped: {'frame': 'frame_crimson', 'nameplate': 'plate_ember'},
    history: [],
  );
}

void main() {
  for (final size in const [Size(1440, 900), Size(390, 844)]) {
    testWidgets('Home layout at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [audioDirectorProvider.overrideWithValue(AudioDirector())],
          child: localizedApp(
            HomeScreen(
              onNewMatch: () {},
              onHistory: () {},
              onSettings: () {},
              onHowToPlay: () {},
              tiltSource: const LevelTiltSource(),
            ),
          ),
        ),
      );
      await tester.pump();
      final desktop = size.width >= 1024;
      expect(
        find.byKey(const ValueKey('home_desktop_start')),
        desktop ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home_desktop_end')),
        desktop ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(HomeScreen.startButton), findsOneWidget);
    });
  }

  testWidgets('Home has one profile entry: the dressed identity chip', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProfileProvider.overrideWith(_Profile.new),
          walletProvider.overrideWith(_Wallet.new),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
        ],
        child: localizedApp(
          HomeScreen(
            onNewMatch: () {},
            onHistory: () {},
            onSettings: () {},
            onHowToPlay: () {},
            onProfile: () => opens++,
            tiltSource: const LevelTiltSource(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('home_profile')), findsNothing);
    expect(find.byKey(HomeScreen.identityChipKey), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    final chip = find.byKey(HomeScreen.identityChipKey);
    expect(
      find.descendant(of: chip, matching: find.byType(CosmeticFrameRing)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chip, matching: find.byType(PlayerAvatar)),
      findsOneWidget,
    );
    // Avatar only beside the corner icons; the name is its tooltip.
    expect(find.byTooltip('سلمى'), findsOneWidget);
    final ring = tester.widget<CosmeticFrameRing>(
      find.descendant(of: chip, matching: find.byType(CosmeticFrameRing)),
    );
    expect(ring.frame, 'frame_crimson');
    await tester.tap(find.byKey(HomeScreen.identityChipKey));
    expect(opens, 1);
  });
}
