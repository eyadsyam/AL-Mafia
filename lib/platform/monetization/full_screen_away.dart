/// When the player last left the game for another full-screen ad or the
/// Play purchase sheet. The app-open ad never follows such a return
/// (phase 108). In memory: a cold start is decided by its own rules.
abstract final class FullScreenAway {
  static int? lastMs;

  static void mark() => lastMs = DateTime.now().millisecondsSinceEpoch;
}
