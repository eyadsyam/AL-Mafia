import 'package:meta/meta.dart';

import '../engine/information/records.dart';
import '../engine/information/trace_generator.dart';
import '../engine/models/enums.dart';
import '../engine/models/match.dart';
import '../engine/models/match_settings.dart';
import '../engine/models/timeline_event.dart' show InvestigateResult;
import '../engine/views.dart';

/// Everything the whole table may see at one moment (doc 10 §7).
///
/// ## The rule this type exists to make structural
///
/// *"The UI layer must never know which transport is active. Every screen takes
/// a `GameSnapshot` and calls the interface."*
///
/// A snapshot carries **no roles**: [public] is a `PublicMatchView`, whose
/// `PublicPlayer` has no role field, and nothing else here can name one. That
/// is not a filtering discipline — there is no role in the type to leak. The
/// online transport can therefore broadcast a snapshot to every client in the
/// room without deciding what to redact, and the offline transport can put the
/// same object on a screen in the middle of the table.
///
/// Anything a *single* player may see and the rest may not is in
/// [ViewerSecrets], which is built per seat and thrown away on the pass.
@immutable
class GameSnapshot {
  final PublicMatchView public;

  /// This morning's trace, as chosen when the night resolved. Public.
  final TraceResult? trace;

  /// Today's confrontation, if one was issued. Public.
  final Confrontation? confrontation;

  /// Today's «اسم واحد» accusations, seat → seat. Public.
  final Map<int, int> openingAccusations;

  /// Today's whisper graph. Public by design; bodies are never here.
  final List<WhisperMeta> whisperGraph;

  /// What the table was told about last night.
  final MorningReport? morning;

  /// The last ballot's outcome.
  final DayVoteResult? lastVote;

  /// The rules this match is being played under.
  ///
  /// On the snapshot because the screens need them — whether whispers are on,
  /// how long a speech runs, whether a tie means a revote — and because online
  /// they are a fact about the room rather than about this device. Offline they
  /// come off the `Match`; online out of `rooms.settings`. Nothing secret is in
  /// them: they are the same for every player and were chosen in front of
  /// everybody.
  final MatchSettings settings;

  /// The winner the *night* produced, before the table has been shown the
  /// result screen. Null whenever the match is still live.
  ///
  /// Distinct from `public.outcome`, which is the recorded end of a finished
  /// match. This one is the answer to "may the day open at all" — offline the
  /// engine computes it from the roster the moment the night resolves, and
  /// online the server writes it into the morning payload. Both mean the same
  /// thing, and the screen that reads it does not have to know which side
  /// worked it out.
  final Alignment? pendingOutcome;

  /// Whether the transport currently has a live link to authority.
  ///
  /// Always [ConnectionQuality.local] offline — the authority is this device,
  /// so there is nothing that can be disconnected from. The connection banner
  /// is one of the two widgets doc 10 §7 permits to branch on the transport,
  /// and this field is what it branches on.
  final ConnectionQuality connection;

  /// Which seats are currently connected, where that is a thing at all.
  ///
  /// Empty offline: there is one device and everybody is in the room, so the
  /// question does not arise. Online it drives the lobby's dots and the day's
  /// «غير متصل» — and it is **frozen for the whole night phase** (doc 10 §6.3).
  ///
  /// The freeze is here, in the transport, rather than in the widget that draws
  /// the dots. *"A player lagging while performing a role action is a tell."*
  /// A rule that lives in one screen is a rule the next screen does not have,
  /// so the night's snapshot carries the values from before the night and no
  /// widget has to remember why.
  final Map<int, bool> connectedSeats;

  /// Every player as the result screen shows them, once the match is over.
  ///
  /// Empty until then, in both modes and for the same reason: there is nothing
  /// in it that may be seen a moment earlier. Offline it is built from the
  /// `Match` the device already holds; online the server writes it into the
  /// public payload at the moment it sets the phase to `result`, which is the
  /// first instant every role is public information (FR-019).
  final List<FinalStanding> standings;

  /// Whether the post-game autopsy can be opened from the result screen.
  ///
  /// It reads the *local* match record — the event log, the analytics builder,
  /// the achievements — and an online match has not been written to this
  /// device's database. Rather than a button that opens an empty screen, the
  /// button is not offered.
  final bool analyticsAvailable;

  /// The seat this device belongs to, or null when the device belongs to the
  /// table rather than to a player.
  ///
  /// Offline it is null: the phone is passed, so "whose device is this" has no
  /// answer and `currentActorSeat` is the only question worth asking. Online it
  /// is this client's own seat, and it never names anybody else's.
  ///
  /// It is on the snapshot rather than on the transport so that a screen can
  /// read it without knowing which transport produced it — a screen asking
  /// "which seat am I" is not the same as a screen asking "am I online".
  final int? viewerSeat;

  /// Whether this device may drive the phase forward.
  ///
  /// True offline, where the device *is* the authority. Online it is true only
  /// on the host's client, because the server refuses a phase change from
  /// anybody else (`NOT_HOST`). Screens gate their "next" affordance on this
  /// rather than on the transport's type: "may I advance" is a fact about the
  /// state, and it is the one doc 10 §7 lets a widget read.
  final bool canAdvance;

  /// When the server says the current phase ends, or null when it does not end
  /// on a clock. Always null offline — offline nothing is timed by a server,
  /// and the pass-the-phone flow has no deadline to render.
  ///
  /// Already corrected for clock skew (O8): it is expressed against *this*
  /// device's clock, so a countdown is `deadline.difference(DateTime.now())`
  /// and a client whose clock is ten minutes out still renders the right
  /// number of seconds.
  final DateTime? phaseDeadline;

