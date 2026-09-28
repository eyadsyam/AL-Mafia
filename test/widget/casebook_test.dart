import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/missions/casebook_data.dart';
import 'package:mafia_master/ui/missions/casebook_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/casebook_fixture.dart';
import '../support/localized.dart';

void main() {
  late FakeCasebookController fake;

  Future<void> pump(
    WidgetTester tester, {
    Widget child = const Scaffold(body: CasebookSheet()),
    Locale locale = const Locale('ar'),
    Map<String, dynamic>? json,
  }) async {
    SharedPreferences.setMockInitialValues({});
    fake = FakeCasebookController(json);
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [casebookProvider.overrideWith(() => fake)],
        child: localizedApp(child, locale: locale),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('the hub parses the contract and counts what is ready', () {
    final book = Casebook.fromJson(casebookJson());
    expect(book.enabled, isTrue);
    expect(book.daily.missions, hasLength(3));
    expect(book.daily.missions[1].voice.name, 'detective');
    expect(book.season.level, 6);
    expect(book.season.levelXp, 130);
    expect(book.season.stop(5).claimable, isTrue);
    // One daily, one season stop, one achievement.
    expect(book.ready, 3);
    expect(Casebook.fromJson(casebookJson(enabled: false)).enabled, isFalse);
    expect(Casebook.fromJson(const {'enabled': true, 'daily': 7}).daily.missions,
        isEmpty);
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('tonight: a ready case is taken with one tap (${locale.languageCode})',
        (tester) async {
      await pump(tester, locale: locale);
      expect(find.byKey(CasebookSheet.tonightKey), findsOneWidget);
      await tester.tap(find.byKey(CasebookSheet.claimKey('d1')));
      await tester.pumpAndSettle();
      expect(fake.claims, ['daily:1']);
      // Nothing to take on a case still open or already closed.
      expect(find.byKey(CasebookSheet.claimKey('d2')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('season and legacy pages lay out at 360 (${locale.languageCode})',
        (tester) async {
      await pump(tester, locale: locale);
      final l = locale.languageCode == 'ar' ? arStrings : enStrings;
      await tester.tap(find.text(l.casebookSeason));
      await tester.pumpAndSettle();
      expect(find.byKey(CasebookSheet.seasonKey), findsOneWidget);
      await tester.ensureVisible(find.byKey(CasebookSheet.claimKey('s5')));
      await tester.tap(find.byKey(CasebookSheet.claimKey('s5')));
      await tester.pumpAndSettle();
      expect(fake.claims, ['season:5']);

      await tester.tap(find.text(l.casebookLegacy));
      await tester.pumpAndSettle();
      expect(find.byKey(CasebookSheet.legacyKey), findsOneWidget);
      await tester.tap(find.byKey(CasebookSheet.claimKey('afirst_win')));
      await tester.pumpAndSettle();
      expect(fake.claims.last, 'achievement:first_win');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the entry is absent while the feature is off', (tester) async {
    await pump(
      tester,
      child: const Scaffold(body: CasebookEntry()),
      json: casebookJson(enabled: false),
    );
    expect(find.byKey(CasebookEntry.entryKey), findsNothing);
  });

  testWidgets('the entry shows what is ready and opens the sheet', (tester) async {
    await pump(tester, child: const Scaffold(body: CasebookEntry()));
    expect(find.text(arStrings.casebookReady(3)), findsOneWidget);
    await tester.tap(find.byKey(CasebookEntry.entryKey));
    await tester.pumpAndSettle();
    expect(find.byType(CasebookSheet), findsOneWidget);
  });
}
