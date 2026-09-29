import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';
import 'package:mafia_master/engine/models/enums.dart' as engine;
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/motion_sprite.dart';
import 'package:mafia_master/platform/device_class.dart';

import '../support/localized.dart';

Finder asset(String path) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == path,
);

void main() {
  setUp(() => DeviceClass.debugLowEndOverride = false);
  tearDown(() => DeviceClass.debugLowEndOverride = null);

  testWidgets('motion sprite draws no image under reduced motion', (
    tester,
  ) async {
    Future<void> pump(bool reduced) => tester.pumpWidget(
      localizedApp(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const MotionSprite(
            AppMotion.emberDrift,
            width: MotionTokens.emberWidth,
            height: MotionTokens.emberHeight,
          ),
        ),
      ),
    );

    await pump(false);
    expect(asset(AppMotion.emberDrift), findsOneWidget);
    await pump(true);
    expect(asset(AppMotion.emberDrift), findsNothing);
  });

  testWidgets('low-end skips loops but keeps one-shot reward moments', (
    tester,
  ) async {
    DeviceClass.debugLowEndOverride = true;
    await tester.pumpWidget(
      localizedApp(
        const Column(
          children: [
            MotionSprite(AppMotion.emberDrift, width: MotionTokens.emberWidth),
            MotionSprite(
              AppMotion.goldBurst,
              width: MotionTokens.burst,
              once: MotionTokens.burstLength,
            ),
          ],
        ),
      ),
    );
    expect(asset(AppMotion.emberDrift), findsNothing);
    expect(asset(AppMotion.goldBurst), findsOneWidget);
  });

  testWidgets('both finished teams get the identical ember sprite', (
    tester,
  ) async {
    for (final winner in engine.Alignment.values) {
      await tester.pumpWidget(
        localizedApp(
          ResultScreen(
            winner: winner,
            rows: const [
              ResultRow(seat: 0, name: 'سلمى', role: engine.Role.citizen),
            ],
            onHome: () {},
          ),
        ),
      );
      expect(asset(AppMotion.emberDrift), findsOneWidget);
    }
  });

  test('private phase widgets cannot import or name the motion sprites', () {
    const privateFiles = [
      'lib/ui/screens/distribution/role_reveal_screen.dart',
      'lib/ui/screens/night/night_action_screen.dart',
      'lib/ui/screens/day/voting_screen.dart',
      'lib/ui/widgets/pass_screen.dart',
    ];
    for (final path in privateFiles) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('emberDrift')), reason: path);
      expect(source, isNot(contains('smokeWisp')), reason: path);
    }
  });

  test('smoke is guarded by the public night-falls moment', () {
    final source = File('lib/ui/screens/match_flow.dart').readAsStringSync();
    expect(source, contains('if (moment != _Moment.night) return child;'));
    expect(source, contains('AppMotion.smokeWisp'));
  });
}
