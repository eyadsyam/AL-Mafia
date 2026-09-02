import '../engine/models/enums.dart';
import '../engine/models/timeline_event.dart' show InvestigateResult;
import 'game_snapshot.dart';
import 'voice_link.dart';

/// One engine, two transports (doc 10 §7).
///
/// ## What this interface is for
///
/// It is the seam between *deciding* and *distributing*. The rules live in
/// `lib/engine/` and are the same in both modes; what differs is who runs them
/// and how the answer reaches a screen. Offline that is this device and a
/// function call. Online it is an Edge Function and a Realtime broadcast.
///
/// **The rule that makes it worth having:** *"the UI layer must never know
/// which transport is active. If a widget contains `if (isOnline)`, that is a
/// design failure — the only permitted exceptions are the voice controls and
/// the connection banner."* Both exceptions read [GameSnapshot.connection], not
/// the transport's type.
///
/// ## Why the commands return futures even offline
///
/// Because online they must, and one interface cannot have two shapes. What
/// [LocalTransport] guarantees in exchange is that the state is already
/// *applied* by the time the future is handed back — the engine is on this
/// device and there is nothing to wait for — so a caller may act on
/// [snapshot] immediately after the call without awaiting. That is what lets
/// the existing screens keep their synchronous flow through this refactor,
/// which is the whole gate for the phase that introduced it: offline play
/// behaves identically, and the abstraction is proven while there is still
/// exactly one implementation.
///
/// ## Authority
///
/// [isAuthoritative] is true offline and false online, and it is not a
/// rendering flag. It answers "may this client resolve a night itself" — which
/// only the transport asks, when it decides whether to compute or to call.
abstract class GameTransport {
  /// Every state the table may see, newest first on subscribe.
  ///
  /// A broadcast stream: several widgets watch it, and a late subscriber gets
  /// the current snapshot rather than nothing (doc 10 §8.4 — snapshots are the
  /// recovery path).
  Stream<GameSnapshot> watch();

  /// The latest snapshot, synchronously. Never null once a match has started.
  GameSnapshot get snapshot;

  /// What the seat currently holding the phone may see, or null when nobody
  /// does. Online, only ever this client's own seat.
  Future<ViewerSecrets?> secretsFor(int seat);

  // ---------------------------------------------------------------------------
  // Commands. Every one is a request; authority validates it.
  // ---------------------------------------------------------------------------

  /// Dismisses the role card the current viewer is holding.
  ///
  /// Offline it hands the phone on: the seat is done and the next one is up.
  /// Online there is nothing to hand on — each player is looking at their own
  /// card on their own device — so it records that this client is ready and the
  /// host opens the night when the room is. Both are "I have seen it", which is
  /// the only thing the screen is saying.
  Future<void> confirmRevealed();

  /// Opens the night.
  Future<void> beginNight();

  /// One night action. A null [targetSeat] records the turn with no choice —
  /// which every role may do (doc 05 rules 5 and 6; doc 10 §8.2).
  ///
  /// Returns the Detective's answer, and only for a Detective. It is a return
  /// value rather than a field on the snapshot because it is the one fact in
  /// the game that is never written down (doc 05 rule 10): it exists between
  /// this call and the pass, in the hand of one player, and nowhere else. A
  /// snapshot that carried it would be a snapshot that could be rebuilt with it
  /// still in place.
  Future<InvestigateResult?> submitNightAction({
    required int seat,
    required NightActionKind kind,
    required int? targetSeat,
  });

  /// Tallies the night.
  Future<void> resolveNight();

  /// Opens the day. Which surface that lands on is the engine's decision.
  Future<void> beginDay();

  /// One public accusation in the «اسم واحد» round.
  Future<void> submitOpeningAccusation({
    required int seat,
    required int targetSeat,
  });

  /// Closes the confrontation window.
  Future<void> endConfrontation({required bool silent});

  /// Opens free discussion, for the days that reach it without a confrontation.
  Future<void> beginDiscussion();

  /// Removes a player who has gone (doc 10 §8.1: "host may mark them «خرج» —
  /// treated as a neutral elimination, then a win check").
  ///
  /// A neutral elimination: no role is announced and nothing is attributed to
  /// the table, because nobody voted for it. Offline it is the host's decision
  /// about somebody who left the room; online it is the host's decision about
  /// somebody who has been silent for three minutes, and the server checks
  /// that they really have been.
  Future<void> removePlayer(int seat);

  /// Records a speaker's floor time.
  Future<void> recordSpeaking({required int seat, required int seconds});

  /// Sends a whisper. Returns its id; the body goes to the transport's own
  /// store, never into the snapshot.
  Future<String> sendWhisper({
    required int fromSeat,
    required int toSeat,
    required String body,
  });

  /// Marks a whisper read by its recipient.
  Future<void> markWhisperDelivered(String id);

  /// Opens the ballot.
  Future<void> beginVoting();

  /// One ballot. Null is an abstention.
  Future<void> submitVote({required int seat, required int? targetSeat});

  /// Tallies the ballot.
  Future<void> resolveDayVote();

  /// Advances past the elimination reveal, ending the match or rolling the day.
  Future<void> winCheck();

  /// Ends the match on a night that already decided it.
  Future<void> concludeAfterNight();

  /// Applies the phase's expiry default (doc 10 §8.2).
  ///
  /// Offline there are no phase timers, so this is only ever called by tests
  /// and by the fuzz harness; online it is the server's job and the client
  /// never calls it at all. It is on the interface because *the guarantee* is
  /// shared: no phase may stall.
  Future<void> advancePhase();

  /// Brings the snapshot back into step with authority, and republishes.
  ///
  /// Online this is the recovery path of doc 10 §8.4: a full read, because a
  /// client that has been away cannot know what it missed. Offline authority is
  /// this device, so there is nothing to fetch — but there is still something
  /// to do, because a match can be replaced wholesale underneath the transport
  /// (a resume from storage, a test parking the game in a phase) and the
  /// snapshot has to catch up.
  ///
  /// It is on the interface because both modes need the same guarantee: after
  /// this returns, what the screens can see is what authority says.
  Future<void> resync();

  /// The call, or null when this transport has none.
  ///
  /// Nullable on purpose, and null offline. Doc 10 §1.2 — *"voice is never
  /// load-bearing"* — is a promise that is only worth anything if it is
  /// structural, and this is where it becomes structural: there is no method
  /// above that a broken call can make fail, because the whole of voice hangs
  /// off one field that is allowed not to be there.
  VoiceLink? get voice;

  /// True when this device resolves the game itself.
  bool get isAuthoritative;

  /// Releases the stream and any connection behind it.
  Future<void> dispose();
}
