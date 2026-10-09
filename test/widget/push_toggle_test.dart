import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/push/push_service.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:mafia_master/ui/social/push_prompt.dart';
import 'package:mafia_master/ui/social/push_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

class _Api extends DirectoryApi {
  _Api(super.ref);
  final registered = <String>[];
  final dropped = <String>[];
  bool failDrop = false;
  @override
  Future<void> registerPush(String token, String platform) async =>
      registered.add(token);
  @override
  Future<void> unregisterPush(String token) async {
    if (failDrop) throw StateError('offline');
    dropped.add(token);
  }
}

class _Push implements PushService {
  _Push({this.platformName = 'android', this.install = false, this.grant = true});
  final String? platformName;
  final bool install;
  final bool grant;
  int asks = 0;
  @override
  String? get platform => platformName;
  @override
  bool get needsInstall => install;
  @override
  Future<void> init() async {}
  @override
  Future<bool> askPermission() async {
    asks++;
    return grant;
  }
  @override
  Future<bool> isGranted() async => false;
  @override
  Future<String?> token() async => 'tok-${'x' * 30}';
  @override
  Stream<PushOpen> get opened => const Stream.empty();
  @override
  Stream<void> get foreground => const Stream.empty();
  @override
  Future<PushOpen?> initialOpen() async => null;
}

Future<void> _pump(WidgetTester tester, _Push push) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pushServiceProvider.overrideWithValue(push),
        directoryApiProvider.overrideWith(_Api.new),
      ],
      child: localizedApp(const Scaffold(body: PushSettingsRow())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('failed token cleanup does not prevent sign-out', () async {
    late _Api api;
    final container = ProviderContainer(overrides: [
      pushServiceProvider.overrideWithValue(_Push()),
      directoryApiProvider.overrideWith((ref) => api = _Api(ref)),
    ]);
    addTearDown(container.dispose);
    container.read(directoryApiProvider);
    api.failDrop = true;
    await container.read(pushPromptProvider).unregisterThisDevice();
    expect(api.dropped, isEmpty);
  });
  test('first completed result asks once without invite capability', () async {
    final push = _Push();
    late _Api api;
    final container = ProviderContainer(overrides: [
      pushServiceProvider.overrideWithValue(push),
      directoryApiProvider.overrideWith((ref) => api = _Api(ref)),
    ]);
    addTearDown(container.dispose);
    final prompt = container.read(pushPromptProvider);
    await prompt.askAfterFirstResult();
    await prompt.askAfterFirstResult();
    expect(push.asks, 1);
    expect(api.registered, hasLength(1));
  });

  test('first result respects explicit off and Safari install requirement',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PushPrompt.onKey, false);
    final off = _Push();
    final container = ProviderContainer(overrides: [
      pushServiceProvider.overrideWithValue(off),
    ]);
    addTearDown(container.dispose);
    await container.read(pushPromptProvider).askAfterFirstResult();
    expect(off.asks, 0);

    SharedPreferences.setMockInitialValues({});
    final safari = _Push(platformName: 'web', install: true);
    final safariContainer = ProviderContainer(overrides: [
      pushServiceProvider.overrideWithValue(safari),
    ]);
    addTearDown(safariContainer.dispose);
    await safariContainer.read(pushPromptProvider).askAfterFirstResult();
    expect(safari.asks, 0);
  });

  testWidgets('hidden where this build has no push', (tester) async {
    await _pump(tester, _Push(platformName: null));
    expect(find.byKey(PushSettingsRow.switchKey), findsNothing);
  });

  testWidgets('turning on asks permission and registers; off drops the token', (
    tester,
  ) async {
    late _Api api;
    final container = ProviderContainer(
      overrides: [
        pushServiceProvider.overrideWithValue(_Push()),
        directoryApiProvider.overrideWith((ref) => api = _Api(ref)),
      ],
    );
    addTearDown(container.dispose);
    container.read(directoryApiProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(const Scaffold(body: PushSettingsRow())),
      ),
    );
    await tester.pumpAndSettle();
    final finder = find.byKey(PushSettingsRow.switchKey);
    expect(tester.widget<Switch>(finder).value, isFalse);

    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(finder).value, isTrue);
    expect(api.registered, hasLength(1));

    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(finder).value, isFalse);
    expect(api.dropped, hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PushPrompt.onKey), isFalse);
  });

  testWidgets('a refused system prompt leaves the switch off', (tester) async {
    await _pump(tester, _Push(grant: false));
    await tester.tap(find.byKey(PushSettingsRow.switchKey));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Switch>(find.byKey(PushSettingsRow.switchKey)).value,
      isFalse,
    );
  });

  testWidgets('an iPhone browser tab explains the Home Screen step', (
    tester,
  ) async {
    await _pump(tester, _Push(platformName: 'web', install: true));
    final sw = tester.widget<Switch>(find.byKey(PushSettingsRow.switchKey));
    expect(sw.onChanged, isNull);
    expect(find.textContaining('الشاشة الرئيسية'), findsOneWidget);
  });
}
