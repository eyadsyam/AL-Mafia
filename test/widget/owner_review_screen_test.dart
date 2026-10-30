import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/account_protection.dart';
import 'package:mafia_master/ui/screens/admin/owner_review_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

void main() {
  FakeBackend backend() => FakeBackend(
    roomId: 'room',
    state: RoomState(
      phase: 'lobby',
      phaseNumber: 0,
      status: 'lobby',
      hostId: 'owner',
      code: 'ABCDEF',
      serverNow: DateTime.utc(2026),
    ),
    players: const [],
  );

  Widget app(FakeBackend server) => ProviderScope(
    overrides: [
      onlineBackendFactoryProvider.overrideWithValue(() async => server),
      accountStatusProvider.overrideWith(
        (ref) async =>
            const AccountStatus(recoverable: true, email: 'owner@example.test'),
      ),
    ],
    child: localizedApp(const OwnerReviewScreen(web: true)),
  );

  final answers = <String, Map<String, dynamic>>{
    'overview': {'accountsTotal': 23},
    'players': {
      'items': [
        {
          'displayName': 'Mona',
          'createdAt': 'today',
          'level': 3,
          'allAccess': true,
        },
      ],
    },
    'rooms': {
      'items': [
        {
          'code': 'ABCDEF',
          'status': 'lobby',
          'phase': 'lobby',
          'playerCount': 2,
          'hostName': 'Mona',
        },
      ],
    },
    'store': {
      'items': [
        {
          'code': 'frame_gilded',
          'kind': 'frame',
          'coinPrice': 200,
          'active': true,
          'owners': 4,
        },
      ],
      'grants': [
        {'displayName': 'Mona', 'since': 'today'},
      ],
    },
    'config': {
      'app': {'min_build_web': 18},
      'economy': {'daily_enabled': true},
    },
    'push': {
      'items': [
        {'kind': 'night', 'status': 'sent', 'count': 12},
      ],
    },
    'testers': {
      'items': [
        {'name': 'Nour', 'status': 'new', 'createdAt': 'today'},
      ],
    },
  };

  testWidgets('every page renders its returned data', (tester) async {
    final server = backend()
      ..responders['owner_review'] = (body) => answers[body['action']]!;
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();
    expect(find.text('23'), findsOneWidget);
    for (final (action, expected) in [
      ('players', 'Mona'),
      ('rooms', 'ABCDEF'),
      ('store', 'frame_gilded'),
      ('config', 'min_build_web'),
      ('push', 'night'),
      ('testers', 'Nour'),
    ]) {
      await tester.tap(find.byKey(OwnerReviewScreen.tab(action)));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsWidgets);
    }
  });

  testWidgets('empty state and retry after error', (tester) async {
    final server = backend()..responses['owner_review'] = {'items': []};
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OwnerReviewScreen.tab('rooms')));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.adminReviewEmpty), findsOneWidget);
    server.refusals['owner_review'] = const BackendException(
      'TEMPORARY',
      'try again',
    );
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.byKey(OwnerReviewScreen.retry), findsOneWidget);
    await tester.tap(find.byKey(OwnerReviewScreen.retry));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.adminReviewEmpty), findsOneWidget);
  });

  testWidgets('player search sends query', (tester) async {
    final server = backend()..responses['owner_review'] = {'items': []};
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OwnerReviewScreen.tab('players')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(OwnerReviewScreen.search), 'Mo');
    await tester.pumpAndSettle();
    expect(server.calls.last.body['query'], 'Mo');
  });

  for (final size in [const Size(360, 640), const Size(1280, 800)]) {
    testWidgets('no overflow at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final server = backend()
        ..responders['owner_review'] = (body) => answers[body['action']]!;
      await tester.pumpWidget(app(server));
      await tester.pumpAndSettle();
      for (final action in [
        'players',
        'rooms',
        'store',
        'config',
        'push',
        'testers',
      ]) {
        await tester.tap(find.byKey(OwnerReviewScreen.tab(action)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
