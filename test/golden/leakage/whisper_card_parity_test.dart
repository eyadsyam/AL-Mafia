import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../../support/turn_shell_harness.dart';

/// **L7 — the whisper card shows on every turn, including the empty state.**
///
/// Doc 11 §8 lists this among the zero-leakage regressions and doc 09 §3.6
/// calls it mandatory rather than optional. The reason is simple arithmetic:
/// the phone visits every seat in order, in front of everybody. If a card
/// appeared only for a player who had received a whisper, the *number of
/// screens* in a turn would say who did — and the whole table can count
/// screens without looking at one.
///
/// So the assertion is not "a whisper is displayed" but "a player with a
/// whisper and a player without one are indistinguishable except for the words
/// inside the card". This suite pins the structure and the geometry; the words
/// are the only thing allowed to differ.
void main() {
  Future<void> driveToConfirmed(WidgetTester tester) async {
    await TurnShellHarness.completeHold(tester);
    await tester.tap(find.text('Seat 1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.tap(find.byKey(TurnShell.actionButton));
    await tester.pump();
  }

  group('L7 — the whisper card is unconditional', () {
    testWidgets('it is on screen with a whisper and without one',
        (tester) async {
      for (final body in <String?>[null, 'خلي بالك من سمير']) {
        await TurnShellHarness.pump(
          tester,
          role: Role.citizen,
          prompt: 'اختر لاعبًا',
          whispersEnabled: true,
          whisperBody: body,
        );
        await driveToConfirmed(tester);
        expect(find.byKey(TurnShell.slotWhisper), findsOneWidget,
            reason: 'body=$body');
      }
    });

    testWidgets('the empty state is a sentence, not blank space',
        (tester) async {
      await TurnShellHarness.pump(
        tester,
        role: Role.citizen,
        prompt: 'اختر لاعبًا',
        whispersEnabled: true,
      );
      await driveToConfirmed(tester);
      expect(find.text('مفيش همسات ليك'), findsOneWidget);
    });

    testWidgets('the slot occupies the same rect either way', (tester) async {
      Map<String, Rect>? withWhisper;
      Map<String, Rect>? without;

      for (final body in <String?>[null, 'كلمة']) {
        await TurnShellHarness.pump(
          tester,
          role: Role.citizen,
          prompt: 'اختر لاعبًا',
          whispersEnabled: true,
          whisperBody: body,
        );
        await driveToConfirmed(tester);
        final rects = TurnShellHarness.slotRects(tester);
        if (body == null) {
          without = rects;
        } else {
          withWhisper = rects;
        }
      }

      expect(withWhisper, isNotNull);
      expect(without, equals(withWhisper),
          reason: 'every reserved slot must land in the same place whether or '
              'not a whisper is waiting — including the ones below it, which '
              'a card that grew would push down the screen');
    });

    testWidgets('the widget skeleton is identical either way', (tester) async {
      List<String>? withWhisper;
      List<String>? without;

      for (final body in <String?>[null, 'كلمة']) {
        await TurnShellHarness.pump(
          tester,
          role: Role.citizen,
          prompt: 'اختر لاعبًا',
          whispersEnabled: true,
          whisperBody: body,
        );
        await driveToConfirmed(tester);
        final skeleton = TurnShellHarness.skeleton(tester);
        if (body == null) {
          without = skeleton;
        } else {
          withWhisper = skeleton;
        }
      }

      expect(without, equals(withWhisper),
          reason: 'only the text inside the card may differ; a whisper must '
              'not add or remove a single widget');
    });

    testWidgets('every role gets it, and gets it in the same place',
        (tester) async {
      Map<String, Rect>? reference;
      for (final role in Role.values) {
        await TurnShellHarness.pump(
          tester,
          role: role,
          prompt: TurnShellHarness.naturalPrompt(role),
          whispersEnabled: true,
          // Only one role is given a whisper, which is the harder case: if the
          // card varied by *anything* structural, this is where it would show.
          whisperBody: role == Role.detective ? 'ركّز مع ليلى' : null,
        );
        await driveToConfirmed(tester);
        final rects = TurnShellHarness.slotRects(tester);
        expect(rects.containsKey('whisper'), isTrue, reason: role.name);
        reference ??= rects;
        expect(rects['whisper'], equals(reference['whisper']),
            reason: '${role.name} put the whisper card somewhere else');
      }
    });

    testWidgets('a match with the layer off has no slot at all, for anybody',
        (tester) async {
      // The one permitted variation, and it is match-level: with whispers off
      // nobody has the card, so nothing about a seat can be read from its
      // absence.
      for (final role in Role.values) {
        await TurnShellHarness.pump(
          tester,
          role: role,
          prompt: TurnShellHarness.naturalPrompt(role),
        );
        await driveToConfirmed(tester);
        expect(find.byKey(TurnShell.slotWhisper), findsNothing,
            reason: role.name);
      }
    });
  });

  group('the card is only readable once the turn is under way', () {
    testWidgets('nothing is shown during the handoff', (tester) async {
      await TurnShellHarness.pump(
        tester,
        role: Role.citizen,
        prompt: 'اختر لاعبًا',
        whispersEnabled: true,
        whisperBody: 'سرّ',
      );
      // The phone is still being passed. Whoever is holding it may not be the
      // recipient, and a whisper on the handoff screen would be readable by
      // the person carrying the phone across the table (L-13).
      expect(find.text('سرّ'), findsNothing);
      expect(find.byKey(TurnShell.slotWhisper), findsOneWidget,
          reason: 'the reservation exists in every state; only its contents '
              'wait');
    });

    testWidgets('the read is reported once, and only when it is shown',
        (tester) async {
      var reads = 0;
      await TurnShellHarness.pump(
        tester,
        role: Role.citizen,
        prompt: 'اختر لاعبًا',
        whispersEnabled: true,
        whisperBody: 'سرّ',
        onWhisperRead: () => reads++,
      );
      expect(reads, isZero);

      await driveToConfirmed(tester);
      await tester.pump();
      expect(reads, equals(1));

      await tester.pump(const Duration(seconds: 5));
      expect(reads, equals(1), reason: 'delivery is recorded once, not once a '
          'frame');
    });

    testWidgets('an empty card reports no read', (tester) async {
      var reads = 0;
      await TurnShellHarness.pump(
        tester,
        role: Role.citizen,
        prompt: 'اختر لاعبًا',
        whispersEnabled: true,
        onWhisperRead: () => reads++,
      );
      await driveToConfirmed(tester);
      await tester.pump();
      expect(reads, isZero);
    });
  });

  group('choosing nobody', () {
    testWidgets('the control exists for every role and unlocks together',
        (tester) async {
      for (final role in Role.values) {
        await TurnShellHarness.pump(
          tester,
          role: role,
          prompt: TurnShellHarness.naturalPrompt(role),
          onSkip: () {},
        );
        await TurnShellHarness.completeHold(tester);

        final locked = tester.widget<TextButton>(
          find.byKey(TurnShell.skipButton),
        );
        expect(locked.onPressed, isNull,
            reason: '${role.name}: skip is behind the same dwell as confirm');

        await tester.pump(const Duration(seconds: 9));
        final open = tester.widget<TextButton>(
          find.byKey(TurnShell.skipButton),
        );
        expect(open.onPressed, isNotNull, reason: role.name);
      }
    });

    testWidgets('taking it records the turn without a target', (tester) async {
      var skipped = 0;
      var confirmed = 0;
      await TurnShellHarness.pump(
        tester,
        role: Role.doctor,
        prompt: 'اختر لاعبًا',
        onSkip: () => skipped++,
        onConfirmed: (_) => confirmed++,
      );
      await TurnShellHarness.completeHold(tester);
      await tester.pump(const Duration(seconds: 9));
      await tester.tap(find.byKey(TurnShell.skipButton));
      await tester.pump();

      expect(skipped, equals(1));
      expect(confirmed, isZero);
      // The turn is now in its pass phase, on the same floor as any other.
      expect(find.byKey(TurnShell.skipButton), findsNothing);
    });
  });
}
