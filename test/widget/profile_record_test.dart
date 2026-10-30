import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/online_match_history.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/ui/account/profile_panels.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

/// The profile's record (owner, 2026-10-30: «نظام البروفايل ضعيف»): only what
/// this device really kept, never a guess for an old row.
void main() {
  Map<String, dynamic> row(String role, bool won) => {
    'roomId': 'r$role$won',
    'names': const ['a'],
    'winner': 'town',
    'days': 2,
    'role': role,
    'won': won,
  };

  test('wins are split by side and the most played role is named', () {
    final record = ProfileRecord.from([
      row('mafia', true),
      row('doctor', false),
      row('doctor', true),
      row('citizen', true),
      {'roomId': 'old', 'names': const [], 'winner': 'town', 'days': 1},
    ]);
    expect(record.played, 4);
    expect(record.won, 3);
    expect((record.townWon, record.townPlayed), (2, 3));
    expect((record.mafiaWon, record.mafiaPlayed), (1, 1));
    expect(record.favourite, Role.doctor);
    expect(record.recent, [true, false, true, true]);
  });

  test('a row with an unknown role or no result is skipped', () {
    final record = ProfileRecord.from([
      {...row('mafia', true), 'role': 'wizard'},
      {...row('mafia', true), 'won': 'yes'},
    ]);
    expect(record.played, 0);
    expect(record.favourite, isNull);
  });

  test('history keeps the own role and result from now on', () async {
    SharedPreferences.setMockInitialValues({});
    await OnlineMatchHistory.save(
      roomId: 'room-1',
      names: const ['a', 'b'],
      winner: 'mafia',
      days: 3,
      role: 'silencer',
      won: true,
    );
    await OnlineMatchHistory.save(
      roomId: 'room-2',
      names: const ['a'],
      winner: 'town',
      days: 1,
    );
    final rows = await OnlineMatchHistory.load();
    expect(rows.last['role'], 'silencer');
    expect(rows.last['won'], isTrue);
    expect(rows.first.containsKey('role'), isFalse);
  });

  Future<void> pump(WidgetTester tester, ProfileRecord record) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRecordProvider.overrideWith((ref) async => record)],
        child: localizedApp(
          const Scaffold(
            body: SingleChildScrollView(child: ProfileRecordPanel()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the panel shows the record and one dot per result', (
    tester,
  ) async {
    await pump(
      tester,
      ProfileRecord.from([row('mafia', true), row('detective', false)]),
    );
    expect(find.byKey(ProfileRecordPanel.recordKey), findsOneWidget);
    expect(find.text(arStrings.profileRecordOnline(1, 2)), findsOneWidget);
    expect(find.byKey(ProfileRecordPanel.resultKey(0)), findsOneWidget);
    expect(find.byKey(ProfileRecordPanel.resultKey(1)), findsOneWidget);
    expect(find.byKey(ProfileRecordPanel.resultKey(2)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing real to show draws nothing', (tester) async {
    await pump(tester, ProfileRecord.empty);
    expect(find.byKey(ProfileRecordPanel.recordKey), findsNothing);
    expect(find.byKey(ProfileRecordPanel.levelKey), findsNothing);
  });

  testWidgets('a long record fits a narrow phone', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await pump(
      tester,
      ProfileRecord.from([
        for (var i = 0; i < 12; i++)
          row(i.isEven ? 'mafia' : 'citizen', i % 3 == 0),
      ]),
    );
    expect(find.byKey(ProfileRecordPanel.resultKey(7)), findsOneWidget);
    expect(find.byKey(ProfileRecordPanel.resultKey(8)), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
