import 'package:flutter/material.dart';
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
import 'package:mafia_master/ui/economy/my_cosmetics.dart';
import 'package:mafia_master/ui/economy/my_identity.dart';
import 'package:mafia_master/ui/economy/pass_table_dress.dart';
import 'package:mafia_master/ui/economy/purchase_reveal.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/table/room_presentation.dart';
import 'package:mafia_master/ui/social/friends.dart';
import 'package:mafia_master/ui/widgets/profile_identity.dart';
import 'package:mafia_master/ui/widgets/textured_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

/// Store truth: every equipped item shows where the buyer's identity shows,
/// never in a private phase, and a purchase ends on the item doing its job.
class _Wallet extends WalletController {
  final Map<String, String> equipped;
  _Wallet(this.equipped);
  @override
  Future<WalletState?> build() async => WalletState(
    balance: 500,
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

const _full = {
  'frame': 'frame_crimson',
  'nameplate': 'plate_ember',
  'room_pack': 'pack_moonlit_archive',
  'narrator': 'narrator_keeper',
};

Future<ProviderContainer> _container(Map<String, String> equipped) async {
  final c = ProviderContainer(
    overrides: [
      walletProvider.overrideWith(() => _Wallet(equipped)),
      playerProfileProvider.overrideWith(_Profile.new),
      audioDirectorProvider.overrideWithValue(AudioDirector()),
    ],
  );
  await c.read(walletProvider.future);
  await c.read(playerProfileProvider.future);
  c.read(myCosmeticsProvider);
  return c;
}

Future<void> _pump(WidgetTester tester, ProviderContainer c, Widget child) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: localizedApp(Scaffold(body: SingleChildScrollView(child: child))),
    ),
  );
  await tester.pump();
}

