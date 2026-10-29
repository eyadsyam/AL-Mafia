import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

abstract final class DesktopLayoutTokens {
  static const double desktopMinWidth = 1024;
  static const int homeStartFlex = 42;
  static const int homeEndFlex = 58;
  static const int tableRailFlex = 24;
  static const int tableCentreFlex = 52;
  static const double railGap = 16;
  static const double keyBorderWidth = 1;
  static const double keyInset = 6;
  static const double keyFontSize = 11;
  static const double artOpacity = 0.55;
  static const double hoverRingWidth = 3;
  static const String keyFontFamily = 'IBM Plex Mono';
}

/// Shared public identity geometry; private turn geometry stays unchanged.
abstract final class IdentityTokens {
  static const double target = 48;
  static const double buttonWidth = 64;

  /// A public screen's header carries its title at headline size.
  static const double headerHeight = 72;
  static const double flat = 0;
  static const transparent = Colors.transparent;
}

/// «نظام الكوتشينة» — the deck the whole public app is dealt from
/// (docs/design/DECK-SYSTEM.md). Built on the home screen's cards: ink black,
/// aged bone paper, engraved silver, and the characters in their arched
/// windows.
///
/// * **Silver is structure** (frames, dividers, icons).
/// * **Gold is value only** (coins, rewards, a purchase, something to claim).
/// * **Bone is the one primary action**, pixel-identical to home's
///   «ابدأ اللعبة», which is also the neutral in-match fill — so the button
///   is the same for every role and Doc 05 has nothing to say about it.
///
/// Public screens share Home's ground; in-match private surfaces keep the
/// neutral palette, whose luminance is budgeted (Doc 05).
/// The mode screen's faces: cropped to the head and shoulders in the window.
abstract final class ModeTokens {
  static const Alignment faceFocus = Alignment(0, -0.3);
  static const double faceZoom = 1.7;

  // «هتلعب إيه؟»: two playing cards fanned like Home's; the Mafia card lifts,
  // flips and deals the ways to play out of itself.
  /// The two cards arriving when the screen opens.
  static const Duration deal = Duration(milliseconds: 700);

  /// The whole open: lift, flip, then the three small cards dealt.
  static const Duration open = Duration(milliseconds: 1100);

  /// A big card's share of the width, and its height over its width.
  static const double cardWidth = 0.47;

  /// The most of the stage's height the pair may take.
  static const double cardMaxHeight = 0.62;
  static const double cardAspect = 1.59;

  /// How far each big card sits from the centre, in card widths, and its tilt.
  static const double fanSpread = 0.47;
  static const double fanTilt = 0.087; // 5°
  static const double fanDrop = 18;

  /// The opened Mafia card, scaled down at the top.
  static const double openScale = 0.66;

  /// Depth of the flip.
  static const double perspective = 0.0012;

  /// The stories card leaving: sideways in card widths, down, and its tilt.
  static const double exitSpread = 0.7;
  static const double exitDrop = 60;
  static const double exitTilt = 0.28; // 16°

  /// The arrival: from below, turned.
  static const double dealRise = 260;
  static const double dealSpread = 90;
  static const double dealTilt = 0.17; // 10°

  /// The small cards: widest, height over width, gap, the middle one raised.
  static const double wayMaxWidth = 132;
  static const double wayAspect = 1.9;

  /// The pick line under the small cards, kept clear.
  static const double pickLine = 32;
  static const double wayGap = 10;
  static const double wayLift = 10;
  static const double wayStartScale = 0.45;
  static const double wayArt = 0.52;

  /// A card's shadow.
  static const Color shadow = Color(0xB3000000);
  static const double shadowBlur = 32;
  static const Offset shadowOffset = Offset(0, 14);
  static const double wayShadowBlur = 16;
  static const Offset wayShadowOffset = Offset(0, 7);

  /// The frame inset inside a big card, and its radius.
  static const double frameInset = 7;
  static const double frameRadius = 9;

  /// «قريبا» on the stories card: the art dimmed, the label in a ringed pill.
  static const double soonScrimAlpha = 0.45;
  static const double soonPillAlpha = 0.6;
  static const double soonRingWidth = 1;

  /// The least height the stage is drawn at, closed and turned over. A
  /// shorter body (a phone on its side) scrolls the stage rather than
  /// squeezing the cards past reading.
  static const double stageMinHeight = 222;
  static const double openMinHeight = 340;

  /// The room kept above the cards for the line that says what to do.
  static const double hintClear = 32;

  /// Landscape, turned: the way back's width under the Mafia card.
  static const double sideBackWidth = 96;

  /// Easing, from Material 3's own set: the deal and lift decelerate into
  /// place, the turn eases both ways, the last settling is gentle.
  static const Curve dealCurve = Easing.emphasizedDecelerate;
  static const Curve liftCurve = Easing.emphasizedDecelerate;
  static const Curve turnCurve = Easing.standard;
  static const Curve settleCurve = Easing.standardDecelerate;

  /// The least height the two cards are drawn at, so they never collapse
  /// under the title on a short screen.
  static const double cardMinHeight = 150;
}

/// «قبل ما تبدأوا»: the numbered lines before an offline deal.
abstract final class BeforeStartTokens {
  /// The round number beside each line.
  static const double badge = 24;
  static const double lineGap = 8;

  /// From this width the lines are set in two columns.
  static const double twoColumnMinWidth = 520;
}

/// «قصص وتحقيقات»' own palette: ink brown ground, warm panels, parchment
/// text. Only `lib/ui/screens/stories/**` may use it
/// (`test/architecture/identity_isolation_test.dart`); Mafia never does.
abstract final class StoryDeckTokens {
  static const Color ground = Color(0xFF140F0C);
  static const Color panel = Color(0xFF1F1813);
  static const Color raised = Color(0xFF2A2019);
  static const Color line = Color(0xFF3A2D23);
  static const Color text = Color(0xFFF1E6D2);
  static const Color text2 = Color(0xFFC2BBB3);
  static const Color muted = Color(0xFF9B978E);
  static const Color silver = Color(0xFF67635F);
  static const Color silverLight = Color(0xFF9E9891);
  static const Color bone = Color(0xFFC2BDB2);
  static const Color bonePressed = Color(0xFF8D8169);
  static const Color ink = Color(0xFF1A120C);
  static const double disabledAlpha = 0.4;
  static const double primaryHeight = 56;
  static const double rim = 48;
  static const double rimBorder = 1.5;
}

/// Home's own thresholds.
abstract final class HomeTokens {
  /// Below this height the «دوس على أي كارت» hint gives its room to the fan.
  static const double hintMinHeight = 700;

  /// The close mark of the web «العبها من التطبيق» ribbon.
  static const double ribbonIcon = 18;

  /// «أهلاً يا <name>» after first run: fade in, hold, fade out.
  static const Duration greetingFade = Duration(milliseconds: 600);
  static const Duration greetingHold = Duration(seconds: 4);
}

/// Mafia's colours are Home's (owner, 2026-10-15/16: «البرنامج كله بهوية
/// لعبة المافيا»): the neutral ground, raised and overlay greys, bone text.
/// The warm brown belongs to «قصص وتحقيقات» only ([StoryDeckTokens]).
abstract final class DeckTokens {
  // Colour.
  static const Color ground = AppColors.groundBase;
  static const Color panel = AppColors.groundRaised;
  static const Color raised = AppColors.groundOverlay;
  static const Color line = AppColors.groundBorder;
  static const Color text = AppColors.boneWhite;
  static const Color text2 = AppColors.secondaryGrey;
  static const Color muted = AppColors.mutedGrey;
  static const Color silver = Color(0xFF67635F);
  static const Color silverLight = Color(0xFF9E9891);
  static const Color bone = AppColors.agedParchment;
  static const Color bonePressed = Color(0xFF8D8169);
  static const Color gold = VaultTokens.gold;
  static const Color goldLight = VaultTokens.goldLight;
  static const Color goldDeep = VaultTokens.goldDeep;
  static const Color ink = Color(0xFF1A120C);

  /// The darkest point of the ground; the curtain crosses through it.
  static const Color seam = AppColors.midCharcoal;
  static const double hairlineAlpha = 0.4;

  // Panels and seals (deck_paper.dart): Mafia's result, match file, profile
  // and casebook.
  static const double panelRadius = 14;
  static const double sealBorder = 1.5;
  static const double sealPlateAlpha = 0.9;

  /// A seal arrives this much larger and settles to its size.
  static const double sealFrom = 1.12;

  /// The verdict's two voices on the result: the town's sage, the mafia's
  /// crimson (also the cross on a dead seat).
  static const Color verdictTown = Color(0xFF8FA58A);
  static const Color verdictMafia = Color(0xFFC4574B);
  static const List<double> goldStops = [0, 0.45, 1];
  static const Alignment narratorFocus = Alignment(0, -0.2);
  static const double narratorZoom = 1.4;
  static const double narratorCompactBelow = 360;
  static const double disabledAlpha = 0.4;
  static const double lockedArtAlpha = 0.4;
  static const double scrimAlpha = 0.6;

  // Buttons.
  static const double primaryHeight = 56;
  static const double rim = 48;
  static const double goldInRow = 48;
  static const double adCta = 40;
  static const double rimBorder = 1.5;
  static const double pressScale = 0.98;

  // Cards and rows.
  static const Size windowList = Size(64, 88);

  /// The same window on a short phone, so a whole hand still fits.
  static const Size windowCompact = Size(48, 64);

  /// Below this height a list of cards draws them compact.
  static const double compactBelow = 700;
  static const double windowArch = 32;
  static const Size windowRole = Size(48, 64);
  static const Size narrator = Size(120, 160);
  static const Size narratorSmall = Size(88, 120);
  static const double narratorLineWidth = 280;
  static const double artMin = 112;
  static const double artMinCompact = 80;

  /// A public screen's full-bleed ground (AppOffline), held well under the
  /// text so the cards stay the brightest thing on it.
  static const double backdropAlpha = 0.7;
  static const double rowOne = 56;
  static const double rowTwo = 72;
  static const double rowInset = 56;
  static const double rowIconSlot = 40;
  static const double icon = 24;
  static const double chevron = 20;
  static const double selectedRim = 2;
  static const double check = 20;
  static const double lock = 16;

  // Pills, chips, dots.
  static const double pill = 32;
  static const double chip = 48;
  static const double dot = 8;
  static const double coinGlyph = 18;
  static const double coinGlyphSmall = 16;

  // Feather, sheet, footer, fan.
  static const double featherFraction = 0.4;
  static const double heroFeather = 48;
  static const double heroAspect = 16 / 9;
  static const double sheetMax = 0.9;
  static const Size sheetHandle = Size(36, 4);
  static const double footerGap = 16;
  static const double fanMinStage = 200;
  static const double header = 72;

  // Motion.
  static const Duration press = Duration(milliseconds: 160);
  static const Duration sheet = Duration(milliseconds: 260);
  static const Duration slide = Duration(milliseconds: 260);
  static const Duration seamFade = Duration(milliseconds: 400);
  static const Duration reduced = Duration(milliseconds: 150);

  /// A deck sheet rises over [sheet] decelerating into place, and leaves a
  /// little faster, accelerating away.
  static const Duration sheetExit = Duration(milliseconds: 200);
  static const Curve sheetCurve = Easing.emphasizedDecelerate;
  static const Curve sheetExitCurve = Easing.emphasizedAccelerate;

  /// Cards arrive once: each rises [enterRise] dp and fades in over [enter],
  /// the next one [enterStagger] later. Only transform and opacity move, so
  /// nothing is laid out again while it plays.
  static const Duration enter = Duration(milliseconds: 420);
  static const Duration enterStagger = Duration(milliseconds: 70);
  static const double enterRise = 24;

  /// Only the first few of a list arrive in turn; the rest are simply there.
  static const int enterStaggered = 4;

  /// How much sharper than the window an art image is decoded, so a zoomed
  /// face still reads crisp while the texture stays small.
  static const double artDecodeHeadroom = 1.5;

