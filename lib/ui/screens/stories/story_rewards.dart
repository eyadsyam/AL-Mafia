import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../online/online_session.dart';
import '../../economy/wallet.dart';
import '../../../stories/v2/session.dart';
import '../../../stories/v2/table.dart';
import 'story_flow_screen.dart';

Map<String, String>? storySolveRequest(StoryCompletion completion) {
  final accusation = completion.accusation;
  if (!completion.solved || accusation == null) return null;
  return {
    'action': 'storySolved',
    'story': completion.story.id,
    'culprit': accusation.culprit,
    'motive': accusation.motive,
    'method': accusation.method,
  };
}

/// Claims the server's first-solve reward for [storyId] and returns the
/// coins granted: 0 when it was already paid, or on any failure. The amount
/// is the server's; a story played offline simply earns nothing.
Future<int> claimStoryReward(
  ProviderContainer container,
  StoryCompletion completion,
) async {
  final request = storySolveRequest(completion);
  if (request == null) return 0;
  if (!SupabaseConfig.isConfigured) return 0;
  try {
    final backend = await container.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final answer = await backend.call('economy', request);
    final granted = (answer['granted'] as num?)?.toInt() ?? 0;
    if (granted > 0) {
      await container.read(walletProvider.notifier).settle(credited: granted);
    }
    return granted;
  } catch (_) {
    return 0;
  }
}

/// The server's deal for one Stories V2 table: who did it, and the session
/// its answer is checked against.
class StoryServerDeal {
  const StoryServerDeal({required this.sessionId, required this.pick});

  final String sessionId;
  final StoryCulpritPick pick;
}

/// Asks the server who did it at a table of [players]; [avoid] is this
/// phone's recent culprits. Null offline, without a project, or on any
/// refusal: the table then deals on the phone and earns no coins.
Future<StoryServerDeal?> startStorySession(
  ProviderContainer container, {
  required String storyId,
  required int players,
  required Set<String> avoid,
}) async {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    final backend = await container.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final answer = await backend.call('economy', {
      'action': 'storyStart',
      'story': storyId,
      'players': players,
      'avoid': avoid.toList(),
    });
    final session = answer['sessionId'];
    final culprit = answer['culprit'];
    final partner = answer['partner'];
    if (session is! String || culprit is! String) return null;
    return StoryServerDeal(
      sessionId: session,
      pick: StoryCulpritPick(
        culpritId: culprit,
        partnerId: partner is String ? partner : null,
      ),
    );
  } catch (_) {
    return null;
  }
}

/// Sends a V2 table's answer for [sessionId] and returns the coins granted:
/// the story's first solve pays once per account, anything else 0.
Future<int> claimStorySession(
  ProviderContainer container, {
  required String sessionId,
  required StoryAccusationV2 accusation,
}) async {
  if (!SupabaseConfig.isConfigured) return 0;
  try {
    final backend = await container.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final answer = await backend.call('economy', {
      'action': 'storyClaim',
      'sessionId': sessionId,
      'who': accusation.suspectId,
      'why': ?accusation.motiveId,
      'how': ?accusation.methodId,
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
