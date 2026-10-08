import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../online/online_session.dart';
import '../../economy/wallet.dart';

/// Claims the server's first-solve reward for [storyId] and returns the
/// coins granted: 0 when it was already paid, or on any failure. The amount
/// is the server's; a story played offline simply earns nothing.
Future<int> claimStoryReward(ProviderContainer container, String storyId) async {
  if (!SupabaseConfig.isConfigured) return 0;
  try {
    final backend = await container.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final answer = await backend.call('economy', {
      'action': 'storySolved',
      'story': storyId,
    });
    final granted = (answer['granted'] as num?)?.toInt() ?? 0;
    if (granted > 0) {
      await container.read(walletProvider.notifier).settle(credited: granted);
    }
    return granted;
  } catch (_) {
    return 0;
  }
}
