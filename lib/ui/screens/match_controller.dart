import '../../engine/models/player.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/match_seed.dart';
import '../../data/whisper_store.dart';
import '../../transport/game_snapshot.dart';
import '../../transport/game_transport.dart';
import '../../transport/local_transport.dart';
import '../../engine/bullets.dart';
import '../../engine/match_engine.dart';
import '../../engine/models/enums.dart';
import '../../engine/models/match.dart';
import '../../engine/models/match_settings.dart';
import '../../engine/models/timeline_event.dart' show InvestigateResult;
import '../../engine/views.dart';
import 'online/online_session.dart';

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

  /// What the whisper slot should say on this turn, if anything specific.
  ///
  /// A secret in exactly the sense the other three fields are: it exists only
  /// while the phone is in one player's hand and is dropped on the pass. Null
  /// means "nothing waiting", which the shell renders as «مفيش همسات ليك» —
  /// never as an absent card (doc 11 H-E8).
  final WhisperDelivery? whisper;

  final MorningReport? morning;
  final DayVoteResult? lastVote;

  const MatchUiState({
    required this.public,
    this.reveal,
    this.actorTurn,
    this.investigateResult,
    this.whisper,
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
    WhisperDelivery? whisper,
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
      whisper: clearSecrets ? null : (whisper ?? this.whisper),
      morning: clearMorning ? null : (morning ?? this.morning),
      lastVote: clearVote ? null : (lastVote ?? this.lastVote),
    );
  }
}

/// One whisper, as the recipient's turn will show it.
///
/// Assembled at the moment of delivery by joining the graph (in the event log)
/// to a body (in the whisper store). Never persisted in this shape.
@immutable
class WhisperDelivery {
  /// Non-null for a whisper addressed to this seat, so it can be marked read.
  final String? id;

  final String body;

  /// True when this is the sender being told their whisper never arrived
  /// («الهمسة ماوصلتش», doc 09 §3.4) rather than a whisper being delivered.
  final bool isUndeliveredNotice;

  const WhisperDelivery({
    this.id,
    required this.body,
    this.isUndeliveredNotice = false,
  });
}

/// The engine instance backing the current match.
///
/// Overridable so tests (and the golden suites) can inject a seeded engine.
///
/// This is where real time enters the game. The engine holds no clock of its
/// own — `lib/engine/` may not read one (see `engine/clock.dart`) — so the
/// production wiring hands it `DateTime.now` here, at the boundary, and tests
/// hand it `Clocks.monotonic` instead.
final matchEngineProvider = Provider<MatchEngine>(
  (ref) => MatchEngine(clock: DateTime.now),
);

/// The transport every command goes through (doc 10 §7).
///
/// Offline this is [LocalTransport] over the engine above; online it will be
/// `OnlineTransport` over Supabase, and **nothing in `lib/ui/` will change**.
/// That is the point of the seam: the controller below names the interface,
/// never the implementation, so swapping the two is an override here.
final gameTransportProvider = Provider<GameTransport>((ref) {
  // The one place in the app that chooses. It is not a widget, it is not a
  // screen, and it is not a branch inside anything that draws: a room has been
  // joined or it has not, and everything above this line reads the interface.
  final online = ref.watch(onlineSessionProvider.select((s) => s.transport));
  if (online != null) return online;

  final transport = LocalTransport(
    engine: ref.watch(matchEngineProvider),
    whispers: ref.watch(whisperStoreProvider),
  );
  ref.onDispose(transport.dispose);
  return transport;
});

/// Bridges [MatchEngine] to the widget tree.
///
/// Every mutation goes through an engine command; the controller never edits
/// `Match` directly. After each command it republishes a fresh [MatchUiState]
/// so that a screen can only ever render state the engine actually agreed to.
class MatchController extends Notifier<MatchUiState?> {
  MatchEngine get engine => ref.read(matchEngineProvider);

