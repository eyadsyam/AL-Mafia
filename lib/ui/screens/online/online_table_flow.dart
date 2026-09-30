import 'dart:async';

import 'package:flutter/material.dart' hide Alignment;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// `Alignment` here is the engine's win side, not Flutter's layout anchor.
import '../../../app/asset_constants.dart';
import '../../../engine/models/enums.dart';
import '../../../engine/models/player.dart' show PlayerGender, PublicPlayer;
import '../../../platform/narrator_bank.dart';
import '../../../platform/audio_director.dart';
import '../../../platform/haptics.dart';
import '../../economy/cosmetics.dart' show cosmeticsVisibleIn;
import '../../social/invite_privacy.dart';
import '../../../platform/monetization/interstitial_policy.dart';
import '../../../platform/reduce_motion.dart';
import '../../../transport/game_snapshot.dart';
import '../../../transport/online_backend.dart';
import '../../../transport/online_transport.dart' show OnlineTransport;
import '../../information_text.dart';
import '../../l10n_ext.dart';
import '../../economy/economy_capabilities.dart';
import '../../economy/interstitial_coordinator.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/hold_pad.dart';
import '../../widgets/role_card.dart';
import '../day/whisper_compose_screen.dart';
import '../../widgets/whisper_card.dart';
import '../match_controller.dart';
import 'council/card_rise.dart';
import 'council/phase_sting.dart';
import 'council/role_roster.dart';
import 'council/revealed_whispers.dart';
import 'council/council_band.dart';
import 'host_handover.dart';
import 'host_sheet.dart';
import 'scene_sheet.dart';
import 'online_session.dart';
import 'rewarded_reward_button.dart';
import '../../economy/council_hub.dart' show CouncilResultStrip;
import '../../economy/vault_kit.dart' show ScrollFadeEdge, VaultCard;
import 'result_share_button.dart';
import '../../fun/award_ribbon.dart' show OnlineAwardsStrip;
import '../../fun/reactions.dart';
import 'voice_session.dart';
import 'council/voice_band.dart';
import 'table/connection_weather.dart';
import 'table/table_mood.dart';
import 'table/table_scene.dart';
import 'witness/elimination_beat.dart';
import 'witness/own_record.dart';
import 'witness/witness_panel.dart';
import '../../widgets/card_art.dart';
import '../../widgets/motion_sprite.dart';
import 'witness/kill_jumpscare.dart';
import 'witness/witness_layer.dart';
import '../../../transport/witness_channel.dart';

/// The online match, as one table that changes state (doc 12 §2.1, §3).
///
/// ## What this replaces, and what it does not
///
/// It replaces the *presentation* of a phase, not its rules. Every command
/// below goes through [MatchController] exactly as the offline screens' do, and
/// the engine and the server decide everything they decided before. What
/// changes is that a phase no longer swaps a screen: it re-dresses the table
/// that was already there.
///
/// ## Why the interaction moved onto the table
///
/// Doc 12 §3.3: *"You select by tapping a seat on the table itself — not from a
/// separate list."* The list was the right shape for one phone being passed
/// around — it is a form you fill in and hand on — and it is the wrong shape
/// for ten people who can all see the same room at once. Tapping the person is
/// what you would do at a table.
///
/// The leakage properties are unchanged and are checked in the same places: the
/// seat's own widget refuses per-seat status when the phase forbids it
/// ([TableMood.showsPerSeatStatus]), the footer's copy is the engine's
/// role-blind prompt, and nothing here branches on a role.
class OnlineTableFlow extends ConsumerStatefulWidget {
  /// Leaves the match.
  final VoidCallback onExit;

  /// Opens the post-game autopsy, when there is one to open.
  final VoidCallback onAnalytics;

  /// Called after a command that changed the match, so the host's device can
  /// persist. A no-op on every client that is not the host.
  final VoidCallback onStepCommitted;

  /// Returns the group to online entry after giving up the completed room.
  final VoidCallback? onRematch;

  const OnlineTableFlow({
    super.key,
    required this.onExit,
    required this.onAnalytics,
    required this.onStepCommitted,
    this.onRematch,
  });

  /// Doc 15 §S-O13 beat 5: the roster control.
  /// Phase 109: the result's primary action, a new room for the same group.
  static const Key playAgain = ValueKey('online_play_again');
  static const Key seeRoles = ValueKey('online_see_roles');
  static const Key revealedWhispers = ValueKey('online_revealed_whispers');

  /// The result's scrolling part: awards, reactions, council, roles, home.
  static const Key resultScroll = ValueKey('online_result_scroll');

  static const Key confirmAction = ValueKey('table_confirm');
  static const Key hostAdvance = ValueKey('table_host_advance');
  static const Key closeRoomConfirm = ValueKey('table_close_room_confirm');
  static const Key abstain = ValueKey('table_abstain');
  static const Key readyToVote = ValueKey('table_ready_to_vote');
  static const Key whisperButton = ValueKey('table_whisper');
  static const Key confrontationDone = ValueKey('table_confrontation_done');

  @override
  ConsumerState<OnlineTableFlow> createState() => _OnlineTableFlowState();
}

