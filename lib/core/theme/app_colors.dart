/// The app's palette, measured from the four painted card faces.
///
/// Every value here was printed by `tool/extract_palette.dart`, which pools
/// every pixel of all four shipped faces, sorts the pile by Rec. 709 luminance,
/// and averages the pixels around a fixed percentile. Re-run it after replacing
/// the art:
///
///     flutter test tool/extract_palette.dart
///
/// ## Why the palette is measured and not chosen
///
/// The paintings are the product. A palette invented alongside them drifts from
/// them the first time the art changes, and the drift reads worse than an
/// obvious mismatch: the eye keeps trying to reconcile an app that looks
/// *almost* like the cards it is showing.
///
/// ## Why one palette and not four
///
/// All four cards are the same monochrome noir register — the measured columns
/// for mafia, doctor, detective and citizen agree to within a few levels at
/// every band. Nothing here varies by role, and nothing may. That is this
/// layer's own answer to Article I: a palette that *cannot* vary by role cannot
/// leak one.
///
/// ## Where these are allowed to be used
///
/// Here and in `lib/ui/theme/design_tokens.dart`, nowhere else. Constitution
/// Article IV: screens and widgets read semantic tokens off the theme
/// (`context.colors.surfaceBase`), never a swatch. This file is what those
/// tokens are made of, not a second way to reach them.
library;

import 'package:flutter/material.dart';

/// Palette tones measured from the card art, darkest to lightest.
///
/// The names describe what each tone *is* on the cards rather than what it
/// *does* in the app, so a designer can hold a printed card next to the screen
/// and see that they are the same colours.
abstract final class AppColors {
  /// The near-black inside the hoods and the deepest coat shadows.
  /// Measured at the 3rd percentile: luminance 1.7 / 255.
  ///
  /// **Not the app's ground** — see [groundBase]. This is the colour the card
  /// box is letterboxed against, and `card_ground` in `tool/manifest.json` must
  /// stay equal to it. The bars either side of a painting are invisible only
  /// because they match the painting's own near-black outer edge; the moment
  /// they do not, they become a frame that is *wider on the mafia card* than on
  /// the other three, because that painting covers 76% of the box and the rest
  /// cover 89%. That is a role tell no luminance budget would catch, since the
  /// pipeline gains the ground along with the art.
  static const Color deepestShadow = Color(0xFF010201);

  /// The app's ground on every screen, private and table alike.
  ///
  /// # Why this is not measured, and why it is not the measured black
  ///
  /// Every other colour in this file comes off the paintings. The four ground
  /// tones are a product decision: the measured 3rd-percentile black
  /// ([deepestShadow]) is what the *inside of a hood* looks like, and a UI built
  /// entirely on it has no headroom to raise a panel off the ground. So the
  /// ground sits a few levels above it and the ladder steps up from there.
  ///
  /// # Why it is cool and not warm
  ///
  /// Doc 05 rule 3: no warm colour at night. 13/15/20 — the blue channel leads,
  /// which is the direction away from skin tone. A warm ground is conspicuous on
  /// a face across a dark table, and the whole point of this app is that the
  /// person opposite you learns nothing from the light coming off your screen.
  ///
  /// An earlier revision made this ground warm tanned leather (`#241C14`) and
  /// logged the deviation as a trade-off. That has been reverted: the ground is
  /// near-black again on every screen, and rule 3 holds in its original form.
  static const Color groundBase = Color(0xFF0D0F14);

  /// The coat bodies and interior folds. 22nd percentile, luminance 8.0.
  ///
  /// Kept as the measured value because it is still the right colour for the
  /// *card* interior. It is no longer the panel colour — see [groundRaised].
  static const Color midCharcoal = Color(0xFF080808);

  /// Panels and tiles, one step up from the ground.
  ///
  /// Derived from [groundBase] rather than measured, for the same reason the
  /// ground is: a panel has to sit *above* the surface it is on. The measured
  /// charcoal is darker than the ground, so using it made every panel look like
  /// a hole cut in the table.
  static const Color groundRaised = Color(0xFF161A22);

  /// Dialogs, sheets and pressed states, one step up again.
  static const Color groundOverlay = Color(0xFF1F2530);

  /// Hairlines. Light enough to draw an edge, dark enough to stay a hairline
  /// rather than a highlight.
  ///
  /// These four tones are one hue family at four brightnesses — the blue
  /// channel leads at every step, by the same few levels. That is what keeps the
  /// ladder from acquiring a cast as it climbs.
  static const Color groundBorder = Color(0xFF2A3140);

  /// The ornament shadows and secondary detail in the painted frames.
  /// 45th percentile, luminance 19.3.
  ///
  /// Overlay surfaces and the pressed state of dark controls.
  static const Color graphite = Color(0xFF141314);

  /// The beadwork highlights and frame edge detail. 72nd percentile,
  /// luminance 88.0.
  ///
  /// Borders and dividers. On a ground this dark the hairline around a card is
  /// what gives it an edge at all, so this is deliberately well clear of the
  /// surfaces rather than a whisper above them.
  static const Color paleSilver = Color(0xFF5A5852);

  /// The dimmest tone still legible as text. 84th percentile, luminance 140.
  ///
  /// Disabled controls, tertiary labels, placeholders.
  static const Color mutedGrey = Color(0xFF908C82);

  /// Receding card detail. 92nd percentile, luminance 168.
  ///
  /// Body text and secondary information — clearly subordinate to bone white
  /// and still far above the 4.5:1 Article VII floor on any surface here.
  static const Color secondaryGrey = Color(0xFFADA89E);

  /// The painted card border and its aged-paper ground. 96.5th percentile,
  /// luminance 188.
  ///
  /// The app's one accent, used for buttons and active states. It measures
  /// close to neutral because the paintings *are* close to neutral; the warmth
  /// people read into a parchment border is mostly its brightness against the
  /// charcoal, not its hue.
  static const Color agedParchment = Color(0xFFC1BCB1);

  /// The brightest highlights — the beadwork catch-light, the pale edge of a
  /// lapel, the printing on the card itself.
  ///
  /// The app's primary text colour, and the colour of the role name beneath
  /// the card.
  ///
  /// The one value in this file taken from the brief rather than straight off a
  /// percentile: the measured band runs from `0xFFE4DED2` at the 99.5th to
  /// `0xFFF6EEE3` at the 99.8th, and this sits inside it. The top of that range
  /// is skewed by the mafia painting, which is the darkest of the four and
  /// therefore carries the largest normalising gain, pushing its own highlights
  /// toward clipping. Picking from inside the range rather than at the very top
  /// keeps the text colour a property of the deck rather than of one card.
  static const Color boneWhite = Color(0xFFE9E4D9);

  /// Cast shadow beneath raised panels.
  ///
  /// Not a measured tone — there is no such thing as a shadow *colour* in a
  /// painting, only darker paint. On a near-black ground a Material elevation
  /// model has no headroom to work with, so depth comes from something that
  /// genuinely darkens what is behind the panel.
  static const Color shadow = Color(0x8C000000);
}
