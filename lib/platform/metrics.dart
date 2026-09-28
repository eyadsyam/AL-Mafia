import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/request_id.dart';
import '../ui/economy/economy_capabilities.dart';
import '../ui/screens/online/online_session.dart';
import '../ui/theme/design_tokens.dart';

typedef MetricsEnabled = Future<bool> Function();
typedef MetricSender = Future<void> Function(Map<String, Object?> body);

/// The only client path into F13. It accepts no generic properties map, so a
/// caller cannot accidentally attach a room, player, role, message or code.
class MetricsClient {
  final MetricsEnabled _enabled;
  final MetricSender _send;
  final String Function() _requestId;
  Future<void> _settled = Future<void>.value();

  MetricsClient({
    required MetricsEnabled enabled,
    required MetricSender send,
    String Function()? requestId,
  }) : _enabled = enabled,
       _send = send,
       _requestId = requestId ?? newRequestId;

  /// Starts the write and returns immediately. Capability, transport and
  /// server failures are deliberately invisible to product flows.
  void record(String event, {String prop = ''}) {
    _settled = _record(event, prop);
    unawaited(_settled);
  }

  Future<void> _record(String event, String prop) async {
    try {
      if (!await _enabled()) return;
      await _send({
        'action': 'metric',
        'event': event,
        'prop': prop,
        'requestId': _requestId(),
      });
    } catch (_) {}
  }

  /// Whether a record would be sent now.
  Future<bool> get enabled async {
    try {
      return await _enabled();
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  Future<void> get settled => _settled;
}

final metricsClientProvider = Provider<MetricsClient>((ref) {
  return MetricsClient(
    // Never fetches capabilities itself (start-up must not wait on it).
    enabled: () async =>
        ref.read(economyCapabilitiesProvider).valueOrNull?.metrics ?? false,
    send: (body) async {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      await backend.call('economy', body);
    },
  );
});

abstract interface class InstallReferrerReader {
  Future<String?> read();
}

class PlayInstallReferrerReader implements InstallReferrerReader {
  const PlayInstallReferrerReader();

  @override
  Future<String?> read() async =>
      (await PlayInstallReferrer.installReferrer).installReferrer;
}

abstract interface class FirstOpenStore {
  Future<bool> isDone();
  Future<void> markDone();
}

class SharedPreferencesFirstOpenStore implements FirstOpenStore {
  static const _doneKey = 'metrics_first_open_done_v1';

  @override
  Future<bool> isDone() async =>
      (await SharedPreferences.getInstance()).getBool(_doneKey) ?? false;

  @override
  Future<void> markDone() async {
    await (await SharedPreferences.getInstance()).setBool(_doneKey, true);
  }
}

/// The complete attribution vocabulary. Only its selected value leaves this
/// class; the source string is held in memory just long enough to choose it.
const Map<String, String> firstOpenCampaignBuckets = {
  'side_detective': 'side_detective',
  'side_doctor': 'side_doctor',
  'side_mafia': 'side_mafia',
  'side_citizen': 'side_citizen',
};

String firstOpenBucket(String? referrer) {
  if (referrer == null || referrer.isEmpty) return 'organic';
  Map<String, String> values;
  try {
    values = Uri.splitQueryString(referrer);
  } catch (_) {
    return 'organic';
  }
  final source = (values['utm_source'] ?? '').toLowerCase();
  final campaign = (values['utm_campaign'] ?? '').toLowerCase();
  final side = firstOpenCampaignBuckets[campaign];
  if (side != null) return side;
  if (campaign.startsWith('creator_') || source.startsWith('creator_')) {
    return 'creator';
  }
  if (campaign == 'case' || source == 'case') return 'case';
  if (campaign == 'invite' || source == 'invite') return 'invite';
  return 'organic';
}

class FirstOpenAttribution {
  final InstallReferrerReader _reader;
  final FirstOpenStore _store;
  final MetricsClient _metrics;
  final bool _supported;
  bool _running = false;

  FirstOpenAttribution({
    required InstallReferrerReader reader,
    required FirstOpenStore store,
    required MetricsClient metrics,
    required bool supported,
  }) : _reader = reader,
       _store = store,
       _metrics = metrics,
       _supported = supported;

  Future<void> run() async {
    if (!_supported || _running) return;
    _running = true;
    try {
      if (await _store.isDone()) return;
      // Not measured yet: leave it for the run after capabilities say on.
      if (!await _metrics.enabled) return;
      var bucket = 'organic';
      try {
        final raw = await _reader.read().timeout(
          MafiaTiming.installReferrerTimeout,
        );
        bucket = firstOpenBucket(raw);
      } catch (_) {}
      _metrics.record('attributed_first_open', prop: bucket);
      await _store.markDone();
    } catch (_) {
      // First-open measurement can never become a startup dependency.
    } finally {
      _running = false;
    }
  }
}

final firstOpenAttributionProvider = Provider<FirstOpenAttribution>((ref) {
  return FirstOpenAttribution(
    reader: const PlayInstallReferrerReader(),
    store: SharedPreferencesFirstOpenStore(),
    metrics: ref.read(metricsClientProvider),
    supported: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  );
});
