import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/platform/invite_share.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/room_invite.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:share_plus/share_plus.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/stores.dart';

void main() {
  group('InviteSharer', () {
    test('a shown sheet is handed over, never reported as delivered', () async {
      for (final status in ShareResultStatus.values) {
        var copied = false;
        final sharer = InviteSharer(
          share: (_) async => ShareResult('', status),
          copy: (_) async => copied = true,
        );
        expect(
          await sharer.share(text: 't', subject: 's'),
          InviteShareOutcome.handedOver,
        );
        expect(copied, isFalse, reason: 'no clipboard write behind a sheet');
      }
    });

    test(
      'no share sheet: the link is copied, and says so only if it was',
      () async {
        ShareParams? seen;
        final ok = InviteSharer(
          share: (params) async {
            seen = params;
            throw Exception('Navigator.canShare() is unavailable');
          },
          copy: (_) async => true,
        );
        expect(
          await ok.share(text: 'invite', subject: 's'),
          InviteShareOutcome.copied,
        );
        expect(seen!.mailToFallbackEnabled, isFalse);
        final refused = InviteSharer(
          share: (_) async => throw Exception('no'),
          copy: (_) async => false,
        );
        expect(
          await refused.share(text: 'invite', subject: 's'),
          InviteShareOutcome.failed,
        );
      },
    );
  });

  group('lobby share', () {
    setUp(seedReturningProfile);
    late FakeBackend backend;

    Future<ProviderContainer> pump(
      WidgetTester tester,
      InviteSharer sharer, {
      bool referrals = false,
    }) async {
      backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
        players: roster(3),
        own: const OwnSeat(seat: 0),
      );
      final container = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          onlineHeartbeatProvider.overrideWithValue(Duration.zero),
          voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
          inviteSharerProvider.overrideWithValue(sharer),
          if (referrals)
            economyCapabilitiesProvider.overrideWith(
              (ref) async => const EconomyCapabilities(
                council: CouncilCapabilities(invites: true),
              ),
            ),
        ],
      );
      if (referrals) {
        backend.responders['economy'] = (body) => body['action'] == 'invite_get'
            ? const {'enabled': true, 'code': '43D4YUG'}
            : const {'ok': true};
      }
      addTearDown(container.dispose);
      container.read(playerProfileProvider);
      await container.read(onlineSessionProvider.notifier).host('A');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(LobbyScreen(onStarted: () {}, onLeave: () {})),
        ),
      );
      await tester.pump();
      return container;
    }

    testWidgets('the host shares the room with their referral code and '
        'sees the offer', (tester) async {
      ShareParams? shared;
      await pump(
        tester,
        InviteSharer(
          share: (params) async {
            shared = params;
            return const ShareResult('', ShareResultStatus.success);
          },
          copy: (_) async => fail('no copy behind a sheet'),
        ),
        referrals: true,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(arStrings.onlineReferralOffer), findsOneWidget);
      await tester.tap(find.byKey(LobbyScreen.shareButton));
      await tester.pump();
      await tester.pump();
      expect(
        shared!.text,
        contains(RoomInvite.webLink('ABCDEF', referralCode: '43D4YUG')),
      );
      expect(shared!.text, contains(arStrings.onlineReferralOffer));
    });

    testWidgets(
      'dismissing the sheet returns to the same lobby, still seated',
      (tester) async {
        ShareParams? shared;
        final container = await pump(
          tester,
          InviteSharer(
            share: (params) async {
              shared = params;
              return const ShareResult('', ShareResultStatus.dismissed);
            },
            copy: (_) async => fail('no copy behind a sheet'),
          ),
        );
        await tester.tap(find.byKey(LobbyScreen.shareButton));
        await tester.pump();
        await tester.pump();

        expect(shared!.text, contains(RoomInvite.webLink('ABCDEF')));
        expect(shared!.sharePositionOrigin, isNotNull);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(LobbyScreen), findsOneWidget);
        expect(container.read(onlineSessionProvider).isInRoom, isTrue);
        expect(backend.called('leave_room'), isFalse);
        expect(backend.called('close_room'), isFalse);

        // The chosen app coming to the front and going away again: the seat is
        // marked away and back, and nothing is torn down.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        final presence = backend.calls
            .where((call) => call.function == 'set_presence')
            .map((call) => call.body['status'])
            .toList();
        expect(presence.last, 'connected');
        expect(presence, contains('away'));
        expect(container.read(onlineSessionProvider).isInRoom, isTrue);
        expect(find.byType(LobbyScreen), findsOneWidget);
        expect(backend.called('leave_room'), isFalse);
      },
    );

    testWidgets('a browser without Web Share gets the link copied', (
      tester,
    ) async {
      await pump(
        tester,
        InviteSharer(
          share: (_) async => throw Exception('unsupported'),
          copy: (_) async => true,
        ),
      );
      await tester.tap(find.byKey(LobbyScreen.shareButton));
      await tester.pump();
      await tester.pump();
      expect(find.text(arStrings.onlineLinkCopied), findsOneWidget);
    });

    testWidgets('a failure is never announced as a copy', (tester) async {
      await pump(
        tester,
        InviteSharer(
          share: (_) async => throw Exception('unsupported'),
          copy: (_) async => false,
        ),
      );
      await tester.tap(find.byKey(LobbyScreen.shareButton));
      await tester.pump();
      await tester.pump();
      expect(find.text(arStrings.onlineLinkCopied), findsNothing);
      expect(find.text(arStrings.onlineShareFailed), findsOneWidget);
    });
  });
}
