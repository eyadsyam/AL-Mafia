import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/enums.dart'
    show DayTieRule, GamePhase, PlayerStatus;
import '../../engine/models/player.dart' show PhaseRef;
import '../../engine/pressure.dart';
import '../../app/asset_constants.dart';
import '../../platform/audio_director.dart';
import '../../platform/narrator_bank.dart';
import '../../platform/review_prompt.dart';
import '../../transport/game_snapshot.dart' show ConnectionQuality;
import '../information_text.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import '../theme/design_tokens.dart';
import '../widgets/motion_sprite.dart';
import 'day/confrontation_screen.dart';
import 'day/discussion_screen.dart';
import 'day/opening_round_screen.dart';
import 'day/vote_result_screen.dart';
import 'day/voting_screen.dart';
import 'distribution/role_reveal_screen.dart';
import 'match_controller.dart';
import '../economy/interstitial_coordinator.dart';
import '../economy/pass_result_inventory.dart';
import '../economy/cosmetics.dart' show NarrationBeat;
import '../economy/my_cosmetics.dart';
import '../economy/pass_table_dress.dart';
import 'online/table/room_presentation.dart';
import 'online/online_session.dart';
import 'online/online_table_flow.dart';
import 'online/table/table_scene.dart' show tableIsAvailableFor;
import 'night/morning_screen.dart';
import 'night/night_action_screen.dart';
import 'postgame/result_screen.dart';
import '../../transport/local_transport.dart' show LocalTransport;
import '../fun/match_awards.dart' show localMatchAwards;
import 'setup/group_follow_up.dart';
import '../widgets/cinematic_text.dart';
import '../widgets/connection_banner.dart';
import '../widgets/phase_transition.dart';
import '../widgets/voice_controls.dart';
import '../widgets/victory_reveal.dart';
import 'online/voice_session.dart';

/// Drives a whole match from role distribution to the result screen.
///
/// ## Why the phase is the router
///
/// Every screen below is chosen from `GamePhase` — the engine's own state — and
/// never from local navigation history. That is deliberate: it means there is no
/// UI-side notion of "where we are" that could drift from the engine, and a match
/// rebuilt from storage lands on exactly the screen its persisted phase implies
/// (L-13). The only local state here is which *on-table* screen has been
/// acknowledged, which is not game state and does not need to survive a restart.
///
/// The transient `*Resolving` phases are never rendered. They are passed through
/// synchronously inside the callback that produced them, so a build never
/// observes the engine mid-resolution.
class MatchFlow extends ConsumerStatefulWidget {
  /// Leaves the match — the host confirmed an end, or the result was dismissed.
  final VoidCallback onExit;

  /// Opens post-game analytics for the finished match.
  final VoidCallback onAnalytics;

  final VoidCallback? onRematch;

  /// Called after every confirmed engine step, so the host can persist. Kept as
  /// a callback rather than a repository dependency so the flow stays testable
  /// without storage.
  final VoidCallback? onStepCommitted;

  const MatchFlow({
    super.key,
    required this.onExit,
    required this.onAnalytics,
    this.onRematch,
    this.onStepCommitted,
  });

  @override
  ConsumerState<MatchFlow> createState() => MatchFlowState();
}

/// The six full-screen announcements, and what each one sounds like.
///
/// One enum rather than six call sites so that "every phase transition has a
/// narrator slot" is a property of the type, not a convention somebody has to
/// remember at the seventh.
enum _Moment {
  morningDeath(
    AudioCue.morning,
    AppImages.outcomeDeath,
    AppVideo.outcomeDeathLoop,
    NarratorBeat.morning,
  ),
  morningQuiet(
    AudioCue.morning,
    AppImages.outcomeSaved,
    AppVideo.outcomeSavedLoop,
    NarratorBeat.morning,
  ),
  voting(null, AppImages.bgVote, AppVideo.bgVoteLoop, NarratorBeat.voting),

