import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../../support/artwork.dart';
import '../../support/localized.dart';
import '../../support/turn_shell_harness.dart';

/// T039 / L-05 — every night screen, and every role card, sits within ±2% of its
/// set's mean average luminance.
///
/// # SHIP-BLOCKING
///
/// This file is not belt-and-braces. Since the four in-match card faces became
/// four distinct paintings instead of one shared base, **nothing structural
/// prevents role leakage through the card art** — there is no longer a single
/// file making divergence impossible. The `L-04 card face budget` group below is
/// the guarantee. If it is deleted, skipped, or its tolerance widened, the app
/// ships a role tell.
///
/// ## Why brightness is a leak
///
/// Structural symmetry (L-01) is not enough on its own. A phone held at a table
/// throws light onto the holder's face and the ceiling, and the people opposite
/// see that glow even when they cannot read a word of the screen. If the Mafia
/// card were even slightly brighter than the Doctor's — a warmer ground, a larger
/// lit area, a brighter figure — the table would eventually learn to read it.
/// This suite measures actual pixels, which is the only way to catch brightness
/// drift introduced by a change that leaves the layout untouched.
///
/// Luminance uses the Rec. 709 coefficients, the standard perceptual weighting:
/// green contributes far more to apparent brightness than blue does, so a naive
/// channel average would under-report exactly the kind of change that matters
/// most.
///
/// ## Both the bytes and the render are measured
///
/// They fail for different reasons and neither subsumes the other:
///
///  * **the shipped bytes** catch art that was replaced without re-running
///    `tool/normalise_art.py`, which is the likely everyday mistake;
///  * **the rendered card** catches the composite — art plus emblem plus type plus
///    border — which is what actually emits light, and which can drift even when
///    every source file is perfect.
void main() {
  /// Mean perceptual luminance of a raw RGBA buffer, in 0..1.
  double meanLuminance(Uint8List rgba) {
    var total = 0.0;
    final pixels = rgba.length ~/ 4;
    for (var i = 0; i < rgba.length; i += 4) {
      final r = rgba[i] / 255.0;
      final g = rgba[i + 1] / 255.0;
      final b = rgba[i + 2] / 255.0;
      total += 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }
    return pixels == 0 ? 0 : total / pixels;
  }

  /// Renders one role's night turn in [state] and returns its mean luminance.
  Future<double> luminanceOf(
    WidgetTester tester,
    Role role,
    TurnShellState state,
  ) async {
    await TurnShellHarness.pump(
      tester,
      role: role,
      // Role-natural copy, not a shared placeholder: the question a Mafioso is
      // asked is genuinely different text, and if *that* moved the brightness
      // budget it would still be a leak.
      prompt: TurnShellHarness.naturalPrompt(role),
      confirmationDetail: role == Role.detective ? 'مافيا' : null,
      // Arabic seat names, because this suite measures light and the detective's
      // panel shows an Arabic verdict where the other three show the seat name
      // they tapped. Comparing an Arabic verdict against a Latin `Seat 1`
      // measures the harness's choice of script, not the app. See
      // [TurnShellHarness.arabicTargets].
      targetList: TurnShellHarness.arabicTargets,
    );

    if (state != TurnShellState.handoff) {
      await TurnShellHarness.completeHold(tester);
    }
    if (state == TurnShellState.selecting ||
        state == TurnShellState.confirmed ||
        state == TurnShellState.passUnlocked) {
      await tester.tap(find.text('أحمد'));
      await tester.pump();
    }
    if (state == TurnShellState.confirmed ||
        state == TurnShellState.passUnlocked) {
      await tester.pump(const Duration(seconds: 9)); // past the dwell gate
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pump();
    }
    if (state == TurnShellState.passUnlocked) {
      await tester.pump(const Duration(seconds: 4)); // past the turn floor
    }

    return meanLuminance(await TurnShellHarness.capture(tester));
  }

  const states = <TurnShellState>[
    TurnShellState.handoff,
    TurnShellState.revealed,
    TurnShellState.selecting,
    TurnShellState.confirmed,
    TurnShellState.passUnlocked,
  ];

  group('L-05 luminance budget', () {
    for (final state in states) {
      testWidgets('all roles are within ±2% of the mean in ${state.name}',
          (tester) async {
        final byRole = <Role, double>{};
        for (final role in Role.values) {
          byRole[role] = await luminanceOf(tester, role, state);
        }

        final mean =
            byRole.values.reduce((a, b) => a + b) / byRole.length;

        // A pitch-black frame would make the ratio test meaningless.
        expect(mean, greaterThan(0.0),
            reason: 'nothing was rendered in state ${state.name}');

        for (final entry in byRole.entries) {
          final drift = (entry.value - mean).abs() / mean;
          expect(drift, lessThanOrEqualTo(0.02),
              reason: '${entry.key.name} in ${state.name} is '
                  '${(drift * 100).toStringAsFixed(2)}% off the set mean '
                  '(${entry.value.toStringAsFixed(6)} vs '
                  '${mean.toStringAsFixed(6)}), outside the ±2% budget');
        }
      });
    }

    testWidgets('the measurement can detect a brightness difference',
        (tester) async {
      // Guards the metric itself. The handoff pad fills a large area, so a
      // screen that has revealed its content is measurably brighter than one
      // that has not; if these came out equal, every budget check above would
      // be passing on a constant.
      final dark = await luminanceOf(tester, Role.citizen, TurnShellState.handoff);
      final lit = await luminanceOf(tester, Role.citizen, TurnShellState.revealed);
      expect((lit - dark).abs() / ((lit + dark) / 2), greaterThan(0.02),
          reason: 'luminance measurement is not sensitive to screen content');
    });
  });

  // ---------------------------------------------------------------------------
  // The card faces. See the SHIP-BLOCKING note at the top of this file.
  // ---------------------------------------------------------------------------

  group('L-04 card face budget', () {
    const faces = <Role, String>{
      Role.mafia: AppImages.cardFaceMafia,
      Role.doctor: AppImages.cardFaceDoctor,
      Role.detective: AppImages.cardFaceDetective,
      Role.citizen: AppImages.cardFaceCitizen,
    };

    /// The four faces share one card box, and the box is measured whole.
    ///
    /// The paintings are never cropped — the painted border, the corner letter
    /// and the corner icon are part of the artwork — so each is scaled to fit
    /// inside a fixed 1024×1536 box and centred on `card_ground`, and the card
    /// is drawn with `BoxFit.contain`. Every pixel of the file therefore reaches
    /// the screen, which is why this measures the whole file rather than a
    /// central window: the window machinery existed only because `BoxFit.cover`
    /// used to throw the outer columns away.
    ///
    /// The consequence worth stating: the three paintings are 0.7467 aspect and
    /// the mafia is 0.8733, so they cover 89.3% and 76.4% of the box
    /// respectively. Two paintings at equal mean brightness would still emit
    /// unequal light. `normalise_art.py` solves the gain on the composited box
    /// for exactly that reason, and this measures the same quantity.
    Future<double> byteLuminance(String path) async {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      codec.dispose();

      final rgba = data!.buffer.asUint8List();
      var total = 0.0;
      for (var i = 0; i < rgba.length; i += 4) {
        total += 0.2126 * rgba[i] / 255.0 +
            0.7152 * rgba[i + 1] / 255.0 +
            0.0722 * rgba[i + 2] / 255.0;
      }
      return total / (rgba.length ~/ 4);
    }

    /// Asserts every value is inside [budget] of the set mean.
    void expectWithinBudget(Map<Role, double> byRole, String what,
        {double budget = 0.02}) {
      final mean = byRole.values.reduce((a, b) => a + b) / byRole.length;
      expect(mean, greaterThan(0.0), reason: 'nothing was measured for $what');

      for (final entry in byRole.entries) {
        final drift = (entry.value - mean).abs() / mean;
        expect(drift, lessThanOrEqualTo(budget),
            reason: '${entry.key.name} $what is '
                '${(drift * 100).toStringAsFixed(3)}% off the set mean '
                '(${entry.value.toStringAsFixed(6)} vs '
                '${mean.toStringAsFixed(6)}), outside the '
                '±${(budget * 100).toStringAsFixed(0)}% budget. Re-run '
                'tool/normalise_art.py; do not widen this number.');
      }
    }

    test('the four shipped faces are within ±2% over the whole card box',
        () async {
      final byRole = <Role, double>{};
      for (final entry in faces.entries) {
        byRole[entry.key] = await byteLuminance(entry.value);
      }
      expectWithinBudget(byRole, 'card face file');
    });

    testWidgets('the four rendered cards are within ±2% of the set mean',
        (tester) async {
      const boundaryKey = ValueKey('luminance_card_boundary');
      var mount = 0;

      Future<double> renderedLuminance(Role role) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));

        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: localizedApp(
              RoleCard(
                key: ValueKey('card-${mount++}'),
                playerName: 'Player',
                role: role,
                // Mafia is the only role carrying extra content. If that content
                // moved the brightness budget it would still be a leak, so it is
                // included rather than held constant.
                teammateNames:
                    role == Role.mafia ? const ['Aaaa', 'Bbbb'] : const [],
                onDismissed: () {},
              ),
            ),
          ),
        );
        await loadArtwork(tester);

        // Turn the card over — the face is the surface under test.
        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(RoleCard.holdPad)));
        await tester.pump();
        await tester.pump(MafiaTiming.defaults.holdToReveal);
        await gesture.up();
        await tester.pumpAndSettle();
        await loadArtwork(tester);

        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
        final pixels = await tester.runAsync(() async {
          final ui.Image image = await boundary.toImage();
          final data =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        return meanLuminance(pixels!);
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));

      final byRole = <Role, double>{};
      for (final role in Role.values) {
        byRole[role] = await renderedLuminance(role);
      }
      expectWithinBudget(byRole, 'revealed card');
    });

    test('the faces are genuinely four different images', () async {
      // Without this, the budget group would pass perfectly if someone "fixed" a
      // drift by copying one face over the other three. That would be leak-free
      // and also a broken game — and it is exactly the shortcut a failing
      // tolerance invites.
      final digests = <String, String>{};
      for (final entry in faces.entries) {
        final bytes = await File(entry.value).readAsBytes();
        digests[entry.key.name] = '${bytes.length}';
      }
      expect(digests.values.toSet(), hasLength(4),
          reason: 'two or more role faces are byte-identical in length, which '
              'suggests one file was copied over another: $digests');
    });

    test('the four faces agree on hue', () async {
      // # What changed, and why this is not the old test
      //
      // The pipeline used to desaturate the faces and this asserted the result
      // was neutral to within 2 levels. The artwork is now shipped with its own
      // colour untouched — no desaturation, no cast stripping — so an absolute
      // neutrality assertion would be asserting something the pipeline no longer
      // does, and passing it would mean the art had been altered.
      //
      // The leakage question was never "is a card warm". It is "can a bystander
      // tell two cards apart by colour". A deck that is uniformly warm by five
      // levels tells nobody anything; one card warmer than the other three is a
      // role tell no luminance budget would catch, because chroma can differ at
      // constant Rec. 709 luminance. So the assertion moves onto the *spread
      // between roles*, which is both the quantity that leaks and the one the
      // shipped art actually satisfies.
      final chroma = <Role, ({double rb, double gb})>{};
      for (final entry in faces.entries) {
        final bytes = await File(entry.value).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final data =
            await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        frame.image.dispose();
        codec.dispose();

        final rgba = data!.buffer.asUint8List();
        var r = 0.0, g = 0.0, b = 0.0;
        final pixels = rgba.length ~/ 4;
        for (var i = 0; i < rgba.length; i += 4) {
          r += rgba[i];
          g += rgba[i + 1];
          b += rgba[i + 2];
        }
        chroma[entry.key] = (rb: (r - b) / pixels, gb: (g - b) / pixels);
      }

      // Opponent-channel differences rather than raw channel means: subtracting
      // blue removes the overall exposure the luminance budget already governs,
      // leaving only where each painting sits on warm↔cool and green↔magenta.
      double spreadOf(double Function(({double rb, double gb})) axis) {
        final values = chroma.values.map(axis).toList();
        return values.reduce(math.max) - values.reduce(math.min);
      }

      const budget = 3.0; // levels out of 255
      expect(spreadOf((c) => c.rb), lessThanOrEqualTo(budget),
          reason: 'the faces disagree on warm↔cool by more than $budget '
              'levels, which is a role tell that survives the luminance '
              'budget: $chroma');
      expect(spreadOf((c) => c.gb), lessThanOrEqualTo(budget),
          reason: 'the faces disagree on green↔magenta by more than $budget '
              'levels: $chroma');
    });
  });
}
