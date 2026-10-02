import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('profile survives a new store without storing match secrets', () async {
    await ProfileStore().save(
      const PlayerProfile(name: 'سيد', gender: PlayerGender.male),
    );
    final restored = await ProfileStore().load();
    expect(restored?.name, 'سيد');
    expect(restored?.gender, PlayerGender.male);
    expect(restored?.toJson().keys.toSet(), {'name', 'gender'});
  });
  test('incomplete profile is rejected', () async {
    expect(
      () => ProfileStore().save(
        const PlayerProfile(name: '', gender: PlayerGender.unspecified),
      ),
      throwsArgumentError,
    );
  });
  test('corrupt persisted profile asks for setup again', () async {
    SharedPreferences.setMockInitialValues({ProfileStore.profileKey: '{bad'});
    expect(await ProfileStore().load(), isNull);
  });
  test('introduction completion is persistent on web and native', () async {
    expect(await ProfileStore().introSeen, isFalse);
    await ProfileStore().markIntroSeen();
    expect(await ProfileStore().introSeen, isTrue);
  });
}
