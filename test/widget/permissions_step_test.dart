import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/terms_consent.dart';
import 'package:mafia_master/platform/push/push_service.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/onboarding/permissions_step.dart';
import 'package:mafia_master/ui/screens/setup/settings_sheet.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:mafia_master/ui/social/push_prompt.dart';
import 'package:mafia_master/ui/social/push_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

class _Push implements PushService {
  _Push(this.grant);
  final bool grant;
  int asks = 0;
  @override
  String? get platform => 'web';
  @override
  bool get needsInstall => false;
  @override
  Future<void> init() async {}
  @override
  Future<bool> askPermission() async {
    asks++;
    return grant;
  }

  @override
  Future<bool> isGranted() async => grant;
  @override
  Future<String?> token() async => 'test-token';
  @override
  Stream<PushOpen> get opened => const Stream.empty();
  @override
  Stream<void> get foreground => const Stream.empty();
  @override
  Future<PushOpen?> initialOpen() async => null;
}

class _Api extends DirectoryApi {
  _Api(super.ref);
  static int registrations = 0;
  @override
  Future<void> registerPush(String token, String platform) async {
    registrations++;
  }
}

class _Mic implements MicrophonePermission {
  @override
  bool get supported => true;
  int asks = 0;
  @override
  Future<bool> request() async {
    asks++;
    return false;
  }
}

Widget _app(_Push push, _Mic mic, Widget child) => ProviderScope(
  overrides: [
    pushServiceProvider.overrideWithValue(push),
    directoryApiProvider.overrideWith(_Api.new),
    microphonePermissionProvider.overrideWithValue(mic),
  ],
  child: localizedApp(child),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _Api.registrations = 0;
  });

  testWidgets('permissions continue works with both requests refused', (
    tester,
  ) async {
    final push = _Push(false);
    final mic = _Mic();
    var continued = false;
    await tester.pumpWidget(
      _app(
        push,
        mic,
        Scaffold(body: PermissionsStep(onContinue: () => continued = true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PushSettingsRow.switchKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(MicrophoneSettingsRow.requestKey));
    await tester.tap(find.byKey(MicrophoneSettingsRow.requestKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PermissionsStep.continueKey));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(continued, isTrue);
    expect(push.asks, 1);
    expect(mic.asks, 1);
    expect(prefs.getBool(PushPrompt.askedKey), isTrue);
    expect(prefs.getBool(PushPrompt.onKey), isFalse);
    expect(prefs.getBool(permissionsDoneKey), isTrue);
  });

  testWidgets('notifications in onboarding ask and register on grant', (
    tester,
  ) async {
    final push = _Push(true);
    await tester.pumpWidget(
      _app(push, _Mic(), Scaffold(body: PermissionsStep(onContinue: () {}))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PushSettingsRow.switchKey));
    await tester.pumpAndSettle();
    expect(push.asks, 1);
    expect(_Api.registrations, 1);
    expect(
      (await SharedPreferences.getInstance()).getBool(PushPrompt.onKey),
      isTrue,
    );
  });

  testWidgets('finished player sees permissions once', (tester) async {
    SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: '{"name":"Old","gender":"female"}',
      TermsStore.versionKey: currentTermsVersion,
      TermsStore.acceptedAtKey: '2026-09-23T10:00:00.000Z',
      TermsStore.adultKey: true,
    });
    final push = _Push(false);
    await tester.pumpWidget(
      _app(push, _Mic(), const SetupRequired(child: Text('HOME'))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(PermissionsStep.continueKey), findsOneWidget);
    await tester.tap(find.byKey(PermissionsStep.continueKey));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _app(push, _Mic(), const SetupRequired(child: Text('HOME'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(PermissionsStep.continueKey), findsNothing);
  });

  testWidgets('settings shows notification and microphone rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _Push(false),
        _Mic(),
        const Scaffold(body: SingleChildScrollView(child: SettingsSheetBody())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(PushSettingsRow.switchKey));
    expect(find.byKey(PushSettingsRow.switchKey), findsOneWidget);
    await tester.ensureVisible(find.byKey(MicrophoneSettingsRow.requestKey));
    expect(find.byKey(MicrophoneSettingsRow.requestKey), findsOneWidget);
  });
}
