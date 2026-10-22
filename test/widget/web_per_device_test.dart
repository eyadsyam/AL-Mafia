import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/push/push_service.dart';
import 'package:mafia_master/platform/review_prompt.dart'
    show SharedPreferencesReviewStateStore;
import 'package:mafia_master/ui/widgets/add_to_home_sheet.dart';
import 'package:mafia_master/ui/widgets/play_app_ribbon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

class _Push implements PushService {
  _Push(this.install);
  final bool install;
  @override
  String? get platform => 'web';
  @override
  bool get needsInstall => install;
  @override
  Future<void> init() async {}
  @override
  Future<bool> askPermission() async => false;
  @override
  Future<bool> isGranted() async => false;
  @override
  Future<String?> token() async => null;
  @override
  Stream<PushOpen> get opened => const Stream.empty();
  @override
  Stream<void> get foreground => const Stream.empty();
  @override
  Future<PushOpen?> initialOpen() async => null;
}

void main() {
  Future<void> ribbon(WidgetTester tester, {required bool eligible}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playRibbonEligibleProvider.overrideWithValue(eligible)],
        child: localizedApp(const Scaffold(body: PlayAppRibbon())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the app ribbon shows on Android web and, closed, stays closed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await ribbon(tester, eligible: true);
    expect(find.text(arStrings.playRibbonText), findsOneWidget);
    await tester.tap(find.byKey(PlayAppRibbon.closeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(PlayAppRibbon.ribbonKey), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await ribbon(tester, eligible: true);
    expect(find.byKey(PlayAppRibbon.ribbonKey), findsNothing);
  });

  testWidgets('the app ribbon never shows anywhere else', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ribbon(tester, eligible: false);
    expect(find.byKey(PlayAppRibbon.ribbonKey), findsNothing);
  });

  Future<void> home(WidgetTester tester, bool install) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pushServiceProvider.overrideWithValue(_Push(install))],
        child: localizedApp(
          Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => AddToHome.maybeOffer(context, ref),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('an iPhone browser tab gets the home-screen steps once, after '
      'a finished match', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await home(tester, true);
    expect(find.text(arStrings.addToHomeTitle), findsNothing);

    SharedPreferences.setMockInitialValues({
      SharedPreferencesReviewStateStore.cleanMatchesKey: 1,
    });
    await home(tester, true);
    expect(find.text(arStrings.addToHomeTitle), findsOneWidget);
    await tester.tap(find.byKey(AddToHome.doneKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.addToHomeTitle), findsNothing);
  });

  testWidgets('no home-screen steps outside an iPhone browser tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesReviewStateStore.cleanMatchesKey: 3,
    });
    await home(tester, false);
    expect(find.text(arStrings.addToHomeTitle), findsNothing);
  });
}
