import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/match_engine.dart';
import '../../engine/models/enums.dart';
import '../../engine/models/match.dart';
import '../../engine/models/match_settings.dart';
import '../../engine/models/timeline_event.dart' show InvestigateResult;
import '../../engine/views.dart';

/// What the current actor is allowed to see about their own role during
/// distribution. Exists only while the phone is in that player's hand.
@immutable
class RoleRevealPayload {
  final int seat;
  final String name;
  final Role role;
  final List<String> teammateNames;

  const RoleRevealPayload({
    required this.seat,
    required this.name,
    required this.role,
    required this.teammateNames,
  });
}

/// Everything the UI is permitted to render.
///
/// [public] is the only field any spectator-visible screen may read; it carries
/// no roles by construction (`PublicPlayer` has no role field). The three
/// nullable secret fields exist **only** while the phone is in one player's
/// hand and are cleared the moment the turn is passed on — that clearing is
/// what makes the Detective result ephemeral (FR-028, L-14).
@immutable
class MatchUiState {
  final PublicMatchView public;

  /// Non-null only during `distributing`, for the seat currently holding the phone.
  final RoleRevealPayload? reveal;

  /// Non-null only during `night`, for the seat currently holding the phone.
  final ActorTurnView? actorTurn;

  /// Non-null only between a Detective's confirm and their pass.
  final InvestigateResult? investigateResult;

  final MorningReport? morning;
  final DayVoteResult? lastVote;

  const MatchUiState({
    required this.public,
    this.reveal,
    this.actorTurn,
    this.investigateResult,
    this.morning,
    this.lastVote,
  });

  GamePhase get phase => public.phase;
  int get dayNumber => public.dayNumber;
  int? get currentActorSeat => public.currentActorSeat;

  MatchUiState copyWith({
    PublicMatchView? public,
    RoleRevealPayload? reveal,
    ActorTurnView? actorTurn,
    InvestigateResult? investigateResult,
    MorningReport? morning,
    DayVoteResult? lastVote,
    bool clearSecrets = false,
    bool clearMorning = false,
    bool clearVote = false,
  }) {
    return MatchUiState(
      public: public ?? this.public,
      reveal: clearSecrets ? null : (reveal ?? this.reveal),
      actorTurn: clearSecrets ? null : (actorTurn ?? this.actorTurn),
      investigateResult: clearSecrets
          ? null
          : (investigateResult ?? this.investigateResult),
      morning: clearMorning ? null : (morning ?? this.morning),
      lastVote: clearVote ? null : (lastVote ?? this.lastVote),
    );
  }
}

/// The engine instance backing the current match.
///
/// Overridable so tests (and the golden suites) can inject a seeded engine.
final matchEngineProvider = Provider<MatchEngine>((ref) => MatchEngine());

/// Bridges [MatchEngine] to the widget tree.
///
/// Every mutation goes through an engine command; the controller never edits
/// `Match` directly. After each command it republishes a fresh [MatchUiState]
/// so that a screen can only ever render state the engine actually agreed to.
class MatchController extends Notifier<MatchUiState?> {
  MatchEngine get engine => ref.read(matchEngineProvider);

  @override
  MatchUiState? build() => null;

  // ---------------------------------------------------------------------------
  // Setup & distribution
  // ---------------------------------------------------------------------------

  void startMatch({
    required List<String> names,
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
    int? seed,
  }) {
    engine.start(
      names: names,
      roleCounts: roleCounts,
      settings: settings,
      seed: seed,
    );
    state = MatchUiState(public: engine.publicView());
  }

  /// Loads a match that was restored from storage.
  ///
  /// Only the public view is published: every secret field starts null, so a
  /// resumed match cannot put a role card, a target list or an investigation
  /// result back on screen. The holder has to re-enter through the pass gate,
  /// which is what makes an interrupted night safe to resume (L-13).
  void adoptMatch(Match match) {
    engine.match = match;
    state = MatchUiState(public: engine.publicView());
  }

