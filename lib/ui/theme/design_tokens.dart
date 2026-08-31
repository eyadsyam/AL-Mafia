import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Color palette tokens for Mafia Master.
class MafiaColors extends ThemeExtension<MafiaColors> {
  final Color surfaceBase;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentGold;
  final Color accentGoldPressed;
  final Color accentCrimson;
  final Color accentSage;

  /// The four role accents. **Post-game surfaces only.**
  ///
  /// These must not appear on any widget reachable while the phone is in a
  /// player's hand — not the role card, not the night turn, not a pass screen.
  /// A role-conditional colour is a role tell, and the card no longer uses one:
  /// the in-match emblem and border are `textPrimary` and `borderSubtle` for
  /// every role, so parity there is structural rather than balanced.
  ///
  /// Legitimate users are the result screen, the vote reveal (where the role has
  /// just been made public to everyone at once) and post-game analytics.
  /// `handoff_purity_test.dart` fails the build if a handoff-reachable file
  /// references one.
  final Color roleMafia;
  final Color roleDoctor;
  final Color roleDetective;
  final Color roleCitizen;

  /// Cast shadow beneath raised panels.
  ///
  /// Opaque-ish black rather than a tinted shade: on a near-black ground a
  /// Material-style light elevation model has no headroom, so depth has to come
  /// from a shadow that actually darkens what is behind the panel.
  final Color shadow;

  const MafiaColors({
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentGold,
    required this.accentGoldPressed,
    required this.accentCrimson,
    required this.accentSage,
    required this.roleMafia,
    required this.roleDoctor,
    required this.roleDetective,
    required this.roleCitizen,
    required this.shadow,
  });

  /// Sampled from the art direction reference — a painterly noir playing-card
  /// set — rather than picked by hand, so the app and the card artwork share one
  /// palette instead of two that nearly agree.
  ///
  /// ## One ground, everywhere
  ///
  /// The four surfaces are a single cool near-black hue family at four
  /// brightnesses — `#0F0F0F` / `#1A1A1A` / `#252525` / `#313131`. The blue
  /// channel leads at every step, which is the direction *away* from skin tone.
  ///
  /// There is deliberately no warm/cold register split any more. Doc 05 rule 3
  /// forbids warm colour at night, and a palette that is warm on the public
  /// screens and cool on the private ones makes the transition between them an
  /// event the whole table can see. One ground on every screen, private and
  /// table alike, is both simpler and the thing rule 3 actually asks for.
  ///
  /// [accentCrimson] and [accentSage] survive as *semantic* accents — elimination
  /// and safety on post-game surfaces — not as a register.
  ///
  /// ## Why the role accents look so close to each other
  ///
  /// They are luminance-matched on purpose: all four sit at Rec. 709 luminance
  /// 116 ± 0.2%, well inside the ±2% budget, with saturation capped so none of
  /// them reads as louder than the others. A saturated crimson for Mafia at the
  /// same *nominal* brightness still throws more light on the holder's face than
  /// a grey — matching the numbers is the only way to actually hold rule 3.
  /// `role_accent_parity_test.dart` fails the build if they drift.
  static const MafiaColors dark = MafiaColors(
    surfaceBase: AppColors.groundBase,
    surfaceRaised: AppColors.groundRaised,
    surfaceOverlay: AppColors.groundOverlay,
    borderSubtle: AppColors.groundBorder,
    textPrimary: AppColors.boneWhite,
    textSecondary: AppColors.secondaryGrey,
    textMuted: AppColors.mutedGrey,
    accentGold: AppColors.agedParchment,
    accentGoldPressed: Color(0xFF8D8169),
    accentCrimson: Color(0xFFAA3D28),
    accentSage: Color(0xFF6B7A63),
    roleMafia: Color(0xFF916D66),
    roleDoctor: Color(0xFF717573),
    roleDetective: Color(0xFF7D7361),
    roleCitizen: Color(0xFF767471),
    shadow: AppColors.shadow,
  );

