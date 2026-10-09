import 'dart:async';

import 'package:flutter/material.dart';

import '../../../stories/story_model.dart';
import '../../../stories/story_session.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/case_file.dart';
import '../../widgets/deck/deck_public.dart' show BoneButton, RimButton;
import '../../widgets/hold_pad.dart';
import '../../widgets/mafia_kit.dart';
import '../../widgets/warm_palette.dart';
import 'story_case_widgets.dart';

class StoryCompletion {
  const StoryCompletion({
    required this.story,
    required this.score,
    required this.solved,
  });

  final StoryDefinition story;
  final int score;
  final bool solved;
}

class StoryFlowScreen extends StatefulWidget {
  const StoryFlowScreen({
    super.key,
    required this.story,
    required this.playerCount,
    required this.onExit,
    required this.onComplete,
    this.onHome,
    this.watchAdForStep,
    this.playNarration,
    this.stopNarration,
  });

  /// Plays an audio asset at the table (the case's opening). Absent in tests.
  final void Function(String asset)? playNarration;

  /// Stops the narrator again.
  final VoidCallback? stopNarration;

  /// Leaves for the home screen once the case is recorded.
  final VoidCallback? onHome;

  /// Shows a rewarded ad; true when it was watched to the end. Absent in
  /// tests and builds without ads. At most [StoryTokens.bonusSteps] a case.
  final Future<bool> Function()? watchAdForStep;

  static const soloBoardKey = ValueKey('story_solo_board');
  static const bonusStepKey = ValueKey('story_bonus_step');
  static const castKey = ValueKey('story_cast');
  static const dealKey = ValueKey('story_deal');
  static const handoffKey = ValueKey('story_group_handoff');
  static const privateCardKey = ValueKey('story_private_card');
  static const discussionKey = ValueKey('story_discussion');
  static const investigationKey = ValueKey('story_investigation');
  static const voteKey = ValueKey('story_vote');
  static const reenactmentKey = ValueKey('story_reenactment');
  static const resultKey = ValueKey('story_result');
  static const accusationButtonKey = ValueKey('story_accuse');
  static const closeCaseKey = ValueKey('story_close_case');
  static const hideFileKey = ValueKey('story_hide_file');

  final StoryDefinition story;
  final int playerCount;
  final VoidCallback onExit;
  final Future<void> Function(StoryCompletion completion) onComplete;

  @override
  State<StoryFlowScreen> createState() => _StoryFlowScreenState();
}

class _StoryFlowScreenState extends State<StoryFlowScreen> {
  late StorySession _session;
  Timer? _timer;
  Timer? _dossierTimer;
  int _seconds = 0;
  int _dossierLeft = 0;
  int _reenactmentStep = 0;

  /// The group has seen the cast and dealt the files.
  bool _dealt = false;

  /// The secret ballot being filled in; cleared the moment it is handed in.
  String? _bCulprit;
  String? _bMotive;
  String? _bMethod;

  bool get _group => widget.playerCount > 1;

  bool get _privatePhase => switch (_session.phase) {
    StoryPhase.groupHandoff ||
    StoryPhase.groupPrivateClue ||
    StoryPhase.groupVoteHandoff ||
    StoryPhase.groupVote => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _session = StorySession.start(
      story: widget.story,
      playerCount: widget.playerCount,
      seed: widget.story.number * StoryTokens.rounds + widget.playerCount,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dossierTimer?.cancel();
    super.dispose();
  }

  void _setSession(StorySession next) {
    _timer?.cancel();
    _dossierTimer?.cancel();
    if (next.phase == StoryPhase.groupDiscussion) {
      _seconds = widget.story.discussionSeconds;
    }
    if (next.phase == StoryPhase.groupPrivateClue) {
      _dossierLeft = StoryTokens.dossierHold.inSeconds;
    }
    _bCulprit = _bMotive = _bMethod = null;
    setState(() => _session = next);
    if (next.phase == StoryPhase.groupDiscussion) _startDiscussion();
    if (next.phase == StoryPhase.groupPrivateClue) _startDossier();
  }

  void _startDiscussion() {
    _timer = Timer.periodic(StoryTokens.timerTick, (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        timer.cancel();
        _setSession(_session.finishDiscussion());
      } else {
        setState(() => _seconds--);
      }
    });
  }