  /// Where every command goes.
  ///
  /// The controller does not resolve anything itself and has not since the
  /// transport landed: it turns a tap into a command, hands it over, and
  /// republishes what came back. Offline the transport applies it on this
  /// device before returning, which is why the methods below can stay
  /// synchronous and why not one screen had to change when they moved.
  GameTransport get transport => ref.read(gameTransportProvider);

  /// The rules this match is being played under.
  ///
  /// Off the snapshot, not off the engine: online the settings are a fact about
  /// the room and there is no local `Match` to read them from. Screens that
  /// need to know whether whispers are on, or how long a speech runs, ask here.
  MatchSettings get settings => transport.snapshot.settings;

  /// The latest public state, synchronously. Every screen's `state` comes from
  /// here; this is for the handful of call sites that need it outside a build.
  GameSnapshot get snapshot => transport.snapshot;

  StreamSubscription<GameSnapshot>? _feed;

  @override
  MatchUiState? build() {
    // Offline this stream is a courtesy - every command already republished
    // before it returned. Online it is the *only* way most of the state ever
    // arrives: the host taps next on another phone and this device finds out
    // because the server said so.
    //
    // It carries nothing secret. `GameSnapshot` has no role field, and the
    // three secret slots of [MatchUiState] are only ever filled by a call to
    // `secretsFor` made for the seat holding this device - which is why a push
    // can never put a card back on screen after a pass (L-14).
    final transport = ref.watch(gameTransportProvider);
    _feed?.cancel();
    _feed = transport.watch().listen(_onSnapshot);
    ref.onDispose(() => _feed?.cancel());
    return null;
  }

  void _onSnapshot(GameSnapshot snapshot) {
    if (snapshot.public.players.isEmpty) return;
    final current = state;
    if (current == null) {
      state = MatchUiState(
        public: snapshot.public,
        morning: snapshot.morning,
        lastVote: snapshot.lastVote,
      );
      return;
    }
    state = current.copyWith(
      public: snapshot.public,
      morning: snapshot.morning,
      lastVote: snapshot.lastVote,
      clearMorning: snapshot.morning == null,
      clearVote: snapshot.lastVote == null,
    );
  }

  /// Adopts a match this device did not start - the online case, where the
  /// state was already there before this screen was.
  void adoptSnapshot() {
    final snapshot = transport.snapshot;
    if (snapshot.public.players.isEmpty) return;
    state = MatchUiState(
      public: snapshot.public,
      morning: snapshot.morning,
      lastVote: snapshot.lastVote,
    );
  }

  // ---------------------------------------------------------------------------
  // Setup & distribution
  // ---------------------------------------------------------------------------

  void startMatch({
    required List<String> names,
    Map<String, PlayerGender> genders = const {},
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
    int? seed,
  }) {
    engine.start(
      names: names,
      genders: genders,
      roleCounts: roleCounts,
      settings: settings,
      // Minted here rather than inside the engine, which may not read the
      // platform's entropy. A caller that passes one - the golden suites, a
      // replay - gets exactly that match back.
      seed: seed ?? newMatchSeed(),
    );
    // The engine was written to directly, so the transport's snapshot is a
    // match behind. Everything the screens read comes off that snapshot now.
    transport.resync();
    state = MatchUiState(public: transport.snapshot.public);
  }

  /// Loads a match that was restored from storage.
  ///
  /// Only the public view is published: every secret field starts null, so a
  /// resumed match cannot put a role card, a target list or an investigation
  /// result back on screen. The holder has to re-enter through the pass gate,
  /// which is what makes an interrupted night safe to resume (L-13).
  void adoptMatch(Match match) {
    engine.match = match;
    transport.resync();
    state = MatchUiState(public: transport.snapshot.public);
  }

