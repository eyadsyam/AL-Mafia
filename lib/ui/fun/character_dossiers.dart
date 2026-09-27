import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../economy/council_art.dart' show CouncilRaster, RasterOr;

import '../../app/l10n/app_localizations.dart';
import '../../data/character_bonds.dart';
import '../../engine/models/enums.dart' hide Alignment;
import '../l10n_ext.dart';
import '../screens/postgame/result_screen.dart' show RoleGalleryPortrait;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/feathered_art.dart';

class CharacterDossiers extends ConsumerWidget {
  /// Opens the full dossiers screen; null keeps the strip inert.
  final VoidCallback? onOpen;
  const CharacterDossiers({super.key, this.onOpen});

  static const sectionKey = ValueKey('bond_dossiers');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(characterBondLedgerProvider).valueOrNull;
    if (ledger == null) return const SizedBox.shrink();
    final spacing = context.spacing;
    final colors = context.colors;
    return Semantics(
      button: onOpen != null,
      label: context.l10n.bondOpenAll,
      child: InkWell(
        key: sectionKey,
        onTap: onOpen,
        borderRadius: BorderRadius.circular(context.radii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: spacing.xl),
            Text(
              context.l10n.bondDossiersTitle,
              style: context.typography.headline,
              textAlign: TextAlign.center,
            ),
            Text(
              context.l10n.bondDossiersHint,
              style: context.typography.caption.copyWith(
                color: colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.sm),
            // Four characters standing side by side, each melting into the
            // page; the ones you have not met yet are drained of colour.
            SizedBox(
              height: DossierTokens.stripHeight,
              child: Row(
                children: [
                  for (final role in Role.values)
                    Expanded(
                      child: _StandingPortrait(
                        role: role,
                        tier: ledger.bond(role).tier,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingPortrait extends StatelessWidget {
  final Role role;
  final int tier;
  const _StandingPortrait({required this.role, required this.tier});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Expanded(
          child: Opacity(
            opacity: tier == 0 ? DossierTokens.strangerOpacity : 1,
            child: FeatheredArt(
              feather: Feather.portrait,
              child: ColorFiltered(
                colorFilter: tier == 0
                    ? const ColorFilter.matrix(bondStrangerMatrix)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: BondPortraitArt(
                  role: role,
                  fit: BoxFit.contain,
                  cacheHeight: (DossierTokens.stripHeight * 2).ceil(),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < bondTierThresholds.length; i++)
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: DossierTokens.sealGap / 4,
                ),
                width: DossierTokens.dot,
                height: DossierTokens.dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < tier ? colors.accentGold : colors.borderSubtle,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Luminance-weighted greyscale: a character you have not met yet.
const List<double> bondStrangerMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

String bondLetter(AppLocalizations l, Role role, int tier) {
  if (tier == 0) return l.bondLockedLine;
  return switch ((role, tier)) {
    (Role.mafia, 1) => l.bondMafiaTier1,
    (Role.mafia, 2) => l.bondMafiaTier2,
    (Role.mafia, 3) => l.bondMafiaTier3,
    (Role.mafia, _) => l.bondMafiaTier4,
    (Role.doctor, 1) => l.bondDoctorTier1,
    (Role.doctor, 2) => l.bondDoctorTier2,
    (Role.doctor, 3) => l.bondDoctorTier3,
    (Role.doctor, _) => l.bondDoctorTier4,
    (Role.detective, 1) => l.bondDetectiveTier1,
    (Role.detective, 2) => l.bondDetectiveTier2,
    (Role.detective, 3) => l.bondDetectiveTier3,
    (Role.detective, _) => l.bondDetectiveTier4,
    (Role.citizen, 1) => l.bondCitizenTier1,
    (Role.citizen, 2) => l.bondCitizenTier2,
    (Role.citizen, 3) => l.bondCitizenTier3,
    (Role.citizen, _) => l.bondCitizenTier4,
  };
}

String bondTitle(AppLocalizations l, Role role) => switch (role) {
  Role.mafia => l.bondTitleMafia,
  Role.doctor => l.bondTitleDoctor,
  Role.detective => l.bondTitleDetective,
  Role.citizen => l.bondTitleCitizen,
};

String bondHomeLine(AppLocalizations l, Role role) => switch (role) {
  Role.mafia => l.bondHomeMafia,
  Role.doctor => l.bondHomeDoctor,
  Role.detective => l.bondHomeDetective,
  Role.citizen => l.bondHomeCitizen,
};

String bondMomentLine(AppLocalizations l, Role role) => switch (role) {
  Role.mafia => l.bondMomentMafia,
  Role.doctor => l.bondMomentDoctor,
  Role.detective => l.bondMomentDetective,
  Role.citizen => l.bondMomentCitizen,
};

/// One public, fixed-height whisper on Home: the character's face, dissolving
/// into the night, and its line. Tapping it opens the dossiers.
/// Its inputs are completed local receipts only.
class BondHomeLine extends ConsumerWidget {
  final VoidCallback? onTap;
  const BondHomeLine({super.key, this.onTap});
  static const lineKey = ValueKey('bond_home_line');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(characterBondLedgerProvider).valueOrNull;
    if (ledger == null || ledger.isEmpty) return const SizedBox.shrink();
    final role = homeBondVoice(
      ledger,
      ref.watch(characterBondClockProvider)(),
      inactiveAfter: BondTokens.inactiveAfter,
    );
    final spacing = context.spacing;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        key: lineKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.card),
        child: SizedBox(
          height: BondTokens.homeLineHeight,
          child: Row(
            children: [
              SizedBox.square(
                dimension: DossierTokens.whisperFace,
                child: FeatheredArt(
                  feather: Feather.portrait,
                  child: BondPortraitArt(
                    role: role,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    cacheWidth: (DossierTokens.whisperFace * 3).ceil(),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  bondHomeLine(context.l10n, role),
                  maxLines: BondTokens.lineMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A character's full-colour painting, zoomed past the card frame drawn into
/// it, so only the figure is left to dissolve into whatever is behind it.
class BondPortraitArt extends StatelessWidget {
  final Role role;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final int? cacheWidth;
  final int? cacheHeight;
  const BondPortraitArt({
    super.key,
    required this.role,
    this.fit = BoxFit.contain,
    this.alignment = AlignmentDirectional.center,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Transform.scale(
      scale: DossierTokens.pastFrameZoom,
      alignment: alignment,
      child: Image.asset(
        RoleGalleryPortrait.art(role),
        fit: fit,
        alignment: alignment,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        excludeFromSemantics: true,
      ),
    ),
  );
}

/// On the result screen, when this match opened a letter: the character
/// rising out of the level-up rays, its name, and the letter itself. Tapping
/// it opens that character's dossier.
class BondLetterArrivedCard extends StatelessWidget {
  final BondLetterArrival arrival;
  const BondLetterArrivedCard({super.key, required this.arrival});

  static const cardKey = ValueKey('bond_letter_arrived');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final name = EngineCopy.roleName(l, arrival.role);
    return Semantics(
      button: true,
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(context.radii.card),
        onTap: () => GoRouter.maybeOf(
          context,
        )?.push('/characters?role=${arrival.role.name}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: DossierTokens.arrivalHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: FeatheredArt(
                      feather: Feather.hero,
                      halo: false,
                      child: RasterOr(
                        path: CouncilRaster.levelUpRays,
                        fit: BoxFit.cover,
                        fallback: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  FeatheredArt(
                    feather: Feather.portrait,
                    child: BondPortraitArt(
                      role: arrival.role,
                      cacheHeight: (DossierTokens.arrivalHeight * 2).ceil(),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              l.bondNewLetter(name),
              textAlign: TextAlign.center,
              style: type.title.copyWith(color: colors.accentGold),
            ),
            SizedBox(height: spacing.xs),
            Text(
              '«${bondLetter(l, arrival.role, arrival.tier)}»',
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
