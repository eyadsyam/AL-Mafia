import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/player.dart' show PlayerGender;
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart';
import 'package:mafia_master/ui/account/profile_panels.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/terms_consent.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/first_run_steps.dart';
import '../support/localized.dart';

class _FakeAuth extends AccountAuth {
  _FakeAuth()
    : super(() => throw UnimplementedError(), ensureSession: () async {});

  final calls = <String>[];

  @override
  Future<void> google() async => calls.add('google');

  @override
  Future<void> googleSignIn() async => calls.add('googleSignIn');

  @override
  Future<void> startSignUp(String email, String password) async =>
      calls.add('startSignUp:$email');
}

/// The account's own entry, as the server would answer it.
class _FakeDirectory extends DirectoryApi {
  _FakeDirectory(super.ref, {this.entry = const DirectoryMe(), this.taken});
  final DirectoryMe entry;
  final String? taken;
  final calls = <String>[];

  @override
  Future<DirectoryMe> me() async {
    calls.add('me');
    return entry;
  }

  @override
  Future<DirectoryMe> hello({
    required String name,
    required String gender,
    required String tz,
    required String locale,
  }) async {
    calls.add('hello:$name');
    return const DirectoryMe(handle: 'auto');
  }

  @override
  Future<(DirectoryMe?, HandleRefusal?)> setHandle(String handle) async {
    calls.add('setHandle:$handle');
    if (handle == taken) return (null, HandleRefusal.taken);
    return (DirectoryMe(handle: handle), null);
  }
}

const _signedIn = AccountProfile(
  signedIn: true,
  userId: 'u-account',
  email: 'eyad@example.com',
  emailConfirmed: true,
  google: true,
);

