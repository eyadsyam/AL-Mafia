import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

/// L-05 / doc 05 rule 3 — the four role accents carry the same amount of light.
///
/// ## Why a colour test and not just the rendered-luminance test
///
/// `luminance_budget_test.dart` measures whole night screens, where the role
/// accent is a few hundred pixels of border and heading against a mostly dark
/// frame. A crimson that is twice as bright as the others moves that average by
/// a fraction of a percent and slips under the ±2% budget — while still being
/// plainly the brightest thing on the card to anyone glancing at the holder's
/// face from across the table.
///
/// So the accents are constrained directly, at the token level, where the
/// difference is not diluted by everything around it.
///
/// ## Saturation, not just brightness
///
/// Two colours at identical Rec. 709 luminance are not equally conspicuous if
/// one is a saturated red and the others are greys — chroma draws the eye on its
/// own, and a red cast on a face is the specific failure doc 05's threat model
/// names. The saturation ceiling is therefore part of the contract, not a
/// stylistic preference.
void main() {
  const colors = MafiaColors.dark;

  final accents = <String, Color>{
    'roleMafia': colors.roleMafia,
    'roleDoctor': colors.roleDoctor,
    'roleDetective': colors.roleDetective,
    'roleCitizen': colors.roleCitizen,
  };

  /// Rec. 709 luminance in 0..255, the same weighting the pixel-level budget
  /// test uses.
  double luminance(Color c) =>
      0.2126 * (c.r * 255) + 0.7152 * (c.g * 255) + 0.0722 * (c.b * 255);

  group('role accent parity', () {
    test('all four accents sit within ±2% of their mean luminance', () {
      final values = {
        for (final e in accents.entries) e.key: luminance(e.value),
      };
      final mean = values.values.reduce((a, b) => a + b) / values.length;

      for (final entry in values.entries) {
        final drift = (entry.value - mean).abs() / mean;
        expect(
          drift,
          lessThanOrEqualTo(0.02),
          reason: 'LEAK: ${entry.key} is ${(drift * 100).toStringAsFixed(2)}% '
              'off the role-accent mean (${entry.value.toStringAsFixed(1)} vs '
              '${mean.toStringAsFixed(1)}). Re-match it before shipping — the '
              'brightest role accent is the one that shows on a face.',
        );
      }
    });

    test('no accent is materially more saturated than the others', () {
      // 0.30 is the cap the palette was solved against. A little headroom is
      // allowed for rounding to 8-bit channels.
      for (final entry in accents.entries) {
        final hsl = HSLColor.fromColor(entry.value);
        expect(
          hsl.saturation,
          lessThanOrEqualTo(0.34),
          reason: 'LEAK: ${entry.key} is ${hsl.saturation.toStringAsFixed(2)} '
              'saturated. Chroma is conspicuous independently of brightness.',
        );
      }
    });

    test('the accents are still four distinguishable colours', () {
      // Guards the opposite failure: matching them so hard they all collapse to
      // the same grey would pass every check above and make the card fronts
      // useless to the one person entitled to read them.
      expect(accents.values.toSet(), hasLength(4),
          reason: 'two role accents are now literally the same colour');
    });

    test('no night surface carries a warm cast', () {
      // Doc 05 rule 3, in its original form: **no warm colour at night.**
      //
      // The warm leather ground that once bent this rule has been reverted, and
      // so has the trade-off entry that logged the bend. What is asserted here
      // is the thing rule 3 actually protects — that no surface throws warm
      // light onto the holder's face — expressed as a direction rather than as
      // a tolerance.
      //
      // # Why this is a direction and not "neutral to within 6 levels"
      //
      // The original test asserted the channels agreed to within 6 levels, and
      // the ramp it was written against did not satisfy it: `#0D0F14` spread 7
      // levels and `#2A3140` spread 22, deliberately cool, on the argument that
      // cool is the direction away from skin tone. A literal neutrality bound
      // would have failed that palette for being too far in the *safe*
      // direction, which is the wrong shape of test — so this became a
      // direction instead.
      //
      // The ramp has since been neutralised (see `AppColors.groundBase`) at the
      // same luminances, because the cool surplus was visible as blue on every
      // panel and did not match the artwork. The direction still holds, now
      // with equality, and it is still the right shape: it admits a neutral
      // ramp and a cool one, rejects every warm one, and cannot be satisfied by
      // drifting toward amber. What it protects is the light on the holder's
      // face, and grey does not warm a face.
      final ladder = <String, Color>{
        'surfaceBase': colors.surfaceBase,
        'surfaceRaised': colors.surfaceRaised,
        'surfaceOverlay': colors.surfaceOverlay,
        'borderSubtle': colors.borderSubtle,
      };

      for (final entry in ladder.entries) {
        final c = entry.value;
        final r = c.r * 255, g = c.g * 255, b = c.b * 255;
        expect(b, greaterThanOrEqualTo(g),
            reason: 'LEAK (doc 05 rule 3): ${entry.key} has more green than '
                'blue (${r.round()}/${g.round()}/${b.round()}) — it is warming '
                'up. Night surfaces must lead with blue.');
        expect(g, greaterThanOrEqualTo(r),
            reason: 'LEAK (doc 05 rule 3): ${entry.key} has more red than '
                'green (${r.round()}/${g.round()}/${b.round()}). That is a warm '
                'cast on the holder\'s face.');
      }
    });

    test('every night surface sits on one hue', () {
      // The surfaces are one colour at four brightnesses, not four different
      // colours. A single surface drifting off that hue would be a glow with no
      // explanation, which is exactly what rule 3 is afraid of.
      final surfaces = <String, Color>{
        'surfaceBase': colors.surfaceBase,
        'surfaceRaised': colors.surfaceRaised,
        'surfaceOverlay': colors.surfaceOverlay,
      };

      final hues = <String, double>{
        for (final e in surfaces.entries)
          e.key: HSLColor.fromColor(e.value).hue,
      };

      final spread =
          hues.values.reduce(math.max) - hues.values.reduce(math.min);
      expect(spread, lessThanOrEqualTo(8.0),
          reason: 'the night surfaces are $spread degrees apart in hue '
              '($hues). They must be one colour at three brightnesses — a '
              'surface with its own hue reads as a light source.');

      // And they must genuinely be a *ladder*, not three shades of the same
      // level: a raised panel that does not read as raised sends players
      // hunting for the edge of every control.
      final levels = [
        for (final c in surfaces.values)
          0.2126 * (c.r * 255) + 0.7152 * (c.g * 255) + 0.0722 * (c.b * 255),
      ];
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i], greaterThan(levels[i - 1] + 4),
            reason: 'the surface ladder has collapsed: $levels');
      }
    });

    test('the accents stay far brighter than the ground they sit on', () {
      // Article VII wants 4.5:1 for secondary content; this is the cheap
      // structural check that the ladder did not close up underneath it. Kept
      // through the ground revert rather than dropped: the ground got darker,
      // which moves every ratio the safe way, and a check that only ever passes
      // is still the one that catches the next person who lightens it.
      double relative(Color c) {
        double channel(double v) =>
            v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
        return 0.2126 * channel(c.r) +
            0.7152 * channel(c.g) +
            0.0722 * channel(c.b);
      }

      double contrast(Color a, Color b) {
        final la = relative(a), lb = relative(b);
        final hi = math.max(la, lb), lo = math.min(la, lb);
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(contrast(colors.textPrimary, colors.surfaceBase),
          greaterThanOrEqualTo(7.0),
          reason: 'primary text no longer clears 7:1 on the ground '
              '(Article VII)');
      expect(contrast(colors.textSecondary, colors.surfaceBase),
          greaterThanOrEqualTo(4.5),
          reason: 'secondary text no longer clears 4.5:1 on the ground');
      expect(contrast(colors.textMuted, colors.surfaceRaised),
          greaterThanOrEqualTo(3.0),
          reason: 'muted text has disappeared into a raised panel');
    });
  });
}
