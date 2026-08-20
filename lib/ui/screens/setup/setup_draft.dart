import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player_group.dart';
import '../../../engine/models/enums.dart' show Role;
import '../../../engine/models/match_settings.dart';

/// The match being configured, accumulated across the three setup screens.
///
/// Held in a provider rather than passed through route arguments so that going
/// back a step keeps what was already entered — re-typing seven names because
/// you wanted to change the Mafia count is exactly the friction the two-minute
/// setup budget (US4) cannot afford.
class SetupDraft {
  final List<String> names;
  final Map<Role, int>? roleCounts;
  final MatchSettings settings;

  /// The saved roster this match was started from, or null for a one-off.
  ///
  /// Outlives the setup screens on purpose: it is still needed when the match
  /// *ends*, to ask whether tonight's guests should join the group and whether
  /// a changed seating order should be kept. Those questions can only be asked
  /// once the answer is known, and it is not known until the match is over.
  final PlayerGroup? group;

  const SetupDraft({
    this.names = const [],
    this.roleCounts,
    this.settings = const MatchSettings.defaults(),
    this.group,
  });

  SetupDraft copyWith({
    List<String>? names,
    Map<Role, int>? roleCounts,
    MatchSettings? settings,
    PlayerGroup? group,
    bool clearGroup = false,
  }) => SetupDraft(
    names: names ?? this.names,
    roleCounts: roleCounts ?? this.roleCounts,
    settings: settings ?? this.settings,
    group: clearGroup ? null : (group ?? this.group),
  );

  /// Members of [group] who played tonight, in the order they were seated.
  ///
  /// Empty when there is no group. Used to work out whether the seating order
  /// changed, without letting tonight's absences look like a reorder.
  List<String> get playedMembers {
    final members = group?.memberNames;
    if (members == null) return const [];
    return [for (final name in names) if (members.contains(name)) name];
  }

  /// Players who are not in [group] — people who turned up tonight only.
  List<String> get guests {
    final members = group?.memberNames;
    if (members == null) return const [];
    return [for (final name in names) if (!members.contains(name)) name];
  }

  /// Whether the members who played sat in a different order from the saved
  /// one.
  ///
  /// Compared against the saved roster *filtered to who was here*, so an absent
  /// player does not read as a reorder of everyone after them. Order matters
  /// because it is the phone-passing order, which is why this is worth asking
  /// about at all.
  bool get seatingOrderChanged {
    final members = group?.memberNames;
    if (members == null) return false;
    final played = playedMembers;
    final expected = [
      for (final name in members) if (played.contains(name)) name,
    ];
    if (expected.length != played.length) return false;
    for (var i = 0; i < played.length; i++) {
      if (played[i] != expected[i]) return true;
    }
    return false;
  }
}

class SetupDraftNotifier extends Notifier<SetupDraft> {
  @override
  SetupDraft build() => const SetupDraft();

  void setNames(List<String> names) =>
      state = state.copyWith(names: List.unmodifiable(names));

  void setRoleCounts(Map<Role, int> counts) =>
      state = state.copyWith(roleCounts: Map.unmodifiable(counts));

  void setSettings(MatchSettings settings) =>
      state = state.copyWith(settings: settings);

  /// Attaches the saved roster this match is being played from.
  void setGroup(PlayerGroup? group) => group == null
      ? state = state.copyWith(clearGroup: true)
      : state = state.copyWith(group: group);

  /// Clears names, roles and the group but keeps settings — those are the
  /// defaults the host just chose, and the next match should inherit them
  /// (FR-005). The group is *not* inherited: the next match starts from the
  /// picker, which is where the host says who is playing this time.
  void resetForNewMatch() => state = SetupDraft(settings: state.settings);
}

final setupDraftProvider = NotifierProvider<SetupDraftNotifier, SetupDraft>(
  SetupDraftNotifier.new,
);
