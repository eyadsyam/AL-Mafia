import 'package:mafia_master/engine/models/enums.dart' show Role;

import 'match_codec.dart';
import 'player_group.dart';

/// Converts a [PlayerGroup] to and from plain JSON-safe maps.
///
/// Separate from the storage layer for the same reason [MatchCodec] is: the
/// round trip is the part with a correctness property worth testing directly,
/// and the property here is **order**. `memberNames` is the seating order, so a
/// codec that reordered it — via a `Set`, a `Map` key iteration, or a helpful
/// sort — would hand the phone to the wrong player on every rematch. The list
/// goes out and comes back as a list, index for index.
///
/// Roles are keyed by [Role.name], never by index, so reordering the `Role`
/// declaration cannot silently reinterpret a stored distribution — the same
/// rule [MatchCodec] follows, for the same reason.
class PlayerGroupCodec {
  const PlayerGroupCodec._();

  static Map<String, dynamic> encode(PlayerGroup group) => {
        'name': group.name,
        'memberNames': [...group.memberNames],
        'createdAt': group.createdAt.toIso8601String(),
        'lastPlayedAt': group.lastPlayedAt.toIso8601String(),
        'playCount': group.playCount,
        'lastRoleCounts': group.lastRoleCounts == null
            ? null
            : {
                for (final entry in group.lastRoleCounts!.entries)
                  entry.key.name: entry.value,
              },
        'lastSettings': group.lastSettings == null
            ? null
            : MatchCodec.encodeSettings(group.lastSettings!),
      };

  /// [id] comes from the storage row rather than the payload, so a group cannot
  /// carry a stale id across a copy.
  static PlayerGroup decode(Map<String, dynamic> json, {required int id}) {
    final counts = json['lastRoleCounts'] as Map<String, dynamic>?;
    final settings = json['lastSettings'] as Map<String, dynamic>?;

    return PlayerGroup(
      id: id,
      name: json['name'] as String,
      memberNames: List.unmodifiable(
        [for (final n in (json['memberNames'] as List)) n as String],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
      playCount: json['playCount'] as int? ?? 0,
      lastRoleCounts: counts == null
          ? null
          : {
              for (final entry in counts.entries)
                _roleByName(entry.key): entry.value as int,
            },
      lastSettings:
          settings == null ? null : MatchCodec.decodeSettings(settings),
    );
  }

  static Role _roleByName(String name) => Role.values.firstWhere(
        (r) => r.name == name,
        orElse: () => throw FormatException('Unknown role "$name"'),
      );
}
