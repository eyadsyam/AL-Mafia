import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/review_prompt.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

class _Store implements ReviewStateStore {
  ReviewPromptState state;
  _Store([this.state = const ReviewPromptState()]);

  @override
  Future<ReviewPromptState> load() async => state;

  @override
  Future<void> save(ReviewPromptState value) async => state = value;
}

class _Requester implements ReviewRequester {
  bool available = true;
  int asks = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => asks++;
}

void main() {
  final now = DateTime.utc(2026, 9, 28);

  ReviewPrompt prompt(_Store store, _Requester requester) => ReviewPrompt(
    store: store,
    requester: requester,
    enabled: () async => true,
    now: () => now,
  );

  test(
    'third clean match becomes eligible but waits for a later calm Home',
    () async {
      final store = _Store();
      final requester = _Requester();
      final review = prompt(store, requester);
      await review.noteCleanMatch();
      await review.noteCleanMatch();
      expect(await review.maybeAskIfEnabled(true), isFalse);
      await review.noteCleanMatch();
      expect(store.state.eligible, isTrue);

      expect(await review.maybeAskIfEnabled(true), isFalse);
      expect(store.state.calmHomeSeen, isTrue);
      expect(await review.maybeAskIfEnabled(true), isTrue);
      expect(requester.asks, 1);
    },
  );

  test('third solved case independently reaches the same threshold', () async {
    final store = _Store();
    final requester = _Requester();
    final review = prompt(store, requester);
    await review.noteSolvedCase();
    await review.noteSolvedCase();
    await review.noteSolvedCase();
    expect(store.state.cleanMatches, 0);
    expect(store.state.solvedCases, 3);
    expect(await review.maybeAskIfEnabled(true), isFalse);
    expect(await review.maybeAskIfEnabled(true), isTrue);
  });

  test(
    'remote switch, availability, and rolling 90-day limit are enforced',
    () async {
      final requester = _Requester();
      final store = _Store(
        ReviewPromptState(
          cleanMatches: 3,
          calmHomeSeen: true,
          lastAsked: now
              .subtract(MafiaTiming.reviewPromptCooldown)
              .add(const Duration(days: 1)),
        ),
      );
      final review = prompt(store, requester);
      expect(await review.maybeAskIfEnabled(false), isFalse);
      expect(await review.maybeAskIfEnabled(true), isFalse);
      expect(requester.asks, 0);

      store.state = ReviewPromptState(
        solvedCases: 3,
        calmHomeSeen: true,
        lastAsked: now.subtract(MafiaTiming.reviewPromptCooldown),
      );
      requester.available = false;
      expect(await review.maybeAskIfEnabled(true), isFalse);
      requester.available = true;
      expect(await review.maybeAskIfEnabled(true), isTrue);
      expect(requester.asks, 1);
      expect(await review.maybeAskIfEnabled(true), isFalse);
    },
  );
}
