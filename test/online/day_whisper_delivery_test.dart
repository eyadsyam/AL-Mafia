import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/widgets/whisper_card.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Doc 14 §3.2–3.4: a whisper is sent in the discussion and delivered
/// **immediately** — the recipient reads it on the card over the live table,
/// not at night. Only the two ends ever hold the words.
void main() {
  FakeBackend backend0({List<WhisperRow> whispers = const []}) {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'discuss', phaseNumber: 2, hostId: 'u4'),
      players: roster(5),
      own: const OwnSeat(seat: 0, role: 'citizen'),
      whispers: whispers,
    );
    backend.bodies['w1'] = 'صوّت على D';
    return backend;
  }

  const toMe = WhisperRow(id: 'w1', day: 2, fromSeat: 2, toSeat: 0, toMe: true);

  Future<OnlineTransport> connect(FakeBackend backend) async {
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    addTearDown(transport.dispose);
    return transport;
  }

  test('in the discussion the recipient\'s secrets carry the words', () async {
    final transport = await connect(backend0(whispers: const [toMe]));
    final secrets = await transport.secretsFor(0);
    expect(secrets?.whisperId, 'w1');
    expect(secrets?.whisperBody, 'صوّت على D');
  });

  test('a whisper already shown is not fetched again', () async {
    final transport = await connect(backend0(whispers: const [toMe]));
    await transport.markWhisperDelivered('w1');
    final secrets = await transport.secretsFor(0);
    expect(secrets?.whisperBody, isNull);
  });

  test('nobody else\'s seat ever gets secrets', () async {
    final transport = await connect(backend0(whispers: const [toMe]));
    expect(await transport.secretsFor(2), isNull);
  });

  testWidgets('arriving mid-argument: the card over the table, then gone', (
    tester,
  ) async {
    final backend = backend0();
    final transport = await connect(backend);
    final container = ProviderContainer(
      overrides: [
        gameTransportProvider.overrideWithValue(transport),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
    );
    addTearDown(container.dispose);
    container.read(matchControllerProvider.notifier).adoptSnapshot();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          OnlineTableFlow(
            onExit: () {},
            onAnalytics: () {},
            onStepCommitted: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(WhisperCard.card), findsNothing);

    // The edge lands with the next fold, as it does live.
    backend.setWhispers(const [toMe]);
    await transport.resync();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(WhisperCard.card), findsOneWidget);
    expect(find.text(arStrings.whisperFromTitle('C')), findsOneWidget);
    expect(find.text('صوّت على D'), findsOneWidget);

    await tester.tap(find.byKey(WhisperCard.dismiss));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(WhisperCard.card), findsNothing);
    expect(find.text('صوّت على D'), findsNothing);
    // Shown once: a later fold does not bring it back.
    await transport.resync();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(WhisperCard.card), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
