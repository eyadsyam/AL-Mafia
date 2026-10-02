import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/widgets/back_action.dart';
import 'package:mafia_master/ui/widgets/gender_picker.dart';
import 'package:mafia_master/ui/widgets/settings_kit.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// Phase 99: the public journey's presentation fixes, each pinned to the
/// problem the renders showed.
void main() {
  group('profile', () {
    Future<void> pumpProfile(
      WidgetTester tester, {
      VoidCallback? onBack,
    }) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(ProfileScreen(onSaved: () {}, onBack: onBack)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a saved profile arriving after the first frame fills it', (
      tester,
    ) async {
      seedReturningProfile();
      await pumpProfile(tester, onBack: () {});
      final field = tester.widget<TextField>(
        find.byKey(ProfileScreen.nameKey),
      );
      expect(field.controller!.text, 'A');
      // An edit is saved, not "continued".
      expect(find.text(arStrings.save), findsOneWidget);
    });

    testWidgets('a first profile continues; nothing to go back to', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpProfile(tester);
      expect(find.byKey(BackAction.button), findsNothing);
      expect(find.text(arStrings.continueAction), findsOneWidget);
    });

    testWidgets('back leaves without saving', (tester) async {
      seedReturningProfile();
      var back = 0;
      await pumpProfile(tester, onBack: () => back++);
      await tester.tap(find.byKey(BackAction.button));
      expect(back, 1);
    });

    testWidgets('the address choice is labelled and gates saving', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpProfile(tester);
      await tester.enterText(find.byKey(ProfileScreen.nameKey), 'Mona');
      await tester.pump();
      FilledButton save() =>
          tester.widget<FilledButton>(find.byKey(ProfileScreen.saveKey));
      expect(save().onPressed, isNull);
      expect(find.text(arStrings.profileAddressLabel), findsOneWidget);
      expect(find.text(arStrings.playerFemale), findsOneWidget);
      await tester.ensureVisible(find.byKey(GenderPicker.femaleKey));
      await tester.pumpAndSettle();
      // The interactive area (the InkWell that takes the tap), not the
      // painted thumb, is at least 48 x 48 for both options.
      for (final key in [GenderPicker.maleKey, GenderPicker.femaleKey]) {
        final ink = tester.getSize(
          find.descendant(of: find.byKey(key), matching: find.byType(InkWell)),
        );
        expect(ink.height, greaterThanOrEqualTo(SettingsTokens.segmentHeight));
        expect(ink.height, greaterThanOrEqualTo(48));
        expect(ink.width, greaterThanOrEqualTo(48));
      }
      // A tap 2 dp inside the top edge — outside the painted thumb's inset —
      // still chooses the option.
      final box = tester.getRect(find.byKey(GenderPicker.femaleKey));
      await tester.tapAt(Offset(box.center.dx, box.top + 2));
      await tester.pump();
      expect(
        tester
            .widget<SettingsSegment>(find.byKey(GenderPicker.femaleKey))
            .selected,
        isTrue,
      );
      expect(save().onPressed, isNotNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  group('a profile that loads late', () {
    late Completer<PlayerProfile?> gate;
    late ProviderContainer container;

    Future<void> pumpGated(WidgetTester tester, {VoidCallback? onSaved}) async {
      SharedPreferences.setMockInitialValues({});
      gate = Completer<PlayerProfile?>();
      container = ProviderContainer(
        overrides: [
          profileStoreProvider.overrideWithValue(_GatedProfileStore(gate)),
        ],
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            ProfileScreen(onSaved: onSaved ?? () {}, onBack: () {}),
          ),
        ),
      );
      await tester.pump();
    }

    String name(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(ProfileScreen.nameKey))
        .controller!
        .text;
    bool chosen(WidgetTester tester, Key key) =>
        tester.widget<SettingsSegment>(find.byKey(key)).selected;
    const saved = PlayerProfile(name: 'Karim', gender: PlayerGender.male);

    testWidgets('an untouched form takes the saved profile', (tester) async {
      await pumpGated(tester);
      expect(name(tester), isEmpty);
      gate.complete(saved);
      await tester.pumpAndSettle();
      expect(name(tester), 'Karim');
      expect(chosen(tester, GenderPicker.maleKey), isTrue);
      expect(find.text(arStrings.save), findsOneWidget);
    });

    testWidgets('a name typed before the load is kept', (tester) async {
      await pumpGated(tester);
      await tester.enterText(find.byKey(ProfileScreen.nameKey), 'Mona');
      gate.complete(saved);
      await tester.pumpAndSettle();
      expect(name(tester), 'Mona');
      expect(chosen(tester, GenderPicker.maleKey), isFalse);
    });

    testWidgets('an address chosen before the load is kept', (tester) async {
      await pumpGated(tester);
      await tester.ensureVisible(find.byKey(GenderPicker.femaleKey));
      await tester.tap(find.byKey(GenderPicker.femaleKey));
      await tester.pump();
      gate.complete(saved);
      await tester.pumpAndSettle();
      expect(chosen(tester, GenderPicker.femaleKey), isTrue);
      expect(chosen(tester, GenderPicker.maleKey), isFalse);
      expect(name(tester), isEmpty);
    });

    testWidgets('saving before the load finishes is not undone by it', (
      tester,
    ) async {
      var done = 0;
      await pumpGated(tester, onSaved: () => done++);
      await tester.enterText(find.byKey(ProfileScreen.nameKey), 'Mona');
      await tester.ensureVisible(find.byKey(GenderPicker.femaleKey));
      await tester.tap(find.byKey(GenderPicker.femaleKey));
      await tester.pump();
      await tester.tap(find.byKey(ProfileScreen.saveKey));
      await tester.pumpAndSettle();
      expect(done, 1);
      // The stale read lands after the save.
      gate.complete(saved);
      await tester.pumpAndSettle();
      final now = container.read(playerProfileProvider).valueOrNull;
      expect(now?.name, 'Mona');
      expect(now?.gender, PlayerGender.female);
      final stored = (await SharedPreferences.getInstance()).getString(
        ProfileStore.profileKey,
      );
      expect(jsonDecode(stored!)['name'], 'Mona');
    });
  });

  group('online door and lobby', () {
    late FakeBackend backend;
    setUp(seedReturningProfile);

    ProviderContainer container({List<Map<String, dynamic>> rooms = const []}) {
      backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
        players: roster(3),
        own: const OwnSeat(seat: 0),
      );
      backend.responses['browse_rooms'] = {'rooms': rooms};
      final c = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          onlineHeartbeatProvider.overrideWithValue(Duration.zero),
          voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> pumpEntry(WidgetTester tester, ProviderContainer c) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await c.read(playerProfileProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: localizedApp(
            OnlineEntryScreen(onJoined: () {}, onBack: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('who you play as is one chip that opens the profile', (
      tester,
    ) async {
      await pumpEntry(tester, container());
      expect(find.text(arStrings.onlinePlayingAs('A')), findsOneWidget);
      final chip = find.byKey(const ValueKey('online_identity'));
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      // Back returns to the door with nothing changed.
      await tester.tap(find.byKey(BackAction.button));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsNothing);
      expect(find.byKey(OnlineEntryScreen.hostButton), findsOneWidget);
    });

    testWidgets('create and join are an equal, 48 dp pair above the list', (
      tester,
    ) async {
      await pumpEntry(tester, container());
      final create = tester.getRect(find.byKey(OnlineEntryScreen.hostButton));
      final join = tester.getRect(
        find.byKey(OnlineEntryScreen.haveCodeButton),
      );
      expect(create.width, closeTo(join.width, 1));
      expect(create.height, greaterThanOrEqualTo(48));
      expect(create.top, closeTo(join.top, 1));
      // Arabic: create, the lit one, reads first (on the right).
      expect(create.left, greaterThan(join.left));
    });

    testWidgets('an empty list says what to do next', (tester) async {
      await pumpEntry(tester, container());
      await tester.pumpAndSettle();
      expect(find.text(arStrings.onlineNoPublicRooms), findsOneWidget);
      expect(find.text(arStrings.onlineNoPublicRoomsHint), findsOneWidget);
    });

    testWidgets('the lobby invite is a labelled 48 dp button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = container();
      await c.read(playerProfileProvider.future);
      await c.read(onlineSessionProvider.notifier).host('A');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: localizedApp(LobbyScreen(onStarted: () {}, onLeave: () {})),
        ),
      );
      await tester.pump();
      final share = find.byKey(LobbyScreen.shareButton);
      expect(
        find.descendant(
          of: share,
          matching: find.text(arStrings.lobbyInviteFriends),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(share).height, greaterThanOrEqualTo(48));
      expect(find.byKey(LobbyScreen.copyButton), findsOneWidget);
      // One numeral system on the screen: «5», like «3 / 10».
      expect(arStrings.onlineNeedFivePlayers.contains('٥'), isFalse);
    });
  });
}

/// The real store, with its first read held until the test releases it.
class _GatedProfileStore extends ProfileStore {
  final Completer<PlayerProfile?> gate;
  _GatedProfileStore(this.gate);

  @override
  Future<PlayerProfile?> load() => gate.future;
}
