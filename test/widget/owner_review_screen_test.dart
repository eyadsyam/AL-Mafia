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
    'feedback': {
      'items': [
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'kind': 'idea',
          'body': 'More scenes please',
          'status': 'new',
          'displayName': 'Mona',
          'createdAt': '2026-10-30',
          'appBuild': 18,
        },
      ],
    },
    'feedbackMark': {
      'id': '11111111-1111-1111-1111-111111111111',
      'status': 'read',
    },
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
    'usage': {
      'items': [
        {
          'day': '2026-10-30',
          'newAccounts': 3,
          'onlinePlayers': 9,
          'onlineMatches': 2,
          'adsAsked': 5,
          'adsPaid': 4,
          'events': {'match_local_finished/p7_9': 6},
        },
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
      ('feedback', 'More scenes please'),
      ('players', 'Mona'),
      ('rooms', 'ABCDEF'),
      ('store', 'frame_gilded'),
      ('config', 'min_build_web'),
      ('push', 'night'),
      ('testers', 'Nour'),
      ('usage', '2026-10-30'),
    ]) {
      await tester.tap(find.byKey(OwnerReviewScreen.tab(action)));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsWidgets);
    }
  });

  testWidgets('feedback page marks a suggestion', (tester) async {
    final server = backend()
      ..responders['owner_review'] = (body) => answers[body['action']]!;
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OwnerReviewScreen.tab('feedback')));
    await tester.pumpAndSettle();
    expect(find.text('More scenes please'), findsOneWidget);
    await tester.tap(find.text(arStrings.feedbackFilterRead).last);
    await tester.pumpAndSettle();
    expect(server.calls.last.body['action'], 'feedbackMark');
    expect(server.calls.last.body['status'], 'read');
    expect(find.text(arStrings.feedbackFilterRead), findsNWidgets(3));
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

  testWidgets('usage page shows the ad pay rate and device counts', (tester) async {
    final server = backend()
      ..responders['owner_review'] = (body) => answers[body['action']]!;
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OwnerReviewScreen.tab('usage')));
    await tester.pumpAndSettle();
    expect(server.calls.last.body['action'], 'usage');
    expect(find.textContaining(arStrings.adminUsageAds(4, 5)), findsOneWidget);
    expect(find.textContaining('match_local_finished/p7_9 6'), findsOneWidget);
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
        'feedback',
        'players',
        'rooms',
        'store',
        'config',
        'push',
        'testers',
        'usage',
      ]) {
        await tester.tap(find.byKey(OwnerReviewScreen.tab(action)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
