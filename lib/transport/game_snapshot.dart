import 'package:meta/meta.dart';

import '../engine/information/records.dart';
import '../engine/information/trace_generator.dart';
import '../engine/models/enums.dart';
import '../engine/models/match.dart';
import '../engine/models/match_settings.dart';
import '../engine/models/timeline_event.dart' show InvestigateResult;
import '../engine/views.dart';

/// The room's own settings, as distinct from the match's rules (task 10).
///
/// [MatchSettings] is what the *engine* plays by, and it is deliberately
/// ignorant of rooms: it has no idea whether anybody is talking, how many
/// seats there are, or whether this room is listed anywhere. Those three are
/// facts about a lobby, they mean nothing offline, and putting them in
/// `MatchSettings` would put them in front of the offline setup screen too.
///
/// Every field has the value a room created before this existed would have had,
/// so an older room reads as a private ten-seat room with voice on.
class RoomOptions {
  /// private | public.
  final String visibility;

  /// The host's name for a public room; null when they have not given one.
  final String? title;

  final int maxPlayers;

  /// Whether the room has voice at all. Off is a legitimate choice, not a
  /// failure: doc 10 §1.2 — the match completes either way.
  final bool voice;

  /// Whether every microphone is dropped for the duration of a night. On by
  /// default, because a night is the one phase where a voice carries a fact
  /// about who is awake.
  final bool muteAllAtNight;
  final String scenarioCode;

  /// The host's presentation pack for the room ('classic' = none). Cosmetic
  /// only: the engine never reads it, and every seat sees the same thing.
  final String presentationPack;

  /// The host's narrator pack ('classic' = none). Same rules.
  final String narratorPack;

  const RoomOptions({
    this.visibility = 'private',
    this.title,
    this.maxPlayers = 10,
    this.voice = true,
    this.muteAllAtNight = true,
    this.scenarioCode = 'classic',
    this.presentationPack = 'classic',
    this.narratorPack = 'classic',
  });

  bool get isPublic => visibility == 'public';

  RoomOptions copyWith({
    String? visibility,
    String? title,
    int? maxPlayers,
    bool? voice,
    bool? muteAllAtNight,
    String? scenarioCode,
    String? presentationPack,
    String? narratorPack,
  }) => RoomOptions(
    visibility: visibility ?? this.visibility,
    title: title ?? this.title,
    maxPlayers: maxPlayers ?? this.maxPlayers,
    voice: voice ?? this.voice,
    muteAllAtNight: muteAllAtNight ?? this.muteAllAtNight,
    scenarioCode: scenarioCode ?? this.scenarioCode,
    presentationPack: presentationPack ?? this.presentationPack,
    narratorPack: narratorPack ?? this.narratorPack,
  );
}

/// A seat's chosen frame and nameplate codes. Unknown codes draw nothing.
class SeatCosmetics {
  final String? frame;
  final String? plate;

  /// The player's Council level when they sat down (phase 107): earned from
  /// matches already over, fixed for this one, and never about a role.
  final int? rank;
  const SeatCosmetics({this.frame, this.plate, this.rank});

  static SeatCosmetics? fromJson(Object? json) {
    if (json is! Map) return null;
    final frame = json['frame'];
    final plate = json['nameplate'];
    final rank = json['rank'];
    final level = rank is num && rank >= 1 && rank <= 50 ? rank.toInt() : null;
    if (frame is! String && plate is! String && level == null) return null;
    return SeatCosmetics(
      frame: frame is String ? frame : null,
      plate: plate is String ? plate : null,
      rank: level,
    );
  }
}

/// One row of the «أوض عامة» browse list. Four fields, and deliberately no
/// room id: joining goes through the code, exactly as it does for a room
/// somebody was told about.
class PublicRoom {
  /// The server defaults, used when an older server omits the fields: a room
  /// with no valid `maxPlayers` holds ten, and start_match needs five.
  static const defaultCapacity = 10;
  static const defaultMinPlayers = 5;