  /// F16: shown only when the narrator has a night line to speak, so the
  /// line plays on a flat phone before the first hand-off, never under it.
  night(null, AppImages.bgNight, AppVideo.bgNightLoop, NarratorBeat.night);

  const _Moment(this.cue, this.backdrop, this.loop, this.beat);

  /// The public beat a narrator pack marks for this moment (store truth).
  NarrationBeat get narration => switch (this) {
    _Moment.morningDeath || _Moment.morningQuiet => NarrationBeat.morning,
    _Moment.voting => NarrationBeat.voting,
    _Moment.night => NarrationBeat.night,
  };

  /// The narrator's beat for this moment (F16). The line plays over the words
  /// and the bed, on the table, and only if a pack is installed.
  final NarratorBeat? beat;

  /// The cue to fire as the words appear, or null for an announcement that has
  /// no sound yet. A recorded narrator line for the cue plays over its ambient
  /// bed; with neither, the line on screen carries the moment alone.
  final AudioCue? cue;

  /// The picture behind the words.
  ///
  /// Here rather than at the call site for the same reason the cue is: "every
  /// announcement has a backdrop" becomes a property of the type, and the
  /// seventh moment cannot be added without one. It is also the only place the
  /// six tier-3/4 paintings are chosen, so the mapping from moment to picture
  /// can be read in one glance and checked against the manifest.
  ///
  /// Safe because every one of these is on-table: the phone is flat, the words
  /// are for the room, and the picture is a function of the *phase*, never of
  /// a role. Nothing reachable while the phone is in a hand has a backdrop at
  /// all.
  final String backdrop;

  /// The ambient loop that plays instead of [backdrop] when motion is allowed.
  ///
  /// Paired in the same row precisely so the two cannot drift: a moment whose
  /// loop showed a different scene from its Reduce Motion still would be two
  /// announcements wearing one name.
  ///
  /// `morningDeath`/`morningQuiet` and `mafiaWins`/`townWins` run the same
  /// number of frames as each other — enforced in `tool/manifest.json` by
  /// `pair` and checked by `normalise_video.py`. An announcement that ran
  /// longer for one outcome than the other would tell the room the answer
  /// before the words arrived.
  final String loop;
}

class MatchFlowState extends ConsumerState<MatchFlow> {
  bool _victorySeen = false;

  /// The day whose morning briefing has been dismissed. On-table only.
  int? _morningAcknowledgedFor;

  /// The announcement currently on screen, if any. Not persisted: an
  /// interrupted match resumes on its phase's own screen, and replaying "night
  /// falls" to a table that has already been playing for an hour would be
  /// theatre at the expense of sense.
  _Moment? _moment;

  /// Runs after the current announcement finishes fading out.
  VoidCallback? _afterMoment;

  /// Shows [moment], then runs [then].
  ///
  /// The engine step goes in [then] rather than before the call, so the words
  /// are on screen while the game is still in its previous state. A night that
  /// began underneath its own announcement would put the first player's pass
  /// screen behind the text.
  void _announce(_Moment moment, VoidCallback then) {
    setState(() {
      _moment = moment;
      _afterMoment = then;
    });
  }

  void _momentFinished() {
    final next = _afterMoment;
    setState(() {
      _moment = null;
      _afterMoment = null;
    });
    next?.call();
  }

  String _momentLine(_Moment moment) {
    final l10n = context.l10n;
    return switch (moment) {
      _Moment.morningDeath => l10n.phaseMorningSomeoneDied,
      _Moment.morningQuiet => l10n.phaseMorningNobodyDied,
      _Moment.voting => l10n.phaseVoting,
      _Moment.night => l10n.phaseNightFalls,
    };
  }

