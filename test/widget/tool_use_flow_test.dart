import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/all_access.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Using a bought tool inside an online match, end to end against a fake
/// server: pick it, give it exactly what it needs (seats, a note, a face),
/// spend it once, read the narrator's private answer, and hear every refusal
/// in words.
void main() {
  Map<String, Object?> tool(
    String code,
    String phase, {
    int targets = 0,
    int charges = 1,
  }) => {
    'code': code,
    'tier': 'medium',
    'packs': {'1': 40},
    'charges': charges,
    'perMatch': 1,
    'phase': phase,
    'targets': targets,
  };

  late FakeBackend backend;
  late List<Map<String, dynamic>> uses;

  Future<void> open(
    WidgetTester tester, {
    required String phase,
    required List<Map<String, Object?>> tools,
    bool alive = true,
    Object? Function(Map<String, dynamic> body)? onUse,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    uses = [];
    backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: phase),
      players: roster(5),
    );
    backend.responders['economy'] = (body) {
      if (body['action'] == 'toolUse') {
        uses.add(body);
        final answer = onUse?.call(body);
        if (answer is BackendException) throw answer;
        return {'ok': true, 'answer': ?answer};
      }
      return {'balance': 0, 'tools': tools};
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          allAccessProvider.overrideWithValue(false),
        ],
        child: localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTableToolsSheet(
                  context,
                  roomId: 'room',
                  phase: phase,
                  alive: alive,
                  freeTalk: false,
                  seats: const {1: 'B', 2: 'C', 3: 'D'},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  FilledButton useButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.text(arStrings.toolUse),
      matching: find.byType(FilledButton),
    ),
  );

  Future<void> pick(WidgetTester tester, String code) async {
    await tester.tap(find.byKey(ToolBagTile.keyFor(code)));
    await tester.pumpAndSettle();
  }

  Future<void> tapUse(WidgetTester tester) async {
    await tester.ensureVisible(find.text(arStrings.toolUse));
    await tester.tap(find.text(arStrings.toolUse));
    await tester.pumpAndSettle();
  }

  testWidgets('a two-seat tool: exactly two seats, then one spend', (
    tester,
  ) async {
    await open(
      tester,
      phase: 'night',
      tools: [tool('sense', 'night', targets: 2)],
      onUse: (_) => true,
    );
    await pick(tester, 'sense');
    expect(find.text(arStrings.toolPickTargets(2)), findsOneWidget);
    expect(useButton(tester).onPressed, isNull);

    for (final name in ['D', 'B', 'C']) {
      await tester.tap(find.widgetWithText(FilterChip, name));
      await tester.pump();
    }
    // A third seat is ignored: the tool takes two.
    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'C')).selected,
      isFalse,
    );
    await tapUse(tester);
    expect(uses.single['tool'], 'sense');
    expect(uses.single['targets'], [1, 3]);
    expect(find.text(arStrings.toolAnswerYes), findsOneWidget);
    await tester.tap(find.text(arStrings.toolAnswerOk));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.toolUse), findsNothing, reason: 'sheet closed');
  });

  testWidgets('the answer can be no', (tester) async {
    await open(
      tester,
      phase: 'night',
      tools: [tool('sense', 'night', targets: 1)],
      onUse: (_) => false,
    );
    await pick(tester, 'sense');
    await tester.tap(find.widgetWithText(FilterChip, 'B'));
    await tester.pump();
    await tapUse(tester);
    expect(find.text(arStrings.toolAnswerNo), findsOneWidget);
  });

  testWidgets('a note tool waits for words and sends them trimmed', (
    tester,
  ) async {
    await open(tester, phase: 'discuss', tools: [tool('anon_note', 'discuss')]);
    await pick(tester, 'anon_note');
    expect(useButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(useButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  واحد فيكم كذاب ');
    await tester.pump();
    await tapUse(tester);
    expect(uses.single['note'], 'واحد فيكم كذاب');
    expect(find.text(arStrings.toolUse), findsNothing);
  });

  testWidgets('impersonate waits for a face and sends it', (tester) async {
    await open(
      tester,
      phase: 'discuss',
      tools: [tool('impersonate', 'discuss')],
    );
    await pick(tester, 'impersonate');
    expect(useButton(tester).onPressed, isNull);
    await tester.tap(find.text(arStrings.toolImpersonateMafia));
    await tester.pump();
    await tapUse(tester);
    expect(uses.single['note'], 'mafia');
  });

  for (final (code, words) in [
    ('LIMIT_PHASE', arStrings.toolLimitPhase),
    ('NO_CHARGES', arStrings.toolNoCharges),
    ('SILENCED', arStrings.toolSilencedToday),
    ('WRONG_PHASE', arStrings.toolWrongPhase),
    ('SOMETHING_NEW', arStrings.toolRefused),
  ]) {
    testWidgets('a refusal $code is said, and the sheet stays usable', (
      tester,
    ) async {
      await open(
        tester,
        phase: 'discuss',
        tools: [tool('spotlight', 'discuss')],
        onUse: (_) => BackendException(code, 'no'),
      );
      await pick(tester, 'spotlight');
      await tapUse(tester);
      expect(find.text(words), findsOneWidget);
      expect(useButton(tester).onPressed, isNotNull, reason: 'not left busy');
    });
  }

  testWidgets('the dead hold only their own tool', (tester) async {
    await open(
      tester,
      phase: 'discuss',
      alive: false,
      tools: [tool('last_will', 'dead'), tool('spotlight', 'discuss')],
    );
    bool now(String code) => tester
        .widget<ToolBagTile>(
          find.ancestor(
            of: find.byKey(ToolBagTile.keyFor(code)),
            matching: find.byType(ToolBagTile),
          ),
        )
        .now;
    expect(now('last_will'), isTrue);
    expect(now('spotlight'), isFalse);
  });

  testWidgets('nothing held says so', (tester) async {
    await open(tester, phase: 'discuss', tools: const []);
    expect(find.text(arStrings.toolNoneOwned), findsOneWidget);
  });

  test('every tier reads from the server; an unknown one is dropped', () {
    for (final tier in ['light', 'medium', 'heavy']) {
      expect(
        TableTool.fromJson({...tool('x', 'discuss'), 'tier': tier})?.tier.name,
        tier,
      );
    }
    expect(
      TableTool.fromJson({...tool('x', 'discuss'), 'tier': 'epic'}),
      isNull,
    );
  });
}