  /// The seat the server has given the floor to, or null when nobody holds it.
  ///
  /// Public by construction and safe to be: who is speaking is a thing the
  /// whole table can hear. It is null for the whole of the night and the whole
  /// of the ballot — not because it is filtered out, but because
  /// `micPolicyFor` refuses the floor in those phases and the server never
  /// wrote one (doc 10 §6.3).
  ///
  /// Always null offline. One phone in the middle of a table has one
  /// microphone and it belongs to whoever is holding it, which is a question
  /// the software has no part in.
  final int? activeSpeakerSeat;

  const GameSnapshot({
    required this.public,
    this.trace,
    this.confrontation,
    this.openingAccusations = const {},
    this.whisperGraph = const [],
    this.morning,
    this.lastVote,
    this.settings = const MatchSettings(),
    this.pendingOutcome,
    this.standings = const [],
    this.analyticsAvailable = true,
    this.connectedSeats = const {},
    this.connection = ConnectionQuality.local,
    this.viewerSeat,
    this.canAdvance = true,
    this.phaseDeadline,
    this.activeSpeakerSeat,
  });

  GamePhase get phase => public.phase;
  int get dayNumber => public.dayNumber;
  int? get currentActorSeat => public.currentActorSeat;
  MatchOutcome? get outcome => public.outcome;

  GameSnapshot copyWith({
    PublicMatchView? public,
    TraceResult? trace,
    Confrontation? confrontation,
    Map<int, int>? openingAccusations,
    List<WhisperMeta>? whisperGraph,
    MorningReport? morning,
    DayVoteResult? lastVote,
    MatchSettings? settings,
    Alignment? pendingOutcome,
    List<FinalStanding>? standings,
    bool? analyticsAvailable,
    Map<int, bool>? connectedSeats,
    ConnectionQuality? connection,
    int? viewerSeat,
    bool? canAdvance,
    DateTime? phaseDeadline,
    int? activeSpeakerSeat,
    bool clearMorning = false,
    bool clearVote = false,
    bool clearDeadline = false,
    bool clearSpeaker = false,
  }) =>
      GameSnapshot(
        public: public ?? this.public,
        trace: trace ?? this.trace,
        confrontation: confrontation ?? this.confrontation,
        openingAccusations: openingAccusations ?? this.openingAccusations,
        whisperGraph: whisperGraph ?? this.whisperGraph,
        morning: clearMorning ? null : (morning ?? this.morning),
        lastVote: clearVote ? null : (lastVote ?? this.lastVote),
        settings: settings ?? this.settings,
        pendingOutcome: pendingOutcome ?? this.pendingOutcome,
        standings: standings ?? this.standings,
        analyticsAvailable: analyticsAvailable ?? this.analyticsAvailable,
        connectedSeats: connectedSeats ?? this.connectedSeats,
        connection: connection ?? this.connection,
        viewerSeat: viewerSeat ?? this.viewerSeat,
        canAdvance: canAdvance ?? this.canAdvance,
        phaseDeadline:
            clearDeadline ? null : (phaseDeadline ?? this.phaseDeadline),
        activeSpeakerSeat: clearSpeaker
            ? null
            : (activeSpeakerSeat ?? this.activeSpeakerSeat),
      );

  @override
  String toString() =>
      'GameSnapshot(phase=${public.phase}, day=${public.dayNumber}, '
      'actor=${public.currentActorSeat}, connection=$connection)';
}

/// What exactly one player may see, and only while they hold the phone.
///
/// Offline this is built when the phone is handed over and dropped on the pass
/// (L-14). Online it is what a client fetches for *itself* — the Edge Function
/// never sends one player's secrets to another (doc 10 §1.3).
@immutable
class ViewerSecrets {
  final int seat;

  /// The viewer's own role. Present during distribution and their night turn.
  final Role? role;

  /// Fellow Mafia, by display name. Empty for every other role.
  final List<String> teammateNames;

  /// The night turn's targets and prompt, or null outside a turn.
  final ActorTurnView? turn;

  /// A Detective's result, from their confirm until their pass, and never
  /// again anywhere (doc 05 rule 10).
  final InvestigateResult? investigation;

  /// The whisper waiting for this seat, if any. Null means "none waiting" —
  /// which the card still renders, as a sentence (doc 11 H-E8).
  final String? whisperId;
  final String? whisperBody;

  /// True when this seat is being told that a whisper *they* sent never
  /// arrived, rather than being handed one.
  final bool whisperUndelivered;

  const ViewerSecrets({
    required this.seat,
    this.role,
    this.teammateNames = const [],
    this.turn,
    this.investigation,
    this.whisperId,
    this.whisperBody,
    this.whisperUndelivered = false,
  });
}

/// One player, as the result screen names them.
///
/// The role is here and nowhere else in this file: it is the one moment the
/// game is over and every role is public by design. A snapshot taken before
/// the result phase carries an empty list, so there is no moment at which this
/// type exists with something still secret in it.
@immutable
class FinalStanding {
  final int seat;
  final String name;
  final Role role;

  /// The phase and number this player went out on, or null if they survived.
  final GamePhase? eliminatedPhase;
  final int? eliminatedNumber;

  const FinalStanding({
    required this.seat,
    required this.name,
    required this.role,
    this.eliminatedPhase,
    this.eliminatedNumber,
  });
}

/// How the transport is currently connected to authority.
enum ConnectionQuality {
  /// Offline. This device *is* the authority, so there is nothing to lose.
  local,

  /// Online and in sync.
  connected,

  /// Online, retrying. Play continues against the last snapshot.
  reconnecting,

  /// Online, given up for now. The client shows the banner and keeps state.
  offline,
}
