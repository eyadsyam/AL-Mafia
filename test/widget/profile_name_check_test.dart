import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/social/directory.dart' show nameRefusedProvider;
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

void main() {
  Future<String?> saveName(WidgetTester tester, {required bool refused}) async {
    SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: jsonEncode({'name': 'ليلى', 'gender': 'female'}),
    });
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nameRefusedProvider.overrideWithValue(
            (name, gender) async => refused,
          ),
        ],
        child: localizedApp(const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ProfileScreen.nameKey), 'اسم جديد');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final raw = (await SharedPreferences.getInstance()).getString(
      ProfileStore.profileKey,
    );
    return (jsonDecode(raw!) as Map)['name'] as String?;
  }

  testWidgets('a name the server refuses is not saved, and says so', (
    tester,
  ) async {
    expect(await saveName(tester, refused: true), 'ليلى');
    expect(find.text(arStrings.onlineNameNotAllowed), findsOneWidget);
  });

  testWidgets('an allowed name, or no answer, is saved as before', (
    tester,
  ) async {
    expect(await saveName(tester, refused: false), 'اسم جديد');
    expect(find.text(arStrings.onlineNameNotAllowed), findsNothing);
  });
}
