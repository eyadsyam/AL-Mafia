import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/player.dart' show PlayerGender;
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/identity_sync.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Directory extends DirectoryApi {
  _Directory(super.ref, this.entry);
  final DirectoryMe entry;
  int calls = 0;
  @override
  Future<DirectoryMe> me() async {
    calls++;
    return entry;
  }
}

const _account = AccountProfile(signedIn: true, userId: 'u-1', google: true);

Future<ProviderContainer> _container({
  required AccountProfile account,
  required DirectoryMe entry,
}) async {
  final c = ProviderContainer(
    overrides: [
      accountsAvailableProvider.overrideWithValue(true),
      accountProfileProvider.overrideWith((ref) => Stream.value(account)),
      directoryApiProvider.overrideWith((ref) => _Directory(ref, entry)),
    ],
  );
  addTearDown(c.dispose);
  await c.read(accountProfileProvider.future);
  await c.read(playerProfileProvider.future);
  return c;
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: '{"name":"Phone name","gender":"male"}',
    }),
  );

  test('a device signed in to an account takes the account name', () async {
    final c = await _container(
      account: _account,
      entry: const DirectoryMe(
        handle: 'mona',
        name: 'Mona',
        gender: PlayerGender.female,
      ),
    );
    await c.read(identitySyncProvider).ensureSynced();
    final now = (await ProfileStore().load())!;
    expect(now.name, 'Mona');
    expect(now.gender, PlayerGender.female);
  });

  test('once per account per launch', () async {
    final c = await _container(
      account: _account,
      entry: const DirectoryMe(handle: 'a', name: 'A'),
    );
    final sync = c.read(identitySyncProvider);
    await sync.ensureSynced();
    await sync.ensureSynced();
    expect(sync.fetches, 1);
  });

  test('a guest and an account with no entry keep the device name', () async {
    final guest = await _container(
      account: AccountProfile.guest,
      entry: const DirectoryMe(name: 'Server'),
    );
    expect(await guest.read(identitySyncProvider).ensureSynced(), isNull);
    expect((await ProfileStore().load())!.name, 'Phone name');

    final fresh = await _container(
      account: _account,
      entry: const DirectoryMe(),
    );
    await fresh.read(identitySyncProvider).ensureSynced();
    expect((await ProfileStore().load())!.name, 'Phone name');
  });
}
