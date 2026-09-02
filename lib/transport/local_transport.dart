import 'dart:async';

import '../data/whisper_store.dart';
import '../engine/legal_moves.dart';
import '../engine/match_engine.dart';
import '../engine/models/enums.dart';
import '../engine/models/match.dart';
import '../engine/models/timeline_event.dart' show InvestigateResult;
import '../engine/views.dart';
import 'game_snapshot.dart';
import 'game_transport.dart';
import 'voice_link.dart';

/// The offline transport: this device is the authority (doc 10 §1.1).
///
/// ## Why every command here completes before it returns
///
/// There is no network and no server. `MatchEngine` is synchronous, so a
/// command applies, the snapshot is rebuilt, the stream emits, and only then is
/// the (already-completed) future handed back. Callers may read [snapshot]
/// immediately afterwards and see the result.
///
/// That is not laziness about async — it is the property that let the whole
/// UI move behind this interface without changing a single screen, which was
/// the entire gate for the phase that introduced it. Online the same call
/// really does wait, and the screens learn about the result from [watch] rather
/// than from the return; they already do, because that is how they learn about
/// it here too.
///
/// ## Whisper bodies
///
/// The transport owns the split of doc 09 §5: the graph goes to the engine (and
/// so into the event log, and so onto the table), and the body goes to a
/// [WhisperStore] the engine cannot reach. Offline that store is Isar; online
/// it is `whisper_content` behind RLS. Neither one is reachable from a
/// [GameSnapshot].
class LocalTransport implements GameTransport {
  final MatchEngine engine;
  final WhisperStore whispers;

  final StreamController<GameSnapshot> _controller =
      StreamController<GameSnapshot>.broadcast();

  GameSnapshot _snapshot;

  /// The most recent morning and ballot, held because they are *reports* rather
  /// than state: the engine returns them once, from the command that produced
  /// them, and the table looks at them for a while afterwards.
  MorningReport? _morning;
  DayVoteResult? _lastVote;

  LocalTransport({required this.engine, required this.whispers})
      : _snapshot = engine.hasMatch
            ? GameSnapshot(
                public: engine.publicView(),
                settings: engine.match.settings,
              )
            // The transport is built when the app is, which is before anybody
            // has started anything. An empty table is the honest answer for
            // that stretch, and every screen that could render it is behind a
            // route that does not exist yet.
            : const GameSnapshot(
                public: PublicMatchView(
                  phase: GamePhase.setup,
                  dayNumber: 0,
                  players: [],
                ),
              );

  /// Adopts a match that has already been started or restored.
  factory LocalTransport.of(
    MatchEngine engine, {
    required WhisperStore whispers,
  }) =>
      LocalTransport(engine: engine, whispers: whispers);

  /// There is no call. One phone in the middle of a table is already a room
  /// of people who can hear each other, and the software has no part in it.
  @override
  VoiceLink? get voice => null;

  @override
  bool get isAuthoritative => true;

  @override
  GameSnapshot get snapshot => _snapshot;

  @override
  Stream<GameSnapshot> watch() async* {
    // A late subscriber gets the current state first, then every change.
    // Doc 10 §8.4: deltas are the happy path, snapshots are the recovery path
    // — and a subscription that started after the fact is exactly a recovery.
    yield _snapshot;
    yield* _controller.stream;
  }

  /// Rebuilds and publishes the snapshot. Called after every command.
  void _publish() {
    if (!engine.hasMatch) return;
    final match = engine.match;
    _snapshot = GameSnapshot(
      public: engine.publicView(),
      trace: engine.currentTrace,
      confrontation: engine.currentConfrontation,
      openingAccusations: engine.openingAccusations,
      whisperGraph: match.settings.whisperEnabled
          ? engine.whispersOn(match.dayNumber)
          : const [],
      morning: _morning,
      lastVote: _lastVote,
      settings: match.settings,
      // Computed here rather than held, because it is a question about the
      // roster and the roster is the thing that just changed. In `morning` it
      // answers "has the night already decided this"; anywhere else there is
      // nothing pending and it is null.
      pendingOutcome: match.phase == GamePhase.morning
          ? engine.outcomeAfterNight()
          : null,
      // Only once the match is over. Before that the list is empty rather than
      // filtered, so there is no code path here that has ever held a live
      // match's roles.
      standings: match.phase == GamePhase.result ||
              match.phase == GamePhase.analytics
          ? [
              for (final player in match.players)
                FinalStanding(
                  seat: player.seat,
                  name: player.name,
                  role: player.role,
                  eliminatedPhase: player.eliminatedOn?.phase,
                  eliminatedNumber: player.eliminatedOn?.number,
                ),
            ]
          : const [],
      connection: ConnectionQuality.local,
    );
    if (!_controller.isClosed) _controller.add(_snapshot);
  }

