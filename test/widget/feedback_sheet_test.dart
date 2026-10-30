import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/feedback/feedback_api.dart';
import 'package:mafia_master/ui/feedback/feedback_sheet.dart';

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

void main() {
  late FakeFeedback api;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    await loadArtwork(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    api = FakeFeedback();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedbackApiProvider.overrideWithValue(api)],
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

  testWidgets('instructions, gating, counter and success', (tester) async {
    await open(tester);
    expect(find.textContaining(arStrings.feedbackStep1), findsOneWidget);
    expect(find.textContaining(arStrings.feedbackStep2), findsOneWidget);
    expect(find.textContaining(arStrings.feedbackStep3), findsOneWidget);
    FilledButton button() => tester.widget(find.byKey(FeedbackSheet.sendKey));
    expect(button().onPressed, isNull);
    await tester.tap(find.byKey(FeedbackSheet.kindKey('idea')));
    await tester.enterText(find.byKey(FeedbackSheet.fieldKey), 'واحد');
    await tester.pump();
    expect(button().onPressed, isNull);
    await tester.enterText(find.byKey(FeedbackSheet.fieldKey), 'واحد اتنين');
    await tester.pump();
    expect(find.text('١٠ / ٥٠٠'), findsOneWidget);
    expect(button().onPressed, isNotNull);
    await tester.tap(find.byKey(FeedbackSheet.sendKey));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.text(arStrings.feedbackSentTitle), findsOneWidget);
    expect(find.text(arStrings.feedbackDone), findsOneWidget);
  });

  testWidgets('rate limit keeps typed text', (tester) async {
    await open(tester);
    api.failure = const BackendException('RATE_LIMITED', 'later');
    await tester.tap(find.byKey(FeedbackSheet.kindKey('problem')));
    await tester.enterText(find.byKey(FeedbackSheet.fieldKey), 'مشكلة جديدة');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(FeedbackSheet.sendKey)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(FeedbackSheet.sendKey));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(find.text(arStrings.feedbackRateLimited), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(FeedbackSheet.fieldKey))
          .controller!
          .text,
      'مشكلة جديدة',
    );
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
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
  }
}
