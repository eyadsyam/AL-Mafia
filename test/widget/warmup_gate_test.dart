import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_warmup.dart';
import 'package:mafia_master/ui/widgets/warmup_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [warmupEnabledProvider.overrideWithValue(true)],
        child: localizedApp(
          const WarmupGate(child: Scaffold(body: Text('table'))),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  test('the signature changes when the asset set changes', () {
    final a = AssetWarmup.signature(['assets/a.webp', 'assets/b.webp']);
    final b = AssetWarmup.signature(['assets/a.webp', 'assets/c.webp']);
    expect(a, isNot(b));
    expect(AssetWarmup.signature(['assets/a.webp', 'assets/b.webp']), a);
  });

  test('the manifest lists the paintings and the sounds', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final assets = await AssetWarmup(bundle: rootBundle).assets();
    expect(assets, contains('assets/images/bg_night.webp'));
    expect(assets.any((a) => a.endsWith('.ogg')), isTrue);
    expect(assets.every((a) => a.startsWith('assets/')), isTrue);
  });

  testWidgets('first launch prepares behind a veil, then lets the table through', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.byKey(WarmupGate.overlayKey), findsOneWidget);
    await settle(tester);
    expect(find.byKey(WarmupGate.overlayKey), findsNothing);
    expect(find.text('table'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AssetWarmup.signatureKey), isNotNull);
  });

  testWidgets('a prepared device shows no veil at all', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final assets = await tester.runAsync(
      () => AssetWarmup(bundle: rootBundle).assets(),
    );
    SharedPreferences.setMockInitialValues({
      AssetWarmup.signatureKey: AssetWarmup.signature(assets!),
    });
    await pump(tester);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(find.byKey(WarmupGate.overlayKey), findsNothing);
    }
  });
}
