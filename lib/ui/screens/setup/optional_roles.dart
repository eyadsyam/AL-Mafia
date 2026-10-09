import '../../../engine/models/enums.dart' show Role;
import '../../../engine/models/match_settings.dart';

/// The three roles that are bought, not given: the setup screens offer them
/// only to a wallet that owns their code, and a table that turns one on swaps
/// one seat of the base split for it. No rule lives here — the engine's own
/// checks (`MatchEngine.start`, `BalanceGuard`) still decide; this only keeps
/// the screens from building a split those checks refuse.
enum OptionalRole {
  silencer(Role.silencer, 'role_silencer', 5),
  elder(Role.elder, 'role_elder', 6),
  sniper(Role.sniper, 'role_sniper', 7);

  final Role role;

  /// The wallet's code for owning this role.
  final String code;

  /// The smallest table the engine accepts it at.
  final int minPlayers;

  const OptionalRole(this.role, this.code, this.minPlayers);

  /// The role whose wallet code is [code], or null for any other code.
  static OptionalRole? byCode(String code) {
    for (final r in OptionalRole.values) {
      if (r.code == code) return r;
    }
    return null;
  }

  /// Why [this] cannot be switched on for a table of [players] with [mafia]
  /// Mafia-side seats and [citizens] citizens in the base split, or null.
  /// The codes are `BalanceGuard`'s own.
  String? blockedBy({
    required int players,
    required int mafia,
    required int citizens,
  }) => switch (this) {
    OptionalRole.silencer => mafia < 2 ? 'silencer_needs_two_mafia' : null,
    OptionalRole.elder =>
      players < minPlayers
          ? 'elder_min_players'
          : citizens < 1
          ? 'no_citizen_left'
          : null,
    OptionalRole.sniper =>
      players < minPlayers
          ? 'sniper_min_players'
          : citizens < 1
          ? 'no_citizen_left'
          : null,
  };

  /// [base] (Mafia counted as one number, silencer included) with [on]
  /// switched on: the silencer takes a Mafia seat, the others a citizen's.
  static Map<Role, int> apply(Map<Role, int> base, Set<OptionalRole> on) {
    final out = Map<Role, int>.of(base);
    for (final r in on) {
      out[r.role] = 1;
      if (r == OptionalRole.silencer) {
        out[Role.mafia] = (out[Role.mafia] ?? 0) - 1;
      } else {
        out[Role.citizen] = (out[Role.citizen] ?? 0) - 1;
      }
    }
    out.removeWhere((_, v) => v == 0);
    return out;
  }

  /// The settings flags for [on], on top of [settings].
  static MatchSettings flags(MatchSettings settings, Set<OptionalRole> on) =>
      settings.copyWith(
        silencerEnabled: on.contains(OptionalRole.silencer),
        elderEnabled: on.contains(OptionalRole.elder),
        sniperEnabled: on.contains(OptionalRole.sniper),
      );

  /// Those of [wanted] that can actually be switched on for this table.
  static Set<OptionalRole> usable(
    Set<OptionalRole> wanted, {
    required int players,
    required int mafia,
    required int citizens,
  }) {
    final out = <OptionalRole>{};
    var left = citizens;
    for (final r in OptionalRole.values) {
      if (!wanted.contains(r)) continue;
      final blocked = r.blockedBy(players: players, mafia: mafia, citizens: left);
      if (blocked != null) continue;
      if (r != OptionalRole.silencer) left--;
      out.add(r);
    }
    return out;
  }
}