  /// Reveals the role of the seat currently holding the phone.
  ///
  /// Asks the transport rather than the engine, and that is the whole of what
  /// makes this screen work online: offline `secretsFor` reads the seat the
  /// phone was just handed to, and online it reads the only seat this device
  /// will ever be told about - its own. Neither can answer for anybody else.
  Future<void> revealCurrentRole() async {
    final seat = transport.snapshot.currentActorSeat;
    if (seat == null) return;
    final secrets = await transport.secretsFor(seat);
    final role = secrets?.role;
    if (role == null) return;
    final players = transport.snapshot.public.players;
    state = _publish().copyWith(
      reveal: RoleRevealPayload(
        seat: seat,
        name: players.firstWhere((p) => p.seat == seat).name,
        role: role,
        teammateNames: secrets!.teammateNames,
      ),
    );
  }

  /// Dismisses the role card and hands the phone to the next seat. The revealed
  /// role is dropped here and is not recoverable from any UI state.
  void confirmRevealed() {
    transport.confirmRevealed();
    state = _publish(clearSecrets: true);
  }

  /// Online reveal acknowledgement must be durable before its card vanishes.
  /// A transient failed request then leaves the card available for retry
  /// instead of stranding this seat behind the communal server gate.
  Future<void> confirmRevealedCommitted() async {
    await transport.confirmRevealed();
    state = _publish(clearSecrets: true);
  }

  // ---------------------------------------------------------------------------
  // Night
  // ---------------------------------------------------------------------------

  void beginNight() {
    transport.beginNight();
    state = _publish(clearSecrets: true, clearMorning: true, clearVote: true);
  }

  /// Loads the in-hand view for the seat whose turn it is.
  ///
  /// Asynchronous because of the whisper, and only because of it: the body
  /// lives in a store the engine cannot reach (doc 09 §5's split), so it has to
  /// be fetched. The turn view itself is published immediately, so the shell
  /// opens in its handoff state at once and the body arrives well before the
  /// dwell gate lets anybody see it.
  Future<void> openActorTurn() async {
    final seat = transport.snapshot.currentActorSeat;
    if (seat == null) return;

    final secrets = await transport.secretsFor(seat);
    final turn = secrets?.turn;
    if (turn == null) return;
    // The turn may have moved on while the read was in flight.
    if (transport.snapshot.currentActorSeat != seat) return;
    state = _publish().copyWith(actorTurn: turn);

    if (!settings.whisperEnabled) return;
    final delivery = _whisperFrom(secrets!);
    if (delivery == null) return;
    if (transport.snapshot.currentActorSeat != seat) return;
    state = state?.copyWith(whisper: delivery);
  }

  /// The whisper waiting for **this device's own player**, or null.
  ///
  /// Doc 14 §3.2 and §3.4: online, a whisper is delivered the moment it is
  /// sent, into the discussion it was written about. It used to wait for the
  /// recipient's next night turn, which offline meant a full phase later and
  /// online meant *never* — the online table has no in-hand turn to put it in,
  /// so the body was fetched by nobody and the recipient heard a chime and read
  /// a light crossing the table.
  ///
  /// Returns the body once. The transport marks the row read on fetch, so a
  /// second call after the card is dismissed finds nothing waiting.
  Future<WhisperDelivery?> pullViewerWhisper() async {
    final seat = transport.snapshot.viewerSeat;
    if (seat == null) return null;
    final secrets = await transport.secretsFor(seat);
    if (secrets == null) return null;
    return _whisperFrom(secrets);
  }

  /// What this seat should be shown, or null for nothing.
  ///
  /// Priority: a whisper addressed to them, then the notice that one they sent
  /// never arrived.
  /// What this seat should be shown in the whisper slot, or null for nothing.
  ///
  /// The join of graph to body happens in the transport - offline against Isar,
  /// online against a table only the two parties can read - and arrives here
  /// already made. All that is left is which of the two sentences to show.
  WhisperDelivery? _whisperFrom(ViewerSecrets secrets) {
    final body = secrets.whisperBody;
    if (body != null) return WhisperDelivery(id: secrets.whisperId, body: body);
    if (secrets.whisperUndelivered) {
      return const WhisperDelivery(body: '', isUndeliveredNotice: true);
    }
    return null;
  }

