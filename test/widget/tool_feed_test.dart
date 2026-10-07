import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';
import 'package:mafia_master/ui/screens/online/table/tool_feed.dart';

import '../support/localized.dart';

GameSnapshot _snap(GamePhase phase, List<ToolLogEntry> log) => GameSnapshot(
  public: PublicMatchView(
    phase: phase,
    dayNumber: 1,
    players: [
      for (var seat = 0; seat < 6; seat++)
        PublicPlayer(seat: seat, name: ['إياد', 'كريم', 'سارة', 'منى', 'علي', 'هبة'][seat], status: PlayerStatus.alive),
    ],
  ),
  viewerSeat: 0,
  toolLog: log,
);

void main() {
  group('ToolLogEntry parsing', () {
    test('good entry', () {
      final list = ToolLogEntry.parseList([
        {'tool': 'spotlight', 'seat': 1, 'targets': [2, 3], 'note': null, 'phaseNumber': 2},
      ]);
      expect(list, hasLength(1));
      expect(list.first.tool, 'spotlight');
      expect(list.first.seat, 1);
      expect(list.first.targets, [2, 3]);
      expect(list.first.note, isNull);
      expect(list.first.phaseNumber, 2);
    });

    test('secret entry has a null seat', () {
      final e = ToolLogEntry.tryParse({'tool': 'peek', 'seat': null, 'targets': []})!;
      expect(e.seat, isNull);
      expect(e.targets, isEmpty);
    });

    test('malformed entries are skipped, not thrown', () {
      final list = ToolLogEntry.parseList([
        'x',
        42,
        null,
        {'seat': 1},
        {'tool': ''},
        {'tool': 7},
        {'tool': 'anon_note', 'note': 'hi', 'targets': ['a', 1, null]},
      ]);
      expect(list, hasLength(1));
      expect(list.first.targets, [1]);
      expect(ToolLogEntry.parseList('nope'), isEmpty);
      expect(ToolLogEntry.parseList(null), isEmpty);
    });

    test('default snapshot has an empty log', () {
      expect(_snap(GamePhase.discussion, const []).toolLog, isEmpty);
    });
  });

  group('ToolFeed', () {
    Future<void> pump(WidgetTester tester, GameSnapshot s) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(Scaffold(body: TableScene(snapshot: s))),
        ),
      );
      await tester.pump();
    }

    final log = [
      const ToolLogEntry(tool: 'extra_minute', seat: 0, phaseNumber: 1),
      const ToolLogEntry(tool: 'spotlight', seat: 1, targets: [2]),
      const ToolLogEntry(tool: 'anon_note', note: 'فيه حد كداب'),
      const ToolLogEntry(tool: 'last_will', seat: 3, note: 'سامحوني'),
      const ToolLogEntry(tool: 'objection', seat: null),
    ];

    testWidgets('renders max 3 newest-first in Arabic without overflow', (tester) async {
      await pump(tester, _snap(GamePhase.discussion, log));
      expect(tester.takeException(), isNull);
      expect(find.byKey(ToolFeed.surface), findsOneWidget);
      expect(find.text('حد استخدم أداة سرّية'), findsOneWidget);
      expect(find.text('وصيّة: سامحوني'), findsOneWidget);
      expect(find.text('ورقة من غير اسم: فيه حد كداب'), findsOneWidget);
      expect(find.textContaining('إياد استخدم'), findsNothing);
    });

    testWidgets('names the user and the targets', (tester) async {
      await pump(tester, _snap(GamePhase.voting, [log[1]]));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('كريم استخدم:'), findsOneWidget);
      expect(find.textContaining('على: سارة'), findsOneWidget);
    });

    testWidgets('absent at night', (tester) async {
      for (final phase in [
        GamePhase.night,
        GamePhase.nightResolving,
        GamePhase.preNightLobby,
      ]) {
        await pump(tester, _snap(phase, log));
        expect(find.byKey(ToolFeed.surface), findsNothing, reason: '$phase');
        expect(find.textContaining('حد استخدم'), findsNothing);
      }
    });

    testWidgets('a new entry raises a snackbar', (tester) async {
      await pump(tester, _snap(GamePhase.discussion, [log[0]]));
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            Scaffold(
              body: TableScene(snapshot: _snap(GamePhase.discussion, [log[0], log[1]])),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