  /// The same count for every seat: a file hides after the same seconds,
  /// whoever holds it.
  void _startDossier() {
    _dossierTimer = Timer.periodic(StoryTokens.timerTick, (timer) {
      if (!mounted) return;
      if (_dossierLeft <= 1) {
        timer.cancel();
        setState(() => _dossierLeft = 0);
      } else {
        setState(() => _dossierLeft--);
      }
    });
  }

  Future<void> _openAccusation() async {
    final accusation = await showMafiaSheet<StoryAccusation>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: CaseFileTokens.desk,
      builder: (context) => _AccusationSheet(story: widget.story),
    );
    if (accusation == null || !mounted) return;
    _setSession(_session.submitSoloAccusation(accusation));
  }

  bool _correct(StoryAccusation value) =>
      value.culprit == widget.story.truth.primaryCulprit &&
      value.motive == widget.story.truth.motive &&
      value.method == widget.story.truth.method;

  bool _isSolved() {
    final solo = _session.soloAccusation;
    if (solo != null) return _correct(solo);
    final correctVotes = _session.votes.where(_correct).length;
    return correctVotes * 2 >= widget.playerCount;
  }

  Future<void> _complete() async {
    await widget.onComplete(
      StoryCompletion(
        story: widget.story,
        score: _session.score?.total ?? 0,
        solved: _isSolved(),
      ),
    );
  }

  Future<void> _completeAndHome() async {
    final home = widget.onHome;
    await _complete();
    home?.call();
  }

  @override
  Widget build(BuildContext context) => WarmPalette(
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_privatePhase) widget.onExit();
      },
      child: AnimatedSwitcher(
        // A private page leaves at once: nothing of a file or a ballot
        // lingers while the next screen fades in.
        duration: _privatePhase ? Duration.zero : context.motion.standard,
        reverseDuration: Duration.zero,
        child: _phase(context),
      ),
    ),
  );

  Widget _phase(BuildContext context) => switch (_session.phase) {
    StoryPhase.soloInvestigation => _solo(context),
    StoryPhase.groupHandoff =>
      _dealt ? _handoff(context, vote: false) : _cast(context),
    StoryPhase.groupPrivateClue => _privateClue(context),
    StoryPhase.groupDiscussion => _discussion(context),
    StoryPhase.groupInvestigation => _sharedInvestigation(context),
    StoryPhase.groupVoteHandoff => _handoff(context, vote: true),
    StoryPhase.groupVote => _vote(context),
    StoryPhase.reenactment => _reenactment(context),
    StoryPhase.complete => _result(context),
  };

  String? get _narration =>
      widget.playNarration == null ? null : widget.story.narrationAudio;
  bool _narrated = false;

  void _listen() {
    final asset = _narration;
    if (asset != null) widget.playNarration!(asset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The opening is read once, as the case is opened.
    if (_narrated || _narration == null) return;
    _narrated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listen();
    });
  }

  int _bonusSteps = 0;
  bool _watchingAd = false;

  /// The cost of one more step, when an ad may pay for it: the player can
  /// no longer afford any open step and has bonus steps left.
  int? get _bonusOffer {
    if (widget.watchAdForStep == null) return null;
    if (_bonusSteps >= StoryTokens.bonusSteps) return null;
    final cost = _session.cheapestOpenCost;
    if (cost == null || _session.remainingBudget >= cost) return null;
    return cost - _session.remainingBudget;
  }

  Future<void> _watchForStep(int cost) async {
    setState(() => _watchingAd = true);
    final watched = await widget.watchAdForStep!();
    if (!mounted) return;
    setState(() {
      _watchingAd = false;
      if (watched) {
        _bonusSteps++;
        _session = _session.grantExtraBudget(cost);
      }
    });
  }

  Widget _narratorBar(
    BuildContext context, {
    required String title,
    required String playingText,
    required bool startsPlaying,
  }) {
    final l = context.l10n;
    return StoryNarratorBar(
      title: title,
      playingText: playingText,
      idleText: l.storiesNarratorIdle,
      stopTooltip: l.storiesNarratorStop,
      playTooltip: title,
      startsPlaying: startsPlaying,
      onPlay: _listen,
      onStop: widget.stopNarration,
    );
  }

  Widget _notes(BuildContext context) {
    final s = context.spacing;
    final type = context.typography;
    final clues = _session.revealedClues.reversed.toList();
    if (clues.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.sm),
        child: Text(
          context.l10n.storiesFoundEmpty,
          style: type.bodySmall.copyWith(color: CaseFileTokens.inkMuted),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: EdgeInsets.only(top: s.sm, bottom: s.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, clue) in clues.indexed) ...[
            StoryPinned(
              key: ValueKey(clue.id),
              delay: StoryTokens.noteStagger * (i < 2 ? i : 0),
              child: StoryNote(
                title: clue.title,
                body: clue.body,
                width: StoryTokens.noteWidth,
                turn: i.isEven ? -0.03 : 0.04,
              ),
            ),
            SizedBox(width: s.md),
          ],
        ],
      ),
    );
  }

  Widget _solo(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final story = widget.story;
    final total = story.actionBudget > _session.remainingBudget
        ? story.actionBudget
        : _session.remainingBudget;
    return StoryDesk(
      key: StoryFlowScreen.soloBoardKey,
      title: story.title,
      onBack: widget.onExit,
      footer: BoneButton(
        key: StoryFlowScreen.accusationButtonKey,
        label: l.storiesIKnowWho,
        onPressed: _openAccusation,
      ),
      body: StoryScroll(
        children: [
          CaseFilePaper(
            padding: EdgeInsets.all(s.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_narration != null) ...[
                  _narratorBar(
                    context,
                    title: l.storiesNarratorTitle,
                    playingText: l.storiesNarratorPlaying,
                    startsPlaying: true,
                  ),
                  SizedBox(height: s.sm),
                  Divider(
                    height: 1,
                    color: DeckTokens.bone.withValues(
                      alpha: StoryTokens.dashAlpha,
                    ),
                  ),
                  SizedBox(height: s.sm),
                ],
                Text(
                  story.synopsis,
                  style: type.bodySmall.copyWith(color: DeckTokens.text2),
                ),
                if (story.evidenceImage case final image?) ...[
                  SizedBox(height: s.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(context.radii.card),
                    child: Image.asset(
                      image,
                      height: StoryTokens.compactCoverHeight,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: s.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l.storiesMoves}: ${l.storiesMovesOf(_session.remainingBudget, total)}',
                  style: type.bodySmall.copyWith(
                    color: CaseFileTokens.inkMuted,
                  ),
                ),
              ),
              StoryPips(total: total, left: _session.remainingBudget),
            ],
          ),
          SizedBox(height: s.sm),
          Text(
            l.storiesFound,
            style: type.bodySmall.copyWith(color: CaseFileTokens.inkMuted),
          ),
          _notes(context),
          Text(
            l.storiesWhereTo,
            style: type.bodySmall.copyWith(color: CaseFileTokens.inkMuted),
          ),
          SizedBox(height: s.sm),
          for (final action in story.actions) ...[
            StoryMoveCard(
              title: action.title,
              description: action.description,
              cost: action.cost,
              unit: l.storiesMoveUnit,
              enabled: _session.canPerform(action),
              done: _session.usedActionIds.contains(action.id),
              onPressed: () =>
                  _setSession(_session.performSoloAction(action.id)),
            ),
            SizedBox(height: s.sm),
          ],
          if (_bonusOffer case final cost?)
            OutlinedButton.icon(
              key: StoryFlowScreen.bonusStepKey,
              onPressed: _watchingAd ? null : () => _watchForStep(cost),
              icon: const Icon(Icons.ondemand_video_rounded),
              label: Text(l.storiesBonusStep),
            ),
        ],
      ),
    );
  }

  // ---- With friends -------------------------------------------------

  /// The case and who is playing; nobody has a file yet.
  Widget _cast(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final story = widget.story;
    return StoryDesk(
      key: StoryFlowScreen.castKey,
      onBack: widget.onExit,
      footer: BoneButton(
        key: StoryFlowScreen.dealKey,
        label: l.storiesDealFiles,
        onPressed: () => setState(() => _dealt = true),
      ),
      body: StoryScroll(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(CaseFileTokens.radius),
            child: SizedBox(
              height: StoryTokens.heroHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    story.coverImage,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: StoryTokens.photoShade),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [StoryTokens.transparentColor, CaseFileTokens.desk],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    bottom: s.sm,
                    start: s.md,
                    end: s.md,
                    child: Text(
                      story.title,
                      style: StoryTokens.ruqaa(
                        type.headline,
                      ).copyWith(color: CaseFileTokens.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: s.sm),
          Text(
            story.synopsis,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: type.bodySmall.copyWith(color: DeckTokens.text2),
          ),
          SizedBox(height: s.md),
          Text(
            l.storiesCastTitle(widget.playerCount),
            style: type.bodySmall.copyWith(color: CaseFileTokens.inkMuted),
          ),
          SizedBox(height: s.sm),
          for (var i = 0; i < widget.playerCount; i++) ...[
            CaseFilePaper(
              padding: EdgeInsets.all(s.sm),
              child: Row(
                children: [
                  Container(
                    width: StoryTokens.castPhotoWidth,
                    height: StoryTokens.castPhotoHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: DeckTokens.silver,
                        width: StoryTokens.dossierDash,
                      ),
                      borderRadius: BorderRadius.circular(
                        CaseFileTokens.stampRadius,
                      ),
                    ),
                    child: const Icon(
                      Icons.question_mark_rounded,
                      color: CaseFileTokens.inkMuted,
                    ),
                  ),
                  SizedBox(width: s.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l.storiesPlayer} ${i + 1}',
                          style: type.body.copyWith(
                            color: CaseFileTokens.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l.storiesCastRole,
                          style: type.caption.copyWith(
                            color: CaseFileTokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: s.sm),
          ],
        ],
      ),
    );
  }

  Widget _handoff(BuildContext context, {required bool vote}) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final seat = _session.currentPlayer + 1;
    final line = vote
        ? l.storiesVoteLine(seat, widget.playerCount)
        : _session.round == 1
        ? l.storiesDealLine(seat, widget.playerCount)
        : '${l.storiesRound} ${_session.round} · $seat/${widget.playerCount}';
    return StoryDesk(
      key: StoryFlowScreen.handoffKey,
      body: Column(
        children: [
          Container(
            height: DeckTokens.primaryHeight,
            alignment: Alignment.center,
            child: Text(
              line,
              style: type.bodySmall.copyWith(color: DeckTokens.text2),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(s.screenMargin),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vote ? l.storiesSecretVotePass : l.storiesThisFileFor,
                      textAlign: TextAlign.center,
                      style: type.body.copyWith(color: DeckTokens.text2),
                    ),
                    Text(
                      '${l.storiesPlayer} $seat',
                      textAlign: TextAlign.center,
                      style: StoryTokens.ruqaa(type.display).copyWith(
                        color: CaseFileTokens.ink,
                        fontSize: StoryTokens.passName,
                      ),
                    ),
                    Text(
                      l.storiesOthersLookAway,
                      textAlign: TextAlign.center,
                      style: type.caption.copyWith(
                        color: CaseFileTokens.inkMuted,
                      ),
                    ),
                    SizedBox(height: s.xl),
                    HoldPad(
                      holdDuration: StoryTokens.privateHold,
                      instruction: l.storiesHoldToReveal,
                      onHoldComplete: () => _setSession(
                        vote
                            ? _session.revealVoteCard()
                            : _session.revealPrivateCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The private file. Built from the same pieces, in the same order and
  /// with the same timing, for every seat; nothing in it asks who holds it.
  Widget _privateClue(BuildContext context) {
    final character = _session.currentCharacter;
    final clues = [
      for (var i = 0; i < _session.round; i++)
        widget.story.clue(character.privateClueIds[i]),
    ];
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    return StoryDesk(
      key: StoryFlowScreen.privateCardKey,
      title: l.storiesYourFile,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoneButton(
            key: StoryFlowScreen.hideFileKey,
            label: l.storiesCoverAndPass2,
            onPressed: _dossierLeft == 0
                ? () => _setSession(_session.coverPrivateCard())
                : null,
          ),
          SizedBox(height: s.xs),
          SizedBox(
            height: type.caption.fontSize! * 1.6,
            child: Text(
              _dossierLeft == 0 ? '' : l.storiesHideIn(_dossierLeft),
              textAlign: TextAlign.center,
              style: type.caption.copyWith(color: CaseFileTokens.inkMuted),
            ),
          ),
        ],
      ),
      body: StoryScroll(
        children: [
          StoryDossier(
            character: character,
            clues: clues,
            youAre: l.storiesYouAre,
            mustDo: l.storiesMustDo,
          ),
          SizedBox(height: s.sm),
          Text(
            l.storiesMemorise,
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: CaseFileTokens.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _lineup(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final seated = widget.story.characters.take(widget.playerCount).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, c) in seated.indexed) ...[
            SizedBox(
              width: StoryTokens.lineupWidth,
              child: Column(
                children: [
                  StoryPhoto(
                    image: c.image,
                    width: StoryTokens.lineupWidth,
                    height: StoryTokens.lineupHeight,
                    focusTop: true,
                  ),
                  SizedBox(height: s.xs),
                  Text(
                    c.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.caption.copyWith(color: CaseFileTokens.ink),
                  ),
                  Text(
                    '${l.storiesPlayer} ${i + 1}',
                    style: type.caption.copyWith(
                      color: CaseFileTokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: s.sm),
          ],
        ],
      ),
    );
  }

  Widget _discussion(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final minutes = _seconds ~/ 60;
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    final total = widget.story.discussionSeconds;
    return StoryDesk(
      key: StoryFlowScreen.discussionKey,
      title: '${l.storiesDiscussionLine} · ${l.storiesRound} ${_session.round} / ${StoryTokens.rounds}',
      onBack: widget.onExit,
      footer: BoneButton(
        label: l.storiesSearchTogether,
        onPressed: () => _setSession(_session.finishDiscussion()),
      ),
      body: StoryScroll(
        children: [
          Center(
            child: StoryTimerRing(
              fraction: total == 0 ? 0 : _seconds / total,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$minutes:$seconds',
                    style: type.timer.copyWith(color: CaseFileTokens.ink),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: s.lg),
                    child: Text(
                      l.storiesDiscussionHint,
                      textAlign: TextAlign.center,
                      style: type.caption.copyWith(
                        color: CaseFileTokens.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_narration != null) ...[
            SizedBox(height: s.md),
            CaseFilePaper(
              padding: EdgeInsets.all(s.sm),
              child: _narratorBar(
                context,
                title: l.storiesHearAgain,
                playingText: l.storiesNarratorTable,
                startsPlaying: false,
              ),
            ),
          ],
          SizedBox(height: s.md),
          Text(
            l.storiesCastOnTable,
            style: type.bodySmall.copyWith(color: CaseFileTokens.inkMuted),
          ),
          SizedBox(height: s.sm),
          _lineup(context),
        ],
      ),
    );
  }

  Widget _sharedInvestigation(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final left = StoryTokens.rounds - (_session.round - 1);
    final turn = (_session.round - 1) % widget.playerCount + 1;
    final actions = widget.story.actions.where(
      (action) => !_session.usedActionIds.contains(action.id),
    );
    return StoryDesk(
      key: StoryFlowScreen.investigationKey,
      title: l.storiesSearchLine,
      onBack: widget.onExit,
      body: StoryScroll(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l.storiesTableMoves}: ${l.storiesMovesOf(left, StoryTokens.rounds)}',
                  style: type.bodySmall.copyWith(
                    color: CaseFileTokens.inkMuted,
                  ),
                ),
              ),
              StoryPips(total: StoryTokens.rounds, left: left),
            ],
          ),
          SizedBox(height: s.sm),
          Text(
            l.storiesTurnOf('${l.storiesPlayer} $turn'),
            textAlign: TextAlign.center,
            style: type.bodySmall.copyWith(color: DeckTokens.text2),
          ),
          SizedBox(height: s.sm),
          Text(
            l.storiesFound,
            style: type.bodySmall.copyWith(color: CaseFileTokens.inkMuted),
          ),
          _notes(context),
          for (final action in actions) ...[
            StoryMoveCard(
              title: action.title,
              description: action.description,
              cost: null,
              unit: l.storiesMoveUnit,
              enabled: true,
              done: false,
              onPressed: () =>
                  _setSession(_session.pickSharedInvestigation(action.id)),
            ),
            SizedBox(height: s.sm),
          ],
        ],
      ),
    );
  }

  /// The secret ballot: the same three questions, then a held press.
  Widget _vote(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final ready = _bCulprit != null && _bMotive != null && _bMethod != null;
    return StoryDesk(
      key: StoryFlowScreen.voteKey,
      title: l.storiesVoteLine(_session.currentPlayer + 1, widget.playerCount),
      footer: StoryHoldButton(
        label: l.storiesHoldConfirm,
        doneLabel: l.storiesVoteRecorded,
        duration: StoryTokens.ballotHold,
        enabled: ready,
        onConfirmed: () => _setSession(
          _session.submitSecretVote(
            StoryAccusation(
              culprit: _bCulprit!,
              motive: _bMotive!,
              method: _bMethod!,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          s.screenMargin,
          s.sm,
          s.screenMargin,
          s.md,
        ),
        children: [
          StoryAccusationForm(
            story: widget.story,
            culprit: _bCulprit,
            motive: _bMotive,
            method: _bMethod,
            questionWho: l.storiesQWho,
            questionWhy: l.storiesQWhy,
            questionHow: l.storiesQHow,
            onCulprit: (v) => setState(() => _bCulprit = v),
            onMotive: (v) => setState(() => _bMotive = v),
            onMethod: (v) => setState(() => _bMethod = v),
          ),
        ],
      ),
    );
  }

  Widget _reenactment(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final beats = widget.story.truth.timeline;
    final last = _reenactmentStep == beats.length - 1;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return StoryDesk(
      key: StoryFlowScreen.reenactmentKey,
      title: _group ? l.storiesWhatHappened : l.storiesReenactment,
      footer: BoneButton(
        label: last
            ? (_group ? l.storiesWhoKnew : l.storiesFinishReveal)
            : l.storiesNextBeat,
        onPressed: () {
          if (last) {
            _setSession(_session.finishReenactment());
          } else {
            setState(() => _reenactmentStep++);
          }
        },
      ),
      body: StoryScroll(
        children: [
          if (_narration != null) ...[
            CaseFilePaper(
              padding: EdgeInsets.all(s.sm),
              child: _narratorBar(
                context,
                title: l.storiesNarratorActs,
                playingText: l.storiesNarratorTable,
                startsPlaying: false,
              ),
            ),
            SizedBox(height: s.md),
          ],
          Stack(
            children: [
              PositionedDirectional(
                start: StoryTokens.timelineDot / 2,
                top: s.xs,
                bottom: s.xs,
                child: Container(
                  width: StoryTokens.timelineLine,
                  color: DeckTokens.bone.withValues(
                    alpha: StoryTokens.dashAlpha,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, beat) in beats.indexed)
                    AnimatedOpacity(
                      key: ValueKey('story_beat_$i'),
                      opacity: i <= _reenactmentStep
                          ? 1
                          : StoryTokens.reenactDim,
                      duration: still ? Duration.zero : StoryTokens.reenactFade,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: StoryTokens.timelineGutter,
                          bottom: s.md,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            PositionedDirectional(
                              start: -StoryTokens.timelineGutter,
                              top: s.xs,
                              child: Container(
                                width: StoryTokens.timelineDot,
                                height: StoryTokens.timelineDot,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i <= _reenactmentStep
                                      ? DeckTokens.bone
                                      : CaseFileTokens.desk,
                                  border: Border.all(
                                    color: i <= _reenactmentStep
                                        ? DeckTokens.bone
                                        : DeckTokens.silverLight,
                                    width: StoryTokens.costStroke,
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  beat.time,
                                  style: type.bodySmall.copyWith(
                                    color: DeckTokens.bone,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  beat.text,
                                  style: type.bodySmall.copyWith(
                                    color: DeckTokens.text2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final story = widget.story;
    final solved = _isSolved();
    final score = _session.score?.total ?? 0;
    final culprit = story.character(story.truth.primaryCulprit);
    final motive = story.motives
        .firstWhere((v) => v.id == story.truth.motive)
        .label;
    final method = story.methods
        .firstWhere((v) => v.id == story.truth.method)
        .label;
    final votes = _session.votes;
    final knew = votes.where(_correct).length;
    return StoryDesk(
      key: StoryFlowScreen.resultKey,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoneButton(
            label: _group ? l.storiesAnotherCase : l.storiesBackToFiles,
            onPressed: _complete,
          ),
          SizedBox(height: s.sm),
          RimButton(label: l.storiesHome, onPressed: _completeAndHome),
        ],
      ),
      body: StoryScroll(
        children: [
          Text(
            story.title,
            textAlign: TextAlign.center,
            style: type.bodySmall.copyWith(color: CaseFileTokens.inkMuted),
          ),
          SizedBox(height: s.sm),
          Center(
            child: StoryStampLanding(
              text: solved ? l.storiesStampSolved : l.storiesStampMissed,
              detail: _group
                  ? l.storiesKnewCount(knew, widget.playerCount)
                  : l.storiesStampScore(score),
              color: solved ? CaseFileTokens.sage : CaseFileTokens.stamp,
            ),
          ),
          SizedBox(height: s.md),
          Text(
            solved ? l.storiesSolved : l.storiesMissed,
            textAlign: TextAlign.center,
            style: StoryTokens.ruqaa(
              type.headline,
            ).copyWith(color: CaseFileTokens.ink),
          ),
          SizedBox(height: s.xs),
          Text(
            '${l.storiesScore}: $score',
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: DeckTokens.text2),
          ),
          SizedBox(height: s.md),
          if (_group) ..._seatRows(context, culprit.id),
          CaseFilePaper(
            padding: EdgeInsets.all(s.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StoryPhoto(
                  image: culprit.image,
                  width: StoryTokens.castPhotoWidth * 1.5,
                  height: StoryTokens.castPhotoHeight * 1.5,
                  focusTop: true,
                ),
                SizedBox(width: s.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l.storiesCulprit}: ${culprit.name}',
                        style: StoryTokens.ruqaa(
                          type.title,
                        ).copyWith(color: CaseFileTokens.ink),
                      ),
                      SizedBox(height: s.xs),
                      Text(
                        '${l.storiesMotive}: $motive\n'
                        '${l.storiesMethod}: $method',
                        style: type.bodySmall.copyWith(color: DeckTokens.text2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Who knew, and whether the one who did it hid well. Only facts the
  /// votes hold: nobody is starred unless a seat really played the culprit.
  List<Widget> _seatRows(BuildContext context, String culpritId) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final votes = _session.votes;
    final seated = widget.story.characters.take(widget.playerCount).toList();
    final culpritSeat = seated.indexWhere((c) => c.id == culpritId);
    var hidFrom = 0;
    for (var i = 0; i < votes.length; i++) {
      if (i != culpritSeat && votes[i].culprit != culpritId) hidFrom++;
    }
    return [
      for (final (i, c) in seated.indexed) ...[
        CaseFilePaper(
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.storiesPlayer} ${i + 1}',
                      style: type.body.copyWith(
                        color: CaseFileTokens.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      c.name,
                      style: type.caption.copyWith(
                        color: CaseFileTokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (i == culpritSeat && hidFrom > 0)
                const Icon(
                  Icons.star_rounded,
                  color: DeckTokens.bone,
                ),
              if (i == culpritSeat)
                Text(
                  hidFrom > 0 ? l.storiesHidWell : l.storiesGotCaught,
                  style: type.bodySmall.copyWith(
                    color: hidFrom > 0
                        ? DeckTokens.bone
                        : CaseFileTokens.inkMuted,
                  ),
                )
              else if (i < votes.length && _correct(votes[i]))
                Text(
                  l.storiesKnew,
                  style: type.bodySmall.copyWith(
                    color: CaseFileTokens.sage,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  l.storiesConfused,
                  style: type.bodySmall.copyWith(
                    color: CaseFileTokens.inkMuted,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: s.sm),
      ],
      if (culpritSeat >= 0)
        Padding(
          padding: EdgeInsets.only(bottom: s.md),
          child: Text(
            l.storiesCulpritHid(seated[culpritSeat].name, hidFrom),
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: CaseFileTokens.inkMuted),
          ),
        ),
    ];
  }
}

/// The solo accusation: three Ruqaa questions and «اقفل القضية».
class _AccusationSheet extends StatefulWidget {
  const _AccusationSheet({required this.story});

  final StoryDefinition story;

  @override
  State<_AccusationSheet> createState() => _AccusationSheetState();
}

class _AccusationSheetState extends State<_AccusationSheet> {
  String? culprit;
  String? motive;
  String? method;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l = context.l10n;
    final ready = culprit != null && motive != null && method != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.screenMargin,
              spacing.md,
              spacing.screenMargin,
              spacing.sm,
            ),
            child: Text(
              l.storiesAccuse,
              style: StoryTokens.ruqaa(
                context.typography.headline,
              ).copyWith(color: CaseFileTokens.ink),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: spacing.screenMargin),
              child: StoryAccusationForm(
                story: widget.story,
                culprit: culprit,
                motive: motive,
                method: method,
                questionWho: l.storiesQWho,
                questionWhy: l.storiesQWhy,
                questionHow: l.storiesQHow,
                onCulprit: (v) => setState(() => culprit = v),
                onMotive: (v) => setState(() => motive = v),
                onMethod: (v) => setState(() => method = v),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.screenMargin,
              spacing.sm,
              spacing.screenMargin,
              spacing.md,
            ),
            child: BoneButton(
              key: StoryFlowScreen.closeCaseKey,
              label: l.storiesCloseCase,
              onPressed: ready
                  ? () => Navigator.pop(
                      context,
                      StoryAccusation(
                        culprit: culprit!,
                        motive: motive!,
                        method: method!,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