  /// Submits the current actor's night action. A Detective's result is held in
  /// state only until [passTurn] is called.
  /// [useBullet] arms «الطلقة الواحدة» on the same turn (doc 13 §2). The shell
  /// holds the flag while the player is deciding; it becomes irreversible here
  /// and nowhere earlier.
  Future<void> submitNightAction({
    required NightActionKind kind,
    required int targetSeat,
    bool useBullet = false,
  }) async {
    final seat = transport.snapshot.currentActorSeat;
    if (seat == null) return;
    // The *result* is a secret handed to one player and never broadcast - it is
    // not, and must never be, on a snapshot - so it comes back from the command
    // itself, in both modes.
    final result = await transport.submitNightAction(
      seat: seat,
      kind: kind,
      targetSeat: targetSeat,
      useBullet: useBullet,
    );
    // The turn has already moved on; keep the outgoing actor's view on screen
    // until the pass so the shell does not change under the player's hands.
    state = _publish().copyWith(
      actorTurn: state?.actorTurn,
      investigateResult: result,
    );
  }

  /// Records the current actor's turn with no target chosen.
  ///
  /// A Doctor arming [useBullet] here is protecting themselves, which is an
  /// action rather than an absence — the engine turns it into one. For every
  /// other role this is the empty turn it has always been, with the bullet
  /// spent alongside it.
  Future<void> skipNightAction({bool useBullet = false}) async {
    final seat = transport.snapshot.currentActorSeat;
    if (seat == null) return;
    // The role comes off the turn view this screen is already holding, not off
    // the roster: the roster has no roles in it, in either mode, by design.
    final kind = state?.actorTurn?.actorRole.nightAction;
    if (kind == null) return;
    final pending = transport.submitNightAction(
      seat: seat,
      kind: kind,
      targetSeat: null,
      useBullet: useBullet,
    );
    state = _publish().copyWith(actorTurn: state?.actorTurn);
    await pending;
  }

  /// Whether «الطلقة الواحدة» exists in this match at all (doc 13 §2, §7).
  ///
  /// Two facts, both constant for the whole match: the host turned it on, and
  /// this transport can carry it. Constant is the point — a control that came
  /// and went inside a match would be a control whose presence is a fact about
  /// whoever is holding the phone.
  bool get bulletsAvailable =>
      settings.bulletsEnabled && transport.supportsBullets;

  /// Whether the current actor still has theirs.
  ///
  /// Asked of the transport, because the answer lives in a different place in
  /// each mode and neither place is this class's business: offline it is the
  /// engine, which spent it; online it is `night_actions.used_bullet`, which
  /// the server wrote after deciding the move was legal. A spent bullet still
  /// draws its tile, dimmed (doc 13 §2.4, doc 14 §1.3) — a tile that vanished
  /// would change the grid's shape, and grid shape is a tell.
  bool get currentBulletSpent =>
      transport.supportsBullets && transport.currentActorBulletSpent;

  /// Whether [role]'s once-per-match ability exists in *this room*.
  ///
  /// Three facts, all constant for the whole match: the role holds one at all
  /// (two of the four do), the host left «الطلقة الواحدة» on, and the host left
  /// this particular one on. Constant is what makes it safe to draw — a control
  /// that came and went inside a match would be a control whose presence is a
  /// fact about whoever is holding the phone.
  ///
  /// Says nothing about whether it has been *used*; that is
  /// [currentBulletSpent], and a used ability still draws its tile (doc 14
  /// §1.3 — a tile that vanished would change the grid's shape, and grid shape
  /// is a tell).
  bool bulletExistsFor(Role role) {
    final kind = role.bullet;
    if (kind == null) return false;
    if (role == Role.doctor) return transport.supportsBullets;
    if (!bulletsAvailable) return false;
    return Bullets.enabled(settings, kind);
  }

  /// Drops every secret held for the outgoing player.
  void passTurn() {
    state = _publish(clearSecrets: true);
  }

  MorningReport resolveNight() {
    transport.resolveNight();
    final report = transport.snapshot.morning ?? const MorningReport();
    state = _publish(clearSecrets: true).copyWith(morning: report);
    return report;
  }

