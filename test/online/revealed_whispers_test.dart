import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/transport/room_codec.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/council/revealed_whispers.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';

import '../support/fake_backend.dart';
import '../support/fake_voice_engine.dart';
import '../support/localized.dart';

/// Doc 09 §7 «كشف محتوى الهمسات بعد المباراة»: off unless the room chose
/// it; when on, the finished match's whispers open from the result.
void main() {
  test('the room rule is read from the room settings, off by default', () {
    expect(settingsFromJson(const {}).revealWhisperContent, isFalse);
    expect(
      settingsFromJson(const {'revealWhisperContent': true})
          .revealWhisperContent,
      isTrue,
    );
  });

  test('malformed rows are skipped; null means not revealed', () {
    expect(RevealedWhisper.listFromJson(null), isNull);
    final rows = RevealedWhisper.listFromJson([
      {'day': 1, 'fromSeat': 0, 'toSeat': 2, 'text': 'hi', 'masked': false},
      {'day': '1', 'fromSeat': 0, 'toSeat': 2},
      {'day': 2, 'fromSeat': 3, 'toSeat': 1, 'text': null, 'masked': true},
    ])!;
    expect(rows, hasLength(2));
    expect(rows.last.masked, isTrue);
    expect(rows.last.text, isNull);
  });

  Future<FakeBackend> pumpResult(
    WidgetTester tester, {
    required bool reveal,
    String phase = 'result',
  }) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(
        phase: phase,
        phaseNumber: 2,
        status: phase == 'result' ? 'finished' : 'playing',
        endsAt: phase == 'result'
            ? null
            : DateTime.now().add(const Duration(minutes: 4)),
        serverNow: DateTime.now(),
        settings: {'revealWhisperContent': reveal, 'whisperEnabled': true},
        publicData: phase != 'result' ? const {} : const {
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
    backend.responders['economy'] = (body) => switch (body['action']) {
      'matchWhispers' => {
        'whispers': [
          {
            'id': 'w1',
            'day': 1,
            'fromSeat': 0,
            'toSeat': 2,
            'text': 'صدقني',
            'masked': false,
          },
          {
            'id': 'w2',
            'day': 2,
            'fromSeat': 3,
            'toSeat': 1,
            'text': null,
            'masked': true,
          },
        ],
      },
      _ => {'ok': true},
    };
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
    return backend;
  }

  Iterable<FakeCall> reads(FakeBackend backend) => backend.calls.where(
    (c) => c.function == 'economy' && c.body['action'] == 'matchWhispers',
  );

  testWidgets('a room that chose it: the result opens its whispers', (
    tester,
  ) async {
    final backend = await pumpResult(tester, reveal: true);
    final button = find.byKey(OnlineTableFlow.revealedWhispers);
    await tester.scrollUntilVisible(
      button,
      40,
      scrollable: find
          .descendant(
            of: find.byKey(OnlineTableFlow.resultScroll),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(reads(backend), isEmpty, reason: 'nothing read before the tap');
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(RevealedWhispers.sheetKey), findsOneWidget);
    expect(reads(backend).single.body['roomId'], 'room-1');
    expect(find.text('صدقني'), findsOneWidget);
    expect(find.text(arStrings.revealWhispersMasked), findsOneWidget);
    expect(find.byKey(RevealedWhispers.row(0)), findsOneWidget);
    await tester.tap(find.byType(TextButton).last);
    await tester.pump();
    expect(find.byKey(RevealedWhispers.sheetKey), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the default room: no button and nothing is asked', (
    tester,
  ) async {
    final backend = await pumpResult(tester, reveal: false);
    expect(find.byKey(OnlineTableFlow.revealedWhispers), findsNothing);
    expect(reads(backend), isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the whisper composer says the room will reveal it', (
    tester,
  ) async {
    await pumpResult(tester, reveal: true, phase: 'discuss');
    final whisper = find.byKey(OnlineTableFlow.whisperButton);
    expect(whisper, findsOneWidget);
    await tester.tap(whisper);
    await tester.pump();
    expect(find.byKey(RevealWhispersNotice.noticeKey), findsOneWidget);
    expect(find.text(arStrings.revealWhispersNotice), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('without the rule the composer carries no notice', (
    tester,
  ) async {
    await pumpResult(tester, reveal: false, phase: 'discuss');
    await tester.tap(find.byKey(OnlineTableFlow.whisperButton));
    await tester.pump();
    expect(find.byKey(RevealWhispersNotice.noticeKey), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}

class _FixedOnlineSession extends OnlineSession {
  final RoomHandle handle;
  final OnlineTransport transport;
  _FixedOnlineSession(this.handle, this.transport);

  @override
  OnlineSessionState build() =>
      OnlineSessionState(room: handle, transport: transport);
}
