import 'dart:math' as math;

import '../../../engine/balance_guard.dart';
import '../../../engine/models/enums.dart';
import '../../../engine/models/match_settings.dart';
import '../../../transport/game_snapshot.dart' show PublicRoom;
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

/// The table a deal is planned for. A host is alone when the room opens, so
/// until a match could start the plan is for the room they opened ([capacity]):
/// otherwise every split they chose would "not fit" and fall back the moment
/// they made it. From five seats on, the deal is for who is really here.
int lobbyDealSeats(int players, {int capacity = 0}) =>
    players >= PublicRoom.defaultMinPlayers
    ? players
    : math.max(capacity, PublicRoom.defaultMinPlayers);

LobbyDeal lobbyDeal(
  int players,
  MatchSettings settings, {
  LobbyBase? base,
  int capacity = 0,
}) {
  final seats = lobbyDealSeats(players, capacity: capacity);
  var start = BalanceGuard.recommended(seats);
  var reset = false;
  if (base != null) {
    final custom = {
      Role.mafia: base.mafia,
      Role.detective: base.detective,
      Role.doctor: base.doctor,
      Role.citizen: seats - base.mafia - base.detective - base.doctor,
    };
    if ((custom[Role.citizen] ?? 0) >= 1 &&
        BalanceGuard.evaluate(playerCount: seats, roleCounts: custom).valid) {
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
  // The silencer works beside another Mafioso. A host who switched it on asked
  // for that, so a one-Mafioso split takes a second from the citizens, when the
  // table can spare one.
  if (wanted.contains(OptionalRole.silencer) &&
      (start[Role.mafia] ?? 0) < 2 &&
      (start[Role.citizen] ?? 0) >= 2 &&
      2 * 2 < seats) {
    start = {...start, Role.mafia: 2, Role.citizen: start[Role.citizen]! - 1};
  }
  final usable = OptionalRole.usable(
    wanted,
    players: seats,
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
