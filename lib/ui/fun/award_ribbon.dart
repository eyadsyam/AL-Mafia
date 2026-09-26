import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_localizations.dart';
import '../../platform/audio_director.dart';
import '../../platform/haptics.dart';
import '../economy/economy_capabilities.dart';
import '../economy/wallet.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart'
    show onlineBackendFactoryProvider;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'fun_art.dart';
import 'loaded_capabilities.dart';
import 'match_awards.dart';

String awardName(AppLocalizations l, AwardKind kind) => switch (kind) {
  AwardKind.mvp => l.awardMvp,
  AwardKind.sharpEye => l.awardSharpEye,
  AwardKind.silverTongue => l.awardSilverTongue,
  AwardKind.firstBlood => l.awardFirstBlood,
  AwardKind.lifesaver => l.awardLifesaver,
  AwardKind.perfectCrime => l.awardPerfectCrime,
  AwardKind.survivor => l.awardSurvivor,
};

String awardBody(AppLocalizations l, AwardKind kind) => switch (kind) {
  AwardKind.mvp => l.awardMvpBody,
  AwardKind.sharpEye => l.awardSharpEyeBody,
  AwardKind.silverTongue => l.awardSilverTongueBody,
  AwardKind.firstBlood => l.awardFirstBloodBody,
  AwardKind.lifesaver => l.awardLifesaverBody,
  AwardKind.perfectCrime => l.awardPerfectCrimeBody,
  AwardKind.survivor => l.awardSurvivorBody,
};

/// The awards of one finished online room, from the server. Asked only from
/// the result screen; a live room answers not-ready and is asked again a few
/// times (the result can reach this phone a beat before the server's phase).
final onlineAwardsProvider = FutureProvider.autoDispose
    .family<OnlineAwards, String>((ref, roomId) async {
      final caps = await ref.watch(economyCapabilitiesProvider.future);
      if (!caps.fun.awards) return OnlineAwards.off;
      final backend = await ref.read(onlineBackendFactoryProvider)();
      await backend.ensureSession();
      for (var attempt = 0; ; attempt++) {
        final answer = OnlineAwards.fromJson(
          await backend.call('economy', {
            'action': 'awards_get',
            'roomId': roomId,
          }),
        );
        if (answer.ready || !answer.enabled || attempt >= 2) {
          if (answer.granted > 0) {
            try {
              unawaited(ref.read(walletProvider.notifier).refresh());
            } catch (_) {}
          }
          return answer;
        }
        await Future<void>.delayed(ref.read(awardsRetryDelayProvider));
      }
    });

/// How long to wait before asking a not-ready room again. Zero in tests.
final awardsRetryDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

/// The online result's awards: skeleton cards while the server answers, then
/// the ribbon. Renders nothing when awards are off or the read fails.
class OnlineAwardsStrip extends ConsumerStatefulWidget {
  final String roomId;
  const OnlineAwardsStrip({super.key, required this.roomId});

  static const Key stripKey = ValueKey('online_awards_strip');

  @override
  ConsumerState<OnlineAwardsStrip> createState() => _OnlineAwardsStripState();
}

class _OnlineAwardsStripState extends ConsumerState<OnlineAwardsStrip> {
  @override
  Widget build(BuildContext context) {
    final roomId = widget.roomId;
    // Uses a capabilities answer the result already has; never starts one.
    final caps = loadedCapabilities(ref);
    if (caps == null) recheckCapabilitiesAfterFrame(this);
    if (!(caps?.fun.awards ?? false)) return const SizedBox.shrink();
    final answer = ref.watch(onlineAwardsProvider(roomId));
    return answer.when(
      loading: () => const Padding(
        key: OnlineAwardsStrip.stripKey,
        padding: EdgeInsets.zero,
        child: AwardRibbon(awards: [], loading: true),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (value) => !value.ready || value.awards.isEmpty
          ? const SizedBox.shrink()
          : AwardRibbon(
              key: OnlineAwardsStrip.stripKey,
              awards: value.awards,
              mine: value.mine,
              granted: value.granted,
            ),
    );
  }
}

/// A horizontal ribbon of medal cards, revealed one after another with a
/// haptic tick and one chime, over a few faint gold motes that settle and
/// stop. Reduced motion shows the cards at rest, with no motes.
class AwardRibbon extends ConsumerStatefulWidget {
  final List<MatchAward> awards;
  final bool loading;
  final Set<AwardKind> mine;
  final int granted;

  const AwardRibbon({
    super.key,
    required this.awards,
    this.loading = false,
    this.mine = const {},
    this.granted = 0,
  });

  static const Key skeletonKey = ValueKey('award_skeleton');
  static Key card(AwardKind kind) => ValueKey('award_card_${kind.code}');

  @override
  ConsumerState<AwardRibbon> createState() => _AwardRibbonState();
}

class _AwardRibbonState extends ConsumerState<AwardRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(vsync: this);
  bool _announced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(AwardRibbon old) {
    super.didUpdateWidget(old);
    _start();
  }