  // Type, derived from the shared scale so the in-match goldens never move.
  static TextStyle title(MafiaTypography t) =>
      t.headline.copyWith(fontSize: 28, height: 1.6, letterSpacing: 0);
  static TextStyle card(MafiaTypography t) =>
      t.title.copyWith(fontSize: 20, height: 1.6, letterSpacing: 0);
  static TextStyle body(MafiaTypography t) =>
      t.body.copyWith(fontSize: 17, height: 1.6, letterSpacing: 0);
  static TextStyle meta(MafiaTypography t) =>
      t.bodySmall.copyWith(fontSize: 15, height: 1.6, letterSpacing: 0);
}

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
  }) => MafiaElevation(
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

/// Fixed geometry for the portrait online council in doc 15.
/// The whisper composer: the seal over the title, the recipients' faces
/// (large to pick, small in the strip above the letter) and how far the
/// faces not picked fade.
/// Transparent motion sprites (`AppMotion`): the reward burst and the coin
/// that rises out of it, how far it rises, and how long the one-shot burst
/// file plays (20 frames at 24 fps).
abstract final class MotionTokens {
  static const double burst = 220;
  static const double coin = 64;
  static const double coinRise = 72;
  static const double seal = 72;
  static const double flame = 28;
  static const Duration burstLength = Duration(milliseconds: 830);

  /// A stamp («×٣» for a revealed Elder) lands from this scale down to 1.
  static const double stampFromScale = 1.6;

  /// A card flipping in (a new story clue) starts edge-on: a quarter turn.
  static const double flipFromRadians = 1.5708;

  /// Perspective for the flip, as the 3D matrix entry (row 3, column 2).
  static const double flipPerspective = 0.0015;
  static const Duration sealLength = Duration(milliseconds: 1000);

  /// The act between two faces on a witness news line, played once.
  static const double newsMark = 40;
  static const Duration newsMarkLength = Duration(milliseconds: 1200);

  /// The crow that lifts off as night falls on the table.
  static const double crow = 96;

  /// The candle on the Casebook's case wall, inset from its corner.
  static const double flameInset = 12;

  /// The seal that lands behind a new rank's emblem, played once.
  static const Duration levelUpLength = Duration(milliseconds: 1400);

  /// The verdict stamp over a vote result.
  static const double stamp = 72;
  static const Duration stampLength = Duration(milliseconds: 1200);
  static const double emberWidth = 300;
  static const double emberHeight = 180;
  static const double vaultEmberOpacity = 0.22;
  static const double smokeWidth = 104;
  static const double smokeHeight = 168;
  static const double smokeInset = 12;
}

abstract final class WhisperTokens {
  static const double seal = 56;
  static const double face = 72;
  static const double stripFace = 44;
  static const double strip = 84;
  static const double unpickedOpacity = 0.5;
}

abstract final class CouncilTokens {
  /// The small emblem beside an invite notice line.
  static const double inviteNoticeArt = 24;
  static const double welcomeArtHeight = 124;
  static const double welcomeArtMinViewport = 600;
  static const double welcomeArtStartScale = 1.04;
  static const double headerHeight = 56;

  /// «أدوات القعدة» announcement feed: visible lines and how much older ones fade.
  static const int toolFeedMax = 3;
  static const double toolFeedOlderOpacity = 0.55;
  static const double toolFeedOldestOpacity = 0.3;
  static const int councilFlex = 36;
  static const int voiceFlex = 34;
  static const int handFlex = 24;
  static const double seatLarge = 72;
  static const double seatMedium = 64;
  static const double seatSmall = 56;
  static const double seatCompact = 48;
  static const double wideCouncilBreakpoint = 768;
  static const double wideCouncilSeatScale = 2;
  static const double wideCouncilTargetGap = 24;
  static const double backRowScale = 0.88;
  static const double selectedScale = 1.08;
  static const double selectedOthersOpacity = 0.45;
  static const double deadOpacity = 0.30;
  static const double disconnectedOpacity = 0.40;

  /// Task 4. A player who stepped away keeps their ring and loses their face:
  /// the empty ring is the whole signal, and it carries no label because the
  /// table is supposed to notice it and wonder.
  static const double awayOpacity = 0.45;

  /// Task 4. A player who is gone. Cracked, and quieter than the dead — they
  /// are not part of the argument any more in either direction.
  static const double leftOpacity = 0.30;

  /// Task 6. The struck-through microphone on a silenced seat, as a fraction
  /// of the ring's diameter.
  static const double mutedMicRatio = 0.30;

  /// Task 7. How much of a seat's diameter the character art fills. The ring
  /// art paints its own margin, so the face sits inside it rather than against
  /// it — the same number `PlayerAvatar.artRatio` uses off-council.
  static const double avatarSizeRatio = 0.96;

  /// Safe, voice-only visual feedback. The level comes from local media stats
  /// and is never sent through the game or signalling layers.
  static const double voicePulseThreshold = 0.025;
  static const double voicePulseSpacingRatio = 0.045;
  static const double voicePulseMaxRadiusRatio = 0.15;
  static const double voicePulseWidth = 2.2;
  static const double voicePulseAlpha = 0.72;
  static const double confrontedOthersOpacity = 0.25;
  static const double backdropOpacity = 0.12;
  static const double primaryHeight = 56;
  static const double nameHeight = 20;
  static const double viewerSeatSize = 30;
  static const double deadTiltRadians = 0.105;
  static const double arcDepth = 0.18;

  /// How far the fog overlay slides with the table's breath, in logical
  /// pixels. Small on purpose: weather that moves is weather; weather that
  /// travels is a distraction sitting on top of the game.
  static const double fogDrift = 24;

  /// The corner ornament on a band divider (doc 15 A4).
  static const double cornerSize = 12;

  /// The perspective entry for the card flip's 4x4 (doc 15 §S-O12 beat 4).
  /// Small: enough for the card to have a near edge, not enough to make the
  /// table look like it is being filmed through a lens.
  static const double flipPerspective = 0.0012;

  /// How strongly a phase sting sits over the council (doc 16 V1/V2).
  ///
  /// Deliberately not opaque: the seats stay readable underneath, because the
  /// sting is a change of light rather than a cut to another screen.
  static const double stingOpacity = 0.55;

  /// The drawn phase curtain (dusk and dawn): how dark the edges get at the
  /// height of a dusk, how bright the top edge glows at dawn, and the hairline
  /// under the title.
  /// Band 3 and the hand re-dressing between phases: how far new content
  /// rises into place (fraction of its own height) and the scale it settles
  /// from.
  static const double bandSwapRise = 0.06;
  static const double bandSwapScale = 0.97;

  /// Your own card at night, above the night's question.
  static const double nightOwnCardHeight = 132;

  static const double curtainDarkness = 0.82;
  static const double curtainVeil = 0.82;
  static const double curtainWordsDelay = 0.14;
  static const double curtainDawnGlow = 0.28;
  static const double curtainRuleWidth = 96;
  static const double curtainRuleHeight = 1.5;

  /// What a losing seat drops to at the result (doc 15 §S-O13 beat 3).
  static const double loserOpacity = 0.30;
  static const double outerGlowBlur = 12;
  static const double hairline = 1;

  /// Ring stroke on a selected seat.
  static const double selectedRingWidth = 2;

  /// How much of the seat's diameter the initial is allowed to occupy.
  static const double initialWidthRatio = 0.55;

  /// How much of the seat's diameter the role mark occupies at the result.
  ///
  /// Larger than the initial's share on purpose. A letter is read; a mark is
  /// recognised, and recognition at the smallest ring the council ever draws —
  /// 44dp at fifteen players — needs the extra few pixels more than the letter
  /// does. Doc 15 §S-O13 beat 2.
  static const double glyphSizeRatio = 0.62;

  /// How wide a name may run before it is truncated, as a share of the seat.
  static const double nameWidthRatio = 1.35;

  /// Radius of the speaking/selected glow, as a share of the seat diameter.
  static const double glowRadiusRatio = 0.43;

  static const double selectedGlowAlpha = 0.22;
  static const double breathingGlowBase = 0.08;
  static const double breathingGlowSwing = 0.10;

  /// A seat that has not been claimed yet, in the lobby.
  static const double emptySeatOpacity = 0.35;

  /// Size of the whisper mote as it crosses the council.
  static const double moteSize = 18;

  /// How high above the straight line a whisper's light arcs, as a share of
  /// the distance it travels.
  static const double whisperArcLift = 0.28;

  /// How far a cracked seat drops and shakes while it tears.
  static const double crackShakeAmplitude = 5;
  static const int crackShakeCycles = 4;

  /// Bar height and gap for the live vote tally in Band 3.
  static const double tallyBarHeight = 10;

  /// Full size a card reaches when it rises out of the council (doc 15 §1.3:
  /// card art never renders below 200dp, and the reveal is 280).
  static const double cardRiseSize = 280;

  /// Width over height of the card art (900×1350). The frame is part of the
  /// art, so a card is always drawn whole at this ratio — never cropped square.
  static const double cardArtAspect = 2 / 3;

  /// A card face shown inside a seat ring (witness view): how much wider than
  /// the ring the card is drawn, and how far down the card the face sits, as
  /// a fraction of its height. Tuned on the four faces in `assets/images`.
  static const double portraitZoom = 1.9;
  static const double portraitFaceY = 0.34;

  /// The open table in the witness panel: one card per seat, a thumbnail per
  /// night choice, and how far a seat that is out fades.
  static const double witnessChipFace = 28;
  static const double witnessActionThumb = 22;
  static const double witnessOutOpacity = 0.45;

  /// The dead watch from the table itself (owner, 2026-09-28): a mark on a
  /// seat that something happened to, the faces on a news line, the portrait
  /// in a seat's dossier, and the seal on a whisper letter.
  static const double witnessBadge = 26;

  /// Where a seat's mark sits: the box it is centred in, and how far toward
  /// the seat's upper shoulder its centre is, as a fraction of the diameter.
  static const double seatMarkSize = 32;
  static const double seatMarkOffset = 0.36;
  static const double witnessBadgeIcon = 15;
  static const double witnessNewsFace = 34;
  static const double witnessDossierFace = 88;
  static const double witnessSeal = 44;
  static const double witnessPopupMaxHeight = 0.62;

  /// Diameter of the confrontation timer ring.
  static const double timerRingSize = 96;

  /// The victory emblem on the result screen.
  static const double victoryEmblemSize = 120;
}

/// Export geometry for the post-game social card. It never enters match UI.
/// Reading sheets (terms, privacy, previews): how much of the screen they
/// open to. Fractions of the viewport, not sizes.
abstract final class SheetTokens {
  static const documentInitialFraction = 0.85;
  static const previewInitialFraction = 0.9;
}

/// «عملات المافيا» and the cosmetic catalog (docs/CLAUDE-UX-ECONOMY-NEXT.md
/// §89). Every colour, ratio and duration a purchased item draws with.
///
/// Doc 05 rule 3: nothing here is ever drawn on a night or reveal surface.
/// Frames fall back to the plain seat ring and packs leave the night ground
/// untouched (see `cosmeticsVisibleIn`).
abstract final class CosmeticTokens {
  // The coin.
  static const Color coinGold = Color(0xFFC9A45C);
  static const Color coinShine = Color(0x55FFF4D6);
  static const double coinInline = 20;
  static const double coinHeader = 40;
  static const double coinHero = 96;
  static const Duration coinShineCycle = Duration(milliseconds: 2600);

  // Frames: outer ring, inner hairline, ring width as a share of the seat.
  static const Color frameGildedOuter = Color(0xFFC9A45C);
  static const Color frameGildedInner = Color(0xFFF1DFA8);
  static const Color frameCrimsonOuter = Color(0xFF7A1F24);
  static const Color frameCrimsonInner = Color(0xFFC9A45C);
  static const Color frameMoonlitOuter = Color(0xFF9AA6B8);
  static const Color frameMoonlitInner = Color(0xFFE3E8F0);
  static const double frameWidthRatio = 0.07;
  static const double frameGapRatio = 0.035;

  // Nameplates: fill, border, text.
  static const Color plateNoirFill = Color(0xE6141414);
  static const Color plateNoirBorder = Color(0xFFC9A45C);
  static const Color plateNoirText = Color(0xFFF2EBDD);
  static const Color plateGildedFill = Color(0xFFC9A45C);
  static const Color plateGildedBorder = Color(0xFFF1DFA8);
  static const Color plateGildedText = Color(0xFF1A1512);
  static const Color plateEmberFill = Color(0xE61C1210);
  static const Color plateEmberBorder = Color(0xFFD9793A);
  static const Color plateEmberText = Color(0xFFF6D9C0);
  static const double plateBorderWidth = 1;

  // The drawn art (assets/images/store_v2). A frame's aperture is its empty
  // centre as a share of the image width, measured from the alpha channel;
  // the frame is scaled so the aperture sits just inside the seat's rim.
  static const double frameGildedAperture = 0.651;
  static const double frameCrimsonAperture = 0.612;
  static const double frameMoonlitAperture = 0.607;
  static const double frameApertureCover = 0.9;
  static const double tableFrameExtent = 1.12;
  static const double avatarApertureInset = 0.98;

  // A plate's ornamented ends (share of width) and its flat field (share of
  // height). Ends keep their aspect; only the field stretches with the name.
  static const double plateNoirCap = 0.165;
  static const double plateNoirField = 0.401;
  static const double plateGildedCap = 0.124;
  static const double plateGildedField = 0.536;
  static const double plateEmberCap = 0.15;
  static const double plateEmberField = 0.433;

  /// The centre finial of a plate, kept at its own aspect.
  static const double plateCentre = 0.16;

  /// How much of a text line's box the glyphs fill (line height 1.6).
  static const double plateGlyphShare = 0.72;

  /// Name colours on the art's charcoal field (the vector fallback keeps its
  /// own [plateNoirText]/[plateGildedText]/[plateEmberText]).
  static const Color plateNoirArtText = Color(0xFFE9E4DA);
  static const Color plateGildedArtText = Color(0xFFF1DFA8);
  static const Color plateEmberArtText = Color(0xFFF6D9C0);
  static const double platePadding = 4;
  static const double plateRadius = 8;

  // Presentation packs: a colour grade over the public backdrops and an
  // overlay. Matrices are 4x5 ColorFilter rows.
  static const List<double> gradeMidnightManor = <double>[
    0.80, 0.05, 0.10, 0, -6, //
    0.05, 0.78, 0.12, 0, -4, //
    0.10, 0.10, 0.95, 0, 8, //
    0, 0, 0, 1, 0,
  ];
  static const List<double> gradeOldTown = <double>[
    0.95, 0.20, 0.05, 0, 10, //
    0.10, 0.85, 0.05, 0, 4, //
    0.05, 0.10, 0.60, 0, -8, //
    0, 0, 0, 1, 0,
  ];
  static const List<double> gradeMoonlitArchive = <double>[
    0.78, 0.08, 0.14, 0, -6, //
    0.06, 0.82, 0.14, 0, -4, //
    0.08, 0.12, 0.92, 0, 4, //
    0, 0, 0, 1, 0,
  ];
  static const double packOverlayOpacity = 0.35;

  /// The pack's own scene over the graded phase backdrop: the phase still
  /// reads through it, and the whole backdrop is dimmed again by the table.
  static const double packArtOpacity = 0.72;
  static const Color archiveVeil = Color(0x5514181F);
  static const Color transitionMoonlight = Color(0x66C9D3E3);
  static const Color manorVeil = Color(0x66101A33);
  static const Color oldTownVeil = Color(0x55332414);
  static const Color transitionCandle = Color(0x88E0B266);
  static const Color transitionSweep = Color(0x77F2E3C4);
  static const Duration transitionDuration = Duration(milliseconds: 1400);
  static const Duration captionHold = Duration(milliseconds: 3200);
  static const double previewHeight = 180;
  static const double previewAvatar = 88;
  static const double previewFrameBox = 1.5;
  static const double captionTop = 84;
  static const double sweepBand = 0.25;
  static const double sweepTravel = 1.4;
  static const double sweepStart = 0.2;
}

abstract final class ShareCardTokens {
  static const double width = 1080;
  static const double height = 1350;
  static const double edge = 84;
  static const double titleSize = 74;
  static const double resultSize = 112;
  static const double bodySize = 46;
  static const double ruleWidth = 4;

  /// The shared image is a picture, not a themed screen: it has no
  /// BuildContext, so its palette lives here beside its geometry.
  static const Color groundTop = Color(0xFF171719);
  static const Color groundBottom = Color(0xFF09090A);
  static const Color gold = Color(0xFFC2AF81);
  static const Color headline = Color(0xFFFFFFFF);
  static const Color footer = Color(0xFFB7B7BA);

  /// Store truth: the sharer's own seal (frame) and name (plate) on the card.
  static const double identityAvatar = 132;
  static const double identityTop = 0.17;
  static const double identityNameGap = 36;
  static const Color identitySeal = Color(0xFF2A2522);
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
  /// The scale a screen settles from as it fades in (see
  /// `NoirPageTransitionsBuilder`).
  static const double pageEnterScale = 0.985;

  final Duration instant;
  final Duration quick;
  final Duration standard;
  final Duration dramatic;

  /// A whole surface changing what it is: the table morphing from night to
  /// morning, a spotlight opening, a backdrop crossfading (doc 12 §6).
  ///
  /// Longer than [dramatic] on purpose. [dramatic] is one object moving and the
  /// eye tracks it; this is the ground under every object moving at once, and
  /// at 600ms that reads as a cut rather than as a change of light.
  final Duration phase;

  /// The death tear. The one motion in the game that is meant to be violent.
  final Duration tear;

  /// A whisper's light crossing the table, seat to seat (doc 12 §3.7).
  ///
  /// Deliberately the same number as [phase] and deliberately a separate token:
  /// they mean different things and only one of them may ever be tuned to make
  /// a whisper feel faster.
  final Duration travel;

  /// Morning light arriving from the top edge (doc 12 §3.4 beat 1).
  final Duration reveal;

  /// One cycle of anything that breathes — a speaking seat's glow, fog drift.
  ///
  /// A *period*, not a transition: it is handed to a repeating controller, so
  /// unlike every other token here it never ends.
  final Duration breathe;

  /// A single seat or button acknowledging a finger (doc 15 §3 `m-tap`).
  ///
  /// Distinct from [instant], which is the whole app's "no perceptible
  /// duration" token. This one is perceptible on purpose: a council seat is
  /// small and far from the thumb, so the acknowledgement has to travel.
  final Duration tap;

  /// Band 3 swapping the thing the game is saying (doc 15 §3 `m-band`).
  final Duration band;

  /// A card rising out of its seat to full size (doc 15 §3 `m-rise`).
  final Duration rise;

  /// A card turning over (doc 15 §3 `m-card`).
  ///
  /// The same number the offline role card flips at, and a separate token for
  /// the same reason [travel] is separate from [phase]: an elimination reveal
  /// and a private identity are two different arguments about pace, and only
  /// one of them may ever be tuned.
  final Duration card;

  /// How often a countdown re-reads the clock.
  ///
  /// A token because doc 15 forbids a bare number anywhere outside this file,
  /// and because a timer that re-read twice a second would cost a rebuild per
  /// seat per half-second for no visible gain.
  final Duration tick;

  final Curve instantCurve;
  final Curve quickCurve;
  final Curve standardCurve;
  final Curve dramaticCurve;
  final Curve phaseCurve;
  final Curve tearCurve;
  final Curve travelCurve;
  final Curve revealCurve;

  /// The overshoot a rising card lands with (doc 15 §3 `m-rise`).
  final Curve riseCurve;

  /// The curve a breathing loop is driven through.
  ///
  /// Sinusoidal in both directions, so there is no moment where the glow stops.
  /// An `easeInOut` ping-pong has a visible dwell at each end, which reads as a
  /// pulse — and a pulse is a beat somebody can count from across a table.
  final Curve breatheCurve;

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

  /// Delay between the characters of the room code as it arrives
  /// (doc 12 §3.1: "letters stagger in on first render, 60ms apart").
  ///
  /// Longer than [stagger] and deliberately so: [stagger] paces a *list*, where
  /// the eye reads a block, and this paces six characters somebody is about to
  /// read out loud one at a time.
  final Duration codeStagger;

  const MafiaMotion({
    required this.instant,
    required this.quick,
    required this.standard,
    required this.dramatic,
    required this.phase,
    required this.tear,
    required this.travel,
    required this.reveal,
    required this.breathe,
    required this.tap,
    required this.card,
    required this.band,
    required this.rise,
    required this.tick,
    required this.instantCurve,
    required this.quickCurve,
    required this.standardCurve,
    required this.dramaticCurve,
    required this.phaseCurve,
    required this.tearCurve,
    required this.travelCurve,
    required this.revealCurve,
    required this.riseCurve,
    required this.breatheCurve,
    required this.pressScale,
    required this.perspective,
    required this.stagger,
    required this.codeStagger,
  });

  static const MafiaMotion defaults = MafiaMotion(
    instant: Duration(milliseconds: 100),
    quick: Duration(milliseconds: 200),
    standard: Duration(milliseconds: 300),
    dramatic: Duration(milliseconds: 600),
    phase: Duration(milliseconds: 700),
    tear: Duration(milliseconds: 400),
    travel: Duration(milliseconds: 700),
    reveal: Duration(milliseconds: 1400),
    breathe: Duration(milliseconds: 1400),
    tap: Duration(milliseconds: 120),
    card: Duration(milliseconds: 600),
    band: Duration(milliseconds: 350),
    rise: Duration(milliseconds: 500),
    tick: Duration(seconds: 1),
    instantCurve: Curves.linear,
    quickCurve: Curves.easeOut,
    standardCurve: Curves.easeInOut,
    dramaticCurve: Curves.easeInOut,
    phaseCurve: Curves.easeInOut,
    tearCurve: Curves.easeIn,
    travelCurve: Curves.easeInOut,
    revealCurve: Curves.easeOut,
    riseCurve: Curves.easeOutBack,
    breatheCurve: Curves.easeInOutSine,
    pressScale: 0.97,
    perspective: 0.0012,
    stagger: Duration(milliseconds: 40),
    codeStagger: Duration(milliseconds: 60),
  );

  @override
  MafiaMotion copyWith({
    Duration? instant,
    Duration? quick,
    Duration? standard,
    Duration? dramatic,
    Duration? phase,
    Duration? tear,
    Duration? travel,
    Duration? reveal,
    Duration? breathe,
    Duration? tap,
    Duration? card,
    Duration? band,
    Duration? rise,
    Duration? tick,
    Curve? instantCurve,
    Curve? quickCurve,
    Curve? standardCurve,
    Curve? dramaticCurve,
    Curve? phaseCurve,
    Curve? tearCurve,
    Curve? travelCurve,
    Curve? revealCurve,
    Curve? riseCurve,
    Curve? breatheCurve,
    double? pressScale,
    double? perspective,
    Duration? stagger,
    Duration? codeStagger,
  }) {
    return MafiaMotion(
      instant: instant ?? this.instant,
      quick: quick ?? this.quick,
      standard: standard ?? this.standard,
      dramatic: dramatic ?? this.dramatic,
      phase: phase ?? this.phase,
      tear: tear ?? this.tear,
      travel: travel ?? this.travel,
      reveal: reveal ?? this.reveal,
      breathe: breathe ?? this.breathe,
      tap: tap ?? this.tap,
      card: card ?? this.card,
      band: band ?? this.band,
      rise: rise ?? this.rise,
      tick: tick ?? this.tick,
      instantCurve: instantCurve ?? this.instantCurve,
      quickCurve: quickCurve ?? this.quickCurve,
      standardCurve: standardCurve ?? this.standardCurve,
      dramaticCurve: dramaticCurve ?? this.dramaticCurve,
      phaseCurve: phaseCurve ?? this.phaseCurve,
      tearCurve: tearCurve ?? this.tearCurve,
      travelCurve: travelCurve ?? this.travelCurve,
      revealCurve: revealCurve ?? this.revealCurve,
      riseCurve: riseCurve ?? this.riseCurve,
      breatheCurve: breatheCurve ?? this.breatheCurve,
      pressScale: pressScale ?? this.pressScale,
      perspective: perspective ?? this.perspective,
      stagger: stagger ?? this.stagger,
      codeStagger: codeStagger ?? this.codeStagger,
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
/// Where the card sits inside every card file (`card_back`, `card_face_*`):
/// the files are 2:3 with a black margin, the card itself is narrower.
/// Measured on the assets — 37/896 each side, 106/1344 top and bottom.
abstract final class CardArtTokens {
  static const double marginX = 0.0413;
  static const double marginY = 0.0789;
  static const double cardAspect = 822 / 1132;
}

/// The witness side sheet: how much of the width it takes (capped), where its
/// edge tab sits down the screen, and how far the table dims behind it.
abstract final class WitnessSheetTokens {
  static const double widthFraction = 0.86;
  static const double maxWidth = 420;
  static const double handleTop = 0.42;
  static const double scrimAlpha = 0.55;
}

/// The press-and-hold pad (every handoff surface, offline and online).
abstract final class HoldPadTokens {
  /// The fingerprint mark, as a fraction of the pad's diameter.
  static const double markRatio = 0.4;
}

abstract final class PlayerSetupTokens {
  static const double dragMarkWidth = 16;
  static const double dragMarkHeight = 1.5;
  static const double dragMarkGap = 3;
}

/// «مين بيلعب؟»: each player a small Mafia card dealt into a grid.
abstract final class SeatTokens {
  /// The empty chair's art (AppOffline.cardSeatEmpty), dimmed: a place, not a player.
  static const double emptyArtAlpha = 0.55;

  /// The dark disc behind the seat number and the corner control.
  static const double badge = 22;
  static const double badgeAlpha = 0.82;

  /// The host's bought frame on their own seat: rim width and glow.
  static const double dressRim = 2;
  static const double dressGlow = 14;
  static const double dressGlowAlpha = 0.55;
  static const int minPlayers = 5;
  static const int maxPlayers = 20;
  static const int columns = 3;

  /// Width over height of one card.
  static const double aspect = 0.68;

  // The card's frame: a lit centre falling to dark, a bone-grey rim and an
  // inner hairline inset from it.
  static const Color frameLit = Color(0xFF3A3634);
  static const Color frameDark = Color(0xFF141210);
  static const Color rim = Color(0xFF8B877F);
  static const double rimWidth = 1.5;
  static const double inset = 5;
  static const double insetRadius = 6;
  static const double radius = 10;
  static const double hairlineAlpha = 0.25;
  static const double plateAlpha = 0.87;
  static const double plateHeight = 28;
  static const double plateInset = 6;
  static const double shadowBlur = 18;
  static const double shadowDrop = 8;
  static const double shadowAlpha = 0.6;
  static const double emptyAlpha = 0.7;
  static const double emptyDash = 6;
  static const double emptyGap = 5;
  static const double emptyStroke = 1.5;

  /// The portrait stands on the plate: its share of the card's height.
  static const double avatarBottom = 0.18;
  static const double avatarHeight = 0.8;
  static const double awayAlpha = 0.45;

  /// The corner control keeps a finger-sized target around a small glyph.
  static const double corner = 48;
  static const double cornerGlyph = 14;

  // Motion.
  static const Duration dealIn = Duration(milliseconds: 500);
  static const Duration dealOut = Duration(milliseconds: 300);
  static const Duration slide = Duration(milliseconds: 280);
  static const Duration dealStagger = Duration(milliseconds: 60);
  static const int dealStaggered = 6;
  static const double dealRise = 60;
  static const double dealTilt = 0.17; // 10°
  static const double dealScale = 0.6;
  static const double outDrop = 30;
  static const double liftScale = 1.08;
  static const double liftShadowBlur = 28;

  // Dragging a card past the edge of the scroll area.
  static const double edgeZone = 72;
  static const double edgeStep = 10;
  static const Duration edgeTick = Duration(milliseconds: 16);

  /// Gender toggle inside the name field.
  static const double genderWidth = 44;
  static const double genderHeight = 36;
  static const double genderRadius = 9;
}

abstract final class ResultTokens {
  static const double heroEmberWidth = 180;
  static const double heroEmberHeight = 96;

  /// The outcome art's share of the screen height, and its floor.
  static const double heroFraction = 0.34;
  static const double heroMin = 200;
  static const double heroZoom = 1.12;

  /// The verdict headline.
  static const double verdictSize = 44;

  /// The seal: size of the border, how far it lands from.
  static const double stampBorder = 4;
  static const double stampFrom = 2.4;
  static const double stampTop = 56;
  static const double stampRadius = 8;

  /// Your portrait window in the «كنت …» card.
  static const Size youWindow = Size(52, 72);
  static const double youZoom = 1.55;

  /// The seat cards: columns, height over width, the flip's depth.
  static const int seatColumns = 4;
  static const double seatAspect = 1.5;
  static const double seatGap = 8;
  static const double seatRadius = 7;
  static const double seatBorder = 1;
  static const double flipDepth = 0.0014;
  static const double deadFade = 0.55;
  static const double meRing = 2;
  static const double meRingGap = 2;
  static const double crossSize = 14;

  /// The coin flight to the pill: how many coins, how long, how far each one
  /// waits for the one before.
  static const int flightCoins = 6;
  static const double flightCoinSize = 20;
  static const Duration flight = Duration(milliseconds: 700);
  static const double flightStagger = 0.1;
  static const double pillBump = 1.2;
  static const Duration pillBumpFor = Duration(milliseconds: 250);

  /// The story, in milliseconds from the first frame (the mockup's beats).
  static const int verdictAt = 0;
  static const int verdictFor = 800;
  static const int stampAt = 1100;
  static const int stampFor = 450;
  static const int youAt = 1400;
  static const int youFor = 500;
  static const int lineAt = 1800;
  static const int lineFor = 600;
  static const int flipAt = 2000;
  static const int flipStagger = 140;
  static const int flipFor = 600;
  static const int rowStagger = 250;
  static const int rowFor = 400;
  static const int countFor = 900;
  static const int tail = 200;
  static const double rowSlide = 10;
  static const double riseFrom = 12;

  /// The match file's timeline rail.
  static const double railWidth = 1;
  static const double railDot = 11;
  static const double railDotBorder = 2;
  static const double medal = 46;
  static const double medalBorder = 2;

  /// Small portraits are decoded to about this height.
  static const int thumbDecode = 96;
  static const int seatDecode = 256;
}

/// The dark case file (profile, casebook, result): dark brown paper with
/// light ink and crimson stamps. Public surfaces only, never in a match, and
/// never with a story's portraits (docs/design/DECK-SYSTEM.md §10).
abstract final class CaseFileTokens {
  static const Color paperTop = Color(0xFF30251C);
  static const Color paperBottom = Color(0xFF241B14);
  static const Color edge = Color(0xFF4A3A2C);
  static const Color ink = Color(0xFFEADFC9);
  static const Color inkMuted = Color(0xFF9B978E);
  static const Color stamp = Color(0xFFC4574B);
  static const Color sage = Color(0xFF8FA58A);
  static const Color photo = Color(0xFF1A130E);
  static const Color tabIdle = Color(0xFF1A130E);
  static const Color tabLine = Color(0xFF3A2D23);
  static const Color board = Color(0xFF1C140F);
  static const Color boardDot = Color(0xFF2A1F17);
  static const Color string = Color(0xFF9B3B32);
  static const Color desk = Color(0xFF0D0907);
  static const Color stampPlate = Color(0xE6241B14);
  static const double radius = 14;
  static const double edgeWidth = 1;
  static const double ruleAlpha = 0.13;
  static const double stampBorder = 3;
  static const double stampRadius = 6;
  static const double stampTilt = -0.21; // -12 degrees
  static const double stampAlpha = 0.9;
  static const List<Color> paper = [paperTop, paperBottom];
}

class MafiaTiming extends ThemeExtension<MafiaTiming> {
  /// One full 60-frame victory sequence at 12 fps.
  static const victoryReveal = Duration(seconds: 5);

  /// First-open attribution gives up on the Play referrer after this long;
  /// it runs after the first frame and never blocks start-up (F13/P8).
  static const installReferrerTimeout = Duration(seconds: 3);

  /// P9: at most one store-review request per 90 days.
  static const reviewPromptCooldown = Duration(days: 90);

  /// F19: a result-screen role figure rising behind its name, the delay
  /// between rows, and how far (in figure heights) it rises from.
  static const figureRise = Duration(milliseconds: 520);
  static const figureRiseStagger = Duration(milliseconds: 90);
  static const double figureRiseLift = 0.35;

  /// §9: reduced motion is opacity-only, 120 ms.
  static const reducedMotionFade = Duration(milliseconds: 120);

  /// How long an eliminated player's card stays face-up before it settles
  /// back into the council. A dramatic hold, so it survives Reduce Motion.
  static const eliminationCardDwell = Duration(milliseconds: 2800);

  /// The whole dusk/dawn curtain, in, held and out — and its Reduce Motion
  /// cross-fade, which keeps the title and drops the travelling light.
  /// How long the night victim's scare takes to go back to black.
  static const jumpscareFadeOut = Duration(milliseconds: 450);

  /// How long before a discussion or ballot closes its warning sounds.
  static const timerWarningLead = Duration(seconds: 10);

  static const phaseCurtain = Duration(milliseconds: 2400);
  static const phaseCurtainReduced = Duration(milliseconds: 1000);

  /// How often an eliminated player's open table is read again. Night choices
  /// arrive on no stream the witness can see, so they are polled.
  static const witnessRefresh = Duration(seconds: 4);

  /// 1.1 F8 reconnect: a neutral strip until the first, the persistent
  /// surface after it, a manual retry after the second.
  static const reconnectStrip = Duration(seconds: 6);
  static const reconnectRetry = Duration(seconds: 15);

  /// How long one line of the dead's news stays over the table.
  static const witnessNewsHold = Duration(milliseconds: 2800);

  /// How long a reward's sparks and rising coin stay on screen.
  static const rewardFlourish = Duration(milliseconds: 1100);

  /// How long Home's daily strip says what the coffer gave before it goes.
  static const cofferStripLinger = Duration(seconds: 4);

  /// How long «{name} بقى الهوست» stays on screen after a host migration.
  static const hostHandover = Duration(seconds: 3);

  /// A browser may throttle timers briefly even while its page is visible.
  /// Ten seconds leaves enough room for one delayed beat without inventing an
  /// `away` player, while explicit lifecycle and room events still travel
  /// immediately through Realtime.
  static const onlineHeartbeat = Duration(seconds: 10);

  /// How long a client that is *not* the host waits past a phase deadline
  /// before driving the room forward itself.
  ///
  /// Zero for the host, which is the ordinary case and stays exactly as it was.
  /// A guest holds back so the room is not advanced out from under a host who
  /// was half a second behind, and holds back in seat order ([onlineDriveStep])
  /// so that five phones do not all ask in the same instant.
  static const onlineDriveGrace = Duration(seconds: 4);

  /// How long the room lingers on a beat it only reads before moving on by
  /// itself: the deal after the last card is seen, the morning report, and
  /// the verdict (long enough for the card to rise, hold and settle).
  static const autoRevealSettle = Duration(seconds: 2);
  static const autoMorningRead = Duration(seconds: 9);
  static const autoVerdictRead = Duration(seconds: 9);
  static const onlineDriveStep = Duration(seconds: 2);

  /// A remote audio element can exist before the browser has finished binding
  /// its MediaStream. Retry briefly; autoplay refusal still waits for a real
  /// user gesture through the web playout bridge.
  static const webPlayoutRetry = Duration(milliseconds: 300);
  static const privateViewRetry = Duration(milliseconds: 500);

  /// How often local WebRTC audio levels are sampled for the speaking ring.
  static const voiceStatsSample = Duration(milliseconds: 250);

  /// The public-room list re-reads itself this often while it is on screen and
  /// the app is in the foreground. A failed read doubles the wait, up to
  /// [publicRoomsBackoffCap], so a server that is down is not asked every
  /// fifteen seconds by every phone looking at the list.
  static const publicRoomsRefresh = Duration(seconds: 15);

  /// The narrator's clips are prepared after the cues, this many at a time,
  /// in the background.
  static const audioWarmUpBatch = 4;
  static const publicRoomsBackoffCap = Duration(seconds: 60);

  /// Between checks for AdMob's signed reward callback after an ad. Doubles
  /// after each check up to [adRewardPollCap], for at most [adRewardPollWindow]
  /// in all; after that the player gets a manual «check again».
  static const adRewardPoll = Duration(seconds: 2);
  static const adRewardPollCap = Duration(seconds: 16);
  static const adRewardPollWindow = Duration(seconds: 90);

  /// Reopening a result with a claim still pending: a short look only.
  static const adRewardRecoverWindow = Duration(seconds: 6);

  /// Only the consent *status* request is bounded. A consent form on screen
  /// is a person reading; it is never timed out.
  static const adConsentInfoTimeout = Duration(seconds: 10);
  static const adLoadTimeout = Duration(seconds: 15);
  static const adShowTimeout = Duration(minutes: 3);

  /// An interstitial that is not loaded within this is skipped, never awaited.
  static const interstitialLoadTimeout = Duration(seconds: 12);

  /// Home from a completed result waits at most this long for the room to be
  /// left; past it the player goes home anyway and no automatic ad follows.
  static const leaveBeforeAd = Duration(seconds: 3);

  /// Product floors for the one automatic ad; the server may only widen them.
  static const interstitialMinGap = Duration(minutes: 10);
  static const interstitialAfterReward = Duration(minutes: 2);

  /// The wheel's spin, landing exactly on the server's outcome.
  static const wheelSpin = Duration(milliseconds: 2600);
  static const rewardReveal = Duration(milliseconds: 420);

  /// How long the identity pad must be held before the turn content is shown.
  final Duration holdToReveal;

  /// Minimum dwell after reveal before Confirm becomes enabled (L-07).
  final Duration dwellGate;

  /// Minimum total turn length, measured from reveal. Pass also waits for
  /// [confirmationFloor] after confirmation, identically for every role.
  final Duration turnFloor;

  /// Minimum private confirmation view before the phone may be passed.
  /// The same gate applies to every night role (doc 05 L-08).
  final Duration confirmationFloor;

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

  /// The pause between the morning's death line and the trace beneath it.
  ///
  /// Doc 09 §1.7: *"Trace text appears **1.2s after** the death line — never
  /// simultaneously. The pause is the drama."* It is on the table, in front of
  /// everyone, so it carries no leakage weight; it is here because it is a
  /// duration and durations live in one file.
  final Duration traceBeat;

  /// How long the «اسم واحد» opener gives each player (doc 09 §2.2).
  ///
  /// Ten seconds, forced, one name. Not a setting: the whole mechanic is that
  /// it is too short to explain in, and a table that stretches it has turned it
  /// back into the opening silence it exists to kill.
  final Duration openingRoundPerPlayer;

  /// How long an in-context hint stays up before it fades (doc 12 §9).
  ///
  /// Long enough to read one line twice, short enough that it is gone before it
  /// becomes furniture. It gates nothing — a hint is a caption, not a modal —
  /// so this is pacing rather than a rule.
  final Duration hintDwell;

  /// Beat 2 of the elimination: how long the colour takes to drain
  /// (doc 12 §4.2).
  final Duration eliminationDrain;

  /// Beat 3: how long the sentence holds before the table returns.
  ///
  /// A *hold*, which is why Reduce Motion keeps it — doc 12 §6: dramatic holds
  /// remain, because they are pacing and not motion. Somebody who has switched
  /// animations off still gets the silence; they simply do not watch the drain.
  final Duration eliminationHold;

  /// How long an arriving whisper stays on screen before it withdraws itself.
  ///
  /// Doc 14 §3.4's twelve seconds. Long enough to read a hundred and twenty
  /// characters twice while an argument is going on around you; short enough
  /// that a card nobody dismissed is not still covering the table when the vote
  /// opens. It never blocks anything — the table and the timer stay live behind
  /// it — so the only cost of the upper bound being generous is the card.
  final Duration whisperCardDwell;

  const MafiaTiming({
    required this.holdToReveal,
    required this.dwellGate,
    required this.turnFloor,
    required this.confirmationFloor,
    required this.passTransition,
    required this.revealFloor,
    required this.autoRevealDuration,
    required this.phaseHold,
    required this.traceBeat,
    required this.openingRoundPerPlayer,
    required this.hintDwell,
    required this.eliminationDrain,
    required this.eliminationHold,
    required this.whisperCardDwell,
  });

  static const MafiaTiming defaults = MafiaTiming(
    holdToReveal: Duration(seconds: 2),
    dwellGate: Duration(seconds: 8),
    turnFloor: Duration(seconds: 12),
    confirmationFloor: Duration(seconds: 3),
    passTransition: Duration(milliseconds: 300),
    revealFloor: Duration(seconds: 5),
    autoRevealDuration: Duration(seconds: 5),
    phaseHold: Duration(seconds: 3),
    traceBeat: Duration(milliseconds: 1200),
    openingRoundPerPlayer: Duration(seconds: 10),
    hintDwell: Duration(seconds: 4),
    eliminationDrain: Duration(milliseconds: 1200),
    eliminationHold: Duration(milliseconds: 2200),
    whisperCardDwell: Duration(seconds: 12),
  );

  @override
  MafiaTiming copyWith({
    Duration? holdToReveal,
    Duration? dwellGate,
    Duration? turnFloor,
    Duration? confirmationFloor,
    Duration? passTransition,
    Duration? revealFloor,
    Duration? autoRevealDuration,
    Duration? phaseHold,
    Duration? traceBeat,
    Duration? openingRoundPerPlayer,
    Duration? hintDwell,
    Duration? eliminationDrain,
    Duration? eliminationHold,
    Duration? whisperCardDwell,
  }) {
    return MafiaTiming(
      holdToReveal: holdToReveal ?? this.holdToReveal,
      dwellGate: dwellGate ?? this.dwellGate,
      turnFloor: turnFloor ?? this.turnFloor,
      confirmationFloor: confirmationFloor ?? this.confirmationFloor,
      passTransition: passTransition ?? this.passTransition,
      revealFloor: revealFloor ?? this.revealFloor,
      autoRevealDuration: autoRevealDuration ?? this.autoRevealDuration,
      phaseHold: phaseHold ?? this.phaseHold,
      traceBeat: traceBeat ?? this.traceBeat,
      openingRoundPerPlayer:
          openingRoundPerPlayer ?? this.openingRoundPerPlayer,
      hintDwell: hintDwell ?? this.hintDwell,
      eliminationDrain: eliminationDrain ?? this.eliminationDrain,
      eliminationHold: eliminationHold ?? this.eliminationHold,
      whisperCardDwell: whisperCardDwell ?? this.whisperCardDwell,
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
      letterSpacing: 0,
      fontVariations: <FontVariation>[FontVariation('wght', 900)],
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    headline: TextStyle(
      fontFamily: 'Bebas Neue',
      fontFamilyFallback: <String>['Cairo'],
      fontSize: 32,
      height: 1.6,
      letterSpacing: 0,
      fontVariations: <FontVariation>[FontVariation('wght', 800)],
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    title: TextStyle(
      fontFamily: 'Bebas Neue',
      fontFamilyFallback: <String>['Cairo'],
      fontSize: 22,
      height: 1.6,
      letterSpacing: 0,
      fontVariations: <FontVariation>[FontVariation('wght', 700)],
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    body: TextStyle(
      fontFamily: 'IBM Plex Sans Arabic',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.6,
      letterSpacing: 0,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    bodySmall: TextStyle(
      fontFamily: 'IBM Plex Sans Arabic',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.6,
      letterSpacing: 0,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    caption: TextStyle(
      fontFamily: 'IBM Plex Sans Arabic',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.6,
      letterSpacing: 0,
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

/// Shared public arrival artwork; never used to encode a role or phase.
abstract final class ExperienceTokens {
  static const heroAspect = 1.5;
  static const heroMaxHeight = 240.0;
  static const compactHeroMaxHeight = 144.0;
  static const compactHeroAspect = 2.5;
  static const backgroundGlow = 0.07;
}

/// Public pass-and-play presentation when the phone lies in the table centre.
/// These values are deliberately absent from private turn widgets.
abstract final class TabletopTokens {
  static const double headlineFontSize = 56.0;
  static const double factFontSize = 26.0;
  static const double timerFontSize = 72.0;
  static const double winnerFontSize = 52.0;
  static const double controlHeight = 64.0;
  static const double compactBreakpoint = 360.0;
}

/// The settings kit (`lib/ui/widgets/settings_kit.dart`): the general
/// settings and the online room settings share one look (owner, 2026-09-24).
abstract final class SettingsTokens {
  /// The round badge each panel's icon sits in.
  static const iconBadge = 38.0;
  static const iconSize = 20.0;

  /// The smaller badge on a link row.
  static const linkBadge = 32.0;
  static const linkIconSize = 18.0;

  /// A segmented control's track — also each option's full hit area, so it
  /// is the 48 dp minimum touch target — and the inset its lit thumb keeps.
  static const segmentHeight = 48.0;
  static const segmentInset = 3.0;

  /// How strongly the gold washes a badge and the «online only» pill.
  static const badgeWash = 0.14;

  /// Gold lamp-light along the top edge of a panel.
  static const panelGlow = 0.05;
}

/// Daily rewards and Play offers in the vault; never used for roles.
abstract final class DailyTokens {
  /// Miniatures in dense cards: readable, never full-screen pictures.
  static const cofferArt = 88.0;
  static const passArt = 72.0;
  static const packArt = 96.0;
  static const wheelSize = 232.0;
  static const wheelRim = 3.0;
  static const wheelHub = 22.0;
  static const pointer = 18.0;

  /// Where a slice's label sits, as a fraction of the wheel radius.
  static const labelRadius = 0.66;

  /// A slice narrower than this carries no painted label (the odds list
  /// beside the wheel names every prize).
  static const minLabelSweepDegrees = 24.0;
  static const wheelTurns = 4;
  static const weekDot = 14.0;
  static const sliceWash = 0.55;
  static const sliceWashAlt = 0.28;
  static const cardMaxWidth = 560.0;
}

/// The win in the vault: the amount counting up over the prize while coins
/// fly out of it, then the next offer appears.
abstract final class WinTokens {
  static const Duration reveal = Duration(milliseconds: 1700);

  /// Reduce motion: the final number, held this long, then the next offer.
  static const Duration hold = Duration(milliseconds: 900);

  /// Share of [reveal] the count takes to reach the amount.
  static const double countShare = 0.55;

  /// Share of [reveal] the number takes to pop in, and the overshoot.
  static const double popShare = 0.3;
  static const double popFrom = 0.6;
  static const double popPeak = 1.18;

  /// The last share of [reveal] fades it out.
  static const double fadeShare = 0.18;

  static const int coins = 10;
  static const double coin = 18.0;
  static const double rise = 150.0;
  static const double spread = 80.0;

  /// Each coin leaves this share of [reveal] after the one before, and takes
  /// [flightShare] of it to fly.
  static const double stagger = 0.045;
  static const double flightShare = 0.5;

  /// The glow behind the number.
  static const double glowBlur = 18.0;
  static const double glowAlpha = 0.55;

  /// One full turn of the wheel while the server confirms an extra spin,
  /// and the turns it adds before settling on the server's slot.
  static const Duration idleTurn = Duration(milliseconds: 900);
  static const int landTurns = 3;

  /// The balance in the vault's header counting to its new value.
  static const Duration balanceCount = Duration(milliseconds: 900);
}

/// F9 Thursday Night's public online-entry banner.
abstract final class ThursdayTokens {
  static const double bannerHeight = 104.0;
  static const double borderWidth = 1.0;
  static const double artOpacity = 0.56;
}

/// Council Vault public surfaces; never used to distinguish secret roles.
abstract final class StoreTokens {
  /// Fallback while a submitted transfer waits for owner review, including
  /// devices where notification permission was declined.
  static const Duration orderReviewPoll = Duration(seconds: 20);

  /// Product art is 768 px square; cards and thumbnails never need more.
  static const decodeWidth = 512;

  /// Frames and plates drawn on the table and in previews.
  static const frameDecodeWidth = 384;
  static const plateDecodeWidth = 512;

  /// A card leaves the next card's edge in view at 360 dp.
  static const cardWidth = 168.0;
  static const railHeight = 262.0;
  static const coinRailHeight = 200.0;
  static const heroTextWidth = 0.64;
  static const hairlineOverlap = 0.5;
  static const progressStroke = 2.0;
  static const walletCoinScale = 1.5;
  static const artHeight = 128.0;
  static const detailArtHeight = 176.0;
  static const thumbnail = 52.0;
  static const heroHeight = 124.0;
  static const touchTarget = 48.0;
  static const heroShade = 0.86;

  /// Wide screens keep the shop to a readable column.
  static const maxContentWidth = 960.0;

  /// The vault art behind the whole store, dimmed this far so cards and
  /// text keep their contrast.
  static const backdropShade = 0.72;

  /// From this header width the tabs centre under the title.
  static const headerWideAt = 720.0;

  /// A tab with its mark above its word.
  static const tabHeight = 60.0;

  /// The owned/equipped mark on a card.
  static const badgeWash = 0.16;
  static const selectedBorder = 1.5;

  /// The small progress ring inside a busy reward button.
  static const busyStroke = 2.0;
}

/// «السوق السودة» (docs/design/DECK-SYSTEM.md §10): the drawers store. Sizes,
/// the crimson stamp and the motion of the shop and its buy sheet.
abstract final class StoreShopTokens {
  static const Color stamp = Color(0xFFC4574B);
  static const Color stampWash = Color(0xCC1A130E);

  static const double searchHeight = 48;
  static const double featHeight = 170;
  static const double featTextWidth = 0.62;
  static const double featShade = 0.94;
  static const double featCorner = 44;
  static const double featFadeAlpha = 0.2;
  static const List<double> featStops = [0.35, 1];
  static const double wellRadius = 0.9;
  static const Alignment wellCenter = Alignment(0, -0.2);
  static const double lineHeight = 1.6;

  /// The three items peeking out of a drawer, fanned like a hand of cards.
  static const double peekWidth = 86;
  static const Size peekTile = Size(46, 58);
  static const double peekStep = 20;
  static const List<double> peekTurns = [0.105, -0.035, -0.157];
  static const int peekCount = 3;

  static const double bagHeight = 252;
  static const double bagArt = 118;
  static const double gridGap = 12;
  static const double previewButton = 48;
  static const double stampBorder = 2;
  static const double stampBigBorder = 4;
  static const double stampBigFrom = 2.2;
  static const double stampBigSize = 30;
  static const double sheetArt = 190;
  static const double sheetFraction = 0.78;
  static const double dividerHeight = 14;
  static const double chipsGap = 8;

  static const Duration stampIn = Duration(milliseconds: 380);
  static const Duration slide = Duration(milliseconds: 320);
  static const double slideShift = 0.3;
  static const double bagRise = 16;
}

/// Council Life (phase 107): rank emblems, contract icons, the Council Seal
/// frame and the hub's motion. Public identity only — nothing here is ever
/// chosen by a role, and emblems are drawn only on public surfaces.
abstract final class CouncilLifeTokens {
  /// Metal per tier, light → mid → dark: bronze (1–3), gold (4–6),
  /// obsidian with gold (7–9) and the Godfather's obsidian and bright gold.
  static const List<List<Color>> tierMetal = [
    [Color(0xFFD9A77A), Color(0xFF9C6A42), Color(0xFF5E3B22)],
    [Color(0xFFE3B387), Color(0xFFA8733F), Color(0xFF643D1E)],
    [Color(0xFFF0C495), Color(0xFFB9824A), Color(0xFF6E4420)],
    [Color(0xFFF1DFA8), Color(0xFFC9A45C), Color(0xFF7A5C26)],
    [Color(0xFFF6E7B4), Color(0xFFD4AE5E), Color(0xFF81612A)],
    [Color(0xFFFFF0C2), Color(0xFFE0B85E), Color(0xFF8A6624)],
    [Color(0xFF6B6570), Color(0xFF2C2830), Color(0xFF121014)],
    [Color(0xFF706874), Color(0xFF2A2530), Color(0xFF0E0C10)],
    [Color(0xFF766D7A), Color(0xFF28222E), Color(0xFF0B090D)],
    [Color(0xFF7C7280), Color(0xFF231E28), Color(0xFF08070A)],
  ];

  /// The trim on obsidian tiers, and the gem the upper tiers carry.
  static const Color obsidianTrim = Color(0xFFE0B85E);
  static const Color godfatherTrim = Color(0xFFFFE08A);
  static const Color gem = Color(0xFF9E1B2A);
  static const Color gemLight = Color(0xFFE0525E);
  static const Color field = Color(0xFF17130F);
  static const Color highlight = Color(0x66FFF4D6);

  /// Emblem sizes: seat badge, list row, card, celebration.
  static const double emblemSeat = 22.0;
  static const double emblemRow = 28.0;
  static const double emblemCard = 64.0;
  static const double emblemHero = 112.0;

  /// Where the seat badge sits, as a share of the seat diameter.
  static const double seatBadgeOffset = 0.36;

  /// Contract icon badge.
  static const double contractIcon = 40.0;
  static const double iconStroke = 0.075;

  /// XP and contract bars.
  static const double barHeight = 8.0;
  static const double barRadius = 4.0;

  /// Coin burst on a claim, and the newly-earned shimmer.
  static const Duration burst = Duration(milliseconds: 900);
  static const int burstCoins = 10;
  static const double burstReach = 56.0;
  static const double burstCoin = 14.0;
  static const Duration shimmer = Duration(milliseconds: 1800);
  static const Duration toastStagger = Duration(milliseconds: 160);

  /// The Council Seal frame (vector): wax-red ring, gold hairline, studs.
  static const Color sealOuter = Color(0xFF8E1F24);
  static const Color sealInner = Color(0xFFE0B85E);
  static const Color sealStud = Color(0xFFF1DFA8);
  static const int sealStuds = 8;
  static const double sealStudRatio = 0.045;

  /// Starter Bundle cover.
  static const double bundleArt = 96.0;

  /// The attention dot on the vault button.
  static const double attentionDot = 9.0;

  /// The code in the invite card.
  static const double inviteCodeScale = 1.6;
  static const double leaderboardAvatar = 36.0;
}

/// Ads v2 (phase 108): the app-open ad's product floors and the waiting-room
/// banner's frame. Never shown on a gameplay surface.
abstract final class AdTokens {
  /// An app-open ad not loaded within this is skipped: the player is never
  /// kept waiting on the launch screen for an ad.
  static const appOpenLoadTimeout = Duration(seconds: 3);

  /// Floors the server may only widen: 20 minutes between app-open ads, 15
  /// minutes away before a return may show one, and a loaded ad is stale
  /// (Google's guidance) four hours after it loaded.
  static const appOpenMinGap = Duration(minutes: 20);
  static const appOpenResumeAfter = Duration(minutes: 15);
  static const appOpenExpiry = Duration(hours: 4);
  static const appOpenMaxPerDay = 10;

  /// A system back that reaches the game this soon after a full-screen ad
  /// closed was meant for the ad (pressed again while it was closing): it is
  /// swallowed, never allowed to close a screen, leave a room or exit.
  static const backAfterAdGrace = Duration(milliseconds: 1500);

  /// A preloaded rewarded ad is shown within this or thrown away (Google
  /// expires them after an hour).
  static const rewardedExpiry = Duration(minutes: 55);

  /// How long an offer must stay on screen before its ad is preloaded, so
  /// scrolling past a card never starts the SDK or a request.
  static const rewardedPreloadAfter = Duration(milliseconds: 700);

  /// The light veil a tap raises while its rewarded ad is being prepared.
  static const loadingVeilAlpha = 0.72;
  static const loadingVeilFade = Duration(milliseconds: 120);
  static const loadingVeilSpinner = 28.0;
  static const loadingVeilStroke = 2.5;

  /// Ads v3 (phase 110): global pacing for every full-screen ad (app-open
  /// and interstitials). A safety cap the server may only lower, and a gap
  /// it may only widen.
  static const fullScreenMaxPerDay = 60;
  static const fullScreenMinGap = Duration(seconds: 60);

  /// Menu time without any full-screen ad before a session interstitial may
  /// follow a navigation between menus; the server may only lengthen it.
  static const sessionInterstitialAfter = Duration(minutes: 3);

  /// The banner's thin frame and the gap that keeps it clear of any button.
  static const bannerFrame = 1.0;
  static const bannerLabelGap = 2.0;
  static const bannerMaxWidth = 728.0;

  /// The native ad card (Google's small template: 90-120 dp tall).
  static const double nativeMinHeight = 90.0;
  static const double nativeMaxHeight = 120.0;
  static const double nativeCorner = 12.0;

  /// Kept clear between a surface's primary action and a banner below it
  /// (the lobby's Start button): well past a thumb's slip, so a tap meant
  /// for the button never lands on the ad.
  static const bannerActionClearance = 72.0;

  /// Below this screen height (a phone on its side) the lobby has no room
  /// for a banner that clear of Start: it shows none.
  static const bannerMinLobbyHeight = 560.0;
}

/// Phase 109: awards, reactions, welcome-back, Founder badge.
abstract final class FunTokens {
  /// One medal card in the awards ribbon, and the medal on it.
  static const double awardCardWidth = 104.0;
  static const double awardCardHeight = 136.0;
  static const double awardMedal = 56.0;
  static const double awardGap = 8.0;
  static const double awardStroke = 2.0;

  /// Cards appear one after another; each lifts this far as it lands.
  static const Duration awardStagger = Duration(milliseconds: 140);
  static const Duration awardReveal = Duration(milliseconds: 420);
  static const double awardLift = 12.0;

  /// Restrained gold motes behind a revealed medal: few, faint, slow.
  static const int particleCount = 9;
  static const double particleOpacity = 0.5;
  static const double particleSize = 2.5;
  static const Duration particleCycle = Duration(milliseconds: 2600);

  /// Skeleton cards while the awards load.
  static const int skeletonCards = 3;
  static const double skeletonOpacity = 0.35;

  /// The eight reaction seals: in the bar, and floating over a seat.
  static const double reactionSeal = 36.0;
  static const double reactionFloat = 44.0;
  static const double reactionRise = 72.0;
  static const Duration reactionFloatDuration = Duration(milliseconds: 1600);
  static const Duration reactionCoalesceWindow = Duration(milliseconds: 1200);
  static const int reactionSeenIds = 1024;
  static const double reactionBadgeGap = 2.0;
  static const double reactionBadgeRadius = 999.0;
  static const double reactionBadgePadding = 6.0;
  static const Color reactionBadgeBackground = Color(0xFFF3E7CC);
  static const Color reactionBadgeText = Color(0xFF211B1B);

  /// The daily strip greets with «وحشتنا» only after this long away.
  static const Duration welcomeBackAfter = Duration(days: 3);
  static const double welcomeArt = 72.0;

  /// The coffer art on Home's slim daily strip.
  static const double cofferStripArt = 36.0;

  /// The Founder badge on the profile.
  static const double founderBadge = 32.0;

  /// Medal palette (the painted fallback): gold face, ribbon per award.
  static const Color medalLight = Color(0xFFF1DFA8);
  static const Color medalMid = Color(0xFFC9A45C);
  static const Color medalDark = Color(0xFF7A5C26);
  static const List<Color> ribbons = [
    Color(0xFF9E1B2A), // mvp — oxblood
    Color(0xFF2E4A6B), // sharp eye — ink blue
    Color(0xFF6B4A8A), // silver tongue — plum
    Color(0xFF7A2E1E), // first blood — rust
    Color(0xFF2F5E47), // lifesaver — bottle green
    Color(0xFF151316), // perfect crime — black
    Color(0xFF8A6A2E), // survivor — candle amber
  ];

  /// Wax colours for the reaction seals' painted fallback.
  static const List<Color> waxes = [
    Color(0xFFB8862E),
    Color(0xFF8E2A2A),
    Color(0xFF4F5B66),
    Color(0xFFA06A2C),
    Color(0xFF9E1B2A),
    Color(0xFF3B3540),
    Color(0xFF5C3A24),
    Color(0xFFC9A45C),
  ];
}

/// The 1.0.1 design pass (2026-09-26): one engraved card system for every
/// vault, Council, reward and result surface, and the gold that marks a
/// reward. Public surfaces only — nothing here is ever chosen by a role, and
/// none of it is drawn while a phone is in a player's hand.
abstract final class VaultTokens {
  /// The coin's metal, light → mid → deep, and the ink printed on it.
  static const Color goldLight = Color(0xFFF1DFA8);
  static const Color gold = Color(0xFFC9A45C);
  static const Color goldDeep = Color(0xFF7A5C26);
  static const Color goldInk = Color(0xFF1A1512);

  /// Pressed gold: the same metal one step darker.
  static const Color goldPressedLight = Color(0xFFD9C38A);
  static const Color goldPressed = Color(0xFFA9864A);

  /// The dark enamel inside a reward chip and a medallion.
  static const Color enamel = Color(0xFF17130F);

  /// Oxblood for the seventh day, the best-value ribbon and the attention dot.
  static const Color oxblood = Color(0xFF8E1F24);
  static const Color oxbloodLight = Color(0xFFB8454A);

  /// Lamp-light along a card's top edge, and the engraved hairline inside it.
  static const double lampWash = 0.07;
  static const double engraveInset = 4.0;
  static const double engraveAlpha = 0.16;
  static const double engraveWidth = 0.8;

  /// The gold corner marks: a short bracket and a stud.
  static const double cornerTick = 10.0;
  static const double cornerAlpha = 0.5;
  static const double cornerStud = 1.4;

  /// A lit card (something waiting to be claimed, the best offer).
  static const double litBorder = 1.2;
  static const double litGlowAlpha = 0.16;
  static const double litGlowBlur = 22.0;

  /// The ribbon tag riding a card's top edge.
  static const double tagHeight = 24.0;
  static const double tagLift = 12.0;

  /// The reward chip: coin and amount in a gold-rimmed enamel pill.
  static const double chipHeight = 28.0;
  static const double chipCoin = 16.0;
  static const double chipRim = 1.0;

  /// The engraved progress bar.
  static const double barHeight = 10.0;
  static const double barShine = 0.45;
  static const Duration barFill = Duration(milliseconds: 700);

  /// The one glint that crosses a best-value card or a fresh reward, once.
  static const Duration glint = Duration(milliseconds: 1400);
  static const double glintAlpha = 0.22;
  static const Duration glintDelay = Duration(milliseconds: 500);

  /// Skeleton blocks while a vault tab loads.
  static const double skeletonAlpha = 0.10;
  static const double skeletonLine = 12.0;
  static const double skeletonCard = 196.0;

  /// The wax seal leading a title row.
  static const double titleSealSize = 28.0;

  /// The seven-day medallions.
  static const double dayMedal = 34.0;
  static const double dayMedalToday = 2.0;

  /// The wheel: studs around the rim, the hub coin, the pointer's shadow.
  static const int wheelStuds = 24;
  static const double wheelStud = 2.2;
  static const double wheelRimWidth = 9.0;
  static const double wheelHubCoin = 30.0;
  static const double sliceShade = 0.35;

  /// Level-up reveal: rays behind the crest and the crest's rise.
  static const int rays = 16;
  static const double raysAlpha = 0.22;
  static const double raysExtent = 1.7;
  static const double revealFromScale = 0.72;
  static const Duration revealDuration = Duration(milliseconds: 820);

  /// The invite code ticket.
  static const double ticketDash = 6.0;
  static const double ticketGap = 4.0;

  /// Leaderboard podium discs.
  static const double podiumDisc = 30.0;
  static const List<Color> podium = [
    Color(0xFFE0B85E), // first — gold
    Color(0xFFB9BCC2), // second — silver
    Color(0xFFB07A4A), // third — bronze
  ];

  /// The fade that lets a scrolling hand slide under a pinned action.
  static const double pinnedFade = 28.0;

  /// A hairline divider inside a card.
  static const double dividerAlpha = 0.6;

  /// The glow under a struck-gold button, and the lift it casts.
  static const double buttonGlowAlpha = 0.22;
  static const double buttonGlowBlur = 14.0;
  static const double buttonGlowDrop = 3.0;

  /// Lamp-light behind a crest or a medal: how far it reaches past the
  /// object, and how bright its centre is.
  static const double lampSpread = 1.25;
  static const double lampAlpha = 0.20;

  /// Below this width a row of header icons draws compact.
  static const double narrowHeaderWidth = 360.0;
}

/// Launch polish (1.0.1+10), Claude's side: the case-file look of History and
/// the other public lists. Emblems are the council's victory masks, tinted.
abstract final class UiPolishTokens {
  static const double caseEmblem = 44.0;
  static const double emptyEmblem = 96.0;
  static const double emblemOpacity = 0.9;
  static const double emptyEmblemOpacity = 0.6;
  static const double caseStripe = 3.0;
  static const double caseSurfaceOpacity = 0.86;
  static const double progressSize = 28.0;
  static const double progressStroke = 2.0;
}

/// Four Dossiers. Public/post-result geometry only; never imported by a
/// handoff, role-reveal or live-match surface.
abstract final class BondTokens {
  static const double homeLineHeight = 52.0;
  static const double portraitHeight = 148.0;
  static const double portraitAspectRatio = 2 / 3;
  static const double lockedOpacity = 0.34;
  static const double tierOneOpacity = 0.62;
  static const double tierTwoOpacity = 0.82;
  static const double unlockedOpacity = 1.0;
  static const double portraitBorder = 1.0;
  static const double veteranBorder = 2.0;
  static const double titleRuleWidth = 48.0;
  static const int lineMaxLines = 3;
  static const Duration inactiveAfter = Duration(days: 3);
}

/// Painted art that belongs to the screen instead of sitting in a box: every
/// hero, portrait and banner dissolves into the backdrop through feathered
/// edges (see `lib/ui/widgets/feathered_art.dart`). Fractions of the art's
/// own size, so a banner and a portrait feather in proportion.
abstract final class FeatherTokens {
  /// Heroes: soft all round, a longer fall at the bottom where text follows.
  static const double heroTop = 0.14;
  static const double heroBottom = 0.34;
  static const double heroSide = 0.12;

  /// Banners across the full width: sides dissolve, top and bottom barely.
  static const double bannerTop = 0.08;
  static const double bannerBottom = 0.30;
  static const double bannerSide = 0.18;

  /// Portraits standing on a surface: the feet melt into it.
  static const double portraitTop = 0.04;
  static const double portraitBottom = 0.28;
  static const double portraitSide = 0.06;

  /// A faint warm light behind the art, so it glows out of the dark rather
  /// than being cut out of it.
  static const double haloOpacity = 0.10;
  static const double haloRadius = 0.75;

  /// A painted banner across a sheet's full width.
  static const double bannerHeight = 148.0;
}

/// The Four Dossiers screen: one character per page, the portrait standing in
/// the room it belongs to, letters beneath it.
abstract final class DossierTokens {
  /// The portrait's share of the page height, and its cap on tall screens.
  static const double portraitFraction = 0.46;
  static const double portraitMaxHeight = 420.0;

  /// The character's own colour, as light behind the portrait.
  static const double auraOpacity = 0.28;
  static const double auraRadius = 0.62;

  /// A stranger's portrait: drained and dim, but still there.
  static const double strangerOpacity = 0.42;

  /// The four seals under the name.
  static const double seal = 12.0;
  static const double sealGap = 8.0;
  static const double sealStroke = 1.5;

  /// Page dots.
  static const double dot = 6.0;
  static const double dotActive = 18.0;

  /// A letter's wax mark in the margin.
  static const double letterMark = 8.0;
  static const double sealedOpacity = 1;

  /// The whisper on Home: a face beside the line.
  static const double whisperFace = 44.0;

  /// Profile strip: four standing portraits.
  static const double stripHeight = 132.0;

  static const Duration pageTurn = Duration(milliseconds: 320);

  /// The gallery paintings are cards with a drawn frame; zooming past the
  /// frame leaves the figure itself to dissolve into the night.
  static const double pastFrameZoom = 1.24;

  /// The letter-arrived moment on the result screen.
  static const double arrivalHeight = 196.0;
}

/// Launch preparation (`lib/ui/widgets/warmup_gate.dart`).
abstract final class WarmupTokens {
  /// Preparation never holds the table longer than this.
  static const Duration maxWait = Duration(seconds: 25);
  static const Duration serverWait = Duration(seconds: 8);

  /// First-screen paintings are decoded at phone width, a few at a time.
  static const int decodeMaxWidth = 1080;
  static const int decodeBatch = 4;

  static const double mask = 112.0;
  static const double barWidth = 220.0;
  static const double barHeight = 3.0;
  static const double backdropOpacity = 0.35;
}

/// Decode and effect budgets used by the low-end device classification.
abstract final class DeviceClassTokens {
  static const int lowEndPhysicalPixels = 1800000;
  static const int backdropDecodeMaxWidth = 1440;
  static const int backdropDecodeMaxHeight = 2560;
  static const double cardDecodeScale = 1.15;
  static const int cardDecodeMaxWidth = 768;
  static const int fallingIconCount = 24;
  static const int lowEndFallingIconCount = 12;
  static const int lowEndRewardParticleCount = 5;
}

/// «أصحابك» (`lib/ui/screens/online/friends.dart`).
abstract final class FriendsTokens {
  /// The «a friend is at a table» dot on the small friends icon.
  static const double presenceDot = 8.0;

  static const double sheetHeight = 0.9;
  static const double heroHeight = 120.0;
  static const double avatar = 44.0;

  /// D5: while the online door is on screen and the app is in front, lobby
  /// invites are asked for this often. Nothing is asked in the background.
  static const Duration inviteRefresh = Duration(seconds: 20);
}

/// Accounts (`lib/ui/account/account_sheet.dart`).
abstract final class AccountTokens {
  static const double sheetHeight = 0.92;
  static const double heroHeight = 96.0;
  static const double progress = 20.0;
  static const double progressStroke = 2.0;
  static const int resendSeconds = 60;
  static const int codeLength = 6;

  /// How long a sign-in that left for a browser (Google, an email link) counts
  /// as coming back. Within it, «تذكّرني» off does not sign the returning
  /// account straight out again.
  static const Duration pendingReturn = Duration(minutes: 15);
}

/// The full profile (`lib/ui/account/profile_panels.dart`).
abstract final class ProfileTokens {
  static const double statArt = 56.0;

  /// The card's photo: a Mafia seat card clipped to a portrait, standing
  /// straight, and the avatar inside it.
  static const Size photo = Size(112, 144);
  static const double photoAvatar = 80;

  /// The stamp sits over the photo's corner.
  static const double stampTop = 4;

  /// How long a profile save waits for the server's word on the name before
  /// saving anyway (the server still checks it at every room).
  static const Duration nameCheckWait = Duration(seconds: 4);
}

/// «ملف القضايا» (`lib/ui/missions/casebook_sheet.dart`): drawn in the
/// vault's engraved family — lit panels, struck gold, a gold thread for the
/// season, a wall of seals for the record.
abstract final class CasebookTokens {
  static const double sheetHeight = 0.94;
  static const double heroHeight = 156.0;
  static const Duration pageTurn = Duration(milliseconds: 260);

  /// The hero's stamped plate: a struck-gold level disc and a gold-rimmed
  /// enamel strip beside it.
  static const double plateDisc = 40.0;
  static const double plateHeight = 30.0;
  static const double plateRimAlpha = 0.7;
  static const double heroShade = 0.55;

  /// Gold underline tabs: the struck rule under the open page, its glow, the
  /// hairline under all three, and the small count plate.
  static const double tabRule = 44.0;
  static const double tabRuleHeight = 3.0;
  static const double tabGlowAlpha = 0.45;
  static const double tabGlowBlur = 8.0;
  static const double tabBaseAlpha = 0.5;
  static const double countPlate = 18.0;

  /// A case card and the character standing half inside it.
  static const double portraitWidth = 84.0;
  static const double portraitRise = 18.0;
  static const double weeklyPortraitWidth = 104.0;
  static const double weeklyPortraitRise = 30.0;
  static const double donePortraitOpacity = 0.45;

  /// The gallery paintings carry a drawn frame and a caption at the top;
  /// a crop just below them keeps the face and loses the card.
  static const Alignment faceFocus = Alignment(0, -0.35);
  static const double claimMinWidth = 96.0;
  static const double busyIndicator = 18.0;
  static const double busyStroke = 2.0;

  /// The season thread: one stop per row, winding across the page. Gold
  /// where it has been walked, dim dashed metal ahead.
  static const double stopHeight = 84.0;
  static const double seal = 42.0;
  static const double sealRim = 1.5;
  static const double sealRimNext = 2.0;
  static const double sealInnerInset = 4.0;
  static const double sealInnerAlpha = 0.45;
  static const double windFrequency = 0.9;
  static const double windAmplitude = 0.26;
  static const double glowAlpha = 0.55;
  static const double glowBlur = 18.0;
  static const double lockedMetalAlpha = 0.55;
  static const double threadWidth = 3.0;
  static const double threadHalo = 9.0;
  static const double threadHaloAlpha = 0.22;
  static const double threadShineAlpha = 0.6;
  static const double threadSlackWidth = 1.4;
  static const double threadSlackAlpha = 0.45;
  static const double threadDash = 5.0;
  static const double threadGap = 5.0;

  /// The record: a wall of seals, three to a row. A locked seal is its
  /// own silhouette pressed dim into the page.
  static const int legacyColumns = 3;
  static const double legacySeal = 76.0;
  static const double legacyIcon = 0.46;
  static const double legacyBar = 6.0;
  static const double lockedSealOpacity = 0.32;
  static const double rankEmblem = 56.0;

  /// Rec. 709 luma, for pressing a locked seal into grey.
  static const List<double> luma = [0.2126, 0.7152, 0.0722];

  /// The entrance: rows rise into place one after another, once.
  static const Duration rise = Duration(milliseconds: 380);
  static const Duration riseStep = Duration(milliseconds: 70);
  static const int riseMaxSteps = 6;
  static const double riseLift = 14.0;

  /// The door on Online.
  static const double entryHeight = 96.0;
  static const double entryFacesWidth = 150.0;
}

/// P6: the pass-and-play result inventory (`pass_result_inventory.dart`).
abstract final class PassInventoryTokens {
  /// The daily rewards sheet opened from the result.
  static const double sheetHeight = 0.9;
}

/// Store truth: a buyer sees what they bought wherever their identity is shown.
abstract final class StoreTruthTokens {
  /// The Home chip and list rows: this player's own avatar.
  static const double chipAvatar = 36.0;

  /// The framed avatar among Home's corner icons.
  static const double cornerAvatar = 32.0;

  /// The account sheet's identity.
  static const double sheetAvatar = 64.0;

  /// The purchase reveal: the item on the buyer's own avatar.
  static const double revealAvatar = 96.0;

  /// The reveal's rise, once; reduced motion shows it at rest.
  static const Duration revealRise = Duration(milliseconds: 520);
  static const double revealLift = 18.0;

  /// A narrator pack's caption marker (its own glyph beside the line).
  static const double narratorMarker = 18.0;
  static const double narratorBorderWidth = 1.2;

  /// The lobby's ready countdown redraws once a second.
  static const Duration countdownTick = Duration(seconds: 1);

  /// Each narrator pack's caption: its ground, rule and ink, so the three are
  /// told apart at a glance at every public beat, online and in «القعدة».
  static const Color storytellerGround = Color(0xE61E160E);
  static const Color storytellerRule = Color(0xFFC9A45C);
  static const Color storytellerInk = Color(0xFFF1DFA8);
  static const Color keeperGround = Color(0xE6121820);
  static const Color keeperRule = Color(0xFF9AA6B8);
  static const Color keeperInk = Color(0xFFE3E8F0);
  static const Color noirGround = Color(0xF20A0A0A);
  static const Color noirRule = Color(0xFF7A1F24);
  static const Color noirInk = Color(0xFFF2EBDD);
}

/// Invites that reach the phone (`lib/ui/screens/online/invite_sheet.dart`,
/// `lib/ui/social/incoming_invite.dart`, `lib/platform/push/**`).
abstract final class InviteTokens {
  /// The «ادعي صحابك» sheet: share of the screen height at most.
  static const double sheetHeight = 0.86;
  static const double rowAvatar = 44.0;
  static const double popupAvatar = 72.0;

  /// The knock-on-the-door art behind the inviter's framed face.
  static const double knockArt = 128.0;
  static const double stateDot = 8.0;
  static const double spinner = 16.0;
  static const double spinnerStroke = 2.0;
  static const double scrimAlpha = 0.72;
  static const double chipAlpha = 0.24;

  /// The empty-state art above an empty tab's text.
  static const double emptyArtWidth = 240.0;

  /// Typing pauses this long before a search is sent.
  static const Duration searchDebounce = Duration(milliseconds: 350);

  /// While the app is in front, pending invites are asked for this often
  /// (the codebase's existing short poll, as for «أصحابك»).
  static const Duration inboxPoll = Duration(seconds: 20);

  /// The directory's «أونلاين دلوقتي» is refreshed at most this often.
  static const Duration presenceBeat = Duration(minutes: 2);

  /// Firebase start at launch is given at most this long.
  static const Duration pushStart = Duration(seconds: 3);

  /// The popup rises once; reduced motion shows it at rest.
  static const Duration popupRise = Duration(milliseconds: 320);
  static const double popupLift = 24.0;

  /// «اتبعتت ✓» stays; a failure clears after this.
  static const Duration failedHold = Duration(seconds: 3);

  /// The long "someone's at the door" vibration, in milliseconds: wait, buzz,
  /// pause, buzz … about two seconds. The same pattern the Android channel
  /// and the web notification use (supabase/functions/_shared/push.ts).
  static const List<int> longVibration = [0, 400, 180, 400, 180, 700];

  /// Our gold, for the Android notification accent.
  static const Color accent = Color(0xFFC2AF81);

  /// Friend requests on the quieter channel: one short buzz.
  static const List<int> shortVibration = [0, 180];

  /// The browser's Vibration API has no "selection click" or "light impact",
  /// so a web tap buzzes for this many milliseconds (Android Chrome only;
  /// every other browser ignores it). Role-blind, as every haptic is (L-10).
  static const List<int> webSelectTick = [8];
  static const List<int> webConfirmTick = [16];
}

/// «حدّث التطبيق» (`lib/app/update_gate.dart`): the server-driven minimum
/// build. The sheet is drawn over the whole app, so it owns its own scrim.
abstract final class UpdateGateTokens {
  /// How long the start-up read may take. A slow answer is no answer: the app
  /// is never held at the door by it.
  static const Duration fetchTimeout = Duration(seconds: 8);

  /// A build left open for days asks again after this long in the background.
  static const Duration recheck = Duration(minutes: 30);

  /// The Play listing, tried in this order: the Play app (`market:`), then the
  /// web page (which hands over to the app, or opens in a browser).
  static final List<Uri> storeUris = [
    Uri.parse('market://details?id=$playApplicationId'),
    Uri.parse(
      'https://play.google.com/store/apps/details?id=$playApplicationId',
    ),
  ];

  /// `applicationId` in `android/app/build.gradle.kts`.
  static const String playApplicationId = 'com.mafiamaster.mafia_master';

  /// The inline «مقدرناش نفتح Google Play» note under the button.
  static const double noteRadius = 10.0;
}

/// Web display inventory. Every ad is outside the private table.
abstract final class WebAdTokens {
  /// The reserved banner slot. 90 so a 728x90 leaderboard fits exactly; the
  /// JS shell sizes the Google unit from the slot and never lets it exceed it.
  static const bannerHeight = 90.0;
  static const bannerArt = 56.0;
  static const bannerGap = 12.0;
  static const interstitialArt = 132.0;
  static const interstitialMaxWidth = 420.0;
  static const interstitialPad = 24.0;
  static const closeDelay = Duration(seconds: 5);
  static const googleBreakTimeout = Duration(seconds: 4);
  static const googleBannerTimeout = Duration(seconds: 4);
  static const transition = Duration.zero;
  static const appOpenDelay = Duration(seconds: 4);

  /// Least time between the end of one web break and the start of a
  /// navigation-driven one (enterLocal / enterOnline), so going back and forth
  /// between menu screens cannot chain breaks. Matches Android's gap; web is
  /// still heavier because every completed match and app open also breaks.
  static const minBreakGap = Duration(seconds: 90);
}

/// The offline state on the online door (`lib/ui/widgets/connection_problem.dart`).
abstract final class OnlineEntryTokens {
  static const double sheetScrimOpacity = 0.78;
}

abstract final class ConnectionProblemTokens {
  static const double iconSize = 32.0;
}

/// «قصص»: public case cards and the one-phone private hand-off flow.
abstract final class StoryTokens {
  static const double coverHeight = 164.0;
  static const double compactCoverHeight = 116.0;
  static const double portrait = 128.0;
  static const double clueMinHeight = 112.0;
  static const double timerDiameter = 104.0;
  static const double lockedOpacity = 0.48;
  static const double transparentAlpha = 0.0;
  static const double featherStart = 0.56;
  static const double featherEnd = 1.0;
  static const int rounds = 3;
  static const int nearImpossibleUnlocks = 3;

  /// Extra investigation steps a case may buy with rewarded ads.
  static const int bonusSteps = 2;
  static const Duration privateHold = Duration(milliseconds: 800);
  static const Duration timerTick = Duration(seconds: 1);
  static const Duration reenactmentBeat = Duration(milliseconds: 420);

  // --- The dark case file (P12): folders, paper notes, pips, ballots. ---
  static const Color note = Color(0xFFD9CDB4);
  static const Color noteInk = Color(0xFF2A1D14);
  static const Color noteShadow = Color(0xAA000000);
  static const Color sealTop = Color(0xFFD0645A);
  static const Color sealBottom = Color(0xFF7D2A23);
  static const Color sealGlyph = Color(0xFFF2D6CF);
  static const Color stampOpen = Color(0xFF9E9891);
  static const Color photoShade = Color(0xFF1A130E);
  static const Color scrim = Color(0xAA0D0907);
  static const Color ringTrack = Color(0xFF3A2D23);
  static const Color transparentColor = Color(0x00000000);

  /// The archive: a folder is a paper with a numbered tab and a clipped photo.
  static const double folderTabHeight = 22.0;
  static const double folderTabInset = 14.0;
  static const double folderPhotoWidth = 104.0;
  static const double folderPhotoHeight = 132.0;
  static const double folderPhotoTilt = -0.052; // -3 degrees
  static const double photoMat = 5.0;
  static const double photoMatBottom = 18.0;
  static const double clipWidth = 22.0;
  static const double clipHeight = 16.0;
  static const double clipStroke = 3.0;
  static const double sealSize = 44.0;
  static const double stampInset = 12.0;
  static const double stampFolderTilt = -0.17; // -10 degrees
  static const double sepia = 0.2;
  static const double chipHeight = 38.0;
  static const double lockedPhotoAlpha = 0.4;

  /// The narrator bar.
  static const double playButton = 48.0;
  static const int waveBars = 26;
  static const double waveBarWidth = 3.0;
  static const double waveBarMin = 6.0;
  static const double waveBarMax = 26.0;
  static const Duration waveTick = Duration(milliseconds: 140);

  /// Move pips and the cost dot.
  static const double pip = 11.0;
  static const double pipSpent = 0.7;
  static const double pipsMaxWidth = 200.0;
  static const double costDot = 46.0;
  static const double costStroke = 1.5;
  static const Duration pipFade = Duration(milliseconds: 300);
  static const double poorOpacity = 0.4;
  static const double doneOpacity = 0.45;

  /// Paper notes pinned on «اللي لقيته».
  static const double noteWidth = 150.0;
  static const double noteLift = 30.0;
  static const double noteTurn = 0.2;
  static const double pinSize = 10.0;
  static const Duration notePin = Duration(milliseconds: 500);
  static const Duration noteStagger = Duration(milliseconds: 120);

  /// Suspect photos, on the accusation and the ballot.
  static const double suspectWidth = 86.0;
  static const double suspectHeight = 112.0;
  static const double suspectLift = 6.0;
  static const double suspectTurn = -0.035;
  static const double suspectRing = 2.0;
  static const double suspectRingGap = 2.0;
  static const Duration suspectLiftTime = Duration(milliseconds: 250);
  static const double optionDot = 20.0;
  static const double optionDotStroke = 1.5;

  /// The private dossier: one frame, one length of time, for every seat.
  static const Duration dossierHold = Duration(seconds: 5);
  static const double dossierPhotoWidth = 96.0;
  static const double dossierPhotoHeight = 124.0;
  static const int dossierNotes = 3;
  static const double dossierDash = 1.5;
  static const double emptyClueSlot = 72;
  static const double dashAlpha = 0.33;

  /// The cast, the table and the line-up.
  static const double castPhotoWidth = 44.0;
  static const double castPhotoHeight = 56.0;
  static const double lineupWidth = 70.0;
  static const double lineupHeight = 88.0;
  static const double heroHeight = 150.0;
  static const double timerRing = 170.0;
  static const double timerStroke = 6.0;
  static const double passName = 44.0;

  /// The secret ballot and the reenactment.
  static const Duration ballotHold = Duration(seconds: 2);
  static const Duration reenactStep = Duration(milliseconds: 1300);
  static const Duration reenactFade = Duration(milliseconds: 500);
  static const double reenactDim = 0.15;
  static const double timelineDot = 10.0;
  static const double timelineLine = 1.0;
  static const double timelineGutter = 22.0;
  static const double stampBig = 34.0;
  static const double stampBigBorder = 5.0;
  static const Duration stampDrop = Duration(milliseconds: 500);

  /// The cases' headings are set in Ruqaa, the hand of old Cairo signs and
  /// police ledgers; body text stays in the app's reading face.
  static const String displayFont = 'Aref Ruqaa';

  static TextStyle ruqaa(TextStyle base) => base.copyWith(
    fontFamily: displayFont,
    fontFamilyFallback: const <String>['Cairo'],
    fontVariations: const <FontVariation>[],
    fontWeight: FontWeight.w700,
  );
}

/// The discussion screen's extras.
abstract final class DiscussionTokens {
  /// The bots' lines card stops growing here and scrolls.
  static const double tableTalkMaxHeight = 160.0;
}

/// A hand of cards fanned out (the roles screen, the computer's table).
abstract final class FanTokens {
  /// Each card sits this far from its neighbour, until the hand would leave
  /// the stage; then it tightens.
  static const double tilt = 0.105; // 6°

  /// The whole hand never turns past this, however many cards it holds.
  static const double maxSpread = 0.9;

  /// The point the cards turn about, below the hand (alignment y).
  static const double pivot = 1.6;

  /// A card arriving starts small, in the middle, and spreads out.
  static const double enterScale = 0.6;
  static const Duration move = Duration(milliseconds: 450);
  static const double shadowBlur = 12;
  static const double shadowAlpha = 0.6;
  static const double shadowDrop = 6;
  static const double radius = 7;
}

/// «الأدوار»: presets, the big fan, role rows.
abstract final class RolesTokens {
  /// One card of the fan, and the same on a short phone.
  static const Size fanCard = Size(78, 117);
  static const Size fanCardCompact = Size(58, 87);
  static const double fanStep = 26;
  static const double fanStepCompact = 20;

  /// Stage height for the fan; the card stands at its bottom edge.
  static const double fanHeight = 150;
  static const double fanHeightCompact = 112;
  static const double fanShort = 700;

  static const double rowGap = 10;
  static const double rowPad = 8;
  static const double stepperButton = 48;
  static const double stepperCount = 30;
  static const double presetGap = 8;
  static const double lockedTextAlpha = 0.7;
}

/// «العب ضد الكمبيوتر»: the table, the levels.
abstract final class BotTokens {
  static const Size tableCard = Size(52, 78);
  static const double tableStep = 30;
  static const double tableHeight = 118;
  static const double tableLift = 6;
  static const double youLabel = 10;
  static const double levelGap = 10;
  static const double levelLift = 0.04; // of the card's height
  static const Duration levelMove = Duration(milliseconds: 200);
}

/// First run: the deck fans into the logo, «نكلّمك إزاي؟», «اسمك إيه؟»,
/// «نحفظ لعبك؟».
abstract final class FirstRunTokens {
  /// The opening: how long the deck takes to fan, and how long the logo is
  /// held before the first question. Reduced motion holds the end state only.
  static const Duration fan = Duration(milliseconds: 900);
  static const Duration intro = Duration(milliseconds: 2600);
  static const Duration introStill = Duration(milliseconds: 900);
  static const Duration stepSlide = Duration(milliseconds: 450);
  static const Duration shake = Duration(milliseconds: 400);
  static const Duration flip = Duration(milliseconds: 600);
  static const Duration hold = Duration(milliseconds: 600);
  static const Duration land = Duration(milliseconds: 600);

  /// The fanned deck: card size, spread, tilt (radians), drop at the edges.
  static const Size deckCard = Size(76, 114);
  static const double deckSpread = 30;
  static const double deckTilt = 0.1;
  static const double deckDrop = 9;
  static const int deckCount = 7;

  /// Progress dots.
  static const double dot = 6;
  static const double dotWide = 20;
  static const Duration dotMove = Duration(milliseconds: 350);

  /// The two big cards.
  static const double pickAspect = 1.5;
  static const double pickMaxHeight = 260;
  static const double pickGap = 12;
  static const double dimmedAlpha = 0.5;
  static const double shakeShift = 6;
  static const double passedAlpha = 0.15;
  static const double chosenLift = 8;

  /// The card that carries the name.
  static const double myCardWidth = 150;
  static const double landRise = 40;
  static const double landTilt = 0.1;
  static const double myCardMin = 96;
  static const double myCardTiny = 72;

  /// Below this much room (keyboard up on a short phone) the name step
  /// drops its hint and shrinks its card.
  static const double roomyAbove = 420;
  static const int nameMin = 2;
  static const int nameMax = 20;

  static const double agreeBorder = 1;
  static const double box = 26;
  static const double boxRadius = 7;

  /// The «محفوظ» ring on the last step.
  static const double safeRing = 118;
  static const double safeCoin = 46;
}

/// The settings sheet over Home: groups, rows, the «اتحفظ» toast.
abstract final class SettingsSheetTokens {
  static const Duration toast = Duration(milliseconds: 1200);
  static const Duration toastMove = Duration(milliseconds: 300);
  static const double toastRise = 10;
  static const double groupRadius = 14;
  static const double rowMin = 56;
  static const double linkMin = 52;
  static const double stepperButton = 48;
  static const double stepperValue = 72;
}

/// «إزاي نلعب»: the booklet, the flip role cards, the FAQ.
abstract final class HowToTokens {
  static const double pageArtHeight = 200;
  static const double pageArtHeightCompact = 140;
  static const double compactBelow = 700;
  static const double pageBodyMin = 90;
  static const double artRadius = 14;
  static const double artFadeFrom = 0.5;
  static const double artScrimAlpha = 0.93;
  static const double roleDecode = 100;
  static const double roleAspect = 0.66;
  static const int roleColumns = 4;
  static const double roleGap = 8;
  static const double roleBackPad = 6;
  static const double rolePerspective = 0.0012;
  static const Duration flip = Duration(milliseconds: 600);
  static const Duration page = Duration(milliseconds: 300);
  static const Duration faq = Duration(milliseconds: 300);
  static const double dot = 6;
  static const double dotWide = 18;
}

/// The casebook's dark cork board: pinned notes joined by red string.
abstract final class CorkTokens {
  /// A note's width as a share of the board, and how far each tilts.
  static const double noteWidth = 0.88;
  static const double tilt = 0.035;

  /// The pin and the string between two notes.
  static const double pin = 12;
  static const double pinLift = 6;
  static const double stringWidth = 2;
  static const double stringGap = 28;

  /// The cork's speckle: spacing and dot size.
  static const double dotGap = 7;
  static const double dotRadius = 1;
  static const double dotAlpha = 0.5;

  /// The «اتقفلت» stamp landing on a note.
  static const Duration stampDrop = Duration(milliseconds: 380);
  static const double noteIcon = 40;
  static const double doneAlpha = 0.6;
}

/// «الأباجورة» — the Stories V2 look the owner chose (2026-10-15), from the
/// draft `design-system/stories/tokens.css`. Used only by
/// `lib/ui/screens/stories/v2/`; never on a Mafia screen.
abstract final class StoriesLampTokens {
  // The room (lamp-dark ground).
  static const Color night = Color(0xFF0A0402);
  static const Color ground = Color(0xFF150B06);
  static const Color panel = Color(0xFF20120A);
  static const Color raised = Color(0xFF2C1A0F);
  static const Color line = Color(0xFF3D2617);
  static const Color text = Color(0xFFF1E3C8);
  static const Color text2 = Color(0xFFC9B597);
  static const Color muted = Color(0xFF8F7A62);

  // The paper: the only light surface.
  static const Color paper = Color(0xFFE1D0AC);
  static const Color paperLine = Color(0xFFB49C70);
  static const Color paperInk = Color(0xFF2A1A10);
  static const Color paperInk2 = Color(0xFF5B4430);

  // Lamplight is the action; velvet is the verdict.
  static const Color amber = Color(0xFFB36E2D);
  static const Color amberHi = Color(0xFFE0A55C);
  static const Color amberDeep = Color(0xFF7A4519);
  static const Color onAmber = Color(0xFF1A0C04);
  static const Color velvet = Color(0xFF6E1A16);
  static const Color glow = Color(0x2EE0A55C);
  static const Color shadow = Color(0x800A0402);

  /// The private role line: one colour and shape for every role (Doc 05).
  static const Color secret = velvet;

  static const double radiusPaper = 6;
  static const double radiusButton = 10;
  static const double radiusSheet = 16;
  static const double buttonHeight = 48;
  static const double heroHeight = 180;
  static const double coverWidth = 64;
  static const double coverHeight = 86;

  static const double caseTitle = 22;

  /// Hub covers decoded ahead of the hub: about one screenful.
  static const int coversAhead = 6;
  static const double lockedCase = 0.6;
  static const double faceWidth = 44;
  static const double faceHeight = 54;
  static const double cardFaceWidth = 88;
  static const double cardFaceHeight = 108;
  static const double revealFaceWidth = 100;
  static const double revealFaceHeight = 124;
  static const double pickFaceWidth = 92;
  static const double pickFaceHeight = 112;
  static const double faceBorder = 2;
  static const double pickedBorder = 3;
  static const double titleSize = 30;
  static const double titleSmall = 24;
  static const double handoffName = 46;
  static const double barHeight = 6;
  static const double barTouch = 32;
  static const double knob = 14;
  static const double control = 44;
  static const double controlMain = 56;
  static const double holdPad = 84;
  static const double holdStroke = 3;
  static const double paperLift = 1;
  static const double paperBlur = 18;
  static const double secretTilt = -0.026;

  static const double dimmed = 0.38;
  static const double glowHeight = 0.42;
  static const Duration hold = Duration(milliseconds: 900);
  static const Duration fade = Duration(milliseconds: 220);

  /// How long a table waits for the server's deal (story sessions) before
  /// it deals on the phone and plays without coins.
  static const Duration serverDealWait = Duration(milliseconds: 2500);

  /// The server pays a v2 first solve only a minute after its deal
  /// (`claim_story_session`); a faster table waits this long from the deal
  /// before claiming, so the reward is not lost (a minute plus a margin).
  static const Duration serverClaimMinimum = Duration(seconds: 62);
}

/// «خلّي اللعبة على شاشتك» (lib/ui/widgets/add_to_home_sheet.dart).
abstract final class AddToHomeTokens {
  /// The square each step's mark sits in.
  static const double mark = 28;
}
