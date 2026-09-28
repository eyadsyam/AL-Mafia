/// Server rows → the same objects the offline game is made of.
///
/// ## Why this file is not "the online model"
///
/// There is no online model. A screen renders a [GameSnapshot], and this
/// decodes one out of `room_state` and `room_players_public` — the same class,
/// with the same fields, that `LocalTransport` builds out of a `Match`. When
/// the two modes disagree about anything, they disagree *here*, in one file,
/// in front of a test — not across a hundred widgets that learned to branch.
///
/// ## What may cross
///
/// Only the public payload. `public_data` is written by the Edge Functions and
/// is table-visible by construction; the roster comes from the view that nulls
/// every role but the reader's own. Nothing in this file can put a role on a
/// screen, because nothing it builds has a field for one — the viewer's own
/// role goes to [ViewerSecrets], which is assembled per client and never
/// broadcast.
library transport.room_codec;

import '../engine/information/records.dart';
import '../engine/information/trace_generator.dart';
import '../engine/models/enums.dart';
import '../engine/models/information_enums.dart';
import '../engine/models/match.dart';
import '../engine/models/match_settings.dart';
import '../engine/models/player.dart';
import '../engine/views.dart';
import '../engine/voice_policy.dart';
import 'game_snapshot.dart';
import 'online_backend.dart';

/// The server's phase vocabulary (`room_state.phase`) → the engine's.
///
/// `defense` maps to [GamePhase.discussion] because the app has one discussion
/// surface and the schema's `defense` is a label for a stretch of it, not a
/// screen of its own. Everything else is one-to-one, which is deliberate: two
/// vocabularies that nearly line up are worse than two that do.
GamePhase phaseFromServer(String phase) => switch (phase) {
  'lobby' => GamePhase.setup,
  'reveal' => GamePhase.distributing,
  'night' => GamePhase.night,
  'morning' => GamePhase.morning,
  'opening' => GamePhase.openingRound,
  'confront' => GamePhase.confrontation,
  'discuss' => GamePhase.discussion,
  'defense' => GamePhase.discussion,
  'vote' => GamePhase.voting,
  // The beat after the ballot: who went, and what they were. It is
  // `GamePhase.reveal` because that is the phase the card-rise and the
  // «فلان كان ...» band are already written against — the offline flow has had
  // this beat since the beginning, and online it had nowhere to happen.
  'verdict' => GamePhase.reveal,
  'result' => GamePhase.result,
  _ => GamePhase.setup,
};

/// The inverse, for the phase a client asks the server to open.
String phaseToServer(GamePhase phase) => switch (phase) {
  GamePhase.setup || GamePhase.rolesConfigured => 'lobby',
  GamePhase.distributing || GamePhase.preNightLobby => 'reveal',
  GamePhase.night || GamePhase.nightResolving => 'night',
  GamePhase.morning => 'morning',
  GamePhase.openingRound => 'opening',
  GamePhase.confrontation => 'confront',
  GamePhase.discussion => 'discuss',
  GamePhase.voting || GamePhase.voteResolving => 'vote',
  GamePhase.reveal || GamePhase.winCheck => 'verdict',
  GamePhase.result || GamePhase.analytics => 'result',
};

Role? roleFromServer(String? role) => switch (role) {
  'mafia' => Role.mafia,
  'doctor' => Role.doctor,
  'detective' => Role.detective,
  'citizen' => Role.citizen,
  _ => null,
};

String roleToServer(Role role) => role.name;

/// The engine's action kind → the string the server stores.
///
/// The two vocabularies differ in exactly one word: the engine calls the
/// Mafia's move a *vote*, because offline it is one — several Mafiosi choose in
/// turn and the tie is broken afterwards. The server calls the row a `kill`.
/// Translating in one function is the whole of keeping that difference from
/// spreading.
String nightActionToServer(NightActionKind kind) => switch (kind) {
  NightActionKind.mafiaVote => 'kill',
  NightActionKind.protect => 'protect',
  NightActionKind.investigate => 'investigate',
  NightActionKind.suspect => 'suspect',
};

