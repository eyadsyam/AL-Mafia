import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/deck/deck_public.dart' show DeckChip, DeckRise;
import '../../widgets/mafia_kit.dart';
import '../../widgets/warm_palette.dart';
import 'story_case_widgets.dart';

import '../../../data/match_seed.dart';
import '../../../data/story_catalog.dart';
import '../../../data/story_progress_store.dart';
import '../../../stories/story_model.dart';
import '../../../stories/story_progress.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import 'story_flow_screen.dart';
import '../../economy/waiting_banner.dart';
import '../../economy/native_ad_card.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({
    super.key,
    required this.onBack,
    this.catalog = const StoryCatalog(),
    this.progressStore = const SharedPreferencesStoryProgressStore(),
    this.claimReward,
    this.beforeStory,
    this.afterStory,
    this.watchAdForStep,
    this.playNarration,
    this.stopNarration,
    this.newSeed = newMatchSeed,
  });

  /// Mints the seating seed of each launch.
  final int Function() newSeed;

  /// Plays a case's read-aloud opening.
  final void Function(String asset)? playNarration;

  /// Stops it again (the narrator bar's pause).
  final VoidCallback? stopNarration;

  /// Full-screen ad moments around a case (pass-and-play pacing rules).
  final Future<void> Function()? beforeStory;
  final Future<void> Function(String storyId)? afterStory;

  /// A rewarded ad that buys one more investigation step.
  final Future<bool> Function()? watchAdForStep;

  final VoidCallback onBack;
  final StoryCatalog catalog;
  final StoryProgressStore progressStore;

  /// Pays the first solve of a story; returns the coins granted (0 when
  /// none). Absent in tests and builds without a server.
  final Future<int> Function(StoryCompletion completion)? claimReward;

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  List<StoryDefinition>? _stories;
  StoryProgress _progress = const StoryProgress();
  StorySessionLaunch? _launch;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object>([
        widget.catalog.load(),
        widget.progressStore.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _stories = values[0] as List<StoryDefinition>;
        _progress = values[1] as StoryProgress;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _record(StoryCompletion completion) async {
    // One record per launch: a second call (double tap, re-entry) finds the
    // launch already closed and does nothing, so nothing is saved, counted
    // as an ad moment or rewarded twice.
    if (_launch == null) return;
    final firstSolve =
        completion.solved &&
        !_progress.solvedStoryIds.contains(completion.story.id);
    final next = _progress.record(
      storyId: completion.story.id,
      category: completion.story.category,
      score: completion.score,
      solved: completion.solved,
    );
    setState(() {
      _progress = next;
      _launch = null;
    });
    await widget.progressStore.save(next);
    unawaited(widget.afterStory?.call(completion.story.id));
    final claim = widget.claimReward;
    if (!firstSolve || claim == null) return;
    final granted = await claim(completion);
    if (granted <= 0 || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.storyRewardGranted(granted))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final launch = _launch;
    if (launch != null) {
      return StoryFlowScreen(
        story: launch.story,
        playerCount: launch.playerCount,
        seed: launch.seed,
        onExit: () => setState(() => _launch = null),
        onComplete: _record,
        watchAdForStep: widget.watchAdForStep,
        playNarration: widget.playNarration,
        stopNarration: widget.stopNarration,
        onHome: widget.onBack,
      );
    }
    if (_error != null) {
      return _StoryLoadError(onBack: widget.onBack, onRetry: _load);
    }
    final stories = _stories;
    if (stories == null) {
      return const MafiaScaffold(body: SafeArea(child: MafiaLoading(cards: 1)));
    }
    return StoriesHub(
      stories: stories,
      progress: _progress,
      onBack: widget.onBack,
      onStart: (story, count) async {
        await widget.beforeStory?.call();
        if (!mounted) return;
        if (count > 1 && count < story.minGroupPlayers) return;
        setState(
          () => _launch = StorySessionLaunch(
            story: story,
            playerCount: count,
            seed: widget.newSeed(),
          ),
        );
      },
    );
  }
}

class StorySessionLaunch {
  const StorySessionLaunch({
    required this.story,
    required this.playerCount,
    required this.seed,
  });

  final StoryDefinition story;
  final int playerCount;
  final int seed;
}

class StoriesHub extends StatefulWidget {
  const StoriesHub({
    super.key,
    required this.stories,
    required this.progress,
    required this.onBack,
    required this.onStart,
  });

  static const hubKey = ValueKey('stories_hub');
  static Key storyKey(String id) => ValueKey('story_card_$id');
  static Key startKey(String id) => ValueKey('story_start_$id');
  static Key chipKey(String category) => ValueKey('story_chip_$category');

  final List<StoryDefinition> stories;
  final StoryProgress progress;
  final VoidCallback onBack;
  final void Function(StoryDefinition story, int playerCount) onStart;

  @override
  State<StoriesHub> createState() => _StoriesHubState();
}

class _StoriesHubState extends State<StoriesHub> {
  /// null = all categories.
  String? _category;

  Future<void> _pickPlayers(BuildContext context, StoryDefinition story) async {
    final count = await showMafiaSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PlayerCountSheet(minGroup: story.minGroupPlayers),
    );
    if (count != null && context.mounted) widget.onStart(story, count);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final type = context.typography;
    final l = context.l10n;
    final categories = <String>[];
    for (final s in widget.stories) {
      if (!categories.contains(s.category)) categories.add(s.category);
    }
    final shown = [
      for (final s in widget.stories)
        if (_category == null || s.category == _category) s,
    ];
    return WarmPalette(
      child: StoryDesk(
        key: StoriesHub.hubKey,
        title: l.storiesArchiveTitle,
        onBack: widget.onBack,
        bottom: const SafeArea(
          top: false,
          child: WaitingBanner(placement: BannerPlacement.stories),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            spacing.screenMargin,
            spacing.sm,
            spacing.screenMargin,
            spacing.lg,
          ),
          children: [
            Text(
              l.storiesSubtitle,
              style: type.bodySmall.copyWith(color: CaseFileTokens.inkMuted),
            ),
            SizedBox(height: spacing.md),
            SizedBox(
              height: StoryTokens.chipHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DeckChip(
                      key: StoriesHub.chipKey(''),
                      label: l.storiesFilterAll,
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final c in categories) ...[
                      SizedBox(width: spacing.sm),
                      DeckChip(
                        key: StoriesHub.chipKey(c),
                        label: c,
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.sm),
            for (final (i, story) in shown.indexed) ...[
              // Never in the first screenful, at most one per four cases.
              if (i >= 4 && i % 4 == 0)
                const NativeAdCard(placement: NativePlacement.stories),
              DeckRise(index: i, child: _folder(context, story)),
              SizedBox(height: spacing.md),
            ],
          ],
        ),
      ),
    );
  }

  Widget _folder(BuildContext context, StoryDefinition story) {
    final l = context.l10n;
    final locked =
        story.isNearImpossible &&
        !widget.progress.isNearImpossibleUnlocked(story.category);
    final solved = widget.progress.solvedStoryIds.contains(story.id);
    final best = widget.progress.bestFor(story.id);
    return KeyedSubtree(
      key: StoriesHub.storyKey(story.id),
      child: StoryFolder(
        key: locked ? null : StoriesHub.startKey(story.id),
        numberLabel: l.storiesCaseNo(story.number),
        title: story.title,
        category: story.category,
        synopsis: story.synopsis,
        facts: [
          '${story.lengthMinutes} ${l.storiesMinutes}',
          '${l.storiesDifficulty} ${story.difficulty}/5',
        ],
        image: story.coverImage,
        stampText: solved
            ? (best > 0
                  ? l.storiesStampSolvedScore(best)
                  : l.storiesStampSolved)
            : l.storiesStampOpen,
        stampColor: solved ? CaseFileTokens.sage : StoryTokens.stampOpen,
        sealed: locked,
        unlockText: '${l.storiesLocked} — ${l.storiesUnlockRule}',
        onTap: locked ? null : () => _pickPlayers(context, story),
      ),
    );
  }
}

class _PlayerCountSheet extends StatelessWidget {
  const _PlayerCountSheet({required this.minGroup});

  /// Smallest group the case seats well; fewer is not offered.
  final int minGroup;

  static Key countKey(int count) => ValueKey('story_players_$count');

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        spacing.screenMargin,
        spacing.lg,
        spacing.screenMargin,
        spacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.storiesPlayerCountTitle, style: context.typography.title),
          SizedBox(height: spacing.md),
          for (var count = 1; count <= 10; count++) ...[
            OutlinedButton(
              key: countKey(count),
              onPressed: count > 1 && count < minGroup
                  ? null
                  : () => Navigator.pop(context, count),
              child: Text(
                count == 1
                    ? '1 — ${l.storiesSolo}'
                    : '$count ${l.storiesPlayers} — ${l.storiesGroup}',
              ),
            ),
            SizedBox(height: spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _StoryLoadError extends StatelessWidget {
  const _StoryLoadError({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MafiaScaffold(
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BackAction(onPressed: onBack),
            ),
            const Spacer(),
            MafiaError(
              message: context.l10n.storiesLoadError,
              action: context.l10n.storiesRetry,
              onRetry: onRetry,
            ),
            const Spacer(),
          ],
        ),
      ),
    ),
  );
}
