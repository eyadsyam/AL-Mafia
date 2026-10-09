import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/app/locale_controller.dart';
import 'package:mafia_master/data/motion_preference.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/terms_consent.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/platform/launcher_label.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/onboarding/permissions_step.dart';
import 'package:mafia_master/ui/screens/online/safety_center.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';
import 'package:mafia_master/ui/widgets/deck/deck_buttons.dart';
import 'package:mafia_master/ui/widgets/language_picker.dart';
import 'package:mafia_master/ui/widgets/legal_documents.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/first_run_steps.dart';

class _FlakyTermsStore extends TermsStore {
  int failuresLeft;
  _FlakyTermsStore(this.failuresLeft);
  @override
  Future<void> save(TermsAcceptance acceptance) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('disk full');
    }
    await super.save(acceptance);
  }
}

Widget _app({List<Override> overrides = const [], Widget? home}) =>
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MafiaTheme.dark,
          locale: ref.watch(localeProvider),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home ?? const SetupRequired(child: Text('HOME')),
        ),
      ),
    );

bool _continueEnabled(WidgetTester tester) =>
    tester
        .widget<BoneButton>(find.byKey(FirstRunScreen.continueKey))
        .onPressed !=
    null;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('fresh install: the three steps, the record, then Home', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(FirstRunScreen.screenKey), findsOneWidget);
    // The intro handed over to the first question (two dots: no server).
    expect(find.byKey(FirstRunScreen.boyKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.girlKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.dotsKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.languageKey), findsOneWidget);
    await tapKey(tester, FirstRunScreen.agreeKey);
    await tapKey(tester, FirstRunScreen.girlKey);
    expect(find.byKey(FirstRunScreen.nameKey), findsOneWidget);
    expect(_continueEnabled(tester), isFalse);
    await typeName(tester, 'Mona');
    expect(_continueEnabled(tester), isTrue);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
    expect(find.byKey(PermissionsStep.continueKey), findsOneWidget);
    await tapKey(tester, PermissionsStep.continueKey);
    expect(find.text('HOME'), findsOneWidget);

    final saved = await TermsStore().load();
    expect(saved!.version, currentTermsVersion);
    expect(saved.adult, isTrue);
    expect(saved.synced, isFalse);
    final profile = (await ProfileStore().load())!;
    expect(profile.name, 'Mona');
    expect(profile.gender, PlayerGender.female);
    expect(await WelcomeGreeting.pending(), isTrue);
  });

  testWidgets('the cards stay dimmed and shake until the box is ticked', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FirstRunScreen.boyKey));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(FirstRunScreen.nameKey), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(FirstRunScreen.nameKey), findsNothing);
    expect(await TermsStore().load(), isNull);
    await tapKey(tester, FirstRunScreen.agreeKey);
    await tapKey(tester, FirstRunScreen.boyKey);
    expect(find.byKey(FirstRunScreen.nameKey), findsOneWidget);
  });

  testWidgets('one letter is not a name; two are, and the plate follows', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await answerKind(tester);
    expect(find.text('اسمك هنا'), findsOneWidget);
    await typeName(tester, 'M');
    expect(_continueEnabled(tester), isFalse);
    await typeName(tester, 'Mo');
    expect(_continueEnabled(tester), isTrue);
    expect(
      find.descendant(
        of: find.byKey(FirstRunScreen.myCardKey),
        matching: find.text('Mo'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('back from the name keeps the box and the typed name', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await answerKind(tester);
    await typeName(tester, 'Eyad');
    await tapKey(tester, FirstRunScreen.backKey);
    expect(find.byKey(FirstRunScreen.boyKey), findsOneWidget);
    await tapKey(tester, FirstRunScreen.boyKey);
    expect(
      tester
          .widget<TextField>(find.byKey(FirstRunScreen.nameKey))
          .controller!
          .text,
      'Eyad',
    );
  });

  testWidgets('opening the terms and coming back keeps the box', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tapKey(tester, FirstRunScreen.agreeKey);
    await tapKey(tester, FirstRunScreen.termsLinkKey);
    expect(find.byKey(LegalDocuments.termsSheetKey), findsOneWidget);
    await tester.tap(find.byKey(LegalDocuments.closeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LegalDocuments.termsSheetKey), findsNothing);
    await tapKey(tester, FirstRunScreen.privacyLinkKey);
    expect(find.byKey(LegalDocuments.privacySheetKey), findsOneWidget);
    // System back closes the sheet, not the setup.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(LegalDocuments.privacySheetKey), findsNothing);
    expect(
      tester.getSemantics(find.byKey(FirstRunScreen.agreeKey)),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
  });

  testWidgets('a failed save stays on the form and retries in place', (
    tester,
  ) async {
    final store = _FlakyTermsStore(1);
    await tester.pumpWidget(
      _app(overrides: [termsStoreProvider.overrideWithValue(store)]),
    );
    await tester.pumpAndSettle();
    await completeFirstRun(tester);
    expect(find.text('HOME'), findsNothing);
    expect(find.byKey(FirstRunScreen.failedKey), findsOneWidget);
    // The profile landed, so the form narrowed to the box, still ticked:
    // no loop, one more tap.
    expect(
      tester
          .widget<BoneButton>(find.byKey(PermissionsStep.continueKey))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(PermissionsStep.continueKey));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('restart after setup goes straight to the destination', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: '{"name":"A","gender":"male"}',
      TermsStore.versionKey: currentTermsVersion,
      TermsStore.acceptedAtKey: '2026-09-23T10:00:00.000Z',
      TermsStore.adultKey: true,
      permissionsDoneKey: true,
    });
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(FirstRunScreen.screenKey), findsNothing);
  });

  testWidgets('an existing profile gets one compact prompt: the box', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: '{"name":"Old","gender":"female"}',
      'community_rules_2026_09': true,
    });
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(FirstRunScreen.screenKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.nameKey), findsNothing);
    expect(find.byKey(FirstRunScreen.boyKey), findsNothing);
    expect(_continueEnabled(tester), isFalse);
    await tapKey(tester, FirstRunScreen.agreeKey);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
    await tapKey(tester, PermissionsStep.continueKey);
    expect(find.text('HOME'), findsOneWidget);
    expect((await ProfileStore().load())!.name, 'Old');
    expect((await TermsStore().load())!.adult, isTrue);
    expect(await WelcomeGreeting.pending(), isFalse);
  });

  testWidgets('only a changed terms version asks again', (tester) async {
    SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: '{"name":"A","gender":"male"}',
      TermsStore.versionKey: '2025-01-01',
      TermsStore.acceptedAtKey: '2025-01-01T10:00:00.000Z',
      TermsStore.adultKey: true,
      TermsStore.syncedKey: true,
    });
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(FirstRunScreen.screenKey), findsOneWidget);
    // The box never carries over.
    expect(_continueEnabled(tester), isFalse);
  });

  testWidgets('a valid acceptance is never asked again before a room', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      TermsStore.versionKey: currentTermsVersion,
      TermsStore.acceptedAtKey: '2026-09-23T10:00:00.000Z',
      TermsStore.adultKey: true,
    });
    bool? accepted;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                accepted = await acceptCommunityRules(context),
            child: const Text('join'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('join'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a deep link resumes its destination after setup', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/join/ABCDEF?ref=43D4YUG',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
        GoRoute(
          path: '/join/:code',
          builder: (_, state) => SetupRequired(
            child: Text(
              'JOIN ${state.pathParameters['code']} REF ${state.uri.queryParameters['ref']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: MafiaTheme.dark,
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await completeFirstRun(tester);
    expect(find.text('JOIN ABCDEF REF 43D4YUG'), findsOneWidget);
  });

  testWidgets('English switches in place and keeps what was ticked', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tapKey(tester, FirstRunScreen.agreeKey);
    final state = tester.state(find.byKey(FirstRunScreen.screenKey));
    await tapKey(tester, FirstRunScreen.languageKey);
    expect(find.text('How should we address you?'), findsOneWidget);
    expect(find.text('العربي'), findsOneWidget);
    // Same State object: nothing was torn down or rebuilt from scratch.
    expect(tester.state(find.byKey(FirstRunScreen.screenKey)), same(state));
    await tapKey(tester, FirstRunScreen.boyKey);
    expect(find.byKey(FirstRunScreen.nameKey), findsOneWidget);
  });

  testWidgets('sound and motion choices follow the name', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await answerKind(tester);
    await typeName(tester, 'Eyad');
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsWidgets);
    expect(await loadReduceMotionPreference(), isFalse);
  });

  for (final size in [const Size(360, 640), const Size(430, 932)]) {
    testWidgets('every step fits $size, also with the keyboard up', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'intro');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'kind');
      await answerKind(tester);
      expect(tester.takeException(), isNull, reason: 'name');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height * 0.4 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final field = tester.getRect(find.byKey(FirstRunScreen.nameKey));
      expect(field.top, greaterThanOrEqualTo(0));
      expect(field.bottom, lessThanOrEqualTo(size.height * 0.6));
      expect(tester.takeException(), isNull, reason: 'keyboard');
    });
  }

  testWidgets('reduced motion jumps to the end states', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(FirstRunTokens.introStill);
    await tester.pump();
    expect(find.byKey(FirstRunScreen.boyKey), findsOneWidget);
    await tester.tap(find.byKey(FirstRunScreen.agreeKey));
    await tester.pump();
    await tester.tap(find.byKey(FirstRunScreen.boyKey));
    await tester.pump();
    expect(find.byKey(FirstRunScreen.nameKey), findsOneWidget);
  });

  group('launcher label', () {
    const channel = MethodChannel('mafia_master/launcher');
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('not Android: nothing to do', () async {
      expect(await LauncherLabel.apply('en'), LauncherLabelResult.unsupported);
    });

    testWidgets('a switch that would close the game waits and says so', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.arguments as String?);
            return 'pending';
          });
      await tester.pumpWidget(
        _app(home: const Scaffold(body: LanguagePicker())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(calls, ['en']);
      expect(find.byKey(LanguagePicker.launcherNoteKey), findsOneWidget);
      // The interface changed at once; nothing restarted.
      expect(find.text('English'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(LanguagePicker))),
        TextDirection.ltr,
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
