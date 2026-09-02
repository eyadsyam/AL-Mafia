import 'models/enums.dart';

/// Who may hold a live microphone, phase by phase (doc 10 §6.3).
///
/// ## Why this is in the engine
///
/// Because it is a rule of the game and not a feature of the call. The table
/// in doc 10 §6.3 is written as a leakage rule — *"the app must not show
/// connection quality, speaking indicators, or typing states during the night;
/// a player lagging while performing a role action is a tell"* — and a rule
/// that decides what may be observed belongs beside the rules that decide what
/// may be known.
///
/// It is also a rule two implementations have to agree on. The client mutes
/// itself and the server refuses the floor, and if those two ever disagreed the
/// disagreement would be a live microphone during a night. So the table exists
/// once, here, in the layer that has no Flutter and no clock, and
/// `supabase/functions/_shared/voice.ts` mirrors it line for line with a golden
/// vector holding them together.
///
/// ## Why it is not "can I speak"
///
/// [MicPolicy] answers what the *phase* permits. Whether **this** player may
/// speak is that answer plus one more fact — do they hold the floor — and that
/// fact is the server's, never the client's. Keeping the two apart is what
/// makes [MicPolicy.activeSpeakerOnly] a hard mute by default rather than a
/// permission granted by the device that would like it.
enum MicPolicy {
  /// Anyone may speak. The lobby, free discussion, and after the game is over.
  open,

  /// Exactly one seat's microphone is live, and the server says which.
  activeSpeakerOnly,

  /// Nobody's. Hard muted, and — during the night — torn down entirely.
  muted,
}

/// The microphone policy for a phase, as doc 10 §6.3 writes it.
///
/// Total over [GamePhase] by construction: a phase this function did not
/// anticipate would otherwise default to something, and the only safe default
/// in a game about hidden roles is silence. There is no `default:` clause, so
/// adding a phase to the enum fails the analyzer here rather than shipping a
/// microphone that is open because nobody remembered to close it.
MicPolicy micPolicyFor(
  GamePhase phase, {
  DiscussionMode discussion = DiscussionMode.structured,
}) {
  switch (phase) {
    // ── Open ──────────────────────────────────────────────────────────────
    //
    // Nothing is secret yet, or nothing is secret any more.
    case GamePhase.setup:
    case GamePhase.rolesConfigured:
    case GamePhase.result:
    case GamePhase.analytics:
      return MicPolicy.open;

    // ── The private stretch ───────────────────────────────────────────────
    //
    // Role reveal, the night, and the resolution either side of it. Doc 10
    // §6.3 marks the night "hard muted for everyone, no exceptions" and the
    // reveal "hard muted, server-enforced"; `preNightLobby` sits between them
    // holding a phone that has just shown somebody their role, so it is the
    // same stretch and gets the same answer.
    case GamePhase.distributing:
    case GamePhase.preNightLobby:
    case GamePhase.night:
    case GamePhase.nightResolving:
      return MicPolicy.muted;

    // ── The app is speaking ───────────────────────────────────────────────
    //
    // Morning and the elimination reveal are announcements. A player talking
    // over them is not a leak, but the trace is the one thing every day turns
    // on and it is read aloud once.
    case GamePhase.morning:
    case GamePhase.reveal:
    case GamePhase.winCheck:
      return MicPolicy.muted;

    // ── One voice at a time ───────────────────────────────────────────────
    //
    // The opening round points the phone at one seat for ten seconds; the
    // confrontation gives the floor to the player who was named. Both are
    // "only this seat", which is what the token is.
    case GamePhase.openingRound:
    case GamePhase.confrontation:
      return MicPolicy.activeSpeakerOnly;

    /// Structured discussion is a queue and free discussion is a room.
    case GamePhase.discussion:
      return discussion == DiscussionMode.free
          ? MicPolicy.open
          : MicPolicy.activeSpeakerOnly;

    // ── The ballot ────────────────────────────────────────────────────────
    //
    // "Voting — hard muted". Talking during a ballot is how a table gets
    // talked into a vote, and the design has already spent the discussion on
    // that.
    case GamePhase.voting:
    case GamePhase.voteResolving:
      return MicPolicy.muted;
  }
}

/// True for the phases where voice is not merely muted but taken down.
///
/// The distinction matters because a muted track is still a connection, and a
/// connection has state a curious client could read — who is publishing, whose
/// bitrate just collapsed, who reconnected in the eleven seconds the Doctor
/// was choosing. Doc 10 §6.3 asks for exactly this and calls it critical:
/// *"freeze all per-player status indicators for the whole night phase"*. The
/// cheapest way to freeze an indicator is to have nothing to indicate.
bool voiceTornDownIn(GamePhase phase) =>
    phase == GamePhase.night ||
    phase == GamePhase.nightResolving ||
    phase == GamePhase.distributing ||
    phase == GamePhase.preNightLobby;