  final String code;
  final String? title;

  /// Seats that are not kicked — the same count admission and start use.
  final int players;
  final int capacity;
  final int minPlayers;
  final bool voice;

  /// A server-owned empty waiting room: nobody is in it, and the first player
  /// to join becomes its host. Never shown as an occupied room.
  final bool waiting;

  const PublicRoom({
    required this.code,
    required this.players,
    required this.voice,
    this.title,
    this.capacity = defaultCapacity,
    this.minPlayers = defaultMinPlayers,
    this.waiting = false,
  });

  bool get isFull => players >= capacity;

  /// How many more players the host needs before they may start. Zero means
  /// the host *can* start — not that the match is starting.
  int get missingToStart => (minPlayers - players).clamp(0, minPlayers);

  factory PublicRoom.fromJson(Map<String, dynamic> json) => PublicRoom(
    code: json['code'] as String? ?? '',
    title: json['title'] as String?,
    players: (json['players'] as num?)?.toInt() ?? 0,
    capacity: (json['capacity'] as num?)?.toInt() ?? defaultCapacity,
    minPlayers: (json['min_players'] as num?)?.toInt() ?? defaultMinPlayers,
    voice: json['voice'] as bool? ?? true,
    waiting: json['waiting'] as bool? ?? false,
  );

