import 'dart:async';

import 'package:flutter/material.dart';

// `show Role` is deliberate: engine's `Alignment` collides with Flutter's.
import '../../engine/models/enums.dart' show Role;
import '../../app/l10n/app_localizations.dart';
import '../theme/mafia_theme.dart';
import 'hold_pad.dart';
import 'player_tile.dart';
import 'textured_surface.dart';

/// The five observable states of a single in-hand turn.
///
/// Reference: spec US1/US3, leakage invariants L-01, L-07, L-08, L-09.
enum TurnShellState {
  /// Neutral handoff: the phone is being passed. Nothing about the turn is on
  /// screen — not even whose turn it is beyond the name printed on the pad.
  handoff,

  /// The identity pad has been held long enough; turn content is visible and
  /// the dwell gate is running.
  revealed,

  /// A target has been picked but the dwell gate has not necessarily elapsed.
  selecting,

  /// The action has been submitted. The pass control exists but is locked.
  confirmed,

  /// The turn floor has elapsed; the pass control is enabled.
  passUnlocked,
}

/// A selectable target within a turn. Seat + display name + tile state — never
/// a role.
@immutable
class TurnTarget {
  final int seat;
  final String name;

  /// Contents of the reserved indicator slot. Non-zero only for a Mafia actor,
  /// but the slot itself is laid out identically for everyone (L-02).
  final int indicatorCount;

  /// Whether this seat can be picked right now. Never role-derived.
  final bool selectable;

  const TurnTarget({
    required this.seat,
    required this.name,
    this.indicatorCount = 0,
    this.selectable = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TurnTarget &&
          runtimeType == other.runtimeType &&
          seat == other.seat &&
          name == other.name &&
          indicatorCount == other.indicatorCount &&
          selectable == other.selectable;

  @override
  int get hashCode => Object.hash(seat, name, indicatorCount, selectable);
}

/// All user-visible copy used by [TurnShell].
///
/// Injected rather than read from [AppLocalizations] so that golden tests can
/// hold copy constant while varying the role — which is precisely the property
/// the symmetry tests assert.
@immutable
class TurnShellLabels {
  final String turnLabel;
  final String handoffInstruction;
  final String notYou;
  final String waitHint;
  final String pickHint;
  final String confirmAction;
  final String confirmedTitle;
  final String confirmedBody;
  final String passAction;
  final String passLockedHint;

  const TurnShellLabels({
    required this.turnLabel,
    required this.handoffInstruction,
    required this.notYou,
    required this.waitHint,
    required this.pickHint,
    required this.confirmAction,
    required this.confirmedTitle,
    required this.confirmedBody,
    required this.passAction,
    required this.passLockedHint,
  });

  /// Builds the labels from the app's localisations.
  ///
  /// The class stays injectable rather than reading `context` itself: the
  /// symmetry suites need to hold copy constant while varying the role, which
  /// is precisely the property they assert.
  factory TurnShellLabels.of(AppLocalizations l10n) => TurnShellLabels(
    turnLabel: l10n.yourTurn,
    handoffInstruction: l10n.holdToConfirm,
    notYou: l10n.notYou,
    waitHint: l10n.takeYourTime,
    pickHint: l10n.choosePlayer,
    confirmAction: l10n.confirmAction,
    confirmedTitle: l10n.choiceRecorded,
    confirmedBody: l10n.keepPhoneUntilUnlock,
    passAction: l10n.passPhone,
    passLockedHint: l10n.waitEllipsis,
  );
}

/// The neutral shell every in-hand turn is rendered inside.
///
/// ## The invariant this widget exists to enforce
///
/// [role] is accepted so that callers can pass an [ActorTurnView] straight
/// through, but **no rendering decision in this file reads it**. Layout,
/// dimensions, colours, motion and every timing gate are identical for mafia,
/// doctor, detective and citizen. Role may only change the *text and data* the
/// caller supplies via [promptText], [targets] and [confirmationDetail]
/// (Constitution II, L-01).
///
/// ## Timing model (L-07, L-08)
///
/// * `t = 0` is the instant the hold-to-reveal completes.
/// * Confirm is disabled until `t >= timing.dwellGate` (8.0s) — the same for
///   every role, and unaffected by how quickly a target is picked.
/// * The pass control unlocks at `t >= timing.turnFloor` (12.0s). That deadline
///   is measured from reveal, **never from the confirm instant**, so a player
///   who acts in one second and a player who acts in seven produce the same
///   observable turn length.
///
/// ## Sensory neutrality (Constitution VI, L-10/L-11)
///
/// This widget deliberately emits no haptics and no audio: it is by definition
/// an in-hand surface, and a buzz or a click is audible to the neighbours.
class TurnShell extends StatefulWidget {
  /// Identifies the turn. Changing it resets the shell back to [TurnShellState.handoff].
  final Object turnId;

  /// Display name printed on the handoff pad.
  final String playerName;

  /// Accepted for API completeness. Never consulted for rendering or timing.
  final Role role;

  /// The role-specific question. Text only — never affects geometry.
  final String promptText;

  /// Selectable seats. Identical set for every role in a given night.
  final List<TurnTarget> targets;

  /// Optional post-confirm detail (e.g. the Detective's ephemeral result).
  /// The slot that holds it is always present and always the same height, so
  /// its emptiness is not observable (L-02).
  final String? confirmationDetail;

  final ValueChanged<int> onConfirmed;
  final VoidCallback onPass;
  final VoidCallback? onNotYou;
  final ValueChanged<TurnShellState>? onStateChanged;

  /// All user-visible copy. Required rather than defaulted: a default would be
  /// a second, untranslated copy of every string, and the l10n coverage test
  /// exists precisely to stop that reappearing.
  final TurnShellLabels labels;

  /// Keys for the reserved layout slots. Every one of these exists in every
  /// state and for every role; the symmetry tests assert their rects never move.
  static const Key slotHeader = ValueKey('turn_shell_header');
  static const Key slotRail = ValueKey('turn_shell_rail');
  static const Key slotBody = ValueKey('turn_shell_body');
  static const Key slotDetail = ValueKey('turn_shell_detail');
  static const Key slotAction = ValueKey('turn_shell_action');
  static const Key slotFootnote = ValueKey('turn_shell_footnote');

  /// Key of the primary action button (Confirm, then Pass).
  static const Key actionButton = ValueKey('turn_shell_action_button');

  /// Key of the hold-to-reveal identity pad.
  static const Key holdPad = ValueKey('turn_shell_hold_pad');

  const TurnShell({
    super.key,
    required this.turnId,
    required this.playerName,
    required this.role,
    required this.promptText,
    required this.targets,
    required this.onConfirmed,
    required this.onPass,
    this.confirmationDetail,
    this.onNotYou,
    this.onStateChanged,
    required this.labels,
  });

  @override
  State<TurnShell> createState() => _TurnShellState();
}

class _TurnShellState extends State<TurnShell> with TickerProviderStateMixin {
  AnimationController? _dwellController;

  Timer? _dwellTimer;
  Timer? _floorTimer;

  bool _revealed = false;
  bool _dwellElapsed = false;
  bool _floorElapsed = false;
  bool _confirmed = false;
  int? _selectedSeat;

  TurnShellState? _lastReportedState;

  /// Bumped on reset so the pad discards any hold in progress.
  int _padGeneration = 0;

  @override
  void didUpdateWidget(covariant TurnShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turnId != widget.turnId) {
      // A rebuild is already scheduled by the parent, so mutate directly rather
      // than calling setState from within didUpdateWidget.
      _resetTurn();
    }
  }

  void _resetTurn() {
    _cancelTimers();
    _dwellController?.dispose();
    _dwellController = null;
    _padGeneration++;
    _revealed = false;
    _dwellElapsed = false;
    _floorElapsed = false;
    _confirmed = false;
    _selectedSeat = null;
    _lastReportedState = null;
  }

  void _cancelTimers() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _floorTimer?.cancel();
    _floorTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    _dwellController?.dispose();
    super.dispose();
  }

