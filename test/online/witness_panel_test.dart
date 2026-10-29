import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/transport/online_backend.dart' show Prediction;
import 'package:mafia_master/transport/witness_channel.dart';
import 'package:mafia_master/ui/screens/online/witness/own_record.dart';
import 'package:mafia_master/ui/screens/online/witness/witness_panel.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// What a dead player has instead of nothing (doc 12 §4.1; owner 2026-09-28:
/// the dead see everything, whispers included): the open table, the
/// graveyard chat walled off from the living, and their own record with no
/// right-or-wrong marks.
class _Channel implements WitnessChannel {
  final feed = StreamController<List<GhostMessage>>.broadcast();
  final said = <String>[];
  final reported = <String>[];
  bool failSay = false;
  bool reportOk = true;

  @override
  Stream<List<GhostMessage>> messages() => feed.stream;

  @override
  Future<void> say(String body) async {
    if (failSay) throw StateError('offline');
    said.add(body);
  }

  @override
  Future<bool> reportWhisper(String whisperId) async {
    reported.add(whisperId);
    return reportOk;
  }

  @override
  Future<Prediction?> myPrediction() async => null;

  @override
  Future<bool> predict(Prediction prediction) async => false;

  @override
  Future<WitnessTable?> table() async => null;

  @override
  Future<void> dispose() => feed.close();
}

class _Record extends OwnRecord {
  final List<RecordEntry> entries;
  _Record(this.entries);

  @override
  List<RecordEntry> build() => entries;
}

