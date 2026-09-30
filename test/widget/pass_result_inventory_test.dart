import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/pass_result_inventory.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// P6: the pass-and-play result surfaces only offers already made today and
/// not yet taken; nothing new, nothing when off, nothing when all are used.
void main() {
  late FakeBackend backend;
  late Map<String, dynamic> caps;
  late Map<String, dynamic> daily;
  late Map<String, dynamic> extras;

  setUp(() {
    caps = {
      'version': 2,
      'dailyAd': true,
      'ads': {'extras': {'spin': true, 'coffer': true, 'swap': false}},
    };
    daily = {
      'enabled': true,
      'day': '2026-09-28',
      'coffer': {'claimed': true, 'amount': 20},
      'wheel': {'spun': true},
      'week': {'progress': 1, 'length': 7, 'bonus': 60},
      'ad': {'enabled': true, 'amount': 25, 'state': 'available'},
      'inMatch': false,
    };
    extras = {
      'day': '2026-09-28',
      'inMatch': false,
      'spin': {'enabled': true, 'state': 'awarded'},
      'coffer': {'enabled': true, 'state': 'available'},
      'swap': {'enabled': false},
    };
    backend = FakeBackend(roomId: 'r', state: roomState(), players: roster(5));
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => caps,
      'daily_status' => daily,
      'extras_status' => extras,
      _ => {'ok': true},
    };
  });

  Future<void> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
    );
    addTearDown(container.dispose);
    // The session's capabilities are already known by the time a result shows.
    await container.read(economyCapabilitiesProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          const Scaffold(body: SingleChildScrollView(child: PassResultInventory())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Iterable<String?> actions() => backend.calls
      .where((c) => c.function == 'economy')
      .map((c) => c.body['action'] as String?);

  testWidgets('capabilities not read yet: nothing drawn, nothing fetched', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onlineBackendFactoryProvider.overrideWithValue(() async => backend)],
        child: localizedApp(const Scaffold(body: PassResultInventory())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(PassResultInventory.stripKey), findsNothing);
    expect(backend.calls, isEmpty);
  });

  testWidgets('pending offers are listed; used ones are not', (tester) async {
    await pump(tester);
    expect(find.byKey(PassResultInventory.stripKey), findsOneWidget);
    expect(find.text('إعلان اليوم بمكافأته'), findsOneWidget);
    expect(find.text('خزنة زيادة'), findsOneWidget);
    expect(find.text('لفة زيادة للعجلة'), findsNothing, reason: 'already taken today');

    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(PassResultInventory.stripKey),
                    matching: find.byType(DecoratedBox),
                  ).first,
                )
                .decoration
            as BoxDecoration;
    expect(
      (decoration.image!.image as AssetImage).assetName,
      'assets/images/economy_v2/ticket_strip.webp',
    );
  });

  testWidgets('everything taken: nothing drawn', (tester) async {
    daily['ad'] = {'enabled': true, 'amount': 25, 'state': 'awarded'};
    extras['coffer'] = {'enabled': true, 'state': 'awarded'};
    await pump(tester);
    expect(find.byKey(PassResultInventory.stripKey), findsNothing);
  });

  testWidgets('features off: nothing drawn and nothing asked beyond capabilities', (tester) async {
    caps = {'version': 2};
    await pump(tester);
    expect(find.byKey(PassResultInventory.stripKey), findsNothing);
    expect(actions(), isNot(contains('daily_status')));
    expect(actions(), isNot(contains('extras_status')));
  });

  testWidgets('no server answer: the result is never held up', (tester) async {
    backend.unreachable = true;
    await pump(tester);
    expect(find.byKey(PassResultInventory.stripKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('never counts an offer while a match is in play', (tester) async {
    daily['ad'] = {'enabled': true, 'amount': 25, 'state': 'available', 'inMatch': true};
    extras['inMatch'] = true;
    await pump(tester);
    expect(find.byKey(PassResultInventory.stripKey), findsNothing);
  });
}