  /// Starts the turn clock. Both gates are scheduled here, from the same
  /// instant, using token durations only.
  void _startTurn() {
    final timing = context.timing;

    _dwellController = AnimationController(
      vsync: this,
      duration: timing.turnFloor,
    )..forward();

    _dwellTimer = Timer(timing.dwellGate, () {
      if (!mounted) return;
      setState(() => _dwellElapsed = true);
    });
    _floorTimer = Timer(timing.turnFloor, () {
      if (!mounted) return;
      setState(() => _floorElapsed = true);
    });

    setState(() => _revealed = true);
  }

  // ---------------------------------------------------------------------------
  // Derived state
  // ---------------------------------------------------------------------------

  TurnShellState get _state {
    if (!_revealed) return TurnShellState.handoff;
    if (_confirmed) {
      return _floorElapsed
          ? TurnShellState.passUnlocked
          : TurnShellState.confirmed;
    }
    return _selectedSeat == null
        ? TurnShellState.revealed
        : TurnShellState.selecting;
  }

  bool get _confirmEnabled =>
      _dwellElapsed && _selectedSeat != null && !_confirmed;

  bool get _passEnabled => _confirmed && _floorElapsed;

  void _select(int seat) {
    if (_confirmed) return;
    setState(() => _selectedSeat = seat);
  }

  void _confirm() {
    if (!_confirmEnabled) return;
    final seat = _selectedSeat!;
    setState(() => _confirmed = true);
    widget.onConfirmed(seat);
  }

