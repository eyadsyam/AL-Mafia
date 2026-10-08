import 'dart:async';

import 'package:flutter/material.dart';

import '../../../stories/story_model.dart';
import '../../../stories/story_session.dart';
import '../../l10n_ext.dart';
import '../../widgets/reveal_motion.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/experience_surface.dart';
import '../../widgets/hold_pad.dart';

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
    this.watchAdForStep,
  });

  /// Shows a rewarded ad; true when it was watched to the end. Absent in
  /// tests and builds without ads. At most [StoryTokens.bonusSteps] a case.
  final Future<bool> Function()? watchAdForStep;

  static const soloBoardKey = ValueKey('story_solo_board');
  static const bonusStepKey = ValueKey('story_bonus_step');
  static const handoffKey = ValueKey('story_group_handoff');
  static const privateCardKey = ValueKey('story_private_card');
  static const discussionKey = ValueKey('story_discussion');
  static const investigationKey = ValueKey('story_investigation');
  static const voteKey = ValueKey('story_vote');
  static const reenactmentKey = ValueKey('story_reenactment');
  static const resultKey = ValueKey('story_result');
  static const accusationButtonKey = ValueKey('story_accuse');

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
  int _seconds = 0;
  int _reenactmentStep = 0;

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
    super.dispose();
  }

  void _setSession(StorySession next) {
    _timer?.cancel();
    if (next.phase == StoryPhase.groupDiscussion) {
      _seconds = widget.story.discussionSeconds;
    }
    setState(() => _session = next);
    if (next.phase == StoryPhase.groupDiscussion) _startDiscussion();
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

  Future<void> _openAccusation({required bool vote}) async {
    final accusation = await showModalBottomSheet<StoryAccusation>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _AccusationSheet(story: widget.story, vote: vote),
    );
    if (accusation == null || !mounted) return;
    _setSession(
      vote
          ? _session.submitSecretVote(accusation)
          : _session.submitSoloAccusation(accusation),
    );
  }

  bool _isSolved() {
    bool correct(StoryAccusation value) =>
        value.culprit == widget.story.truth.primaryCulprit &&
        value.motive == widget.story.truth.motive &&
        value.method == widget.story.truth.method;
    final solo = _session.soloAccusation;
    if (solo != null) return correct(solo);
    final correctVotes = _session.votes.where(correct).length;
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_privatePhase) widget.onExit();
    },
    child: Scaffold(
      backgroundColor: context.colors.surfaceBase,
      body: ExperienceSurface(
        image: widget.story.sceneImage,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: context.motion.standard,
            child: _phase(context),
          ),
        ),
      ),
    ),
  );

  Widget _phase(BuildContext context) => switch (_session.phase) {
    StoryPhase.soloInvestigation => _solo(context),
    StoryPhase.groupHandoff => _handoff(context, vote: false),
    StoryPhase.groupPrivateClue => _privateClue(context),
    StoryPhase.groupDiscussion => _discussion(context),
    StoryPhase.groupInvestigation => _sharedInvestigation(context),
    StoryPhase.groupVoteHandoff => _handoff(context, vote: true),
    StoryPhase.groupVote => _vote(context),
    StoryPhase.reenactment => _reenactment(context),
    StoryPhase.complete => _result(context),
  };

  Widget _shell({required Key key, required List<Widget> children}) {
    final spacing = context.spacing;
    return ListView(
      key: key,
      padding: EdgeInsets.all(spacing.screenMargin),
      children: [
        if (!_privatePhase)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BackAction(onPressed: widget.onExit),
          ),
        if (!_privatePhase) SizedBox(height: spacing.md),
        ...children,
      ],
    );
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

  Widget _solo(BuildContext context) {
    final l = context.l10n;
    final spacing = context.spacing;
    return _shell(
      key: StoryFlowScreen.soloBoardKey,
      children: [
        _StoryHeading(story: widget.story),
        SizedBox(height: spacing.md),
        _StatusLine(
          label: l.storiesActionsLeft,
          value: '${_session.remainingBudget}',
        ),
        SizedBox(height: spacing.md),
        for (final action in widget.story.actions) ...[
          _ActionCard(
            action: action,
            enabled: _session.canPerform(action),
            onPressed: () => _setSession(_session.performSoloAction(action.id)),
          ),
          SizedBox(height: spacing.sm),
        ],
        if (_bonusOffer case final cost?)
          OutlinedButton.icon(
            key: StoryFlowScreen.bonusStepKey,
            onPressed: _watchingAd ? null : () => _watchForStep(cost),
            icon: const Icon(Icons.ondemand_video_rounded),
            label: Text(l.storiesBonusStep),
          ),
        SizedBox(height: spacing.md),
        _ClueBoard(clues: _session.revealedClues),
        SizedBox(height: spacing.lg),
        FilledButton(
          key: StoryFlowScreen.accusationButtonKey,
          onPressed: () => _openAccusation(vote: false),
          child: Text(l.storiesAccuse),
        ),
      ],
    );
  }

  Widget _handoff(BuildContext context, {required bool vote}) {
    final l = context.l10n;
    final spacing = context.spacing;
    return _shell(
      key: StoryFlowScreen.handoffKey,
      children: [
        SizedBox(height: spacing.xl),
        Text(
          vote ? l.storiesVoteHandoff : '${l.storiesRound} ${_session.round}',
          textAlign: TextAlign.center,
          style: context.typography.headline,
        ),
        SizedBox(height: spacing.sm),
        Text(
          '${l.storiesPlayer} ${_session.currentPlayer + 1}',
          textAlign: TextAlign.center,
          style: context.typography.title,
        ),
        SizedBox(height: spacing.xl),
        HoldPad(
          holdDuration: StoryTokens.privateHold,
          instruction: l.storiesHoldToReveal,
          onHoldComplete: () => _setSession(
            vote ? _session.revealVoteCard() : _session.revealPrivateCard(),
          ),
        ),
      ],
    );
  }

  Widget _privateClue(BuildContext context) {
    final character = _session.currentCharacter;
    final clue = _session.currentPrivateClue;
    final involved = _session.playerCount >= 6
        ? widget.story.truth.involvedCharacters.contains(character.id)
        : character.id == widget.story.truth.primaryCulprit;
    final l = context.l10n;
    final spacing = context.spacing;
    final colors = context.colors;
    return _shell(
      key: StoryFlowScreen.privateCardKey,
      children: [
        Center(
          child: ClipOval(
            child: Image.asset(
              character.image,
              width: StoryTokens.portrait,
              height: StoryTokens.portrait,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: spacing.md),
        Text(
          character.name,
          textAlign: TextAlign.center,
          style: context.typography.headline,
        ),
        SizedBox(height: spacing.xs),
        Text(
          involved ? l.storiesInvolved : l.storiesNotInvolved,
          textAlign: TextAlign.center,
          style: context.typography.title.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: spacing.md),
        _PrivateBlock(
          title: l.storiesPersonalObjective,
          body: character.objective,
        ),
        SizedBox(height: spacing.sm),
        _PrivateBlock(
          title: '${l.storiesPrivateClue}: ${clue.title}',
          body: clue.body,
        ),
        SizedBox(height: spacing.lg),
        FilledButton(
          onPressed: () => _setSession(_session.coverPrivateCard()),
          child: Text(l.storiesCoverAndPass),
        ),
      ],
    );
  }

  Widget _discussion(BuildContext context) {
    final spacing = context.spacing;
    final minutes = _seconds ~/ 60;
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return _shell(
      key: StoryFlowScreen.discussionKey,
      children: [
        SizedBox(height: spacing.xl),
        Text(
          '${context.l10n.storiesRound} ${_session.round} / ${StoryTokens.rounds}',
          textAlign: TextAlign.center,
          style: context.typography.title,
        ),
        SizedBox(height: spacing.md),
        Text(
          context.l10n.storiesDiscussion,
          textAlign: TextAlign.center,
          style: context.typography.headline,
        ),
        SizedBox(height: spacing.lg),
        Center(
          child: SizedBox(
            width: StoryTokens.timerDiameter,
            height: StoryTokens.timerDiameter,
            child: Center(
              child: Text('$minutes:$seconds', style: context.typography.timer),
            ),
          ),
        ),
        SizedBox(height: spacing.lg),
        FilledButton(
          onPressed: () => _setSession(_session.finishDiscussion()),
          child: Text(context.l10n.storiesEndDiscussion),
        ),
      ],
    );
  }

  Widget _sharedInvestigation(BuildContext context) {
    final spacing = context.spacing;
    final actions = widget.story.actions.where(
      (action) => !_session.usedActionIds.contains(action.id),
    );
    return _shell(
      key: StoryFlowScreen.investigationKey,
      children: [
        Text(
          context.l10n.storiesSharedPick,
          style: context.typography.headline,
        ),
        SizedBox(height: spacing.md),
        for (final action in actions) ...[
          _ActionCard(
            action: action,
            enabled: true,
            onPressed: () =>
                _setSession(_session.pickSharedInvestigation(action.id)),
          ),
          SizedBox(height: spacing.sm),
        ],
        SizedBox(height: spacing.md),
        _ClueBoard(clues: _session.revealedClues),
      ],
    );
  }

  Widget _vote(BuildContext context) => _shell(
    key: StoryFlowScreen.voteKey,
    children: [
      SizedBox(height: context.spacing.xl),
      Text(
        '${context.l10n.storiesPlayer} ${_session.currentPlayer + 1}',
        textAlign: TextAlign.center,
        style: context.typography.headline,
      ),
      SizedBox(height: context.spacing.lg),
      FilledButton(
        onPressed: () => _openAccusation(vote: true),
        child: Text(context.l10n.storiesVote),
      ),
    ],
  );

  Widget _reenactment(BuildContext context) {
    final beats = widget.story.truth.timeline;
    final beat = beats[_reenactmentStep];
    final last = _reenactmentStep == beats.length - 1;
    final spacing = context.spacing;
    return _shell(
      key: StoryFlowScreen.reenactmentKey,
      children: [
        Text(
          context.l10n.storiesReenactment,
          textAlign: TextAlign.center,
          style: context.typography.headline,
        ),
        SizedBox(height: spacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.card),
          child: Image.asset(
            widget.story.coverImage,
            height: StoryTokens.coverHeight,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: spacing.lg),
        AnimatedSwitcher(
          duration: StoryTokens.reenactmentBeat,
          child: _TimelineBeat(key: ValueKey(_reenactmentStep), beat: beat),
        ),
        SizedBox(height: spacing.lg),
        FilledButton(
          onPressed: () {
            if (last) {
              _setSession(_session.finishReenactment());
            } else {
              setState(() => _reenactmentStep++);
            }
          },
          child: Text(
            last
                ? context.l10n.storiesFinishReveal
                : context.l10n.storiesNextBeat,
          ),
        ),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final solved = _isSolved();
    final spacing = context.spacing;
    return _shell(
      key: StoryFlowScreen.resultKey,
      children: [
        SizedBox(height: spacing.xl),
        Text(
          solved ? context.l10n.storiesSolved : context.l10n.storiesMissed,
          textAlign: TextAlign.center,
          style: context.typography.headline,
        ),
        SizedBox(height: spacing.md),
        Text(
          '${context.l10n.storiesScore}: ${_session.score?.total ?? 0}',
          textAlign: TextAlign.center,
          style: context.typography.title,
        ),
        SizedBox(height: spacing.lg),
        _TruthSummary(story: widget.story),
        SizedBox(height: spacing.lg),
        FilledButton(
          onPressed: _complete,
          child: Text(context.l10n.storiesBackToFiles),
        ),
      ],
    );
  }
}

class _StoryHeading extends StatelessWidget {
  const _StoryHeading({required this.story});

  final StoryDefinition story;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(story.title, style: context.typography.headline),
      SizedBox(height: context.spacing.xs),
      Text(story.synopsis, style: context.typography.body),
      if (story.evidenceImage case final image?) ...[
        SizedBox(height: context.spacing.sm),
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
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: context.typography.body),
      Text(value, style: context.typography.title),
    ],
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.enabled,
    required this.onPressed,
  });

  final StoryInvestigationAction action;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surfaceRaised,
    borderRadius: BorderRadius.circular(context.radii.card),
    child: Padding(
      padding: EdgeInsets.all(context.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(action.title, style: context.typography.title),
          SizedBox(height: context.spacing.xs),
          Text(action.description, style: context.typography.bodySmall),
          SizedBox(height: context.spacing.sm),
          OutlinedButton(
            onPressed: enabled ? onPressed : null,
            child: Text('${context.l10n.storiesInvestigate} — ${action.cost}'),
          ),
        ],
      ),
    ),
  );
}

