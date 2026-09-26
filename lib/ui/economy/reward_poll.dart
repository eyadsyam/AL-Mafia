import 'dart:async';

import '../theme/design_tokens.dart';

/// Waits for AdMob's signed callback to land on the server.
///
/// The client never grants anything: it only asks the server whether the
/// reward is there yet. Checks back off from [MafiaTiming.adRewardPoll] to
/// [MafiaTiming.adRewardPollCap] for at most [MafiaTiming.adRewardPollWindow],
/// then gives up quietly so the screen can offer a manual «check again».
///
/// [alive] is asked before every check: a disposed screen or a newer poll
/// makes an older one stop without touching state.
Future<bool> pollForReward({
  required Future<bool> Function() awarded,
  required bool Function() alive,
  Duration first = MafiaTiming.adRewardPoll,
  Duration cap = MafiaTiming.adRewardPollCap,
  Duration window = MafiaTiming.adRewardPollWindow,
}) async {
  var waited = Duration.zero;
  var step = first;
  while (waited < window) {
    await Future<void>.delayed(step);
    waited += step;
    if (!alive()) return false;
    try {
      if (await awarded()) return true;
    } catch (_) {
      // A failed check is just a check that did not answer yet.
    }
    if (!alive()) return false;
    final next = step * 2;
    step = next > cap ? cap : next;
  }
  return false;
}
