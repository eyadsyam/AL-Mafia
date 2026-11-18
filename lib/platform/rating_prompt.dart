import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/theme/design_tokens.dart';
import 'review_prompt.dart';

/// What this device remembers about «إيه رأيك في اللعبة؟»: matches finished,
/// times the sheet was shown and closed, whether a rating was sent, and the
/// last day it was on screen (the Play review prompt stays away that day).
@immutable
class RatingPromptState {
  final int finished;
  final int shown;
  final bool done;
  final DateTime? shownDay;

  const RatingPromptState({
    this.finished = 0,
    this.shown = 0,
    this.done = false,
    this.shownDay,
  });

  RatingPromptState copyWith({
    int? finished,
    int? shown,
    bool? done,
    DateTime? shownDay,
  }) => RatingPromptState(
    finished: finished ?? this.finished,
    shown: shown ?? this.shown,
    done: done ?? this.done,
    shownDay: shownDay ?? this.shownDay,
  );

  /// The second finished match shows it once; if it was closed, the fifth
  /// shows it one last time; a sent rating ends it for good.
  bool get due =>
      !done &&
      ((finished >= FeedbackSheetTokens.firstAtFinished && shown == 0) ||
          (finished >= FeedbackSheetTokens.secondAtFinished && shown == 1));
}

abstract interface class RatingPromptStore {
  Future<RatingPromptState> load();
  Future<void> save(RatingPromptState state);
}

class SharedPreferencesRatingPromptStore implements RatingPromptStore {
  static const finishedKey = 'rating_finished_v1';
  static const shownKey = 'rating_shown_v1';
  static const doneKey = 'rating_done_v1';
  static const dayKey = 'rating_shown_day_ms_v1';

  @override
  Future<RatingPromptState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final day = prefs.getInt(dayKey);
    return RatingPromptState(
      finished: prefs.getInt(finishedKey) ?? 0,
      shown: prefs.getInt(shownKey) ?? 0,
      done: prefs.getBool(doneKey) ?? false,
      shownDay: day == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(day, isUtc: true),
    );
  }

  @override
  Future<void> save(RatingPromptState state) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(finishedKey, state.finished),
      prefs.setInt(shownKey, state.shown),
      prefs.setBool(doneKey, state.done),
      if (state.shownDay != null)
        prefs.setInt(dayKey, state.shownDay!.millisecondsSinceEpoch),
    ]);
  }
}

bool _sameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Decides when the rating sheet shows. Never load-bearing: every failure
/// reads as "not now".
class RatingPrompt {
  final RatingPromptStore _store;
  final ReviewStateStore _reviewStore;
  final DateTime Function() _now;

  RatingPrompt({
    required RatingPromptStore store,
    required ReviewStateStore reviewStore,
    DateTime Function()? now,
  }) : _store = store,
       _reviewStore = reviewStore,
       _now = now ?? (() => DateTime.now().toUtc());

  /// A one-phone or online match reached its result screen.
  Future<void> noteFinishedMatch() async {
    try {
      final before = await _store.load();
      await _store.save(before.copyWith(finished: before.finished + 1));
    } catch (_) {}
  }

  /// True when the sheet should open now. Not on a day the Play review prompt
  /// was asked.
  Future<bool> shouldShow() async {
    try {
      final state = await _store.load();
      if (!state.due) return false;
      final asked = (await _reviewStore.load()).lastAsked;
      if (asked != null && _sameLocalDay(asked, _now())) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The sheet is on screen: the review prompt skips today.
  Future<void> markShownToday() async {
    try {
      final state = await _store.load();
      await _store.save(state.copyWith(shownDay: _now()));
    } catch (_) {}
  }

  /// «مش دلوقتي», or the sheet was dismissed.
  Future<void> dismissed() async {
    try {
      final state = await _store.load();
      await _store.save(state.copyWith(shown: state.shown + 1));
    } catch (_) {}
  }

  /// A rating was sent: never again.
  Future<void> sent() async {
    try {
      final state = await _store.load();
      await _store.save(state.copyWith(done: true));
    } catch (_) {}
  }

  /// The last day the sheet was shown, for the review prompt.
  Future<DateTime?> shownDay() async {
    try {
      return (await _store.load()).shownDay;
    } catch (_) {
      return null;
    }
  }
}

final ratingPromptStoreProvider = Provider<RatingPromptStore>(
  (ref) => SharedPreferencesRatingPromptStore(),
);

final ratingPromptProvider = Provider<RatingPrompt>(
  (ref) => RatingPrompt(
    store: ref.watch(ratingPromptStoreProvider),
    reviewStore: SharedPreferencesReviewStateStore(),
  ),
);
