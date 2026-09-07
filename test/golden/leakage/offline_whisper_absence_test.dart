/// Doc 14 §3.1 and §1.4: offline there are no whispers, and the confirmation
/// screen says one thing.
///
/// # What this file replaces
///
/// It replaces `whisper_card_parity_test`, which asserted the opposite and was
/// right to at the time. Doc 09 §3.6 made the whisper card *unconditional* on
/// the night screen for a good arithmetic reason: the phone visits every seat
/// in order, in front of everybody, so a card that appeared only for a player
/// who had received a whisper would let the table count screens and work out
/// who had. That reasoning was sound. The premise under it was not.
///
/// Doc 14 §3.1 removes the premise: a private message delivered on a shared
/// phone cannot arrive without stopping the discussion to pass the phone
/// around, which is the discussion it was written to influence. So the layer
/// is online-only, delivered the moment it is sent, and the night screen has no
/// whisper slot to keep parity in.
///
/// The obligation does not disappear, it inverts — and this file states the
/// inverted form: **there is nothing whisper-shaped on an offline night screen
/// at all**, for any role, in any state. A slot that is absent for everybody
/// cannot be read by anybody.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../../support/localized.dart';
import '../../support/turn_shell_harness.dart';

void main() {
  Future<void> driveToConfirmed(WidgetTester tester, Role role) async {
    await TurnShellHarness.pump(
      tester,
      role: role,
      prompt: TurnShellHarness.naturalPrompt(role),
      targetList: TurnShellHarness.withSpecial(role),
    );
    await TurnShellHarness.completeHold(tester);
    await tester.tap(find.byKey(NightGrid.tile(1)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.tap(find.byKey(TurnShell.actionButton));
    await tester.pump();
  }

  group('doc 14 §3.1 — offline has no whisper layer', () {
    testWidgets('no whisper copy reaches the night screen, in any state',
        (tester) async {
      final forbidden = [
        arStrings.whisperLabel,
        arStrings.whisperCompose,
        arStrings.whisperUndelivered,
        arStrings.whisperPickRecipient,
      ];

      for (final role in Role.values) {
        await TurnShellHarness.pump(
          tester,
          role: role,
          prompt: TurnShellHarness.naturalPrompt(role),
          targetList: TurnShellHarness.withSpecial(role),
        );
        for (final word in forbidden) {
          expect(find.text(word), findsNothing,
              reason: '$role, handoff: "$word"');
        }

        await TurnShellHarness.completeHold(tester);
        for (final word in forbidden) {
          expect(find.text(word), findsNothing,
              reason: '$role, revealed: "$word"');
        }
      }
    });

    testWidgets('and none after the turn is recorded either', (tester) async {
      for (final role in Role.values) {
        await driveToConfirmed(tester, role);
        expect(find.text(arStrings.whisperLabel), findsNothing, reason: '$role');
      }
    });
  });

  group('doc 14 §1.4 — the confirmation screen is one line', () {
    testWidgets('the recorded line is there, and no panel under it',
        (tester) async {
      await driveToConfirmed(tester, Role.citizen);

      expect(find.text(arStrings.choiceRecorded), findsOneWidget);
      // The seat they picked, as one word. Doc 14 §1.4 asks for no name at
      // all; doc 05 outranks it and will not have three screens carrying
      // nothing here while a fourth carries a verdict — see `_detailSlot`.
      // What went is the whisper card and the bordered panel.
      expect(find.text('أحمد'), findsOneWidget);
    });

    testWidgets('the Detective still gets their answer', (tester) async {
      await TurnShellHarness.pump(
        tester,
        role: Role.detective,
        prompt: TurnShellHarness.naturalPrompt(Role.detective),
        targetList: TurnShellHarness.withSpecial(Role.detective),
        confirmationDetail: 'مافيا',
      );
      await TurnShellHarness.completeHold(tester);
      await tester.tap(find.byKey(NightGrid.tile(1)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pump();

      expect(find.text('مافيا'), findsOneWidget);
    });

    testWidgets('the detail slot holds one rect for all four roles',
        (tester) async {
      final rects = <Role, Rect>{};
      for (final role in Role.values) {
        await driveToConfirmed(tester, role);
        rects[role] = tester.getRect(find.byKey(TurnShell.slotDetail));
      }
      final first = rects[Role.values.first]!;
      for (final entry in rects.entries) {
        expect(entry.value, first, reason: '${entry.key}');
      }
      expect(first.height, greaterThan(0));
    });
  });
}
