import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/engine/models/match_settings.dart';

/// A saved roster — the same people who play together every week.
///
/// ## Why this type exists at all
///
/// Mafia is played with a fixed group. Re-typing eight names before every match
/// is 30–60 seconds of friction at the exact moment nobody has any patience for
/// it: everyone is seated, the phone is out, and the game has not started. This
/// is the app's largest single piece of setup friction and this type is the
/// whole fix.
///
/// ## Order is the contract
///
/// [memberNames] order **is** the seating order, and seating order is the
/// phone-passing order. Preserve it on every read, write and edit. Nothing in
/// this file, the codec, the repository or the UI may sort it — not
/// alphabetically, not by any other key. A group whose order drifts hands the
/// phone to the wrong person, which is a rules failure, not a cosmetic one.
///
/// ## What is deliberately *not* here
///
/// There is no per-player history of any kind. [playCount] counts matches the
/// *group* played, never "Ahmed was Mafia four times". Per-player role history
/// would survive between sessions and become a metagame tell — the one piece of
/// information this feature could leak, and it leaks across whole evenings
/// rather than within one match. Group-level only, permanently.
class PlayerGroup {
  /// Storage id. [unsaved] for a group that has never been written.
  final int id;

  /// Host-chosen label, e.g. "شلة الجمعة".
  final String name;

  /// Members, **in seating order**. Never sorted. See the class doc.
  final List<String> memberNames;

  final DateTime createdAt;

  /// Drives the picker's ordering — most recently played first, because the
  /// group you played last is overwhelmingly the group you are about to play.
  final DateTime lastPlayedAt;

  final int playCount;

  /// The role distribution this group last played with, or null if it has not
  /// started a match yet.
  ///
  /// Kept so a rematch can skip the roles screen entirely. Nullable rather than
  /// defaulted because "this group has never played" and "this group plays the
  /// recommended distribution" are different facts, and only the first one may
  /// suppress the quick-start action.
  final Map<Role, int>? lastRoleCounts;

  /// The match settings this group last played with, or null as above.
  final MatchSettings? lastSettings;

  /// The id of a group that has never been persisted.
  static const int unsaved = 0;

  const PlayerGroup({
    this.id = unsaved,
    required this.name,
    required this.memberNames,
    required this.createdAt,
    required this.lastPlayedAt,
    this.playCount = 0,
    this.lastRoleCounts,
    this.lastSettings,
  });

  /// A brand-new group, stamped at [now].
  factory PlayerGroup.create({
    required String name,
    required List<String> memberNames,
    required DateTime now,
  }) =>
      PlayerGroup(
        name: name,
        memberNames: List.unmodifiable(memberNames),
        createdAt: now,
        lastPlayedAt: now,
      );

  bool get isSaved => id != unsaved;

  int get memberCount => memberNames.length;

  /// Whether this group can start a match without visiting the roles and
  /// settings screens. Both halves are required: a saved roster with no saved
  /// configuration still has to be configured once.
  bool get canQuickStart => lastRoleCounts != null && lastSettings != null;

  /// Whether [names] is this group's roster, in this group's order.
  ///
  /// Order-sensitive on purpose. A roster that is the same people seated
  /// differently is a *change* to the group, not a match for it — which is what
  /// lets the players screen offer to save the new order.
  bool hasRoster(List<String> names) {
    if (names.length != memberNames.length) return false;
    for (var i = 0; i < names.length; i++) {
      if (names[i] != memberNames[i]) return false;
    }
    return true;
  }

  /// Whether [names] is this group's roster as a *set*, ignoring order.
  bool hasSameMembers(List<String> names) =>
      names.length == memberNames.length &&
      names.toSet().containsAll(memberNames);

  PlayerGroup copyWith({
    int? id,
    String? name,
    List<String>? memberNames,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    int? playCount,
    Map<Role, int>? lastRoleCounts,
    MatchSettings? lastSettings,
  }) =>
      PlayerGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        memberNames:
            memberNames == null ? this.memberNames : List.unmodifiable(memberNames),
        createdAt: createdAt ?? this.createdAt,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
        playCount: playCount ?? this.playCount,
        lastRoleCounts: lastRoleCounts ?? this.lastRoleCounts,
        lastSettings: lastSettings ?? this.lastSettings,
      );

  @override
  String toString() => 'PlayerGroup(id=$id, name=$name, '
      'members=${memberNames.length}, playCount=$playCount)';
}
