import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/voice_policy.dart';
import 'package:mafia_master/platform/voice/voice_controller.dart';
import 'package:mafia_master/transport/voice_link.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/widgets/voice_controls.dart';

import '../support/fake_voice_engine.dart';
import '../support/localized.dart';

void main() {
  test('a floor call that never answered, or was granted, says nothing', () {
    expect(floorClaimMessage(arStrings, null), isNull);
    expect(
      floorClaimMessage(arStrings, const FloorClaim(granted: true)),
      isNull,
    );
  });

  for (final (claim, expected) in <(FloorClaim, String?)>[
    (
      const FloorClaim(granted: false, policy: 'muted', reason: 'silenced'),
      arStrings.floorSilenced,
    ),
    (const FloorClaim(granted: false, policy: 'muted'), arStrings.floorMuted),
    (
      const FloorClaim(granted: false, policy: 'turn', owner: 2),
      arStrings.floorNotYourTurn,
    ),
    (const FloorClaim(granted: false, policy: 'turn'), arStrings.floorTaken),
    (const FloorClaim(granted: false, policy: 'open'), null),
  ]) {
    testWidgets(
      'floor refusal ${claim.reason ?? claim.policy}/${claim.owner} appears only when useful',
      (tester) async {
        final link = FakeVoiceLink()..claimResponse = claim;
        final controller = VoiceController(
          engine: FakeVoiceEngine(),
          link: link,
          statsInterval: Duration.zero,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              voiceControllerProvider.overrideWithValue(controller),
              voiceStateProvider.overrideWith(
                (ref) => Stream.value(
                  const VoiceState(
                    mode: VoiceMode.live,
                    policy: MicPolicy.activeSpeakerOnly,
                  ),
                ),
              ),
            ],
            child: localizedApp(const Scaffold(body: VoiceControls())),
          ),
        );
        await tester.pump();
        await tester.tap(find.byKey(VoiceControls.floorButton));
        await tester.pump();
        if (expected == null) {
          expect(find.byType(SnackBar), findsNothing);
        } else {
          expect(find.text(expected), findsOneWidget);
        }
        expect(link.claims, 1);
      },
    );
  }
}
