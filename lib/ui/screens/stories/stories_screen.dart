import '../../widgets/mafia_kit.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/deck/deck_public.dart' show BoneButton, DeckPill;

import '../../../data/story_catalog.dart';
import '../../../data/story_progress_store.dart';
import '../../../stories/story_model.dart';
import '../../../stories/story_progress.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/experience_surface.dart';
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
  });

  /// Plays a case's read-aloud opening.
  final void Function(String asset)? playNarration;

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
  final Future<int> Function(String storyId)? claimReward;

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
    final granted = await claim(completion.story.id);
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
        onExit: () => setState(() => _launch = null),
        onComplete: _record,
        watchAdForStep: widget.watchAdForStep,
        playNarration: widget.playNarration,
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
        setState(
          () => _launch = StorySessionLaunch(story: story, playerCount: count),
        );
      },
    );
  }
}

class StorySessionLaunch {
  const StorySessionLaunch({required this.story, required this.playerCount});

  final StoryDefinition story;
  final int playerCount;
}

class StoriesHub extends StatelessWidget {
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

  final List<StoryDefinition> stories;
  final StoryProgress progress;
  final VoidCallback onBack;
  final void Function(StoryDefinition story, int playerCount) onStart;

  Future<void> _pickPlayers(BuildContext context, StoryDefinition story) async {
    final count = await showMafiaSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _PlayerCountSheet(),
    );
    if (count != null && context.mounted) onStart(story, count);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final l = context.l10n;
    return MafiaScaffold(
      key: hubKey,
      backgroundColor: colors.surfaceBase,
      bottomNavigationBar: const SafeArea(
        top: false,
        child: WaitingBanner(placement: BannerPlacement.stories),
      ),
      body: ExperienceSurface(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(spacing.screenMargin),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: BackAction(onPressed: onBack),
              ),
              SizedBox(height: spacing.md),
              Text(
                l.storiesTitle,
                style: StoryTokens.ruqaa(type.headline).copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: spacing.xs),
              Text(
                l.storiesSubtitle,
                style: type.body.copyWith(color: colors.textSecondary),
              ),
              SizedBox(height: spacing.lg),
              for (final (i, story) in stories.indexed) ...[
                // Never in the first screenful, at most one per four cases.
                if (i >= 4 && i % 4 == 0)
                  const NativeAdCard(placement: NativePlacement.stories),
                _StoryCard(
                  key: storyKey(story.id),
                  story: story,
                  bestScore: progress.bestFor(story.id),
                  locked:
                      story.isNearImpossible &&
                      !progress.isNearImpossibleUnlocked(story.category),
                  onStart: () => _pickPlayers(context, story),
                ),
                SizedBox(height: spacing.md),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    super.key,
    required this.story,
    required this.bestScore,
    required this.locked,
    required this.onStart,
  });

  final StoryDefinition story;
  final int bestScore;
  final bool locked;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final l = context.l10n;
    // Locked dims the art only: the title and what unlocks it stay readable.
    return MafiaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: locked ? StoryTokens.lockedOpacity : 1,
              child: _FeatheredStoryArt(
                image: story.coverImage,
                height: StoryTokens.coverHeight,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${story.number}. ${story.title}',
                    style: StoryTokens.ruqaa(type.title).copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    story.synopsis,
                    style: type.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  SizedBox(height: spacing.sm),
                  Wrap(
                    spacing: spacing.sm,
                    runSpacing: spacing.xs,
                    children: [
                      DeckPill(story.category),
                      DeckPill('${story.lengthMinutes} ${l.storiesMinutes}'),
                      DeckPill('${l.storiesDifficulty} ${story.difficulty}/5'),
                    ],
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    bestScore == 0
                        ? l.storiesNoScore
                        : '${l.storiesBestScore}: $bestScore',
                    style: type.caption.copyWith(color: colors.textMuted),
                  ),
                  if (locked) ...[
                    SizedBox(height: spacing.sm),
                    Text(
                      '${l.storiesLocked} — ${l.storiesUnlockRule}',
                      style: type.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: spacing.md),
                    BoneButton(
                      key: StoriesHub.startKey(story.id),
                      label: l.storiesStart,
                      onPressed: onStart,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _FeatheredStoryArt extends StatelessWidget {
  const _FeatheredStoryArt({required this.image, required this.height});

  final String image;
  final double height;

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surfaceRaised;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(image, fit: BoxFit.cover, excludeFromSemantics: true),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: StoryTokens.transparentAlpha),
                  surface,
                ],
                stops: const [StoryTokens.featherStart, StoryTokens.featherEnd],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCountSheet extends StatelessWidget {
  const _PlayerCountSheet();

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
              onPressed: () => Navigator.pop(context, count),
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
