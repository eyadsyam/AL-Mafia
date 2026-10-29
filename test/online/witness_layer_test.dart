import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart' show Prediction;
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/transport/witness_channel.dart';
import 'package:mafia_master/ui/screens/online/witness/witness_layer.dart';
import 'package:mafia_master/ui/screens/online/witness/witness_panel.dart';

import '../support/artwork.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';

/// What the dead see on the table itself (owner, 2026-09-28: the dead stay on
/// the play screen, with popups): news of each new choice and whisper, a mark
/// on every seat a choice or an unopened letter reached tonight, the letter
/// itself, a seat's dossier, and the dock to the chat and the record.
class _Channel implements WitnessChannel {
  final reported = <String>[];
  bool ok = true;

  @override
  Future<bool> reportWhisper(String whisperId) async {
    reported.add(whisperId);
    return ok;
  }

  @override
  Stream<List<GhostMessage>> messages() => const Stream.empty();
  @override
  Future<void> say(String body) async {}
  @override
  Future<Prediction?> myPrediction() async => null;
  @override
  Future<bool> predict(Prediction prediction) async => false;
  @override
  Future<WitnessTable?> table() async => null;
  @override
  Future<void> dispose() async {}
}

void main() {
  late GameSnapshot snapshot;
  const names = {0: 'A', 1: 'B', 2: 'C', 3: 'D', 4: 'E'};

  setUp(() async {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'discuss', phaseNumber: 2, hostId: 'u4'),
      players: roster(5, dead: {0}),
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    snapshot = transport.snapshot;
    await transport.dispose();
  });

  WitnessTable table({int day = 2}) => WitnessTable.fromJson({
    'roles': [
      {'seat': 1, 'role': 'mafia'},
      {'seat': 2, 'role': 'doctor'},
      {'seat': 3, 'role': 'detective'},
      {'seat': 4, 'role': 'citizen'},
    ],
    'actions': [
      {'night': day, 'seat': 1, 'action': 'kill', 'targetSeat': 4},
      {'night': day, 'seat': 2, 'action': 'protect', 'targetSeat': 3},
      {'night': day - 1, 'seat': 3, 'action': 'investigate', 'targetSeat': 1},
    ],
    'whispers': [
      {
        'id': 'w1',
        'day': day,
        'fromSeat': 1,
        'toSeat': 2,
        'text': 'متقولش لحد',
        'masked': false,
      },
    ],
  });

  group('news', () {
    test('the first table is the past, not news', () {
      expect(witnessNewsSince(null, table()), isEmpty);
    });

    test('only what is new, choices before whispers', () {
      final before = WitnessTable.fromJson({
        'actions': [
          {'night': 2, 'seat': 1, 'action': 'kill', 'targetSeat': 4},
        ],
      });
      final news = witnessNewsSince(before, table());
      expect(news.map((n) => n.id), [
        'a:2:2:protect:3',
        'a:1:3:investigate:1',
        'w:w1',
      ]);
      expect(news.last.whisper?.id, 'w1');
      expect(witnessNewsSince(table(), table()), isEmpty);
    });
  });

  group('seat marks', () {
    Map<int, Widget> marks({Set<String> opened = const {}}) => witnessSeatMarks(
      snapshot: snapshot,
      table: table(day: snapshot.dayNumber),
      opened: opened,
      onOpenLetter: (_) {},
      onOpenSeat: (_) {},
    );

    test('tonight\'s choices mark their targets; a kill is hostile', () {
      final m = marks();
      expect((m[4] as WitnessSeatMark).hostile, isTrue);
      expect((m[3] as WitnessSeatMark).hostile, isFalse);
      // Last night's choice is no mark tonight.
      expect(m.containsKey(1), isFalse);
    });

    test('an unopened letter seals its seat; opened, it does not', () {
      expect((marks()[2] as WitnessSeatMark).sealed, isTrue);
      expect(marks(opened: {'w1'}).containsKey(2), isFalse);
    });

    test('no table read yet, no marks', () {
      expect(
        witnessSeatMarks(
          snapshot: snapshot,
          table: null,
          opened: const {},
          onOpenLetter: (_) {},
          onOpenSeat: (_) {},
        ),
        isEmpty,
      );
    });
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await loadArtwork(tester);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(Scaffold(body: Center(child: child))));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('a news line says who did what to whom', (tester) async {
    final t = table();
    var taps = 0;
    await pump(
      tester,
      WitnessNewsLine(
        news: WitnessNews.action(t.actions.first),
        table: t,
        names: names,
        onTap: () => taps++,
      ),
    );
    expect(find.text(arStrings.witnessActionKill('B', 'E')), findsOneWidget);
    await tester.tap(find.byKey(WitnessNewsLine.key_));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a whisper as news names both ends, never the words', (
    tester,
  ) async {
    final t = table();
    await pump(
      tester,
      WitnessNewsLine(
        news: WitnessNews.whisper(t.whispers.single),
        table: t,
        names: names,
      ),
    );
    expect(find.text(arStrings.witnessWhisperLine('B', 'C')), findsOneWidget);
    expect(find.text('متقولش لحد'), findsNothing);
  });

  testWidgets('the letter shows the words and can be reported once', (
    tester,
  ) async {
    final t = table();
    final channel = _Channel();
    await pump(
      tester,
      WitnessLetter(
        whisper: t.whispers.single,
        table: t,
        names: names,
        channel: channel,
      ),
    );
    expect(find.text('متقولش لحد'), findsOneWidget);
    channel.ok = false;
    await tester.tap(find.byKey(WitnessLetter.report));
    await tester.pump();
    expect(find.byKey(WitnessLetter.report), findsOneWidget);
    channel.ok = true;
    await tester.tap(find.byKey(WitnessLetter.report));
    await tester.pump();
    expect(find.byKey(WitnessLetter.report), findsNothing);
    expect(find.text(arStrings.witnessWhisperReported), findsOneWidget);
    expect(channel.reported, ['w1', 'w1']);
  });

  testWidgets('a masked letter keeps its words hidden', (tester) async {
    final t = table();
    const masked = WitnessWhisper(
      id: 'w9',
      day: 2,
      fromSeat: 3,
      toSeat: 4,
      text: null,
      masked: true,
    );
    await pump(tester, WitnessLetter(whisper: masked, table: t, names: names));
    expect(find.text(arStrings.witnessWhisperMasked), findsOneWidget);
  });

  testWidgets('a seat\'s dossier: its card, tonight\'s choices, its letters', (
    tester,
  ) async {
    final t = table(day: snapshot.dayNumber);
    final opened = <String>[];
    var managed = 0;
    await pump(
      tester,
      WitnessDossier(
        seat: 2,
        snapshot: snapshot,
        table: t,
        onOpenLetter: (w) => opened.add(w.id),
        onManage: () => managed++,
      ),
    );
    expect(find.text('C'), findsOneWidget);
    expect(find.text(arStrings.witnessActionProtect('C', 'D')), findsOneWidget);
    await tester.tap(find.byKey(WitnessPanel.whisper('w1')));
    expect(opened, ['w1']);
    await tester.tap(find.text(arStrings.witnessManageSeat));
    expect(managed, 1);
  });

  testWidgets('a quiet seat says so', (tester) async {
    await pump(
      tester,
      WitnessDossier(
        seat: 0,
        snapshot: snapshot,
        table: table(day: snapshot.dayNumber),
        onOpenLetter: (_) {},
      ),
    );
    expect(find.text(arStrings.witnessSeatQuiet), findsOneWidget);
    expect(find.text(arStrings.witnessManageSeat), findsNothing);
  });

  testWidgets('the dock opens the chat and the record', (tester) async {
    final opened = <String>[];
    await pump(
      tester,
      WitnessDock(
        onChat: () => opened.add('chat'),
        onRecord: () => opened.add('record'),
        unread: 2,
      ),
    );
    await tester.tap(find.byKey(WitnessDock.chat));
    await tester.tap(find.byKey(WitnessDock.record));
    expect(opened, ['chat', 'record']);
    expect(find.byIcon(Icons.mark_chat_unread_outlined), findsOneWidget);
  });

  testWidgets('a popup closes from its scrim', (tester) async {
    var closed = 0;
    await pump(
      tester,
      SizedBox.expand(
        child: Stack(
          children: [
            WitnessPopup(
              onDismiss: () => closed++,
              child: const Text('inside'),
            ),
          ],
        ),
      ),
    );
    expect(find.text('inside'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    expect(closed, 1);
  });
}
