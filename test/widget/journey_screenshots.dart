/// Renders the public journey — Home, mode choice, onboarding, profile, the
/// online door and the lobby — for looking at.
///
/// **Not a test** (no `_test` suffix, asserts nothing), like
/// `test/widget/store_screenshots.dart`. Real fonts and the real asset bundle
/// are loaded; these are widget renders, not device screenshots.
///
///     flutter test test/widget/journey_screenshots.dart
///
/// Writes to `build/phase99/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/app/locale_controller.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/fake_voice_engine.dart';
import '../support/localized.dart';
import '../support/stores.dart';

const _narrow = Size(360, 780);
const _phone = Size(390, 844);
const _desktop = Size(1280, 800);

Future<void> _fonts() async {
  const families = <String, List<String>>{
    'Roboto': ['assets/fonts/IBMPlexSansArabic-Regular.ttf'],
    'Bebas Neue': ['assets/fonts/BebasNeue-Regular.ttf'],
    'Cairo': ['assets/fonts/Cairo-Variable.ttf'],
    'IBM Plex Sans Arabic': [
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
      'assets/fonts/IBMPlexSansArabic-Medium.ttf',
      'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    ],
    'IBM Plex Mono': ['assets/fonts/IBMPlexMono-Regular.ttf'],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

void main() {
  final out = Directory('build/phase99')..createSync(recursive: true);
  setUpAll(() async => _fonts());

  Future<void> save(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        // An animated loop never "finishes"; its first frame is enough.
        await precacheImage(
          (element.widget as Image).image,
          element,
        ).timeout(const Duration(seconds: 2), onTimeout: () {});
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 2);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  Future<void> surface(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Widget shot(Widget child, {List<Override> overrides = const []}) =>
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [
            audioDirectorProvider.overrideWithValue(AudioDirector()),
            ...overrides,
          ],
          child: AmbientMotion(enabled: false, child: child),
        ),
      );

  for (final (name, size, locale) in [
    ('home-ar-390', _phone, const Locale('ar')),
    ('home-en-360', _narrow, const Locale('en')),
    ('home-ar-desktop', _desktop, const Locale('ar')),
  ]) {
    testWidgets(name, (tester) async {
      seedReturningProfile();
      await surface(tester, size);
      await tester.pumpWidget(
        shot(
          localizedApp(
            HomeScreen(
              onNewMatch: () {},
              onHistory: () {},
              onSettings: () {},
              onHowToPlay: () {},
              onProfile: () {},
              tiltSource: const LevelTiltSource(),
            ),
            locale: locale,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await save(tester, name);
    });
  }

  for (final (name, size, locale) in [
    ('mode-ar-360', _narrow, const Locale('ar')),
    ('mode-en-390', _phone, const Locale('en')),
    ('mode-ar-desktop', _desktop, const Locale('ar')),
  ]) {
    testWidgets(name, (tester) async {
      await surface(tester, size);
      await tester.pumpWidget(
        shot(
          localizedApp(
            ModeScreen(
              onPlayOffline: () {},
              onPlayOnline: () {},
              onBack: () {},
            ),
            locale: locale,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await save(tester, name);
    });
  }

  for (final (name, size, locale) in [
    ('profile-ar-360', _narrow, const Locale('ar')),
    ('profile-en-desktop', _desktop, const Locale('en')),
  ]) {
    testWidgets(name, (tester) async {
      seedReturningProfile();
      await surface(tester, size);
      await tester.pumpWidget(
        shot(
          localizedApp(
            ProfileScreen(onSaved: () {}, onBack: () {}),
            locale: locale,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await save(tester, name);
    });
  }

  for (final (name, size, locale) in [
    ('onboarding-ar-360', _narrow, const Locale('ar')),
    ('onboarding-en-390', _phone, const Locale('en')),
    ('onboarding-ar-desktop', _desktop, const Locale('ar')),
  ]) {
    testWidgets(name, (tester) async {
      SharedPreferences.setMockInitialValues({});
      await surface(tester, size);
      await tester.pumpWidget(
        shot(
          Consumer(
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
              home: const SetupRequired(child: Text('HOME')),
            ),
          ),
          overrides: [initialLocaleProvider.overrideWithValue(locale)],
        ),
      );
      await tester.pumpAndSettle();
      await save(tester, '$name-1');
      Future<void> next() async {
        await tester.ensureVisible(find.byKey(FirstRunScreen.nextKey));
        await tester.tap(find.byKey(FirstRunScreen.nextKey));
        await tester.pumpAndSettle();
      }

      await next();
      await tester.enterText(find.byKey(FirstRunScreen.nameKey), 'Eyad');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await save(tester, '$name-2');
      await tester.tap(find.byKey(const ValueKey('gender_male')));
      await tester.pumpAndSettle();
      await next();
      await save(tester, '$name-3');
      await next();
      await save(tester, '$name-4');
    });
  }

  ProviderContainer online({List<Map<String, dynamic>> rooms = const []}) {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(3),
      own: const OwnSeat(seat: 0),
    );
    backend
      ..responses['browse_rooms'] = {'rooms': rooms}
      ..responses['create_room'] = {'roomId': 'room-1', 'code': 'ABCDEF'};
    return ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
        // The lobby starts the room's voice; the test host has no WebRTC
        // plugin, so the capture uses the suite's fake engine.
        voiceEngineFactoryProvider.overrideWithValue(FakeVoiceEngine.new),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
    );
  }

  const rooms = [
    {'code': 'NEARAA', 'players': 4, 'voice': true, 'title': 'سهرة الخميس'},
    {'code': 'READYA', 'players': 6, 'voice': false},
  ];

  for (final (name, size, locale, list) in [
    ('entry-ar-360', _narrow, const Locale('ar'), rooms),
    ('entry-en-390-empty', _phone, const Locale('en'), <Map<String, dynamic>>[]),
    ('entry-ar-desktop', _desktop, const Locale('ar'), rooms),
  ]) {
    testWidgets(name, (tester) async {
      seedReturningProfile();
      await surface(tester, size);
      final container = online(rooms: list);
      addTearDown(container.dispose);
      await container.read(playerProfileProvider.future);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: UncontrolledProviderScope(
            container: container,
            child: localizedApp(
              OnlineEntryScreen(onJoined: () {}, onBack: () {}),
              locale: locale,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await save(tester, name);
    });
  }

  for (final (name, size, locale) in [
    ('lobby-ar-360', _narrow, const Locale('ar')),
    ('lobby-en-desktop', _desktop, const Locale('en')),
  ]) {
    testWidgets(name, (tester) async {
      seedReturningProfile();
      await surface(tester, size);
      final container = online();
      addTearDown(container.dispose);
      await container.read(playerProfileProvider.future);
      await container.read(onlineSessionProvider.notifier).host('A');
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: UncontrolledProviderScope(
            container: container,
            child: localizedApp(
              LobbyScreen(onStarted: () {}, onLeave: () {}),
              locale: locale,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await save(tester, name);
    });
  }
}
