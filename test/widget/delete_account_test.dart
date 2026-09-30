import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/platform/links/external_link.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/account/account_footer.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/delete_account_sheet.dart';
import 'package:mafia_master/ui/friendly_error.dart';
import 'package:mafia_master/ui/widgets/legal_documents.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

class _Auth extends AccountAuth {
  _Auth() : super(() => throw UnimplementedError(), ensureSession: () async {});
}

Future<void> _pumpAccountSheet(
  WidgetTester tester, {
  required DeleteAccountAction action,
  ExternalLinkOpener? opener,
  AccountProfile profile = AccountProfile.guest,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountAuthProvider.overrideWithValue(_Auth()),
        accountProfileProvider.overrideWith((ref) => Stream.value(profile)),
        deleteAccountActionProvider.overrideWithValue(action),
        if (opener != null)
          externalLinkOpenerProvider.overrideWithValue(opener),
      ],
      child: localizedApp(const Scaffold(body: AccountSheet())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDelete(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(AccountFooter.deleteKey));
  await tester.tap(find.byKey(AccountFooter.deleteKey));
  await tester.pumpAndSettle();
}

Future<void> _tick(WidgetTester tester) async {
  await tester.tap(find.byKey(DeleteAccountSheet.confirmKey));
  await tester.pump();
}

bool _enabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(DeleteAccountSheet.actionKey))
        .onPressed !=
    null;

void main() {
  testWidgets('the account sheet reaches terms, privacy and deletion', (
    tester,
  ) async {
    await _pumpAccountSheet(tester, action: () async {});
    await tester.ensureVisible(find.byKey(LegalDocuments.termsButtonKey));
    expect(find.byKey(LegalDocuments.termsButtonKey), findsOneWidget);
    expect(find.byKey(LegalDocuments.privacyButtonKey), findsOneWidget);
    await tester.tap(find.byKey(LegalDocuments.privacyButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LegalDocuments.privacySheetKey), findsOneWidget);
  });

  testWidgets('deleting needs the box ticked, and cancel deletes nothing', (
    tester,
  ) async {
    var calls = 0;
    await _pumpAccountSheet(tester, action: () async => calls++);
    await _openDelete(tester);
    expect(find.text(arStrings.deleteAccountTitle), findsOneWidget);
    expect(_enabled(tester), isFalse, reason: 'nothing is prechecked');
    await _tick(tester);
    expect(_enabled(tester), isTrue);
    await tester.tap(find.byKey(DeleteAccountSheet.cancelKey));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byKey(DeleteAccountSheet.actionKey), findsNothing);
  });

  testWidgets('a confirmed deletion runs once and says it is done', (
    tester,
  ) async {
    var calls = 0;
    await _pumpAccountSheet(
      tester,
      action: () async => calls++,
      profile: const AccountProfile(
        signedIn: true,
        email: 'eyad@example.com',
        emailConfirmed: true,
        password: true,
      ),
    );
    await _openDelete(tester);
    await _tick(tester);
    await tester.tap(find.byKey(DeleteAccountSheet.actionKey));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byKey(DeleteAccountSheet.doneKey), findsOneWidget);
    expect(find.text(arStrings.deleteAccountDone), findsOneWidget);
  });

  testWidgets('a room or an open payment refuses in plain Arabic', (
    tester,
  ) async {
    await _pumpAccountSheet(
      tester,
      action: () async => throw const BackendException('IN_MATCH', 'x'),
    );
    await _openDelete(tester);
    await _tick(tester);
    await tester.tap(find.byKey(DeleteAccountSheet.actionKey));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.deleteAccountInRoom), findsOneWidget);
    expect(find.byKey(DeleteAccountSheet.doneKey), findsNothing);
    expect(find.textContaining('IN_MATCH'), findsNothing);
  });

  testWidgets('no network: the offline sentence, never the exception', (
    tester,
  ) async {
    await _pumpAccountSheet(
      tester,
      action: () async => throw const BackendUnreachable('socket closed'),
    );
    await _openDelete(tester);
    await _tick(tester);
    await tester.tap(find.byKey(DeleteAccountSheet.actionKey));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.errOffline), findsOneWidget);
    expect(find.textContaining('socket'), findsNothing);
    // And the button is live again for a retry.
    expect(_enabled(tester), isTrue);
  });

  testWidgets('the website page is offered, opened where a browser exists', (
    tester,
  ) async {
    final opened = <String>[];
    await _pumpAccountSheet(
      tester,
      action: () async {},
      opener: (url) {
        opened.add(url);
        return true;
      },
    );
    await _openDelete(tester);
    await tester.ensureVisible(find.byKey(DeleteAccountSheet.webKey));
    await tester.tap(find.byKey(DeleteAccountSheet.webKey));
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(opened.single, endsWith('/delete-data/'));
  });

  group('friendly errors', () {
    final codes = RegExp(r'\|\s*"([A-Z_]+)"')
        .allMatches(
          File('supabase/functions/_shared/api.ts')
              .readAsStringSync()
              .split('export type ErrorCode =')
              .last
              .split(';')
              .first,
        )
        .map((m) => m.group(1)!)
        .toList();

    test('the server codes were found', () {
      expect(codes.length, greaterThan(40));
      expect(codes, contains('RATE_LIMITED'));
    });

    for (final locale in const [Locale('ar'), Locale('en')]) {
      test('every server code is a sentence in ${locale.languageCode}', () {
        final l = lookupAppLocalizations(locale);
        for (final code in [...codes, 'UNREACHABLE', 'BAD_RESPONSE', 'NOPE']) {
          final text = friendlyCode(l, code);
          expect(text.trim(), isNotEmpty, reason: code);
          expect(
            text,
            isNot(contains(RegExp(r'[A-Z]{3,}_[A-Z]+'))),
            reason: code,
          );
          if (locale.languageCode == 'ar') {
            expect(text, contains(RegExp(r'[؀-ۿ]')), reason: code);
          }
        }
      });
    }

    test('whatever is thrown becomes a sentence', () {
      final l = arStrings;
      expect(friendlyError(l, const BackendUnreachable('boom')), l.errOffline);
      expect(
        friendlyError(l, const BackendException('RATE_LIMITED', 'slow down')),
        l.errRateLimited,
      );
      expect(
        friendlyError(l, const AccountFailure('RATE_LIMITED')),
        l.errRateLimited,
      );
      expect(friendlyError(l, StateError('raw')), l.errGeneric);
      expect(friendlyError(l, null), l.errGeneric);
    });
  });
}
