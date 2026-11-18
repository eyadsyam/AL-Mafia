import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/rating_prompt.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/feedback/feedback_api.dart';
import 'package:mafia_master/ui/feedback/rating_sheet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

class _Api implements RatingApi {
  final calls = <(int, String?)>[];
  Object? failure;

  @override
  Future<void> rate(int stars, String? body) async {
    calls.add((stars, body));
    if (failure != null) throw failure!;
  }
}

class _Store implements RatingPromptStore {
  RatingPromptState state = const RatingPromptState(finished: 2);

  @override
  Future<RatingPromptState> load() async => state;

  @override
  Future<void> save(RatingPromptState value) async => state = value;
}

void main() {
  test('the real api posts action rating, the stars and a trimmed body', () async {
    final backend = FakeBackend(roomId: 'r', state: roomState(), players: const []);
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      ],
    );
    addTearDown(container.dispose);
    await container.read(ratingApiProvider).rate(5, '  nice  ');
    await container.read(ratingApiProvider).rate(3, '   ');
    final calls = backend.calls.where((c) => c.function == 'player_feedback');
    expect(calls.length, 2);
    expect(calls.first.body['action'], 'rating');
    expect(calls.first.body['stars'], 5);
    expect(calls.first.body['body'], 'nice');
    expect(calls.first.body['platform'], isIn(['android', 'web', 'ios']));
    expect(calls.last.body.containsKey('body'), isFalse);
  });

  late _Api api;
  late _Store store;

  Future<void> open(WidgetTester tester) async {
    api = _Api();
    store = _Store();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ratingApiProvider.overrideWithValue(api),
          ratingPromptStoreProvider.overrideWithValue(store),
        ],
        child: localizedApp(
          Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showRatingSheet(context, ref),
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

  testWidgets('five stars and «مش دلوقتي» first; no field yet', (tester) async {
    await open(tester);
    expect(find.text(arStrings.ratingTitle), findsOneWidget);
    for (var n = 1; n <= 5; n++) {
      expect(find.byKey(RatingSheet.starKey(n)), findsOneWidget);
      final size = tester.getSize(find.byKey(RatingSheet.starKey(n)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.bySemanticsLabel(arStrings.ratingStars(3)), findsOneWidget);
    expect(find.byKey(RatingSheet.fieldKey), findsNothing);
    expect(find.byKey(RatingSheet.sendKey), findsNothing);
    expect(find.byKey(RatingSheet.notNowKey), findsOneWidget);
    // Left to right: one star furthest left.
    expect(
      tester.getCenter(find.byKey(RatingSheet.starKey(1))).dx,
      lessThan(tester.getCenter(find.byKey(RatingSheet.starKey(5))).dx),
    );
  });

  testWidgets('a star reveals the field; send posts the stars and text', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(RatingSheet.starKey(4)));
    await tester.pumpAndSettle();
    expect(find.byKey(RatingSheet.fieldKey), findsOneWidget);
    expect(find.text(arStrings.ratingHint), findsOneWidget);
    await tester.enterText(find.byKey(RatingSheet.fieldKey), '  حلوة  ');
    await tester.tap(find.byKey(RatingSheet.sendKey));
    await tester.pumpAndSettle();
    expect(api.calls, [(4, '  حلوة  ')]);
    // Closed, thanked once, never asked again.
    expect(find.byKey(RatingSheet.sendKey), findsNothing);
    expect(find.text(arStrings.ratingThanks), findsOneWidget);
    expect(store.state.done, isTrue);
    expect(store.state.shown, 0);
  });

  testWidgets('«مش دلوقتي» closes and counts one closing', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(RatingSheet.notNowKey));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.ratingTitle), findsNothing);
    expect(api.calls, isEmpty);
    expect(store.state.shown, 1);
    expect(store.state.done, isFalse);
    expect(store.state.shownDay, isNotNull);
  });

  testWidgets('a failed send keeps the sheet, says so, and can retry', (
    tester,
  ) async {
    await open(tester);
    api.failure = const BackendException('UNREACHABLE', 'down');
    await tester.tap(find.byKey(RatingSheet.starKey(2)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RatingSheet.sendKey));
    await tester.pumpAndSettle();
    expect(find.byKey(RatingSheet.errorKey), findsOneWidget);
    expect(find.text(arStrings.errOffline), findsOneWidget);
    expect(store.state.done, isFalse);
    api.failure = null;
    await tester.tap(find.byKey(RatingSheet.sendKey));
    await tester.pumpAndSettle();
    expect(api.calls.length, 2);
    expect(store.state.done, isTrue);
  });
}
