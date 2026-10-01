import '../../ui/theme/design_tokens.dart';

/// When the player last left the game for another full-screen ad or the
/// Play purchase sheet, and when they came back from an ad. The app-open ad
/// never follows such a return (phase 108). In memory: a cold start is
/// decided by its own rules.
abstract final class FullScreenAway {
  /// When the player left (an ad or the purchase sheet).
  static int? lastMs;

  /// When the last full-screen ad was closed.
  static int? returnedMs;

  /// A full-screen ad of ours is on screen right now.
  static bool adShowing = false;

  /// Wall clock; a test replaces it.
  static int Function() clock = () => DateTime.now().millisecondsSinceEpoch;

  static void mark() => lastMs = clock();

  /// A full-screen ad is about to cover the game.
  static void adOpened() {
    mark();
    adShowing = true;
  }

  /// The ad is gone (dismissed, failed, or timed out).
  static void adClosed() {
    adShowing = false;
    returnedMs = clock();
  }

  /// The latest moment the player was away: the return from an ad when there
  /// was one, otherwise the departure. The app-open ad measures its
  /// "just returned" rule from here, so a long ad cannot outlast it.
  static int? get awayMs {
    final left = lastMs;
    final back = returnedMs;
    if (left == null) return back;
    if (back == null) return left;
    return back > left ? back : left;
  }

  /// A system back that reaches the game while an ad is up, or in the
  /// moment after it closes, was meant for the ad (the player pressing back
  /// to leave it, more than once). It must never close a screen, leave a
  /// room, or exit the app.
  static bool swallowsBack() {
    if (adShowing) return true;
    final back = returnedMs;
    return back != null &&
        clock() - back < AdTokens.backAfterAdGrace.inMilliseconds;
  }

  /// Tests only.
  static void reset() {
    lastMs = null;
    returnedMs = null;
    adShowing = false;
    clock = () => DateTime.now().millisecondsSinceEpoch;
  }
}