  @override
  MafiaColors copyWith({
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? surfaceOverlay,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentGold,
    Color? accentGoldPressed,
    Color? accentCrimson,
    Color? accentSage,
    Color? roleMafia,
    Color? roleDoctor,
    Color? roleDetective,
    Color? roleCitizen,
    Color? shadow,
  }) {
    return MafiaColors(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentGold: accentGold ?? this.accentGold,
      accentGoldPressed: accentGoldPressed ?? this.accentGoldPressed,
      accentCrimson: accentCrimson ?? this.accentCrimson,
      accentSage: accentSage ?? this.accentSage,
      roleMafia: roleMafia ?? this.roleMafia,
      roleDoctor: roleDoctor ?? this.roleDoctor,
      roleDetective: roleDetective ?? this.roleDetective,
      roleCitizen: roleCitizen ?? this.roleCitizen,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  MafiaColors lerp(ThemeExtension<MafiaColors>? other, double t) {
    if (other is! MafiaColors) return this;
    return MafiaColors(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t) ?? surfaceBase,
      surfaceRaised:
          Color.lerp(surfaceRaised, other.surfaceRaised, t) ?? surfaceRaised,
      surfaceOverlay:
          Color.lerp(surfaceOverlay, other.surfaceOverlay, t) ?? surfaceOverlay,
      borderSubtle:
          Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      accentGold: Color.lerp(accentGold, other.accentGold, t) ?? accentGold,
      accentGoldPressed:
          Color.lerp(accentGoldPressed, other.accentGoldPressed, t) ??
          accentGoldPressed,
      accentCrimson:
          Color.lerp(accentCrimson, other.accentCrimson, t) ?? accentCrimson,
      accentSage: Color.lerp(accentSage, other.accentSage, t) ?? accentSage,
      roleMafia: Color.lerp(roleMafia, other.roleMafia, t) ?? roleMafia,
      roleDoctor: Color.lerp(roleDoctor, other.roleDoctor, t) ?? roleDoctor,
      roleDetective:
          Color.lerp(roleDetective, other.roleDetective, t) ?? roleDetective,
      roleCitizen: Color.lerp(roleCitizen, other.roleCitizen, t) ?? roleCitizen,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
    );
  }
}

/// The app's one light source, and the elevation it produces.
///
/// # Why this is a token and not three `BoxShadow`s written where they are used
///
/// Inconsistent light direction is the most common tell of an amateur
/// interface. Nobody can name it, but everyone feels it: one panel lit from
/// above, one card lit from the left, and the screen stops reading as a single
/// physical space. The app had three hand-written shadows with three different
/// offsets, which is exactly how that starts.
///
/// So there is one lamp — above and slightly to the left, consistent with a
/// light over a table — and elevation is expressed by shadow **size** only.
/// Direction never varies. The ratio of offset to blur is fixed, so a card at
/// level 3 looks like the same object at the same lamp as a tile at level 1,
/// just further off the surface.
class MafiaElevation extends ThemeExtension<MafiaElevation> {
  /// Panels and tiles: resting on the surface.
  final List<BoxShadow> level1;

  /// Selected tiles and buttons: lifted slightly.
  final List<BoxShadow> level2;

  /// Cards and dialogs: clearly held above everything.
  final List<BoxShadow> level3;

  const MafiaElevation({
    required this.level1,
    required this.level2,
    required this.level3,
  });

  /// The horizontal component, as a fraction of the vertical one. Negative
  /// because the lamp is to the *left*, so shadows fall to the right.
  static const double lightSkew = 0.35;

  static BoxShadow _step(Color shadow, double y, double blur, double alpha) =>
      BoxShadow(
        color: shadow.withValues(alpha: alpha),
        offset: Offset(y * lightSkew, y),
        blurRadius: blur,
      );

  /// Built from the palette's shadow colour so elevation and colour cannot
  /// drift apart.
  static MafiaElevation from(Color shadow) => MafiaElevation(
        level1: [_step(shadow, 2, 8, 0.20)],
        level2: [_step(shadow, 4, 16, 0.28)],
        level3: [_step(shadow, 12, 32, 0.40)],
      );

  @override
  MafiaElevation copyWith({
    List<BoxShadow>? level1,
    List<BoxShadow>? level2,
    List<BoxShadow>? level3,
  }) =>
      MafiaElevation(
        level1: level1 ?? this.level1,
        level2: level2 ?? this.level2,
        level3: level3 ?? this.level3,
      );

  @override
  MafiaElevation lerp(ThemeExtension<MafiaElevation>? other, double t) {
    if (other is! MafiaElevation) return this;
    return MafiaElevation(
      level1: BoxShadow.lerpList(level1, other.level1, t) ?? level1,
      level2: BoxShadow.lerpList(level2, other.level2, t) ?? level2,
      level3: BoxShadow.lerpList(level3, other.level3, t) ?? level3,
    );
  }
}

/// Spacing scale tokens.
class MafiaSpacing extends ThemeExtension<MafiaSpacing> {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double screenMargin;
  final double maxContentWidth;

