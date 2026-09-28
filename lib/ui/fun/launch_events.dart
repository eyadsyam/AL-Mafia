import '../../transport/online_backend.dart';

/// Row 12: the launch-event stamps a finished online room earned, for the
/// public result only (`eventResult{roomId}`). The server answers empty for a
/// room that is still being played, so no live surface can draw one.
///
/// TODO(art): the result-screen stamp that shows these codes.
Future<List<String>> fetchLaunchEventStamps(
  OnlineBackend backend,
  String roomId,
) async {
  try {
    final answer = await backend.call('economy', {
      'action': 'eventResult',
      'roomId': roomId,
    });
    final events = answer['events'];
    if (answer['enabled'] != true || events is! List) return const [];
    return [for (final code in events) if (code is String) code];
  } catch (_) {
    // Never load-bearing for the result screen.
    return const [];
  }
}
