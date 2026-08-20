import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';

/// Converts a [Match] to and from plain JSON-safe maps.
///
/// ## Why this is a separate, storage-free file
///
/// Round-trip fidelity is a contract invariant (match-repository inv. 5): a
/// reloaded match must be *equal* to the one that was written, seed and event
/// order included, or a resumed night would resolve differently from the one
/// the players actually played. Keeping the conversion here — with no Isar and
/// no `dart:io` — means that invariant is testable directly, and the storage
/// backends stay thin enough to be obviously correct.
///
/// Enums are encoded by **name**, never by index, so reordering an enum
/// declaration cannot silently reinterpret stored matches.
class MatchCodec {
  const MatchCodec._();

  // ---------------------------------------------------------------------------
  // Match
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> encode(Match match) => {
        'id': match.id,
        'createdAt': match.createdAt.toIso8601String(),
        'seed': match.seed,
        'phase': match.phase.name,
        'dayNumber': match.dayNumber,
        'currentActorSeat': match.currentActorSeat,
        'settings': _encodeSettings(match.settings),
        'players': [for (final p in match.players) _encodePlayer(p)],
        'eventLog': [for (final e in match.eventLog) _encodeEvent(e)],
        'outcome': match.outcome == null
            ? null
            : {
                'winner': match.outcome!.winner.name,
                'completedAt': match.outcome!.completedAt.toIso8601String(),
              },
      };

