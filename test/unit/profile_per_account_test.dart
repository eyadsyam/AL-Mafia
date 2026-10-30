import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const alice = PlayerProfile(name: 'Alice', gender: PlayerGender.female);
  const bob = PlayerProfile(name: 'Bob', gender: PlayerGender.male);
  const guest = PlayerProfile(name: 'Guest', gender: PlayerGender.male);

  test(
    'switching saves and restores each account and guest separately',
    () async {
      final store = ProfileStore();
      await ProfileStore.switchAccount(null);
      await store.save(guest);
      await ProfileStore.switchAccount('alice');
      expect(await store.load(), isNull);
      await store.save(alice);
      await ProfileStore.switchAccount('bob');
      expect(await store.load(), isNull);
      await store.save(bob);
      await ProfileStore.switchAccount('alice');
      expect((await store.load())?.name, 'Alice');
      await ProfileStore.switchAccount(null);
      expect((await store.load())?.name, 'Guest');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('${ProfileStore.profileKey}.bob'), isNotNull);
    },
  );

  test('legacy working keys migrate once to current account', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ProfileStore.profileKey,
      '{"name":"Alice","gender":"female"}',
    );
    await prefs.setString(
      FirstRunProgress.key,
      '{"chapter":"name","name":"Alice"}',
    );
    await prefs.setBool(WelcomeGreeting.key, true);
    await ProfileStore.switchAccount('alice');
    expect((await ProfileStore().load())?.name, 'Alice');
    await ProfileStore.switchAccount('bob');
    expect(await ProfileStore().load(), isNull);
    expect(await FirstRunProgress.load(), isNull);
    expect(await WelcomeGreeting.pending(), isFalse);
    await ProfileStore.switchAccount('alice');
    expect((await ProfileStore().load())?.name, 'Alice');
    expect((await FirstRunProgress.load())?.name, 'Alice');
    expect(await WelcomeGreeting.pending(), isTrue);
    await WelcomeGreeting.consume();
    await FirstRunProgress.clear();
    await ProfileStore.switchAccount('bob');
    await ProfileStore.switchAccount('alice');
    expect(await WelcomeGreeting.pending(), isFalse);
    expect(await FirstRunProgress.load(), isNull);
  });
}
