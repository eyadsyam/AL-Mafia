/// Renders the store-truth placements for the owner to look at: the purchase
/// reveal, try-on, the buyer's own identity, friends rows, the «القعدة»
/// dressing and the three narrator looks.
///
/// **Not a test** (no `_test` suffix, asserts nothing), like
/// `casebook_screenshots.dart`.
///
///     flutter test test/screenshots/store_truth_screenshots.dart
///
/// Writes 390 px wide PNGs to `build/screens_store/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/economy/cosmetic_paint.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';
import 'package:mafia_master/ui/economy/my_identity.dart';
import 'package:mafia_master/ui/economy/pass_table_dress.dart';
import 'package:mafia_master/ui/economy/purchase_reveal.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/table/room_presentation.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/social/friends.dart';
import 'package:mafia_master/ui/widgets/profile_identity.dart';
import 'package:mafia_master/ui/widgets/textured_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

const _phone = Size(390, 844);

class _Wallet extends WalletController {
  final Map<String, String> equipped;
  _Wallet(this.equipped);
  @override
  Future<WalletState?> build() async => WalletState(
    balance: 1200,
    catalog: const [],
    owned: {...equipped.values},
    equipped: equipped,
    history: const [],
  );
}

class _Profile extends PlayerProfileController {
  @override
  Future<PlayerProfile?> build() async =>
      const PlayerProfile(name: 'سلمى', gender: PlayerGender.female);
}

class _Friends extends FriendsController {
  @override
  Future<FriendsState?> build() async => FriendsState.fromJson({
    'friends': [
      {
        'id': 'a',
        'name': 'كريم',
        'gender': 'male',
        'frame': 'frame_crimson',
        'plate': 'plate_ember',
        'presence': {'state': 'lobby', 'code': 'K7M2QP', 'players': 4},
      },
      {'id': 'b', 'name': 'نور', 'gender': 'female', 'frame': 'frame_moonlit'},
      {'id': 'c', 'name': 'عمر', 'gender': 'male'},
    ],
  });
  @override
  Future<void> refresh() async {}
}

const _dressed = {
  'frame': 'frame_gilded',
  'nameplate': 'plate_gilded',
  'room_pack': 'pack_moonlit_archive',
  'narrator': 'narrator_noir',
};

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

void main() {
  final out = Directory('build/screens_store')..createSync(recursive: true);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    Map<String, String> equipped = _dressed,
    List<Override> extra = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(_fonts);
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith(() => _Wallet(equipped)),
        playerProfileProvider.overrideWith(_Profile.new),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(walletProvider.future);
      await container.read(playerProfileProvider.future);
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: UncontrolledProviderScope(
          container: container,
          child: localizedApp(child),
        ),
      ),
    );
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
      await tester.pump(const Duration(milliseconds: 300));
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
  }

  Widget page(Widget child) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );

  testWidgets('purchase reveal: frame on the buyer', (tester) async {
    await shoot(
      tester,
      'reveal_frame_ar',
      page(PurchaseReveal(code: 'frame_crimson', onEquip: (_, _) async {})),
      equipped: const {'nameplate': 'plate_ember'},
    );
  });

  testWidgets('purchase reveal: bundle parts', (tester) async {
    await shoot(tester, 'reveal_bundle_ar', page(const PurchaseReveal(code: 'bundle_nocturne')));
  });

  testWidgets('try on: nameplate', (tester) async {
    await shoot(tester, 'try_on_plate_ar', page(const TryOnPreview(code: 'plate_noir')));
  });

  testWidgets('own identity: chip and sheet', (tester) async {
    await shoot(
      tester,
      'identity_ar',
      page(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MyIdentityBadge(),
            SizedBox(height: 40),
            MyIdentityBadge(axis: Axis.vertical, diameter: 64),
          ],
        ),
      ),
    );
  });

  testWidgets('profile fields', (tester) async {
    final name = TextEditingController(text: 'سلمى');
    addTearDown(name.dispose);
    await shoot(
      tester,
      'profile_fields_ar',
      page(
        ProfileIdentityFields(
          name: name,
          nameKey: const ValueKey('n'),
          gender: PlayerGender.female,
          onGender: null,
          avatarDiameter: 64,
          frame: 'frame_gilded',
          plate: 'plate_gilded',
        ),
      ),
    );
  });

  testWidgets('friends rows', (tester) async {
    await shoot(
      tester,
      'friends_rows_ar',
      Scaffold(body: FriendsSheet(onJoin: (_) {})),
      extra: [friendsProvider.overrideWith(_Friends.new)],
    );
  });

  testWidgets('«القعدة» discussion dressed', (tester) async {
    final snapshot = GameSnapshot(
      public: PublicMatchView(
        phase: GamePhase.discussion,
        dayNumber: 2,
        players: [
          for (var seat = 0; seat < 5; seat++)
            PublicPlayer(seat: seat, name: 'P$seat', status: PlayerStatus.alive),
        ],
      ),
    );
    await shoot(
      tester,
      'pass_discussion_dressed_ar',
      Scaffold(
        body: PassTableDress(
          phase: GamePhase.discussion,
          child: AppBackdrop(
            image: AppImages.bgDay,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Builder(
                    builder: (context) => CosmeticNameplate(
                      name: 'سلمى',
                      plate: HostIdentityScope.plateFor(context, 'سلمى'),
                      style: Theme.of(context).textTheme.headlineSmall!,
                    ),
                  ),
                ),
                RoomPresentationLayer.local(
                  snapshot: snapshot,
                  packCode: null,
                  narratorCode: 'narrator_noir',
                  visibleIn: passCosmeticsVisibleIn,
                  moment: NarrationBeat.discussion,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('narrator looks', (tester) async {
    await shoot(
      tester,
      'narrator_looks_ar',
      page(
        Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final n in Cosmetics.narrators.values) ...[
                NarrationCaption(
                  text: n.line(context.l10n, NarrationBeat.voting),
                  narrator: n,
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  });
}
