import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../app/l10n/app_localizations.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';

/// Keys for «إزاي نلعب».
abstract final class HowToKeys {
  static const sheet = ValueKey('how_to_sheet');
  static const pages = ValueKey('how_to_pages');
  static const video = ValueKey('how_to_video');
  static ValueKey<String> role(String name) => ValueKey('how_to_role_$name');
  static ValueKey<String> faq(int i) => ValueKey('how_to_faq_$i');
}

/// «إزاي نلعب» as a deck sheet over Home: a booklet turned page by page (the
/// idea, night, day, voting, who wins, the roles as cards that flip), the
/// one-minute video, and the questions people ask.
///
/// Everything on it is public: the same seven roles, in the same order, for
/// every reader (Doc 05).
Future<void> showHowToSheet(
  BuildContext context, {
  required VoidCallback onVideo,
}) => showDeckSheet<void>(
  context: context,
  title: context.l10n.howToPlayTitle,
  ruqaa: true,
  body: (sheetContext) => HowToBody(
    key: HowToKeys.sheet,
    onVideo: () {
      Navigator.of(sheetContext).maybePop();
      onVideo();
    },
  ),
);

class _Page {
  final String title;
  final String body;
  final String? art;
  const _Page(this.title, this.body, this.art);
}

class _RoleCard {
  final String name;
  final String face;
  final String label;
  final String does;
  const _RoleCard(this.name, this.face, this.label, this.does);
}

class HowToBody extends StatefulWidget {
  final VoidCallback onVideo;
  const HowToBody({super.key, required this.onVideo});

  @override
  State<HowToBody> createState() => _HowToBodyState();
}

class _HowToBodyState extends State<HowToBody> {
  final _controller = PageController();
  int _page = 0;
  int? _open;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  List<_Page> _pages(AppLocalizations l) => [
    _Page(l.howIdeaTitle, l.howIdeaBody, AppImages.onboardingPass),
    _Page(l.howNightTitle, l.howNightBody, AppImages.onboardingNight),
    _Page(l.howDayTitle, l.howDayBody, AppImages.onboardingDay),
    _Page(l.howVoteTitle, l.howVoteBody, AppImages.bgVote),
    _Page(l.howWinTitle, l.howWinBody, AppImages.onboardingWin),
    _Page(l.howRolesTitle, l.howRolesHint, null),
  ];