  /// Reveals the role of the seat currently holding the phone.
  void revealCurrentRole() {
    final seat = engine.match.currentActorSeat;
    if (seat == null) return;
    final result = engine.revealFor(seat);
    state = _publish().copyWith(
      reveal: RoleRevealPayload(
        seat: seat,
        name: engine.match.players[seat].name,
        role: result.role,
        teammateNames: result.teammateNames,
      ),
    );
  }

  /// Dismisses the role card and hands the phone to the next seat. The revealed
  /// role is dropped here and is not recoverable from any UI state.
  void confirmRevealed() {
    engine.confirmRevealed();
    state = _publish(clearSecrets: true);
  }

  // ---------------------------------------------------------------------------
  // Night
  // ---------------------------------------------------------------------------

  void beginNight() {
    engine.beginNight();
    state = _publish(clearSecrets: true, clearMorning: true, clearVote: true);
  }

  /// Loads the in-hand view for the seat whose turn it is.
  void openActorTurn() {
    final seat = engine.match.currentActorSeat;
    if (seat == null) return;
    state = _publish().copyWith(actorTurn: engine.actorView(seat));
  }

  /// Submits the current actor's night action. A Detective's result is held in
  /// state only until [passTurn] is called.
  void submitNightAction({
    required NightActionKind kind,
    required int targetSeat,
  }) {
    final seat = engine.match.currentActorSeat;
    if (seat == null) return;
    final result = engine.submitNightAction(
      seat: seat,
      kind: kind,
      targetSeat: targetSeat,
    );
    // The engine has already advanced currentActorSeat; keep the outgoing
    // actor's view on screen until the pass so the shell does not change under
    // the player's hands.
    state = _publish().copyWith(
      actorTurn: state?.actorTurn,
      investigateResult: result,
    );
  }

  /// Drops every secret held for the outgoing player.
  void passTurn() {
    state = _publish(clearSecrets: true);
  }

  MorningReport resolveNight() {
    final report = engine.resolveNight();
    state = _publish(clearSecrets: true).copyWith(morning: report);
    return report;
  }

  // ---------------------------------------------------------------------------
  // Day
  // ---------------------------------------------------------------------------

  void beginDiscussion() {
    engine.beginDiscussion();
    state = _publish(clearSecrets: true);
  }

  /// Ends the match if last night already decided it. Returns the winner, or
  /// null if there is still a game to play.
  Alignment? concludeAfterNight() {
    final result = engine.concludeAfterNight();
    if (result != null) state = _publish(clearSecrets: true);
    return result;
  }

  void beginVoting() {
    engine.beginVoting();
    state = _publish(clearSecrets: true, clearVote: true);
  }

  void submitVote({required int? targetSeat}) {
    final seat = engine.match.currentActorSeat;
    if (seat == null) return;
    engine.submitVote(seat: seat, voterSeat: seat, targetSeat: targetSeat);
    state = _publish(clearSecrets: true);
  }

  DayVoteResult resolveDayVote() {
    final result = engine.resolveDayVote();
    state = _publish(clearSecrets: true).copyWith(lastVote: result);
    return result;
  }

  Alignment? winCheck() {
    final winner = engine.winCheck();
    state = _publish(clearSecrets: true);
    return winner;
  }

  void removePlayer(int seat) {
    engine.removePlayer(seat);
    state = _publish(clearSecrets: true);
  }

  // ---------------------------------------------------------------------------

  MatchUiState _publish({
    bool clearSecrets = false,
    bool clearMorning = false,
    bool clearVote = false,
  }) {
    final current = state;
    final public = engine.publicView();
    if (current == null) return MatchUiState(public: public);
    return current.copyWith(
      public: public,
      clearSecrets: clearSecrets,
      clearMorning: clearMorning,
      clearVote: clearVote,
    );
  }
}

final matchControllerProvider =
    NotifierProvider<MatchController, MatchUiState?>(MatchController.new);