class _OnlineTableFlowState extends ConsumerState<OnlineTableFlow>
    with TickerProviderStateMixin {
  MatchController get _controller => ref.read(matchControllerProvider.notifier);

  /// Captured once, so leaving the table can clear the privacy flag.
  late final StateController<bool> _privacy = ref.read(
    privateMomentProvider.notifier,
  );
  GameSnapshot get _snapshot => _controller.snapshot;

  /// The seat this client currently has chosen, or null.
  int? _selected;

  /// True once this client has committed its move for the current phase.
  ///
  /// Reset on every phase change rather than tracked per phase, so a client
  /// that reconnects into a new phase is never left holding a stale "done".
  bool _submitted = false;
  bool _acknowledged = false;
  bool _actionFailed = false;
  int _attemptNumber = 0;

  GamePhase? _phaseAt;
  int? _dayAt;
  int? _ballotRoundAt;

  /// The snapshot this device last asked its private view from, and whether
  /// the answer ever arrived.
  ///
  /// Online nobody passes the phone, so nothing else asks on this seat's
  /// behalf: the role card and the night turn both have to be pulled by the
  /// client that owns the seat. See [_maybePullPrivateView].
  GameSnapshot? _privateAskedFor;

  /// The snapshot this device was holding a private view for.
  ///
  /// A *snapshot*, not a flag. The flag this replaces was set the first time a
  /// card was on screen and never cleared until the phase changed, so a card
  /// that left the screen without the room hearing about it could never be
  /// asked for again: the seat sat in its own waiting list with nothing to
  /// press. A hold that expires with the fact that justified it cannot do that.
  GameSnapshot? _privateHeldAt;

  /// Whether a dismissal is in flight. It holds the card off the screen for the
  /// one round trip between the player letting go of it and the server saying
  /// it heard — without which an unrelated push landing in that window would
  /// hand the card straight back.
  bool _committing = false;
  Timer? _privateRetry;

  /// The morning's tear, and the seat it belongs to.
  // Built with no duration and given one in `didChangeDependencies`, where the
  // theme is readable. Zero rather than a literal: a placeholder number here
  // would be a second, wrong copy of a token, and the one that never gets
  // updated is the one somebody eventually ships.
  late final AnimationController _tear = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );
  int? _tearingSeat;

  /// A whisper crossing the table.
  late final AnimationController _sparkFlight = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  /// The confrontation's radial mask opening over the council (doc 15 §S-O7).
  late final AnimationController _spotlight = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );
  CouncilSpark? _spark;

  /// Doc 15 §S-O13 beat 2: the whole council turning over at once.
  ///
  /// Owned here rather than inside [CouncilBand] because the band is allowed
  /// exactly one controller — doc 15 §3's frame budget is what fifteen
  /// controllers would spend — and because the beat is a *phase* event, which
  /// is the thing this state object exists to notice.
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  /// The transition sting playing over the council, or null.
  ///
  /// Doc 16 V1/V2. Muted and never load-bearing — see [PhaseSting].
  PhaseLight? _sting;

  /// The night victim's scare (see [KillJumpscare]), once per day.
  bool _scaring = false;
  int? _scaredDay;

  /// Night one's citizen has nothing to do; their "nothing" is sent for them
  /// once, so the night can end as soon as the others are done.
  int? _restSentDay;
  int? _heardSpeaker;

  /// The «last ten seconds» tick for the phase that is running, armed once
  /// per phase and deadline.
  Timer? _warning;
  String? _warningKey;
  String? _cardSounded;

  /// The verdict this device has already watched turn over, as a phase-and-day
  /// stamp. Doc 15 §S-O12 is a once-per-elimination beat, and a rebuild is not
  /// an elimination.
  String? _cardShown;

  /// The completed match this screen has already counted (interstitial grace
  /// and preload). Once per room, however often the result rebuilds.
  String? _completedRoom;

  void _noteCompleted(String roomId) {
    if (_completedRoom == roomId) return;
    _completedRoom = roomId;
    unawaited(ref.read(interstitialCoordinatorProvider).matchCompleted(roomId));
  }

  /// Leaves the room first (heartbeat, channel, voice link), then goes home;
  /// only a room actually left in time lets the automatic ad be considered,
  /// and only if one is already loaded and every rule allows it.
  bool _leavingHome = false;
  Future<void> _homeAfterCompleted() async {
    if (_leavingHome) return;
    _leavingHome = true;
    final coordinator = ref.read(interstitialCoordinatorProvider);
    final session = ref.read(onlineSessionProvider.notifier);
    await leaveThenMaybeAd(
      leave: session.leave,
      exit: widget.onExit,
      ad: () => coordinator.leftResult(ResultExit.homeAfterCompleted),
    );
  }

  /// Whether the elimination beat has been played for this device's own death.
  bool _mourned = false;

  /// The open table an eliminated viewer watches: every role, every night
  /// choice. Null for the living, always — the server refuses them.
  WitnessTable? _witnessTable;

  /// The dead's news (owner, 2026-09-28): what is waiting, what is showing,
  /// and the clock that takes it down.
  final List<WitnessNews> _newsQueue = [];
  WitnessNews? _news;
  Timer? _newsTimer;

  /// The witness's popups: an opened whisper, a seat's dossier, or one of the
  /// dock's pages. At most one is open.
  WitnessWhisper? _letter;
  int? _dossier;
  WitnessPanelTab? _witnessPage;

  /// Whispers this witness has opened, so their seals stop breathing.
  final Set<String> _openedLetters = <String>{};

  /// Keeps the table the same element while the witness grey is put on it.
  final GlobalKey _tableKey = GlobalKey();
  Timer? _witnessPoll;
  bool _mourning = false;

  /// The ballot as it stood at the last build, so a new one can be heard
  /// arriving (doc 12 §8's vote tick).
  Map<int, int?> _heardBallots = const {};

  /// Whispers this device has already sounded for, so a resync does not replay
  /// the day's conversation as a burst of chimes.
  final Set<String> _heardWhispers = <String>{};

  late final AudioDirector _audio;
  String? _selectedNarrator;

  /// The whisper this device is currently showing, or null.
  ///
  /// One at a time. Two arriving inside twelve seconds is a real possibility
  /// and stacking cards over a table nobody can see is not an answer, so the
  /// second waits for the first to go — [_pullWhisper] is re-entered on the
  /// next fold either way.
  _Incoming? _incoming;

  /// True while a body fetch is in flight, so a rebuild does not start a
  /// second one for the same whisper.
  bool _pulling = false;

  /// True while the whisper composer is over the table.
  ///
  /// Local state rather than a route, for the same reason the offline flow
  /// keeps it local: the phase is the router here, and a pushed page would
  /// create a second notion of "where we are" that a reconnection could not
  /// reproduce. An unsent whisper was never sent.
  bool _composing = false;

  /// Doc 15 §S-O13 beat 5: whether the roster is open over the council.
  bool _roster = false;

  /// Doc 09 §7: the finished match's whispers, open over the result.
  bool _whispers = false;

  /// True once this device has been told to go home and has asked to.
  bool _leaving = false;

  /// The seat whose host sheet is open, and whether the close-room
  /// confirmation is showing. Layers in the table's Stack, never routes
  /// (doc 12 §2.1).
  int? _inspect;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioDirectorProvider);
    _privacy;
    _tear.addListener(_repaint);
    _sparkFlight.addListener(_repaint);
    _spotlight.addListener(_repaint);
    _turn.addListener(_repaint);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tear.duration = context.motion.tear;
    _sparkFlight.duration = context.motion.travel;
    _spotlight.duration = context.motion.phase;
  }

  @override
  void dispose() {
    if (_audio.activeVoice == _selectedNarrator) {
      _audio.activeVoice = null;
    }
    final privacy = _privacy;
    WidgetsBinding.instance.addPostFrameCallback((_) => privacy.state = false);
    _privateRetry?.cancel();
    _witnessPoll?.cancel();
    _newsTimer?.cancel();
    _warning?.cancel();
    _tear.dispose();
    _sparkFlight.dispose();
    _spotlight.dispose();
    _turn.dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  // ── phase bookkeeping ────────────────────────────────────────────────────

  /// Notices a phase change and resets everything that was about the old one.
  void _syncPhase(GameSnapshot snapshot) {
    _selectedNarrator = snapshot.room.narratorPack == 'classic'
        ? null
        : snapshot.room.narratorPack;
    _audio.activeVoice = _selectedNarrator;
    // Invites wait through every phase with something private on screen
    // (the deal, the night) and through a ballot.
    reportPrivateMoment(
      ref,
      !cosmeticsVisibleIn(snapshot.phase) || snapshot.phase == GamePhase.voting,
    );
    if (snapshot.phase == _phaseAt &&
        snapshot.dayNumber == _dayAt &&
        snapshot.ballotRound == _ballotRoundAt) {
      return;
    }

    final previous = _phaseAt;
    _phaseAt = snapshot.phase;
    _dayAt = snapshot.dayNumber;
    _ballotRoundAt = snapshot.ballotRound;
    _selected = null;
    _submitted = false;
    _acknowledged = false;
    _actionFailed = false;
    _privateAskedFor = null;
    _privateHeldAt = null;
    _privateRetry?.cancel();
    _privateRetry = null;

    // The morning's tear. Started here rather than in a builder so it plays
    // once per morning and not once per rebuild.
    if (snapshot.phase == GamePhase.morning && previous != GamePhase.morning) {
      final victim = snapshot.morning?.victimSeat;
      _tearingSeat = victim;
      if (victim != null) {
        // Paper and one low drum. Safe here and nowhere near a night: the
        // morning is the phone flat on the table with the whole room looking
        // at it, which is the only condition `play` accepts.
        _audio.play(AudioCue.deathTear);
        if (ReduceMotion.of(context)) {
          _tear.value = 1;
        } else {
          _tear.forward(from: 0);
        }
      }
    } else if (snapshot.phase != GamePhase.morning) {
      _tearingSeat = null;
      _tear.value = 0;
    }

    // Doc 16 V1 and V2, on the two phase changes that are a change of *light*
    // rather than a change of turn. Started here, with the rest of the phase's
    // one-shot beats, so a rebuild cannot replay it.
    _sting = switch (snapshot.phase) {
      GamePhase.night when previous != GamePhase.night => PhaseLight.dusk,
      GamePhase.morning when previous != GamePhase.morning => PhaseLight.dawn,
      _ => null,
    };
    // The player the Mafia took gets the reaper instead of the dawn: straight
    // into the dark, on their phone only, before the table starts talking.
    if (snapshot.phase == GamePhase.morning &&
        previous != GamePhase.morning &&
        snapshot.morning?.victimSeat != null &&
        snapshot.morning?.victimSeat == snapshot.viewerSeat &&
        _scaredDay != snapshot.dayNumber &&
        // A lunge at the camera is exactly what Reduce Motion asks us not to
        // do; those players get the morning and the beat without it.
        !ReduceMotion.of(context)) {
      _scaredDay = snapshot.dayNumber;
      _scaring = true;
      _sting = null;
    }
    // The light change has a sound, and online it plays on every phone at the
    // same moment — a shared beat, not a private one, so it tells nobody
    // anything. The narrator line rides on it when narration is on.
    if (_sting == PhaseLight.dusk) _sharedCue(AudioCue.nightFalls);
    if (_sting == PhaseLight.dawn) _sharedCue(AudioCue.morning);
    final line = _publicLine(snapshot, previous);
    if (line != null) _sharedNarrate(line.$1, line.$2);

    // Doc 15 §S-O13. Beat 1 is the freeze the result phase arrives with; this
    // is beat 2, once per match. Under Reduce Motion the rings are simply
    // carrying their marks when the result appears — there is no turn to read
    // and none is faked.
    if (snapshot.phase == GamePhase.result && previous != GamePhase.result) {
      _audio.play(AudioCue.cardFlip);
      if (ReduceMotion.of(context)) {
        _turn.value = 1;
      } else {
        _turn.duration = context.motion.card;
        _turn.forward(from: 0);
      }
    } else if (snapshot.phase != GamePhase.result &&
        snapshot.phase != GamePhase.analytics) {
      _turn.value = 0;
    }

    if (snapshot.phase == GamePhase.confrontation) {
      if (previous != GamePhase.confrontation) {
        _audio.play(AudioCue.confrontationSwell);
      }
      if (ReduceMotion.of(context)) {
        _spotlight.value = 1;
      } else if (_spotlight.value == 0) {
        _spotlight.forward(from: 0);
      }
    } else {
      _spotlight.value = 0;
    }

    ref.read(ownRecordProvider.notifier).observe(snapshot);
  }

  /// Pulls whatever this device is privately owed in the phase it is in.
  ///
  /// # Why anything has to ask at all
  ///
  /// Offline a screen walks the seats: it asks for one seat's card, waits for
  /// the phone to be handed on, and asks for the next. Online there is no such
  /// screen and no phone to pass — every client sits in the same phase at the
  /// same moment — so each one has to ask for its own seat, and only its own.
  /// `secretsFor` refuses every other seat, which is what makes asking safe.
  ///
  /// Two phases owe this device something private: the deal owes it a role
  /// card, and the night owes it the turn view its action is chosen from.
  /// Neither had a caller here. The deal showed the table backs for ever, and
  /// the night showed «مستني اللاعبين» to a player who had not yet acted — both
  /// of them silently, because the server was perfectly happy and the client
  /// was simply never going to ask.
  ///
  /// # Why it retries, and why it still asks only once
  ///
  /// The answer is not always ready the first time. A phase change arrives as
  /// a push, and the client's own row — the one carrying the role — is only
  /// re-read by the resync that push triggers. So the first snapshot of a new
  /// phase can legitimately have nothing to give, and a single attempt spent
  /// on it is an attempt wasted for the whole phase. That is exactly what one
  /// real five-player match did: the reveal arrived, the ask went out a beat
  /// early, and the card never came.
  ///
  /// So the attempt is once per *snapshot* rather than once per phase, and it
  /// stops for good the moment the answer lands — which is what keeps a
  /// dismissed card from being handed straight back, and a submitted night
  /// action from reopening its own picker.
  void _maybePullPrivateView(GameSnapshot snapshot, MatchUiState state) {
    final held = switch (snapshot.phase) {
      GamePhase.distributing => state.reveal != null,
      GamePhase.night => state.actorTurn != null,
      // Every other phase is public, or is answered by a call this screen
      // already makes. Nothing to pull, and nothing to retry.
      _ => true,
    };
    if (held || _committing) {
      _privateHeldAt = snapshot;
      _privateRetry?.cancel();
      _privateRetry = null;
      return;
    }
    // Only for as long as the snapshot that justified it. The moment the server
    // says something new and this device still owes the phase, the view is
    // asked for again — which is the difference between a card the player put
    // down and a card that was taken from them.
    if (identical(_privateHeldAt, snapshot)) return;
    // Null means this device owes nothing: it has already acted tonight, or
    // it is dead, or the roster has not landed yet. Asking would answer
    // nothing.
    if (snapshot.currentActorSeat == null) return;
    if (identical(_privateAskedFor, snapshot)) return;
    _privateAskedFor = snapshot;

    // After the frame: both calls publish controller state, and a notifier
    // must not be written to during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_pullPrivateView(snapshot));
    });
  }

  Future<void> _pullPrivateView(GameSnapshot requested) async {
    try {
      if (requested.phase == GamePhase.distributing) {
        await _controller.revealCurrentRole();
      } else {
        await _controller.openActorTurn();
      }
    } catch (_) {
      // A private read may race an auth refresh or a brief network loss. The
      // retry below is the recovery; a failed voice/private request must never
      // move or terminate the public match.
    }
    if (!mounted) return;
    final current = ref.read(matchControllerProvider);
    final latest = _snapshot;
    final missing = switch (latest.phase) {
      GamePhase.distributing => current?.reveal == null,
      GamePhase.night => current?.actorTurn == null,
      _ => false,
    };
    if (!missing || latest.currentActorSeat == null) return;

    // A deal is several server writes. If this device caught the phase before
    // its private row was readable, retry locally instead of requiring an
    // unrelated Realtime event to wake it. The server still authenticates and
    // answers every request; this timer grants no information by itself.
    _privateRetry?.cancel();
    _privateRetry = Timer(MafiaTiming.privateViewRetry, () {
      if (!mounted) return;
      _privateAskedFor = null;
      setState(() {});
    });
  }

  /// Sounds the things that happen *within* a phase.
  ///
  /// Separate from [_syncPhase] because these are not transitions: a ballot
  /// landing and a whisper arriving both happen while the phase stands still,
  /// and both are public events on a table everybody is looking at.
  /// A cue every phone plays at the same moment. Never while this phone is
  /// held for something private — the director refuses that outright (FR-026),
  /// and a refused cue must cost a sound, not a frame: an uncaught refusal
  /// here once painted the whole screen grey as the night opened.
  /// The ballot the narrator last opened, so a same-day revote is spoken
  /// once and a rebuild never repeats a line.
  int? _narratedBallot;

  /// F16 online: the narrator line for the public beat this snapshot just
  /// entered, built only from what every seat is shown at this moment —
  /// how many the night took, whether the vote removed someone, whether
  /// this ballot is a revote, and who won once the result is on screen.
  (NarratorBeat, NarrationFacts)? _publicLine(
    GameSnapshot snapshot,
    GamePhase? previous,
  ) {
    final phase = snapshot.phase;
    if (phase == GamePhase.voting) {
      if (previous == GamePhase.voting &&
          _narratedBallot == snapshot.ballotRound) {
        return null;
      }
      _narratedBallot = snapshot.ballotRound;
      return (
        NarratorBeat.voting,
        NarrationFacts(revote: snapshot.ballotCandidates.isNotEmpty),
      );
    }
    if (phase == previous) return null;
    return switch (phase) {
      GamePhase.night => (NarratorBeat.night, NarrationFacts.none),
      GamePhase.morning => (
        NarratorBeat.morning,
        NarrationFacts(
          nightEliminated: snapshot.morning?.victimSeat == null ? 0 : 1,
        ),
      ),
      GamePhase.discussion => (NarratorBeat.discussion, NarrationFacts.none),
      GamePhase.reveal when snapshot.lastVote != null => (
        NarratorBeat.result,
        NarrationFacts(
          dayEliminated: snapshot.lastVote!.eliminatedSeat == null ? 0 : 1,
        ),
      ),
      GamePhase.result
          when (snapshot.outcome?.winner ?? snapshot.pendingOutcome) != null =>
        (
          NarratorBeat.win,
          NarrationFacts(
            winner: (snapshot.outcome?.winner ?? snapshot.pendingOutcome)!.name,
          ),
        ),
      _ => null,
    };
  }

  /// A spoken line on every phone at the same public moment. Never while the
  /// phone is in a hand; a voice that fails is never load-bearing.
  void _sharedNarrate(NarratorBeat beat, NarrationFacts facts) {
    if (_audio.location == PhoneLocation.inHand) return;
    try {
      _audio.narrate(beat, facts);
    } catch (_) {}
  }

  void _sharedCue(AudioCue cue) {
    if (_audio.location == PhoneLocation.inHand) return;
    try {
      _audio.play(cue);
    } catch (_) {
      // Sound is never load-bearing.
    }
  }

  /// Ten seconds before a discussion or a ballot closes, one soft warning on
  /// every phone at once — the clock is public, so the tick is too.
  void _armWarning(GameSnapshot snapshot) {
    final deadline = snapshot.phaseDeadline;
    final timed =
        snapshot.phase == GamePhase.discussion ||
        snapshot.phase == GamePhase.voting;
    final key = timed && deadline != null
        ? '${snapshot.phase}-${snapshot.dayNumber}-'
              '${snapshot.ballotRound}-$deadline'
        : null;
    if (key == _warningKey) return;
    _warningKey = key;
    _warning?.cancel();
    _warning = null;
    if (key == null || _viewerIsDead(snapshot)) return;
    final wait = deadline!
        .subtract(MafiaTiming.timerWarningLead)
        .difference(DateTime.now());
    if (wait.isNegative) return;
    _warning = Timer(wait, () {
      if (mounted) _sharedCue(AudioCue.timerWarning);
    });
  }

  void _syncSounds(GameSnapshot snapshot) {
    _armWarning(snapshot);
    // The floor changing hands is public — the seat glows on every screen —
    // so the soft turn cue plays everywhere too.
    final speaker = snapshot.activeSpeakerSeat;
    if (speaker != null && speaker != _heardSpeaker) {
      _sharedCue(AudioCue.speakerChange);
    }
    _heardSpeaker = speaker;

    // One tick per new ballot, never per rebuild. Only reachable at all in a
    // room that chose an open ballot — a secret one has an empty map, so this
    // is silent and there is nothing to suppress.
    if (snapshot.phase == GamePhase.voting) {
      for (final voter in snapshot.liveBallots.keys) {
        if (!_heardBallots.containsKey(voter)) {
          _audio.play(AudioCue.voteTick);
          break;
        }
      }
      _heardBallots = Map.of(snapshot.liveBallots);
    } else if (_heardBallots.isNotEmpty) {
      _heardBallots = const {};
    }

    final me = snapshot.viewerSeat;
    final first = _heardWhispers.isEmpty;
    for (final whisper in snapshot.whisperGraph) {
      if (whisper.voided || !_heardWhispers.add(whisper.id)) continue;

      // The light crosses the table on **every** device (doc 12 §3.7):
      // *"Everyone sees the light — nobody sees the words."* Driven off the
      // graph rather than off the sender's own tap, so it is the same event on
      // every screen and a viewer who joined late still sees the traffic.
      //
      // Not on the first fold, though: a client that has just resynced would
      // otherwise replay the whole day's conversation as a burst of lights.
      if (!first) _flyWhisper(whisper.fromSeat, whisper.toSeat);

      // Only the two ends *hear* it. A chime on every device would turn the
      // graph into an audible census of who is talking to whom.
      if (whisper.toSeat == me) {
        _audio.play(AudioCue.whisperReceive);
        // …and the words, which is the half that was missing. The chime and
        // the light said *somebody wrote to you* and stopped there.
        unawaited(_pullWhisper(snapshot, whisper.fromSeat));
      } else if (whisper.fromSeat == me) {
        _audio.play(AudioCue.whisperSend);
      }
    }
  }

  /// Fetches the body of a whisper that has just arrived for this device.
  ///
  /// The graph is public and arrives with the fold; the body lives behind a
  /// row only the two parties may read, so it takes a round trip. A failure is
  /// swallowed on purpose: a whisper whose body cannot be fetched is a whisper
  /// that did not arrive, and the sender is already told that separately.
  Future<void> _pullWhisper(GameSnapshot snapshot, int fromSeat) async {
    if (_pulling || _incoming != null) return;
    _pulling = true;
    try {
      final delivery = await _controller.pullViewerWhisper();
      if (!mounted) return;
      if (delivery == null || delivery.id == null) return;
      if (delivery.isUndeliveredNotice) return;
      final sender = snapshot.public.players
          .where((p) => p.seat == fromSeat)
          .map((p) => p.name)
          .firstOrNull;
      setState(
        () => _incoming = _Incoming(
          id: delivery.id!,
          senderName: sender ?? '',
          body: delivery.body,
        ),
      );
    } on Object {
      // Nothing to say and nowhere to say it. See above.
    } finally {
      _pulling = false;
    }
  }

  /// Whether the match has reached its result.
  bool _matchOver(GameSnapshot snapshot) =>
      snapshot.phase == GamePhase.result ||
      snapshot.phase == GamePhase.analytics;

  /// Whether this device's own player is out of the match.
  /// Keeps the open table fresh while this viewer is a witness. Night choices
  /// change nothing the snapshot carries, so they are read on a beat rather
  /// than waited for.
  void _syncWitness(bool watching) {
    final channel = _controller.transport.witness;
    if (!watching || channel == null) {
      _witnessPoll?.cancel();
      _witnessPoll = null;
      return;
    }
    if (_witnessPoll != null) return;
    Future<void> pull() async {
      final table = await channel.table();
      if (!mounted || table == null) return;
      final news = witnessNewsSince(_witnessTable, table);
      setState(() {
        _witnessTable = table;
        _newsQueue.addAll(news);
      });
      _nextNews();
    }

    unawaited(pull());
    _witnessPoll = Timer.periodic(MafiaTiming.witnessRefresh, (_) => pull());
  }

  /// Puts the next line of the dead's news over the table, and flies a night
  /// choice from the seat that made it to the seat it chose. Whispers already
  /// fly for everybody from the snapshot's whisper graph.
  void _nextNews() {
    if (_news != null || _newsQueue.isEmpty || !mounted) return;
    final news = _newsQueue.removeAt(0);
    setState(() => _news = news);
    if (news.action != null && _spark == null) {
      _flyWhisper(news.fromSeat, news.toSeat);
    }
    _newsTimer?.cancel();
    _newsTimer = Timer(MafiaTiming.witnessNewsHold, () {
      if (!mounted) return;
      setState(() => _news = null);
      _nextNews();
    });
  }

  void _openLetter(WitnessWhisper whisper) => setState(() {
    _openedLetters.add(whisper.id);
    _dossier = null;
    _witnessPage = null;
    _letter = whisper;
  });

  Map<int, String> _names(GameSnapshot snapshot) => {
    for (final player in snapshot.public.players) player.seat: player.name,
  };

  /// Every other seat has left the room while the match is still running.
  bool _abandoned(GameSnapshot snapshot) {
    if (_matchOver(snapshot) || snapshot.phase == GamePhase.setup) return false;
    final others = [
      for (final p in snapshot.public.players)
        if (p.seat != snapshot.viewerSeat) p.seat,
    ];
    return others.isNotEmpty &&
        others.every((seat) => snapshot.presence[seat] == SeatPresence.left);
  }

  /// Night one, and this player is a Citizen: nothing has happened yet, so a
  /// suspicion would be a guess about nothing (owner, 2026-09-23).
  bool _citizenRests(GameSnapshot snapshot, MatchUiState state) =>
      snapshot.phase == GamePhase.night &&
      snapshot.dayNumber <= 1 &&
      state.actorTurn?.actorRole == Role.citizen;

  Widget _ownCard(BuildContext context, Role role) => SizedBox(
    height: CouncilTokens.nightOwnCardHeight,
    child: CardArt(image: faceFor(role), radius: context.radii.card),
  );

  bool _viewerIsDead(GameSnapshot snapshot) {
    final seat = snapshot.viewerSeat;
    if (seat == null) return false;
    return snapshot.public.players.any(
      (p) => p.seat == seat && p.status == PlayerStatus.dead,
    );
  }

  // ── commands ─────────────────────────────────────────────────────────────

  void _pick(int seat) {
    if (_submitted) return;
    Haptics.select();
    setState(() => _selected = _selected == seat ? null : seat);
  }

  Future<void> _attempt(Future<void> Function() action) async {
    if (_submitted) return;
    final phase = _snapshot.phase;
    final day = _snapshot.dayNumber;
    final round = _snapshot.ballotRound;
    setState(() {
      _submitted = true;
      _acknowledged = false;
      _actionFailed = false;
    });
    try {
      await action();
      if (!mounted ||
          _snapshot.phase != phase ||
          _snapshot.dayNumber != day ||
          _snapshot.ballotRound != round) {
        return;
      }
      if (phase == GamePhase.voting && !_snapshot.viewerVoteRecorded) {
        throw const BackendException('ACTION_NOT_SAVED', 'No ballot receipt');
      }
      setState(() => _acknowledged = true);
      widget.onStepCommitted();
    } on BackendUnreachable {
      // The room was never told. Reported exactly as a refusal is, because to
      // the player they are the same fact: the choice did not land, and it can
      // be made again.
      if (!mounted ||
          _snapshot.phase != phase ||
          _snapshot.dayNumber != day ||
          _snapshot.ballotRound != round) {
        return;
      }
      setState(() {
        _submitted = false;
        _actionFailed = true;
        _attemptNumber++;
      });
    } on BackendException {
      if (!mounted ||
          _snapshot.phase != phase ||
          _snapshot.dayNumber != day ||
          _snapshot.ballotRound != round) {
        return;
      }
      setState(() {
        _submitted = false;
        _actionFailed = true;
        _attemptNumber++;
      });
    }
  }

  Future<void> _confirmNight() => _attempt(() async {
    final seat = _snapshot.viewerSeat;
    final turn = ref.read(matchControllerProvider)?.actorTurn;
    if (seat == null || turn == null) return;

    final target = _selected;
    if (target == null && turn.actorRole == Role.doctor) {
      throw const BackendException('BAD_REQUEST', 'Choose a player to protect');
    }
    if (target == null) {
      // A turn with no choice, which **every** role may take (doc 05 rules 5
      // and 6). It is the same command, the same duration and the same
      // confirmation as a turn with one — a role that could not decline would
      // be a role you could identify by the fact that it never did.
      //
      // For the Mafia it is also «الليلة الهادية» when they still hold it: the
      // decline *is* the move, and it is what makes the morning ambiguous. For
      // the other three it is simply declining.
      await _controller.skipNightAction(
        useBullet:
            turn.actorRole == Role.mafia &&
            _controller.bulletExistsFor(Role.mafia) &&
            !_controller.currentBulletSpent,
      );
    } else {
      await _controller.submitNightAction(
        kind: turn.actorRole.nightAction,
        targetSeat: target,
        // The Doctor choosing their own seat is the self-protection, and it is
        // the only reason a night action may name its own actor. The server
        // checks the same three things again with the service key.
        useBullet: target == seat && _canSelfProtect(turn.actorRole),
      );
    }
  });

  /// Whether this client's own seat is a legal target tonight.
  ///
  /// Offline this is a tile in the night grid bearing the Doctor's own name,
  /// among the names (doc 14 §4). The online table has no grid to put a tile
  /// in, so the affordance is the one every other target already has: the seat
  /// itself, tappable. Same rule, same three conditions, drawn by the surface
  /// each mode actually has.
  bool _canSelfProtect(Role role) =>
      role == Role.doctor &&
      _controller.bulletExistsFor(Role.doctor) &&
      !_controller.currentBulletSpent;

  void _confirmAccusation() {
    final target = _selected;
    if (target == null) return;
    _attempt(() => _controller.submitOpeningAccusation(targetSeat: target));
  }

  void _confirmVote({required bool abstaining}) {
    _attempt(
      () => _controller.submitVote(targetSeat: abstaining ? null : _selected),
    );
  }

  /// Flies a light from this seat to [toSeat] (doc 12 §3.7).
  ///
  /// Everybody sees the light; nobody sees the words. This is the sender's own
  /// copy of it — the recipients see the same flight from their own snapshot's
  /// whisper graph a moment later.
  void _flyWhisper(int fromSeat, int toSeat) {
    setState(
      () => _spark = CouncilSpark(
        fromSeat: fromSeat,
        toSeat: toSeat,
        progress: 0,
      ),
    );
    _sparkFlight.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _spark = null);
    });
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchControllerProvider);
    final voice = ref.watch(voiceStateProvider).valueOrNull;
    if (state == null) return const SizedBox.shrink();

    final snapshot = _snapshot;
    // Task 5. A room that was closed was not a room that was won, so there is
    // no result screen to land on — this device goes home and says why. Once:
    // `_leaving` is what stops a rebuild queuing a second exit.
    // Task 6. Being removed is not a disconnection and there is nothing to
    // come back to: the room code is barred, so this device says so and goes
    // home rather than sitting on a table it is not part of.
    if (snapshot.viewerKicked && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.onlineKickedByHost)),
        );
        // Through the session, not straight home: the transport, the voice
        // link and the resume pointer all go with the seat. A removed player
        // used to keep all three, and the pointer offered them the barred
        // room again on the next launch.
        await ref.read(onlineSessionProvider.notifier).leave();
        if (mounted) widget.onExit();
      });
    }
    if (snapshot.roomClosed && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(onlineSessionProvider.notifier).leave();
        if (mounted) widget.onExit();
      });
    }
    _syncPhase(snapshot);
    if (snapshot.phase == GamePhase.voting && snapshot.viewerVoteRecorded) {
      _submitted = true;
      _acknowledged = true;
      _actionFailed = false;
    }
    _maybePullPrivateView(snapshot, state);
    if (_citizenRests(snapshot, state) &&
        !_submitted &&
        _restSentDay != snapshot.dayNumber) {
      _restSentDay = snapshot.dayNumber;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _attempt(() => _controller.skipNightAction(useBullet: false));
        }
      });
    }
    _syncSounds(snapshot);

    final dead = _viewerIsDead(snapshot);
    // Not when the vote that put you out also ended the match: the result is
    // the moment then, and «خرجت من المباراة» drawn over «الشعب كسب» read as
    // two screens on top of each other.
    // A night death reaches this phone before the morning does. The beat
    // waits for the morning — and for the scare the morning brings — rather
    // than starting in the dark and being cut in half by it.
    final stillNight =
        snapshot.phase == GamePhase.night ||
        snapshot.phase == GamePhase.nightResolving;
    if (dead &&
        !_mourned &&
        !_mourning &&
        !stillNight &&
        !_matchOver(snapshot)) {
      _mourning = true;
    }

    _syncWitness(dead && _mourned && !_matchOver(snapshot));

    final witnessing = dead && _mourned && !_matchOver(snapshot);
    final table = TableScene(
      snapshot: snapshot,
      witnessRoles: _witnessTable?.roles ?? const {},
      seatMarks: witnessing
          ? witnessSeatMarks(
              snapshot: snapshot,
              table: _witnessTable,
              opened: _openedLetters,
              onOpenLetter: _openLetter,
              onOpenSeat: (seat) => setState(() => _dossier = seat),
            )
          : const {},
      speakingLevels: voice?.speakingLevels ?? const {},
      selectedSeat: _selected,
      selectableSeats: _selectable(snapshot, state),
      onSeatTap: _pick,
      centre: _centre(context, snapshot, state),
      spark: _spark == null
          ? null
          : CouncilSpark(
              fromSeat: _spark!.fromSeat,
              toSeat: _spark!.toSeat,
              progress: _sparkFlight.value,
            ),
      tearingSeat: _tearingSeat,
      tearProgress: _tear.value,
      spotlight: _spotlight.value,
      onCloseRoom: snapshot.canAdvance
          ? () => setState(() => _closing = true)
          : null,
      // A witness taps a seat to open its dossier; a dead host manages the
      // seat from inside it.
      onSeatInspect: witnessing && _witnessTable != null
          ? (seat) => setState(() => _dossier = seat)
          : snapshot.canAdvance
          ? (seat) => setState(() => _inspect = seat)
          : null,
      revealProgress: _turn.value,
      // Doc 15 §S-O14: a witness keeps the four bands. Band 4 stops being the
      // one action and becomes the graveyard, the prediction and the record —
      // which is doc 12 §4's "three things to do, not none", in the place the
      // living player's control was.
      //
      // Not once the match is over, though: the witness panel asks «مين
      // هيكسب؟» of an outcome already on the table, and it stood in front of
      // the result's own two controls — a seat put out at the last ballot had
      // no «الرئيسية» to press.
      // The witness panel is a side sheet now (see below); the hand is empty
      // for a witness so the table keeps the room.
      footer: witnessing
          ? WitnessDock(
              onChat: () => setState(() {
                _letter = null;
                _dossier = null;
                _witnessPage = WitnessPanelTab.chat;
              }),
              onRecord: () => setState(() {
                _letter = null;
                _dossier = null;
                _witnessPage = WitnessPanelTab.record;
              }),
            )
          : _footer(context, snapshot, state),
    );

    // Doc 12 §4.2 beat 4: the table returns, in monochrome. Permanent for a
    // witness, which is what makes being dead read as a *state* rather than as
    // an ending.
    //
    // The grey drains in over the beat rather than arriving in one frame, and
    // the table keeps its identity while the filter goes on: without the key,
    // wrapping it re-created every seat and restarted every animation on it.
    //
    // Owner, 2026-09-28: the grey is the beat, not the state. Once it has
    // played, the colour comes back and the witness watches the table they
    // were playing at, every seat wearing its character's face.
    final grey = dead && !_mourned && _mourning && _sting == null && !_scaring;
    final ground = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: grey ? 1 : 0),
      duration: ReduceMotion.of(context)
          ? Duration.zero
          : context.timing.eliminationDrain,
      child: KeyedSubtree(key: _tableKey, child: table),
      builder: (context, drain, child) => drain == 0
          ? child!
          : ColorFiltered(
              colorFilter: ColorFilter.matrix(
                ConnectionWeather.saturationMatrix(drain),
              ),
              child: child,
            ),
    );

    return ConnectionWeather(
      weather: TableWeather.of(snapshot.connection),
      onPlayOffline: widget.onExit,
      onRetry: () => unawaited(_controller.transport.resync()),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ground,
          // After the dawn curtain, never on top of it: two overlays with two
          // sentences at once read as neither.
          if (_mourning && _sting == null && !_scaring && !_matchOver(snapshot))
            EliminationBeat(
              onFinished: () => setState(() {
                _mourning = false;
                _mourned = true;
              }),
            ),
          // The role card is the one thing that legitimately covers the table:
          // doc 12 §3.2 beat 2 is your card *lifting out of its seat toward the
          // camera*, so for the length of the reveal it is the whole screen.
          if (snapshot.phase == GamePhase.distributing && state.reveal != null)
            _reveal(context, state),
          // Doc 15 §S-O12 beats 2–5, over the council rather than instead of
          // it: the seat the card came out of is still there underneath, which
          // is what makes the ring cracking at the end read as the same
          // person.
          if (_sting != null)
            PhaseSting(
              key: ValueKey('sting-${snapshot.phase}-${snapshot.dayNumber}'),
              light: _sting!,
              title: _sting == PhaseLight.dusk
                  ? context.l10n.nightNumbered(snapshot.dayNumber)
                  : context.l10n.dayNumbered(snapshot.dayNumber),
              onFinished: () {
                if (mounted) setState(() => _sting = null);
              },
            ),
          ?_verdict(context, snapshot),
          // Loaded during every night by every player who could still be the
          // victim, so the scare lands on the morning's first frame; thrown
          // away unplayed when the morning names somebody else.
          if (_scaring ||
              (!_mourned &&
                  !ReduceMotion.of(context) &&
                  _scaredDay != snapshot.dayNumber &&
                  (snapshot.phase == GamePhase.night ||
                      snapshot.phase == GamePhase.nightResolving)))
            KillJumpscare(
              key: const ValueKey('kill_jumpscare'),
              armed: _scaring,
              muted: _audio.muted,
              onFinished: () {
                if (mounted) setState(() => _scaring = false);
              },
            ),
          // Above the curtain and the verdict: an open sheet is where the
          // witness is looking, and a title drawn across it read as clutter.
          if (witnessing && _witnessTable != null) ...[
            if (_news case final news?)
              PositionedDirectional(
                top:
                    MediaQuery.paddingOf(context).top +
                    CouncilTokens.headerHeight +
                    context.spacing.sm,
                start: context.spacing.screenMargin,
                end: context.spacing.screenMargin,
                child: AnimatedSwitcher(
                  duration: ReduceMotion.of(context)
                      ? Duration.zero
                      : context.motion.band,
                  transitionBuilder: bandTransition,
                  child: WitnessNewsLine(
                    key: ValueKey(news.id),
                    news: news,
                    table: _witnessTable!,
                    names: _names(snapshot),
                    onTap: switch (news.whisper) {
                      final whisper? => () => _openLetter(whisper),
                      null => () => setState(() => _dossier = news.toSeat),
                    },
                  ),
                ),
              ),
            if (_dossier case final seat?)
              WitnessPopup(
                onDismiss: () => setState(() => _dossier = null),
                child: WitnessDossier(
                  seat: seat,
                  snapshot: snapshot,
                  table: _witnessTable!,
                  onOpenLetter: _openLetter,
                  onManage: snapshot.canAdvance
                      ? () => setState(() {
                          _dossier = null;
                          _inspect = seat;
                        })
                      : null,
                ),
              ),
            if (_letter case final letter?)
              WitnessPopup(
                onDismiss: () => setState(() => _letter = null),
                child: WitnessLetter(
                  key: ValueKey('letter-${letter.id}'),
                  whisper: letter,
                  table: _witnessTable!,
                  names: _names(snapshot),
                  channel: _controller.transport.witness,
                ),
              ),
          ],
          if (witnessing && _witnessPage != null)
            WitnessPopup(
              fill: true,
              onDismiss: () => setState(() => _witnessPage = null),
              child: VaultCard(
                lit: true,
                padding: EdgeInsets.zero,
                children: [
                  Expanded(
                    child: WitnessPanel(
                      only: _witnessPage,
                      snapshot: snapshot,
                      channel: _controller.transport.witness,
                      table: _witnessTable,
                    ),
                  ),
                ],
              ),
            ),
          if (_composing) _composer(context, snapshot),
          if (_roster)
            RoleRoster(
              standings: snapshot.standings,
              cosmetics: snapshot.seatCosmetics,
              onClose: () => setState(() => _roster = false),
            ),
          if (_whispers && _matchOver(snapshot))
            if (ref.read(onlineSessionProvider).room?.roomId case final id?)
              RevealedWhispers(
                roomId: id,
                names: _names(snapshot),
                onClose: () => setState(() => _whispers = false),
              ),
          // Task 5 — one line, three seconds, over whatever is on screen. It
          // is not a phase and it does not stop anything.
          // Task 6 — the host's two moderation actions, in the scene.
          HostSheet(
            snapshot: snapshot,
            transport: ref.read(onlineSessionProvider).transport,
            seat: _inspect,
            onDismiss: () => setState(() => _inspect = null),
          ),
          // Task 5 — the deliberate ending, never the accidental one.
          // Everybody else has gone. A match with one person left at the table
          // is not a match; say so and offer the way home rather than run the
          // clocks on for nobody (owner, 2026-09-23).
          SceneSheet(
            visible: _abandoned(snapshot),
            title: context.l10n.onlineAbandonedTitle,
            body: context.l10n.onlineAbandonedBody,
            onDismiss: () {},
            actions: [
              SceneAction(
                key: const ValueKey('table_abandoned_home'),
                label: context.l10n.homeAction,
                emphasised: true,
                onTap: () async {
                  final transport = ref.read(onlineSessionProvider).transport;
                  if (snapshot.canAdvance) await transport?.closeRoom();
                  await ref.read(onlineSessionProvider.notifier).leave();
                  if (mounted) widget.onExit();
                },
              ),
            ],
          ),
          SceneSheet(
            visible: _closing,
            title: context.l10n.onlineHostExitTitle,
            body: context.l10n.onlineHostExitBody,
            onDismiss: () => setState(() => _closing = false),
            actions: [
              SceneAction(
                key: const ValueKey('table_leave_keep_room'),
                label: context.l10n.onlineLeaveKeepRoom,
                emphasised: true,
                onTap: () async {
                  setState(() => _closing = false);
                  await ref.read(onlineSessionProvider.notifier).leave();
                  if (mounted) widget.onExit();
                },
              ),
              SceneAction(
                key: OnlineTableFlow.closeRoomConfirm,
                label: context.l10n.onlineCloseRoomConfirm,
                emphasised: true,
                onTap: () {
                  setState(() => _closing = false);
                  ref.read(onlineSessionProvider).transport?.closeRoom();
                },
              ),
            ],
          ),
          HostHandover(snapshot: snapshot),
          // Doc 14 §3.4. Over the table, never instead of it: the timer and
          // the seats stay live underneath, because a whisper is a thing that
          // happens *during* the argument.
          if (_incoming != null)
            WhisperCard(
              key: ValueKey(_incoming!.id),
              senderName: _incoming!.senderName,
              body: _incoming!.body,
              onDismissed: () {
                final id = _incoming!.id;
                setState(() => _incoming = null);
                _controller.markWhisperDelivered(id);
              },
            ),
        ],
      ),
    );
  }

  // ── which seats may be tapped ────────────────────────────────────────────

  /// The seats this client may choose right now.
  ///
  /// Everything else stays drawn and inert. A table that hid the seats you
  /// cannot pick would tell the room which seats those are — and during a night
  /// the set of legal targets is a fact about the actor's role.
  Set<int> _selectable(GameSnapshot snapshot, MatchUiState state) {
    if (_submitted || _viewerIsDead(snapshot)) return const {};
    return switch (snapshot.phase) {
      GamePhase.night => {
        ...?state.actorTurn?.targets,
        // `turnFor` builds the target list out of the *other* living seats,
        // which is right for every role and every night but one move. The
        // Doctor's self-protection is that move, and adding the seat here
        // rather than there keeps the transport's view of a turn free of a
        // rule it would otherwise have to know about bullets.
        if (state.actorTurn != null &&
            snapshot.viewerSeat != null &&
            _canSelfProtect(state.actorTurn!.actorRole))
          snapshot.viewerSeat!,
      },
      GamePhase.openingRound || GamePhase.voting => {
        for (final p in snapshot.public.players)
          if (p.status == PlayerStatus.alive &&
              p.seat != snapshot.viewerSeat &&
              (snapshot.phase != GamePhase.voting ||
                  snapshot.ballotRound == 1 ||
                  snapshot.ballotCandidates.contains(p.seat)))
            p.seat,
      },
      _ => const {},
    };
  }

  // -- band 3: the voice ----------------------------------------------------

  /// Doc 15 Band 3: one idea per phase, and at most one thing supporting it.
  ///
  /// The old centre was a stack of independently-placed strings, which is how
  /// it ended up overlapping. [CouncilVoice] is the layout contract that
  /// replaced it: a headline and a single support slot, with no third place to
  /// put anything.
  Widget? _centre(
    BuildContext context,
    GameSnapshot snapshot,
    MatchUiState state,
  ) {
    final l10n = context.l10n;
    final type = context.typography;
    final colors = context.colors;
    final names = {
      for (final player in snapshot.public.players) player.seat: player.name,
    };

    /// Doc 15 §1.6's third selection signal, and the only one that spells the
    /// name out. Null when nothing is chosen, so the slot stays empty rather
    /// than holding a placeholder.
    Widget? chosen() {
      final name = names[_selected];
      return name == null
          ? null
          : SelectionChip(label: l10n.onlineChosen(name));
    }

    Widget caption(String text) => Text(
      text,
      textAlign: TextAlign.center,
      style: type.caption.copyWith(color: colors.textSecondary),
    );

    // A witness has no move to be told about. What they get instead is the
    // headline of what the table is doing right now.
    if (_viewerIsDead(snapshot) && _mourned && !_matchOver(snapshot)) {
      final headline = switch (snapshot.phase) {
        GamePhase.night || GamePhase.nightResolving => l10n.witnessEventNight,
        GamePhase.openingRound =>
          names[snapshot.currentActorSeat] == null
              ? l10n.openingRoundTitle
              : l10n.witnessEventOpening(names[snapshot.currentActorSeat]!),
        GamePhase.discussion => l10n.witnessEventDiscussion,
        GamePhase.voting => l10n.witnessEventVoting,
        _ => null,
      };
      if (headline != null) {
        final tally = snapshot.phase == GamePhase.voting
            ? _tally(snapshot)
            : const <({String name, int votes})>[];
        return CouncilVoice(
          headline: headline,
          support: tally.isEmpty
              ? null
              : VoteTally(rows: tally, peak: tally.first.votes),
        );
      }
    }

    switch (snapshot.phase) {
      case GamePhase.setup:
      case GamePhase.rolesConfigured:
        return null;

      case GamePhase.distributing:
        // Doc 05: a COUNT only, never a name. A Mafia card carries the
        // teammate list, so dwell on it is a role signal; a live per-seat
        // "still looking" indicator would hand that signal to the table.
        final waiting = snapshot.unseenRoleSeats.length;
        if (waiting == 0) return null;
        return CouncilVoice(headline: l10n.onlineWaitingForCards(waiting));

      case GamePhase.preNightLobby:
        return CouncilVoice(headline: l10n.onlineWaitingForTheRest);

      case GamePhase.night:
      case GamePhase.nightResolving:
        final turn = state.actorTurn;
        // Your own card, small, over whatever the night asks of you: the one
        // thing every player looks at first (owner, 2026-09-23). Every role
        // gets the same slot and the same size — only the art differs.
        final own = turn == null ? null : _ownCard(context, turn.actorRole);
        if (_citizenRests(snapshot, state)) {
          return CouncilVoice(
            leading: own,
            headline: l10n.nightCitizenRest,
            support: caption(l10n.nightCitizenRestSupport),
          );
        }
        // No count and no names while the night runs. Doc 15 §S-O5: "how many
        // are still to act" is a fact about how many people have a move, and
        // that is a fact about roles.
        if (turn == null || _submitted) {
          return CouncilVoice(
            leading: own,
            headline: l10n.onlineWaitingForTheRest,
          );
        }
        return CouncilVoice(
          leading: own,
          headline: EngineCopy.nightPrompt(l10n, turn.actorRole),
          support: chosen(),
        );

      case GamePhase.morning:
        final victim = snapshot.morning?.victimSeat;
        final trace = InformationText.trace(l10n, snapshot.trace, names);
        return CouncilVoice(
          headline: victim == null
              ? l10n.quietNight
              : l10n.lostPlayerLastNight(names[victim] ?? ''),
          // The trace does not arrive with the body. Doc 15 §S-O6 beat 5: the
          // room hears what happened, and only then hears what was left
          // behind.
          support: trace == null ? null : _AfterBeat(child: caption(trace)),
        );

      case GamePhase.openingRound:
        final speaker = names[snapshot.currentActorSeat];
        final queue = _upNext(snapshot);
        return CouncilVoice(
          headline: speaker == null
              ? l10n.openingRoundTitle
              : l10n.openingRoundPrompt(speaker),
          // Your own choice outranks the queue: once you have picked, the one
          // thing you want confirmed is who.
          support:
              chosen() ??
              (queue.isEmpty ? null : caption(l10n.onlineUpNext(queue))),
        );

      case GamePhase.confrontation:
        final confrontation = snapshot.confrontation;
        if (confrontation == null) return null;
        final deadline = snapshot.phaseDeadline;
        return CouncilVoice(
          // `title`, not `headline`: doc 15 §1.4 gives this phase the ring, and
          // two things shouting at once is the old screen's mistake.
          style: type.title,
          headline:
              InformationText.confrontation(l10n, confrontation, names) ??
              l10n.confrontationExplain,
          support: deadline == null
              ? null
              : _ConfrontationClock(
                  deadline: deadline,
                  total: snapshot.settings.confrontationSeconds,
                ),
        );

      case GamePhase.discussion:
        // Doc 15 §1.4, resolved 2026-09-07. Two real things and no third: the
        // floor, and the hands. There is still no queue — `micPolicyFor` hands
        // the floor out on request rather than in an order — so the hands go
        // up in seat order and carry no numbers. Whoever claims next wins on
        // their own merits, and the band never suggests otherwise.
        final speaker = names[snapshot.activeSpeakerSeat];
        final hands = _handsUp(snapshot, names);
        final support = hands == null
            ? null
            : caption(l10n.onlineRaisedHands(hands));
        // Nobody holding the floor is a fact of its own, not «الدور على»
        // trailing off into a blank: the label used to dangle over an empty
        // line for the whole discussion until somebody asked to speak.
        if (speaker == null) {
          return CouncilVoice(headline: l10n.onlineFloorOpen, support: support);
        }
        // The speaker is already the glowing seat. A name printed large in the
        // middle of the table read as an accusation (owner, 2026-09-23).
        return CouncilVoice(
          headline: l10n.onlineDiscussionLive,
          support: support,
        );

      case GamePhase.voting:
      case GamePhase.voteResolving:
        final tally = _tally(snapshot);
        return CouncilVoice(
          headline: snapshot.phase == GamePhase.voteResolving
              ? l10n.onlineVoteResolving
              : _submitted
              ? (_acknowledged
                    ? l10n.onlineVoteReceived
                    : l10n.onlineVoteSending)
              : snapshot.ballotRound > 1
              ? l10n.tieRevoteHeadline
              : l10n.whoDoYouVoteOut,
          // Public ballots become the bars; a secret ballot leaves `tally`
          // empty and the band falls back to your own choice. Neither branch
          // reads a setting: an empty `liveBallots` *is* the secret ballot.
          support: tally.isEmpty
              ? (_submitted || snapshot.phase == GamePhase.voteResolving
                    ? null
                    : chosen() ?? caption(l10n.onlineVoteSelectHint))
              : VoteTally(rows: tally, peak: tally.first.votes),
        );

      case GamePhase.reveal:
      case GamePhase.winCheck:
        final vote = snapshot.lastVote;
        if (vote == null) return null;
        final seat = vote.eliminatedSeat;
        if (seat == null) {
          // A completed verdict with no elimination does not imply a revote.
          // The server may have resolved abstention or the configured tie rule.
          return CouncilVoice(
            headline: vote.tie
                ? l10n.tieNoEliminationHeadline
                : l10n.nobodyEliminated,
          );
        }
        final role = vote.eliminatedRole;
        return CouncilVoice(
          headline: names[seat] ?? '',
          style: type.display,
          support: role == null
              ? null
              : caption(EngineCopy.roleName(l10n, role)),
        );

      case GamePhase.result:
      case GamePhase.analytics:
        final winner = snapshot.outcome?.winner ?? snapshot.pendingOutcome;
        if (winner == null) return null;
        final mafiaWon = winner == Alignment.mafia;
        return Stack(
          alignment: AlignmentDirectional.center,
          children: [
            const IgnorePointer(
              child: MotionSprite(
                AppMotion.emberDrift,
                width: MotionTokens.emberWidth,
                height: MotionTokens.emberHeight,
              ),
            ),
            CouncilVoice(
              headline: mafiaWon ? l10n.mafiaWins : l10n.townWins,
              style: type.display,
              support: VictoryEmblem(mafiaWon: mafiaWon),
            ),
          ],
        );
    }
  }

  /// The seats the opening round has still to hear from, in seat order.
  ///
  /// Derived from `openingAccusations`, which is public and complete: it is
  /// the record of who has already named somebody. Nothing here is inferred —
  /// a seat is either in that map or it is not.
  /// Who has asked for the floor, in **seat order**, or null when nobody has.
  ///
  /// Seat order is the point. Sorting these by when they asked would print the
  /// queue doc 15 §1.4 spent a whole section removing, because a reader who
  /// sees two names in a row reads the first one as next — and the server does
  /// not decide it that way. Seat order carries no such claim: it is the same
  /// order the council is already drawn in.
  ///
  /// Null rather than an empty string, so band 3 renders one element instead of
  /// a headline over a blank line.
  String? _handsUp(GameSnapshot snapshot, Map<int, String> names) {
    final up = snapshot.raisedHands.toList()..sort();
    final labels = [
      for (final seat in up)
        if (names[seat] != null) names[seat]!,
    ];
    return labels.isEmpty ? null : labels.join(' · ');
  }

  String _upNext(GameSnapshot snapshot) {
    final speaking = snapshot.currentActorSeat;
    final waiting = [
      for (final player in snapshot.public.players)
        if (player.status == PlayerStatus.alive &&
            player.seat != speaking &&
            !snapshot.openingAccusations.containsKey(player.seat))
          player.name,
    ];
    // Two names. A full roster read back at caption size is the wall of text
    // doc 15 Part 0 was written against.
    return waiting.take(2).join(' · ');
  }

  /// The open ballot as rows, heaviest first.
  ///
  /// Empty whenever the room chose a secret ballot, because the server never
  /// sends the rows in that case. There is no branch on the setting here, and
  /// there must not be one: the absence of data is the enforcement.
  List<({String name, int votes})> _tally(GameSnapshot snapshot) {
    if (snapshot.liveBallots.isEmpty) return const [];
    final counts = <int, int>{};
    for (final target in snapshot.liveBallots.values) {
      if (target != null) counts[target] = (counts[target] ?? 0) + 1;
    }
    final rows = [
      for (final player in snapshot.public.players)
        if (counts[player.seat] != null)
          (name: player.name, votes: counts[player.seat]!),
    ]..sort((a, b) => b.votes.compareTo(a.votes));
    return rows;
  }

  // -- band 4: your hand ----------------------------------------------------

  /// Doc 15 §1.5: **one** primary action, in the same place every phase.
  ///
  /// The hints the old footer carried have moved up into band 3, where they
  /// are the headline. A footer that repeated them was the second half of the
  /// overlapping-strings problem: the same sentence, twice, in two type sizes.
  /// When there is nothing for this device to do, there is no button — the
  /// band holds your own seat and nothing else.
  Widget? _footer(
    BuildContext context,
    GameSnapshot snapshot,
    MatchUiState state,
  ) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final l10n = context.l10n;

    final action = _action(context, snapshot, state);
    if (action == null && !_actionFailed) return null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_actionFailed)
            Text(
              l10n.actionNotSaved,
              style: type.caption.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          if (action != null) ...[
            if (_actionFailed) SizedBox(height: spacing.xs),
            // Flexible, so the hand's bounded height reaches the action. A
            // plain child of a Column is laid out with unbounded height, and
            // the result's scroll view then grew to its full content and
            // overflowed the band instead of scrolling.
            Flexible(child: action),
          ],
        ],
      ),
    );
  }

  Widget? _action(
    BuildContext context,
    GameSnapshot snapshot,
    MatchUiState state,
  ) {
    final l10n = context.l10n;
    final spacing = context.spacing;

    switch (snapshot.phase) {
      case GamePhase.night:
        final turn = state.actorTurn;
        if (turn == null || _submitted || _citizenRests(snapshot, state)) {
          return null;
        }
        // Held, not tapped. The confirm is the one irreversible move of the
        // night, and a hold is what stops a thumb resting on a phone from
        // making it (doc 12 §3.3).
        return Center(
          key: OnlineTableFlow.confirmAction,
          child: IgnorePointer(
            ignoring: turn.actorRole == Role.doctor && _selected == null,
            child: HoldPad(
              key: ValueKey('night-confirm-$_attemptNumber'),
              holdDuration: context.timing.holdToReveal,
              instruction: l10n.onlineConfirmHold,
              onHoldComplete: _confirmNight,
              diameter: spacing.xxl * 2,
            ),
          ),
        );

      case GamePhase.openingRound:
        if (_submitted) return null;
        return FilledButton(
          key: OnlineTableFlow.confirmAction,
          onPressed: _selected == null ? null : _confirmAccusation,
          child: Text(l10n.onlineConfirmSuspicion),
        );

      case GamePhase.confrontation:
        // The audience has no move. Band 3 is already telling them what is
        // being answered, so the hand stays empty rather than holding a
        // sentence dressed as a control.
        if (snapshot.confrontation?.targetSeat != snapshot.viewerSeat) {
          return null;
        }
        return FilledButton(
          key: OnlineTableFlow.confrontationDone,
          onPressed: () {
            _controller.endConfrontation(silent: false);
            widget.onStepCommitted();
          },
          child: Text(l10n.confrontationDone),
        );

      case GamePhase.voting:
        if (_submitted) return null;
        final abstainAllowed = snapshot.settings.abstainAllowed;
        final confirm = FilledButton(
          key: OnlineTableFlow.confirmAction,
          onPressed: _selected == null
              ? null
              : () => _confirmVote(abstaining: false),
          child: Text(l10n.confirmVote),
        );
        if (!abstainAllowed) return confirm;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            confirm,
            TextButton(
              key: OnlineTableFlow.abstain,
              onPressed: () => _confirmVote(abstaining: true),
              child: Text(l10n.abstain),
            ),
          ],
        );

      case GamePhase.discussion:
        // No host control (owner decision 2026-09-23): the discussion ends on
        // its own clock, the same moment for everybody, and the ballot opens
        // by itself. The host set that clock when they set up the room.
        // …or earlier, when every living player has said they are ready
        // (owner, 2026-09-24). The count is public; so is who has said it.
        final living = snapshot.public.players
            .where((p) => p.status == PlayerStatus.alive)
            .length;
        final ready = snapshot.readyToVoteSeats;
        final mine =
            snapshot.viewerSeat != null && ready.contains(snapshot.viewerSeat);
        final Widget? readyButton = _viewerIsDead(snapshot)
            ? null
            : (mine ? OutlinedButton.new : FilledButton.new)(
                key: OnlineTableFlow.readyToVote,
                onPressed: () => unawaited(
                  _controller.setReadyToVote(!mine).catchError((_) {}),
                ),
                child: Text(
                  mine
                      ? l10n.readyToVoteWaiting(ready.length, living)
                      : l10n.readyToVote(ready.length, living),
                ),
              );

        Widget? whisper;
        if (snapshot.settings.whisperEnabled && snapshot.viewerSeat != null) {
          final spent = snapshot.whisperGraph.any(
            (w) => w.fromSeat == snapshot.viewerSeat && !w.voided,
          );
          whisper = FilledButton.icon(
            key: OnlineTableFlow.whisperButton,
            onPressed: spent ? null : () => setState(() => _composing = true),
            icon: Image.asset(
              AppCouncilArt.whisperSeal,
              width: context.spacing.lg,
              height: context.spacing.lg,
              color: context.colors.textPrimary,
              excludeFromSemantics: true,
            ),
            label: Text(
              spent ? l10n.whisperAlreadySentToday : l10n.whisperCompose,
            ),
          );
        }

        if (readyButton == null) return whisper;
        if (whisper == null) return readyButton;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            whisper,
            SizedBox(height: spacing.sm),
            readyButton,
          ],
        );

      case GamePhase.distributing:
        // Everybody's button, not the host's. The server refuses the night
        // until the last card is dismissed, so the gate is enforced there and
        // shown here — disabled while anyone is still looking, live for the
        // whole room the moment the last one is not.
        return FilledButton(
          key: OnlineTableFlow.hostAdvance,
          onPressed: snapshot.unseenRoleSeats.isEmpty
              ? () {
                  _controller.advancePhase();
                  widget.onStepCommitted();
                }
              : null,
          child: Text(l10n.continueAction),
        );

      case GamePhase.result:
      case GamePhase.analytics:
        // Doc 15 §S-O13 beat 5. Two controls, and this is the one exception
        // §1.5's "one primary button" makes for itself — the same exception the
        // discussion already takes, and for the same reason: leaving is not the
        // only thing left to do. The roster is where the card art lives now
        // that beat 2 stopped trying to draw fifteen of them at once.
        //
        // The button is not shown when the standings are empty. A roster of
        // nobody is the app offering a screen it cannot fill.
        final roster = snapshot.standings;
        final roomId = ref.watch(onlineSessionProvider).room?.roomId;
        final completed = snapshot.outcome?.winner != null;
        if (completed && roomId != null) _noteCompleted(roomId);
        // Home from a completed result is the one exit an automatic ad may
        // follow (after the screen has already moved on). Rematch gets the
        // next match's pre-match ad instead (Ads v3), never both.
        final goHome = completed ? _homeAfterCompleted : widget.onExit;
        final home = FilledButton(
          onPressed: goHome,
          child: Text(l10n.homeAction),
        );
        if (roster.isEmpty) return home;
        // Phase 109: awards and reactions, only once the outcome is public.
        final backend = ref.watch(onlineSessionProvider).transport?.backend;
        final reactionsAreOpen = reactionsOpen(
          snapshot.phase,
          outcomePublic: completed,
        );
        final names = {for (final p in snapshot.public.players) p.seat: p.name};
        return ReactionScope(
          roomId: roomId,
          backend: backend,
          open: reactionsAreOpen,
          nameOf: (seat) => names[seat] ?? '',
          // The hand is a quarter of the screen and the result has more to
          // say than that on a short phone: everything but the rematch
          // scrolls, and the rematch is pinned under it so the loudest thing
          // left to do is on screen at 640 high, awards or not.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                // Fades under the pinned rematch while more lies below.
                child: ScrollFadeEdge(
                  child: SingleChildScrollView(
                    key: OnlineTableFlow.resultScroll,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (roomId != null && completed)
                          OnlineAwardsStrip(
                            key: ValueKey('awards-$roomId'),
                            roomId: roomId,
                          ),
                        if (roomId != null && backend != null)
                          ReactionBar(
                            roomId: roomId,
                            backend: backend,
                            open: reactionsAreOpen,
                          ),
                        // Phase 107: what the finished match moved in the
                        // Council. Only once the outcome is public — never
                        // during play.
                        if (roomId != null && completed)
                          CouncilResultStrip(
                            key: ValueKey(roomId),
                            roomId: roomId,
                          ),
                        if (roomId != null)
                          RewardedRewardButton(roomId: roomId),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: OnlineTableFlow.seeRoles,
                                onPressed: () => setState(() => _roster = true),
                                child: Text(l10n.onlineSeeRoles),
                              ),
                            ),
                            // Doc 09 §7: only a room that chose it, only
                            // once the outcome is public.
                            if (completed &&
                                roomId != null &&
                                snapshot.settings.revealWhisperContent) ...[
                              SizedBox(width: spacing.sm),
                              Expanded(
                                child: OutlinedButton(
                                  key: OnlineTableFlow.revealedWhispers,
                                  onPressed: () =>
                                      setState(() => _whispers = true),
                                  child: Text(l10n.revealWhispersButton),
                                ),
                              ),
                            ],
                            if (snapshot.outcome?.winner != null) ...[
                              SizedBox(width: spacing.sm),
                              ResultShareButton(
                                winner: snapshot.outcome!.winner,
                                days: snapshot.dayNumber,
                                roomId: roomId,
                              ),
                            ],
                          ],
                        ),
                        TextButton(
                          onPressed: goHome,
                          child: Text(l10n.homeAction),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.xs),
              // Phase 109: keeping the group together is the loudest thing
              // left to do — ahead of the roles and ahead of home.
              _TableRematch(
                snapshot: snapshot,
                onGone: () => (widget.onRematch ?? widget.onExit)(),
              ),
            ],
          ),
        );

      default:
        // Every remaining phase moves on by itself — on its clock, or once the
        // room has read it (see `OnlineTransport._armEarlyAlarm`). Nobody has
        // a «كمل», the host included (owner decision 2026-09-23).
        return null;
    }
  }

  /// The eliminated player's card, rising and turning over (doc 15 §S-O12).
  ///
  /// Null on every other phase, and null once this device has watched it — a
  /// resync mid-reveal must not play the flip again, because the second time
  /// it is not a reveal, it is a glitch.
  Widget? _verdict(BuildContext context, GameSnapshot snapshot) {
    if (snapshot.phase != GamePhase.reveal) return null;
    final vote = snapshot.lastVote;
    final seat = vote?.eliminatedSeat;
    final role = vote?.eliminatedRole;
    // No role means the server has not said one yet, and a card with nothing
    // on its face is not a reveal. A tie has no card at all.
    if (seat == null || role == null) return null;

    final stamp = 'day${snapshot.dayNumber}-seat$seat';
    if (_cardShown == stamp) return null;
    // Once per card, on every phone at once: the verdict is public.
    if (_cardSounded != stamp) {
      _cardSounded = stamp;
      _sharedCue(AudioCue.eliminationReveal);
    }

    return CardRise(
      key: ValueKey(stamp),
      role: role,
      name:
          snapshot.public.players
              .where((player) => player.seat == seat)
              .map((player) => player.name)
              .firstOrNull ??
          '',
      onFinished: () {
        if (mounted) setState(() => _cardShown = stamp);
      },
    );
  }

  // ── the reveal ───────────────────────────────────────────────────────────

  Widget _reveal(BuildContext context, MatchUiState state) {
    final reveal = state.reveal!;
    return ColoredBox(
      color: context.colors.surfaceBase.withValues(alpha: 0.92),
      child: SafeArea(
        child: RoleCard(
          key: ValueKey('online-role-card-${reveal.seat}'),
          playerName: reveal.name,
          role: reveal.role,
          teammateNames: reveal.teammateNames,
          identityHold: context.timing.holdToReveal,
          // Not «سلّم الموبايل». This phone is staying exactly where it is.
          dismissLabel: context.l10n.continueAction,
          onDismissed: () {
            unawaited(_confirmReveal());
          },
        ),
      ),
    );
  }

  Future<void> _confirmReveal() async {
    if (_committing) return;
    setState(() => _committing = true);
    try {
      await _controller.confirmRevealedCommitted();
      if (mounted) widget.onStepCommitted();
    } catch (_) {
      // Keep the card visible. The same explicit user action can safely retry;
      // `saw_role` is idempotent and the phase remains server-gated.
      //
      // And say so. A card that stays put after «كمل» is indistinguishable
      // from a button that does not work, which is exactly what it looked like
      // to a room where four people were waiting on each other.
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(context.l10n.actionNotSaved)));
      }
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  /// The whisper composer, over the table rather than instead of it.
  ///
  /// Doc 12 §3.7: *"bottom sheet, does not leave the table."* The table stays
  /// underneath — this is a conversation *about* the room, and a screen that
  /// replaced the room would be the wrong shape for it.
  Widget _composer(BuildContext context, GameSnapshot snapshot) {
    final me = snapshot.viewerSeat;
    if (me == null) return const SizedBox.shrink();

    final composer = ColoredBox(
      color: context.colors.surfaceBase.withValues(alpha: 0.72),
      child: SafeArea(
        child: WhisperComposeScreen(
          players: snapshot.public.players,
          // This device's own player. The recipient list is built from the
          // others, so there is no seat to exclude.
          fromSeat: me,
          witnessed:
              ref
                  .watch(economyCapabilitiesProvider)
                  .valueOrNull
                  ?.witnessWhispers ??
              false,
          onCancel: () => setState(() => _composing = false),
          onSend: (fromSeat, toSeat, body) {
            setState(() => _composing = false);
            unawaited(
              _controller.sendWhisper(
                fromSeat: fromSeat,
                toSeat: toSeat,
                body: body,
              ),
            );
            widget.onStepCommitted();
          },
        ),
      ),
    );
    if (!snapshot.settings.revealWhisperContent) return composer;
    // Doc 09 §7: the room's rule, on the page where the words are written.
    return Stack(
      fit: StackFit.expand,
      children: [
        composer,
        Align(
          alignment: AlignmentDirectional.topCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(context.spacing.sm),
              child: const RevealWhispersNotice(),
            ),
          ),
        ),
      ],
    );
  }
}

