import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import 'artwork.dart';
import 'localized.dart';

/// Shared driver for the US2 symmetry and timing-parity suites.
///
/// Everything here is intentionally deterministic: a fixed surface size, a fixed
/// pump schedule, and no wall-clock reads. Two runs that differ only in [Role]
/// must therefore produce byte-identical frames — which is the property under
/// test, not an accident of the harness.
class TurnShellHarness {
  static const Key boundaryKey = ValueKey('turn_shell_boundary');
  static const Size surface = Size(390, 844);

  /// Neutral, role-independent target list used by every scenario.
  ///
  /// Latin names, which is fine for the structural suites: every role gets the
  /// same string, so whatever it costs in ink it costs four times. Any suite
  /// that measures *light* wants [arabicTargets] instead — see there.
  static const List<NightChoice> targets = [
    NightChoice(seat: 0, label: 'Seat 0'),
    NightChoice(seat: 1, label: 'Seat 1'),
    NightChoice(seat: 2, label: 'Seat 2'),
    NightChoice(seat: 3, label: 'Seat 3'),
  ];

  /// The same four seats under Arabic names, for suites that measure emitted
  /// light rather than structure.
  ///
  /// # Why this exists, and why it is not "making the test pass"
  ///
  /// The detective is the one role whose post-confirm panel shows something
  /// other than the seat name it just tapped: it shows a verdict, `مافيا`. So a
  /// luminance comparison across roles is really a comparison between the
  /// detective's Arabic verdict and everyone else's *seat name*.
  ///
  /// With [targets] that seat name is `Seat 1` — Latin, rendered in Bebas Neue.
  /// The verdict is Arabic, rendered in Cairo. Those two strings do not carry
  /// the same amount of ink, so the measurement reports a difference that comes
  /// from the *script the harness chose*, not from anything the app does. The
  /// app is Arabic-first (`locale: ar`, and every other string this harness
  /// feeds the shell already comes from `arStrings`); a player name in a real
  /// match is an Arabic word, exactly like the verdict.
  ///
  /// Measured on the shipped ground, `confirmed` state: Latin seat names put the
  /// detective 2.35% off the set mean, Arabic ones put it at 0.40%. The budget
  /// is ±2% and has not moved. What moved is that the stimulus now matches what
  /// ships — which is the only reason the old number was ever interesting.
  static const List<NightChoice> arabicTargets = [
    NightChoice(seat: 0, label: 'سمير'),
    NightChoice(seat: 1, label: 'أحمد'),
    NightChoice(seat: 2, label: 'منى'),
    NightChoice(seat: 3, label: 'ليلى'),
  ];

  /// The same four seats plus the special tile every role's grid ends with
  /// (doc 14 §1.3), which is what a real night screen actually renders.
  static List<NightChoice> withSpecial(
    Role role, {
    List<NightChoice> seats = arabicTargets,
    bool spent = false,
  }) => [
    ...seats,
    if (role == Role.doctor)
      NightChoice(
        seat: 99,
        // The shipped words, not a stand-in name. The Doctor's tile used
        // to read their own name and now reads the self-protection, and a
        // harness holding the old string would let the luminance suites
        // keep measuring copy the app no longer draws.
        label: EngineCopy.nightSpecial(arStrings, Role.doctor),
        special: true,
        spent: spent,
      )
    else
      NightChoice(
        seat: NightChoice.skipSeat,
        label: EngineCopy.nightSpecial(arStrings, role),
        special: true,
        spent: spent && role == Role.mafia,
      ),
  ];

  /// The prompt each role is really shown.
  ///
  /// Delegates to the shipped copy rather than keeping a second set: a local
  /// copy would let the tests keep passing while the app's actual prompts
  /// drifted out of balance, which is exactly the leak the luminance budget
  /// exists to catch.
  static String naturalPrompt(Role role) =>
      EngineCopy.nightPrompt(arStrings, role);

  static int _turnCounter = 0;

  /// Mounts a [TurnShell] at a fixed surface size, wrapped in a repaint
  /// boundary so frames can be captured.
  ///
  /// Each call gets a fresh `turnId`, so re-pumping inside a single test really
  /// does start a new turn instead of silently reusing the previous [State].
  static Future<void> pump(
    WidgetTester tester, {
    required Role role,
    required String prompt,
    String playerName = 'Player',
    String? confirmationDetail,
    List<NightChoice> targetList = targets,
    ValueChanged<int>? onConfirmed,
    VoidCallback? onPass,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: localizedApp(
          TurnShell(
            labels: TurnShellLabels.of(arStrings),
            turnId: 'turn-${_turnCounter++}',
            playerName: playerName,
            role: role,
            promptText: prompt,
            choices: targetList,
            confirmationDetail: confirmationDetail,
            onConfirmed: onConfirmed ?? (_) {},
            onPass: onPass ?? () {},
          ),
        ),
      ),
    );

    // The shell paints on `AppBackdrop`, which decodes the canvas weave. Without
    // waiting for that decode the first role measured renders on bare charcoal
    // and every later role renders on the texture — which reads as a 4%
    // brightness difference *between roles* and is indistinguishable from a real
    // leak. It is not one; it is measurement order. Wait for the bytes.
    await loadArtwork(tester);
  }

  /// Completes the hold-to-reveal gesture. Returns with the shell in
  /// [TurnShellState.revealed] at turn-time `t = 0`.
  static Future<void> completeHold(WidgetTester tester) async {
    final pad = find.byKey(TurnShell.holdPad);
    final gesture = await tester.startGesture(tester.getCenter(pad));
    await tester.pump(); // start the hold animation
    await tester.pump(MafiaTiming.defaults.holdToReveal); // t = 0 for the turn
    await gesture.up();
    await tester.pump();
  }

  /// Captures the current frame as raw RGBA bytes.
  ///
  /// Rasterisation has to happen on the real async zone (this is what
  /// `matchesGoldenFile` does internally), hence [WidgetTester.runAsync].
  static Future<Uint8List> capture(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final bytes = await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return data!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    });
    return bytes!;
  }

  /// A structural fingerprint of the mounted tree: widget types and nesting
  /// only, with no text metrics. Two roles must always produce the same list.
  static List<String> skeleton(WidgetTester tester) {
    final out = <String>[];
    void visit(Element element, int depth) {
      out.add('${'  ' * depth}${element.widget.runtimeType}');
      element.visitChildren((child) => visit(child, depth + 1));
    }

    visit(tester.element(find.byType(TurnShell)), 0);
    return out;
  }

  /// The rects of the reserved layout slots. These must be identical across
  /// roles even when the copy inside them differs (L-01, L-02).
  static Map<String, Rect> slotRects(WidgetTester tester) {
    const slots = <String, Key>{
      'header': TurnShell.slotHeader,
      'rail': TurnShell.slotRail,
      'body': TurnShell.slotBody,
      'detail': TurnShell.slotDetail,
      'action': TurnShell.slotAction,
      'footnote': TurnShell.slotFootnote,
    };
    return {
      for (final entry in slots.entries)
        if (find.byKey(entry.value).evaluate().isNotEmpty)
          entry.key: tester.getRect(find.byKey(entry.value)),
    };
  }

  /// Whether the primary action button is currently enabled.
  static bool actionEnabled(WidgetTester tester) {
    final button = tester.widget<FilledButton>(
      find.byKey(TurnShell.actionButton),
    );
    return button.onPressed != null;
  }
}
