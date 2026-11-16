import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/startup_permissions.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/terms_consent.dart';
import 'package:mafia_master/platform/push/push_service.dart';
import 'package:mafia_master/platform/voice/microphone_permission.dart';
import 'package:mafia_master/platform/voice/voice_controller.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/onboarding/permissions_step.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/setup/settings_sheet.dart';
import 'package:mafia_master/ui/social/push_prompt.dart';
import 'package:mafia_master/ui/social/push_toggle.dart';
import 'package:mafia_master/ui/widgets/mic_off_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

class _Push implements PushService {
  _Push({this.granted = false, this.grant = false});
  bool granted;
  final bool grant;
  int asks = 0;
  @override
  String? get platform => 'android';
  @override
  bool get needsInstall => false;
  @override
  Future<void> init() async {}
  @override
  Future<bool> askPermission() async {
    asks++;
    granted = grant;
    return grant;
  }

  @override
  Future<bool> isGranted() async => granted;
  @override
  Future<String?> token() async => 'test-token';
  @override
  Stream<PushOpen> get opened => const Stream.empty();
  @override
  Stream<void> get foreground => const Stream.empty();
  @override
  Future<PushOpen?> initialOpen() async => null;
}

class _Mic implements MicrophoneAccess {
  _Mic(this.now, {this.answer = MicrophoneStatus.denied});
  MicrophoneStatus now;
  final MicrophoneStatus answer;
  int asks = 0;
  int settings = 0;
  final order = <String>[];

  @override
  bool get supported => true;
  @override
  Future<MicrophoneStatus> status() async => now;
  @override
  Future<MicrophoneStatus> request() async {
    asks++;
    order.add('mic');
    return now = answer;
  }

  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }
}

class _BrokenMic implements MicrophoneAccess {
  @override
  bool get supported => true;
  @override
  Future<MicrophoneStatus> status() => throw StateError('no plugin');
  @override
  Future<MicrophoneStatus> request() => throw StateError('no plugin');
  @override
  Future<bool> openSettings() async => false;
}

