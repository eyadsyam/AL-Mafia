import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/metrics.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';

class _Reader implements InstallReferrerReader {
  final String? value;
  int reads = 0;
  _Reader(this.value);

  @override
  Future<String?> read() async {
    reads++;
    return value;
  }
}

class _Store implements FirstOpenStore {
  bool done = false;

  @override
  Future<bool> isDone() async => done;

  @override
  Future<void> markDone() async => done = true;
}

void main() {
  test('metric and review capabilities are exact booleans and default off', () {
    expect(EconomyCapabilities.none.metrics, isFalse);
    expect(EconomyCapabilities.none.reviewPrompt, isFalse);
    final enabled = EconomyCapabilities.fromJson({
      'version': 3,
      'metrics': true,
      'reviewPrompt': true,
    });
    expect(enabled.metrics, isTrue);
    expect(enabled.reviewPrompt, isTrue);
    expect(
      EconomyCapabilities.fromJson({
        'version': 3,
        'metrics': 1,
        'reviewPrompt': 'true',
      }).metrics,
      isFalse,
    );
  });

  test(
    'metric is off by default and transport failures never escape',
    () async {
      var sends = 0;
      final off = MetricsClient(
        enabled: () async => false,
        send: (_) async => sends++,
        requestId: () => '10000000-0000-4000-8000-000000000001',
      );
      off.record('case_open');
      await off.settled;
      expect(sends, 0);

      final broken = MetricsClient(
        enabled: () async => true,
        send: (_) async => throw StateError('offline'),
      );
      broken.record('case_open');
      await expectLater(broken.settled, completes);
    },
  );

  test(
    'metric sends only the allowlisted shape and a fresh request id',
    () async {
      Map<String, Object?>? sent;
      final client = MetricsClient(
        enabled: () async => true,
        send: (body) async => sent = body,
        requestId: () => '10000000-0000-4000-8000-000000000002',
      );
      client.record('partner_pick', prop: 'doctor');
      await client.settled;
      expect(sent, {
        'action': 'metric',
        'event': 'partner_pick',
        'prop': 'doctor',
        'requestId': '10000000-0000-4000-8000-000000000002',
      });
    },
  );

  test('referrer mapping has exactly the eight aggregate buckets', () {
    expect(firstOpenCampaignBuckets.values.toSet(), {
      'side_detective',
      'side_doctor',
      'side_mafia',
      'side_citizen',
    });
    expect(firstOpenBucket('utm_campaign=side_mafia'), 'side_mafia');
    expect(firstOpenBucket('utm_campaign=creator_nour'), 'creator');
    expect(firstOpenBucket('utm_source=case'), 'case');
    expect(firstOpenBucket('utm_campaign=invite'), 'invite');
    expect(firstOpenBucket('utm_campaign=something_else'), 'organic');
    expect(firstOpenBucket('not a query%ZZ'), 'organic');
    expect(
      {
        ...firstOpenCampaignBuckets.values,
        firstOpenBucket('utm_campaign=creator_x'),
        firstOpenBucket('utm_campaign=case'),
        firstOpenBucket('utm_campaign=invite'),
        firstOpenBucket(null),
      },
      {
        'side_detective',
        'side_doctor',
        'side_mafia',
        'side_citizen',
        'creator',
        'case',
        'invite',
        'organic',
      },
    );
  });

  test(
    'first open reads once, persists only done, and emits only a bucket',
    () async {
      final reader = _Reader(
        'utm_source=private_name&utm_campaign=side_doctor',
      );
      final store = _Store();
      Map<String, Object?>? sent;
      final metrics = MetricsClient(
        enabled: () async => true,
        send: (body) async => sent = body,
        requestId: () => '10000000-0000-4000-8000-000000000003',
      );
      final attribution = FirstOpenAttribution(
        reader: reader,
        store: store,
        metrics: metrics,
        supported: true,
      );

      await attribution.run();
      await metrics.settled;
      await attribution.run();

      expect(reader.reads, 1);
      expect(store.done, isTrue);
      expect(sent?['event'], 'attributed_first_open');
      expect(sent?['prop'], 'side_doctor');
      expect(sent.toString(), isNot(contains('private_name')));
    },
  );

  test('unsupported platforms never touch the plugin or preferences', () async {
    final reader = _Reader('utm_campaign=side_mafia');
    final store = _Store();
    final attribution = FirstOpenAttribution(
      reader: reader,
      store: store,
      metrics: MetricsClient(enabled: () async => true, send: (_) async {}),
      supported: false,
    );
    await attribution.run();
    expect(reader.reads, 0);
    expect(store.done, isFalse);
  });
}
