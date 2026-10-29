import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/night/night_action_screen.dart'
    show nightPromptInkLength;
import 'package:mafia_master/ui/screens/online/council/voice_band.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Update 1.5 / WP8 (#u6), Doc 05: what a phone shows during the online night
/// must not depend on the role it belongs to — the same words-length, the same
/// boxes, the same pad, in the same places.
void main() {
  /// Glyphs that actually emit light (whitespace advances the layout only).
  int ink(String s) => s.replaceAll(RegExp(r'\s+'), '').runes.length;

  /// Every line a night can show, the Sniper's spent-bullet variant included.
  final lines = <String, String>{
    for (final role in Role.values)
      role.name: EngineCopy.nightLine(arStrings, role),
    'sniperSpent': EngineCopy.nightLine(
      arStrings,
      Role.sniper,
      bulletInHand: false,
    ),
  };

  group('night copy', () {
    test('every role\'s night line inks the same number of glyphs', () {
      final lengths = {for (final e in lines.entries) e.key: ink(e.value)};
      final expected = lengths.values.first;
      expect(
        lengths.values.toSet(),
        {expected},
        reason:
            'a longer line is a brighter phone and a visible tell (Doc 05). '
            'Rewrite it to length; do not relax this. All: $lengths',
      );
    });

    test('the resting Citizen\'s headline is as long as every question', () {
      expect(ink(arStrings.nightCitizenRest), nightPromptInkLength);
    });

    test('no night line or headline names a role', () {
      const roleWords = ['مافيا', 'دكتور', 'طبيب', 'محقق', 'مواطن'];
      final texts = [
        ...lines.values,
        for (final role in Role.values)
          if (role != Role.citizen) EngineCopy.nightPrompt(arStrings, role),
      ];
      for (final text in texts) {
        for (final word in roleWords) {
          expect(text.contains(word), isFalse, reason: '"$text" names $word');
        }
      }
    });
  });

  group('the online night table', () {
    late FakeBackend backend;
    late OnlineTransport transport;

    Future<({Size headline, Size slot, Size pad})> measure(
      WidgetTester tester,
      Role role,
      Size size,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'night', phaseNumber: 1),
        players: roster(6),
        own: OwnSeat(seat: 0, role: role.name),
      );
      transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      final container = ProviderContainer(
        overrides: [
          gameTransportProvider.overrideWithValue(transport),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
        ],
      );
      container.read(matchControllerProvider.notifier).adoptSnapshot();
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            OnlineTableFlow(
              onExit: () {},
              onAnalytics: () {},
              onStepCommitted: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: '$role at $size');

      return (
        headline: tester.getSize(find.byKey(CouncilVoice.body)),
        slot: tester.getSize(find.byKey(NightSlot.box)),
        pad: tester.getSize(find.byType(HoldPad)),
      );
    }

    for (final size in const [Size(360, 640), Size(390, 844), Size(640, 360)]) {
      testWidgets(
        'all roles draw the same slot, pad and headline height at $size',
        (tester) async {
          final seen = <String, ({Size headline, Size slot, Size pad})>{};
          for (final role in Role.values) {
            seen[role.name] = await measure(tester, role, size);
            await tester.pumpWidget(const SizedBox.shrink());
          }
          final first = seen.values.first;
          for (final entry in seen.entries) {
            expect(entry.value.slot, first.slot, reason: '${entry.key} slot');
            expect(entry.value.pad, first.pad, reason: '${entry.key} pad');
            expect(
              entry.value.headline.height,
              first.headline.height,
              reason: '${entry.key} headline height (same number of lines)',
            );
          }
        },
      );
    }

    testWidgets('a resting Citizen holds the pad and sends nothing', (
      tester,
    ) async {
      await measure(tester, Role.citizen, const Size(390, 844));
      expect(find.byType(HoldPad), findsOneWidget);
      final pad = tester.getCenter(find.byType(HoldPad));
      final gesture = await tester.startGesture(pad);
      await tester.pump(const Duration(seconds: 3));
      await gesture.up();
      await tester.pump();
      await tester.pump();
      // Same line as everybody lands on after confirming; no server call.
      expect(find.text(arStrings.onlineWaitingForTheRest), findsOneWidget);
      expect(
        backend.calls.where(
          (c) =>
              c.function == 'submit_night_action' ||
              c.function == 'skip_night_action',
        ),
        isEmpty,
      );
    });
  });
}
