import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/request_id.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/account_protection.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/screens/admin/safety_admin_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/safety_center.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';

/// F11 — Safety v11 on the client.
void main() {
  group('request ids', () {
    test('are version-4 UUIDs and differ', () {
      final a = newRequestId(Random(1));
      final b = newRequestId(Random(2));
      final shape = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(a, matches(shape));
      expect(b, matches(shape));
      expect(a, isNot(b));
    });
  });

  group('capabilities', () {
    test('safety.v11 is read, and off unless the server says so', () {
      expect(
        EconomyCapabilities.fromJson({
          'version': 3,
          'safety': {'v11': true},
        }).safetyV11,
        isTrue,
      );
      expect(EconomyCapabilities.fromJson({'version': 3}).safetyV11, isFalse);
      expect(EconomyCapabilities.none.safetyV11, isFalse);
    });
  });

  group('report body', () {
    Map<String, Object?> body({
      bool v11 = true,
      int? seat = 2,
      String? category = 'harassment',
      String? status = 'playing',
      String action = 'report',
    }) {
      var minted = 0;
      final out = safetyReportBody(
        action: action,
        v11: v11,
        roomId: 'room',
        roomStatus: status,
        seat: seat,
        category: category,
        details: 'text',
        requestId: () => 'req-${++minted}',
      );
      return out;
    }

    test('a v11 report names the seat, the category and where it was made', () {
      expect(body(), {
        'action': 'report_v11',
        'context': 'match',
        'roomId': 'room',
        'seat': 2,
        'category': 'harassment',
        'details': 'text',
        'requestId': 'req-1',
      });
      expect(body(status: 'lobby')['context'], 'lobby');
      expect(body(status: 'finished')['context'], 'result');
    });

    test('never carries a role, an action or a whisper', () {
      final keys = body().keys.toSet();
      expect(keys, {
        'action',
        'context',
        'roomId',
        'seat',
        'category',
        'details',
        'requestId',
      });
    });

    test('without v11, a category or a seat it is the original report', () {
      for (final b in [
        body(v11: false),
        body(category: null),
        body(seat: null),
      ]) {
        expect(b['action'], 'report');
        expect(b['reason'], 'other');
        expect(b.containsKey('requestId'), isFalse);
      }
      expect(body(action: 'block')['action'], 'block');
    });

    test('the form lists all eight categories', () {
      expect(safetyCategories, [
        'harassment',
        'hate',
        'sexual',
        'threat',
        'spam',
        'cheating',
        'inappropriate_name',
        'other',
      ]);
    });
  });

  group('the owner queue', () {
    const signedIn = AccountStatus(recoverable: true, email: 'o@example.test');

    Widget app(FakeBackend backend, {bool web = true}) => ProviderScope(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        accountStatusProvider.overrideWith((ref) async => signedIn),
      ],
      child: localizedApp(SafetyAdminScreen(web: web)),
    );

    final report = {
      'id': '11111111-1111-4111-8111-111111111111',
      'category': 'harassment',
      'context': 'lobby',
      'status': 'pending',
      'createdAt': '2026-09-28T10:00:00Z',
      'details': 'insults in the lobby',
      'evidence': {
        'context': 'lobby',
        'roomCode': 'SAFEAA',
        'roomTitle': 'قعدة الخميس',
        'targetName': 'Bee',
        'targetSeat': 1,
      },
      'targetId': '22222222-2222-4222-8222-222222222222',
      'targetOpenReports': 1,
      'targetActioned': 0,
      'targetRestrictions': <String>[],
      'note': '',
    };

    testWidgets('outside the web build: a guard, and no server call', (
      tester,
    ) async {
      final backend = FakeBackend(
        roomId: 'r',
        state: roomState(),
        players: roster(2),
      );
      await tester.pumpWidget(app(backend, web: false));
      await tester.pumpAndSettle();
      expect(find.byKey(SafetyAdminScreen.guard), findsOneWidget);
      expect(backend.calls, isEmpty);
    });

    testWidgets('a non-admin sees the guard and no report', (tester) async {
      final backend =
          FakeBackend(roomId: 'r', state: roomState(), players: roster(2))
            ..responders['player_safety'] = (_) => throw const BackendException(
              'NOT_ADMIN',
              'not an administrator',
            );
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      expect(find.byKey(SafetyAdminScreen.guard), findsOneWidget);
      expect(
        find.byKey(SafetyAdminScreen.report(report['id'] as String)),
        findsNothing,
      );
    });

    testWidgets('lists evidence and sends one decision with a request id', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend =
          FakeBackend(roomId: 'r', state: roomState(), players: roster(2))
            ..responses['player_safety'] = {
              'items': [report],
              'next': null,
            };
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      final id = report['id'] as String;
      expect(find.byKey(SafetyAdminScreen.report(id)), findsOneWidget);
      expect(find.textContaining('Bee'), findsOneWidget);
      expect(find.textContaining('SAFEAA'), findsOneWidget);
      expect(find.text('insults in the lobby'), findsOneWidget);

      await tester.tap(find.byKey(SafetyAdminScreen.action(id, 'suspend7')));
      await tester.pumpAndSettle();
      final resolve = backend.calls
          .where((c) => c.body['action'] == 'admin_resolve')
          .single
          .body;
      expect(resolve['reportId'], id);
      expect(resolve['decision'], 'suspend');
      expect(resolve['durationDays'], 7);
      expect(resolve['requestId'], isA<String>());
    });
  });
}
