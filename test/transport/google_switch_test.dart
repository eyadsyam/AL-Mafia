import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AccountAuth {
  _Auth({Future<bool> Function()? stake})
    : super(
        () => throw UnimplementedError(),
        ensureSession: () async {},
        guestStake: stake,
      );

  var signIns = 0;

  @override
  Future<void> googleSignIn() async => signIns++;
}

/// A guest whose Google account turns out to be another player's. Switching
/// leaves the guest identity — and its coins and items — behind for good, so
/// only a guest with nothing there is switched without being asked.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a guest with nothing to lose is switched straight away', () async {
    final auth = _Auth(stake: () async => false);
    expect(await auth.switchToTakenGoogle(), isTrue);
    expect(auth.signIns, 1);
  });

  test('a guest with coins or items chooses first', () async {
    final auth = _Auth(stake: () async => true);
    expect(await auth.switchToTakenGoogle(), isFalse);
    expect(auth.signIns, 0);
  });

  test('a stake nobody could read counts as one', () async {
    final auth = _Auth(stake: () async => throw StateError('offline'));
    expect(await auth.switchToTakenGoogle(), isFalse);
    expect(auth.signIns, 0);
  });
}
