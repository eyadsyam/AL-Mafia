import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/remembered_accounts.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

class _Auth extends AccountAuth {
  _Auth() : super(() => throw UnimplementedError(), ensureSession: () async {});
  String? failure;
  String? hint;

  @override
  Future<void> googleSignInForAccount(String email) async {
    hint = email;
    if (failure != null) throw AccountFailure(failure!);
  }

  @override
  Future<void> google() async {
    if (failure != null) throw AccountFailure(failure!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;

  Future<void> pump(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    await RememberedAccounts().add(
      RememberedAccount(
        userId: 'u1',
        email: 'alice@example.com',
        displayName: 'Alice',
        provider: 'email',
        lastUsedAt: DateTime.utc(2026),
      ),
    );
    await RememberedAccounts().add(
      RememberedAccount(
        userId: 'u2',
        email: 'bob@example.com',
        displayName: 'Bob',
        provider: 'google',
        lastUsedAt: DateTime.utc(2026, 2),
      ),
    );
    auth = _Auth();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountAuthProvider.overrideWithValue(auth),
          accountProfileProvider.overrideWith(
            (ref) => Stream.value(AccountProfile.guest),
          ),
        ],
        child: localizedApp(const Scaffold(body: AccountSheet())),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(320, 568), Size(390, 844)]) {
    testWidgets('cards fit and email account focuses password at $size', (
      tester,
    ) async {
      await pump(tester, size);
      expect(find.text('a***@example.com'), findsOneWidget);
      expect(find.text('b***@example.com'), findsOneWidget);
      expect(find.text('alice@example.com'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(AccountSheet.rememberedCardKey('u1')),
      );
      await tester.tap(find.byKey(AccountSheet.rememberedCardKey('u1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(AccountSheet.emailKey))
            .controller!
            .text,
        'alice@example.com',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(AccountSheet.passwordKey))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('remove affects the device list', (tester) async {
    await pump(tester, const Size(390, 844));
    await tester.ensureVisible(
      find.byKey(AccountSheet.removeRememberedKey('u1')),
    );
    await tester.tap(find.byKey(AccountSheet.removeRememberedKey('u1')));
    await tester.pumpAndSettle();
    expect(find.text('a***@example.com'), findsNothing);
    expect((await RememberedAccounts().load()).map((a) => a.userId), ['u2']);
  });

  for (final failure in ['CANCELLED', 'UNAVAILABLE']) {
    testWidgets('Google clears busy after $failure', (tester) async {
      await pump(tester, const Size(390, 844));
      auth.failure = failure;
      await tester.ensureVisible(
        find.byKey(AccountSheet.rememberedCardKey('u2')),
      );
      await tester.tap(find.byKey(AccountSheet.rememberedCardKey('u2')));
      await tester.pumpAndSettle();
      expect(auth.hint, 'bob@example.com');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(AccountSheet.rememberedCardKey('u2')), findsOneWidget);
      expect(
        find.byKey(AccountSheet.errorKey),
        failure == 'CANCELLED' ? findsNothing : findsOneWidget,
      );
    });
    testWidgets('main Google button clears busy after $failure', (
      tester,
    ) async {
      await pump(tester, const Size(390, 844));
      auth.failure = failure;
      await tester.ensureVisible(find.byKey(AccountSheet.googleKey));
      await tester.tap(find.byKey(AccountSheet.googleKey));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(AccountSheet.googleKey), findsOneWidget);
      expect(
        find.byKey(AccountSheet.errorKey),
        failure == 'CANCELLED' ? findsNothing : findsOneWidget,
      );
    });
  }
}
