import 'dart:math';

/// A random (version 4) UUID for a mutation's `requestId`.
///
/// The server keeps the first answer under this id and replays it, so a
/// request retried after a lost response is applied once. Mint one per
/// intended action and reuse it for that action's retries; mint a new one
/// only when the player means to do something again.
String newRequestId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
