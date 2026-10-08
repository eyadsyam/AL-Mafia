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
  @override
  Future<void> registerPush(String token, String platform) async =>
      registered.add(token);
  @override
  Future<void> unregisterPush(String token) async => dropped.add(token);
}

class _Push implements PushService {
  _Push({this.platformName = 'android', this.install = false, this.grant = true});
  final String? platformName;
  final bool install;
  final bool grant;
  @override
  String? get platform => platformName;
  @override
  bool get needsInstall => install;
  @override
  Future<void> init() async {}
  @override
  Future<bool> askPermission() async => grant;
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
