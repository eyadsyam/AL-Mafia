import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/setup/help_center.dart';

import '../support/localized.dart';

void main() {
  testWidgets('FAQ exposes gameplay, voice, safety and deletion answers', (
    tester,
  ) async {
    await tester.pumpWidget(localizedApp(const HelpCenter()));

    expect(find.text(arStrings.helpTitle), findsOneWidget);
    expect(find.text(arStrings.helpPlayQuestion), findsOneWidget);
    expect(find.text(arStrings.helpVoiceQuestion), findsOneWidget);
    expect(find.text(arStrings.helpSafetyQuestion), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(arStrings.helpPrivacyQuestion),
      200,
    );
    expect(find.text(arStrings.helpPrivacyQuestion), findsOneWidget);

    await tester.tap(find.text(arStrings.helpSafetyQuestion));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.helpSafetyAnswer), findsOneWidget);
    expect(arStrings.helpSafetyAnswer, contains('مش حكم آلي'));
  });
}
