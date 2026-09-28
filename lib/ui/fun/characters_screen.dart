import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../../data/character_bonds.dart';
import '../../engine/models/enums.dart';
import '../../platform/reduce_motion.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/back_action.dart';
import '../widgets/feathered_art.dart';
import '../widgets/textured_surface.dart';
import 'character_dossiers.dart';

/// The Four Dossiers, one character to a page.
///
/// Each page is the character standing in its own light — the full-colour
/// gallery painting, feathered into the night, with the character's colour
/// glowing behind it — and under it the letters it has written to this table.
/// Opened letters read in full; the rest stay sealed and say how many more
/// cases open them.
///
/// Public and outside any match: everything here comes from completed,
/// already-revealed results (see `character_bonds.dart`).
class CharactersScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  /// The page to open on, e.g. the character whose letter just arrived.
  final Role? initial;

  const CharactersScreen({super.key, required this.onBack, this.initial});

  static const Key pages = ValueKey('characters_pages');
  static Key pageFor(Role role) => ValueKey('characters_page_${role.name}');

  @override
  ConsumerState<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends ConsumerState<CharactersScreen> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = Role.values.indexOf(widget.initial ?? Role.values.first);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger =
        ref.watch(characterBondLedgerProvider).valueOrNull ??
        CharacterBondLedger.empty;
    final colors = context.colors;
    final spacing = context.spacing;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
        image: AppImages.bgNight,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                child: Row(
                  children: [
                    BackAction(onPressed: widget.onBack),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            l.bondDossiersTitle,
                            style: context.typography.title.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            l.bondScreenSubtitle,
                            style: context.typography.caption.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Balances the back control so the title sits centred.
                    SizedBox(width: spacing.xxl),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  key: CharactersScreen.pages,
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final role in Role.values)
                      _CharacterPage(
                        key: CharactersScreen.pageFor(role),
                        role: role,
                        bond: ledger.bond(role),
                      ),
                  ],
                ),
              ),
              _PageDots(
                count: Role.values.length,
                index: _index,
                colorOf: (i) => _roleColor(context, Role.values[i]),
                onTap: (i) => _pages.animateToPage(
                  i,
                  duration: ReduceMotion.of(context)
                      ? Duration.zero
                      : DossierTokens.pageTurn,
                  curve: Curves.easeOutCubic,
                ),
              ),
              SizedBox(height: spacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

Color _roleColor(BuildContext context, Role role) {
  final colors = context.colors;
  return switch (role) {
    Role.mafia => colors.roleMafia,
    Role.doctor => colors.roleDoctor,
    Role.detective => colors.roleDetective,
    Role.citizen => colors.roleCitizen,
  };
}

class _CharacterPage extends StatelessWidget {
  final Role role;
  final CharacterBond bond;
  const _CharacterPage({super.key, required this.role, required this.bond});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l = context.l10n;
    final tier = bond.tier;
    final tint = _roleColor(context, role);
    final height = MediaQuery.sizeOf(context).height;
    final portraitHeight = (height * DossierTokens.portraitFraction).clamp(
      0.0,
      DossierTokens.portraitMaxHeight,
    );

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: spacing.screenMargin),
      children: [
        // The character, lit from behind by its own colour, dissolving into
        // the night at every edge.
        SizedBox(
          height: portraitHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: DossierTokens.auraRadius,
                colors: [
                  tint.withValues(alpha: DossierTokens.auraOpacity),
                  tint.withValues(alpha: 0),
                ],
              ),
            ),
            child: Opacity(
              opacity: tier == 0 ? DossierTokens.strangerOpacity : 1,
              child: FeatheredArt(
                feather: Feather.portrait,
                halo: false,
                child: ColorFiltered(
                  colorFilter: tier == 0
                      ? const ColorFilter.matrix(bondStrangerMatrix)
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.dst,
                        ),
                  child: BondPortraitArt(
                    role: role,
                    fit: BoxFit.contain,
                    cacheHeight: (portraitHeight * 2).ceil(),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          EngineCopy.roleName(l, role),
          textAlign: TextAlign.center,
          style: type.display.copyWith(color: colors.textPrimary),
        ),
        if (tier >= bondTierThresholds.length)
          Text(
            bondTitle(l, role),
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: colors.accentGold),
          ),
        SizedBox(height: spacing.sm),
        _Seals(tier: tier, tint: tint),
        SizedBox(height: spacing.sm),
        Text(
          [
            l.bondCaseCount(bond.cases),
            l.bondVictoryCount(bond.victories),
            l.bondWitnessCount(bond.witnesses),
            if (bond.personal > 0) l.bondPersonalCount(bond.personal),
          ].join(l.listSeparator),
          textAlign: TextAlign.center,
          style: type.caption.copyWith(color: colors.textMuted),
        ),
        SizedBox(height: spacing.lg),
        Text(
          tier == 0 ? l.bondStrangerLine : l.bondLettersTitle,
          style: type.title.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: spacing.sm),
        for (var t = 1; t <= bondTierThresholds.length; t++)
          _Letter(
            text: t <= tier
                ? bondLetter(l, role, t)
                : l.bondSealedLetter(bondTierThresholds[t - 1] - bond.cases),
            open: t <= tier,
            tint: tint,
          ),
        SizedBox(height: spacing.lg),
      ],
    );
  }
}

/// Four wax seals: filled for every letter opened.
class _Seals extends StatelessWidget {
  final int tier;
  final Color tint;
  const _Seals({required this.tier, required this.tint});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < bondTierThresholds.length; i++)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DossierTokens.sealGap / 2),
          child: Container(
            width: DossierTokens.seal,
            height: DossierTokens.seal,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < tier ? tint : Colors.transparent,
              border: Border.all(
                color: i < tier ? tint : context.colors.borderSubtle,
                width: DossierTokens.sealStroke,
              ),
            ),
          ),
        ),
    ],
  );
}

/// One letter: the character's words when open, a sealed line when not.
class _Letter extends StatelessWidget {
  final String text;
  final bool open;
  final Color tint;
  const _Letter({required this.text, required this.open, required this.tint});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Opacity(
      opacity: open ? 1 : DossierTokens.sealedOpacity,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: spacing.sm),
              child: Container(
                width: DossierTokens.letterMark,
                height: DossierTokens.letterMark,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: open ? tint : colors.borderSubtle,
                ),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Text(
                open ? '«$text»' : text,
                style:
                    (open
                            ? context.typography.body
                            : context.typography.bodySmall)
                        .copyWith(
                          color: open ? colors.textPrimary : colors.textMuted,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int index;
  final Color Function(int) colorOf;
  final ValueChanged<int> onTap;
  const _PageDots({
    required this.count,
    required this.index,
    required this.colorOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        GestureDetector(
          onTap: () => onTap(i),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.all(context.spacing.xs),
            child: AnimatedContainer(
              duration: ReduceMotion.of(context)
                  ? Duration.zero
                  : DossierTokens.pageTurn,
              width: i == index ? DossierTokens.dotActive : DossierTokens.dot,
              height: DossierTokens.dot,
              decoration: BoxDecoration(
                color: i == index ? colorOf(i) : context.colors.borderSubtle,
                borderRadius: BorderRadius.circular(DossierTokens.dot),
              ),
            ),
          ),
        ),
    ],
  );
}