  void _start() {
    if (_announced || widget.loading || widget.awards.isEmpty) return;
    _announced = true;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _reveal.value = 1;
    } else {
      _reveal
        ..duration =
            FunTokens.awardReveal +
            FunTokens.awardStagger * widget.awards.length +
            FunTokens.particleCycle
        ..forward(from: 0);
    }
    // One tick and one chime for the whole ribbon, not one per card. The
    // result is on the table and every card is already public; the director
    // still refuses (and we ignore) anything while a phone is in hand.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.confirm();
      try {
        ref.read(audioDirectorProvider).play(AudioCue.joinChime);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final loading = widget.loading;
    final count = loading ? FunTokens.skeletonCards : widget.awards.length;
    final total = _reveal.duration?.inMilliseconds ?? 1;

    return Padding(
      padding: EdgeInsets.only(bottom: s.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loading ? l.awardsLoading : l.awardsTitle,
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: colors.accentGold),
          ),
          SizedBox(height: s.xs),
          SizedBox(
            height: FunTokens.awardCardHeight,
            child: Semantics(
              liveRegion: !loading,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: count,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: FunTokens.awardGap),
                itemBuilder: (context, i) {
                  if (loading) return const _SkeletonCard();
                  final award = widget.awards[i];
                  final begin =
                      (FunTokens.awardStagger * i).inMilliseconds / total;
                  final end =
                      ((FunTokens.awardStagger * i) + FunTokens.awardReveal)
                          .inMilliseconds /
                      total;
                  final curve = CurvedAnimation(
                    parent: _reveal,
                    curve: Interval(
                      begin.clamp(0.0, 1.0),
                      end.clamp(0.0, 1.0),
                      curve: Curves.easeOutCubic,
                    ),
                  );
                  return AnimatedBuilder(
                    animation: curve,
                    builder: (context, child) => Opacity(
                      opacity: curve.value,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          FunTokens.awardLift * (1 - curve.value),
                        ),
                        child: child,
                      ),
                    ),
                    child: _AwardCard(
                      award: award,
                      mine: widget.mine.contains(award.kind),
                      motes: _reveal,
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.granted > 0)
            Padding(
              padding: EdgeInsets.only(top: s.xs),
              child: Text(
                l.awardsYouEarned(widget.granted),
                textAlign: TextAlign.center,
                style: type.caption.copyWith(color: colors.accentGold),
              ),
            ),
        ],
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  final MatchAward award;
  final bool mine;
  final Animation<double> motes;
  const _AwardCard({
    required this.award,
    required this.mine,
    required this.motes,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final names = award.names.where((n) => n.isNotEmpty).toList();
    final who = names.isEmpty
        ? ''
        : names.length == 1
        ? names.first
        : '${names.first} +${names.length - 1}';
    return Semantics(
      label: '${awardName(l, award.kind)}. ${awardBody(l, award.kind)}. $who',
      excludeSemantics: true,
      child: Container(
        key: AwardRibbon.card(award.kind),
        width: FunTokens.awardCardWidth,
        padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.xs),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(context.radii.card),
          border: Border.all(
            color: mine ? colors.accentGold : colors.borderSubtle,
            width: mine ? FunTokens.awardStroke : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: FunTokens.awardMedal,
              child: CustomPaint(
                painter: _MotesPainter(motes, colors.accentGold),
                child: AwardMedal(kind: award.kind),
              ),
            ),
            SizedBox(height: s.xs),
            Text(
              awardName(l, award.kind),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: type.caption.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              who,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: type.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A handful of faint gold motes that drift up behind a medal as it lands
/// and are gone when the reveal ends — no confetti, no loop.
class _MotesPainter extends CustomPainter {
  final Animation<double> t;
  final Color gold;
  _MotesPainter(this.t, this.gold) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    if (v <= 0 || v >= 1) return;
    final fade = math.sin(v * math.pi) * FunTokens.particleOpacity;
    final paint = Paint()..color = gold.withValues(alpha: fade);
    for (var i = 0; i < FunTokens.particleCount; i++) {
      final angle = i / FunTokens.particleCount * 2 * math.pi;
      final r = size.width * (0.35 + 0.2 * ((i * 37) % 10) / 10);
      final rise = size.height * 0.4 * v;
      final p =
          size.center(Offset.zero) +
          Offset(math.cos(angle) * r, math.sin(angle) * r * 0.6 - rise);
      canvas.drawCircle(p, FunTokens.particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) => old.gold != gold;
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = context.spacing;
    final block = colors.textMuted.withValues(alpha: FunTokens.skeletonOpacity);
    return Container(
      key: AwardRibbon.skeletonKey,
      width: FunTokens.awardCardWidth,
      padding: EdgeInsets.all(s.sm),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(context.radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: FunTokens.awardMedal * 0.8,
            height: FunTokens.awardMedal * 0.8,
            decoration: BoxDecoration(color: block, shape: BoxShape.circle),
          ),
          SizedBox(height: s.sm),
          Container(
            width: FunTokens.awardCardWidth * 0.6,
            height: s.sm,
            color: block,
          ),
          SizedBox(height: s.xs),
          Container(
            width: FunTokens.awardCardWidth * 0.4,
            height: s.sm,
            color: block,
          ),
        ],
      ),
    );
  }
}
