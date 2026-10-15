import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../economy/all_access.dart' show allAccessProvider;

import '../../widgets/deck/deck_public.dart' show DeckRise;

import '../../../data/match_seed.dart';
import '../../../data/story_catalog.dart';
import '../../../data/story_progress_store.dart';
import '../../../data/story_v2_memory.dart';
import '../../../data/story_world_catalog.dart';
import '../../../platform/narration_player.dart';
import '../../../platform/narration_controller.dart';
import '../../../stories/story_model.dart';
import '../../../stories/story_progress.dart';
import '../../../stories/v2/session.dart';
import '../../../stories/v2/table.dart';
import '../../../stories/v2/world.dart';
import 'v2/lamp_kit.dart';
import 'v2/story_about_screen.dart';
import 'v2/story_lobby_screen.dart';
import 'v2/story_table_screen.dart';
import '../../../app/l10n/app_localizations.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import 'story_flow_screen.dart';
import 'story_rewards.dart' show StoryServerDeal;
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
    this.worldCatalog = const StoryWorldCatalog(),
    this.culpritHistory = const SharedPreferencesStoryCulpritHistory(),
    this.v2Memory = const SharedPreferencesStoryV2Memory(),
    this.narrationFactory = _pluginNarration,
    this.startV2Session,
    this.claimV2Reward,
    this.exitGuard,
  });

  /// The route's question to an open V2 table before the browser leaves.
  final StoryExitGuard? exitGuard;

  static NarrationController _pluginNarration() =>
      NarrationController(createNarrationPlayer());

  /// Stories V2: the rewritten cases, and what the phone remembers of them.
  final StoryWorldCatalog worldCatalog;
  final StoryCulpritHistory culpritHistory;
  final StoryV2Memory v2Memory;

  /// The narrator's player, made the first time a V2 case opens.
  final NarrationController Function() narrationFactory;

  /// Story sessions: the server deals who did it at a V2 table (null when
  /// it cannot: the phone deals and the table earns nothing) …
  final Future<StoryServerDeal?> Function(
    String storyId,
    int players,
    Set<String> avoid,
  )?
  startV2Session;

  /// … and pays a right answer's first solve; returns the coins granted.
  final Future<int> Function(String sessionId, StoryAccusationV2 accusation)?
  claimV2Reward;

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

  Map<String, StoryWorld> _worlds = const {};
  bool? _aboutSeen;
  bool _showAbout = false;
  StoryDefinition? _v2Story;
  List<String>? _v2Players;
  StoryTable? _v2Table;
  int _v2Seed = 0;
  String? _v2Session;
  NarrationController? _narrationOrNull;

  NarrationController get _narration =>
      _narrationOrNull ??= widget.narrationFactory();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _narrationOrNull?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<Object>([
        widget.catalog.load(),
        widget.progressStore.load(),
        widget.worldCatalog.load(),
        widget.v2Memory.aboutSeen(),
      ]);
      if (!mounted) return;
      _precacheCovers(values[0] as List<StoryDefinition>);
      setState(() {
        _stories = values[0] as List<StoryDefinition>;
        _progress = values[1] as StoryProgress;
        _worlds = values[2] as Map<String, StoryWorld>;
        _aboutSeen = values[3] as bool;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// The first screenful of hub covers decodes while the explainer (or the
  /// load) is up, not during the hub's entrance.
  void _precacheCovers(List<StoryDefinition> stories) {
    for (final story in stories.take(StoriesLampTokens.coversAhead)) {
      precacheImage(
        StoriesHub.coverImage(context, story.coverImage),
        context,
        onError: (_, _) {},
      );
    }
  }

  Future<void> _dealV2(List<String> players) async {
    final story = _v2Story;
    final world = story == null ? null : _worlds[story.id];
    if (story == null || world == null) return;
    final recent = await widget.culpritHistory.recent(world.id);
    // The server's deal runs while the ad moment plays, and is given up
    // after a short wait: a table never waits on the network.
    final asked = widget.startV2Session?.call(world.id, players.length, recent);
    await widget.beforeStory?.call();
    StoryServerDeal? deal;
    try {
      deal = await asked?.timeout(StoriesLampTokens.serverDealWait);
    } on Object {
      deal = null;
    }
    if (!mounted) return;
    final seed = widget.newSeed();
    StoryTable table;
    try {
      table = StoryTable.deal(
        world: world,
        players: players,
        seed: seed,
        recentCulprits: recent,
        pick: deal?.pick,
      );
    } on ArgumentError {
      // A pick this build cannot play (a newer server): deal on the phone.
      deal = null;
      table = StoryTable.deal(
        world: world,
        players: players,
        seed: seed,
        recentCulprits: recent,
      );
    }
    await widget.culpritHistory.remember(world.id, table.culpritId);
    if (!mounted) return;
    setState(() {
      _v2Players = players;
      _v2Seed = seed;
      _v2Table = table;
      _v2Session = deal?.sessionId;
    });
  }

  Future<void> _finishV2(StorySessionV2 session) async {
    final story = _v2Story;
    if (story == null) return;
    final next = _progress.record(
      storyId: story.id,
      category: story.category,
      score: 0,
      solved: session.solved,
    );
    final sessionId = _v2Session;
    setState(() {
      _progress = next;
      _v2Session = null;
    });
    await widget.progressStore.save(next);
    unawaited(widget.afterStory?.call(story.id));
    final claim = widget.claimV2Reward;
    if (!session.solved || sessionId == null || claim == null) return;
    final granted = await claim(sessionId, session.accusation!);
    if (granted <= 0 || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.storyRewardGranted(granted))),
    );
  }

  void _closeV2() {
    _narrationOrNull?.stop();
    setState(() {
      _v2Story = null;
      _v2Players = null;
      _v2Table = null;
      _v2Session = null;
    });
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
      // The lamp ground from the first frame: no other look flashes first.
      return const LampScaffold(body: SizedBox.shrink());
    }
    if (_aboutSeen == false || _showAbout) {
      return StoryAboutScreen(
        onBack: _showAbout
            ? () => setState(() => _showAbout = false)
            : widget.onBack,
        onDone: () {
          widget.v2Memory.markAboutSeen();
          setState(() {
            _aboutSeen = true;
            _showAbout = false;
          });
        },
      );
    }
    final v2Story = _v2Story;
    final v2World = v2Story == null ? null : _worlds[v2Story.id];
    if (v2Story != null && v2World != null) {
      final table = _v2Table;
      if (table == null) {
        return StoryLobbyScreen(
          world: v2World,
          coverImage: v2Story.coverImage,
          narration: _narration,
          memory: widget.v2Memory,
          onExit: _closeV2,
          onPlay: _dealV2,
        );
      }
      return StoryTableScreen(
        key: ValueKey(_v2Seed),
        table: table,
        seed: _v2Seed,
        narration: _narration,
        onExit: _closeV2,
        onPlayAgain: () => _dealV2(_v2Players!),
        onFinished: _finishV2,
        watchAdForSearch: widget.watchAdForStep,
        exitGuard: widget.exitGuard,
      );
    }
    return StoriesHub(
      stories: stories,
      progress: _progress,
      onBack: widget.onBack,
      worldIds: _worlds.keys.toSet(),
      onOpenWorld: (story) => setState(() => _v2Story = story),
      onHowTo: () => setState(() => _showAbout = true),
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

class StoriesHub extends ConsumerStatefulWidget {
  const StoriesHub({
    super.key,
    required this.stories,
    required this.progress,
    required this.onBack,
    required this.onStart,
    this.worldIds = const {},
    this.onOpenWorld,
    this.onHowTo,
  });

  static const hubKey = ValueKey('stories_hub');
  static const howToKey = ValueKey('stories_how_to');
  static Key storyKey(String id) => ValueKey('story_card_$id');
  static Key startKey(String id) => ValueKey('story_start_$id');
  static Key chipKey(String category) => ValueKey('story_chip_$category');

  /// A hub cover, decoded at the size the card draws it.
  static ImageProvider coverImage(BuildContext context, String path) =>
      ResizeImage(
        AssetImage(path),
        width:
            (StoriesLampTokens.coverWidth *
                    MediaQuery.devicePixelRatioOf(context))
                .ceil(),
      );

  final List<StoryDefinition> stories;
  final StoryProgress progress;
  final VoidCallback onBack;
  final void Function(StoryDefinition story, int playerCount) onStart;

  /// Stories rewritten for V2 open their own file instead of the count sheet.
  final Set<String> worldIds;
  final void Function(StoryDefinition story)? onOpenWorld;

  /// Opens «يعني إيه قصص وتحقيقات؟» again.
  final VoidCallback? onHowTo;

  @override
  ConsumerState<StoriesHub> createState() => _StoriesHubState();
}

class _StoriesHubState extends ConsumerState<StoriesHub> {
  /// null = all categories.
  String? _category;

  Future<void> _pickPlayers(BuildContext context, StoryDefinition story) async {
    final count = await showLampSheet<int>(
      context,
      (context) => _PlayerCountSheet(minGroup: story.minGroupPlayers),
    );
    if (count != null && context.mounted) widget.onStart(story, count);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = context.l10n;
    final categories = <String>[];
    for (final story in widget.stories) {
      if (!categories.contains(story.category)) categories.add(story.category);
    }
    final shown = [
      for (final story in widget.stories)
        if (_category == null || story.category == _category) story,
    ];
    return LampScaffold(
      key: StoriesHub.hubKey,
      onBack: widget.onBack,
      trailing: widget.onHowTo == null
          ? null
          : TextButton(
              key: StoriesHub.howToKey,
              onPressed: widget.onHowTo,
              child: Text(
                l.sv2HowToPlay,
                style: context.typography.bodySmall.copyWith(
                  color: StoriesLampTokens.amberHi,
                ),
              ),
            ),
      footer: const WaitingBanner(placement: BannerPlacement.stories),
      body: ListView(
        // Its own scroll memory: a case opened from far down the list does
        // not open scrolled down too.
        key: const PageStorageKey<String>('stories_hub_list'),
        padding: EdgeInsets.fromLTRB(s.screenMargin, 0, s.screenMargin, s.lg),
        children: [
          LampTitle(l.sv2HubTitle, small: true),
          SizedBox(height: s.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  context,
                  StoriesHub.chipKey(''),
                  l.storiesFilterAll,
                  null,
                ),
                for (final c in categories) ...[
                  SizedBox(width: s.sm),
                  _chip(context, StoriesHub.chipKey(c), c, c),
                ],
              ],
            ),
          ),
          SizedBox(height: s.md),
          for (final (i, story) in shown.indexed) ...[
            // Never in the first screenful, at most one per four cases.
            if (i >= 4 && i % 4 == 0) ...[
              const NativeAdCard(placement: NativePlacement.stories),
              SizedBox(height: s.sm),
            ],
            DeckRise(index: i, child: _case(context, story)),
            SizedBox(height: s.sm),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, Key key, String label, String? category) {
    final on = _category == category;
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: on,
      showCheckmark: false,
      selectedColor: StoriesLampTokens.amber,
      backgroundColor: StoriesLampTokens.ground,
      side: BorderSide(
        color: on ? StoriesLampTokens.amber : StoriesLampTokens.line,
      ),
      shape: const StadiumBorder(),
      labelStyle: context.typography.bodySmall.copyWith(
        color: on ? StoriesLampTokens.onAmber : StoriesLampTokens.text2,
        fontWeight: on ? FontWeight.w700 : FontWeight.w400,
      ),
      onSelected: (_) => setState(() => _category = category),
    );
  }

  Widget _case(BuildContext context, StoryDefinition story) {
    final l = context.l10n;
    final s = context.spacing;
    final locked =
        story.isNearImpossible &&
        !ref.watch(allAccessProvider) &&
        !widget.progress.isNearImpossibleUnlocked(story.category);
    final solved = widget.progress.solvedStoryIds.contains(story.id);
    final best = widget.progress.bestFor(story.id);
    final rewritten = widget.worldIds.contains(story.id);
    final players = rewritten || story.minGroupPlayers <= 2
        ? l.sv2HubPlayersAll
        : l.sv2HubPlayersFrom(_digits(context, story.minGroupPlayers));
    final status = locked
        ? '${l.storiesLocked} — ${l.storiesUnlockRule}'
        : solved
        ? (best > 0 ? l.storiesStampSolvedScore(best) : l.storiesStampSolved)
        : l.sv2HubOpen;
    final card = Container(
      padding: EdgeInsets.all(s.sm),
      decoration: BoxDecoration(
        color: StoriesLampTokens.panel,
        borderRadius: BorderRadius.circular(StoriesLampTokens.radiusButton),
        border: Border.all(color: StoriesLampTokens.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(StoriesLampTokens.radiusPaper),
            child: Image(
              image: StoriesHub.coverImage(context, story.coverImage),
              width: StoriesLampTokens.coverWidth,
              height: StoriesLampTokens.coverHeight,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox(
                width: StoriesLampTokens.coverWidth,
                height: StoriesLampTokens.coverHeight,
              ),
            ),
          ),
          SizedBox(width: s.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.title,
                  style: StoryTokens.ruqaa(context.typography.headline)
                      .copyWith(
                        color: StoriesLampTokens.paper,
                        fontSize: StoriesLampTokens.caseTitle,
                      ),
                ),
                LampMeta(
                  '${story.category} · $players · '
                  '${_length(l, story.lengthMinutes)}',
                ),
                LampMeta(
                  status,
                  color: solved || locked
                      ? StoriesLampTokens.text2
                      : StoriesLampTokens.amberHi,
                ),
              ],
            ),
          ),
          if (locked)
            const Icon(Icons.lock_rounded, color: StoriesLampTokens.muted),
        ],
      ),
    );
    return KeyedSubtree(
      key: StoriesHub.storyKey(story.id),
      child: locked
          ? Opacity(opacity: StoriesLampTokens.lockedCase, child: card)
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: StoriesHub.startKey(story.id),
                borderRadius: BorderRadius.circular(
                  StoriesLampTokens.radiusButton,
                ),
                onTap: rewritten && widget.onOpenWorld != null
                    ? () => widget.onOpenWorld!(story)
                    : () => _pickPlayers(context, story),
                child: card,
              ),
            ),
    );
  }

  /// [n] in the digits of the line it sits in (the Arabic copy writes
  /// «من ١ لـ١٠», so a number beside it is written the same way).
  static String _digits(BuildContext context, int n) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? String.fromCharCodes([
          for (final unit in '$n'.codeUnits) unit - _asciiZero + _arabicZero,
        ])
      : '$n';

  static const _asciiZero = 0x30;
  static const _arabicZero = 0x0660;

  /// A case's length in plain words, to the nearest quarter hour.
  static String _length(AppLocalizations l, int minutes) =>
      switch ((minutes / 15).round()) {
        <= 1 => l.sv2LengthQ1,
        2 => l.sv2LengthQ2,
        3 => l.sv2LengthQ3,
        4 => l.sv2LengthQ4,
        5 => l.sv2LengthQ5,
        _ => l.sv2LengthQ6,
      };
}

class _PlayerCountSheet extends StatelessWidget {
  const _PlayerCountSheet({required this.minGroup});

  /// Smallest group the case seats well; fewer is not offered.
  final int minGroup;

  static Key countKey(int count) => ValueKey('story_players_$count');

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        s.screenMargin,
        s.lg,
        s.screenMargin,
        s.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LampTitle(l.storiesPlayerCountTitle, small: true),
          SizedBox(height: s.md),
          for (var count = 1; count <= 10; count++) ...[
            LampButton(
              key: countKey(count),
              kind: LampButtonKind.ghost,
              onPressed: count > 1 && count < minGroup
                  ? null
                  : () => Navigator.pop(context, count),
              label: count == 1
                  ? '1 — ${l.storiesSolo}'
                  : '$count ${l.storiesPlayers} — ${l.storiesGroup}',
            ),
            SizedBox(height: s.sm),
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
  Widget build(BuildContext context) => LampScaffold(
    onBack: onBack,
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.screenMargin),
        child: LampMeta(context.l10n.storiesLoadError, center: true),
      ),
    ),
    footer: LampButton(label: context.l10n.storiesRetry, onPressed: onRetry),
  );
}
