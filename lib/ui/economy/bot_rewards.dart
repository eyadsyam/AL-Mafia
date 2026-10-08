import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/online/online_session.dart';
import 'wallet.dart';

/// Claims the coins for a win against bots and returns how many the server
/// granted: 0 past the daily cap, offline, or on any failure.
Future<int> claimBotWin(ProviderContainer container) async {
  if (!SupabaseConfig.isConfigured) return 0;
  try {
    final backend = await container.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final answer = await backend.call('economy', {'action': 'botWin'});
    final granted = (answer['granted'] as num?)?.toInt() ?? 0;
    if (granted > 0) {
      await container.read(walletProvider.notifier).settle(credited: granted);
    }
    return granted;
  } catch (_) {
    return 0;
  }
}