  @override
  Future<ViewerSecrets?> secretsFor(int seat) async {
    final match = engine.match;
    if (seat < 0 || seat >= match.players.length) return null;

    if (match.phase == GamePhase.distributing) {
      if (match.currentActorSeat != seat) return null;
      final reveal = engine.revealFor(seat);
      return ViewerSecrets(
        seat: seat,
        role: reveal.role,
        teammateNames: reveal.teammateNames,
      );
    }

    if (match.phase != GamePhase.night) return null;
    if (match.currentActorSeat != seat) return null;

    String? whisperId;
    String? whisperBody;
    var undelivered = false;
    if (match.settings.whisperEnabled) {
      for (final meta in engine.pendingWhispersFor(seat)) {
        final body =
            await whispers.read(matchId: match.id, whisperId: meta.id);
        if (body != null) {
          whisperId = meta.id;
          whisperBody = body;
          break;
        }
        // A graph edge with no body is a whisper whose store was lost. It is
        // never arriving; leaving it pending would re-offer it every turn.
        engine.markWhisperDelivered(meta.id);
      }
      if (whisperBody == null && engine.voidedWhispersFrom(seat).isNotEmpty) {
        undelivered = true;
      }
    }

    return ViewerSecrets(
      seat: seat,
      role: match.players[seat].role,
      turn: engine.actorView(seat),
      whisperId: whisperId,
      whisperBody: whisperBody,
      whisperUndelivered: undelivered,
    );
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  @override
  Future<void> beginNight() async {
    engine.beginNight();
    _morning = null;
    _lastVote = null;
    _publish();
  }

  @override
  Future<InvestigateResult?> submitNightAction({
    required int seat,
    required NightActionKind kind,
    required int? targetSeat,
  }) async {
    InvestigateResult? result;
    if (targetSeat == null) {
      engine.skipNightAction(seat: seat);
    } else {
      result =
          engine.submitNightAction(seat: seat, kind: kind, targetSeat: targetSeat);
    }
    _publish();
    return result;
  }

  @override
  Future<void> confirmRevealed() async {
    engine.confirmRevealed();
    _publish();
  }

  @override
  Future<void> beginDiscussion() async {
    engine.beginDiscussion();
    _publish();
  }

  @override
  Future<void> removePlayer(int seat) async {
    engine.removePlayer(seat);
    _publish();
  }

  @override
  Future<void> resolveNight() async {
    _morning = engine.resolveNight();
    _publish();
  }

  @override
  Future<void> beginDay() async {
    engine.beginDay();
    _publish();
  }

  @override
  Future<void> submitOpeningAccusation({
    required int seat,
    required int targetSeat,
  }) async {
    engine.submitOpeningAccusation(seat: seat, targetSeat: targetSeat);
    _publish();
  }

  @override
  Future<void> endConfrontation({required bool silent}) async {
    engine.endConfrontation(silent: silent);
    _publish();
  }

  @override
  Future<void> recordSpeaking({
    required int seat,
    required int seconds,
  }) async {
    engine.recordSpeaking(seat: seat, seconds: seconds);
    _publish();
  }

  @override
  Future<String> sendWhisper({
    required int fromSeat,
    required int toSeat,
    required String body,
  }) async {
    // The engine validates and records the edge; only then does the body get
    // written, so a rejected whisper leaves nothing behind anywhere.
    final id = engine.sendWhisper(
      fromSeat: fromSeat,
      toSeat: toSeat,
      body: body,
    );
    await whispers.put(
      matchId: engine.match.id,
      whisperId: id,
      body: body.trim(),
    );
    _publish();
    return id;
  }

  @override
  Future<void> markWhisperDelivered(String id) async {
    engine.markWhisperDelivered(id);
    _publish();
  }

  @override
  Future<void> beginVoting() async {
    engine.beginVoting();
    _lastVote = null;
    _publish();
  }

  @override
  Future<void> submitVote({
    required int seat,
    required int? targetSeat,
  }) async {
    engine.submitVote(seat: seat, voterSeat: seat, targetSeat: targetSeat);
    _publish();
  }

  @override
  Future<void> resolveDayVote() async {
    _lastVote = engine.resolveDayVote();
    _publish();
  }

  @override
  Future<void> winCheck() async {
    engine.winCheck();
    _publish();
  }

  @override
  Future<void> concludeAfterNight() async {
    engine.concludeAfterNight();
    _publish();
  }

  @override
  Future<void> advancePhase() async {
    // Offline there are no phase timers, so nothing calls this in the app. It
    // is implemented anyway, and honestly: the *guarantee* doc 10 §8.2 is about
    // — no phase can stall — is shared by both transports, and a local
    // implementation is what lets the fuzz harness prove it holds against the
    // same interface the server will.
    final move = defaultMoveOnExpiry(
      engine.match,
      phaseIndex: _phaseIndex(engine.match),
    );
    if (move == null) return;
    move.apply(engine);
    _publish();
  }

  /// A monotonically increasing index for the current phase, so two expiries in
  /// the same match never draw the same default.
  int _phaseIndex(Match match) =>
      match.dayNumber * GamePhase.values.length + match.phase.index;

  @override
  Future<void> resync() async {
    _publish();
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