Widget _host(
  Widget child, {
  bool accounts = true,
  AccountProfile profile = AccountProfile.guest,
  required _FakeAuth auth,
  _FakeDirectory Function(Ref ref)? directory,
}) => ProviderScope(
  overrides: [
    accountsAvailableProvider.overrideWithValue(accounts),
    accountAuthProvider.overrideWithValue(auth),
    accountProfileProvider.overrideWith((ref) => Stream.value(profile)),
    if (directory != null) directoryApiProvider.overrideWith(directory),
  ],
  child: localizedApp(child),
);

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _phone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the account comes first: Google, email, and a visible guest', (
    tester,
  ) async {
    await _phone(tester);
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const FirstRunScreen(), auth: auth));
    await passIntro(tester);
    expect(find.byKey(FirstRunScreen.googleKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.emailKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.guestKey), findsOneWidget);
    expect(find.text(arStrings.firstRunGuestPlain), findsOneWidget);
    expect(find.text(arStrings.firstRunAccountNote), findsOneWidget);
    expect(find.bySemanticsLabel(arStrings.arrivalStep(1, 3)), findsOneWidget);

    // Guest keeps the anonymous session: the profile is saved, nothing signed.
    await _tap(tester, FirstRunScreen.guestKey);
    await answerKind(tester);
    await typeName(tester, 'Eyad');
    expect(find.byKey(FirstRunScreen.handleKey), findsNothing);
    await _tap(tester, FirstRunScreen.continueKey);
    expect(auth.calls, isEmpty, reason: 'nothing was signed in or linked');
    expect((await ProfileStore().load())!.name, 'Eyad');
    expect((await TermsStore().load())!.adult, isTrue);
  });

  testWidgets('email: opens the account sheet', (tester) async {
    await _phone(tester);
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const FirstRunScreen(), auth: auth));
    await passIntro(tester);
    await _tap(tester, FirstRunScreen.emailKey);
    expect(find.byKey(AccountSheet.googleKey), findsOneWidget);
    expect(find.byKey(AccountSheet.createKey), findsOneWidget);
    await tester.tap(find.byKey(AccountSheet.googleKey));
    await tester.pumpAndSettle();
    // First run links too: the anonymous user id must stay the same.
    expect(auth.calls, ['google']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google: one tap starts the link', (tester) async {
    await _phone(tester);
    final auth = _FakeAuth();
    await tester.pumpWidget(_host(const FirstRunScreen(), auth: auth));
    await passIntro(tester);
    await _tap(tester, FirstRunScreen.googleKey);
    expect(auth.calls, ['google']);
  });

  testWidgets('an account with a name is welcomed back and never asked', (
    tester,
  ) async {
    await _phone(tester);
    late _FakeDirectory directory;
    await tester.pumpWidget(
      _host(
        const FirstRunScreen(),
        auth: _FakeAuth(),
        profile: _signedIn,
        directory: (ref) => directory = _FakeDirectory(
          ref,
          entry: const DirectoryMe(
            handle: 'ahmed_mafia',
            name: 'أحمد',
            gender: PlayerGender.male,
          ),
        ),
      ),
    );
    // Signed in already: the account step goes on by itself.
    await passIntro(tester);
    expect(find.byKey(FirstRunScreen.welcomeKey), findsOneWidget);
    expect(find.text(arStrings.firstRunWelcomeBack('أحمد')), findsOneWidget);
    expect(find.text('@ahmed_mafia'), findsOneWidget);
    expect(find.byKey(FirstRunScreen.boyKey), findsNothing);
    expect(find.byKey(FirstRunScreen.nameKey), findsNothing);

    // The box is still the player's own answer.
    await _tap(tester, FirstRunScreen.agreeKey);
    await _tap(tester, FirstRunScreen.playKey);
    final saved = (await ProfileStore().load())!;
    expect(saved.name, 'أحمد', reason: 'the account name wins');
    expect(saved.gender, PlayerGender.male);
    expect(directory.calls, ['me'], reason: 'nothing published over it');
  });

  testWidgets('a new account picks a name and a username together', (
    tester,
  ) async {
    await _phone(tester);
    // The coarse country comes from the phone's time zone.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('mafia_master/device'),
      (_) async => 'Africa/Cairo',
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('mafia_master/device'),
        null,
      ),
    );
    late _FakeDirectory directory;
    await tester.pumpWidget(
      _host(
        const FirstRunScreen(),
        auth: _FakeAuth(),
        profile: _signedIn,
        directory: (ref) => directory = _FakeDirectory(ref, taken: 'Mona'),
      ),
    );
    // Signed in already: the account step goes on by itself.
    await passIntro(tester);
    await answerKind(tester, boy: false);
    await typeName(tester, 'Mona');
    final handle = find.byKey(FirstRunScreen.handleKey);
    expect(handle, findsOneWidget);
    expect(tester.widget<TextField>(handle).controller!.text, 'Mona');

    // Taken: said here, and the player stays on the card.
    await _tap(tester, FirstRunScreen.continueKey);
    expect(find.text(arStrings.firstRunHandleTaken), findsOneWidget);
    expect(await ProfileStore().load(), isNull);

    await tester.enterText(handle, 'mona_22');
    await tester.pumpAndSettle();
    await _tap(tester, FirstRunScreen.continueKey);
    expect(directory.calls, [
      'me',
      'hello:Mona',
      'setHandle:Mona',
      'hello:Mona',
      'setHandle:mona_22',
    ]);
    expect((await ProfileStore().load())!.name, 'Mona');
  });

  testWidgets('a build with no server: two steps and no account step', (
    tester,
  ) async {
    await _phone(tester);
    await tester.pumpWidget(
      _host(const FirstRunScreen(), accounts: false, auth: _FakeAuth()),
    );
    await passIntro(tester);
    expect(find.byKey(FirstRunScreen.googleKey), findsNothing);
    await answerKind(tester);
    expect(find.bySemanticsLabel(arStrings.arrivalStep(2, 2)), findsOneWidget);
    expect(find.byKey(FirstRunScreen.nextKey), findsNothing);
    expect(find.byKey(FirstRunScreen.continueKey), findsOneWidget);
  });

  testWidgets('later: a guest links an account from the profile card', (
    tester,
  ) async {
    await _phone(tester);
    final auth = _FakeAuth();
    await tester.pumpWidget(
      _host(const Scaffold(body: AccountCard()), auth: auth),
    );
    await tester.pumpAndSettle();
    expect(find.text(arStrings.authAccount), findsOneWidget);
    expect(find.text(arStrings.authGuestBadge), findsOneWidget);
    await tester.tap(find.byKey(AccountCard.cardKey));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(AccountSheet.googleKey), findsOneWidget);
    await tester.tap(find.byKey(AccountSheet.googleKey));
    await tester.pumpAndSettle();
    expect(auth.calls, ['google']);
  });

  testWidgets('the profile card stays away when the build has no accounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Scaffold(body: AccountCard()),
        accounts: false,
        auth: _FakeAuth(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(AccountCard.cardKey), findsNothing);
  });
}
