import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/router.dart';

void main() {
  group('the system back control', () {
    test('mirrors each screen\'s own back control', () {
      expect(systemBackTarget(Routes.mode), Routes.home);
      expect(systemBackTarget(Routes.online), Routes.mode);
      expect(systemBackTarget('/join/K7M2QP'), Routes.online);
      expect(systemBackTarget(Routes.profile), Routes.home);
      expect(systemBackTarget(Routes.defaults), Routes.home);
      expect(systemBackTarget(Routes.history), Routes.home);
      expect(systemBackTarget(Routes.storedAnalytics(7)), Routes.history);
      expect(systemBackTarget(Routes.groups), Routes.home);
      expect(systemBackTarget(Routes.players), Routes.groups);
      expect(systemBackTarget(Routes.players, hasGroups: false), Routes.home);
      expect(systemBackTarget(Routes.roles), Routes.players);
      expect(systemBackTarget(Routes.settings), Routes.roles);
    });

    test('leaves the lobby for the online door without leaving the room', () {
      expect(systemBackTarget(Routes.lobby), Routes.online);
    });

    test('is the platform\'s at Home and inside a match', () {
      expect(systemBackTarget(Routes.home), isNull);
      expect(systemBackTarget(Routes.match), isNull);
    });
  });
}