TraceResult? traceFromJson(Object? value) {
  if (value is! Map) return null;
  final name = value['type'] as String?;
  if (name == null) return null;
  return TraceResult(
    type: TraceType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => TraceType.t0,
    ),
    subjectSeat: (value['subjectSeat'] as num?)?.toInt(),
    targetSeat: (value['targetSeat'] as num?)?.toInt(),
    count: (value['count'] as num?)?.toInt(),
  );
}

Confrontation? confrontationFromJson(Object? value) {
  if (value is! Map) return null;
  final name = value['type'] as String?;
  final target = (value['targetSeat'] as num?)?.toInt();
  if (name == null || target == null) return null;
  return Confrontation(
    type: ConfrontationType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => ConfrontationType.c10,
    ),
    targetSeat: target,
    evidenceSeat: (value['evidenceSeat'] as num?)?.toInt(),
    evidenceSeat2: (value['evidenceSeat2'] as num?)?.toInt(),
    evidenceDay: (value['evidenceDay'] as num?)?.toInt(),
    count: (value['count'] as num?)?.toInt(),
  );
}

MorningReport? morningFromJson(Object? value) {
  if (value is! Map) return null;
  final victim = (value['victimSeat'] as num?)?.toInt();
  final saved = value['someoneSavedUnnamed'] as bool? ?? false;
  return MorningReport(
    victimSeat: victim,
    someoneSavedUnnamed: saved,
    allSurvived: victim == null && !saved,
  );
}

DayVoteResult? voteFromJson(Object? value) {
  if (value is! Map) return null;
  final tally = <int, int>{
    for (final e in ((value['tally'] as Map?) ?? const {}).entries)
      int.parse('${e.key}'): (e.value as num).toInt(),
  };
  final tied = [
    for (final s in (value['tiedSeats'] as List?) ?? const [])
      (s as num).toInt(),
  ];
  return DayVoteResult(
    eliminatedSeat: (value['eliminatedSeat'] as num?)?.toInt(),
    tally: tally.isEmpty ? null : tally,
    tie: tied.length > 1,
    tiedSeats: tied.isEmpty ? null : tied,
    eliminatedRole: roleFromServer(value['eliminatedRole'] as String?),
  );
}

Map<int, int> accusationsFromJson(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final e in value.entries)
      int.parse('${e.key}'): (e.value as num).toInt(),
  };
}

List<WhisperMeta> whisperGraph(List<WhisperRow> rows, int day) => [
  for (final row in rows.where((w) => w.day == day))
    WhisperMeta(
      id: row.id,
      day: row.day,
      fromSeat: row.fromSeat,
      toSeat: row.toSeat,
      voided: row.voided,
    ),
];

/// The final standings, which the server writes only when it sets `result`.
///
/// Nothing here filters anything: if the key is absent the list is empty, and
/// the key is absent for the whole of a live match. That is the difference
/// between a screen that may not show roles and a payload that does not have
/// any.
List<FinalStanding> standingsFromJson(Object? value, List<RoomPlayer> players) {
  if (value is! List) return const [];
  final nameOf = {for (final p in players) p.seat: p.name};
  final out = <FinalStanding>[];
  for (final entry in value) {
    if (entry is! Map) continue;
    final seat = (entry['seat'] as num?)?.toInt();
    final role = roleFromServer(entry['role'] as String?);
    if (seat == null || role == null) continue;
    out.add(
      FinalStanding(
        seat: seat,
        name: nameOf[seat] ?? '',
        role: role,
        eliminatedPhase: switch (entry['eliminatedPhase']) {
          'night' => GamePhase.night,
          'day' => GamePhase.voting,
          _ => null,
        },
        eliminatedNumber: (entry['eliminatedNumber'] as num?)?.toInt(),
      ),
    );
  }
  out.sort((a, b) => a.seat.compareTo(b.seat));
  return out;
}

