import 'dart:async';
import 'dart:math' as math;

import '../../widgets/mafia_kit.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/public_web_origin.dart';
import '../../../data/character_bonds.dart';
import '../../../platform/clipboard.dart';
import '../../economy/web_ads.dart';
import '../../../engine/models/enums.dart' as engine;
import '../../../engine/coaching.dart';
import '../../../transport/local_transport.dart';
import '../../../transport/online_transport.dart';
import '../../l10n_ext.dart';
import '../../../app/asset_constants.dart';
import '../../economy/cosmetic_paint.dart';
import '../../economy/economy_capabilities.dart';
import '../../economy/mafia_coin.dart';
import '../../economy/pass_table_dress.dart';
import '../../economy/wallet.dart';
import '../online/online_session.dart' show SupabaseConfig;
import '../../missions/casebook_data.dart';
import '../../missions/casebook_sheet.dart' show caseLine;
import '../../theme/mafia_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/deck/deck_paper.dart';
import '../../widgets/deck/deck_buttons.dart';
import '../../widgets/deck/deck_public.dart' show CoinPill;
import '../../widgets/motion_sprite.dart';
import '../../widgets/textured_surface.dart';
import '../../fun/award_ribbon.dart';
import '../../fun/match_awards.dart';
import '../../fun/character_dossiers.dart' show BondLetterArrivedCard;
import '../match_controller.dart';
import 'match_file.dart';

/// A single row in the result table showing a player's role and status.
class ResultRow {
  final int seat;
  final String name;
  final engine.Role role;

  /// When the player was eliminated (e.g. "Night 1", "Day 2", "نجا").
  /// Null means they survived.
  final String? eliminatedLabel;

  const ResultRow({
    required this.seat,
    required this.name,
    required this.role,
    this.eliminatedLabel,
  });
}

/// One line of what the match paid: the existing reward data, never invented.
class ResultCoinRow {
  final String label;
  final int coins;
  const ResultCoinRow({required this.label, required this.coins});
}

/// Result Screen (S-14) — post-game winner reveal and role exposure.
///
/// Displayed after the match ends. The deck's last page: the outcome art and
/// verdict, a stamp, who you were, a line from that character, every seat's
/// card turned in turn, what the match paid, and the buttons pinned below.
/// This is the ONLY screen that reveals roles during the match (since it's
/// after the match).
///
/// Reference: spec FR-022, T036
class ResultScreen extends StatelessWidget {
  /// The winning alignment (Mafia or Town).
  final engine.Alignment winner;

  /// All players with their roles and elimination status.
  final List<ResultRow> rows;

  /// Callback when "التحليلات" is tapped.
  /// Opens the post-game autopsy, or null when there is nothing to open.
  ///
  /// Null hides the button rather than disabling it: a greyed-out control on
  /// the last screen of a match reads as something broken, and there is nothing
  /// broken about an online match having no local record to inspect.
  final VoidCallback? onAnalytics;

  /// Callback when "الرئيسية" is tapped.
  final VoidCallback onHome;

  /// «ماتش تاني»: a fresh match at the same bot table. Null elsewhere.
  final VoidCallback? onPlayAgain;

  static const playAgainKey = ValueKey('result_play_again');
  static const openFileKey = ValueKey('result_open_file');
  static const youKey = ValueKey('result_you');
  static const coinTotalKey = ValueKey('result_coin_total');
  static const stampKey = ValueKey('result_stamp');
  static const casebookKey = ValueKey('result_casebook');

  /// Key on a seat's card, by seat.
  static Key seatKey(int seat) => ValueKey('result_seat_$seat');

  /// Doc 13 §4.4's «كان ممكن», by seat.
  ///
  /// # Why this tier is safe when the other two are not
  ///
  /// It is conditioned on a player's own role, their own suspicions and their
  /// own votes, which would be a leak anywhere else in the app. Here the match
  /// is over, every role is already printed on this very screen, and nothing
  /// said here can change a decision — there are none left. Doc 13 §4.1's
  /// table says so in as many words.
  ///
  /// # And why a seat can be missing
  ///
  /// Doc 13 §9: *"post-match coaching generates from real data only; no
  /// generic filler."* A player who did nothing remarkable gets nothing, not a
  /// platitude. An absent seat here is a correct result and not a gap to fill.
  final Map<int, List<CoachingNote>> coaching;

  /// Phase 109: the finished match's awards (`localMatchAwards`). Empty hides
  /// the ribbon. Safe here for the same reason the roles are: it is over.
  final List<MatchAward> awards;