  Widget _decorateMoment(_Moment moment, Widget child) {
    if (moment != _Moment.night) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const PositionedDirectional(
          end: MotionTokens.smokeInset,
          bottom: MotionTokens.smokeInset,
          child: IgnorePointer(
            child: MotionSprite(
              AppMotion.smokeWisp,
              width: MotionTokens.smokeWidth,
              height: MotionTokens.smokeHeight,
            ),
          ),
        ),
      ],
    );
  }

  MatchController get _controller => ref.read(matchControllerProvider.notifier);

  AudioDirector get _audio => ref.read(audioDirectorProvider);

  void _commit() => widget.onStepCommitted?.call();

  /// Phases during which the phone is in one player's hand.
  ///
  /// Kept as one list rather than being decided per screen, so a new in-hand
  /// phase cannot be added without deciding what it means for audio.
  static const _inHandPhases = {
    GamePhase.distributing,
    GamePhase.night,
    GamePhase.nightResolving,
    GamePhase.voting,
    GamePhase.voteResolving,
  };
  //
  // `openingRound` is deliberately absent, and it is the one entry worth
  // justifying: it has a `currentActorSeat`, and every *other* phase that has
  // one is in-hand. Nothing on it is private — the player says the name to the
  // room and the phone writes down what everyone already heard — so the phone
  // stays flat and the cues stay allowed.

  /// Pushes the host's audio settings onto the director before anything plays.
  ///
  /// Done from `build`, next to the location gate and for the same reason: it
  /// covers every path into a phase, including a resume, rather than only the
  /// ones somebody remembered to annotate.
  void _syncAudioSettings() {
    final settings = _controller.settings;
    _audio
      ..muted = settings.muteAllAudio
      ..narrationEnabled = settings.narrationEnabled
      ..scoreEnabled = settings.scoreEnabled
      // Idempotent: the loop is only started or stopped when the *setting*
      // changes, never when the phase does. See [AudioDirector.syncScore].
      ..syncScore();
  }

  /// Tells the audio layer where the phone is, before anything tries to play.
  ///
  /// Doing this from `build` — rather than at each transition — means the gate
  /// is closed for *every* path into an in-hand phase, including a resume, and
  /// cannot be left open by a transition someone forgot to annotate.
  void _syncPhoneLocation(GamePhase phase) {
    // An announcement is on-table by definition — it covers the whole screen and
    // nobody is holding anything. It can therefore run over a phase that is
    // otherwise in-hand (the night announcement is shown while the engine is
    // still one step behind), and the gate has to follow what is on screen
    // rather than what the engine says.
    final inHand = _moment == null && _inHandPhases.contains(phase);
    _audio.setLocation(inHand ? PhoneLocation.inHand : PhoneLocation.onTable);
  }

  /// Plays an on-table cue, ignoring it if the phone is in someone's hand.
  ///
  /// The director throws in that case by design; a cue arriving late (say, a
  /// timer firing just as a turn opens) is a scheduling accident, not a reason
  /// to crash the match in front of the players.
  void _cue(AudioCue cue) {
    try {
      _audio.play(cue);
    } on StateError {
      // Suppressed deliberately — see above.
    }
  }

  /// Speaks a public beat (F16) under the same rule as [_cue]: never in a
  /// hand, and a late call is dropped rather than crashing the table.
  void _narrate(
    NarratorBeat beat, [
    NarrationFacts facts = NarrationFacts.none,
  ]) {
    try {
      _audio.narrate(beat, facts);
    } on StateError {
      // Suppressed deliberately — see [_cue].
    }
  }

  /// The next voting announcement is a revote (a tie under the revote rule).
  bool _revoteNext = false;

  /// The facts a moment's line may depend on — each one on screen already.
  NarrationFacts _momentFacts(_Moment moment) => switch (moment) {
    _Moment.morningDeath => const NarrationFacts(nightEliminated: 1),
    _Moment.morningQuiet => const NarrationFacts(nightEliminated: 0),
    _Moment.voting => NarrationFacts(revote: _revoteNext),
    _Moment.night => NarrationFacts.none,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchControllerProvider);
    if (state == null) return const SizedBox.shrink();

    _syncAudioSettings();
    _syncPhoneLocation(state.phase);

    final outcome = state.public.outcome;
    if (state.phase == GamePhase.result && outcome != null && !_victorySeen) {
      return VictoryReveal(
        winner: outcome.winner,
        onStart: () => _cue(AudioCue.win),
        onComplete: () {
          // Spoken after the reveal has shown the winner, never before it.
          _narrate(
            NarratorBeat.win,
            NarrationFacts(winner: outcome.winner.name),
          );
          // P9: a pass-and-play match that reached its result is a clean
          // completed match; the prompt itself waits for a calm home screen.
          unawaited(ref.read(reviewPromptProvider).noteCleanMatch());
          setState(() => _victorySeen = true);
        },
      );
    }

    // Doc 12 §2.1 — one table that changes state, rather than a stack of
    // screens. The branch is on a *fact about the snapshot*, never on the
    // transport: `viewerSeat` is "the seat this device belongs to, or null when
    // the device belongs to the table rather than to a player", and a device
    // that belongs to one player is the only device that can show that player a
    // room. See `TableScene`'s class comment for why that is the honest
    // distinction and not `if (isOnline)` in a hat.
    if (tableIsAvailableFor(_controller.snapshot)) {
      final call = ref.watch(voiceStateProvider).valueOrNull;
      final table = OnlineTableFlow(
        onExit: widget.onExit,
        onAnalytics: widget.onAnalytics,
        onRematch: widget.onRematch,
        onStepCommitted: _commit,
      );
      if (call == null) return table;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: table),
          const SafeArea(top: false, child: VoiceControls()),
        ],
      );
    }

    final moment = _moment;
    if (moment != null) {
      return _presented(
        state,
        moment: moment.narration,
        _decorateMoment(
          moment,
          CinematicText(
            // Keyed so that two announcements in a row — a morning that resolves
            // straight into a win — really do play twice rather than the second
            // inheriting the first's finished animation.
            key: ValueKey('moment-${moment.name}-${state.dayNumber}'),
            text: _momentLine(moment),
            image: moment.backdrop,
            loop: moment.loop,
            onStart: () {
              final cue = moment.cue;
              if (cue != null) _cue(cue);
              final beat = moment.beat;
              if (beat != null) _narrate(beat, _momentFacts(moment));
              if (moment == _Moment.voting) _revoteNext = false;
            },
            onComplete: _momentFinished,
          ),
        ),
      );
    }

    // Keyed on the phase alone, so a rebuild inside a phase — a timer tick, a
    // target being picked — passes straight through without a dip.
    final screen = PhaseTransition(
      phaseKey: state.phase,
      // Store truth: the host phone's pack and identity, public phases only.
      child: PassTableDress(phase: state.phase, child: _phaseScreen(state)),
    );

    // The banner is one of the two widgets doc 10 §7 lets read the transport's
    // state, and it reads a field rather than a type. Offline the quality is
    // `local` and it draws nothing at all, so this costs an offline match one
    // zero-height box.
    final connection = _controller.snapshot.connection;
    final banner =
        connection != ConnectionQuality.local &&
        connection != ConnectionQuality.connected;

    // The voice controls are the second of doc 10 §7's two exceptions, and
    // they are here rather than on the screens that have a floor so that the
    // rule lives in one place. Offline there is no call, so this is null and
    // the tree below is exactly the tree an offline match has always had —
    // which the golden tests would notice if it were not.
    final voice = ref.watch(voiceStateProvider).valueOrNull;

    if (!banner && voice == null) return _presented(state, screen);
    return _presented(
      state,
      Column(
        children: [
          if (banner)
            SafeArea(
              bottom: false,
              child: ConnectionBanner(quality: connection),
            ),
          Expanded(child: screen),
          if (voice != null) const SafeArea(top: false, child: VoiceControls()),
        ],
      ),
    );
  }

  static const Key presentationKey = ValueKey('pass_presentation');

  /// Store truth: the host phone's narrator and presentation packs over
  /// «القعدة», the same layer the online table plays, limited to the phases
  /// the phone lies flat for everybody. One tree for moments and screens so
  /// the layer keeps its state across both.
  Widget _presented(
    MatchUiState state,
    Widget content, {
    NarrationBeat? moment,
  }) {
    final mine = ref.watch(myCosmeticsProvider);
    if (mine.pack == null && mine.narrator == null) return content;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        RoomPresentationLayer.local(
          key: presentationKey,
          snapshot: _controller.snapshot,
          packCode: mine.pack,
          narratorCode: mine.narrator,
          visibleIn: passCosmeticsVisibleIn,
          moment: moment,
        ),
      ],
    );
  }

  Widget _phaseScreen(MatchUiState state) {
    return switch (state.phase) {
      GamePhase.setup || GamePhase.rolesConfigured => const SizedBox.shrink(),
      GamePhase.distributing => RoleRevealScreen(
        onDistributionComplete: _commit,
      ),
      // Also upgrades saved matches stopped at the former start-night step.
      GamePhase.preNightLobby => _AutoAdvance(onReady: _beginNight),
      GamePhase.night || GamePhase.nightResolving => _night(state),
      GamePhase.morning => _morningOrDay(state),
      GamePhase.openingRound => _openingRound(state),
      GamePhase.confrontation => _confrontation(state),
      GamePhase.discussion => _discussion(state),
      GamePhase.voting || GamePhase.voteResolving => VotingScreen(
        allowAbstain: _controller.settings.abstainAllowed,
        onVotingComplete: _resolveDayVote,
      ),
      GamePhase.reveal || GamePhase.winCheck => _voteResult(state),
      GamePhase.result || GamePhase.analytics => _result(state),
    };
  }

  // ---------------------------------------------------------------------------
  // Transitions
  // ---------------------------------------------------------------------------

  void _beginNight() {
    void begin() {
      _controller.beginNight();
      _controller.openActorTurn();
      _commit();
    }

    // With a night line to speak, the night gets its own announcement so the
    // voice finishes on a flat phone; without one the table goes straight in.
    if (_audio.canNarrate(NarratorBeat.night)) {
      _announce(_Moment.night, begin);
    } else {
      begin();
    }
  }

  void _resolveNight() {
    _controller.resolveNight();
    setState(() => _morningAcknowledgedFor = null);
    // The phone is back on the table now that the last actor has passed.
    _audio.setLocation(PhoneLocation.onTable);
    _commit();

    // Which morning it was is public the moment it is announced — the briefing
    // screen behind this says the same thing in more words.
    final died =
        _controller.snapshot.phase == GamePhase.morning &&
        ref.read(matchControllerProvider)?.morning?.victimSeat != null;
    _announce(died ? _Moment.morningDeath : _Moment.morningQuiet, () {});
  }

  void _startDay() {
    // The morning has been read; only now may the match end on it. Doc 06 §4:
    // the victim is announced first and the result second, because "the last
    // mafia is gone" landing *after* you know who died is the payoff for the
    // whole match.
    final decided = _controller.concludeAfterNight();
    if (decided != null) {
      _commit();
      return;
    }

    setState(() => _morningAcknowledgedFor = _controller.snapshot.dayNumber);
    // One door out of the morning. Whether that lands on the «اسم واحد» round,
    // a confrontation, or straight on the discussion is the engine's call —
    // `_phaseScreen` follows the phase it produced, exactly as it does
    // everywhere else.
    _controller.beginDay();
    _commit();
    _narrate(NarratorBeat.discussion);
  }

  void _startVoting() {
    // "الشعب هيقرر… ومفيش رجوع"
    _announce(_Moment.voting, () {
      _controller.beginVoting();
      _commit();
    });
  }

  void _resolveDayVote() {
    final result = _controller.resolveDayVote();
    // The drum marks a real elimination only. Sounding it on a tie would tell
    // the table an outcome that has not happened yet.
    if (result.eliminatedSeat != null) {
      _audio.setLocation(PhoneLocation.onTable);
      _cue(AudioCue.eliminationReveal);
    }
    // A tie under the revote rule is not a result yet: the next announcement
    // is the revote, and the result line waits for it.
    _revoteNext =
        result.tie && _controller.settings.dayTieRule == DayTieRule.revote;
    if (!_revoteNext) {
      _audio.setLocation(PhoneLocation.onTable);
      _narrate(
        NarratorBeat.result,
        NarrationFacts(dayEliminated: result.eliminatedSeat == null ? 0 : 1),
      );
    }
    _commit();
  }

  /// Advances past the reveal. A win ends the match; otherwise the engine has
  /// already rolled the day number forward and put us back at the night lobby.
  void _continueAfterReveal() {
    _controller.winCheck();
    _commit();
  }

  // ---------------------------------------------------------------------------
  // Screens that need a little assembly
  // ---------------------------------------------------------------------------

  Widget _night(MatchUiState state) {
    // A match restored from storage has a current actor but no loaded turn:
    // `adoptMatch` deliberately publishes only the public view, so no secret
    // survives a resume. Load the turn here so the shell has something to gate
    // — it opens in its handoff state regardless, so the interrupted player
    // still has to identify themselves before anything appears (L-13).
    if (state.actorTurn == null && state.currentActorSeat != null) {
      return _AutoAdvance(onReady: _controller.openActorTurn);
    }
    return NightActionScreen(onNightComplete: _resolveNight);
  }

  Widget _morningOrDay(MatchUiState state) {
    // `morning` covers both the briefing and the moment just before the day
    // opens; the acknowledgement flag distinguishes them without inventing a
    // phase the engine does not have.
    if (_morningAcknowledgedFor == state.dayNumber) {
      return _discussion(state);
    }

    final report = state.morning;
    final victimSeat = report?.victimSeat;
    return MorningScreen(
      tabletop: _controller.settings.tabletopPresentation,
      dayNumber: state.dayNumber,
      victimName: victimSeat == null
          ? null
          : state.public.players[victimSeat].name,
      someoneSavedUnnamed: report?.someoneSavedUnnamed ?? false,
      // Doc 13 §5's «سريعة» row, and off everywhere else. Read from the
      // engine, which is the only thing that holds a role — the snapshot does
      // not, by construction, and that is not going to change.
      victimRole:
          victimSeat == null || !_controller.settings.revealNightVictimRole
          ? null
          : EngineCopy.roleName(
              context.l10n,
              _controller.engine.match.players[victimSeat].role,
            ),
      // Read from the engine rather than recomputed here. The trace was
      // decided when the night resolved and written to the log; asking the
      // generator again on every rebuild could produce a different sentence
      // from the one the table is looking at.
      traceText: InformationText.trace(
        context.l10n,
        _controller.snapshot.trace,
        _seatNames(state),
      ),
      onContinue: _startDay,
    );
  }

  int _livingCount(MatchUiState state) =>
      state.public.players.where((p) => p.status == PlayerStatus.alive).length;

  /// The turn-change chime, pitched for the pressure band (doc 13 §3).
  ///
  /// Routed through the director's own door rather than the generic [_cue] so
  /// that the pitch cannot be handed to any other cue by accident.
  void _turnChangeCue(MatchUiState state) {
    try {
      _audio.playTurnChange(
        band: _controller.settings.pressureCurveEnabled
            ? PressureCurve.bandIndex(_livingCount(state))
            : 0,
      );
    } on StateError {
      // Same suppression as [_cue], and for the same reason.
    }
  }

  Map<int, String> _seatNames(MatchUiState state) => {
    for (final p in state.public.players) p.seat: p.name,
  };

  Widget _openingRound(MatchUiState state) {
    final seat = state.currentActorSeat;
    if (seat == null) return const SizedBox.shrink();
    return OpeningRoundScreen(
      key: ValueKey('opening-$seat'),
      dayNumber: state.dayNumber,
      currentSeat: seat,
      players: state.public.players,
      onAccuse: (target) {
        _controller.submitOpeningAccusation(targetSeat: target);
        _commit();
      },
    );
  }

  Widget _confrontation(MatchUiState state) {
    final confrontation = _controller.snapshot.confrontation;
    final names = _seatNames(state);
    final observation = confrontation == null
        ? null
        : InformationText.confrontation(context.l10n, confrontation, names);

    // A confrontation the renderer cannot express is not shown at all — the
    // day simply moves on. Never a blank screen with a timer on it.
    if (confrontation == null || observation == null) {
      return _AutoAdvance(
        onReady: () {
          _controller.endConfrontation(silent: true);
          _commit();
        },
      );
    }

    return ConfrontationScreen(
      key: ValueKey('confrontation-${state.dayNumber}'),
      interfaceHintsEnabled: _controller.settings.interfaceHintsEnabled,
      dayNumber: state.dayNumber,
      playerName: names[confrontation.targetSeat] ?? '',
      observation: observation,
      window: Duration(seconds: _controller.settings.confrontationSeconds),
      onFinished: ({required bool silent}) {
        _controller.endConfrontation(silent: silent);
        _commit();
      },
    );
  }

  Widget _discussion(MatchUiState state) {
    final settings = _controller.settings;
    // Discussion is entirely on-table, so its cues are always safe to play.
    // (The narration switch itself is applied in `build`, for every phase.)
    return DiscussionScreen(
      tabletop: settings.tabletopPresentation,
      // Re-entering discussion on a later day must restart the speaking order.
      key: ValueKey('discussion-${state.dayNumber}'),
      interfaceHintsEnabled: settings.interfaceHintsEnabled,
      mode: settings.discussionMode,
      alivePlayers: [
        for (final p in state.public.players)
          if (p.status == PlayerStatus.alive) p,
      ],
      // Doc 13 §3. The clock closes as the table shrinks, and it closes on a
      // number every player can already see — how many cards are still in.
      perSpeakerTime: Duration(
        seconds: PressureCurve.speechSeconds(settings, _livingCount(state)),
      ),
      totalTime: Duration(
        seconds: PressureCurve.discussionSeconds(settings, _livingCount(state)),
      ),
      onSpeakerChanged: () => _turnChangeCue(state),
      onTimerEnded: () => _cue(AudioCue.timerEnd),
      // Floor time is the only evidence `C6` has, and it is recorded whether
      // the slot expired or was waved on.
      onSpoke: (seat, seconds) {
        _controller.recordSpeaking(seat: seat, seconds: seconds);
        _commit();
      },
      // Doc 14 §3.1: **null, always.** One phone on a table cannot deliver a
      // private message without stopping the discussion to pass it, which is
      // the discussion the message was supposed to be about. The layer is
      // online-only now, and offline there is nothing to hide behind a flag —
      // the button is not built and the graph is not drawn.
      onWhisper: null,
      onFinished: _startVoting,
    );
  }

  Widget _voteResult(MatchUiState state) {
    final vote = state.lastVote;
    if (vote == null) {
      // Nothing to reveal (e.g. a host removal drove us straight here).
      return _AutoAdvance(onReady: _continueAfterReveal);
    }

    return VoteResultScreen(
      tabletop: _controller.settings.tabletopPresentation,
      names: {for (final p in state.public.players) p.seat: p.name},
      tally: vote.tally ?? const {},
      eliminatedSeat: vote.eliminatedSeat,
      eliminatedRole: vote.eliminatedRole,
      tiedSeats: vote.tiedSeats ?? const [],
      revoteRequired: vote.tie,
      onContinue: _continueAfterReveal,
    );
  }

  Widget _result(MatchUiState state) {
    final outcome = state.public.outcome;
    if (outcome == null) return const SizedBox.shrink();

    final snapshot = _controller.snapshot;
    // Wrapped, not modified: the follow-up asks whether tonight's guests and
    // seating order should be kept in the saved group, and renders the result
    // screen underneath untouched. It is a no-op unless this match was started
    // from a group and something about the roster actually changed.
    return GroupFollowUp(
      child: ResultScreen(
        tabletop: _controller.settings.tabletopPresentation,
        winner: outcome.winner,
        // Doc 13 §4.4. Built from the finished match rather than from the
        // snapshot, because the notes are about roles and suspicions and the
        // snapshot has neither — which is exactly the property that keeps them
        // out of every screen before this one.
        rows: [
          for (final p in snapshot.standings)
            ResultRow(
              seat: p.seat,
              name: p.name,
              role: p.role,
              eliminatedLabel: _eliminationLabel(
                p.eliminatedPhase == null
                    ? null
                    : PhaseRef(
                        phase: p.eliminatedPhase!,
                        number: p.eliminatedNumber ?? 0,
                      ),
              ),
            ),
        ],
        // Offered only when there is a local record to open. An online match
        // has not been written to this device's database, so the autopsy would
        // open on nothing.
        onAnalytics: snapshot.analyticsAvailable ? widget.onAnalytics : null,
        // Phase 109. Pass-and-play only: this device holds the finished log.
        // Online the awards come from the server on the online result.
        awards: switch (_controller.transport) {
          final LocalTransport local when local.engine.hasMatch =>
            localMatchAwards(local.engine.match),
          _ => const [],
        },
        // P6: pass-and-play only, like the awards: the existing offers still
        // waiting today, below the fully revealed roles.
        inventory: switch (_controller.transport) {
          LocalTransport() => const PassResultInventory(),
          _ => null,
        },
        // Not a branch on the transport: `leave()` on a session that holds no
        // room does nothing, so an offline match pays nothing here. Online it
        // is what stops the heartbeat, the channel and the voice link of a
        // match that is over — they used to outlive the result screen until
        // the next room was entered.
        onHome: () async {
          // Ads v3 (phase 110): a finished pass-and-play match is counted and
          // may be followed by one ad, after Home is already on screen —
          // never while the phone is passed or a role is private.
          final localId = switch (_controller.transport) {
            final LocalTransport local when local.engine.hasMatch =>
              'local-${local.engine.match.seed}',
            _ => null,
          };
          final ads = ref.read(interstitialCoordinatorProvider);
          await ref.read(onlineSessionProvider.notifier).leave();
          widget.onExit();
          if (localId != null) {
            unawaited(ads.leftPassAndPlayResult(localId));
          }
        },
      ),
    );
  }

  String? _eliminationLabel(PhaseRef? eliminatedOn) {
    if (eliminatedOn == null) return null;
    final l10n = context.l10n;
    return eliminatedOn.phase == GamePhase.night
        ? l10n.nightNumbered(eliminatedOn.number)
        : l10n.dayNumbered(eliminatedOn.number);
  }
}

/// Renders nothing and runs [onReady] once, after the frame.
///
/// Used for the handful of states the engine can pass through with no player
/// decision attached; doing the work post-frame keeps it out of `build`.
class _AutoAdvance extends StatefulWidget {
  final VoidCallback onReady;

  const _AutoAdvance({required this.onReady});

  @override
  State<_AutoAdvance> createState() => _AutoAdvanceState();
}

class _AutoAdvanceState extends State<_AutoAdvance> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.surfaceBase,
    child: const SizedBox.expand(),
  );
}