class _ClueBoard extends StatelessWidget {
  const _ClueBoard({required this.clues});

  final List<StoryClue> clues;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.storiesClues, style: context.typography.title),
        SizedBox(height: spacing.sm),
        if (clues.isEmpty)
          Text(context.l10n.storiesNoClues, style: context.typography.bodySmall)
        else
          for (final clue in clues) ...[
            FlipIn(
              key: ValueKey(clue.id),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: StoryTokens.clueMinHeight,
                ),
                padding: EdgeInsets.all(spacing.md),
                decoration: BoxDecoration(
                  color: context.colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(context.radii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clue.title, style: context.typography.title),
                    SizedBox(height: spacing.xs),
                    Text(clue.body, style: context.typography.bodySmall),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.sm),
          ],
      ],
    );
  }
}

class _PrivateBlock extends StatelessWidget {
  const _PrivateBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(context.spacing.md),
    decoration: BoxDecoration(
      color: context.colors.surfaceRaised,
      borderRadius: BorderRadius.circular(context.radii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.typography.title),
        SizedBox(height: context.spacing.xs),
        Text(body, style: context.typography.body),
      ],
    ),
  );
}

class _TimelineBeat extends StatelessWidget {
  const _TimelineBeat({super.key, required this.beat});

  final StoryTimelineBeat beat;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(context.spacing.md),
    decoration: BoxDecoration(
      color: context.colors.surfaceRaised,
      borderRadius: BorderRadius.circular(context.radii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(beat.time, style: context.typography.title),
        SizedBox(height: context.spacing.xs),
        Text(beat.text, style: context.typography.body),
      ],
    ),
  );
}