/// One whisper on its way onto the screen.
class _Incoming {
  final String id;
  final String senderName;
  final String body;

  const _Incoming({
    required this.id,
    required this.senderName,
    required this.body,
  });
}

/// One beat late, then in.
///
/// Doc 15 §S-O6 sequences the morning: the room is told *what happened*, and
/// only after it has landed is it told *what was left behind*. Both at once is
/// two sentences competing, which is exactly the failure Part 0 catalogued.
///
/// Under Reduce Motion there is no beat: the second element is simply there,
/// because a delay a user cannot see is a screen that looks broken.
class _AfterBeat extends StatefulWidget {
  final Widget child;

  const _AfterBeat({required this.child});

  @override
  State<_AfterBeat> createState() => _AfterBeatState();
}

class _AfterBeatState extends State<_AfterBeat> {
  bool _shown = false;
  Timer? _beat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown || _beat != null) return;
    if (ReduceMotion.of(context)) {
      _shown = true;
      return;
    }
    _beat = Timer(context.motion.phase, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _beat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _shown ? 1 : 0,
    duration: ReduceMotion.of(context) ? Duration.zero : context.motion.reveal,
    curve: context.motion.standardCurve,
    child: widget.child,
  );
}

/// The confrontation's answer clock (doc 15 §1.4, asset A5).
///
/// The one place a second timer is allowed, because it is not the match clock:
/// it is *this person's* time to answer, and it is the subject of the phase
/// rather than a status line about it. It burns down as an arc, never turns
/// red, and carries the number so nobody has to read an angle.
class _ConfrontationClock extends StatefulWidget {
  final DateTime deadline;

