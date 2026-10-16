import '../../../engine/balance_guard.dart';
import '../../../engine/models/enums.dart';
import '../../../engine/models/match_settings.dart';
import '../setup/optional_roles.dart';

/// What an online room deals at [players] seats: the recommended split
/// (ruling RL11) with the sold roles the host switched on, each only where
/// the table is big enough — the same rule the offline roles screen applies
/// (`OptionalRole.usable`), so the server's `start_match` never refuses a
/// split this lobby offers (ruling RL12, D14).
typedef LobbyDeal = ({
  Map<Role, int> counts,
  MatchSettings settings,
  List<OptionalRole> skipped,
});

LobbyDeal lobbyDeal(int players, MatchSettings settings) {
  final base = BalanceGuard.recommended(players);
  final wanted = {
    if (settings.silencerEnabled) OptionalRole.silencer,
    if (settings.elderEnabled) OptionalRole.elder,
    if (settings.sniperEnabled) OptionalRole.sniper,
  };
  final usable = OptionalRole.usable(
    wanted,
    players: players,
    mafia: base[Role.mafia] ?? 0,
    citizens: base[Role.citizen] ?? 0,
  );
  return (
    counts: OptionalRole.apply(base, usable),
    settings: OptionalRole.flags(settings, usable),
    skipped: [
      for (final r in OptionalRole.values)
        if (wanted.contains(r) && !usable.contains(r)) r,
    ],
  );
}
