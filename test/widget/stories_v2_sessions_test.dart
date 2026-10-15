import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/story_catalog.dart';
import 'package:mafia_master/data/story_progress_store.dart';
import 'package:mafia_master/data/story_v2_memory.dart';
import 'package:mafia_master/data/story_world_catalog.dart';
import 'package:mafia_master/platform/narration_controller.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/stories/v2/session.dart';
import 'package:mafia_master/stories/v2/table.dart';
import 'package:mafia_master/stories/v2/world.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/stories/story_rewards.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_lobby_screen.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_table_screen.dart';

import '../support/localized.dart';

final _world = StoryWorld.decode(
  File('assets/stories_v2/qahwet_el_moallem.json').readAsStringSync(),
);
final _cafe = StoryDefinition.decode(
  File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
);

class _OneStory extends StoryCatalog {
  const _OneStory();

  @override
  Future<List<StoryDefinition>> load() async => [_cafe];
}

/// The world from memory: rootBundle caches its futures in the first test's
/// fake-async zone, where a later test would wait on them forever.
class _Worlds extends StoryWorldCatalog {
  const _Worlds();

  @override
  Future<Map<String, StoryWorld>> load() async => {_world.id: _world};
}

class _Silent implements NarrationPlayer {
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<Duration> get durations => const Stream.empty();
  @override
  Stream<void> get completions => const Stream.empty();
  @override
  Future<void> start(String assetKey) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> seek(Duration to) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Claim {
  _Claim(this.session, this.accusation);
  final String session;
  final StoryAccusationV2 accusation;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  if (find.byKey(key).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Opens the pilot from the hub and walks solo's how-to; the last tap deals.
Future<void> _toSoloDeal(
  WidgetTester tester, {
  required Future<StoryServerDeal?> Function(String, int, Set<String>) start,
  required List<_Claim> claims,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    localizedApp(
      StoriesScreen(
        onBack: () {},
        catalog: const _OneStory(),
        worldCatalog: const _Worlds(),
        progressStore: MemoryStoryProgressStore(),
        v2Memory: MemoryStoryV2Memory(about: true),
        culpritHistory: MemoryStoryCulpritHistory(),
        narrationFactory: () => NarrationController(_Silent(), web: false),
        newSeed: () => 7,
        startV2Session: start,
        claimV2Reward: (session, accusation) async {
          claims.add(_Claim(session, accusation));
          return 60;
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, StoriesHub.startKey(_cafe.id));
  await _tap(tester, StoryLobbyScreen.soloKey);
  await _tap(tester, StoryLobbyScreen.nextKey);
  await _tap(tester, StoryLobbyScreen.nextKey);
  await tester.tap(find.byKey(StoryLobbyScreen.nextKey));
  await tester.pump();
}

Future<void> _solve(WidgetTester tester, String culprit) async {
  final guilt = _world.suspect(culprit).guilty;
  await _tap(tester, StoryTableScreen.decideKey);
  await _tap(tester, StoryTableScreen.pickKey(culprit));
  await _tap(tester, StoryTableScreen.motiveKey(guilt.motive.id));
  await _tap(tester, StoryTableScreen.methodKey(guilt.method.id));
  await _tap(tester, StoryTableScreen.confirmKey);
  await _tap(tester, StoryTableScreen.resultKey);
}

StoryTable _shown(WidgetTester tester) =>
    tester.widget<StoryTableScreen>(find.byType(StoryTableScreen)).table;

void main() {
  testWidgets('the server picks who did it, and a right answer is paid', (
    tester,
  ) async {
    final claims = <_Claim>[];
    int? asked;
    await _toSoloDeal(
      tester,
      claims: claims,
      start: (story, players, avoid) async {
        asked = players;
        expect(story, _world.id);
        return const StoryServerDeal(
          sessionId: 'session-1',
          pick: StoryCulpritPick(culpritId: 'n05'),
        );
      },
    );
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(_shown(tester).culpritId, 'n05');
    expect(_shown(tester).suspectIds, contains('n05'));

    await _solve(tester, 'n05');
    expect(find.text(arStrings.sv2SoloWon), findsOneWidget);
    expect(claims, hasLength(1));
    expect(claims.single.session, 'session-1');
    expect(claims.single.accusation.suspectId, 'n05');
    expect(
      claims.single.accusation.motiveId,
      _world.suspect('n05').guilty.motive.id,
    );
    expect(find.text(arStrings.storyRewardGranted(60)), findsOneWidget);
  });

  testWidgets('a slow server never holds the table: it deals on the phone', (
    tester,
  ) async {
    final claims = <_Claim>[];
    final never = Completer<StoryServerDeal?>();
    await _toSoloDeal(tester, claims: claims, start: (_, _, _) => never.future);
    // While it waits, the button says so and cannot be pressed twice.
    expect(find.text(arStrings.sv2Dealing), findsOneWidget);
    expect(find.byType(StoryTableScreen), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(StoryTableScreen), findsOneWidget);

    await _solve(tester, _shown(tester).culpritId);
    expect(find.text(arStrings.sv2SoloWon), findsOneWidget);
    expect(claims, isEmpty, reason: 'no session, no coins');
  });

  testWidgets('a pick this build cannot play deals on the phone, unpaid', (
    tester,
  ) async {
    final claims = <_Claim>[];
    await _toSoloDeal(
      tester,
      claims: claims,
      start: (_, _, _) async => const StoryServerDeal(
        sessionId: 'session-2',
        pick: StoryCulpritPick(culpritId: 'n99'),
      ),
    );
    await tester.pumpAndSettle();
    final table = _shown(tester);
    expect(_world.suspects.map((s) => s.id), contains(table.culpritId));
    await _solve(tester, table.culpritId);
    expect(claims, isEmpty);
  });

  testWidgets('solo with the right who but a wrong why is close, not solved', (
    tester,
  ) async {
    final claims = <_Claim>[];
    await _toSoloDeal(
      tester,
      claims: claims,
      start: (_, _, _) async => const StoryServerDeal(
        sessionId: 'session-3',
        pick: StoryCulpritPick(culpritId: 'n03'),
      ),
    );
    await tester.pumpAndSettle();
    final other = _world.suspects.firstWhere(
      (s) => s.id != 'n03' && _shown(tester).suspectIds.contains(s.id),
    );
    await _tap(tester, StoryTableScreen.decideKey);
    await _tap(tester, StoryTableScreen.pickKey('n03'));
    await _tap(tester, StoryTableScreen.motiveKey(other.guilty.motive.id));
    await _tap(
      tester,
      StoryTableScreen.methodKey(_world.suspect('n03').guilty.method.id),
    );
    await _tap(tester, StoryTableScreen.confirmKey);
    await _tap(tester, StoryTableScreen.resultKey);
    expect(find.text(arStrings.sv2SoloClose), findsOneWidget);
    expect(claims, isEmpty);
  });
}
