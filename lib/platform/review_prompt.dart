import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/economy/economy_capabilities.dart';
import '../ui/theme/design_tokens.dart';

@immutable
class ReviewPromptState {
  final int cleanMatches;
  final int solvedCases;
  final DateTime? lastAsked;
  final bool calmHomeSeen;

  const ReviewPromptState({
    this.cleanMatches = 0,
    this.solvedCases = 0,
    this.lastAsked,
    this.calmHomeSeen = false,
  });

  bool get eligible => cleanMatches >= 3 || solvedCases >= 3;

  ReviewPromptState copyWith({
    int? cleanMatches,
    int? solvedCases,
    DateTime? lastAsked,
    bool? calmHomeSeen,
  }) => ReviewPromptState(
    cleanMatches: cleanMatches ?? this.cleanMatches,
    solvedCases: solvedCases ?? this.solvedCases,
    lastAsked: lastAsked ?? this.lastAsked,
    calmHomeSeen: calmHomeSeen ?? this.calmHomeSeen,
  );
}

abstract interface class ReviewStateStore {
  Future<ReviewPromptState> load();
  Future<void> save(ReviewPromptState state);
}

class SharedPreferencesReviewStateStore implements ReviewStateStore {
  static const _cleanKey = 'review_clean_matches_v1';
  static const _casesKey = 'review_solved_cases_v1';
  static const _lastKey = 'review_last_asked_ms_v1';
  static const _calmKey = 'review_calm_home_seen_v1';

  @override
  Future<ReviewPromptState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastKey);
    return ReviewPromptState(
      cleanMatches: prefs.getInt(_cleanKey) ?? 0,
      solvedCases: prefs.getInt(_casesKey) ?? 0,
      lastAsked: last == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(last, isUtc: true),
      calmHomeSeen: prefs.getBool(_calmKey) ?? false,
    );
  }

  @override
  Future<void> save(ReviewPromptState state) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(_cleanKey, state.cleanMatches),
      prefs.setInt(_casesKey, state.solvedCases),
      prefs.setBool(_calmKey, state.calmHomeSeen),
      if (state.lastAsked != null)
        prefs.setInt(_lastKey, state.lastAsked!.millisecondsSinceEpoch),
    ]);
  }
}

abstract interface class ReviewRequester {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

class PlayReviewRequester implements ReviewRequester {
  const PlayReviewRequester();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

class ReviewPrompt {
  final ReviewStateStore _store;
  final ReviewRequester _requester;
  final Future<bool> Function() _enabled;
  final DateTime Function() _now;
  bool _asking = false;

  ReviewPrompt({
    required ReviewStateStore store,
    required ReviewRequester requester,
    required Future<bool> Function() enabled,
    DateTime Function()? now,
  }) : _store = store,
       _requester = requester,
       _enabled = enabled,
       _now = now ?? (() => DateTime.now().toUtc());

  Future<void> noteCleanMatch() => _increment(clean: true);
  Future<void> noteSolvedCase() => _increment(clean: false);

  Future<void> _increment({required bool clean}) async {
    try {
      final before = await _store.load();
      final after = before.copyWith(
        cleanMatches: clean ? before.cleanMatches + 1 : before.cleanMatches,
        solvedCases: clean ? before.solvedCases : before.solvedCases + 1,
        calmHomeSeen: before.eligible ? before.calmHomeSeen : false,
      );
      await _store.save(after);
    } catch (_) {}
  }

  /// Called only from Home. The first calm Home visit after eligibility merely
  /// arms the request; a later visit asks, keeping it away from a loss/reward.
  Future<void> maybeAsk(BuildContext context) async {
    if (!context.mounted) return;
    try {
      await maybeAskIfEnabled(await _enabled());
    } catch (_) {}
  }

  @visibleForTesting
  Future<bool> maybeAskIfEnabled(bool enabled) async {
    if (!enabled || _asking) return false;
    _asking = true;
    try {
      var state = await _store.load();
      if (!state.eligible) return false;
      final last = state.lastAsked;
      if (last != null &&
          _now().difference(last) < MafiaTiming.reviewPromptCooldown) {
        return false;
      }
      if (!state.calmHomeSeen) {
        await _store.save(state.copyWith(calmHomeSeen: true));
        return false;
      }
      if (!await _requester.isAvailable()) return false;
      state = state.copyWith(lastAsked: _now());
      await _store.save(state);
      await _requester.requestReview();
      return true;
    } catch (_) {
      return false;
    } finally {
      _asking = false;
    }
  }
}

final reviewPromptProvider = Provider<ReviewPrompt>((ref) {
  return ReviewPrompt(
    store: SharedPreferencesReviewStateStore(),
    requester: const PlayReviewRequester(),
    // Never fetches: the prompt is a courtesy, so it follows capabilities
    // someone else already loaded rather than starting a request of its own.
    enabled: () async =>
        ref.read(economyCapabilitiesProvider).valueOrNull?.reviewPrompt ??
        false,
  );
});