GameSnapshot _snapshot(GamePhase phase, {int day = 1}) => GameSnapshot(
  public: PublicMatchView(
    phase: phase,
    dayNumber: day,
    players: [
      for (var seat = 0; seat < 5; seat++)
        PublicPlayer(seat: seat, name: 'P$seat', status: PlayerStatus.alive),
    ],
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('own cosmetics', () {
    test('the wallet decides; unknown and wrong-slot codes are dropped', () {
      final mine = MyCosmetics.fromEquipped({
        'frame': 'plate_noir',
        'nameplate': 'plate_noir',
        'room_pack': 'pack_nope',
        'narrator': 'narrator_noir',
      });
      expect(mine.frame, isNull);
      expect(mine.plate, 'plate_noir');
      expect(mine.pack, isNull);
      expect(mine.narrator, 'narrator_noir');
    });

    test('kept on the device for an offline «القعدة»', () async {
      final c = await _container(_full);
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MyCosmeticsController.storageKey), contains('frame_crimson'));
    });
  });

  group('frames and plates on the buyer\'s own identity', () {
    testWidgets('identity badge: frame ring and plate', (tester) async {
      final c = await _container(_full);
      addTearDown(c.dispose);
      await _pump(tester, c, const MyIdentityBadge());
      expect(find.byKey(CosmeticFrameRing.ringKey), findsOneWidget);
      expect(find.byKey(CosmeticNameplate.plateKey), findsOneWidget);
      expect(find.text('سلمى'), findsOneWidget);
    });

    testWidgets('nothing equipped: the plain avatar and name', (tester) async {
      final c = await _container(const {});
      addTearDown(c.dispose);
      await _pump(tester, c, const MyIdentityBadge());
      expect(find.byKey(CosmeticFrameRing.ringKey), findsNothing);
      expect(find.byKey(CosmeticNameplate.plateKey), findsNothing);
      expect(find.text('سلمى'), findsOneWidget);
    });

    testWidgets('profile fields: ring on the avatar, the name on the plate', (tester) async {
      final c = await _container(const {});
      addTearDown(c.dispose);
      final name = TextEditingController(text: 'سلمى');
      addTearDown(name.dispose);
      await _pump(
        tester,
        c,
        ProfileIdentityFields(
          name: name,
          nameKey: const ValueKey('n'),
          gender: PlayerGender.female,
          onGender: null,
          avatarDiameter: 64,
          frame: 'frame_gilded',
          plate: 'plate_gilded',
        ),
      );
      expect(find.byKey(CosmeticFrameRing.ringKey), findsOneWidget);
      expect(find.byKey(ProfileIdentityFields.platePreviewKey), findsOneWidget);
    });

    testWidgets('friends rows carry each friend\'s own frame and plate', (tester) async {
      final c = await _container(const {});
      addTearDown(c.dispose);
      final friend = FriendEntry.fromJson({
        'id': 'a',
        'name': 'كريم',
        'frame': 'frame_moonlit',
        'plate': 'plate_noir',
      })!;
      expect(friend.frame, 'frame_moonlit');
      expect(friend.plate, 'plate_noir');
      final plain = FriendEntry.fromJson({'id': 'b', 'name': 'نور'})!;
      expect(plain.frame, isNull);
    });
  });

  group('«القعدة»', () {
    testWidgets('public phases dress backdrops with art; the host seat wears the plate', (
      tester,
    ) async {
      final c = await _container(_full);
      addTearDown(c.dispose);
      for (final phase in [
        GamePhase.morning,
        GamePhase.discussion,
        GamePhase.reveal,
        GamePhase.result,
      ]) {
        await _pump(
          tester,
          c,
          SizedBox(
            height: 400,
            child: PassTableDress(
              phase: phase,
              child: AppBackdrop(
                image: AppImages.bgHome,
                child: Builder(
                  builder: (context) => CosmeticNameplate(
                    name: 'سلمى',
                    plate: HostIdentityScope.plateFor(context, 'سلمى'),
                    style: const TextStyle(),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(PackBackdrop), findsOneWidget, reason: '$phase');
        expect(find.byKey(CosmeticNameplate.plateKey), findsOneWidget, reason: '$phase');
      }
    });

    testWidgets('never on a hand-off, the deal, the night or the passed vote', (
      tester,
    ) async {
      final c = await _container(_full);
      addTearDown(c.dispose);
      for (final phase in [
        GamePhase.distributing,
        GamePhase.preNightLobby,
        GamePhase.night,
        GamePhase.nightResolving,
        GamePhase.voting,
        GamePhase.voteResolving,
      ]) {
        await _pump(
          tester,
          c,
          SizedBox(
            height: 400,
            child: PassTableDress(
              phase: phase,
              child: AppBackdrop(
                image: AppImages.bgHome,
                child: Builder(
                  builder: (context) => CosmeticNameplate(
                    name: 'سلمى',
                    plate: HostIdentityScope.plateFor(context, 'سلمى'),
                    style: const TextStyle(),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(PackBackdrop), findsNothing, reason: '$phase');
        expect(find.byKey(CosmeticNameplate.plateKey), findsNothing, reason: '$phase');
      }
    });

    testWidgets('an in-hand surface (no art) is never dressed', (tester) async {
      final c = await _container(_full);
      addTearDown(c.dispose);
      await _pump(
        tester,
        c,
        const SizedBox(
          height: 300,
          child: PassTableDress(
            phase: GamePhase.discussion,
            child: AppBackdrop(child: SizedBox.shrink()),
          ),
        ),
      );
      expect(find.byType(PackBackdrop), findsNothing);
    });

    testWidgets('only the host\'s own name is dressed', (tester) async {
      final c = await _container(_full);
      addTearDown(c.dispose);
      await _pump(
        tester,
        c,
        PassTableDress(
          phase: GamePhase.discussion,
          child: Builder(
            builder: (context) => CosmeticNameplate(
              name: 'كريم',
              plate: HostIdentityScope.plateFor(context, 'كريم'),
              style: const TextStyle(),
            ),
          ),
        ),
      );
      expect(find.byKey(CosmeticNameplate.plateKey), findsNothing);
    });

    test('the pass-and-play visibility is stricter than the table\'s', () {
      for (final phase in GamePhase.values) {
        if (passCosmeticsVisibleIn(phase)) {
          expect(cosmeticsVisibleIn(phase), isTrue, reason: '$phase');
        }
      }
      expect(passCosmeticsVisibleIn(GamePhase.voting), isFalse);
      expect(cosmeticsVisibleIn(GamePhase.voting), isTrue);
    });
  });

  group('narrator packs', () {
    testWidgets('each pack has its own marker and look', (tester) async {
      final markers = <IconData>{};
      for (final narrator in Cosmetics.narrators.values) {
        markers.add(narrator.look.marker);
        await tester.pumpWidget(
          localizedApp(NarrationCaption(text: 'سطر', narrator: narrator)),
        );
        expect(find.byKey(NarrationCaption.markerKey(narrator.code)), findsOneWidget);
      }
      expect(markers, hasLength(Cosmetics.narrators.length));
      final grounds = {for (final n in Cosmetics.narrators.values) n.look.ground};
      expect(grounds, hasLength(Cosmetics.narrators.length));
    });

    testWidgets('«القعدة»: styled at a public beat, nothing on the passed vote', (
      tester,
    ) async {
      final c = await _container(_full);
      addTearDown(c.dispose);
      Future<void> show(GamePhase phase, {NarrationBeat? moment, int day = 1}) =>
          _pump(
            tester,
            c,
            SizedBox(
              height: 500,
              child: Stack(
                children: [
                  RoomPresentationLayer.local(
                    key: const ValueKey('layer'),
                    snapshot: _snapshot(phase, day: day),
                    packCode: null,
                    narratorCode: 'narrator_keeper',
                    visibleIn: passCosmeticsVisibleIn,
                    moment: moment,
                  ),
                ],
              ),
            ),
          );
      await show(GamePhase.night);
      await show(GamePhase.discussion);
      expect(find.byKey(NarrationCaption.markerKey('narrator_keeper')), findsOneWidget);
      await show(GamePhase.voting);
      expect(find.byKey(NarrationCaption.captionKey), findsNothing,
          reason: 'the vote is passed hand to hand');
      await show(GamePhase.voting, moment: NarrationBeat.voting);
      expect(find.byKey(NarrationCaption.markerKey('narrator_keeper')), findsOneWidget,
          reason: 'the vote announcement is on the flat phone');
      await show(GamePhase.night, day: 2);
      expect(find.byKey(NarrationCaption.captionKey), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('the buy → see loop', () {
    testWidgets('a frame is shown on the buyer\'s own avatar; equip now wears it', (
      tester,
    ) async {
      final c = await _container(const {'nameplate': 'plate_ember'});
      addTearDown(c.dispose);
      (CosmeticSlot, String)? worn;
      await _pump(
        tester,
        c,
        PurchaseReveal(
          code: 'frame_gilded',
          onEquip: (slot, code) async => worn = (slot, code),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(PurchaseReveal.revealKey), findsOneWidget);
      expect(find.byKey(CosmeticFrameRing.ringKey), findsOneWidget);
      expect(find.byKey(CosmeticNameplate.plateKey), findsOneWidget,
          reason: 'shown with the plate already worn');
      expect(find.text('سلمى'), findsOneWidget);
      await tester.tap(find.byKey(PurchaseReveal.equipNowKey));
      await tester.pumpAndSettle();
      expect(worn, (CosmeticSlot.frame, 'frame_gilded'));
    });

    testWidgets('already worn: no equip button, the equipped state instead', (
      tester,
    ) async {
      final c = await _container(const {'frame': 'frame_gilded'});
      addTearDown(c.dispose);
      await _pump(
        tester,
        c,
        PurchaseReveal(code: 'frame_gilded', onEquip: (_, _) async {}),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(PurchaseReveal.equipNowKey), findsNothing);
      expect(find.text(arStrings.storeEquipped), findsOneWidget);
    });

    testWidgets('a bundle lists every part as owned', (tester) async {
      final c = await _container(const {});
      addTearDown(c.dispose);
      await _pump(tester, c, const PurchaseReveal(code: 'bundle_nocturne'));
      await tester.pumpAndSettle();
      for (final part in Cosmetics.bundles['bundle_nocturne']!) {
        expect(find.byKey(PurchaseReveal.partKey(part)), findsOneWidget);
      }
      expect(find.byKey(PurchaseReveal.equipNowKey), findsNothing);
    });

    testWidgets('reduced motion shows the item at rest at once', (tester) async {
      final c = await _container(const {});
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: localizedApp(
            const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(body: PurchaseReveal(code: 'plate_noir')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(CosmeticNameplate.plateKey), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    test('every item kind says what it changes', () {
      for (final kind in CosmeticKind.values) {
        expect(storeWhatItChanges(arStrings, kind), isNotEmpty);
      }
    });
  });
}