  void _notifyStateIfChanged() {
    final current = _state;
    if (current != _lastReportedState) {
      _lastReportedState = current;
      final cb = widget.onStateChanged;
      if (cb != null) {
        // Defer so listeners may rebuild without reentering this build pass.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cb(current);
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build — ONE tree, identical for every role.
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _notifyStateIfChanged();

    final spacing = context.spacing;
    final state = _state;

    return AppBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.screenMargin,
                vertical: spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyedSubtree(
                    key: TurnShell.slotHeader,
                    child: _header(state),
                  ),
                  SizedBox(height: spacing.md),
                  KeyedSubtree(key: TurnShell.slotRail, child: _progressRail()),
                  SizedBox(height: spacing.md),
                  Expanded(
                    child: KeyedSubtree(
                      key: TurnShell.slotBody,
                      child: _body(state),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  KeyedSubtree(
                    key: TurnShell.slotDetail,
                    child: _detailSlot(state),
                  ),
                  SizedBox(height: spacing.md),
                  KeyedSubtree(
                    key: TurnShell.slotAction,
                    child: _actionSlot(state),
                  ),
                  SizedBox(height: spacing.sm),
                  KeyedSubtree(
                    key: TurnShell.slotFootnote,
                    child: _footnote(state),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A reserved height that grows with the OS text size.
  ///
  /// Every slot in this shell is a fixed height, which is what makes the four
  /// roles' layouts provably identical. Fixed in *logical pixels* is not the
  /// same as fixed in *lines of text*, though: at 130% Dynamic Type the header
  /// overflowed its reservation by 13px, because the type got taller and the
  /// box did not.
  ///
  /// Scaling the reservation by the same factor fixes it without weakening
  /// anything — the scale comes from the OS, not from the role, so all four
  /// still measure identical. Capped, because someone at 200% would otherwise
  /// push the action button off the bottom, and a control you cannot reach is
  /// worse than one you have to squint at.
  double _reserve(double height) =>
      height * MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);

  /// Fixed-height header. Text changes with state, never with role.
  Widget _header(TurnShellState state) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return SizedBox(
      // Two lines of type, plus the gap between them, plus a little slack.
      //
      // Sized from the tokens rather than eyeballed, because it has to survive
      // a change to either style: the headline is 32 × 1.6 and the caption is
      // 12 × 1.6, which is 74.4 — the old `xxl + lg` reservation was 72 and
      // overflowed by exactly the 2px the framework reported when Arabic
      // leading went from 1.4 to 1.6.
      //
      // This is a *role-invariant* number, so growing it costs nothing in
      // parity terms: all four roles reserve the same box, which is the whole
      // point of the slot.
      height: _reserve(spacing.xxl + spacing.lg + spacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.playerName,
            style: type.headline.copyWith(color: colors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.xs),
          Text(
            widget.labels.turnLabel,
            style: type.caption.copyWith(color: colors.textMuted),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Fixed-height turn-progress rail. Driven only by the shared turn clock.
  Widget _progressRail() {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final controller = _dwellController;

    return SizedBox(
      height: spacing.xs,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radii.button),
        child: controller == null
            ? ColoredBox(color: colors.surfaceOverlay)
            : AnimatedBuilder(
                animation: controller,
                builder: (context, _) => LinearProgressIndicator(
                  value: controller.value,
                  backgroundColor: colors.surfaceOverlay,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.textMuted),
                ),
              ),
      ),
    );
  }

  Widget _body(TurnShellState state) {
    switch (state) {
      case TurnShellState.handoff:
        return _handoffPad();
      case TurnShellState.revealed:
      case TurnShellState.selecting:
        return _targetPanel();
      case TurnShellState.confirmed:
      case TurnShellState.passUnlocked:
        return _confirmedPanel();
    }
  }

  Widget _handoffPad() {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final diameter = spacing.xxl * 3;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        KeyedSubtree(
          key: TurnShell.holdPad,
          // The generation key forces a fresh pad on turn change, so a hold
          // begun by the previous player can never carry over.
          child: HoldPad(
            key: ValueKey(_padGeneration),
            holdDuration: context.timing.holdToReveal,
            instruction: widget.labels.handoffInstruction,
            diameter: diameter,
            onHoldComplete: _startTurn,
          ),
        ),
        SizedBox(height: spacing.lg),
        TextButton(
          onPressed: widget.onNotYou,
          child: Text(
            widget.labels.notYou,
            style: type.bodySmall.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _targetPanel() {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.promptText,
          style: type.title.copyWith(color: colors.textPrimary),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: spacing.md),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: widget.targets.length,
            separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
            itemBuilder: (context, index) {
              final target = widget.targets[index];
              return PlayerTile(
                seat: target.seat,
                name: target.name,
                indicatorCount: target.indicatorCount,
                state: !target.selectable
                    ? PlayerTileState.disabled
                    : _selectedSeat == target.seat
                    ? PlayerTileState.selected
                    : PlayerTileState.normal,
                onTap: () => _select(target.seat),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _confirmedPanel() {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.labels.confirmedTitle,
          style: type.title.copyWith(color: colors.textPrimary),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: spacing.sm),
        Text(
          widget.labels.confirmedBody,
          style: type.bodySmall.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Reserved detail slot. Present and identically sized in every state and for
  /// every role, whether or not there is anything to show (L-02).
  /// The Detective's result, and an equally-sized nothing for everyone else.
  ///
  /// ## The box is back, and only when there is something in it
  ///
  /// Three versions of this slot, and the reasoning for the third is the one
  /// worth keeping:
  ///
  /// 1. A filled, bordered panel drawn in every state for every role. Empty for
  ///    three players out of four, which read as a bug and was reported as one.
  /// 2. No panel at all, just text. That fixed the empty box and created a
  ///    worse problem — the one player who *does* get a result got a bare word
  ///    floating in the layout with nothing to say it was the answer to their
  ///    question.
  /// 3. This: the panel is drawn **only when it has content**, and the space it
  ///    occupies is reserved unconditionally.
  ///
  /// ## What that costs, stated rather than glossed
  ///
  /// L-02 asks that the slot's emptiness not be observable, and a panel that
  /// appears is a larger change in emitted light than a word that appears. That
  /// is a real cost and it is accepted deliberately: the *bounds* never move —
  /// the golden suite measures [TurnShell.slotDetail]'s rect for all four roles
  /// in every state — and the alternative was a result the player could not
  /// reliably identify as their result. A detective who misreads their own
  /// investigation is a worse failure than a detective whose screen is a few
  /// hundred lumens brighter for four seconds.
  Widget _detailSlot(TurnShellState state) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    // Every role gets a line, and only the *text* differs — which is all
    // Article II permits a role to change anyway.
    //
    // The detective's line is their verdict. Everyone else falls back to the
    // name they picked, which is genuinely useful: in a dark room it is the
    // only confirmation that the tap landed on the seat they meant.
    //
    // This fallback is not cosmetic. With a panel for one role and bare ground
    // for the other three, the shell went over the ±2% luminance budget and
    // `luminance_budget_test` caught it — a filled box is a lot of light.
    // Differences between two names are well inside the budget; a whole panel
    // is not.
    final picked = _selectedSeat;
    final detail = widget.confirmationDetail ??
        (picked == null
            ? null
            : widget.targets
                .where((t) => t.seat == picked)
                .map((t) => t.name)
                .firstOrNull);

    final showDetail = detail != null &&
        (state == TurnShellState.confirmed ||
            state == TurnShellState.passUnlocked);

    return SizedBox(
      // Unconditional. This is the part L-02 actually requires.
      height: _reserve(spacing.xxl),
      child: showDetail
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(radii.card),
                border: Border.all(color: colors.accentGold),
              ),
              child: Center(
                child: Text(
                  detail,
                  style: type.title.copyWith(color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }

  /// Fixed-height action slot: Confirm before the action, Pass after it.
  Widget _actionSlot(TurnShellState state) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    final isPassPhase =
        state == TurnShellState.confirmed ||
        state == TurnShellState.passUnlocked;
    final enabled = isPassPhase ? _passEnabled : _confirmEnabled;
    final label = isPassPhase
        ? widget.labels.passAction
        : widget.labels.confirmAction;

    return SizedBox(
      height: _reserve(spacing.xxl + spacing.sm),
      child: FilledButton(
        key: TurnShell.actionButton,
        onPressed: enabled ? (isPassPhase ? widget.onPass : _confirm) : null,
        style: FilledButton.styleFrom(
          backgroundColor: colors.accentGold,
          foregroundColor: colors.surfaceBase,
          disabledBackgroundColor: colors.surfaceOverlay,
          disabledForegroundColor: colors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.button),
          ),
        ),
        child: Text(label, style: type.title),
      ),
    );
  }

  /// Fixed-height hint line. Never names a role and never counts down in a way
  /// that differs between roles.
  Widget _footnote(TurnShellState state) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    final String text;
    switch (state) {
      case TurnShellState.handoff:
        text = '';
      case TurnShellState.revealed:
        text = widget.labels.pickHint;
      case TurnShellState.selecting:
        text = _dwellElapsed ? '' : widget.labels.waitHint;
      case TurnShellState.confirmed:
        text = widget.labels.passLockedHint;
      case TurnShellState.passUnlocked:
        text = '';
    }

    return SizedBox(
      height: _reserve(spacing.lg),
      child: Center(
        child: Text(
          text,
          style: type.caption.copyWith(color: colors.textMuted),
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
