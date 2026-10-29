import '../../../engine/balance_guard.dart';
import '../../../engine/models/enums.dart';
import '../../../engine/models/match_settings.dart';
import '../setup/optional_roles.dart';

/// What an online room deals at [players] seats: the recommended split
/// (ruling RL11) with the sold roles the host switched on, each only where
/// the table is big enough — the same rule the offline roles screen applies
/// (`OptionalRole.usable`), so the server's `start_match` never refuses a
/// split this lobby offers (ruling RL12, D14).
///
/// [reset] is true when the host's own split ([LobbyBase]) no longer fits the
/// table (someone left) and the recommended one was dealt instead.
typedef LobbyDeal = ({
  Map<Role, int> counts,
  MatchSettings settings,
  List<OptionalRole> skipped,
  bool reset,
});

/// The host's own split (owner, 2026-10-29: «لازم في توزيع الادوار يكون عندي
/// صلاحية لكل حاجة كا هوست»): how many Mafia (a silencer counted among them),
/// Detectives and Doctors. Citizens are whatever seats are left, so a player
/// joining or leaving changes the citizens and nothing else.
typedef LobbyBase = ({int mafia, int detective, int doctor});

LobbyDeal lobbyDeal(int players, MatchSettings settings, {LobbyBase? base}) {
  var start = BalanceGuard.recommended(players);
  var reset = false;
  if (base != null) {
    final custom = {
      Role.mafia: base.mafia,
      Role.detective: base.detective,
      Role.doctor: base.doctor,
      Role.citizen: players - base.mafia - base.detective - base.doctor,
    };
    if ((custom[Role.citizen] ?? 0) >= 1 &&
        BalanceGuard.evaluate(playerCount: players, roleCounts: custom).valid) {
      start = {
        for (final e in custom.entries)
          if (e.value > 0) e.key: e.value,
      };
    } else {
      reset = true;
    }
  }
  final wanted = {
    if (settings.silencerEnabled) OptionalRole.silencer,
    if (settings.elderEnabled) OptionalRole.elder,
    if (settings.sniperEnabled) OptionalRole.sniper,
  };
  final usable = OptionalRole.usable(
    wanted,
    players: players,
    mafia: start[Role.mafia] ?? 0,
    citizens: start[Role.citizen] ?? 0,
  );
  return (
    counts: OptionalRole.apply(start, usable),
    settings: OptionalRole.flags(settings, usable),
    skipped: [
      for (final r in OptionalRole.values)
        if (wanted.contains(r) && !usable.contains(r)) r,
    ],
    reset: reset,
  );
}
