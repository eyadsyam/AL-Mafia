import 'package:flutter/material.dart';

import '../../../../engine/models/enums.dart' hide Alignment;
import '../../../../transport/game_snapshot.dart' show FinalStanding;
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import 'card_rise.dart';

/// One player's card, at the only size doc 15 lets a card be drawn.
///
/// Doc 15 §5: *"card art never renders below 200dp."* This draws at
/// [CouncilTokens.cardRiseSize] — 280 — and the roster around it exists so
/// that it never has to be smaller.
class RosterCard extends StatelessWidget {
  final String name;
  final Role role;

  /// «٣ من ٨». A position in a list of cards, which is a real fact about this
  /// screen — unlike a position in band 3's raised hands, where a number would
  /// have implied an order the server does not keep (§1.4).
  final String position;

  const RosterCard({
    super.key,
    required this.name,
    required this.role,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radii.card),
          child: Image.asset(
            faceFor(role),
            width: CouncilTokens.cardRiseSize,
            height: CouncilTokens.cardRiseSize,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        SizedBox(height: spacing.md),
        Text(
          name,
          textAlign: TextAlign.center,
          style: type.title.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: spacing.xs),
        Text(
          EngineCopy.roleName(context.l10n, role),
          textAlign: TextAlign.center,
          style: type.body.copyWith(color: colors.accentGold),
        ),
        SizedBox(height: spacing.lg),
        // Under the card rather than pinned to the bottom of the screen. A
        // counter at the foot of a mostly empty column is how this screen came
        // in at 26% empty against §5's 25% budget; travelling with the content
        // it describes, it is a quarter of that.
        Text(
          position,
          style: type.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Doc 15 §S-O13 beat 5: «شوف الأدوار» — the roster, one card at a time.
///
/// ## Why this screen exists
///
/// Beat 2 used to ask for every card to rise and flip at once. It could not be
/// built against §5's floor — card art never renders below 200dp, and fifteen
/// cards at 200dp need seven times the width a phone has. The resolution
/// (2026-09-07) split the beat in two: the **drama** stayed with the council,
/// where fifteen rings turn over on the same frame, and the **art** came here,
/// where there is room to show it properly.
///
/// ## Why it is an overlay and not a route
///
/// Doc 12 §2.1: *"the table changes state; nothing is pushed on top of it."*
/// The match is one place from the lobby to the result, and a roster pushed as
/// a route would be the slideshow the four bands exist to end — the council
/// would leave the screen, and coming back would be an arrival rather than a
/// return. So it draws over the council, which stays where it is underneath,
/// still carrying the marks that sent the player here.
///
/// ## Why it is a page and not a grid
///
/// A grid would be the same mistake in a different shape: nine cards on a
/// phone is nine cards at ninety pixels. One at a time is the only layout that
/// keeps the promise, and it is also the honest one about how this screen is
/// used — nobody scans a post-mortem, they look for one person and then the
/// next.
///
/// ## Why there is no leakage argument to make
///
/// It opens after `GamePhase.result`. Every role in it is in the standings the
/// server published to end the match, and there is no remaining phase for an
/// inference to matter in.
class RoleRoster extends StatefulWidget {
  final List<FinalStanding> standings;

  /// Called when the player is done looking.
  final VoidCallback onClose;

  const RoleRoster({
    super.key,
    required this.standings,
    required this.onClose,
  });

  static const Key page = ValueKey('council_role_roster');
  static const Key pager = ValueKey('council_role_roster_pager');
  static const Key close = ValueKey('council_role_roster_close');

  @override
  State<RoleRoster> createState() => _RoleRosterState();
}

class _RoleRosterState extends State<RoleRoster> {
  late final PageController _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final l10n = context.l10n;
    final roster = widget.standings;

    return ColoredBox(
      key: RoleRoster.page,
      // Not opaque. The council is still there behind it, which is the
      // difference between an overlay and a route.
      color: colors.surfaceBase.withValues(alpha: 0.94),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: RoleRoster.close,
                onPressed: widget.onClose,
                child: Text(l10n.back),
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: RoleRoster.pager,
                controller: _pages,
                itemCount: roster.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.md),
                  child: RosterCard(
                    name: roster[index].name,
                    role: roster[index].role,
                    position: l10n.onlineRosterOf(index + 1, roster.length),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