/// Builds the snapshot every screen reads.
///
/// [viewerSeat] is this client's own seat and is the one thing here that is not
/// symmetric across the room. It reaches the snapshot because a screen needs to
/// know which seat it is drawing *for*, never which role it holds.
GameSnapshot snapshotFrom({
  required RoomState state,
  required List<RoomPlayer> players,
  required int? viewerSeat,
  required bool isHost,
  required ConnectionQuality connection,
  required Duration skew,
  List<WhisperRow> whispers = const [],
  bool ownTurnPending = false,
  bool viewerVoteRecorded = false,
  Map<int, bool>? frozenConnected,
  Map<int, SeatPresence>? frozenPresence,
  Map<int, int?> liveBallots = const {},
}) {
  final phase = phaseFromServer(state.phase);
  final data = state.publicData;

  // A pre-deal removal retains its notification row, not a place in the match.
  // Once dealt, the public seat list stays fixed, including later departures.
  final dealtSeats = data['rosterSeats'];
  final roster = players.where((p) {
    if (state.phase == 'lobby') return !p.kicked;
    return dealtSeats is! List || dealtSeats.contains(p.seat);
  }).toList()..sort((a, b) => a.seat.compareTo(b.seat));
  final public = PublicMatchView(
    phase: phase,
    dayNumber: state.phaseNumber,
    players: [
      for (final p in roster)
        PublicPlayer(
          seat: p.seat,
          name: p.name,
          gender: PlayerGender.values.firstWhere(
            (g) => g.name == p.gender,
            orElse: () => PlayerGender.unspecified,
          ),
          status: p.alive ? PlayerStatus.alive : PlayerStatus.dead,
        ),
    ],
    // Online there is no phone to pass: every client acts at once, on its own
    // device. `currentActorSeat` therefore answers "is it *my* turn", which is
    // the only form of the question a single client can act on — and the
    // screens already ask it that way, so nothing about them changes.
    currentActorSeat: ownTurnPending ? viewerSeat : null,
    morningReport: morningFromJson(data['morning']),
    outcome: _outcome(data, state),
  );

  final deadline = state.phaseEndsAt?.subtract(skew);

  return GameSnapshot(
    public: public,
    ballotRound: ((data['revote'] as Map?)?['round'] as num?)?.toInt() ?? 1,
    ballotCandidates: {
      for (final seat
          in ((data['revote'] as Map?)?['tiedSeats'] as List?) ?? const [])
        if (seat is int) seat,
    },
    viewerVoteRecorded: phase == GamePhase.voting && viewerVoteRecorded,
    lobbyRevision: state.lobbyRevision,
    lobbyReadySeats: state.phase == 'lobby'
        ? {
            for (final player in roster)
              if (player.lobbyReady) player.seat,
          }
        : const {},
    lobbyReadyExpiredSeats: state.phase == 'lobby'
        ? {
            for (final player in roster)
              if (player.readyExpired) player.seat,
          }
        : const {},
    trace: traceFromJson((data['morning'] as Map?)?['trace']),
    confrontation: confrontationFromJson(data['confrontation']),
    openingAccusations: accusationsFromJson(data['openingAccusations']),
    whisperGraph: whisperGraph(whispers, state.phaseNumber),
    morning: morningFromJson(data['morning']),
    lastVote: voteFromJson(data['lastVote']),
    settings: settingsFromJson(state.settings),
    room: RoomOptions(
      visibility: state.visibility,
      title: state.title,
      maxPlayers: (state.settings['maxPlayers'] as num?)?.toInt() ?? 10,
      voice: state.settings['voice'] as bool? ?? true,
      muteAllAtNight: state.settings['muteAllAtNight'] as bool? ?? true,
      scenarioCode: state.settings['scenarioCode'] as String? ?? 'classic',
      presentationPack:
          state.settings['presentationPack'] as String? ?? 'classic',
      narratorPack: state.settings['narratorPack'] as String? ?? 'classic',
    ),
    pendingOutcome: switch (data['outcome']) {
      'mafia' => Alignment.mafia,
      'town' => Alignment.town,
      _ => null,
    },
    standings: standingsFromJson(data['standings'], roster),
    // Doc 10 §6.3 — frozen for the whole night, and for the reveal that
    // precedes it. The transport hands in the values from before it started;
    // a live map here would report on who is still deciding.
    connectedSeats:
        frozenConnected ?? {for (final p in roster) p.seat: p.connected},
    mutedSeats: {
      for (final p in roster)
        if (p.muted) p.seat,
    },
    seatCosmetics: {
      for (final p in roster)
        if (p.cosmetics != null) p.seat: p.cosmetics!,
    },
    viewerKicked: players
        .where((p) => p.seat == viewerSeat)
        .any((p) => p.kicked),
    hostSeat: roster
        .where((p) => p.userId == state.hostId)
        .map((p) => p.seat)
        .firstOrNull,
    // A finished room with nothing in the payload that says anybody won. The
    // only way to reach it is `close_room`, which deliberately writes no
    // outcome — a room that was closed was not a room that was won, and
    // inventing an ending would be exactly what rule 4 forbids.
    roomClosed: state.status == 'finished' && data['outcome'] == null,
    // Frozen for the night for the same reason `connectedSeats` is: a table
    // that watched people arrive and leave while the room was dark would be
    // reporting on who is still deciding.
    presence:
        frozenPresence ??
        {for (final p in roster) p.seat: SeatPresence.fromServer(p.status)},
    // Doc 12 §3.6. Empty unless the room opted into an open ballot, and empty
    // then too until somebody votes — the policy decides, not this file.
    liveBallots: liveBallots,
    // The post-game autopsy reads a local match record, and an online match
    // has not been written to this device's database.
    analyticsAvailable: false,
    connection: connection,
    viewerSeat: viewerSeat,
    canAdvance: isHost,
    phaseDeadline: deadline,
    // Whose microphone the server says is live, as a seat rather than as a
    // user id — the screens know seats, and a user id on a snapshot is a fact
    // about a person that nothing above the transport should need.
    //
    // The night needs no special case here: `micPolicyFor` refuses the floor
    // in every dark phase, so `active_speaker` was never written and there is
    // nothing to redact.
    activeSpeakerSeat: state.activeSpeaker == null
        ? null
        : roster
              .where((p) => p.userId == state.activeSpeaker)
              .map((p) => p.seat)
              .firstOrNull,
    // Who has asked. Read straight off the roster and kept as a set, because
    // the moment it became a list somebody would sort it by `hand_raised_at`
    // and the queue doc 15 §1.4 removed would be back.
    //
    // The floor holder is never in it — the server lowers a hand the instant
    // it grants that hand the floor — but the filter is here anyway, because a
    // snapshot arriving mid-write should not show the speaker asking to speak.
    //
    // Gated on the phase as well as on the column, and that is not belt and
    // braces for its own sake. `micPolicyFor` is the same function the server
    // runs, so a hand can only have been written in a phase where a floor
    // exists — but doc 05's guarantees are not allowed to rest on the server
    // having behaved, and the client already collapses every per-seat fact at
    // night for exactly this reason. A raised hand arriving in a dark phase is
    // a row that should not exist, and the answer to a row that should not
    // exist is to draw nothing.
    // Who the room is still waiting for on the deal. Only during the deal:
    // the column stays true for the rest of the match and a set that outlived
    // the phase would read as a list of people who had done nothing.
    unseenRoleSeats: phase == GamePhase.distributing
        ? {
            for (final player in roster)
              if (!player.sawRole && !player.kicked) player.seat,
          }
        : const {},
    readyToVoteSeats: _readyToVote(data, state, phase),
    raisedHands: micPolicyFor(phase) == MicPolicy.muted
        ? const {}
        : {
            for (final player in roster)
              if (player.handRaisedAt != null &&
                  player.alive &&
                  player.userId != state.activeSpeaker)
                player.seat,
          },
  );
}