  // ---------------------------------------------------------------------------
  // Day
  // ---------------------------------------------------------------------------

  /// Opens the day. The engine decides which of the three day surfaces the
  /// table lands on — see [MatchEngine.beginDay].
  void beginDay() {
    transport.beginDay();
    state = _publish(clearSecrets: true);
  }

  /// One public accusation in the Day-1 «اسم واحد» round.
  Future<void> submitOpeningAccusation({required int targetSeat}) async {
    final seat = transport.snapshot.currentActorSeat;
    if (seat == null) return;
    final pending = transport.submitOpeningAccusation(
      seat: seat,
      targetSeat: targetSeat,
    );
    state = _publish(clearSecrets: true);
    await pending;
  }

  /// Closes the confrontation window. [silent] when nobody spoke.
  void endConfrontation({required bool silent}) {
    transport.endConfrontation(silent: silent);
    state = _publish(clearSecrets: true);
  }

  /// Records a speaker's floor time. Feeds `C6`.
  void recordSpeaking({required int seat, required int seconds}) {
    transport.recordSpeaking(seat: seat, seconds: seconds);
  }

  /// Sends a whisper and returns its id, so the caller can store the body in
  /// the whisper store. The engine never holds the body.
  /// Sends a whisper and returns its id.
  ///
  /// The transport writes the body to its own store — that is the whole of doc
  /// 09 §5's split, and it is the transport's job precisely because *where the
  /// body lives* is the thing that differs between the two modes.
  Future<String> sendWhisper({
    required int fromSeat,
    required int toSeat,
    required String body,
  }) async {
    final id = await transport.sendWhisper(
      fromSeat: fromSeat,
      toSeat: toSeat,
      body: body,
    );
    state = _publish();
    return id;
  }

  /// Marks a whisper read by its recipient.
  void markWhisperDelivered(String id) {
    transport.markWhisperDelivered(id);
    state = _publish();
  }

  void beginDiscussion() {
    transport.beginDiscussion();
    state = _publish(clearSecrets: true);
  }

  /// Applies the phase's expiry default (doc 10 §8.2).
  ///
  /// Nothing offline calls this — there are no phase timers at a table — but
  /// the guarantee it carries is shared, so the controller exposes it and the
  /// transport implements it on both sides.
  void advancePhase() {
    transport.advancePhase();
    state = _publish(clearSecrets: true);
  }

  /// Ends the match if last night already decided it. Returns the winner, or
  /// null if there is still a game to play.
  Alignment? concludeAfterNight() {
    final result = transport.snapshot.pendingOutcome;
    if (result == null) return null;
    transport.concludeAfterNight();
    state = _publish(clearSecrets: true);
    return result;
  }

  Future<void> setReadyToVote(bool ready) => transport.setReadyToVote(ready);

  void beginVoting() {
    transport.beginVoting();
    state = _publish(clearSecrets: true, clearVote: true);
  }

  Future<void> submitVote({required int? targetSeat}) async {
    final seat = transport.snapshot.currentActorSeat;
    if (seat == null) return;
    final pending = transport.submitVote(seat: seat, targetSeat: targetSeat);
    state = _publish(clearSecrets: true);
    await pending;
  }

  DayVoteResult resolveDayVote() {
    transport.resolveDayVote();
    final result = transport.snapshot.lastVote ?? const DayVoteResult();
    state = _publish(clearSecrets: true).copyWith(lastVote: result);
    return result;
  }

  Alignment? winCheck() {
    transport.winCheck();
    final winner = transport.snapshot.public.outcome?.winner;
    state = _publish(clearSecrets: true);
    return winner;
  }

  void removePlayer(int seat) {
    transport.removePlayer(seat);
    state = _publish(clearSecrets: true);
  }

  // ---------------------------------------------------------------------------

  MatchUiState _publish({
    bool clearSecrets = false,
    bool clearMorning = false,
    bool clearVote = false,
  }) {
    final current = state;
    final public = transport.snapshot.public;
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
