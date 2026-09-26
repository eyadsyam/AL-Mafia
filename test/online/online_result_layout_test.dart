import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/fun/award_ribbon.dart';
import 'package:mafia_master/ui/fun/match_awards.dart';
import 'package:mafia_master/ui/fun/reactions.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';

import '../support/fake_backend.dart';
import '../support/fake_voice_engine.dart';
import '../support/localized.dart';

/// The online result's hand on short phones: the award ribbon, the reactions
/// bar and a floating reaction all present, and still no overflow and the
/// rematch on screen and tappable.
void main() {
  Map<String, dynamic> economy(Map<String, dynamic> body) =>
      switch (body['action']) {
        'capabilities' => {
          'version': 2,
          'fun': {'awards': true, 'reactions': true, 'known': true},
        },
        'awards_get' => {
          'enabled': true,
          'ready': true,
          'awards': [
            {
              'code': 'mvp',
              'seats': [2],
              'names': ['منى عبد الرحمن'],
              'coins': 20,
            },
            {
              'code': 'sharpEye',
              'seats': [3],
              'names': ['Karim'],
              'coins': 10,
            },
            {
              'code': 'survivor',
              'seats': [2, 3, 4],
              'names': ['Mona', 'Karim', 'Laila'],
              'coins': 5,
            },
          ],
          'mine': ['mvp'],
          'granted': 20,
        },
        _ => {'ok': true},
      };

  for (final size in const [Size(320, 640), Size(360, 640), Size(430, 640)]) {
    testWidgets(
      'result with awards and reactions fits ${size.width.toInt()}x640',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final backend = FakeBackend(
          roomId: 'room-1',
          state: roomState(
            phase: 'result',
            phaseNumber: 2,
            status: 'finished',
            publicData: const {
              'outcome': 'town',
              'rosterSeats': [0, 1, 2, 3, 4],
              'standings': [
                {'seat': 0, 'role': 'mafia'},
                {'seat': 1, 'role': 'citizen'},
                {'seat': 2, 'role': 'doctor'},
                {'seat': 3, 'role': 'detective'},
                {'seat': 4, 'role': 'citizen'},
              ],
            },
          ),
          players: roster(5),
          own: const OwnSeat(seat: 2, role: 'doctor'),
          userId: 'u2',
        );
        backend.responders['economy'] = economy;
        final transport = await OnlineTransport.connect(
          backend: backend,
          roomId: 'room-1',
          heartbeatInterval: Duration.zero,
        );
        final container = ProviderContainer(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
            audioDirectorProvider.overrideWithValue(AudioDirector()),
            voiceEngineFactoryProvider.overrideWithValue(FakeVoiceEngine.new),
            voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
            onlineSessionProvider.overrideWith(
              () => _FixedOnlineSession(
                const RoomHandle(roomId: 'room-1', code: 'ABCDEF', seat: 2),
                transport,
              ),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await transport.dispose();
        });
        container.read(matchControllerProvider.notifier).adoptSnapshot();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedApp(
              Scaffold(
                body: OnlineTableFlow(
                  onExit: () {},
                  onAnalytics: () {},
                  onStepCommitted: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 12));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        expect(find.byKey(AwardRibbon.card(AwardKind.mvp)), findsOneWidget);
        expect(find.byKey(ReactionBar.barKey), findsOneWidget);

        // A reaction arrives and floats over the hand.
        backend.reactionFeed.add(
          const RoomReactionRow(id: 1, seat: 3, kind: 'laugh'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(ReactionFloats.floatKey), findsOneWidget);
        expect(tester.takeException(), isNull);

        final rematch = find.byKey(OnlineTableFlow.playAgain);
        expect(rematch, findsOneWidget);
        expect(rematch.hitTestable(), findsOneWidget);
        final box = tester.getRect(rematch);
        expect(box.bottom, lessThanOrEqualTo(size.height));

        // Roles and home are one scroll away, never cut off.
        await tester.scrollUntilVisible(
          find.byKey(OnlineTableFlow.seeRoles),
          40,
          scrollable: find
              .descendant(
                of: find.byKey(OnlineTableFlow.resultScroll),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.byKey(OnlineTableFlow.seeRoles).hitTestable(),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _FixedOnlineSession extends OnlineSession {
  final RoomHandle handle;
  final OnlineTransport transport;
  _FixedOnlineSession(this.handle, this.transport);

  @override
  OnlineSessionState build() =>
      OnlineSessionState(room: handle, transport: transport);
}