  const MafiaSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.screenMargin,
    required this.maxContentWidth,
  });

  static const MafiaSpacing defaults = MafiaSpacing(
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
    screenMargin: 20,
    maxContentWidth: 480,
  );

  @override
  MafiaSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? screenMargin,
    double? maxContentWidth,
  }) {
    return MafiaSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      screenMargin: screenMargin ?? this.screenMargin,
      maxContentWidth: maxContentWidth ?? this.maxContentWidth,
    );
  }

  @override
  MafiaSpacing lerp(ThemeExtension<MafiaSpacing>? other, double t) {
    if (other is! MafiaSpacing) return this;
    return MafiaSpacing(
      xs: xs * (1 - t) + other.xs * t,
      sm: sm * (1 - t) + other.sm * t,
      md: md * (1 - t) + other.md * t,
      lg: lg * (1 - t) + other.lg * t,
      xl: xl * (1 - t) + other.xl * t,
      xxl: xxl * (1 - t) + other.xxl * t,
      screenMargin: screenMargin * (1 - t) + other.screenMargin * t,
      maxContentWidth: maxContentWidth * (1 - t) + other.maxContentWidth * t,
    );
  }
}

/// Border radius tokens.
class MafiaRadii extends ThemeExtension<MafiaRadii> {
  final double card;
  final double button;
  final double dialog;

  const MafiaRadii({
    required this.card,
    required this.button,
    required this.dialog,
  });

  static const MafiaRadii defaults = MafiaRadii(
    card: 16,
    button: 14,
    dialog: 20,
  );

  @override
  MafiaRadii copyWith({double? card, double? button, double? dialog}) {
    return MafiaRadii(
      card: card ?? this.card,
      button: button ?? this.button,
      dialog: dialog ?? this.dialog,
    );
  }

  @override
  MafiaRadii lerp(ThemeExtension<MafiaRadii>? other, double t) {
    if (other is! MafiaRadii) return this;
    return MafiaRadii(
      card: card * (1 - t) + other.card * t,
      button: button * (1 - t) + other.button * t,
      dialog: dialog * (1 - t) + other.dialog * t,
    );
  }
}

/// Motion duration and curve tokens.
class MafiaMotion extends ThemeExtension<MafiaMotion> {
  final Duration instant;
  final Duration quick;
  final Duration standard;
  final Duration dramatic;

  final Curve instantCurve;
  final Curve quickCurve;
  final Curve standardCurve;
  final Curve dramaticCurve;

  /// Scale a pressable surface shrinks to while held.
  ///
  /// Deliberately shallow. A press on an in-hand surface is watched by the
  /// people either side of the holder, and a big squash is a visible event they
  /// can count. This is enough to feel under the thumb and almost nothing to see
  /// from a metre away.
  final double pressScale;

  /// `Matrix4` entry (3,2) used for the card flip's perspective divisor.
  ///
  /// Lives here rather than in the widget so the one 3D effect in the app cannot
  /// acquire a second, differently-warped copy.
  final double perspective;

  /// Delay between successive items in a staggered entrance.
  ///
  /// Only ever applied to lists whose contents are already public — the vote
  /// tally and the post-game rows. Staggering anything role-derived would turn
  /// list position into a timing channel.
  final Duration stagger;

  const MafiaMotion({
    required this.instant,
    required this.quick,
    required this.standard,
    required this.dramatic,
    required this.instantCurve,
    required this.quickCurve,
    required this.standardCurve,
    required this.dramaticCurve,
    required this.pressScale,
    required this.perspective,
    required this.stagger,
  });

  static const MafiaMotion defaults = MafiaMotion(
    instant: Duration(milliseconds: 100),
    quick: Duration(milliseconds: 200),
    standard: Duration(milliseconds: 300),
    dramatic: Duration(milliseconds: 600),
    instantCurve: Curves.linear,
    quickCurve: Curves.easeOut,
    standardCurve: Curves.easeInOut,
    dramaticCurve: Curves.easeInOut,
    pressScale: 0.97,
    perspective: 0.0012,
    stagger: Duration(milliseconds: 40),
  );

