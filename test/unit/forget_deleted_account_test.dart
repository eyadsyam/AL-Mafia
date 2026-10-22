import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/locale_controller.dart'
    show localePreferenceKey;
import 'package:mafia_master/data/motion_preference.dart'
    show reduceMotionPreferenceKey;
import 'package:mafia_master/ui/account/delete_account_sheet.dart';
import 'package:mafia_master/ui/economy/all_access.dart'
    show AllAccessController;
import 'package:mafia_master/ui/economy/my_cosmetics.dart'
    show MyCosmeticsController, OwnedRolesController;
import 'package:mafia_master/ui/social/push_prompt.dart' show PushPrompt;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the forgotten names are the caches\' own keys', () {
    expect(
      deletedAccountKeys,
      containsAll(<String>[
        OwnedRolesController.storageKey,
        MyCosmeticsController.storageKey,
        AllAccessController.storageKey,
        PushPrompt.onKey,
      ]),
    );
  });

  test(
    'a deleted account leaves no grant behind; the player keeps theirs',
    () async {
      SharedPreferences.setMockInitialValues({
        for (final key in deletedAccountKeys) key: 'x',
        localePreferenceKey: 'ar',
        reduceMotionPreferenceKey: true,
      });

      await forgetDeletedAccount();

      final prefs = await SharedPreferences.getInstance();
      for (final key in deletedAccountKeys) {
        expect(prefs.containsKey(key), isFalse, reason: key);
      }
      expect(prefs.getString(localePreferenceKey), 'ar');
      expect(prefs.getBool(reduceMotionPreferenceKey), isTrue);
    },
  );
}
