import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/rating_prompt.dart';
import 'package:mafia_master/platform/review_prompt.dart';

class _RatingStore implements RatingPromptStore {
  RatingPromptState state = const RatingPromptState();

  @override
  Future<RatingPromptState> load() async => state;

  @override
  Future<void> save(RatingPromptState value) async => state = value;
}

class _ReviewStore implements ReviewStateStore {
  ReviewPromptState state = const ReviewPromptState();

  @override
  Future<ReviewPromptState> load() async => state;

  @override
  Future<void> save(ReviewPromptState value) async => state = value;
}

class _Requester implements ReviewRequester {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> requestReview() async {}
}

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);
  late _RatingStore store;
  late _ReviewStore reviews;
  late RatingPrompt prompt;

  setUp(() {
    store = _RatingStore();
    reviews = _ReviewStore();
    prompt = RatingPrompt(store: store, reviewStore: reviews, now: () => now);
  });

  Future<void> finish(int matches) async {
    for (var i = 0; i < matches; i++) {
      await prompt.noteFinishedMatch();
    }
  }

  test('the first finished match shows nothing, the second shows it', () async {
    await finish(1);
    expect(await prompt.shouldShow(), isFalse);
    await finish(1);
    expect(await prompt.shouldShow(), isTrue);
  });

  test('closing it counts; the fifth match shows it once more; then never',
      () async {
    await finish(2);
    await prompt.markShownToday();
    await prompt.dismissed();
    expect(store.state.shown, 1);
    expect(await prompt.shouldShow(), isFalse);

    await finish(2);
    expect(store.state.finished, 4);
    expect(await prompt.shouldShow(), isFalse);
    await finish(1);
    expect(await prompt.shouldShow(), isTrue);

    await prompt.dismissed();
    expect(store.state.shown, 2);
    await finish(20);
    expect(await prompt.shouldShow(), isFalse);
  });

  test('a sent rating ends it for good', () async {
    await finish(2);
    await prompt.sent();
    expect(store.state.done, isTrue);
    await finish(10);
    expect(await prompt.shouldShow(), isFalse);
  });

  test('not on a day the Play review prompt was asked', () async {
    await finish(2);
    reviews.state = ReviewPromptState(lastAsked: now);
    expect(await prompt.shouldShow(), isFalse);
    // Another day: fine.
    reviews.state = ReviewPromptState(
      lastAsked: now.subtract(const Duration(days: 2)),
    );
    expect(await prompt.shouldShow(), isTrue);
  });

  test('when the sheet shows, the review prompt skips that day', () async {
    final review = ReviewPrompt(
      store: reviews..state = const ReviewPromptState(cleanMatches: 3),
      requester: _Requester(),
      enabled: () async => true,
      ratingShownOn: prompt.shownDay,
      now: () => now,
    );
    // Armed by a calm Home visit first, so the next one would ask.
    reviews.state = reviews.state.copyWith(calmHomeSeen: true);
    await finish(2);
    await prompt.markShownToday();
    expect(await review.maybeAskIfEnabled(true), isFalse);
    expect(reviews.state.lastAsked, isNull);

    // The next day it asks as before.
    final tomorrow = ReviewPrompt(
      store: reviews,
      requester: _Requester(),
      enabled: () async => true,
      ratingShownOn: prompt.shownDay,
      now: () => now.add(const Duration(days: 1)),
    );
    expect(await tomorrow.maybeAskIfEnabled(true), isTrue);
  });
}