/// The room's rules, as the host chose them in the lobby.
///
/// Defaults win wherever the payload is silent: a room created by an older
/// client is playing the same game as this one, not a game with no rules.
MatchSettings settingsFromJson(Object? value) {
  if (value is! Map) return const MatchSettings();
  const defaults = MatchSettings();
  return defaults.copyWith(
    speechSeconds: (value['speechSeconds'] as num?)?.toInt(),
    discussionMode: switch (value['discussionMode']) {
      'free' => DiscussionMode.free,
      'structured' => DiscussionMode.structured,
      _ => null,
    },
    confrontationSeconds: (value['confrontationSeconds'] as num?)?.toInt(),
    discussionSeconds: (value['discussionSeconds'] as num?)?.toInt(),
    openVoting: value['openVoting'] as bool?,
    abstainAllowed: value['abstainAllowed'] as bool?,
    whisperEnabled: value['whisperEnabled'] as bool?,
    traceEnabled: value['traceEnabled'] as bool?,
    confrontationEnabled: value['confrontationEnabled'] as bool?,
    openingRoundEnabled: value['openingRoundEnabled'] as bool?,
    survivorConfrontationEnabled:
        value['survivorConfrontationEnabled'] as bool?,
    bulletsEnabled: value['bulletsEnabled'] as bool?,
    quietNightEnabled: value['quietNightEnabled'] as bool?,
    selfProtectEnabled: value['selfProtectEnabled'] as bool?,
    dayTieRule: switch (value['dayTieRule']) {
      'revote' => DayTieRule.revote,
      'noElimination' => DayTieRule.noElimination,
      _ => null,
    },
  );
}

