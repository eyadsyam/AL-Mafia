import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/feedback/feedback_api.dart';
import 'package:mafia_master/ui/feedback/feedback_sheet.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:mafia_master/ui/widgets/deck/deck_buttons.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

class FakeFeedback implements FeedbackApi {
  Object? failure;
  int calls = 0;
  @override
  Future<void> submit(String kind, String body) async {
    calls++;
    if (failure != null) throw failure!;
  }
}

class _Directory extends DirectoryApi {
  _Directory(super.ref);
  @override
  Future<DirectoryMe> me() async => const DirectoryMe(handle: 'salma_ali');
}

class _Profile extends PlayerProfileController {
  @override
  Future<PlayerProfile?> build() async =>
      const PlayerProfile(name: 'سلمى', gender: PlayerGender.female);
}

const _account = AccountProfile(
  signedIn: true,
  userId: 'u1',
  email: 'salma@example.com',
);

void main() {
  late FakeFeedback api;
  late StreamController<AccountProfile> accounts;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    AccountProfile profile = _account,
  }) async {
    await loadArtwork(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    api = FakeFeedback();
    accounts = StreamController<AccountProfile>();
    addTearDown(accounts.close);
    accounts.add(profile);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedbackApiProvider.overrideWithValue(api),
          accountProfileProvider.overrideWith((ref) => accounts.stream),
          directoryApiProvider.overrideWith(_Directory.new),
          playerProfileProvider.overrideWith(_Profile.new),
        ],
        child: localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFeedbackSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  BoneButton button(WidgetTester tester) =>
      tester.widget(find.byKey(FeedbackSheet.sendKey));

  Future<void> write(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(FeedbackSheet.fieldKey), text);
    await tester.pump();
  }

  testWidgets('a guest sees the sign-in state, not the form', (tester) async {
    await open(tester, profile: AccountProfile.guest);
    expect(find.text(arStrings.feedbackSignInTitle), findsOneWidget);
    expect(find.text(arStrings.feedbackSignInLine), findsOneWidget);
    expect(find.text(arStrings.accountSaveGoogle), findsOneWidget);
    expect(find.text(arStrings.accountSaveEmail), findsOneWidget);
    expect(find.byKey(FeedbackSheet.fieldKey), findsNothing);
    expect(find.byKey(FeedbackSheet.sendKey), findsNothing);
  });

  testWidgets('the form appears in place after sign-in', (tester) async {
    await open(tester, profile: AccountProfile.guest);
    accounts.add(_account);
    await tester.pumpAndSettle();
    expect(find.byKey(FeedbackSheet.fieldKey), findsOneWidget);
    expect(find.text(arStrings.feedbackSignInTitle), findsNothing);
  });

  testWidgets('signed in: name, @handle and the tick, then the form', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('سلمى  @salma_ali'), findsOneWidget);
    expect(find.text(arStrings.feedbackSignedIn), findsOneWidget);
    expect(find.textContaining(arStrings.feedbackStep1), findsWidgets);
    expect(find.byKey(FeedbackSheet.fieldKey), findsOneWidget);
  });

  testWidgets('needs a kind and 3 words and 10 letters; success', (
    tester,
  ) async {
    await open(tester);
    expect(button(tester).onPressed, isNull);
    // Why it is disabled shows under the button.
    expect(find.text(arStrings.feedbackStep1), findsWidgets);
    await tester.tap(find.byKey(FeedbackSheet.kindKey('idea')));
    await write(tester, 'واحد اتنين');
    expect(button(tester).onPressed, isNull);
    expect(find.byKey(FeedbackSheet.hintKey), findsOneWidget);
    // Three words but fewer than ten letters.
    await write(tester, 'أ ب ج د');
    expect(button(tester).onPressed, isNull);
    await write(tester, 'واحد اتنين تلاتة');
    expect(find.text('١٦ / ٥٠٠'), findsOneWidget);
    expect(button(tester).onPressed, isNotNull);
    expect(find.byKey(FeedbackSheet.hintKey), findsNothing);
    await tester.tap(find.byKey(FeedbackSheet.sendKey));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.text(arStrings.feedbackSentTitle), findsOneWidget);
    expect(find.text(arStrings.feedbackDone), findsOneWidget);
  });

  testWidgets('no kind chosen keeps send off even with a full sentence', (
    tester,
  ) async {
    await open(tester);
    await write(tester, 'جملة كاملة من كذا كلمة');
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('rate limit keeps typed text', (tester) async {
    await open(tester);
    api.failure = const BackendException('RATE_LIMITED', 'later');
    await tester.tap(find.byKey(FeedbackSheet.kindKey('problem')));
    await write(tester, 'مشكلة جديدة في اللعبة');
    expect(button(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(FeedbackSheet.sendKey));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.text(arStrings.feedbackRateLimited), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(FeedbackSheet.fieldKey))
          .controller!
          .text,
      'مشكلة جديدة في اللعبة',
    );
  });

  testWidgets('server TOO_SHORT shows the hint and keeps the text', (
    tester,
  ) async {
    await open(tester);
    api.failure = const BackendException('TOO_SHORT', 'short');
    await tester.tap(find.byKey(FeedbackSheet.kindKey('idea')));
    await write(tester, 'كلمة كلمتين تلاتة');
    expect(find.byKey(FeedbackSheet.hintKey), findsNothing);
    await tester.tap(find.byKey(FeedbackSheet.sendKey));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.byKey(FeedbackSheet.hintKey), findsOneWidget);
    expect(find.text(arStrings.feedbackTooShort), findsOneWidget);
    expect(find.text(arStrings.feedbackError), findsNothing);
    expect(find.byKey(FeedbackSheet.fieldKey), findsOneWidget);
  });

  testWidgets('server SIGN_IN_REQUIRED goes back to the sign-in state', (
    tester,
  ) async {
    await open(tester);
    api.failure = const BackendException('SIGN_IN_REQUIRED', 'sign in');
    await tester.tap(find.byKey(FeedbackSheet.kindKey('idea')));
    await write(tester, 'كلمة كلمتين تلاتة');
    await tester.tap(find.byKey(FeedbackSheet.sendKey));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.feedbackSignInTitle), findsOneWidget);
    expect(find.byKey(FeedbackSheet.fieldKey), findsNothing);
    expect(find.text(arStrings.feedbackError), findsNothing);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(640, 360),
  ]) {
    testWidgets('no overflow at $size', (tester) async {
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(FeedbackSheet.fieldKey));
      await tester.tap(find.byKey(FeedbackSheet.fieldKey));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('sign-in state has no overflow at $size', (tester) async {
      await open(tester, size: size, profile: AccountProfile.guest);
      expect(tester.takeException(), isNull);
    });
  }
}
