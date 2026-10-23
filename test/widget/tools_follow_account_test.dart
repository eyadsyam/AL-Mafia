import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/account/delete_account_sheet.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

/// The tool shelf belongs to the account that bought it. Read once and kept,
/// it went on showing a deleted account's charges to the guest who came next.
void main() {
  test('a deleted account leaves no tool charges on the shelf', () async {
    SharedPreferences.setMockInitialValues({});
    var charges = 5;
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(),
      players: roster(5),
    );
    backend.responders['economy'] = (_) => {
      'tools': [
        {
          'code': 'double_vote',
          'tier': 'medium',
          'packs': {'1': 400},
          'charges': charges,
        },
      ],
      'balance': 0,
    };
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(tableToolsProvider, (_, _) {});
    addTearDown(sub.close);

    expect(
      (await container.read(tableToolsProvider.future)).owned(),
      hasLength(1),
    );

    // The server forgets the account; the next identity owns nothing.
    backend.responders['delete_account'] = (_) {
      charges = 0;
      return const {'ok': true};
    };
    await container.read(deleteAccountActionProvider)();

    expect((await container.read(tableToolsProvider.future)).owned(), isEmpty);
  });
}
