import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/enums.dart' as engine show Alignment;
import '../../engine/models/enums.dart' show GamePhase, PlayerStatus;
import '../../engine/models/player.dart' show PhaseRef;
import '../../platform/audio_director.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import 'day/discussion_screen.dart';
import 'day/vote_result_screen.dart';
import 'day/voting_screen.dart';
import 'distribution/pre_night_lobby_screen.dart';
import 'distribution/role_reveal_screen.dart';
import 'match_controller.dart';
import 'night/morning_screen.dart';
import 'night/night_action_screen.dart';
import 'postgame/result_screen.dart';
import 'setup/group_follow_up.dart';
import '../widgets/cinematic_text.dart';
import '../widgets/phase_transition.dart';

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

  /// Called after every confirmed engine step, so the host can persist. Kept as
  /// a callback rather than a repository dependency so the flow stays testable
  /// without storage.
  final VoidCallback? onStepCommitted;

  const MatchFlow({
    super.key,
    required this.onExit,
    required this.onAnalytics,
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
  nightFalls(AudioCue.nightFalls),
  morningDeath(AudioCue.morning),
  morningQuiet(AudioCue.morning),
  voting(null),
  mafiaWins(AudioCue.win),
  townWins(AudioCue.win);

  const _Moment(this.cue);

  /// The cue to fire as the words appear, or null for an announcement that has
  /// no sound yet. A recorded narrator line for the cue plays over its ambient
  /// bed; with neither, the line on screen carries the moment alone.
  final AudioCue? cue;
}

class MatchFlowState extends ConsumerState<MatchFlow> {
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
      _Moment.nightFalls => l10n.phaseNightFalls,
      _Moment.morningDeath => l10n.phaseMorningSomeoneDied,
      _Moment.morningQuiet => l10n.phaseMorningNobodyDied,
      _Moment.voting => l10n.phaseVoting,
      _Moment.mafiaWins => l10n.phaseMafiaWins,
      _Moment.townWins => l10n.phaseTownWins,
    };
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

  /// Pushes the host's audio settings onto the director before anything plays.
  ///
  /// Done from `build`, next to the location gate and for the same reason: it
  /// covers every path into a phase, including a resume, rather than only the
  /// ones somebody remembered to annotate.
  void _syncAudioSettings() {
    final settings = _controller.engine.match.settings;
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchControllerProvider);
    if (state == null) return const SizedBox.shrink();

    _syncAudioSettings();
    _syncPhoneLocation(state.phase);

    final moment = _moment;
    if (moment != null) {
      return CinematicText(
        // Keyed so that two announcements in a row — a morning that resolves
        // straight into a win — really do play twice rather than the second
        // inheriting the first's finished animation.
        key: ValueKey('moment-${moment.name}-${state.dayNumber}'),
        text: _momentLine(moment),
        onStart: () {
          final cue = moment.cue;
          if (cue != null) _cue(cue);
        },
        onComplete: _momentFinished,
      );
    }

    // Keyed on the phase alone, so a rebuild inside a phase — a timer tick, a
    // target being picked — passes straight through without a dip.
    return PhaseTransition(phaseKey: state.phase, child: _phaseScreen(state));
  }

  Widget _phaseScreen(MatchUiState state) {
    return switch (state.phase) {
      GamePhase.setup || GamePhase.rolesConfigured => const SizedBox.shrink(),
      GamePhase.distributing => RoleRevealScreen(
        onDistributionComplete: _commit,
      ),
      GamePhase.preNightLobby => PreNightLobbyScreen(
        dayNumber: state.dayNumber,
        aliveCount: state.public.players
            .where((p) => p.status == PlayerStatus.alive)
            .length,
        onBeginNight: _beginNight,
      ),
      GamePhase.night || GamePhase.nightResolving => _night(state),
      GamePhase.morning => _morningOrDiscussion(state),
      GamePhase.discussion => _discussion(state),
      GamePhase.voting || GamePhase.voteResolving => VotingScreen(
        allowAbstain: _controller.engine.match.settings.abstainAllowed,
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
    // "الضلمة نزلت على البلد… كله يغمّض" — announced first, with the night
    // opening underneath it once the words have gone. The announcement fires
    // `nightFalls`; the wake call follows it, still on the table, which is the
    // only window in which either is safe.
    _announce(_Moment.nightFalls, () {
      _cue(AudioCue.mafiaWake);
      _controller.beginNight();
      _controller.openActorTurn();
      _commit();
    });
  }

  void _resolveNight() {
    _controller.resolveNight();
    setState(() => _morningAcknowledgedFor = null);
    // The phone is back on the table now that the last actor has passed.
    _audio.setLocation(PhoneLocation.onTable);
    _commit();

    // Which morning it was is public the moment it is announced — the briefing
    // screen behind this says the same thing in more words.
    final died = _controller.engine.match.phase == GamePhase.morning &&
        ref.read(matchControllerProvider)?.morning?.victimSeat != null;
    _announce(died ? _Moment.morningDeath : _Moment.morningQuiet, () {});
  }

  void _startDiscussion() {
    // The morning has been read; only now may the match end on it. Doc 06 §4:
    // the victim is announced first and the result second, because "the last
    // mafia is gone" landing *after* you know who died is the payoff for the
    // whole match.
    final decided = _controller.concludeAfterNight();
    if (decided != null) {
      _commit();
      _announce(
        decided == engine.Alignment.mafia
            ? _Moment.mafiaWins
            : _Moment.townWins,
        () {},
      );
      return;
    }

    setState(
      () => _morningAcknowledgedFor = _controller.engine.match.dayNumber,
    );
    _controller.beginDiscussion();
    _commit();
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
    _commit();
  }

  /// Advances past the reveal. A win ends the match; otherwise the engine has
  /// already rolled the day number forward and put us back at the night lobby.
  void _continueAfterReveal() {
    _controller.winCheck();
    _commit();

    // If that ended the match, the result gets its own announcement before the
    // roster of who was what. The same sting either way — two would tell the
    // room the outcome before the screen did.
    final winner = _controller.engine.match.outcome?.winner;
    if (winner != null) {
      _announce(
        winner == engine.Alignment.mafia ? _Moment.mafiaWins : _Moment.townWins,
        () {},
      );
    }
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

  Widget _morningOrDiscussion(MatchUiState state) {
    // `morning` covers both the briefing and the moment just before discussion
    // opens; the acknowledgement flag distinguishes them without inventing a
    // phase the engine does not have.
    if (_morningAcknowledgedFor == state.dayNumber) {
      return _discussion(state);
    }

    final report = state.morning;
    final victimSeat = report?.victimSeat;
    return MorningScreen(
      dayNumber: state.dayNumber,
      victimName: victimSeat == null
          ? null
          : state.public.players[victimSeat].name,
      someoneSavedUnnamed: report?.someoneSavedUnnamed ?? false,
      onContinue: _startDiscussion,
    );
  }

  Widget _discussion(MatchUiState state) {
    final settings = _controller.engine.match.settings;
    // Discussion is entirely on-table, so its cues are always safe to play.
    // (The narration switch itself is applied in `build`, for every phase.)
    return DiscussionScreen(
      // Re-entering discussion on a later day must restart the speaking order.
      key: ValueKey('discussion-${state.dayNumber}'),
      mode: settings.discussionMode,
      alivePlayers: [
        for (final p in state.public.players)
          if (p.status == PlayerStatus.alive) p,
      ],
      perSpeakerTime: Duration(seconds: settings.speechSeconds),
      onSpeakerChanged: () => _cue(AudioCue.speakerChange),
      onTimerEnded: () => _cue(AudioCue.timerEnd),
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

    final match = _controller.engine.match;
    // Wrapped, not modified: the follow-up asks whether tonight's guests and
    // seating order should be kept in the saved group, and renders the result
    // screen underneath untouched. It is a no-op unless this match was started
    // from a group and something about the roster actually changed.
    return GroupFollowUp(
      child: ResultScreen(
        winner: outcome.winner,
        rows: [
          for (final p in match.players)
            ResultRow(
              seat: p.seat,
              name: p.name,
              role: p.role,
              eliminatedLabel: _eliminationLabel(p.eliminatedOn),
            ),
        ],
        onAnalytics: widget.onAnalytics,
        onHome: widget.onExit,
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