  /// P6: below the fully revealed roles, the existing offers still waiting
  /// today (pass-and-play only). Null draws nothing.
  final Widget? inventory;

  /// Row 12: the launch-event stamps this online room earned. Null draws
  /// nothing (pass-and-play never has any).
  final Widget? eventStamps;
  final bool tabletop;

  /// The seat this phone plays (online, or the human at a bot table). Null at
  /// a shared phone, where nobody is "you": the «كنت …» card is left out.
  final int? viewerSeat;

  /// What the match paid, row by row, from the existing reward data. Empty
  /// draws no earnings card and no flight to the pill.
  final List<ResultCoinRow> coinRows;

  /// «ملف الماتش»: the night-by-night record. Null hides the entry (a match
  /// without a local log has none).
  final MatchFile? matchFile;

  const ResultScreen({
    super.key,
    required this.winner,
    required this.rows,
    this.onAnalytics,
    required this.onHome,
    this.onPlayAgain,
    this.coaching = const {},
    this.awards = const [],
    this.inventory,
    this.eventStamps,
    this.tabletop = false,
    this.viewerSeat,
    this.coinRows = const [],
    this.matchFile,
  });

  /// Key on the «كان ممكن» block for a given seat.
  static Key coachingKey(int seat) => ValueKey('coaching_$seat');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _BondResultRecorder(
      winner: winner,
      rows: rows,
      child: MafiaScaffold(
        backgroundColor: colors.surfaceBase,
        bottomNavigationBar: kIsWeb ? const WebAdBanner() : null,
        body: AppBackdrop(child: _ResultStage(screen: this)),
      ),
    );
  }
}

Color _roleColor(BuildContext context, engine.Role role) {
  final colors = context.colors;
  switch (role) {
    case engine.Role.mafia:
    case engine.Role.silencer:
      return colors.roleMafia;
    case engine.Role.doctor:
      return colors.roleDoctor;
    case engine.Role.detective:
      return colors.roleDetective;
    case engine.Role.elder:
    case engine.Role.sniper:
    case engine.Role.citizen:
      return colors.roleCitizen;
  }
}

String _roleLabel(BuildContext context, engine.Role role) =>
    EngineCopy.roleName(context.l10n, role);

class _ResultStage extends StatefulWidget {
  final ResultScreen screen;
  const _ResultStage({required this.screen});

  @override
  State<_ResultStage> createState() => _ResultStageState();
}