  static Match decode(Map<String, dynamic> json) {
    final outcome = json['outcome'] as Map<String, dynamic>?;
    return Match(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      seed: json['seed'] as int,
      phase: _enumByName(GamePhase.values, json['phase'] as String),
      dayNumber: json['dayNumber'] as int,
      currentActorSeat: json['currentActorSeat'] as int?,
      settings: _decodeSettings(json['settings'] as Map<String, dynamic>),
      players: [
        for (final p in (json['players'] as List))
          _decodePlayer(p as Map<String, dynamic>),
      ],
      eventLog: [
        for (final e in (json['eventLog'] as List))
          _decodeEvent(e as Map<String, dynamic>),
      ],
      outcome: outcome == null
          ? null
          : MatchOutcome(
              winner: _enumByName(Alignment.values, outcome['winner'] as String),
              completedAt: DateTime.parse(outcome['completedAt'] as String),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> encodeSettings(MatchSettings s) =>
      _encodeSettings(s);

  static MatchSettings decodeSettings(Map<String, dynamic> json) =>
      _decodeSettings(json);

  static Map<String, dynamic> _encodeSettings(MatchSettings s) => {
        'speechSeconds': s.speechSeconds,
        'discussionMode': s.discussionMode.name,
        'dayTieRule': s.dayTieRule.name,
        'narrationEnabled': s.narrationEnabled,
        'abstainAllowed': s.abstainAllowed,
        'identityHoldSeconds': s.identityHoldSeconds,
        'muteAllAudio': s.muteAllAudio,
        'scoreEnabled': s.scoreEnabled,
      };

  static MatchSettings _decodeSettings(Map<String, dynamic> json) =>
      MatchSettings(
        speechSeconds: json['speechSeconds'] as int,
        discussionMode:
            _enumByName(DiscussionMode.values, json['discussionMode'] as String),
        dayTieRule: _enumByName(DayTieRule.values, json['dayTieRule'] as String),
        narrationEnabled: json['narrationEnabled'] as bool,
        abstainAllowed: json['abstainAllowed'] as bool,
        // Tolerated as missing: a match saved before this setting existed must
        // still resume. Everything else here is required, because a match with
        // no speech time or no tie rule is not a match that can be played on.
        identityHoldSeconds: json['identityHoldSeconds'] as int? ??
            const MatchSettings.defaults().identityHoldSeconds,
        muteAllAudio: json['muteAllAudio'] as bool? ??
            const MatchSettings.defaults().muteAllAudio,
        scoreEnabled: json['scoreEnabled'] as bool? ??
            const MatchSettings.defaults().scoreEnabled,
      );

  // ---------------------------------------------------------------------------
  // Player
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _encodePlayer(Player p) => {
        'seat': p.seat,
        'name': p.name,
        'role': p.role.name,
        'status': p.status.name,
        'eliminatedOn': _encodePhaseRef(p.eliminatedOn),
      };

  static Player _decodePlayer(Map<String, dynamic> json) => Player(
        seat: json['seat'] as int,
        name: json['name'] as String,
        role: _enumByName(Role.values, json['role'] as String),
        status: _enumByName(PlayerStatus.values, json['status'] as String),
        eliminatedOn:
            _decodePhaseRef(json['eliminatedOn'] as Map<String, dynamic>?),
      );

  static Map<String, dynamic>? _encodePhaseRef(PhaseRef? ref) => ref == null
      ? null
      : {'phase': ref.phase.name, 'number': ref.number};

  static PhaseRef? _decodePhaseRef(Map<String, dynamic>? json) => json == null
      ? null
      : PhaseRef(
          phase: _enumByName(GamePhase.values, json['phase'] as String),
          number: json['number'] as int,
        );

  // ---------------------------------------------------------------------------
  // Events
  //
  // Every variant of the sealed hierarchy is handled explicitly. The switch is
  // exhaustive, so adding an event without teaching the codec about it is a
  // compile error rather than a silently dropped row.
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _encodeEvent(TimelineEvent e) {
    final base = {
      'at': e.at.toIso8601String(),
      'phase': e.phaseRef.phase.name,
      'number': e.phaseRef.number,
    };
    return switch (e) {
      RoleAssigned() => {...base, 'k': 'roleAssigned', 'seat': e.seat, 'role': e.role.name},
      NightOpened() => {...base, 'k': 'nightOpened'},
      MafiaVoteCast() => {...base, 'k': 'mafiaVote', 'actor': e.actorSeat, 'target': e.targetSeat},
      ProtectCast() => {...base, 'k': 'protect', 'actor': e.actorSeat, 'target': e.targetSeat},
      InvestigateCast() => {...base, 'k': 'investigate', 'actor': e.actorSeat, 'target': e.targetSeat},
      SuspectCast() => {...base, 'k': 'suspect', 'actor': e.actorSeat, 'target': e.targetSeat, 'reason': e.reason},
      NightResolved() => {...base, 'k': 'nightResolved', 'victim': e.victimSeat, 'saved': e.savedSeat},
      MorningAnnounced() => {...base, 'k': 'morning'},
      DiscussionRound() => {...base, 'k': 'discussionRound'},
      QuestionAsked() => {...base, 'k': 'question', 'from': e.fromSeat, 'to': e.toSeat},
      VoteCast() => {...base, 'k': 'vote', 'voter': e.voterSeat, 'target': e.targetSeat, 'round': e.round},
      DayRevoteCalled() => {...base, 'k': 'revote', 'tied': e.tiedSeats},
      DayResolved() => {
          ...base,
          'k': 'dayResolved',
          'eliminated': e.eliminatedSeat,
          // Map keys must be strings to survive a JSON round trip.
          'tally': {for (final entry in e.tally.entries) '${entry.key}': entry.value},
        },
      PlayerRemoved() => {...base, 'k': 'playerRemoved', 'seat': e.seat},
      WinReached() => {...base, 'k': 'winReached', 'alignment': e.alignment.name},
    };
  }

  static TimelineEvent _decodeEvent(Map<String, dynamic> json) {
    final at = DateTime.parse(json['at'] as String);
    final ref = PhaseRef(
      phase: _enumByName(GamePhase.values, json['phase'] as String),
      number: json['number'] as int,
    );

    switch (json['k'] as String) {
      case 'roleAssigned':
        return RoleAssigned(
          at: at,
          phaseRef: ref,
          seat: json['seat'] as int,
          role: _enumByName(Role.values, json['role'] as String),
        );
      case 'nightOpened':
        return NightOpened(at: at, phaseRef: ref);
      case 'mafiaVote':
        return MafiaVoteCast(
          at: at,
          phaseRef: ref,
          actorSeat: json['actor'] as int,
          targetSeat: json['target'] as int,
        );
      case 'protect':
        return ProtectCast(
          at: at,
          phaseRef: ref,
          actorSeat: json['actor'] as int,
          targetSeat: json['target'] as int,
        );
      case 'investigate':
        return InvestigateCast(
          at: at,
          phaseRef: ref,
          actorSeat: json['actor'] as int,
          targetSeat: json['target'] as int,
        );
      case 'suspect':
        return SuspectCast(
          at: at,
          phaseRef: ref,
          actorSeat: json['actor'] as int,
          targetSeat: json['target'] as int,
          reason: json['reason'] as String?,
        );
      case 'nightResolved':
        return NightResolved(
          at: at,
          phaseRef: ref,
          victimSeat: json['victim'] as int?,
          savedSeat: json['saved'] as int?,
        );
      case 'morning':
        return MorningAnnounced(at: at, phaseRef: ref);
      case 'discussionRound':
        return DiscussionRound(at: at, phaseRef: ref);
      case 'question':
        return QuestionAsked(
          at: at,
          phaseRef: ref,
          fromSeat: json['from'] as int,
          toSeat: json['to'] as int,
        );
      case 'vote':
        return VoteCast(
          at: at,
          phaseRef: ref,
          voterSeat: json['voter'] as int,
          targetSeat: json['target'] as int?,
          round: json['round'] as int? ?? 1,
        );
      case 'revote':
        return DayRevoteCalled(
          at: at,
          phaseRef: ref,
          tiedSeats: [for (final s in (json['tied'] as List)) s as int],
        );
      case 'dayResolved':
        return DayResolved(
          at: at,
          phaseRef: ref,
          eliminatedSeat: json['eliminated'] as int,
          tally: {
            for (final entry in (json['tally'] as Map).entries)
              int.parse(entry.key as String): entry.value as int,
          },
        );
      case 'playerRemoved':
        return PlayerRemoved(at: at, phaseRef: ref, seat: json['seat'] as int);
      case 'winReached':
        return WinReached(
          at: at,
          phaseRef: ref,
          alignment: _enumByName(Alignment.values, json['alignment'] as String),
        );
      default:
        throw FormatException('Unknown timeline event kind: ${json['k']}');
    }
  }

  static T _enumByName<T extends Enum>(List<T> values, String name) =>
      values.firstWhere(
        (v) => v.name == name,
        orElse: () => throw FormatException('Unknown enum value "$name"'),
      );
}