ProviderContainer _container(_Push push, _Mic mic) {
  final container = ProviderContainer(
    overrides: [
      pushServiceProvider.overrideWithValue(push),
      microphoneAccessProvider.overrideWithValue(mic),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('at launch, by itself', () {
    test('notifications only: the microphone is never asked as the game opens '
        '(Play audio policy)', () async {
      final push = _Push(grant: true);
      final mic = _Mic(MicrophoneStatus.denied, answer: MicrophoneStatus.granted);
      final c = _container(push, mic);
      await c.read(startupPermissionsProvider).run();
      expect(mic.asks, 0, reason: 'the microphone waits for an online room');
      expect(push.asks, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(microphoneAllowedKey), isNull);
      expect(prefs.getBool(PushPrompt.onKey), isTrue);
    });

    test('a refusal is asked again on the next launch, never twice in one', () async {
      final push = _Push();
      final mic = _Mic(MicrophoneStatus.denied);
      final c = _container(push, mic);
      final once = c.read(startupPermissionsProvider);
      await once.run();
      await once.run();
      expect(push.asks, 1);

      final next = _container(push, mic);
      await next.read(startupPermissionsProvider).run();
      expect(push.asks, 2);
      expect(mic.asks, 0);
    });

    test('nothing is shown for what is already allowed', () async {
      final push = _Push(granted: true);
      final mic = _Mic(MicrophoneStatus.granted);
      await _container(push, mic).read(startupPermissionsProvider).run();
      expect(mic.asks, 0);
      expect(push.asks, 0);
    });
  });

  group('the microphone is asked on the way into a room', () {
    test('the system dialog once, and the answer kept for the settings row', () async {
      final mic = _Mic(MicrophoneStatus.denied, answer: MicrophoneStatus.granted);
      await askMicrophoneForRoom(mic);
      expect(mic.asks, 1);
      expect(
        (await SharedPreferences.getInstance()).getBool(microphoneAllowedKey),
        isTrue,
      );
    });

    test('a refusal is kept as information and asked again next room', () async {
      final mic = _Mic(MicrophoneStatus.denied);
      await askMicrophoneForRoom(mic);
      expect(
        (await SharedPreferences.getInstance()).getBool(microphoneAllowedKey),
        isFalse,
      );
      await askMicrophoneForRoom(mic);
      expect(mic.asks, 2);
    });

    test('nothing is shown when it is already allowed', () async {
      final mic = _Mic(MicrophoneStatus.granted);
      await askMicrophoneForRoom(mic);
      expect(mic.asks, 0);
    });

    test('a blocked microphone is left to the room card', () async {
      final mic = _Mic(MicrophoneStatus.blocked);
      await askMicrophoneForRoom(mic);
      expect(mic.asks, 0);
    });

    test('a failing permission plugin never stops the entry', () async {
      await askMicrophoneForRoom(_BrokenMic());
    });

    test('entering a room asks before anything else', () {
      final source = File(
        'lib/ui/screens/online/online_session.dart',
      ).readAsStringSync();
      final enter = source.indexOf('Future<void> _enter(');
      expect(enter, isNonNegative);
      final ask = source.indexOf('askMicrophoneForRoom(', enter);
      final network = source.indexOf('_ensureBackend()', enter);
      expect(ask, isNonNegative, reason: 'every room entry goes through _enter');
      expect(ask, lessThan(network), reason: 'the dialog comes on the tap');
    });

    test('the settings switch turned off still wins for notifications', () async {
      SharedPreferences.setMockInitialValues({PushPrompt.onKey: false});
      final push = _Push(grant: true);
      await _container(
        push,
        _Mic(MicrophoneStatus.granted),
      ).read(startupPermissionsProvider).run();
      expect(push.asks, 0);
    });
  });

  testWidgets('a finished player goes straight in: no permissions page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: '{"name":"Old","gender":"female"}',
      TermsStore.versionKey: currentTermsVersion,
      TermsStore.acceptedAtKey: '2026-09-23T10:00:00.000Z',
      TermsStore.adultKey: true,
    });
    await tester.pumpWidget(
      ProviderScope(
        child: localizedApp(const SetupRequired(child: Text('HOME'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('settings: the microphone row opens the phone settings when blocked', (
    tester,
  ) async {
    final mic = _Mic(MicrophoneStatus.blocked);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushServiceProvider.overrideWithValue(_Push()),
          microphoneAccessProvider.overrideWithValue(mic),
        ],
        child: localizedApp(
          const Scaffold(body: SingleChildScrollView(child: SettingsSheetBody())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(PushSettingsRow.switchKey));
    await tester.ensureVisible(find.byKey(MicrophoneSettingsRow.requestKey));
    expect(find.text(arStrings.micOpenSettings), findsOneWidget);
    await tester.tap(find.byKey(MicrophoneSettingsRow.requestKey));
    await tester.pumpAndSettle();
    expect(mic.settings, 1);
    expect(mic.asks, 0);
  });

  group('the room asks again', () {
    Widget lobby(_Mic mic, VoiceState state) => ProviderScope(
      overrides: [
        microphoneAccessProvider.overrideWithValue(mic),
        voiceStateProvider.overrideWith((ref) => Stream.value(state)),
        voiceControllerProvider.overrideWithValue(null),
      ],
      child: localizedApp(const Scaffold(body: MicOffCard())),
    );

    testWidgets('red card while refused; the button shows the dialog again', (
      tester,
    ) async {
      final mic = _Mic(MicrophoneStatus.denied);
      await tester.pumpWidget(
        lobby(
          mic,
          const VoiceState(mode: VoiceMode.live, microphoneRefused: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(MicOffCard.cardKey), findsOneWidget);
      expect(find.text(arStrings.micOffTitle), findsOneWidget);
      await tester.tap(find.byKey(MicOffCard.actionKey));
      await tester.pumpAndSettle();
      expect(mic.asks, 1);
    });

    testWidgets('a phone that stopped asking opens its settings page', (
      tester,
    ) async {
      final mic = _Mic(MicrophoneStatus.blocked);
      await tester.pumpWidget(
        lobby(
          mic,
          const VoiceState(mode: VoiceMode.live, microphoneRefused: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MicOffCard.actionKey));
      await tester.pumpAndSettle();
      expect(mic.settings, 1);
      expect(find.text(arStrings.micOffSettingsHint), findsOneWidget);
    });

    testWidgets('no card once the microphone works', (tester) async {
      await tester.pumpWidget(
        lobby(
          _Mic(MicrophoneStatus.granted),
          const VoiceState(mode: VoiceMode.live, microphoneAvailable: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(MicOffCard.cardKey), findsNothing);
    });
  });
}