  /// The phase's full length, so the arc has a scale to be a fraction of.
  final int total;

  const _ConfrontationClock({required this.deadline, required this.total});

  @override
  State<_ConfrontationClock> createState() => _ConfrontationClockState();
}

class _ConfrontationClockState extends State<_ConfrontationClock> {
  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticker?.cancel();
    _ticker = Timer.periodic(context.motion.tick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = HeaderTimer.secondsLeft(widget.deadline, DateTime.now());
    return TimerRing(
      remaining: widget.total <= 0 ? 0 : left / widget.total,
      seconds: '$left',
    );
  }
}

/// The result's loudest action: keep the table together.
///
/// The host opens the next room with this room's settings; every other seat
/// watches this finished room's public data and, the moment the code arrives,
/// joins with one tap under the same name. Until then a guest can still take
/// the old way — the online door — or wait for the host.
class _TableRematch extends ConsumerStatefulWidget {
  final GameSnapshot snapshot;
  final VoidCallback onGone;
  const _TableRematch({required this.snapshot, required this.onGone});

  static const Key hostKey = ValueKey('online_rematch_host');
  static const Key joinKey = ValueKey('online_rematch_join');

  @override
  ConsumerState<_TableRematch> createState() => _TableRematchState();
}

class _TableRematchState extends ConsumerState<_TableRematch> {
  bool _busy = false;

