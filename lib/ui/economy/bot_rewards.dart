import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/online/online_session.dart';
import 'wallet.dart';

final botRewardSessionProvider = StateProvider<String?>((ref) => null);

Map<String, String> botWinRequest(String sessionId) => {
  'action': 'botWin',
  'sessionId': sessionId,
};

Future<void> startBotRewardSession(ProviderContainer container) async {
  container.read(botRewardSessionProvider.notifier).state = null;
  if (!SupabaseConfig.isConfigured) return;
  try {
    final backend = await container.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final answer = await backend.call('economy', {'action': 'botStart'});
    container.read(botRewardSessionProvider.notifier).state =
        answer['sessionId'] as String?;
  } catch (_) {
    // Local play still works when the server is unavailable.
  }
}

/// Claims the coins for a win against bots and returns how many the server
/// granted: 0 past the daily cap, offline, or on any failure.
Future<int> claimBotWin(ProviderContainer container) async {
  final sessionId = container.read(botRewardSessionProvider);
  container.read(botRewardSessionProvider.notifier).state = null;
  if (sessionId == null) return 0;
  if (!SupabaseConfig.isConfigured) return 0;
  try {
    final backend = await container.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final answer = await backend.call('economy', botWinRequest(sessionId));
    final granted = (answer['granted'] as num?)?.toInt() ?? 0;
    if (granted > 0) {
      await container.read(walletProvider.notifier).settle(credited: granted);
    }
    return granted;
  } catch (_) {
    return 0;
  }
}
