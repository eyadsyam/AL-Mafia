import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/safety_center.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('reporting has no privacy policy or data deletion controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(child: localizedApp(const SafetyCenter())),
    );
    expect(find.text(arStrings.safetyTools), findsOneWidget);
    expect(find.text(arStrings.safetyPolicy), findsNothing);
    expect(find.text(arStrings.safetyDelete), findsNothing);
  });
  testWidgets(
    'community rules require an explicit acceptance and are remembered',
    (tester) async {
      bool? accepted;
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  accepted = await acceptCommunityRules(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(accepted, isNull);
      await tester.tap(find.text(arStrings.safetyAgree));
      await tester.pumpAndSettle();
      expect(accepted, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(communityRulesKey),
        isTrue,
      );
    },
  );

  testWidgets(
    'deletion only submits after confirmation and shows its receipt',
    (tester) async {
      final backend = FakeBackend(
        roomId: 'r',
        state: roomState(),
        players: roster(2),
      )..responses['player_safety'] = {'receipt': 'test-receipt'};
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          ],
          child: localizedApp(const SafetyCenter(privacy: true)),
        ),
      );
      final list = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text(arStrings.safetyDelete),
        300,
        scrollable: list,
      );
      await tester.tap(find.text(arStrings.safetyDelete));
      await tester.pumpAndSettle();
      expect(
        backend.calls.where((c) => c.function == 'player_safety'),
        isEmpty,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, arStrings.safetyDelete),
      );
      await tester.pumpAndSettle();
      expect(backend.calls.single.body['action'], 'delete');
      await tester.scrollUntilVisible(
        find.textContaining('test-receipt'),
        300,
        scrollable: list,
      );
      expect(find.textContaining('test-receipt'), findsOneWidget);
    },
  );
}