  PublicPlayer? _me(OnlineTransport transport) {
    final seat = transport.mySeat;
    return widget.snapshot.public.players
        .where((p) => p.seat == seat)
        .firstOrNull;
  }

  String _gender(PublicPlayer? me) => switch (me?.gender) {
    PlayerGender.male => 'male',
    PlayerGender.female => 'female',
    _ => 'unspecified',
  };

  Future<void> _go(Future<void> Function() enter) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ads = ref.read(interstitialCoordinatorProvider);
    await enter();
    if (!mounted) return;
    // Ads v3: the next match's pre-match ad, between rooms, never in a lobby.
    await ads.beforeRematch();
    if (mounted) widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.read(onlineSessionProvider.notifier);
    final transport = ref.watch(onlineSessionProvider).transport;
    if (transport == null) return const SizedBox.shrink();
    return StreamBuilder<GameSnapshot>(
      stream: transport.watch(),
      builder: (context, _) {
        final me = _me(transport);
        final next = transport.rematch;
        if (next != null && !transport.isHost) {
          return FilledButton.icon(
            key: _TableRematch.joinKey,
            onPressed: _busy || me == null
                ? null
                : () => _go(
                    () => session.join(
                      code: next.code,
                      name: me.name,
                      gender: _gender(me),
                    ),
                  ),
            icon: const Icon(Icons.login_rounded),
            label: Text(l10n.rematchJoin),
          );
        }
        if (transport.isHost) {
          return FilledButton.icon(
            key: _TableRematch.hostKey,
            onPressed: _busy || me == null
                ? null
                : () => _go(
                    () => session.rematch(name: me.name, gender: _gender(me)),
                  ),
            icon: const Icon(Icons.replay_rounded),
            label: Text(l10n.rematchHost),
          );
        }
        // Until the host opens the next table, a guest can still take the
        // old way; the moment the code arrives this becomes «ادخل».
        return FilledButton.icon(
          key: OnlineTableFlow.playAgain,
          onPressed: _busy ? null : () => _go(() => session.leave()),
          icon: const Icon(Icons.group_add_rounded),
          label: Text(l10n.playAgainWithGroup),
        );
      },
    );
  }
}
