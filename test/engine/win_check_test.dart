import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/win_check.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:test/test.dart';

/// T021 — win condition is a PURE rule (WinChecker.checkWin), so we test it in
/// isolation against constructed board states rather than driving a whole match
/// (full-match flow is covered by test/integration/full_match_test.dart).
///
/// Rule (inv. 7): town wins iff living mafia == 0; mafia wins iff living mafia
/// >= living town; otherwise continue (null).
void main() {
  group('Win Check (T021)', () {
    // Build a valid started match, then override player statuses to model a board.
    MatchEngine started(Map<Role, int> roles) {
      final engine = MatchEngine();
      engine.start(
        names: const ['A', 'B', 'C', 'D', 'E'],
        roleCounts: roles,
        settings: const MatchSettings.defaults(),
      );
      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }
      return engine;
    }

    void setStatuses(MatchEngine e, bool Function(Role role) killIf) {
      final players = e.match.players
          .map((p) => killIf(p.role) ? p.copyWith(status: PlayerStatus.dead) : p)
          .toList();
      e.match = e.match.copyWith(players: players);
    }

    test('town wins when all mafia are dead (mafia count == 0)', () {
      final e = started({Role.mafia: 1, Role.doctor: 1, Role.detective: 1, Role.citizen: 2});
      setStatuses(e, (role) => role == Role.mafia); // kill the only mafia
      expect(WinChecker.checkWin(e.match), equals(Alignment.town));
    });

    test('mafia wins when living mafia >= living town', () {
      final e = started({Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 1});
      setStatuses(e, (role) => role != Role.mafia); // kill all non-mafia → 2 mafia, 0 town
      expect(WinChecker.checkWin(e.match), equals(Alignment.mafia));
    });

    test('mafia wins at parity (mafia == town)', () {
      final e = started({Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 1});
      // Kill 2 of the 3 town → 2 mafia vs 1 town? No: kill doctor+detective leaves citizen.
      // Model parity: keep exactly 2 town alive vs 2 mafia is impossible here (only 2 mafia,3 town).
      // Instead kill one town → 2 mafia vs 2 town = parity → mafia wins.
      var killed = 0;
      final players = e.match.players.map((p) {
        if (p.role != Role.mafia && killed < 1) {
          killed++;
          return p.copyWith(status: PlayerStatus.dead);
        }
        return p;
      }).toList();
      e.match = e.match.copyWith(players: players);
      // now 2 mafia, 2 town alive → parity → mafia
      expect(WinChecker.checkWin(e.match), equals(Alignment.mafia));
    });

    test('continue when 0 < mafia < town alive', () {
      final e = started({Role.mafia: 1, Role.doctor: 1, Role.detective: 1, Role.citizen: 2});
      // all alive: 1 mafia, 4 town → continue
      expect(WinChecker.checkWin(e.match), isNull);
    });
  });
}