  /// Joinable rooms nearest to starting first; full rooms last. The server
  /// already orders this way; sorting again keeps an older server's list
  /// (newest first) in the same order the cards describe.
  static List<PublicRoom> ordered(Iterable<PublicRoom> rooms) {
    final list = rooms.toList();
    // Dart's sort is not stable; ties keep the server's order explicitly.
    final position = {for (var i = 0; i < list.length; i++) list[i]: i};
    // Rooms with people first, then the empty waiting room, then full ones.
    int rank(PublicRoom r) => r.isFull
        ? 2
        : r.waiting
        ? 1
        : 0;
    list.sort((a, b) {
      final byFull = rank(a).compareTo(rank(b));
      if (byFull != 0) return byFull;
      final byMissing = a.missingToStart.compareTo(b.missingToStart);
      if (byMissing != 0) return byMissing;
      final byPlayers = b.players.compareTo(a.players);
      if (byPlayers != 0) return byPlayers;
      return position[a]!.compareTo(position[b]!);
    });
    return list;
  }
}

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

  /// The ballot as it stands, voter seat to target seat, while the day's vote
  /// is still open. Null is an abstention; an absent key has not voted yet.
  ///
  /// **Empty unless the room chose an open ballot** (`MatchSettings.openVoting`,
  /// doc 12 §3.6). Empty offline in every case: one phone in the middle of a
  /// table already has a secret ballot, and this is the field that would take
  /// it away.
  ///
  /// It is the one thing on the snapshot that only an online game can carry,
  /// and it is here rather than behind a transport check because a screen
  /// asking "what does the table know about the vote" is not a screen asking
  /// "am I online". A closed ballot answers "nothing", which is a real answer
  /// and renders as a table with no lines on it.
  ///
  /// The server enforces this, not the client: `votes_read` refuses the rows
  /// unless the room's own settings say otherwise, so a patched client sees the
  /// same empty map.
  final Map<int, int?> liveBallots;

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

  /// The seats that have asked for the floor and not been given it.
  ///
  /// Doc 15 §1.4, resolved 2026-09-07: this is a **set**, and the type is the
  /// argument. There is no queue on the server — `micPolicyFor` grants the
  /// floor to whoever claims it and is allowed to have it — so an ordered
  /// collection here would be an order the app made up, and non-negotiable 4
  /// forbids the app inventing a fact. A set cannot be printed as a queue by
  /// accident; a list can.
  ///
  /// Safe by the same argument as [activeSpeakerSeat]: raising a hand is a
  /// public, voluntary act available to every living player in exactly the
  /// phases where every living player may speak. It is empty for the whole of
  /// the night and the whole of the ballot, because the server refuses to
  /// record a request it would never honour.
  ///
  /// Always empty offline. One phone has one microphone.
  final Set<int> raisedHands;

  /// The living seats that have said «جاهزين للتصويت» in this discussion
  /// (owner, 2026-09-24). Public by nature — it is said to the whole table —
  /// and empty outside the discussion and always offline.
  final Set<int> readyToVoteSeats;

  /// Public pre-deal confirmation for the current lobby revision.
  final Set<int> lobbyReadySeats;
  final Set<int> lobbyReadyExpiredSeats;

  /// Each unready seat's one ready deadline for this revision, on the
  /// server's clock (F8). Screens convert it with the transport's
  /// `onLocalClock` before counting down (D9).
  final Map<int, DateTime> lobbyReadyDeadlines;
  final int lobbyRevision;

  /// The seats the host has silenced for the whole room (task 6).
  ///
  /// Every client subtracts these from what it will play, which is the only
  /// place a mute can actually be enforced: a mesh has no server in the media
  /// path, so the drop happens at fifteen ears rather than once in the middle.
  final Set<int> mutedSeats;

  /// True when the host removed *this* device's player.
  ///
  /// The ban list is a fact about the room and never crosses; this is the one
  /// bit of it the ejected player is entitled to, on their own row.
  final bool viewerKicked;

  /// The seat the room's host is sitting in, or null when nobody in the
  /// roster holds it.
  ///
  /// A seat rather than a user id, for the reason every other identity on this
  /// object is a seat: a screen knows seats, and a user id on a snapshot is a
  /// fact about a person that nothing above the transport needs. Null offline,
  /// where the device *is* the authority and there is nobody to name.
  final int? hostSeat;

  /// True when the room was closed without being won.
  ///
  /// Task 5 draws the line: a host who leaves does not end a match, and a host
  /// who taps «اقفل الأوضة» does. This is the second one — a finished room with
  /// no outcome — and it is the only thing that puts every client back on Home
  /// without a winner.
  final bool roomClosed;

  /// How present each seat is, as the server aged it.
  ///
  /// Three states because two were not enough to draw the table honestly. A
  /// player who put the phone down for ten seconds and a player who closed the
  /// app and went to bed were the same row, and both kept a face on the table.
  ///
  /// Empty offline, where everybody is in the room by definition.
  final Map<int, SeatPresence> presence;

  /// The seats that have not yet dismissed their role card.
  ///
  /// Empty offline, where the deal *is* a sequence of dismissals and the flow
  /// cannot reach the night until the last phone has been handed back. Online
  /// every player is looking at their own card at the same moment, so "has
  /// everybody seen theirs" is a real question, and the server answers it —
  /// `room_players.saw_role`, written by one Edge Function and re-checked by
  /// `open_phase` before it will open the night.
  ///
  /// It carries seats and the screen turns them into names. Whether a seat has
  /// dismissed a card says nothing about what was on it.
  final Set<int> unseenRoleSeats;

  /// The room's own settings — visibility, title, capacity, voice. Empty
  /// defaults offline, where there is no room.
  final RoomOptions room;

  /// What each seat chose to wear (frame, nameplate), copied by the server
  /// when the seat was taken. Identity, never role; empty offline.
  final Map<int, SeatCosmetics> seatCosmetics;

  /// Public ballot iteration; changes on a same-day revote.
  final int ballotRound;

  /// Server-published tied seats for a revote; never inferred from a local tally.
  final Set<int> ballotCandidates;

  /// Only this viewer's acknowledged ballot, never another player's status.
  final bool viewerVoteRecorded;

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
    this.liveBallots = const {},
    this.connection = ConnectionQuality.local,
    this.viewerSeat,
    this.canAdvance = true,
    this.phaseDeadline,
    this.activeSpeakerSeat,
    this.raisedHands = const {},
    this.readyToVoteSeats = const {},
    this.lobbyReadySeats = const {},
    this.lobbyReadyExpiredSeats = const {},
    this.lobbyReadyDeadlines = const {},
    this.lobbyRevision = 0,
    this.unseenRoleSeats = const {},
    this.presence = const {},
    this.hostSeat,
    this.roomClosed = false,
    this.mutedSeats = const {},
    this.viewerKicked = false,
    this.room = const RoomOptions(),
    this.seatCosmetics = const {},
    this.ballotRound = 1,
    this.ballotCandidates = const {},
    this.viewerVoteRecorded = false,
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
    Map<int, int?>? liveBallots,
    ConnectionQuality? connection,
    int? viewerSeat,
    bool? canAdvance,
    DateTime? phaseDeadline,
    int? activeSpeakerSeat,
    Set<int>? raisedHands,
    Set<int>? readyToVoteSeats,
    Set<int>? lobbyReadySeats,
    Set<int>? lobbyReadyExpiredSeats,
    Map<int, DateTime>? lobbyReadyDeadlines,
    int? lobbyRevision,
    Set<int>? unseenRoleSeats,
    Map<int, SeatPresence>? presence,
    int? hostSeat,
    bool? roomClosed,
    Set<int>? mutedSeats,
    bool? viewerKicked,
    RoomOptions? room,
    Map<int, SeatCosmetics>? seatCosmetics,
    int? ballotRound,
    Set<int>? ballotCandidates,
    bool? viewerVoteRecorded,
    bool clearMorning = false,
    bool clearVote = false,
    bool clearDeadline = false,
    bool clearSpeaker = false,
  }) => GameSnapshot(
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
    liveBallots: liveBallots ?? this.liveBallots,
    connection: connection ?? this.connection,
    viewerSeat: viewerSeat ?? this.viewerSeat,
    canAdvance: canAdvance ?? this.canAdvance,
    phaseDeadline: clearDeadline ? null : (phaseDeadline ?? this.phaseDeadline),
    activeSpeakerSeat: clearSpeaker
        ? null
        : (activeSpeakerSeat ?? this.activeSpeakerSeat),
    // A cleared floor clears the hands with it, for the same reason the
    // server's trigger does: the thing being asked for no longer exists.
    raisedHands: clearSpeaker ? const {} : (raisedHands ?? this.raisedHands),
    readyToVoteSeats: readyToVoteSeats ?? this.readyToVoteSeats,
    lobbyReadySeats: lobbyReadySeats ?? this.lobbyReadySeats,
    lobbyReadyExpiredSeats:
        lobbyReadyExpiredSeats ?? this.lobbyReadyExpiredSeats,
    lobbyReadyDeadlines: lobbyReadyDeadlines ?? this.lobbyReadyDeadlines,
    lobbyRevision: lobbyRevision ?? this.lobbyRevision,
    unseenRoleSeats: unseenRoleSeats ?? this.unseenRoleSeats,
    presence: presence ?? this.presence,
    hostSeat: hostSeat ?? this.hostSeat,
    roomClosed: roomClosed ?? this.roomClosed,
    mutedSeats: mutedSeats ?? this.mutedSeats,
    viewerKicked: viewerKicked ?? this.viewerKicked,
    room: room ?? this.room,
    seatCosmetics: seatCosmetics ?? this.seatCosmetics,
    ballotRound: ballotRound ?? this.ballotRound,
    ballotCandidates: ballotCandidates ?? this.ballotCandidates,
    viewerVoteRecorded: viewerVoteRecorded ?? this.viewerVoteRecorded,
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
/// How present one player is (task 3), as the server aged it.
///
/// The three states are drawn differently and deliberately (task 4): a
/// connected seat has a face in its ring, an away seat has the ring and
/// nothing inside it, and a seat that left is gone from a lobby and cracked in
/// a match. The empty ring carries no label, because the table is supposed to
/// notice it and wonder.
enum SeatPresence {
  connected,
  away,
  left;

  static SeatPresence fromServer(String? value) => switch (value) {
    'away' => SeatPresence.away,
    'left' => SeatPresence.left,
    _ => SeatPresence.connected,
  };
}

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