  List<_RoleCard> _roles(AppLocalizations l) => [
    _RoleCard('mafia', AppImages.cardFaceMafia, l.howRoleMafia, l.howRoleMafiaDo),
    _RoleCard(
      'detective',
      AppImages.cardFaceDetective,
      l.howRoleDetective,
      l.howRoleDetectiveDo,
    ),
    _RoleCard('doctor', AppImages.cardFaceDoctor, l.howRoleDoctor, l.howRoleDoctorDo),
    _RoleCard(
      'citizen',
      AppImages.cardFaceCitizen,
      l.howRoleCitizen,
      l.howRoleCitizenDo,
    ),
    _RoleCard('elder', AppImages.cardFaceElder, l.howRoleElder, l.howRoleElderDo),
    _RoleCard(
      'silencer',
      AppImages.cardFaceSilencer,
      l.howRoleSilencer,
      l.howRoleSilencerDo,
    ),
    _RoleCard('sniper', AppImages.cardFaceSniper, l.howRoleSniper, l.howRoleSniperDo),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final compact =
        MediaQuery.sizeOf(context).height < HowToTokens.compactBelow;
    final artH = compact
        ? HowToTokens.pageArtHeightCompact
        : HowToTokens.pageArtHeight;
    final pages = _pages(l);
    final roles = _roles(l);
    final pagesHeight = artH + HowToTokens.pageBodyMin + s.xxl + s.xl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: pagesHeight,
          child: PageView.builder(
            key: HowToKeys.pages,
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final page = pages[i];
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: s.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (page.art != null)
                      _PageArt(
                        asset: page.art!,
                        height: artH,
                        counter: l.howPageOf(i + 1, pages.length),
                      ),
                    SizedBox(height: s.sm),
                    Text(
                      page.title,
                      style: StoryTokens.ruqaa(
                        type.headline,
                      ).copyWith(color: context.colors.textPrimary),
                    ),
                    Text(
                      page.body,
                      style: DeckTokens.meta(
                        type,
                      ).copyWith(color: context.colors.textSecondary),
                    ),
                    if (page.art == null) ...[
                      SizedBox(height: s.sm),
                      _roleGrid(context, roles),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: s.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pages.length; i++)
                AnimatedContainer(
                  duration: _still ? Duration.zero : HowToTokens.page,
                  margin: EdgeInsets.symmetric(horizontal: s.xs / 2),
                  width: i == _page ? HowToTokens.dotWide : HowToTokens.dot,
                  height: HowToTokens.dot,
                  decoration: BoxDecoration(
                    color: i == _page ? DeckTokens.bone : DeckTokens.silver,
                    borderRadius: BorderRadius.circular(HowToTokens.dot / 2),
                  ),
                ),
            ],
          ),
        ),
        RimButton(
          key: HowToKeys.video,
          label: l.howVideo,
          onPressed: widget.onVideo,
        ),
        SizedBox(height: s.md),
        Text(
          l.howFaqTitle,
          style: DeckTokens.meta(
            type,
          ).copyWith(color: context.colors.textMuted),
        ),
        for (var i = 0; i < 3; i++) _faq(context, i),
        SizedBox(height: s.sm),
      ],
    );
  }

  Widget _roleGrid(BuildContext context, List<_RoleCard> roles) {
    return LayoutBuilder(
      builder: (context, box) {
        const cols = HowToTokens.roleColumns;
        final w = (box.maxWidth - HowToTokens.roleGap * (cols - 1)) / cols;
        final h = w / HowToTokens.roleAspect;
        return Wrap(
          spacing: HowToTokens.roleGap,
          runSpacing: HowToTokens.roleGap,
          children: [
            for (final r in roles)
              SizedBox(
                width: w,
                height: h,
                child: _FlipRole(
                  key: HowToKeys.role(r.name),
                  role: r,
                  still: _still,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _faq(BuildContext context, int i) {
    final l = context.l10n;
    final q = [l.howFaq1Q, l.howFaq2Q, l.howFaq3Q][i];
    final a = [l.howFaq1A, l.howFaq2A, l.howFaq3A][i];
    final open = _open == i;
    final type = context.typography;
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        key: HowToKeys.faq(i),
        onTap: () => setState(() => _open = open ? null : i),
        child: Container(
          constraints: const BoxConstraints(minHeight: IdentityTokens.target),
          padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: DeckTokens.line)),
          ),
          child: AnimatedSize(
            duration: _still ? Duration.zero : HowToTokens.faq,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        q,
                        style: DeckTokens.body(
                          type,
                        ).copyWith(color: context.colors.textPrimary),
                      ),
                    ),
                    Icon(
                      open ? Icons.remove : Icons.add,
                      size: DeckTokens.icon,
                      color: DeckTokens.silverLight,
                    ),
                  ],
                ),
                if (open)
                  Text(
                    a,
                    style: DeckTokens.meta(
                      type,
                    ).copyWith(color: context.colors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageArt extends StatelessWidget {
  final String asset;
  final double height;
  final String counter;
  const _PageArt({
    required this.asset,
    required this.height,
    required this.counter,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(HowToTokens.artRadius),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: ResizeImage(
                AssetImage(asset),
                height: (height * dpr * DeckTokens.artDecodeHeadroom).round(),
                policy: ResizeImagePolicy.fit,
              ),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [HowToTokens.artFadeFrom, 1],
                  colors: [
                    IdentityTokens.transparent,
                    DeckTokens.ground.withValues(alpha: HowToTokens.artScrimAlpha),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              end: context.spacing.md,
              bottom: context.spacing.sm,
              child: Text(
                counter,
                style: context.typography.caption.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A role card that turns over to say what the role does.
class _FlipRole extends StatefulWidget {
  final _RoleCard role;
  final bool still;
  const _FlipRole({super.key, required this.role, required this.still});

  @override
  State<_FlipRole> createState() => _FlipRoleState();
}

class _FlipRoleState extends State<_FlipRole> {
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.role;
    final type = context.typography;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return Semantics(
      button: true,
      label: _flipped ? '${r.label}: ${r.does}' : r.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _flipped = !_flipped),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _flipped ? 1 : 0),
          duration: widget.still ? Duration.zero : HowToTokens.flip,
          curve: Curves.easeInOutCubic,
          builder: (context, t, _) {
            final back = t > 0.5;
            return RepaintBoundary(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, HowToTokens.rolePerspective)
                  ..rotateY(t * math.pi),
                child: back
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: DeckTokens.panel,
                            borderRadius: BorderRadius.circular(SeatTokens.radius),
                            border: Border.all(color: SeatTokens.rim),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              HowToTokens.roleBackPad,
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      r.label,
                                      style: type.caption.copyWith(
                                        color: context.colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      r.does,
                                      textAlign: TextAlign.center,
                                      style: type.caption.copyWith(
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(SeatTokens.radius),
                          border: Border.all(color: SeatTokens.rim),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(SeatTokens.radius),
                          child: Image(
                            image: ResizeImage(
                              AssetImage(r.face),
                              width: (HowToTokens.roleDecode * dpr).round(),
                              policy: ResizeImagePolicy.fit,
                            ),
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
