import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/app/router.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/transport/account_service.dart'
    show AccountFailure;
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart';
import 'package:mafia_master/ui/account/profile_panels.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/first_run_steps.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// The Google return (owner report, 2026-10-01, real phones).
///
/// Google sign-in leaves the app for the browser and comes back through
/// `mafiamaster://login-callback?code=…`. Android hands that link to the
/// Flutter router as well as to Supabase, and the router used to treat it as
/// a page address: it has no path, so it became Home. During onboarding that
/// built a fresh first-run screen at its first chapter (bug 1); from the
/// profile it closed the profile and the account sheet that would have said
/// how the link went (bug 2). The link belongs to the auth client; the player
/// stays where they were.
class _FakeAuth extends AccountAuth {
  _FakeAuth()
    : super(() => throw UnimplementedError(), ensureSession: () async {});

  final calls = <String>[];

  @override
  Future<void> google() async => calls.add('google');

  @override
  Future<void> googleSignIn() async => calls.add('googleSignIn');
}

const _callback = 'mafiamaster://login-callback?code=abc123';

const _google = AccountProfile(
  signedIn: true,
  email: 'eyad@example.com',
  emailConfirmed: true,
  google: true,
  name: 'Eyad Abdelrahman',
);

/// What the engine does when Android delivers an intent's link.
Future<void> _platformOpens(WidgetTester tester, String link) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', {'location': link, 'state': null}),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  late MemoryMatchStore store;
  late _FakeAuth auth;
  late StreamController<AccountProfile> profiles;

  setUp(() {
    store = MemoryMatchStore();
    auth = _FakeAuth();
    profiles = StreamController<AccountProfile>.broadcast();
  });
  tearDown(() => profiles.close());

  Future<void> launch(
    WidgetTester tester, {
    String? at,
    AccountProfile initial = AccountProfile.guest,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // A real relaunch: nothing of the previous tree survives.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final container = ProviderContainer(
      overrides: [
        matchRepositoryProvider.overrideWithValue(MemoryMatchRepository(store)),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        accountsAvailableProvider.overrideWithValue(true),
        accountAuthProvider.overrideWithValue(auth),
        accountProfileProvider.overrideWith((ref) async* {
          yield initial;
          yield* profiles.stream;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AmbientMotion(
          enabled: false,
          child: MafiaApp(initialLocation: at),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> toSaveStep(WidgetTester tester) async {
    await passIntro(tester);
    await answerKind(tester);
    await typeName(tester, 'Eyad');
    await _tap(tester, FirstRunScreen.nextKey);
  }

  group('bug 1: Google during onboarding', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('the return finishes setup, never restarts it', (
      tester,
    ) async {
      await launch(tester);
      expect(find.byKey(FirstRunScreen.screenKey), findsOneWidget);
      await toSaveStep(tester);
      await _tap(tester, FirstRunScreen.emailKey);
      await _tap(tester, AccountSheet.googleKey);
      expect(auth.calls, hasLength(1));

      await _platformOpens(tester, _callback);
      expect(
        find.byType(AccountSheet),
        findsOneWidget,
        reason: 'the full-screen sign-in survives the browser return',
      );

      profiles.add(_google);
      await tester.pumpAndSettle();
      expect(find.byType(AccountSheet), findsNothing);
      expect(
        find.byKey(FirstRunScreen.boyKey),
        findsNothing,
        reason: 'the first question is not asked again',
      );
      expect((await ProfileStore().load())!.name, 'Eyad');
    });

    testWidgets('a cold start from the return resumes the same step', (
      tester,
    ) async {
      await launch(tester);
      await toSaveStep(tester);
      await _tap(tester, FirstRunScreen.googleKey);

      // Android killed the app while the browser was open; the link starts
      // it again, already signed in.
      await launch(tester, at: _callback, initial: _google);
      expect(find.byKey(FirstRunScreen.boyKey), findsNothing);
      expect(
        (await ProfileStore().load())?.name,
        'Eyad',
        reason: 'the typed name and the ticked box came back with it',
      );
    });

    testWidgets('system back during first run steps back one step', (
      tester,
    ) async {
      await launch(tester);
      await toSaveStep(tester);
      expect(find.byKey(FirstRunScreen.guestKey), findsOneWidget);
      // Used to `go` Home, which is a brand-new first-run screen.
      await tester.runAsync(() => tester.binding.handlePopRoute());
      await tester.pumpAndSettle();
      expect(find.byKey(FirstRunScreen.nameKey), findsOneWidget);
    });

    testWidgets('onboarding links Google and keeps the anonymous id', (
      tester,
    ) async {
      await launch(tester);
      await toSaveStep(tester);
      await _tap(tester, FirstRunScreen.googleKey);
      expect(auth.calls, ['google']);
    });
  });

  group('bug 2: a guest links Google from the profile', () {
    setUp(seedReturningProfile);

    Future<void> openSheetAndGoogle(WidgetTester tester) async {
      store = returningHostStore();
      await launch(tester, at: Routes.profile);
      expect(find.byType(ProfileScreen), findsOneWidget);
      await _tap(tester, AccountCard.cardKey);
      await _tap(tester, AccountSheet.googleKey);
      expect(auth.calls, ['google'], reason: 'a guest links, keeping the id');
      await _platformOpens(tester, _callback);
    }

    testWidgets('the return stays on the profile and shows the email', (
      tester,
    ) async {
      await openSheetAndGoogle(tester);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(AccountSheet), findsOneWidget);

      profiles.add(_google);
      await tester.pumpAndSettle();
      expect(find.byType(AccountSheet), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(AccountCard.cardKey),
          matching: find.text('eyad@example.com'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a Google account that is taken is signed in to', (
      tester,
    ) async {
      await openSheetAndGoogle(tester);
      profiles.addError(const AccountFailure('EMAIL_TAKEN'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['google', 'googleSignIn']);
      expect(find.byKey(AccountSheet.googleExistingKey), findsNothing);
    });

    testWidgets('taken twice in a row: switch or stay, the guest decides', (
      tester,
    ) async {
      await openSheetAndGoogle(tester);
      profiles.addError(const AccountFailure('EMAIL_TAKEN'));
      await tester.pumpAndSettle();
      profiles.addError(const AccountFailure('EMAIL_TAKEN'));
      await tester.pumpAndSettle();
      expect(find.byKey(AccountSheet.googleExistingKey), findsOneWidget);
      expect(find.byKey(AccountSheet.keepGuestKey), findsOneWidget);

      await _tap(tester, AccountSheet.keepGuestKey);
      expect(find.byKey(AccountSheet.googleExistingKey), findsNothing);
      expect(find.byKey(AccountSheet.errorKey), findsNothing);
      expect(auth.calls, [
        'google',
        'googleSignIn',
      ], reason: 'staying a guest changes nothing');
    });

    testWidgets('a refusal that arrives with no sheet open signs in', (
      tester,
    ) async {
      store = returningHostStore();
      await launch(tester, at: Routes.profile);
      await _platformOpens(tester, _callback);
      profiles.addError(const AccountFailure('EMAIL_TAKEN'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['googleSignIn']);
      expect(find.byType(AccountSheet), findsNothing);

      // Refused again at once: the sheet opens with the choice.
      profiles.addError(const AccountFailure('EMAIL_TAKEN'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSheet), findsOneWidget);
      expect(find.byKey(AccountSheet.googleExistingKey), findsOneWidget);
    });
  });

  group('auth callbacks are not page addresses', () {
    test('which links are auth returns', () {
      expect(isAuthCallback(Uri.parse(_callback)), isTrue);
      expect(
        isAuthCallback(Uri.parse('mafiamaster://login-callback#error=x')),
        isTrue,
      );
      expect(
        isAuthCallback(Uri.parse('https://saidalmafia.com/?code=abc')),
        isTrue,
      );
      expect(
        isAuthCallback(Uri.parse('https://saidalmafia.com/join/K7M2QP')),
        isFalse,
      );
      expect(isAuthCallback(Uri.parse('/onboarding?next=%2F')), isFalse);
    });

    test('stays put while running; strips the auth part on a cold start', () {
      final here = Uri.parse('/onboarding?next=%2F');
      expect(authCallbackRedirect(Uri.parse(_callback), here), here.toString());
      expect(authCallbackRedirect(Uri.parse(_callback), null), Routes.home);
      expect(
        authCallbackRedirect(
          Uri.parse('https://saidalmafia.com/admin?code=abc&order=7'),
          null,
        ),
        '/admin?order=7',
      );
      expect(authCallbackRedirect(here, null), isNull);
    });
  });

  testWidgets('first-run progress survives a restart', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsAvailableProvider.overrideWithValue(true),
          accountAuthProvider.overrideWithValue(auth),
          accountProfileProvider.overrideWith(
            (ref) => Stream.value(AccountProfile.guest),
          ),
        ],
        child: localizedApp(const FirstRunScreen()),
      ),
    );
    await passIntro(tester);
    await answerKind(tester);
    await typeName(tester, 'Mona');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsAvailableProvider.overrideWithValue(true),
          accountAuthProvider.overrideWithValue(auth),
          accountProfileProvider.overrideWith(
            (ref) => Stream.value(AccountProfile.guest),
          ),
        ],
        child: localizedApp(const FirstRunScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(FirstRunScreen.nameKey), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(FirstRunScreen.nameKey))
          .controller!
          .text,
      'Mona',
    );
  });
}
