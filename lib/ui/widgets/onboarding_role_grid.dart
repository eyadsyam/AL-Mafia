import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../../engine/models/enums.dart' show Role;
import '../../platform/reduce_motion.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

/// The four role cards, face up, on the roles chapter of the onboarding deck.
///
/// ## Why this is safe to show, in full, before anyone has played
///
/// The same reason [CardSpread] is safe on Home: every leakage rule in this app
/// governs what one player can learn about *another*, and here nothing has been
/// dealt, nobody is holding anything, and the whole table is looking at one
/// screen together. Showing all four openly beforehand is what makes four
/// identical backs during the match mean nothing.
///
/// Like the home spread, it uses the **gallery** copies rather than the
/// in-match faces: those are the same paintings without the ±2% luminance
/// matching, so they keep their original contrast. Side by side in a lit room
/// the gained mafia card reads as washed out next to the others.
/// `handoff_purity_test.dart` is what keeps this file out of any surface
/// reachable while the phone is in a hand — it derives the ban from the import
/// graph, so nothing here has to be remembered.
///
/// ## Two by two, not four across
///
/// Four across inside a card is about sixty logical pixels each on a small
/// phone. The back of a card has to hold a sentence, and a sentence in a
/// sixty-pixel column is a stack of two-word lines. Two by two buys double the
/// measure for the same area.
class OnboardingRoleGrid extends StatelessWidget {
  /// Fired every time one of the four tiles turns over.
  ///
  /// Same arrangement as `CardSpread.onFlip`: a callback, so the widget can be
  /// pumped by a test or a preview without an audio stack behind it.
  final VoidCallback? onFlip;

  const OnboardingRoleGrid({super.key, this.onFlip});

  /// A stable handle on one tile.
  ///
  /// Keyed by role rather than by grid position so a test — or a later change
  /// to the layout — cannot silently start driving a different card.
  static Key tileFor(Role role) => ValueKey('onboarding_role_${role.name}');

  /// Card proportion, matching the shipped art: 1024×1536.
  static const double _aspect = 1024 / 1536;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    const roles = Role.values;

    return Column(
      children: [
        for (var row = 0; row < roles.length; row += 2) ...[
          if (row > 0) SizedBox(height: spacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < 2; column++) ...[
                if (column > 0) SizedBox(width: spacing.md),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: _aspect,
                    child: _RoleTile(
                      key: tileFor(roles[row + column]),
                      role: roles[row + column],
                      onFlip: onFlip,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One role card that turns over when tapped.
///
/// Deliberately *not* shared with `_Face` in `card_spread.dart`, which does the
/// same trick. That widget is welded to the home spread — it takes a depth, a
/// slot and an externally driven flip animation, because the spread owns which
/// single card is open at a time. This one owns its own state so all four can be
/// open at once, which is what you want on a reference card and not what you
/// want on a background. Extracting a shared primitive would mean reworking the
/// spread's animation ownership on a screen whose behaviour is already tested;
/// the duplication is about forty lines and is the cheaper of the two.
class _RoleTile extends StatefulWidget {
  final Role role;
  final VoidCallback? onFlip;

  const _RoleTile({super.key, required this.role, this.onFlip});

  @override
  State<_RoleTile> createState() => _RoleTileState();
}

class _RoleTileState extends State<_RoleTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  bool _open = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read from the context rather than at construction: the duration depends
    // on the OS Reduce Motion setting, which can change while the app is up.
    _flip.duration =
        ReduceMotion.of(context) ? Duration.zero : context.motion.dramatic;
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggle() {
    // Both directions: a card turning back over is still a card turning over.
    widget.onFlip?.call();
    setState(() => _open = !_open);
    if (_open) {
      _flip.forward();
    } else {
      _flip.reverse();
    }
  }

  String get _painting => switch (widget.role) {
        Role.mafia => AppGallery.galleryMafia,
        Role.doctor => AppGallery.galleryDoctor,
        Role.detective => AppGallery.galleryDetective,
        Role.citizen => AppGallery.galleryCitizen,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: EngineCopy.roleName(l10n, widget.role),
      // The description is what the flip reveals, so a screen reader gets it
      // without having to perform the animation.
      value: EngineCopy.roleDescription(l10n, widget.role),
      // One node, whichever way the card is facing. Without this the flipped
      // back contributes its own name and description as child nodes, and the
      // tile announces both twice — and the merged label stops matching the
      // name it is supposed to be known by.
      container: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final turn = _flip.value;
            final showingBack = turn >= 0.5;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, context.motion.perspective)
                ..rotateY(turn * math.pi),
              child: showingBack
                  // Counter-rotated, or the back would read mirrored.
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _back(context),
                    )
                  : _front(context),
            );
          },
        ),
      ),
    );
  }

  Widget _front(BuildContext context) {
    final colors = context.colors;
    final shape = BorderRadius.circular(context.radii.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.elevation.level2,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Image.asset(
          _painting,
          // Contain, never cover. These are finished paintings and the frame is
          // part of the picture.
          fit: BoxFit.contain,
          // The sources are 1024×1536 and there are four here. At source size
          // that is roughly 24 MB of decoded bitmap for tiles a couple of
          // centimetres wide.
          cacheWidth: 256,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }

  Widget _back(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;
    final shape = BorderRadius.circular(context.radii.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceOverlay,
        borderRadius: shape,
        border: Border.all(color: colors.accentGold.withValues(alpha: 0.55)),
        boxShadow: context.elevation.level2,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppImages.canvasTexture,
              repeat: ImageRepeat.repeat,
              fit: BoxFit.none,
              alignment: Alignment.topLeft,
              // Opacity on the image, not an `Opacity` widget: no offscreen
              // layer, which matters with four of these compositing at once.
              opacity: const AlwaysStoppedAnimation<double>(0.20),
              excludeFromSemantics: true,
            ),
            Padding(
              padding: EdgeInsets.all(spacing.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    EngineCopy.roleName(l10n, widget.role),
                    style: type.title.emphasised.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: spacing.xs),
                  Flexible(
                    child: Text(
                      EngineCopy.roleDescription(l10n, widget.role),
                      style: type.caption.copyWith(color: colors.textSecondary),
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