/// «جاهزين للتصويت» for the discussion that is running now, or nothing. The
/// set is keyed by `phase_number` on the server, so a set left over from an
/// earlier day reads as empty here without anything having to clear it.
Set<int> _readyToVote(
  Map<String, dynamic> data,
  RoomState state,
  GamePhase phase,
) {
  if (phase != GamePhase.discussion) return const {};
  final ready = data['readyToVote'];
  if (ready is! Map || ready['number'] != state.phaseNumber) return const {};
  final seats = ready['seats'];
  if (seats is! List) return const {};
  return {
    for (final seat in seats)
      if (seat is int) seat,
  };
}

MatchOutcome? _outcome(Map<String, dynamic> data, RoomState state) {
  final winner = switch (data['outcome']) {
    'mafia' => Alignment.mafia,
    'town' => Alignment.town,
    _ => null,
  };
  if (winner == null) return null;
  return MatchOutcome(winner: winner, completedAt: state.serverNow);
}

/// The night turn, built for one client out of its own role and the roster.
///
/// The offline engine builds this from a `Match` it holds; online the client
/// holds no match, so the same view is assembled from the two things it does
/// have. The question text is the engine's, word for word, because a different
/// sentence online would be a different game.
ActorTurnView? turnFor({
  required int seat,
  required Role role,
  required List<RoomPlayer> players,
}) {
  final targets = [
    for (final p in players)
      if (p.seat != seat && p.alive) p.seat,
  ]..sort();
  if (targets.isEmpty) return null;

  final questionText = switch (role) {
    Role.mafia => 'Who is tonight\'s target?',
    Role.doctor => 'Who do you protect tonight?',
    Role.detective => 'Whose identity do you investigate?',
    Role.citizen => 'Who do you suspect is Mafia?',
  };

  return ActorTurnView(
    actorSeat: seat,
    actorRole: role,
    questionText: questionText,
    targets: targets,
    // Online a Mafioso does not see the other Mafiosi's running votes: the
    // offline list exists because they are all looking at one phone in turn,
    // and a live feed of it here would be a coordination channel the table
    // game does not have.
    teammateVotes: const [],
  );
}
