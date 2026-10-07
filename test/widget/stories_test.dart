import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/stories/story_progress.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/stories/story_flow_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';

import '../support/localized.dart';

void main() {
  late StoryDefinition cafe;
  late StoryDefinition lockedRoom;

  setUpAll(() {
    cafe = StoryDefinition.decode(
      File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
    );
    lockedRoom = StoryDefinition.decode(
      File('assets/stories/el_oda_el_mafoola.json').readAsStringSync(),
    );
  });

  testWidgets('hub shows scores and enforces near-impossible lock', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        StoriesHub(
          stories: [cafe, lockedRoom],
          progress: const StoryProgress(
            bestScores: {'qahwet_el_moallem': 1200},
          ),
          onBack: () {},
          onStart: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(StoriesHub.hubKey), findsOneWidget);
    expect(find.byKey(StoriesHub.storyKey(cafe.id)), findsOneWidget);
    expect(find.byKey(StoriesHub.startKey(cafe.id)), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(StoriesHub.storyKey(lockedRoom.id)),
      StoryTokens.coverHeight,
    );
    expect(find.byKey(StoriesHub.startKey(lockedRoom.id)), findsNothing);
  });

  testWidgets('complete solo investigation reaches score through reenactment', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        StoryFlowScreen(
          story: cafe,
          playerCount: 1,
          onExit: () {},
          onComplete: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(StoryFlowScreen.soloBoardKey), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(StoryFlowScreen.accusationButtonKey),
      StoryTokens.coverHeight,
    );
    await tester.tap(find.byKey(StoryFlowScreen.accusationButtonKey));
    await tester.pumpAndSettle();
    await _pick(tester, 0, cafe.character(cafe.truth.primaryCulprit).name);
    await _pick(
      tester,
      1,
      cafe.motives.firstWhere((value) => value.id == cafe.truth.motive).label,
    );
    await _pick(
      tester,
      2,
      cafe.methods.firstWhere((value) => value.id == cafe.truth.method).label,
    );
    await tester.tap(find.text(arStrings.storiesConfirmAccusation));
    await tester.pumpAndSettle();

    expect(find.byKey(StoryFlowScreen.reenactmentKey), findsOneWidget);
    for (var i = 0; i < cafe.truth.timeline.length; i++) {
      final label = i == cafe.truth.timeline.length - 1
          ? arStrings.storiesFinishReveal
          : arStrings.storiesNextBeat;
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(StoryFlowScreen.resultKey), findsOneWidget);
    expect(find.text(arStrings.storiesSolved), findsOneWidget);
  });

  testWidgets(
    'group hand-off requires hold, reveals, then covers for next seat',
    (tester) async {
      await tester.pumpWidget(
        localizedApp(
          StoryFlowScreen(
            story: cafe,
            playerCount: 2,
            onExit: () {},
            onComplete: (_) async {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(StoryFlowScreen.handoffKey), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldPad)),
      );
      await tester.pump(StoryTokens.privateHold);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(StoryFlowScreen.privateCardKey), findsOneWidget);

      await tester.ensureVisible(find.text(arStrings.storiesCoverAndPass));
      await tester.tap(find.text(arStrings.storiesCoverAndPass));
      await tester.pumpAndSettle();
      expect(find.byKey(StoryFlowScreen.handoffKey), findsOneWidget);
      expect(find.text('${arStrings.storiesPlayer} 2'), findsOneWidget);
    },
  );

  testWidgets('360x640 hub and picker remain reachable with keyboard inset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);

    var picked = 0;
    await tester.pumpWidget(
      localizedApp(
        StoriesHub(
          stories: [cafe],
          progress: const StoryProgress(),
          onBack: () {},
          onStart: (_, count) => picked = count,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(StoriesHub.startKey(cafe.id)));
    await tester.pumpAndSettle();
    final ten = find.byKey(const ValueKey('story_players_10'));
    await tester.scrollUntilVisible(
      ten,
      StoryTokens.coverHeight,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(ten);
    await tester.pumpAndSettle();
    expect(picked, 10);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pick(WidgetTester tester, int index, String label) async {
  final dropdowns = find.byType(DropdownButtonFormField<String>);
  await tester.tap(dropdowns.at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