  @override
  MafiaMotion copyWith({
    Duration? instant,
    Duration? quick,
    Duration? standard,
    Duration? dramatic,
    Curve? instantCurve,
    Curve? quickCurve,
    Curve? standardCurve,
    Curve? dramaticCurve,
    double? pressScale,
    double? perspective,
    Duration? stagger,
  }) {
    return MafiaMotion(
      instant: instant ?? this.instant,
      quick: quick ?? this.quick,
      standard: standard ?? this.standard,
      dramatic: dramatic ?? this.dramatic,
      instantCurve: instantCurve ?? this.instantCurve,
      quickCurve: quickCurve ?? this.quickCurve,
      standardCurve: standardCurve ?? this.standardCurve,
      dramaticCurve: dramaticCurve ?? this.dramaticCurve,
      pressScale: pressScale ?? this.pressScale,
      perspective: perspective ?? this.perspective,
      stagger: stagger ?? this.stagger,
    );
  }

  @override
  MafiaMotion lerp(ThemeExtension<MafiaMotion>? other, double t) {
    if (other is! MafiaMotion) return this;
    // Durations and Curves don't interpolate meaningfully, return this.
    return this;
  }
}

/// Turn-timing tokens.
///
/// These are the ONLY source of truth for the anti-leakage timing gates
/// (Constitution VI, leakage invariants L-07/L-08/L-09). They are global and
/// role-agnostic by construction: nothing in the widget layer may derive a
/// duration from a [Role].
class MafiaTiming extends ThemeExtension<MafiaTiming> {
  /// How long the identity pad must be held before the turn content is shown.
  final Duration holdToReveal;

  /// Minimum dwell after reveal before Confirm becomes enabled (L-07).
  final Duration dwellGate;

  /// Minimum total turn length, measured from reveal. The pass control unlocks
  /// at exactly this offset regardless of when the action was confirmed, so a
  /// fast actor and a slow actor produce the same observable turn length
  /// (L-08).
  final Duration turnFloor;

  /// Duration of the pass-to-next-player transition (L-09).
  final Duration passTransition;

  /// Minimum time a role card stays face-up before its dismiss control
  /// activates, measured from the flip. Role-invariant, so the length of a
  /// player's distribution turn says nothing about what they drew (L-04, L-08).
  final Duration revealFloor;

  /// How long the card stays face-up before auto-concealing. The card flips
  /// back to its back face after this duration. The player may swipe again to
  /// re-reveal. Role-invariant — every player gets the same window.
  final Duration autoRevealDuration;

  /// How long a full-screen phase announcement holds at full opacity, between
  /// its fade in and its fade out.
  ///
  /// The same for every announcement. These are on-table moments, so the number
  /// is not a leakage constraint in the way the turn gates are — but a night
  /// that lingered longer than a morning would still teach the table to read the
  /// pause before the words arrive, and there is nothing to gain by varying it.
  final Duration phaseHold;

  const MafiaTiming({
    required this.holdToReveal,
    required this.dwellGate,
    required this.turnFloor,
    required this.passTransition,
    required this.revealFloor,
    required this.autoRevealDuration,
    required this.phaseHold,
  });

  static const MafiaTiming defaults = MafiaTiming(
    holdToReveal: Duration(milliseconds: 600),
    dwellGate: Duration(seconds: 8),
    turnFloor: Duration(seconds: 12),
    passTransition: Duration(milliseconds: 300),
    revealFloor: Duration(seconds: 5),
    autoRevealDuration: Duration(seconds: 5),
    phaseHold: Duration(seconds: 3),
  );

  @override
  MafiaTiming copyWith({
    Duration? holdToReveal,
    Duration? dwellGate,
    Duration? turnFloor,
    Duration? passTransition,
    Duration? revealFloor,
    Duration? autoRevealDuration,
    Duration? phaseHold,
  }) {
    return MafiaTiming(
      holdToReveal: holdToReveal ?? this.holdToReveal,
      dwellGate: dwellGate ?? this.dwellGate,
      turnFloor: turnFloor ?? this.turnFloor,
      passTransition: passTransition ?? this.passTransition,
      revealFloor: revealFloor ?? this.revealFloor,
      autoRevealDuration: autoRevealDuration ?? this.autoRevealDuration,
      phaseHold: phaseHold ?? this.phaseHold,
    );
  }

  @override
  MafiaTiming lerp(ThemeExtension<MafiaTiming>? other, double t) {
    // Durations must never interpolate: a half-applied gate is a leak.
    return this;
  }
}

