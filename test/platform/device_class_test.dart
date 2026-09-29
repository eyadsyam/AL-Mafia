import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/device_class.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

void main() {
  bool lowEnd() => DeviceClass.isLowEnd(
    maxPhysicalPixels: DeviceClassTokens.lowEndPhysicalPixels,
  );

  testWidgets('a 720p screen is low-end, a 1080p one is not', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(720, 1600);
    expect(lowEnd(), isTrue);
    tester.view.physicalSize = const Size(1080, 2400);
    expect(lowEnd(), isFalse);
  });

  testWidgets('the debug override wins both ways', (tester) async {
    addTearDown(() => DeviceClass.debugLowEndOverride = null);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1080, 2400);
    DeviceClass.debugLowEndOverride = true;
    expect(lowEnd(), isTrue);
    tester.view.physicalSize = const Size(720, 1600);
    DeviceClass.debugLowEndOverride = false;
    expect(lowEnd(), isFalse);
  });

  test('low-end budgets are smaller than the full ones', () {
    expect(
      DeviceClassTokens.lowEndFallingIconCount,
      lessThan(DeviceClassTokens.fallingIconCount),
    );
  });
}
