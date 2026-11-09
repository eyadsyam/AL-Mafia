import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/tilt_source.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/guest_save_card.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

const _account = AccountProfile(
  signedIn: true,
  userId: 'u1',
  email: 'salma@example.com',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<StreamController<AccountProfile>> home(
    WidgetTester tester, {
    AccountProfile profile = AccountProfile.guest,
    bool accounts = true,
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stream = StreamController<AccountProfile>();
    addTearDown(() {
      // Not awaited: a stream nobody listened to never reports closed.
      unawaited(stream.close());
    });
    stream.add(profile);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          audioDirectorProvider.overrideWithValue(AudioDirector()),
          accountsAvailableProvider.overrideWithValue(accounts),
          accountProfileProvider.overrideWith((ref) => stream.stream),
        ],
        child: localizedApp(
          HomeScreen(
            onNewMatch: () {},
            onHistory: () {},
            onSettings: () {},
            onHowToPlay: () {},
            tiltSource: const LevelTiltSource(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return stream;
  }

  testWidgets('a guest sees the card with its copy and the status line', (
    tester,
  ) async {
    await home(tester);
    expect(find.byKey(GuestSaveCard.cardKey), findsOneWidget);
    expect(find.text(arStrings.guestCardTitle), findsOneWidget);
    expect(find.text(arStrings.guestCardLine), findsOneWidget);
    expect(find.text(arStrings.accountSaveGoogle), findsOneWidget);
    expect(find.text(arStrings.accountSaveEmail), findsOneWidget);
    expect(find.byTooltip(arStrings.guestCardClose), findsOneWidget);
    expect(find.text(arStrings.guestStatusLine), findsOneWidget);
  });

  testWidgets('a signed-in player sees neither the card nor the status', (
    tester,
  ) async {
    await home(tester, profile: _account);
    expect(find.byKey(GuestSaveCard.cardKey), findsNothing);
    expect(find.byKey(GuestStatusLine.lineKey), findsNothing);
  });

  testWidgets('a build without accounts never shows it', (tester) async {
    await home(tester, accounts: false);
    expect(find.byKey(GuestSaveCard.cardKey), findsNothing);
    expect(find.byKey(GuestStatusLine.lineKey), findsNothing);
  });

  testWidgets('signing in removes the card', (tester) async {
    final stream = await home(tester);
    expect(find.byKey(GuestSaveCard.cardKey), findsOneWidget);
    stream.add(_account);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(GuestSaveCard.cardKey), findsNothing);
  });

  testWidgets('closing hides it and it returns after 3 finished matches', (
    tester,
  ) async {
    await home(tester);
    await tester.tap(find.byKey(GuestSaveCard.closeKey));
    await tester.pump();
    expect(find.byKey(GuestSaveCard.cardKey), findsNothing);

    // Reopened Home: still hidden, and after two matches too.
    await home(tester);
    expect(find.byKey(GuestSaveCard.cardKey), findsNothing);
    await GuestNudge.matchFinished();
    await GuestNudge.matchFinished();
    await home(tester);
    expect(find.byKey(GuestSaveCard.cardKey), findsNothing);

    // The third match brings it back.
    await GuestNudge.matchFinished();
    await home(tester);
    expect(find.byKey(GuestSaveCard.cardKey), findsOneWidget);
  });

  testWidgets('once signed in it never comes back, even as a guest again', (
    tester,
  ) async {
    final stream = await home(tester, profile: _account);
    stream.add(AccountProfile.guest);
    await tester.pump();
    await home(tester);
    expect(find.byKey(GuestSaveCard.cardKey), findsNothing);
  });

  for (final size in const [
    Size(360, 640),
    Size(390, 844),
    Size(640, 360),
    Size(1440, 900),
  ]) {
    testWidgets('no overflow with the card at $size', (tester) async {
      await home(tester, size: size);
      expect(find.byKey(GuestSaveCard.cardKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
