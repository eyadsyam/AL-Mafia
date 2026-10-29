import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/stories/story_progress.dart';
import 'package:mafia_master/stories/story_session.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/stories/story_case_widgets.dart';
import 'package:mafia_master/ui/screens/stories/story_flow_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';

import '../support/localized.dart';

const _small = Size(360, 640);
const _large = Size(430, 932);

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

  void size(WidgetTester tester, Size s) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = s;
    addTearDown(tester.view.reset);
  }

  Widget flow(
    StoryDefinition story,
    int players, {
    void Function(StoryCompletion)? done,
    bool still = false,
  }) {
    final screen = StoryFlowScreen(
      story: story,
      playerCount: players,
      onExit: () {},
      onComplete: (c) async => done?.call(c),
    );
    return localizedApp(
      still
          ? Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: screen,
              ),
            )
          : screen,
    );
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> holdPad(WidgetTester tester) async {
    final g = await tester.startGesture(tester.getCenter(find.byType(HoldPad)));
    await tester.pump(StoryTokens.privateHold);
    await g.up();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('the hub lists the easiest first and the locked ones last', (
    tester,
  ) async {
    size(tester, _large);
    await tester.pumpWidget(
      localizedApp(
        StoriesHub(
          stories: [lockedRoom, cafe],
          progress: const StoryProgress(),
          onBack: () {},
          onStart: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cafeTop = tester.getTopLeft(find.byKey(StoriesHub.storyKey(cafe.id)));
    final lockedTop = tester.getTopLeft(
      find.byKey(StoriesHub.storyKey(lockedRoom.id)),
    );
    expect(cafeTop.dy, lessThan(lockedTop.dy));
  });

  for (final s in [_small, _large]) {
    group('${s.width.toInt()}x${s.height.toInt()}', () {
      testWidgets('archive: stamps, wax seal, category filter', (tester) async {
        size(tester, s);
        await tester.pumpWidget(
          localizedApp(
            StoriesHub(
              stories: [cafe, lockedRoom],
              progress: StoryProgress(
                bestScores: {cafe.id: 1200},
                solvedStoryIds: {cafe.id},
              ),
              onBack: () {},
              onStart: (_, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(arStrings.sv2HubTitle), findsOneWidget);
        expect(
          find.text(arStrings.storiesStampSolvedScore(1200)),
          findsOneWidget,
        );
        expect(find.byKey(StoriesHub.startKey(cafe.id)), findsOneWidget);

        // The locked case: wax seal, how it opens, title still readable.
        await tester.scrollUntilVisible(
          find.byKey(StoriesHub.storyKey(lockedRoom.id)),
          StoryTokens.coverHeight,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(StoriesHub.startKey(lockedRoom.id)), findsNothing);
        expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
        expect(find.text(lockedRoom.title), findsOneWidget);
        expect(
          find.text(
            '${arStrings.storiesLocked} — ${arStrings.storiesUnlockRule}',
          ),
          findsOneWidget,
        );

        // Filtering by a category leaves only its cases.
        await tester.ensureVisible(
          find.byKey(StoriesHub.chipKey(lockedRoom.category)),
        );
        await tester.pump();
        await tester.tap(find.byKey(StoriesHub.chipKey(lockedRoom.category)));
        await tester.pumpAndSettle();
        expect(find.byKey(StoriesHub.storyKey(cafe.id)), findsNothing);
        expect(find.byKey(StoriesHub.storyKey(lockedRoom.id)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('investigation: moves spend, notes pin, accusation scores', (
        tester,
      ) async {
        size(tester, s);
        StoryCompletion? completion;
        await tester.pumpWidget(flow(cafe, 1, done: (c) => completion = c));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final budget = cafe.actionBudget;
        expect(
          find.text(
            '${arStrings.storiesMoves}: ${arStrings.storiesMovesOf(budget, budget)}',
          ),
          findsOneWidget,
        );
        expect(find.byType(StoryNote), findsNothing);

        final first = cafe.actions.first;
        await reveal(tester, find.text(first.title));
        await tester.tap(find.text(first.title));
        await tester.pumpAndSettle();
        final left = budget - first.cost;
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(
          find.text(
            '${arStrings.storiesMoves}: ${arStrings.storiesMovesOf(left, budget)}',
          ),
          findsOneWidget,
        );
        expect(find.byType(StoryNote), findsWidgets);
        expect(tester.takeException(), isNull);

        // Accuse wrongly first: a wrong answer does not solve.
        final wrong = cafe.characters
            .firstWhere((c) => c.id != cafe.truth.primaryCulprit)
            .id;
        await tapKey(tester, StoryFlowScreen.accusationButtonKey);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final button = find.byKey(StoryFlowScreen.closeCaseKey);
        expect(
          tester
              .widget<FilledButton>(
                find.descendant(
                  of: button,
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNull,
        );
        await tapKey(tester, StoryAccusationForm.suspectKey(wrong));
        await tapKey(tester, StoryAccusationForm.motiveKey(cafe.truth.motive));
        await tapKey(tester, StoryAccusationForm.methodKey(cafe.truth.method));
        await tester.tap(button);
        await tester.pumpAndSettle();
        for (var i = 0; i < cafe.truth.timeline.length; i++) {
          await tester.tap(
            find.text(
              i == cafe.truth.timeline.length - 1
                  ? arStrings.storiesFinishReveal
                  : arStrings.storiesNextBeat,
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(find.byKey(StoryFlowScreen.resultKey), findsOneWidget);
        expect(find.text(arStrings.storiesMissed), findsOneWidget);
        expect(find.text(arStrings.storiesStampMissed), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(arStrings.storiesBackToFiles));
        await tester.pumpAndSettle();
        // 250 + 250: motive + method right, culprit wrong; no efficiency points.
        expect(completion?.solved, isFalse);
        expect(completion?.score, 250 + 250);
      });

      testWidgets('group: the whole table, no overflow on any page', (
        tester,
      ) async {
        size(tester, s);
        StoryCompletion? completion;
        await tester.pumpWidget(flow(cafe, 3, done: (c) => completion = c));
        await tester.pump();
        expect(find.byKey(StoryFlowScreen.castKey), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapKey(tester, StoryFlowScreen.dealKey);

        for (var round = 1; round <= StoryTokens.rounds; round++) {
          for (var seat = 0; seat < 3; seat++) {
            expect(find.byKey(StoryFlowScreen.handoffKey), findsOneWidget);
            expect(
              find.text('${arStrings.storiesPlayer} ${seat + 1}'),
              findsOneWidget,
            );
            await holdPad(tester);
            expect(find.byKey(StoryFlowScreen.privateCardKey), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pump(StoryTokens.dossierHold);
            await tapKey(tester, StoryFlowScreen.hideFileKey);
          }
          expect(find.byKey(StoryFlowScreen.discussionKey), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(arStrings.storiesSearchTogether));
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.byKey(StoryFlowScreen.investigationKey), findsOneWidget);
          expect(tester.takeException(), isNull);
          final open = cafe.actions.where((a) => !_picked.contains(a.id)).first;
          _picked.add(open.id);
          await reveal(tester, find.text(open.title));
          await tester.tap(find.text(open.title));
          await tester.pump(const Duration(milliseconds: 50));
        }
        _picked.clear();

        // Secret ballot, one seat after the other.
        for (var seat = 0; seat < 3; seat++) {
          expect(find.byKey(StoryFlowScreen.handoffKey), findsOneWidget);
          await holdPad(tester);
          expect(find.byKey(StoryFlowScreen.voteKey), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tapKey(
            tester,
            StoryAccusationForm.suspectKey(cafe.truth.primaryCulprit),
          );
          await tapKey(
            tester,
            StoryAccusationForm.motiveKey(cafe.truth.motive),
          );
          await tapKey(
            tester,
            StoryAccusationForm.methodKey(cafe.truth.method),
          );
          final g = await tester.startGesture(
            tester.getCenter(find.byType(StoryHoldButton)),
          );
          await tester.pump(StoryTokens.ballotHold);
          await g.up();
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byKey(StoryFlowScreen.reenactmentKey), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (var i = 0; i < cafe.truth.timeline.length; i++) {
          await tester.tap(
            find.text(
              i == cafe.truth.timeline.length - 1
                  ? arStrings.storiesWhoKnew
                  : arStrings.storiesNextBeat,
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(find.byKey(StoryFlowScreen.resultKey), findsOneWidget);
        expect(find.text(arStrings.storiesSolved), findsOneWidget);
        expect(find.text(arStrings.storiesHidWell), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(arStrings.storiesAnotherCase));
        await tester.pumpAndSettle();
        expect(completion?.solved, isTrue);
      });
    });
  }

  testWidgets('moves dearer than what is left dim and cannot be tapped', (
    tester,
  ) async {
    size(tester, _large);
    await tester.pumpWidget(flow(cafe, 1));
    await tester.pumpAndSettle();
    // Spend until a move no longer fits: cafe's budget is 12, its moves cost
    // 2, 3, 4, 3.
    var session = StorySession.start(story: cafe, playerCount: 1, seed: 1);
    for (final a in cafe.actions) {
      if (session.canPerform(a)) {
        session = session.performSoloAction(a.id);
        await reveal(tester, find.text(a.title));
        await tester.tap(find.text(a.title));
        await tester.pumpAndSettle();
      }
    }
    final cards = tester.widgetList<StoryMoveCard>(find.byType(StoryMoveCard));
    for (final c in cards) {
      expect(
        c.done || !c.enabled || c.cost! <= session.remainingBudget,
        isTrue,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion: a pinned note is there at once', (tester) async {
    size(tester, _small);
    await tester.pumpWidget(flow(cafe, 1, still: true));
    await tester.pump();
    await reveal(tester, find.text(cafe.actions.first.title));
    await tester.tap(find.text(cafe.actions.first.title));
    await tester.pump();
    final fade = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(StoryPinned),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(fade.opacity, 1);
  });

  testWidgets('narrator bar plays and stops', (tester) async {
    var played = 0;
    var stopped = 0;
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: StoryNarratorBar(
            title: 't',
            playingText: 'p',
            idleText: 'i',
            stopTooltip: 's',
            playTooltip: 'g',
            onPlay: () => played++,
            onStop: () => stopped++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(StoryNarratorBar.playKey));
    await tester.pump();
    expect(played, 1);
    expect(find.text('p'), findsOneWidget);
    await tester.tap(find.byKey(StoryNarratorBar.playKey));
    await tester.pump();
    expect(stopped, 1);
    expect(find.text('i'), findsOneWidget);
  });

  group('the private file is the same for every seat', () {
    /// The widget types of a subtree, in order, with no text or colour.
    List<String> shape(WidgetTester tester, Key key) {
      final out = <String>[];
      void walk(Element e) {
        out.add(e.widget.runtimeType.toString());
        e.visitChildren(walk);
      }

      walk(tester.element(find.byKey(key)));
      return out;
    }

    testWidgets('culprit and innocent: same tree, same seconds', (
      tester,
    ) async {
      size(tester, _small);
      await tester.pumpWidget(flow(cafe, 2));
      await tester.pump();
      await tapKey(tester, StoryFlowScreen.dealKey);

      // In cafe the culprit sits in seat 2 (index 1), the other is innocent.
      expect(
        cafe.characters.indexWhere((c) => c.id == cafe.truth.primaryCulprit),
        1,
      );
      final shapes = <List<String>>[];
      final hideOpen = <List<bool>>[];
      for (var seat = 0; seat < 2; seat++) {
        await holdPad(tester);
        shapes.add(shape(tester, StoryFlowScreen.privateCardKey));
        final open = <bool>[];
        FilledButton hide() => tester.widget<FilledButton>(
          find.descendant(
            of: find.byKey(StoryFlowScreen.hideFileKey),
            matching: find.byType(FilledButton),
          ),
        );
        open.add(hide().onPressed != null);
        await tester.pump(StoryTokens.dossierHold - const Duration(seconds: 1));
        open.add(hide().onPressed != null);
        await tester.pump(const Duration(seconds: 1));
        open.add(hide().onPressed != null);
        hideOpen.add(open);
        await tapKey(tester, StoryFlowScreen.hideFileKey);
      }
      expect(shapes[0], shapes[1]);
      expect(hideOpen[0], hideOpen[1]);
      expect(hideOpen[0], [false, false, true]);
      // The old marker that told a culprit apart is gone from the page.
      expect(find.text(arStrings.storiesInvolved), findsNothing);
      expect(find.text(arStrings.storiesNotInvolved), findsNothing);
    });
  });
}

final _picked = <String>{};
