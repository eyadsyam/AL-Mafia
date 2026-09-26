import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
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
import 'package:mafia_master/platform/launcher_label.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/online/safety_center.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';
import 'package:mafia_master/ui/widgets/gender_picker.dart';
import 'package:mafia_master/ui/widgets/language_picker.dart';
import 'package:mafia_master/ui/widgets/legal_documents.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _fillProfile(WidgetTester tester) async {
  await _tick(tester, FirstRunScreen.nextKey);
  await tester.enterText(find.byKey(FirstRunScreen.nameKey), 'Eyad');
  await tester.ensureVisible(find.byKey(GenderPicker.maleKey));
  await tester.tap(find.byKey(GenderPicker.maleKey));
  await tester.pumpAndSettle();
  await _tick(tester, FirstRunScreen.nextKey);
  await _tick(tester, FirstRunScreen.nextKey);
}

Future<void> _tick(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

bool _continueEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(FirstRunScreen.continueKey))
        .onPressed !=
    null;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('fresh install: continue waits for profile, 18+ and the box', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(FirstRunScreen.screenKey), findsOneWidget);
    expect(find.byType(LanguagePicker), findsOneWidget);
    expect(find.byKey(FirstRunScreen.termsKey), findsNothing);
    await _fillProfile(tester);
    // Nothing is prechecked.
    expect(
      tester.widget<Checkbox>(find.byKey(FirstRunScreen.termsKey)).value,
      isFalse,
    );
    expect(_continueEnabled(tester), isFalse);
    await _tick(tester, FirstRunScreen.adultKey);
    expect(_continueEnabled(tester), isFalse, reason: 'terms unticked');
    await _tick(tester, FirstRunScreen.termsKey);
    expect(_continueEnabled(tester), isTrue);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);

    final saved = await TermsStore().load();
    expect(saved!.version, currentTermsVersion);
    expect(saved.adult, isTrue);
    expect(saved.synced, isFalse);
    expect((await ProfileStore().load())!.name, 'Eyad');
  });

  testWidgets('opening the terms and coming back keeps the form', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _fillProfile(tester);
    await _tick(tester, FirstRunScreen.adultKey);
    await _tick(tester, FirstRunScreen.termsLinkKey);
    expect(find.byKey(LegalDocuments.termsSheetKey), findsOneWidget);
    // Opening the document is not acceptance.
    expect(
      tester.widget<Checkbox>(find.byKey(FirstRunScreen.termsKey)).value,
      isFalse,
    );
    await tester.tap(find.byKey(LegalDocuments.closeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LegalDocuments.termsSheetKey), findsNothing);
    await _tick(tester, FirstRunScreen.privacyLinkKey);
    expect(find.byKey(LegalDocuments.privacySheetKey), findsOneWidget);
    // System back closes the sheet, not the setup.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(LegalDocuments.privacySheetKey), findsNothing);
    await _tick(tester, FirstRunScreen.backKey);
    await _tick(tester, FirstRunScreen.backKey);
    expect(
      tester
          .widget<TextField>(find.byKey(FirstRunScreen.nameKey))
          .controller!
          .text,
      'Eyad',
    );
    await _tick(tester, FirstRunScreen.nextKey);
    await _tick(tester, FirstRunScreen.nextKey);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(FirstRunScreen.adultKey))
          .value,
      isTrue,
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
    await _fillProfile(tester);
    await _tick(tester, FirstRunScreen.adultKey);
    await _tick(tester, FirstRunScreen.termsKey);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsNothing);
    expect(find.byKey(FirstRunScreen.failedKey), findsOneWidget);
    // The profile landed, so the form narrowed to the terms, and the ticks
    // the player already gave are still there: no loop, one more tap.
    expect(
      tester.widget<Checkbox>(find.byKey(FirstRunScreen.termsKey)).value,
      isTrue,
    );
    expect(_continueEnabled(tester), isTrue);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
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
    });
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(FirstRunScreen.screenKey), findsNothing);
  });

  testWidgets('an existing profile gets one compact terms prompt', (
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
    expect(find.byType(LanguagePicker), findsNothing);
    await _tick(tester, FirstRunScreen.adultKey);
    await _tick(tester, FirstRunScreen.termsKey);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect((await ProfileStore().load())!.name, 'Old');
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
    // The 18+ answer carries over; the terms box never does.
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(FirstRunScreen.adultKey))
          .value,
      isTrue,
    );
    expect(
      tester.widget<Checkbox>(find.byKey(FirstRunScreen.termsKey)).value,
      isFalse,
    );
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
      initialLocation: '/join/ABCD',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
        GoRoute(
          path: '/join/:code',
          builder: (_, state) => SetupRequired(
            child: Text('JOIN ${state.pathParameters['code']}'),
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
    await tester.pumpAndSettle();
    await _fillProfile(tester);
    await _tick(tester, FirstRunScreen.adultKey);
    await _tick(tester, FirstRunScreen.termsKey);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
    expect(find.text('JOIN ABCD'), findsOneWidget);
  });

  testWidgets('language switches in place and keeps what was typed', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _fillProfile(tester);
    await _tick(tester, FirstRunScreen.adultKey);
    for (var i = 0; i < 3; i++) {
      await _tick(tester, FirstRunScreen.backKey);
    }
    final state = tester.state(find.byKey(FirstRunScreen.screenKey));
    await tester.ensureVisible(find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Mafia Master'), findsOneWidget);
    await _tick(tester, FirstRunScreen.nextKey);
    final name = find.byKey(FirstRunScreen.nameKey);
    expect(Directionality.of(tester.element(name)), TextDirection.ltr);
    expect(tester.widget<TextField>(name).controller!.text, 'Eyad');
    await _tick(tester, FirstRunScreen.nextKey);
    await _tick(tester, FirstRunScreen.nextKey);
    // Same State object: nothing was torn down or rebuilt from scratch.
    expect(tester.state(find.byKey(FirstRunScreen.screenKey)), same(state));
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(FirstRunScreen.adultKey))
          .value,
      isTrue,
    );
  });

  testWidgets('preferences are saved with setup', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _fillProfile(tester);
    await _tick(tester, FirstRunScreen.backKey);
    await _tick(tester, FirstRunScreen.motionKey);
    await _tick(tester, FirstRunScreen.nextKey);
    await _tick(tester, FirstRunScreen.adultKey);
    await _tick(tester, FirstRunScreen.termsKey);
    await tester.tap(find.byKey(FirstRunScreen.continueKey));
    await tester.pumpAndSettle();
    expect(await loadReduceMotionPreference(), isTrue);
  });

  for (final locale in ['ar', 'en']) {
    for (final size in [const Size(390, 844), const Size(740, 360)]) {
      testWidgets('arrival is usable in $locale at $size', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const capture = bool.fromEnvironment('CAPTURE_ARRIVAL');
        const frame = ValueKey('arrival_frame');
        if (capture) {
          const fonts = {
            'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
            'IBM Plex Sans Arabic':
                'assets/fonts/IBMPlexSansArabic-Regular.ttf',
            'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
            'Cairo': 'assets/fonts/Cairo-Variable.ttf',
            'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
          };
          for (final entry in fonts.entries) {
            final loader = FontLoader(entry.key)
              ..addFont(rootBundle.load(entry.value));
            await loader.load();
          }
        }
        await tester.pumpWidget(
          RepaintBoundary(
            key: frame,
            child: _app(
              overrides: [
                initialLocaleProvider.overrideWithValue(Locale(locale)),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> photo(String name) async {
          if (!capture || locale != 'ar' || size.width != 390) return;
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(frame),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/experience-review/$name.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await photo('01-language');
        await _tick(tester, FirstRunScreen.nextKey);
        expect(
          tester
              .widget<FilledButton>(find.byKey(FirstRunScreen.nextKey))
              .onPressed,
          isNull,
        );
        await tester.enterText(find.byKey(FirstRunScreen.nameKey), 'Eyad');
        await _tick(tester, GenderPicker.maleKey);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await photo('02-identity');
        await _tick(tester, FirstRunScreen.nextKey);
        await photo('03-preferences');
        // System back moves one chapter, preserving the entered profile.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(FirstRunScreen.nameKey))
              .controller!
              .text,
          'Eyad',
        );
        await _tick(tester, FirstRunScreen.nextKey);
        await _tick(tester, FirstRunScreen.nextKey);
        await photo('04-pact');
        expect(_continueEnabled(tester), isFalse);
        await _tick(tester, FirstRunScreen.adultKey);
        await _tick(tester, FirstRunScreen.termsKey);
        await _tick(tester, FirstRunScreen.continueKey);
        expect(find.text('HOME'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

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