/// Typography tokens.
class MafiaTypography extends ThemeExtension<MafiaTypography> {
  final TextStyle display;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle caption;
  final TextStyle timer;

  const MafiaTypography({
    required this.display,
    required this.headline,
    required this.title,
    required this.body,
    required this.bodySmall,
    required this.caption,
    required this.timer,
  });

  /// The shipping type set — pairing "A · Interrogation" from the Phase-1
  /// specimen (Bebas Neue over Cairo Black, IBM Plex Sans Arabic for body,
  /// IBM Plex Mono for figures).
  ///
  /// ## How the two scripts are handled
  ///
  /// Bebas Neue contains no Arabic. Every display style therefore names it as
  /// [TextStyle.fontFamily] and lists Cairo in [TextStyle.fontFamilyFallback];
  /// Flutter resolves fallbacks per glyph, so an Arabic heading renders in Cairo
  /// and a Latin one in Bebas from the same token. Nothing in the widget layer
  /// ever branches on locale.
  ///
  /// Cairo is a variable font, so the heavy cuts are requested through
  /// [TextStyle.fontVariations] on the `wght` axis. Setting only [FontWeight]
  /// would leave it at its default instance and let the platform synthesise a
  /// fake bold, which smears at display sizes. The axis value is ignored by
  /// Bebas, which has a single static cut — so one token is correct for both.
  ///
  /// Display sizes run above the doc-01 scale on purpose: Bebas is narrow
  /// uppercase and reads considerably smaller than its nominal point size, and
  /// these headings are read at arm's length across a dim table.
  static const MafiaTypography defaults = MafiaTypography(
    // # Two rules hold across every style below
    //
    // **No letter-spacing, anywhere.** Arabic glyphs *join*, and tracking pulls
    // the joins apart — it does not look "spaced" to a native reader, it looks
    // broken. This is an Arabic-first app, so the rule is absolute rather than
    // per-style: even the Latin display face falls back to Cairo, and the
    // fallback is the case that matters.
    //
    // **Line height 1.6 on every text style.** Arabic ascenders and descenders
    // need more room than Latin does at the same size; 1.4 was clipping them on
    // the display cuts, which is why every style that can render Arabic now
    // carries the same 1.6. The one exception is [timer], which is digits only,
    // single-line, and set solid on purpose.
    //
    // **Tabular figures everywhere.** Not a nicety: a counter whose digits
    // change width makes its whole row twitch as it counts, and that twitch is
    // visible from across the table. Applying the feature at the token level
    // means a new counter cannot be added without it.
    display: TextStyle(
      fontFamily: 'Bebas Neue',
      fontFamilyFallback: <String>['Cairo'],
      fontSize: 44,
      height: 1.6,
      fontVariations: <FontVariation>[FontVariation('wght', 900)],
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    headline: TextStyle(
      fontFamily: 'Bebas Neue',
      fontFamilyFallback: <String>['Cairo'],
      fontSize: 32,
      height: 1.6,
      fontVariations: <FontVariation>[FontVariation('wght', 800)],
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    title: TextStyle(
      fontFamily: 'Bebas Neue',
      fontFamilyFallback: <String>['Cairo'],
      fontSize: 22,
      height: 1.6,
      fontVariations: <FontVariation>[FontVariation('wght', 700)],
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    body: TextStyle(
      fontFamily: 'IBM Plex Sans Arabic',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.6,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    bodySmall: TextStyle(
      fontFamily: 'IBM Plex Sans Arabic',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.6,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    caption: TextStyle(
      fontFamily: 'IBM Plex Sans Arabic',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.6,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    // Tabular figures are load-bearing, not a nicety: a timer whose digits
    // change width makes the whole row twitch once a second, and that twitch is
    // visible from across the table.
    timer: TextStyle(
      fontFamily: 'IBM Plex Mono',
      fontSize: 48,
      fontWeight: FontWeight.w500,
      height: 1.0,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
  );

  @override
  MafiaTypography copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? caption,
    TextStyle? timer,
  }) {
    return MafiaTypography(
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      body: body ?? this.body,
      bodySmall: bodySmall ?? this.bodySmall,
      caption: caption ?? this.caption,
      timer: timer ?? this.timer,
    );
  }

  @override
  MafiaTypography lerp(ThemeExtension<MafiaTypography>? other, double t) {
    if (other is! MafiaTypography) return this;
    // TextStyle lerp exists in Flutter, but it's complex. For now, return this.
    return this;
  }
}