class _ResultStageState extends State<_ResultStage>
    with TickerProviderStateMixin {
  late final AnimationController _t;
  late final AnimationController _pay;
  late final AnimationController _fly;
  late final int _totalMs;
  bool _payStarted = false;
  final _stackKey = GlobalKey();
  final _totalKey = GlobalKey();
  final _pillKey = GlobalKey();
  bool _started = false;
  bool _landed = false;
  Offset? _from;
  Offset? _to;

  ResultScreen get s => widget.screen;
  int get _coins => s.coinRows.fold(0, (a, r) => a + r.coins);

  bool _walletAsked = false;

  @override
  void initState() {
    super.initState();
    final flipsEnd = s.rows.isEmpty
        ? 0
        : ResultTokens.flipAt +
              (s.rows.length - 1) * ResultTokens.flipStagger +
              ResultTokens.flipFor;
    _totalMs =
        math.max(flipsEnd, ResultTokens.lineAt + ResultTokens.lineFor) +
        ResultTokens.tail;
    _t = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    )..addStatusListener((_) => _maybePay());
    _pay = AnimationController(vsync: this, duration: _payDuration())
      ..addStatusListener(_onPaid);
    _fly = AnimationController(vsync: this, duration: ResultTokens.flight)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _landed = true);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _t.value = 1;
      _pay.value = 1;
      _fly.value = 1;
      _payStarted = true;
      _landed = true;
    } else {
      _t.forward();
    }
  }

  Duration _payDuration() => Duration(
    milliseconds:
        s.coinRows.length * ResultTokens.rowStagger + ResultTokens.countFor,
  );

  @override
  void didUpdateWidget(_ResultStage old) {
    super.didUpdateWidget(old);
    if (old.screen.coinRows.length != s.coinRows.length) {
      _pay.duration = _payDuration();
      if (_payStarted && _pay.value >= 1 && _coins > 0) {
        // Rows that arrived after a reduced-motion jump: show them as they are.
        _landed = true;
      } else {
        _maybePay();
      }
    }
  }

  /// The coin rows start once the cards have turned, and only when there is
  /// something that was paid.
  void _maybePay() {
    if (_payStarted || _coins <= 0 || !_t.isCompleted) return;
    _payStarted = true;
    _pay.forward();
  }

  void _onPaid(AnimationStatus status) {
    if (status != AnimationStatus.completed || _coins <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stack = _stackKey.currentContext?.findRenderObject();
      Offset? centre(GlobalKey key) {
        final box = key.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || stack is! RenderBox) {
          return null;
        }
        return stack.globalToLocal(
          box.localToGlobal(box.size.center(Offset.zero)),
        );
      }

      final from = centre(_totalKey);
      final to = centre(_pillKey);
      if (from == null || to == null) {
        setState(() => _landed = true);
        return;
      }
      setState(() {
        _from = from;
        _to = to;
      });
      _fly.forward();
    });
  }

  @override
  void dispose() {
    _t.dispose();
    _pay.dispose();
    _fly.dispose();
    super.dispose();
  }

  Animation<double> _beat(int at, int forMs, [Curve curve = Curves.easeOut]) =>
      CurvedAnimation(
        parent: _t,
        curve: Interval(
          (at / _totalMs).clamp(0.0, 1.0),
          ((at + forMs) / _totalMs).clamp(0.0, 1.0),
          curve: curve,
        ),
      );

  Future<void> _shareFile() async {
    final l10n = context.l10n;
    final winner = s.winner == engine.Alignment.mafia
        ? l10n.mafiaWins
        : l10n.townWins;
    final message = l10n
        .shareResultText(winner, s.matchFile?.days ?? 0)
        .replaceAll('https://saidalmafia.com', kPublicWebOrigin);
    try {
      await SharePlus.instance.share(
        ShareParams(title: l10n.matchFileShare, text: message),
      );
    } catch (_) {
      final copied = await AppClipboard.copy(message);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                copied ? l10n.shareTextCopied : l10n.shareUnavailable,
              ),
            ),
          );
      }
    }
  }

  String _lineFor(BuildContext context, engine.Role role, bool won) {
    final l = context.l10n;
    return switch (role) {
      engine.Role.mafia || engine.Role.silencer =>
        won ? l.resultLineMafiaWin : l.resultLineMafiaLose,
      engine.Role.doctor =>
        won ? l.resultLineDoctorWin : l.resultLineDoctorLose,
      engine.Role.detective =>
        won ? l.resultLineDetectiveWin : l.resultLineDetectiveLose,
      engine.Role.elder || engine.Role.sniper || engine.Role.citizen =>
        won ? l.resultLineCitizenWin : l.resultLineCitizenLose,
    };
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final screen = s;
    final me = screen.viewerSeat == null
        ? null
        : screen.rows.where((r) => r.seat == screen.viewerSeat).firstOrNull;
    final foot = Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.screenMargin,
        spacing.sm,
        spacing.screenMargin,
        spacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (screen.onPlayAgain != null) ...[
            BoneButton(
              key: ResultScreen.playAgainKey,
              label: context.l10n.botPlayAgain,
              onPressed: screen.onPlayAgain,
            ),
            SizedBox(height: spacing.sm),
          ] else ...[
            BoneButton(
              label: context.l10n.homeAction,
              onPressed: screen.onHome,
            ),
            SizedBox(height: spacing.sm),
          ],
          Row(
            children: [
              if (screen.onAnalytics != null) ...[
                Expanded(
                  child: RimButton(
                    label: context.l10n.analytics,
                    onPressed: screen.onAnalytics,
                  ),
                ),
                SizedBox(width: spacing.sm),
              ],
              if (screen.onPlayAgain != null)
                Expanded(
                  child: RimButton(
                    label: context.l10n.homeAction,
                    onPressed: screen.onHome,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    final content = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _hero(context)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: spacing.screenMargin),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (me != null) ...[
                  SizedBox(height: spacing.sm),
                  _youCard(context, me),
                ],
                SizedBox(height: spacing.md),
                _BondResultMoment(winner: screen.winner, rows: screen.rows),
                SizedBox(height: spacing.md),
                _tableLabel(context),
                SizedBox(height: spacing.sm),
                _seatGrid(context, me?.seat),
                SizedBox(height: spacing.md),
                if (screen.awards.isNotEmpty) ...[
                  AwardRibbon(awards: screen.awards),
                  SizedBox(height: spacing.md),
                ],
                ..._coachingBlocks(context),
                if (screen.coinRows.isNotEmpty) ...[
                  _earnings(context),
                  SizedBox(height: spacing.sm),
                ],
                const _CasebookLine(key: ResultScreen.casebookKey),
                if (screen.matchFile != null) ...[
                  SizedBox(height: spacing.sm),
                  _fileEntry(context),
                ],
                if (screen.inventory != null) ...[
                  SizedBox(height: spacing.md),
                  screen.inventory!,
                ],
                if (screen.eventStamps != null) ...[
                  SizedBox(height: spacing.md),
                  screen.eventStamps!,
                ],
                SizedBox(height: spacing.lg),
              ],
            ),
          ),
        ),
      ],
    );

    return Stack(
      key: _stackKey,
      children: [
        Positioned.fill(
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: content),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.surfaceBase.withValues(alpha: 0),
                            colors.surfaceBase,
                          ],
                          stops: const [0, 0.3],
                        ),
                      ),
                      child: foot,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_coins > 0) _pill(context),
        if (_from != null && _to != null && !_landed) _flight(),
      ],
    );
  }

  // --- the verdict ---

  Widget _hero(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final screen = s;
    final town = screen.winner == engine.Alignment.town;
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final decodeWidth = (size.width * dpr).round();
    final art = AssetImage(
      town ? AppImages.outcomeTownWin : AppImages.outcomeMafiaWin,
    );
    final height = math.max(
      ResultTokens.heroMin,
      size.height * ResultTokens.heroFraction,
    );
    final verdict = _beat(
      ResultTokens.verdictAt,
      ResultTokens.verdictFor,
      Curves.easeOutCubic,
    );
    final zoom = CurvedAnimation(
      parent: _t,
      curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
    );
    final stamp = _beat(ResultTokens.stampAt, ResultTokens.stampFor);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: zoom,
              builder: (context, child) => Transform.scale(
                scale:
                    ResultTokens.heroZoom -
                    (ResultTokens.heroZoom - 1) * zoom.value,
                child: child,
              ),
              child: Image(
                image: decodeWidth > 0
                    ? ResizeImage(
                        art,
                        width: decodeWidth,
                        policy: ResizeImagePolicy.fit,
                      )
                    : art,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surfaceBase.withValues(alpha: 0.4),
                  colors.surfaceBase.withValues(alpha: 0),
                  colors.surfaceBase,
                ],
                stops: const [0, 0.3, 0.96],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: MotionSprite(
              AppMotion.emberDrift,
              width: ResultTokens.heroEmberWidth,
              height: ResultTokens.heroEmberHeight,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: spacing.xs),
              child: FadeTransition(
                opacity: verdict,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(verdict),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.gameOver,
                        style: type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        town ? context.l10n.townWins : context.l10n.mafiaWins,
                        key: const ValueKey('result_winner_headline'),
                        style: type.headline.copyWith(
                          color: colors.textPrimary,
                          fontSize: screen.tabletop
                              ? TabletopTokens.winnerFontSize
                              : ResultTokens.verdictSize,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + ResultTokens.stampTop,
            end: spacing.md,
            child: DeckSealDrop(
              key: ResultScreen.stampKey,
              progress: stamp,
              child: DeckSeal(
                town
                    ? context.l10n.resultStampTown
                    : context.l10n.resultStampMafia,
                color: town ? DeckTokens.verdictTown : DeckTokens.verdictMafia,
                style: type.title,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- you ---

  Widget _youCard(BuildContext context, ResultRow me) {
    final spacing = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final l = context.l10n;
    final won = me.role.alignment == s.winner;
    final you = _beat(ResultTokens.youAt, ResultTokens.youFor);
    final line = _beat(ResultTokens.lineAt, ResultTokens.lineFor);
    Widget rise(Animation<double> a, Widget child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, ResultTokens.riseFrom / 100),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rise(
          you,
          DeckPanel(
            key: ResultScreen.youKey,
            padding: EdgeInsets.all(spacing.md),
            child: Row(
              children: [
                RoleGalleryPortrait(
                  role: me.role,
                  height: ResultTokens.youWindow.height,
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.resultWasRole(_roleLabel(context, me.role)),
                        style: type.title.copyWith(color: DeckTokens.text),
                      ),
                      Text(
                        me.eliminatedLabel ?? l.resultSurvived,
                        style: type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.sm),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: won ? DeckTokens.bone : null,
                    borderRadius: BorderRadius.circular(context.radii.button),
                    border: won ? null : Border.all(color: DeckTokens.silver),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.sm,
                      vertical: spacing.xs / 2,
                    ),
                    child: Text(
                      won ? l.resultYouWon : l.resultYouLost,
                      style: type.caption.emphasised.copyWith(
                        color: won ? DeckTokens.ink : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.sm),
        rise(
          line,
          DeckPanel(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm,
            ),
            child: Text(
              _lineFor(context, me.role, won),
              key: const ValueKey('result_character_line'),
              style: type.body.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  // --- everyone's card, turned in turn ---

  Widget _tableLabel(BuildContext context) {
    final type = context.typography;
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            context.l10n.resultTable,
            style: type.caption.copyWith(color: colors.textMuted),
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.close_rounded,
                size: ResultTokens.crossSize,
                color: DeckTokens.verdictMafia,
              ),
              Flexible(
                child: Text(
                  context.l10n.resultDeadLegend,
                  style: type.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seatGrid(BuildContext context, int? meSeat) {
    final spacing = context.spacing;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = ResultTokens.seatGap;
        const cols = ResultTokens.seatColumns;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: spacing.md,
          children: [
            for (final (i, row) in s.rows.indexed)
              SizedBox(
                width: w,
                child: _SeatTile(
                  key: ResultScreen.seatKey(row.seat),
                  row: row,
                  me: row.seat == meSeat,
                  flip: _beat(
                    ResultTokens.flipAt + i * ResultTokens.flipStagger,
                    ResultTokens.flipFor,
                    Curves.easeOutCubic,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _coachingBlocks(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final nameOf = {for (final r in s.rows) r.seat: r.name};
    final blocks = <Widget>[];
    for (final row in s.rows) {
      final notes = s.coaching[row.seat] ?? const <CoachingNote>[];
      if (notes.isEmpty) continue;
      blocks
        ..add(
          DeckPanel(
            key: ResultScreen.coachingKey(row.seat),
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: type.bodySmall.emphasised.copyWith(
                    color: DeckTokens.text,
                  ),
                ),
                Text(
                  context.l10n.coachingTitle,
                  style: type.caption.copyWith(color: colors.accentGold),
                ),
                for (final note in notes) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    EngineCopy.coaching(
                      context.l10n,
                      note,
                      (seat) => nameOf[seat] ?? '',
                    ),
                    style: type.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        )
        ..add(SizedBox(height: spacing.sm));
    }
    if (blocks.isNotEmpty) blocks.add(SizedBox(height: spacing.sm));
    return blocks;
  }

  // --- what the match paid ---

  Widget _earnings(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final payMs = _pay.duration!.inMilliseconds;
    Animation<double> payBeat(
      int at,
      int forMs, [
      Curve curve = Curves.easeOut,
    ]) => CurvedAnimation(
      parent: _pay,
      curve: Interval(
        (at / payMs).clamp(0.0, 1.0),
        ((at + forMs) / payMs).clamp(0.0, 1.0),
        curve: curve,
      ),
    );
    final count = payBeat(
      s.coinRows.length * ResultTokens.rowStagger,
      ResultTokens.countFor,
    );
    return DeckPanel(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in s.coinRows.indexed)
            _CoinRowView(
              row: row,
              reveal: payBeat(
                i * ResultTokens.rowStagger,
                ResultTokens.rowFor,
                Curves.easeOutCubic,
              ),
            ),
          Divider(
            color: colors.textMuted.withValues(alpha: 0.3),
            height: spacing.md,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.resultCoins,
                style: type.body.emphasised.copyWith(color: DeckTokens.text),
              ),
              Row(
                key: _totalKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MafiaCoin(size: DeckTokens.coinGlyph),
                  SizedBox(width: spacing.xs),
                  AnimatedBuilder(
                    animation: count,
                    builder: (context, _) => Text(
                      '${(_coins * count.value).round()}',
                      key: ResultScreen.coinTotalKey,
                      style: type.title.copyWith(color: DeckTokens.gold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context) {
    final spacing = context.spacing;
    return PositionedDirectional(
      top: MediaQuery.paddingOf(context).top + spacing.sm,
      end: spacing.screenMargin,
      child: Consumer(
        builder: (context, ref, _) {
          final wallet = ref.watch(walletProvider).valueOrNull;
          final unread = wallet == null && SupabaseConfig.isConfigured;
          if (unread && !_walletAsked) {
            // An unread wallet would count the pill up from nothing. Read it
            // first; the balance stays hidden until the server has answered.
            _walletAsked = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              try {
                unawaited(ref.read(walletProvider.notifier).refresh());
              } catch (_) {}
            });
          }
          final now = wallet?.balance ?? _coins;
          final base = math.max(0, now - _coins);
          final shown = _landed ? now : base;
          final bump = AnimatedBuilder(
            animation: _fly,
            builder: (context, child) {
              final k = _fly.value > 0.85 && _fly.value < 1
                  ? ResultTokens.pillBump
                  : 1.0;
              return AnimatedScale(
                scale: k,
                duration: ResultTokens.pillBumpFor,
                child: child,
              );
            },
            child: KeyedSubtree(
              key: _pillKey,
              // Kept in the tree (the coins fly to it) but invisible until
              // the wallet has been read.
              child: Opacity(
                opacity: unread ? 0 : 1,
                child: CoinPill(balance: shown),
              ),
            ),
          );
          return bump;
        },
      ),
    );
  }

  Widget _flight() {
    final from = _from!;
    final to = _to!;
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _fly,
            builder: (context, _) {
              const n = ResultTokens.flightCoins;
              const window = 1 - (n - 1) * ResultTokens.flightStagger;
              return Stack(
                children: [
                  for (var i = 0; i < n; i++)
                    () {
                      final p = Curves.easeIn.transform(
                        ((_fly.value - i * ResultTokens.flightStagger) / window)
                            .clamp(0.0, 1.0),
                      );
                      final at = Offset.lerp(from, to, p)!;
                      return Positioned(
                        left: at.dx - ResultTokens.flightCoinSize / 2,
                        top: at.dy - ResultTokens.flightCoinSize / 2,
                        child: Opacity(
                          opacity: p == 0 ? 0 : 1 - 0.8 * p,
                          child: const MafiaCoin(
                            size: ResultTokens.flightCoinSize,
                          ),
                        ),
                      );
                    }(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fileEntry(BuildContext context) {
    final spacing = context.spacing;
    final type = context.typography;
    final screen = s;
    return DeckPress(
      child: InkWell(
        key: ResultScreen.openFileKey,
        borderRadius: BorderRadius.circular(DeckTokens.panelRadius),
        onTap: () => showMatchFile(
          context,
          file: screen.matchFile!,
          rows: screen.rows,
          awards: screen.awards,
          onShare: _shareFile,
        ),
        child: DeckPanel(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.matchFileTitle,
                  style: type.body.emphasised.copyWith(color: DeckTokens.text),
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinRowView extends StatelessWidget {
  final ResultCoinRow row;
  final Animation<double> reveal;
  const _CoinRowView({required this.row, required this.reveal});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    return FadeTransition(
      opacity: reveal,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(-ResultTokens.rowSlide / 100, 0),
          end: Offset.zero,
        ).animate(reveal),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xs / 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  row.label,
                  style: type.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MafiaCoin(size: DeckTokens.coinGlyphSmall),
                  SizedBox(width: spacing.xs),
                  Text(
                    '+${row.coins}',
                    style: type.bodySmall.emphasised.copyWith(
                      color: DeckTokens.gold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One seat's card: it starts face-down and turns over in its turn, with the
/// name and the role under it. The dead carry a ✕ and a dimmed face.
class _SeatTile extends StatelessWidget {
  final ResultRow row;
  final bool me;
  final Animation<double> flip;
  const _SeatTile({
    super.key,
    required this.row,
    required this.me,
    required this.flip,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final dead = row.eliminatedLabel != null;
    final radius = BorderRadius.circular(ResultTokens.seatRadius);
    Widget face() => ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          dead
              ? Opacity(
                  opacity: ResultTokens.deadFade,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: _art(RoleGalleryPortrait.art(row.role)),
                  ),
                )
              : _art(RoleGalleryPortrait.art(row.role)),
          if (dead)
            PositionedDirectional(
              top: spacing.xs / 2,
              start: spacing.xs,
              child: const Icon(
                Icons.close_rounded,
                size: ResultTokens.crossSize,
                color: DeckTokens.verdictMafia,
              ),
            ),
        ],
      ),
    );
    final back = ClipRRect(
      borderRadius: radius,
      child: _art(AppImages.cardBack),
    );
    final card = AnimatedBuilder(
      animation: flip,
      builder: (context, _) {
        final angle = flip.value * math.pi;
        final showFace = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, ResultTokens.flipDepth)
            ..rotateY(angle),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: DeckTokens.silverLight,
                width: ResultTokens.seatBorder,
              ),
            ),
            child: showFace
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: face(),
                  )
                : back,
          ),
        );
      },
    );
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1 / ResultTokens.seatAspect,
          child: RepaintBoundary(
            child: me
                ? DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: DeckTokens.bone,
                        width: ResultTokens.meRing,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(ResultTokens.meRingGap),
                      child: card,
                    ),
                  )
                : card,
          ),
        ),
        SizedBox(height: spacing.xs),
        CosmeticNameplate(
          name: row.name,
          plate: HostIdentityScope.plateFor(context, row.name),
          style: type.caption.emphasised.copyWith(color: colors.textPrimary),
          textAlign: TextAlign.center,
        ),
        Text(
          _roleLabel(context, row.role),
          style: type.caption.copyWith(color: _roleColor(context, row.role)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (row.eliminatedLabel != null)
          Text(
            row.eliminatedLabel!,
            style: type.caption.copyWith(color: colors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _art(String asset) => Image.asset(
    asset,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    cacheHeight: ResultTokens.seatDecode,
    excludeFromSemantics: true,
  );
}

/// The casebook's progress for today, from what the casebook already holds.
/// Draws nothing when it is off, empty or not loaded: the app invents none.
class _CasebookLine extends StatelessWidget {
  const _CasebookLine({super.key});

  @override
  Widget build(BuildContext context) {
    ProviderContainer container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      return const SizedBox.shrink();
    }
    if (!container.exists(casebookProvider)) return const SizedBox.shrink();
    return Consumer(
      builder: (context, ref, _) {
        final book = ref.watch(casebookProvider).valueOrNull;
        if (book == null || !book.enabled) return const SizedBox.shrink();
        final open = book.daily.missions.where((m) => !m.claimed).toList()
          ..sort((a, b) => b.fraction.compareTo(a.fraction));
        final mission = open.firstOrNull ?? book.daily.missions.firstOrNull;
        if (mission == null) return const SizedBox.shrink();
        final l = context.l10n;
        final spacing = context.spacing;
        final type = context.typography;
        final colors = context.colors;
        return DeckPanel(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.resultCasebook(
                        caseLine(l, mission.metric, mission.target),
                      ),
                      style: type.bodySmall.copyWith(color: DeckTokens.text),
                    ),
                    SizedBox(height: spacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(spacing.xs),
                      child: LinearProgressIndicator(
                        value: mission.fraction,
                        minHeight: spacing.xs,
                        color: DeckTokens.silverLight,
                        backgroundColor: DeckTokens.line,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.md),
              Text(
                l.casebookProgress(
                  mission.progress < mission.target
                      ? mission.progress
                      : mission.target,
                  mission.target,
                ),
                style: type.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _bondsEnabled(BuildContext context) {
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    if (!container.exists(economyCapabilitiesProvider)) return false;
    return container
            .read(economyCapabilitiesProvider)
            .valueOrNull
            ?.fun
            .characterBonds ==
        true;
  } catch (_) {
    return false;
  }
}

class _BondResultRecorder extends StatefulWidget {
  final engine.Alignment winner;
  final List<ResultRow> rows;
  final Widget child;
  const _BondResultRecorder({
    required this.winner,
    required this.rows,
    required this.child,
  });

  @override
  State<_BondResultRecorder> createState() => _BondResultRecorderState();
}

class _BondResultRecorderState extends State<_BondResultRecorder> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled || !_bondsEnabled(context)) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _record());
  }

  Future<void> _record() async {
    if (!mounted) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final controller = container.read(matchControllerProvider.notifier);
      final transport = controller.transport;
      final String receiptId;
      final DateTime completedAt;
      engine.Role? personal;
      if (transport is LocalTransport) {
        if (!transport.engine.hasMatch) return;
        final match = transport.engine.match;
        final outcome = match.outcome;
        if (match.phase != engine.GamePhase.result || outcome == null) return;
        receiptId = 'local-${match.id}';
        completedAt = outcome.completedAt;
      } else if (transport is OnlineTransport) {
        // The same public result every seat sees; this device adds the one
        // role it held, which the roster above has just shown to everyone.
        final snapshot = transport.snapshot;
        final outcome = snapshot.outcome;
        if (snapshot.phase != engine.GamePhase.result || outcome == null) {
          return;
        }
        receiptId = 'online-${transport.roomId}';
        completedAt = outcome.completedAt;
        final seat = snapshot.viewerSeat;
        personal = widget.rows
            .where((row) => row.seat == seat)
            .map((row) => row.role)
            .firstOrNull;
      } else {
        return;
      }
      final roles = widget.rows.map((row) => row.role).toSet();
      final survivors = widget.rows
          .where((row) => row.eliminatedLabel == null)
          .map((row) => row.role)
          .toSet();
      final zeroDeaths = widget.rows.every(
        (row) => row.eliminatedLabel == null,
      );
      final moment = characterMomentRole(
        winner: widget.winner,
        roles: roles,
        survivingRoles: survivors,
        personalRole: personal,
        zeroDeaths: zeroDeaths,
      );
      await container
          .read(characterBondLedgerProvider.notifier)
          .record(
            CharacterBondCase(
              receiptId: receiptId,
              completedAt: completedAt,
              winner: widget.winner,
              roles: roles,
              survivingRoles: survivors,
              personalRole: personal,
              zeroDeaths: zeroDeaths,
              momentRole: moment,
            ),
          );
    } catch (_) {
      // A flavour ledger must never obstruct or replace the public result.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BondResultMoment extends ConsumerWidget {
  final engine.Alignment winner;
  final List<ResultRow> rows;
  const _BondResultMoment({required this.winner, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_bondsEnabled(context) || rows.isEmpty) return const SizedBox.shrink();
    final arrived = ref.watch(bondLetterArrivedProvider);
    if (arrived != null) return BondLetterArrivedCard(arrival: arrived);
    return _momentLine(context);
  }

  Widget _momentLine(BuildContext context) {
    final roles = rows.map((row) => row.role).toSet();
    final survivors = rows
        .where((row) => row.eliminatedLabel == null)
        .map((row) => row.role)
        .toSet();
    final role = characterMomentRole(
      winner: winner,
      roles: roles,
      survivingRoles: survivors,
      zeroDeaths: rows.every((row) => row.eliminatedLabel == null),
    );
    final line = switch (role) {
      engine.Role.mafia => context.l10n.bondMomentMafia,
      engine.Role.silencer => context.l10n.bondMomentMafia,
      engine.Role.doctor => context.l10n.bondMomentDoctor,
      engine.Role.detective => context.l10n.bondMomentDetective,
      engine.Role.elder || engine.Role.sniper => context.l10n.bondMomentCitizen,
      engine.Role.citizen => context.l10n.bondMomentCitizen,
    };
    return Text(
      line,
      textAlign: TextAlign.center,
      style: context.typography.body.copyWith(
        color: context.colors.textSecondary,
      ),
    );
  }
}

/// The full-colour role card for one player, at roster-row size.
///
/// ## Why this widget exists rather than an inline `Image.asset`
///
/// The `Role -> gallery asset` map is the single dangerous line on this screen,
/// and putting it in one named place means there is exactly one thing for
/// `handoff_purity_test.dart` to find if it ever migrates somewhere it should
/// not. The gallery art is deliberately *not* luminance-matched across roles —
/// matching it would defeat the point of having a full-colour set — so a copy of
/// this mapping on an in-hand surface would leak brightness and hue at once,
/// and would sail past `luminance_budget_test.dart`, which only measures
/// `card_face_*`.
/// Reuses the result screen's single role-to-gallery map on other public,
/// post-match-only surfaces. The map itself remains private and singular.
class RoleGalleryPortrait extends StatelessWidget {
  final engine.Role role;
  final double height;
  const RoleGalleryPortrait({
    super.key,
    required this.role,
    required this.height,
  });

  @override
  Widget build(BuildContext context) =>
      _GalleryThumb(role: role, height: height);

  /// The full-colour painting for [role]. The map itself stays in
  /// [_GalleryThumb], the one place that owns it.
  static String art(engine.Role role) => _GalleryThumb(role: role)._art;
}

class _GalleryThumb extends StatelessWidget {
  final engine.Role role;
  final double? height;

  const _GalleryThumb({required this.role, this.height});

  String get _art => switch (role) {
    engine.Role.mafia => AppGallery.galleryMafia,
    engine.Role.silencer => AppGallery.gallerySilencer,
    engine.Role.doctor => AppGallery.galleryDoctor,
    engine.Role.detective => AppGallery.galleryDetective,
    engine.Role.elder => AppGallery.galleryElder,
    engine.Role.sniper => AppGallery.gallerySniper,
    engine.Role.citizen => AppGallery.galleryCitizen,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;

    // Card proportions, not a square thumbnail: at a glance the roster should
    // read as a hand of cards laid face-up on the table.
    final resolvedHeight = height ?? spacing.xl + spacing.lg;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radii.button),
      child: SizedBox(
        width: resolvedHeight * 2 / 3,
        height: resolvedHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.surfaceOverlay),
          child: Image.asset(
            _art,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Decoded down to roughly what is drawn. The source is 1024x1536 and
            // there is one of these per player; at full resolution a ten-player
            // roster would hold ~60MB of decoded bitmaps for thumbnails a
            // centimetre tall.
            cacheHeight: 256,
            // The role is already stated in text on the same row. Announcing the
            // art as well would make a screen reader say it twice.
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
