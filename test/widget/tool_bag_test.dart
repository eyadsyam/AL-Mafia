import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/all_access.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// The tool bag inside an online match (owner, 2026-10-29): every tool held,
/// its art, the ones that fit this moment first, the rest dimmed with when
/// they open, and no count on an owner grant.
void main() {
  Map<String, Object?> tool(String code, String phase, int charges) => {
    'code': code,
    'tier': 'light',
    'packs': {'1': 40},
    'charges': charges,
    'perMatch': 1,
    'phase': phase,
    'targets': 0,
  };

  Future<void> open(
    WidgetTester tester, {
    required String phase,
    bool unlimited = false,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: phase),
      players: roster(5),
    );
    backend.responders['economy'] = (_) => {
      'balance': 0,
      'tools': [
        tool('spotlight', 'discuss', 2),
        tool('sense', 'night', 1),
        tool('appeal', 'vote', 1),
      ],
    };
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          allAccessProvider.overrideWithValue(unlimited),
        ],
        child: localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTableToolsSheet(
                  context,
                  roomId: 'room',
                  phase: phase,
                  alive: true,
                  freeTalk: false,
                  seats: const {1: 'P1'},
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

  bool now(WidgetTester tester, String code) =>
      tester
          .widget<ToolBagTile>(
            find.ancestor(
              of: find.byKey(ToolBagTile.keyFor(code)),
              matching: find.byType(ToolBagTile),
            ),
          )
          .now;

  testWidgets('by day: the talk tools now, the night tool later', (
    tester,
  ) async {
    await open(tester, phase: 'discuss');
    expect(now(tester, 'spotlight'), isTrue);
    expect(now(tester, 'appeal'), isTrue);
    expect(now(tester, 'sense'), isFalse);
    expect(find.text(arStrings.toolBagLater), findsOneWidget);
    expect(find.text(arStrings.vaultToolPhaseNight), findsOneWidget);
    expect(find.text(arStrings.vaultToolLeft(2)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at night only the night tool opens', (tester) async {
    await open(tester, phase: 'night');
    expect(now(tester, 'sense'), isTrue);
    expect(now(tester, 'spotlight'), isFalse);
    // A dimmed tool cannot be picked.
    await tester.tap(find.byKey(ToolBagTile.keyFor('spotlight')));
    await tester.pump();
    expect(find.text(arStrings.toolUse), findsNothing);
  });

  testWidgets('an owner grant shows no count', (tester) async {
    await open(tester, phase: 'discuss', unlimited: true);
    expect(find.text(arStrings.vaultToolLeft(2)), findsNothing);
    expect(find.text(arStrings.vaultToolsUnlimited), findsWidgets);
  });
}