void main() {
  late GameSnapshot snapshot;

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

  final table = WitnessTable.fromJson({
    'roles': [
      {'seat': 0, 'role': 'citizen'},
      {'seat': 1, 'role': 'mafia'},
      {'seat': 2, 'role': 'doctor'},
      {'seat': 3, 'role': 'detective'},
      {'seat': 4, 'role': 'citizen'},
    ],
    'actions': [
      {'night': 1, 'seat': 1, 'action': 'kill', 'targetSeat': 0},
      {'night': 1, 'seat': 2, 'action': 'protect', 'targetSeat': 3},
      {'night': 2, 'seat': 3, 'action': 'investigate', 'targetSeat': 1},
    ],
    'whispers': [
      {
        'id': 'w1',
        'day': 1,
        'fromSeat': 1,
        'toSeat': 4,
        'text': 'خلّيك معايا',
        'masked': false,
      },
      {
        'id': 'w2',
        'day': 1,
        'fromSeat': 3,
        'toSeat': 2,
        'text': 'should not show',
        'masked': true,
      },
    ],
  });

  Future<_Channel> pump(
    WidgetTester tester, {
    WitnessTable? open,
    WitnessPanelTab? only,
    List<RecordEntry> record = const [],
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final channel = _Channel();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ownRecordProvider.overrideWith(() => _Record(record))],
        child: localizedApp(
          Scaffold(
            body: WitnessPanel(
              snapshot: snapshot,
              channel: channel,
              table: open,
              only: only,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return channel;
  }

  group('the open table', () {
    test('parses roles, nights and whispers, dropping what it cannot read', () {
      final parsed = WitnessTable.fromJson({
        'roles': [
          {'seat': 0, 'role': 'sniper'},
          {'seat': 1, 'role': 'wizard'},
          {'seat': '2', 'role': 'mafia'},
        ],
        'actions': [
          {'night': 1, 'seat': 0, 'action': 'suspect', 'targetSeat': 3},
          {'night': 1, 'seat': 0, 'action': 'kill'},
        ],
      });
      expect(parsed.roles, {0: Role.sniper});
      expect(parsed.actions.single.action, 'suspect');
      expect(parsed.whispers, isEmpty);
      expect(WitnessTable.fromJson(const {}).roles, isEmpty);
    });

    testWidgets('waits for the table before showing anything', (tester) async {
      await pump(tester, only: WitnessPanelTab.table);
      expect(find.text(arStrings.witnessTableLoading), findsOneWidget);
    });

    testWidgets('every seat, every night newest first, every whisper', (
      tester,
    ) async {
      await pump(tester, open: table, only: WitnessPanelTab.table);
      for (final name in ['A', 'B', 'C', 'D', 'E']) {
        expect(find.text(name), findsWidgets);
      }
      final night2 = tester.getTopLeft(find.text(arStrings.nightNumbered(2)));
      final night1 = tester.getTopLeft(find.text(arStrings.nightNumbered(1)));
      expect(night2.dy, lessThan(night1.dy));
      expect(find.text(arStrings.witnessActionKill('B', 'A')), findsOneWidget);
      expect(
        find.text(arStrings.witnessActionProtect('C', 'D')),
        findsOneWidget,
      );
      expect(
        find.text(arStrings.witnessActionInvestigate('D', 'B')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(WitnessPanel.whisper('w2')),
        200,
      );
      expect(find.text('خلّيك معايا'), findsOneWidget);
      expect(find.text(arStrings.witnessWhisperMasked), findsOneWidget);
      expect(find.text('should not show'), findsNothing);
    });

    testWidgets('a quiet first night says so', (tester) async {
      await pump(
        tester,
        open: const WitnessTable(roles: {}, actions: []),
        only: WitnessPanelTab.table,
      );
      expect(find.text(arStrings.witnessTableNoActions), findsOneWidget);
    });

    testWidgets('a whisper is reported once; a failed report can be retried', (
      tester,
    ) async {
      final channel = await pump(
        tester,
        open: table,
        only: WitnessPanelTab.table,
      );
      final flag = find.descendant(
        of: find.byKey(WitnessPanel.whisper('w1')),
        matching: find.byIcon(Icons.flag_outlined),
      );
      await tester.scrollUntilVisible(flag, 200);
      channel.reportOk = false;
      await tester.tap(flag);
      await tester.pumpAndSettle();
      expect(flag, findsOneWidget);
      channel.reportOk = true;
      await tester.tap(flag);
      await tester.pumpAndSettle();
      expect(flag, findsNothing);
      expect(channel.reported, ['w1', 'w1']);
    });
  });

  group('the graveyard', () {
    testWidgets('empty, then each message with its author', (tester) async {
      final channel = await pump(tester, only: WitnessPanelTab.chat);
      expect(find.text(arStrings.witnessChatWalled), findsOneWidget);
      expect(find.text(arStrings.witnessChatEmpty), findsOneWidget);
      channel.feed.add([
        GhostMessage(
          id: 'm1',
          seat: 2,
          authorName: 'C',
          body: 'أنا قلت كده',
          at: DateTime.utc(2026),
          mine: false,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text(arStrings.witnessChatEmpty), findsNothing);
      expect(find.textContaining('أنا قلت كده', findRichText: true), findsOne);
    });

    testWidgets('sends the trimmed words and clears; blank sends nothing', (
      tester,
    ) async {
      final channel = await pump(tester, only: WitnessPanelTab.chat);
      await tester.enterText(find.byKey(WitnessPanel.chatField), '   ');
      await tester.tap(find.byKey(WitnessPanel.chatSend));
      await tester.pumpAndSettle();
      expect(channel.said, isEmpty);

      await tester.enterText(
        find.byKey(WitnessPanel.chatField),
        '  هو المافيا ',
      );
      await tester.tap(find.byKey(WitnessPanel.chatSend));
      await tester.pumpAndSettle();
      expect(channel.said, ['هو المافيا']);
      expect(
        tester
            .widget<TextField>(find.byKey(WitnessPanel.chatField))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('a message that did not send stays in the field', (
      tester,
    ) async {
      final channel = await pump(tester, only: WitnessPanelTab.chat);
      channel.failSay = true;
      await tester.enterText(find.byKey(WitnessPanel.chatField), 'تاني');
      await tester.tap(find.byKey(WitnessPanel.chatSend));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(WitnessPanel.chatField))
            .controller!
            .text,
        'تاني',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the record', () {
    testWidgets('empty says so', (tester) async {
      await pump(tester, only: WitnessPanelTab.record);
      expect(find.text(arStrings.witnessRecordEmpty), findsOneWidget);
    });

    testWidgets('each day: who they named and whispered to, no marks', (
      tester,
    ) async {
      await pump(
        tester,
        only: WitnessPanelTab.record,
        record: const [
          RecordEntry(day: 1, accused: 1, whisperedTo: 3),
          RecordEntry(day: 2, accused: 4),
        ],
      );
      expect(find.text(arStrings.dayNumbered(1)), findsOneWidget);
      expect(
        find.text(
          '${arStrings.openingRoundTitle}: B  ·  ${arStrings.whisperLabel}: D',
        ),
        findsOneWidget,
      );
      expect(find.text('${arStrings.openingRoundTitle}: E'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });

  testWidgets('all three pages behind tabs fit the table band', (tester) async {
    await pump(tester, open: table);
    expect(find.byKey(WitnessPanel.tabs), findsOneWidget);
    for (final tab in [
      arStrings.witnessTabChat,
      arStrings.witnessTabRecord,
      arStrings.witnessTabTable,
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  test('record entries merge one day and ignore a repeat', () {
    const a = RecordEntry(day: 1, accused: 2);
    const b = RecordEntry(day: 1, whisperedTo: 3);
    expect(a.merge(b), const RecordEntry(day: 1, accused: 2, whisperedTo: 3));
    expect(a.merge(a), a);
    expect(const RecordEntry(day: 1).isEmpty, isTrue);
  });
}