class _TruthSummary extends StatelessWidget {
  const _TruthSummary({required this.story});

  final StoryDefinition story;

  @override
  Widget build(BuildContext context) {
    final culprit = story.character(story.truth.primaryCulprit).name;
    final motive = story.motives
        .firstWhere((v) => v.id == story.truth.motive)
        .label;
    final method = story.methods
        .firstWhere((v) => v.id == story.truth.method)
        .label;
    return _PrivateBlock(
      title: '${context.l10n.storiesCulprit}: $culprit',
      body:
          '${context.l10n.storiesMotive}: $motive\n'
          '${context.l10n.storiesMethod}: $method',
    );
  }
}

class _AccusationSheet extends StatefulWidget {
  const _AccusationSheet({required this.story, required this.vote});

  final StoryDefinition story;
  final bool vote;

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
    final ready = culprit != null && motive != null && method != null;
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
          Text(
            widget.vote ? context.l10n.storiesVote : context.l10n.storiesAccuse,
            style: context.typography.headline,
          ),
          SizedBox(height: spacing.md),
          _Picker(
            label: context.l10n.storiesCulprit,
            value: culprit,
            values: [
              for (final value in widget.story.characters)
                StoryOption(id: value.id, label: value.name),
            ],
            onChanged: (value) => setState(() => culprit = value),
          ),
          SizedBox(height: spacing.sm),
          _Picker(
            label: context.l10n.storiesMotive,
            value: motive,
            values: widget.story.motives,
            onChanged: (value) => setState(() => motive = value),
          ),
          SizedBox(height: spacing.sm),
          _Picker(
            label: context.l10n.storiesMethod,
            value: method,
            values: widget.story.methods,
            onChanged: (value) => setState(() => method = value),
          ),
          SizedBox(height: spacing.lg),
          FilledButton(
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
            child: Text(context.l10n.storiesConfirmAccusation),
          ),
        ],
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<StoryOption> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    hint: Text(context.l10n.storiesChoose),
    items: [
      for (final option in values)
        DropdownMenuItem(value: option.id, child: Text(option.label)),
    ],
    onChanged: onChanged,
  );
}
