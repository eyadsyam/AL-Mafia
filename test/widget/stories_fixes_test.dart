import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/story_catalog.dart';
import 'package:mafia_master/data/story_progress_store.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/stories/story_progress.dart';
import 'package:mafia_master/stories/story_session.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/stories/story_case_widgets.dart';
import 'package:mafia_master/ui/screens/stories/story_flow_screen.dart';
import 'package:mafia_master/ui/screens/stories/story_rewards.dart';
import 'package:mafia_master/ui/economy/bot_rewards.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';

import '../support/localized.dart';

const _small = Size(360, 640);

class _OneStory extends StoryCatalog {
  const _OneStory(this.story);
  final StoryDefinition story;

  @override
  Future<List<StoryDefinition>> load() async => [story];
}

class _MemoryStore implements StoryProgressStore {
  int saves = 0;

  @override
  Future<StoryProgress> load() async => const StoryProgress();

  @override
  Future<void> save(StoryProgress progress) async => saves++;
}

void main() {
  late StoryDefinition cafe;

  setUpAll(() {
    cafe = StoryDefinition.decode(
      File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
    );
  });

  test('economy requests include the solve picks and bot session', () {
    final correct = StoryAccusation(
      culprit: cafe.truth.primaryCulprit,
      motive: cafe.truth.motive,
      method: cafe.truth.method,
    );
    final completion = StoryCompletion(
      story: cafe,
      score: 100,
      solved: true,
      accusation: correct,
    );
    expect(storySolveRequest(completion), {
      'action': 'storySolved',
      'story': cafe.id,
      'culprit': correct.culprit,
      'motive': correct.motive,
      'method': correct.method,
    });
    expect(
      storySolveRequest(
        StoryCompletion(
          story: cafe,
          score: 0,
          solved: false,
          accusation: correct,
        ),
      ),
      isNull,
    );
    expect(botWinRequest('session-1'), {
      'action': 'botWin',
      'sessionId': 'session-1',
    });
  });

  void size(WidgetTester tester, Size s) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = s;
    addTearDown(tester.view.reset);
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

  Future<void> castVote(
    WidgetTester tester,
    StoryDefinition story, {
    required bool correct,
  }) async {
    final wrong = story.characters
        .firstWhere((c) => c.id != story.truth.primaryCulprit)
        .id;
    await tapKey(
      tester,
      StoryAccusationForm.suspectKey(
        correct ? story.truth.primaryCulprit : wrong,
      ),
    );
    await tapKey(tester, StoryAccusationForm.motiveKey(story.truth.motive));
    await tapKey(tester, StoryAccusationForm.methodKey(story.truth.method));
    final g = await tester.startGesture(
      tester.getCenter(find.byType(StoryHoldButton)),
    );
    await tester.pump(StoryTokens.ballotHold);
    await g.up();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Plays a whole group case; [correct] says per seat whether it votes right.
  Future<void> playGroup(
    WidgetTester tester,
    StoryDefinition story,
    List<bool> correct,
  ) async {
    final players = correct.length;
    await tapKey(tester, StoryFlowScreen.dealKey);
    final picked = <String>{};
    for (var round = 1; round <= StoryTokens.rounds; round++) {
      for (var seat = 0; seat < players; seat++) {
        await holdPad(tester);
        expect(tester.takeException(), isNull);
        await tester.pump(StoryTokens.dossierHold);
        await tapKey(tester, StoryFlowScreen.hideFileKey);
      }
      await tester.tap(find.text(arStrings.storiesSearchTogether));
      await tester.pump(const Duration(milliseconds: 50));
      final open = story
          .sharedActions(players)
          .firstWhere((a) => !picked.contains(a.id));
      picked.add(open.id);
      await tester.scrollUntilVisible(
        find.text(open.title),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(open.title));
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var seat = 0; seat < players; seat++) {
      await holdPad(tester);
      expect(tester.takeException(), isNull);
      await castVote(tester, story, correct: correct[seat]);
    }
    for (var i = 0; i < story.truth.timeline.length; i++) {
      await tester.tap(
        find.text(
          i == story.truth.timeline.length - 1
              ? arStrings.storiesWhoKnew
              : arStrings.storiesNextBeat,
        ),
      );
      await tester.pumpAndSettle();
    }
  }

  Widget flow(
    StoryDefinition story,
    int players, {
    int? seed,
    void Function(StoryCompletion)? done,
    VoidCallback? onExit,
    void Function(String)? play,
    VoidCallback? stop,
  }) => localizedApp(
    StoryFlowScreen(
      story: story,
      playerCount: players,
      seed: seed,
      onExit: onExit ?? () {},
      onComplete: (c) async => done?.call(c),
      playNarration: play,
      stopNarration: stop,
    ),
  );

  testWidgets('culprit own vote does not count: 1 of 2 non-culprit voters '
      'right is not solved', (tester) async {
    size(tester, _small);
    StoryCompletion? completion;
    const seed = 5;
    await tester.pumpWidget(
      flow(cafe, 3, seed: seed, done: (c) => completion = c),
    );
    await tester.pump();
    final seated = StorySession.start(
      story: cafe,
      playerCount: 3,
      seed: seed,
    ).seated;
    final culpritSeat = seated.indexWhere(
      (c) => c.id == cafe.truth.primaryCulprit,
    );
    expect(culpritSeat, isNonNegative);
    // The culprit votes right, one innocent right, the other wrong.
    final others = [
      for (var i = 0; i < 3; i++)
        if (i != culpritSeat) i,
    ];
    final correct = List<bool>.filled(3, false);
    correct[culpritSeat] = true;
    correct[others.first] = true;
    await playGroup(tester, cafe, correct);
    expect(find.byKey(StoryFlowScreen.resultKey), findsOneWidget);
    await tester.tap(find.text(arStrings.storiesAnotherCase));
    await tester.pumpAndSettle();
    expect(completion?.solved, isFalse);
    expect(storySolveRequest(completion!), isNull);
  });

  testWidgets('a majority of non-culprit voters solves it', (tester) async {
    size(tester, _small);
    StoryCompletion? completion;
    await tester.pumpWidget(flow(cafe, 3, done: (c) => completion = c));
    await tester.pump();
    await playGroup(tester, cafe, [true, true, true]);
    await tester.tap(find.text(arStrings.storiesAnotherCase));
    await tester.pumpAndSettle();
    expect(completion?.solved, isTrue);
    expect(completion?.accusation?.culprit, cafe.truth.primaryCulprit);
    expect(completion?.accusation?.motive, cafe.truth.motive);
    expect(completion?.accusation?.method, cafe.truth.method);
  });

  testWidgets('completing twice reports once', (tester) async {
    size(tester, _small);
    var done = 0;
    await tester.pumpWidget(flow(cafe, 3, done: (_) => done++));
    await tester.pump();
    await playGroup(tester, cafe, [true, true, true]);
    final button = find.text(arStrings.storiesAnotherCase);
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(done, 1);
  });

  testWidgets('screen records one launch once and mints a seed per launch', (
    tester,
  ) async {
    size(tester, _small);
    final store = _MemoryStore();
    var afterStory = 0;
    var seeds = 0;
    await tester.pumpWidget(
      localizedApp(
        StoriesScreen(
          onBack: () {},
          catalog: _OneStory(cafe),
          progressStore: store,
          afterStory: (_) async => afterStory++,
          newSeed: () => ++seeds,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(StoriesHub.startKey(cafe.id)));
    await tester.pumpAndSettle();
    // cafe's culprit is seat 2 of 2: a pair leaves one innocent voter.
    final two = find.byKey(const ValueKey('story_players_2'));
    await tester.scrollUntilVisible(
      two,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.widget<OutlinedButton>(two).onPressed, isNull);
    await tapKey(tester, const ValueKey('story_players_1'));
    await tester.pumpAndSettle();
    expect(seeds, 1);
    expect(find.byKey(StoryFlowScreen.soloBoardKey), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(StoryFlowScreen.accusationButtonKey),
      120,
    );
    await tapKey(tester, StoryFlowScreen.accusationButtonKey);
    await tester.pumpAndSettle();
    await tapKey(
      tester,
      StoryAccusationForm.suspectKey(cafe.truth.primaryCulprit),
    );
    await tapKey(tester, StoryAccusationForm.motiveKey(cafe.truth.motive));
    await tapKey(tester, StoryAccusationForm.methodKey(cafe.truth.method));
    await tester.tap(find.byKey(StoryFlowScreen.closeCaseKey));
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
    final back = find.text(arStrings.storiesBackToFiles);
    await tester.tap(back);
    await tester.tap(back, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(store.saves, 1);
    expect(afterStory, 1);
  });

  group('narration', () {
    testWidgets('stops on deal, on exit and on dispose; never plays in a '
        'private phase', (tester) async {
      size(tester, _small);
      var played = 0;
      var stopped = 0;
      var exited = 0;
      await tester.pumpWidget(
        flow(
          cafe,
          3,
          play: (_) => played++,
          stop: () => stopped++,
          onExit: () => exited++,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(played, 1);
      final before = stopped;
      await tapKey(tester, StoryFlowScreen.dealKey);
      expect(stopped, greaterThan(before));
      expect(find.byKey(StoryFlowScreen.handoffKey), findsOneWidget);
      // No narrator control exists on a private page, so nothing can start it.
      expect(find.byKey(StoryNarratorBar.playKey), findsNothing);
      await holdPad(tester);
      expect(find.byKey(StoryNarratorBar.playKey), findsNothing);
      expect(played, 1);

      final beforeDispose = stopped;
      await tester.pumpWidget(const SizedBox());
      expect(stopped, greaterThan(beforeDispose));
      expect(exited, 0);
    });

    testWidgets('system back on the cast page leaves and stops', (
      tester,
    ) async {
      size(tester, _small);
      var stopped = 0;
      var exited = 0;
      await tester.pumpWidget(
        flow(cafe, 3, stop: () => stopped++, onExit: () => exited++),
      );
      await tester.pump();
      expect(find.byKey(StoryFlowScreen.castKey), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exited, 1);
      expect(stopped, greaterThan(0));
    });

    testWidgets('system back is ignored once the files are dealt', (
      tester,
    ) async {
      size(tester, _small);
      var exited = 0;
      await tester.pumpWidget(flow(cafe, 3, onExit: () => exited++));
      await tester.pump();
      await tapKey(tester, StoryFlowScreen.dealKey);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exited, 0);
    });
  });

  group('backgrounded during a private phase', () {
    testWidgets('dossier is covered and the phone returns to the pass state', (
      tester,
    ) async {
      size(tester, _small);
      await tester.pumpWidget(flow(cafe, 3));
      await tester.pump();
      await tapKey(tester, StoryFlowScreen.dealKey);
      await holdPad(tester);
      expect(find.byKey(StoryFlowScreen.privateCardKey), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(StoryFlowScreen.privateCardKey), findsNothing);
      expect(find.byKey(StoryFlowScreen.handoffKey), findsOneWidget);
      expect(find.text('${arStrings.storiesPlayer} 1'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(StoryFlowScreen.privateCardKey), findsNothing);
    });

    testWidgets('ballot selection and hold are dropped', (tester) async {
      size(tester, _small);
      await tester.pumpWidget(flow(cafe, 3));
      await tester.pump();
      // Walk to the first ballot.
      await tapKey(tester, StoryFlowScreen.dealKey);
      final picked = <String>{};
      for (var round = 1; round <= StoryTokens.rounds; round++) {
        for (var seat = 0; seat < 3; seat++) {
          await holdPad(tester);
          await tester.pump(StoryTokens.dossierHold);
          await tapKey(tester, StoryFlowScreen.hideFileKey);
        }
        await tester.tap(find.text(arStrings.storiesSearchTogether));
        await tester.pump(const Duration(milliseconds: 50));
        final open = cafe
            .sharedActions(3)
            .firstWhere((a) => !picked.contains(a.id));
        picked.add(open.id);
        await tester.scrollUntilVisible(
          find.text(open.title),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(open.title));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await holdPad(tester);
      expect(find.byKey(StoryFlowScreen.voteKey), findsOneWidget);
      await tapKey(
        tester,
        StoryAccusationForm.suspectKey(cafe.truth.primaryCulprit),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(StoryFlowScreen.voteKey), findsNothing);
      expect(find.byKey(StoryFlowScreen.handoffKey), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await holdPad(tester);
      expect(find.byKey(StoryFlowScreen.voteKey), findsOneWidget);
      final hold = tester.widget<StoryHoldButton>(find.byType(StoryHoldButton));
      expect(hold.enabled, isFalse);
    });
  });

  group('StoryHoldButton', () {
    testWidgets('a second finger neither starts nor cancels the hold', (
      tester,
    ) async {
      var confirmed = 0;
      await tester.pumpWidget(
        localizedApp(
          Center(
            child: SizedBox(
              width: 300,
              child: StoryHoldButton(
                label: 'hold',
                doneLabel: 'done',
                duration: const Duration(seconds: 1),
                enabled: true,
                onConfirmed: () => confirmed++,
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(StoryHoldButton));
      final first = await tester.startGesture(center, pointer: 1);
      await tester.pump(const Duration(milliseconds: 300));
      final second = await tester.startGesture(center, pointer: 2);
      await tester.pump(const Duration(milliseconds: 100));
      await second.up();
      await tester.pump(const Duration(milliseconds: 700));
      expect(confirmed, 1);
      await first.up();
    });

    testWidgets('a change of enabled resets a hold in flight', (tester) async {
      var confirmed = 0;
      Widget build(bool enabled) => localizedApp(
        Center(
          child: SizedBox(
            width: 300,
            child: StoryHoldButton(
              label: 'hold',
              doneLabel: 'done',
              duration: const Duration(seconds: 1),
              enabled: enabled,
              onConfirmed: () => confirmed++,
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(true));
      final g = await tester.startGesture(
        tester.getCenter(find.byType(StoryHoldButton)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(build(false));
      await tester.pump(const Duration(seconds: 2));
      expect(confirmed, 0);
      await g.up();
    });
  });

  testWidgets('dossier keeps one slot per round, empty ones included', (
    tester,
  ) async {
    size(tester, _small);
    final clue = cafe.clues.first;
    Widget dossier(List<StoryClue?> clues) => localizedApp(
      Scaffold(
        body: SingleChildScrollView(
          child: StoryDossier(
            character: cafe.characters.first,
            clues: clues,
            youAre: 'a',
            mustDo: 'b',
          ),
        ),
      ),
    );
    await tester.pumpWidget(dossier([clue, null, clue]));
    expect(find.byType(StoryNote), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == StoryTokens.emptyClueSlot,
      ),
      findsOneWidget,
    );
  });

  group('360x640 no overflow', () {
    late StoryDefinition longObjective;

    setUpAll(() {
      final c = cafe;
      longObjective = StoryDefinition(
        id: c.id,
        number: c.number,
        title: c.title,
        category: c.category,
        synopsis: c.synopsis,
        difficulty: c.difficulty,
        lengthMinutes: c.lengthMinutes,
        coverImage: c.coverImage,
        actionBudget: c.actionBudget,
        discussionSeconds: c.discussionSeconds,
        characters: [
          for (final ch in c.characters)
            StoryCharacter(
              id: ch.id,
              name: ch.name,
              image: ch.image,
              background: ch.background,
              objective: List.filled(30, ch.objective).join(' '),
              privateClueIds: ch.privateClueIds,
            ),
        ],
        locations: c.locations,
        motives: c.motives,
        methods: c.methods,
        truth: c.truth,
        clues: c.clues,
        actions: c.actions,
      );
    });

    testWidgets('ballot with ten options, long-objective dossier and the '
        'result', (tester) async {
      size(tester, _small);
      expect(longObjective.characters, hasLength(10));
      await tester.pumpWidget(flow(longObjective, 3));
      await tester.pump();
      await playGroup(tester, longObjective, [true, true, false]);
      expect(find.byKey(StoryFlowScreen.resultKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
