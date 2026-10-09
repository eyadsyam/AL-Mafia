import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../data/player_group.dart';
import '../../../engine/balance_guard.dart';
import '../../../engine/models/player.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/deck_public.dart';
import '../../widgets/deck/seat_card.dart';
import '../../widgets/gender_picker.dart';
import '../../widgets/mafia_kit.dart';

/// Add Players screen (S-02) — collect player names in seating order.
///
/// Reference: spec US4, FR-001, FR-006 (duplicate disambiguation), T058
/// UI patterns: see turn_shell.dart for styling reference
///
/// ## Two modes
///
/// **Fresh** — an empty list, the behaviour this screen has always had, and
/// still exactly what a first-run host sees.
///
/// **Group** — reached by picking a saved roster. The names arrive pre-filled
/// *in the saved order*, and the per-row control changes from delete to a
/// presence toggle. That swap is the point of the whole feature: when someone
/// is absent tonight the host must not be made to delete them, because deleting
/// throws away the roster they will want again next week, which is the exact
/// friction saved groups exist to remove.
///
/// ## The screen stays dumb on purpose
///
/// No providers are read here. Everything it needs — the roster, the group, the
/// other saved groups — arrives as plain data, and everything it wants done
/// leaves as a callback. That is what keeps it pumpable in a widget test with
/// no router and no `ProviderScope`, which several existing tests rely on.
class AddPlayersScreen extends StatefulWidget {
  /// Callback with the final player list when the host moves on.
  ///
  /// Carries **only the players who are present**, in seating order (list index
  /// = seat). Anyone toggled away tonight is not in it and is not in the match.
  final void Function(List<String> names) onNext;

  /// Back to the home screen. A host who tapped "start" by mistake must not
  /// have to quit the app to undo it.
  final VoidCallback onBack;

  /// Names to start with, in seating order. Never sorted.
  final List<String> initialNames;
  final Map<String, PlayerGender> initialGenders;
  final ValueChanged<Map<String, PlayerGender>>? onGendersChanged;

  /// The group these names came from, or null for a fresh roster.
  ///
  /// Its presence is what turns on attendance toggles and, if the group has a
  /// saved configuration, the quick-start action.
  final PlayerGroup? group;

  /// Every saved group, used for one thing: not offering to save a roster that
  /// is already saved. Asking "shall I remember these people?" about people the
  /// app already remembers is how a helpful prompt becomes noise.
  final List<PlayerGroup> savedGroups;

  /// Start the match immediately on the group's saved role distribution and
  /// settings, skipping the roles and settings screens.
  ///
  /// Null disables the action entirely. Even when non-null it is only offered
  /// while the saved configuration still fits who is actually here — see
  /// [_canQuickStart].
  final void Function(List<String> names)? onQuickStart;

  /// Offer to save this roster as a new group. Null hides the prompt.
  final void Function(List<String> names)? onSaveGroup;

  const AddPlayersScreen({
    super.key,
    required this.onNext,
    required this.onBack,
    this.initialNames = const [],
    this.initialGenders = const {},
    this.onGendersChanged,
    this.group,
    this.savedGroups = const [],
    this.onQuickStart,
    this.onSaveGroup,
  });

  static const Key quickStartButton = ValueKey('players_quick_start');
  static const Key nextButton = ValueKey('players_next');
  static const Key addButton = ValueKey('players_add');
  static const Key saveGroupPrompt = ValueKey('players_save_group_prompt');
  static const Key saveGroupAccept = ValueKey('players_save_group_accept');
  static const Key saveGroupDismiss = ValueKey('players_save_group_dismiss');

  static Key attendanceToggleFor(int seat) =>
      ValueKey('attendance_toggle_$seat');

  @override
  State<AddPlayersScreen> createState() => _AddPlayersScreenState();
}

class _AddPlayersScreenState extends State<AddPlayersScreen> {
  /// Everyone on screen, in seating order — present and absent alike.
  late final List<String> _players = [...widget.initialNames];
  late final Map<String, PlayerGender> _genders = {...widget.initialGenders};
  PlayerGender _gender = PlayerGender.male;

  /// The group in play: the one the host arrived with, or one picked from the
  /// chips above the field. Null is a fresh roster.
  late PlayerGroup? _group = widget.group;

  /// Members sitting tonight out. Held by name rather than by index so a
  /// reorder cannot silently mark the wrong person away.
  final Set<String> _absent = {};

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _scrollKey = GlobalKey();

  /// The save-group prompt is offered once. Dismissing or accepting it retires
  /// it for this visit — it is a suggestion, not a demand.
  bool _savePromptClosed = false;

  /// Cards leaving, kept on screen until their exit finishes.
  final List<_Leaving> _leaving = [];
  int _leavingId = 0;

  // Grid geometry, refreshed every build.
  double _cardW = 0;
  double _cardH = 0;
  double _gap = 0;
  double _gridW = 0;
  bool _rtl = true;

  // A card held under a finger.
  String? _dragName;
  Offset _dragPos = Offset.zero;
  Offset _grab = Offset.zero;
  int _target = 0;
  Offset _lastGlobal = Offset.zero;
  Timer? _edgeTimer;
  int _edgeDir = 0;

  @override
  void dispose() {
    _edgeTimer?.cancel();
    _inputController.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _groupMode => _group != null;

  bool _isMember(String name) => _group?.memberNames.contains(name) ?? false;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Seating order, present players only. This is what starts a match.
  List<String> get _present => [
    for (final name in _players)
      if (!_absent.contains(name)) name,
  ];

  bool get _full => _players.length >= SeatTokens.maxPlayers;

  /// Adds a player name, auto-suffixing duplicates.
  void _addPlayer() {
    final name = _inputController.text.trim();
    if (name.isEmpty || _full) return;

    _inputController.clear();

    // Auto-suffix duplicates
    var finalName = name;
    int suffix = 2;
    while (_players.contains(finalName)) {
      finalName = '$name $suffix';
      suffix++;
    }

    setState(() {
      _players.add(finalName);
      _genders[finalName] = _gender;
      widget.onGendersChanged?.call(_genders);
    });
    // Enter submits and drops focus; the next name is one keystroke away.
    _inputFocus.requestFocus();
  }

  void _removePlayer(String name) {
    final index = _players.indexOf(name);
    if (index < 0) return;
    setState(() {
      if (!_still && _cardW > 0) {
        _leaving.add(
          _Leaving(
            id: _leavingId++,
            name: name,
            seat: index + 1,
            gender: _genders[name] ?? PlayerGender.unspecified,
            at: _slotOffset(index),
          ),
        );
      }
      _players.removeAt(index);
      _absent.remove(name);
    });
  }

  /// Marks a member present or away for tonight only.
  ///
  /// Note what this does *not* touch: the saved group. Attendance is a property
  /// of this evening, and a member who is away on Friday is still in the group
  /// on Saturday.
  void _toggleAttendance(String name) {
    setState(() {
      if (!_absent.remove(name)) _absent.add(name);
    });
  }

  void _flipGender(String name) {
    setState(() {
      _genders[name] = _genders[name] == PlayerGender.female
          ? PlayerGender.male
          : PlayerGender.female;
      widget.onGendersChanged?.call(_genders);
    });
  }

  /// A saved group's chip: its people take the table, in their saved order.
  void _pickGroup(PlayerGroup group, bool on) {
    setState(() {
      if (!on) {
        _group = null;
        _absent.clear();
        return;
      }
      _group = group;
      _absent.clear();
      _players
        ..clear()
        ..addAll(group.memberNames);
      _genders.addAll(group.genders);
      widget.onGendersChanged?.call(_genders);
    });
  }

  bool get _canNext => _present.length >= SeatTokens.minPlayers;

  /// Whether the group's saved configuration still describes who is here.
  ///
  /// It stops fitting the moment attendance changes the head count — a
  /// distribution for eight does not sum for seven — and a distribution that
  /// does not sum is exactly what the balance guard exists to refuse. Rather
  /// than quietly reshuffling roles on the host's behalf, the action simply
  /// stops being offered and the normal roles screen takes over, which is the
  /// right place to decide who drops when the table shrinks.
  bool get _canQuickStart {
    if (widget.onQuickStart == null) return false;
    final counts = _group?.lastRoleCounts;
    if (counts == null) return false;

    final present = _present.length;
    if (counts.values.fold(0, (a, b) => a + b) != present) return false;

    return BalanceGuard.evaluate(
      playerCount: present,
      roleCounts: counts,
    ).valid;
  }

  /// Whether to offer to remember this roster.
  ///
  /// Suppressed in group mode (already saved), below the minimum table size
  /// (not yet a roster), once closed, and — the one that matters — when some
  /// saved group already has these same people.
  bool get _showSavePrompt {
    if (widget.onSaveGroup == null) return false;
    if (_groupMode || _savePromptClosed) return false;
    if (_present.length < SeatTokens.minPlayers) return false;
    final present = _present;
    return !widget.savedGroups.any((g) => g.hasSameMembers(present));
  }

  void _onNext() => widget.onNext(_present);

  void _onQuickStart() => widget.onQuickStart!(_present);

  void _onSaveGroup() {
    setState(() => _savePromptClosed = true);
    widget.onSaveGroup!(_present);
  }

  // ── Grid geometry ────────────────────────────────────────────────────────

  /// Top-left of a seat, in the grid's own space. Right-to-left puts seat 1 at
  /// the right, the way the circle is read.
  Offset _slotOffset(int slot) {
    final col = slot % SeatTokens.columns;
    final row = slot ~/ SeatTokens.columns;
    final step = _cardW + _gap;
    final x = _rtl ? _gridW - _cardW - col * step : col * step;
    return Offset(x, row * (_cardH + _gap));
  }

  int _slotAt(Offset point) {
    final step = _cardW + _gap;
    var col = (point.dx / step).floor().clamp(0, SeatTokens.columns - 1);
    if (_rtl) col = SeatTokens.columns - 1 - col;
    final row = (point.dy / (_cardH + _gap)).floor().clamp(0, 99);
    return (row * SeatTokens.columns + col).clamp(0, _players.length - 1);
  }

  Offset _toGrid(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  // ── Long-press drag ──────────────────────────────────────────────────────

  void _dragStart(String name, Offset global) {
    final index = _players.indexOf(name);
    if (index < 0 || _cardW == 0) return;
    HapticFeedback.selectionClick();
    final slot = _slotOffset(index);
    setState(() {
      _dragName = name;
      _lastGlobal = global;
      _grab = _toGrid(global) - slot;
      _dragPos = slot;
      _target = index;
    });
  }

  void _dragMove(Offset global) {
    if (_dragName == null) return;
    _lastGlobal = global;
    _followPointer();
    _watchEdges(global);
  }

  void _followPointer() {
    final local = _toGrid(_lastGlobal);
    final centre = local - _grab + Offset(_cardW / 2, _cardH / 2);
    setState(() {
      _dragPos = local - _grab;
      _target = _slotAt(centre);
    });
  }

  void _watchEdges(Offset global) {
    final box = _scrollKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final y = box.globalToLocal(global).dy;
    final dir = y < SeatTokens.edgeZone
        ? -1
        : (y > box.size.height - SeatTokens.edgeZone ? 1 : 0);
    if (dir == _edgeDir) return;
    _edgeDir = dir;
    _edgeTimer?.cancel();
    _edgeTimer = null;
    if (dir == 0) return;
    _edgeTimer = Timer.periodic(SeatTokens.edgeTick, (_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final next = (_scroll.offset + dir * SeatTokens.edgeStep).clamp(0.0, max);
      if (next == _scroll.offset) return;
      _scroll.jumpTo(next);
      _followPointer();
    });
  }

  void _dragEnd() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
    _edgeDir = 0;
    final name = _dragName;
    if (name == null) return;
    setState(() {
      final from = _players.indexOf(name);
      if (from >= 0) {
        _players.removeAt(from);
        _players.insert(_target.clamp(0, _players.length), name);
      }
      _dragName = null;
    });
  }

  /// The seating as it will be if the held card is let go now: the others have
  /// already slid to make room.
  List<String> get _order {
    final name = _dragName;
    if (name == null) return _players;
    final rest = [..._players]..remove(name);
    rest.insert(_target.clamp(0, rest.length), name);
    return rest;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = context.l10n;

    final canNext = _canNext;
    final canQuickStart = _canQuickStart;
    final present = _present.length;

    return DeckScaffold(
      title: _group?.name ?? l10n.addPlayersTitle,
      subtitle: _groupMode ? l10n.attendanceHint : l10n.seatingDragHint,
      onBack: widget.onBack,
      trailing: DeckPill('$present'),
      body: SingleChildScrollView(
        key: _scrollKey,
        controller: _scroll,
        physics: _dragName == null
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.savedGroups.isNotEmpty) ...[
              _GroupChips(
                groups: widget.savedGroups,
                selectedId: _group?.id,
                onPick: _pickGroup,
              ),
              SizedBox(height: spacing.md),
            ],
            _AddRow(
              controller: _inputController,
              focus: _inputFocus,
              gender: _gender,
              onGender: (g) => setState(() => _gender = g),
              onAdd: _addPlayer,
              canAdd: !_full,
            ),
            SizedBox(height: spacing.md),
            _buildGrid(context),
          ],
        ),
      ),
      primary: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showSavePrompt) ...[
            _SaveGroupPrompt(
              onSave: _onSaveGroup,
              onDismiss: () => setState(() => _savePromptClosed = true),
            ),
            SizedBox(height: spacing.sm),
          ],
          if (canQuickStart) ...[
            BoneButton(
              key: AddPlayersScreen.quickStartButton,
              label: l10n.quickStartAction,
              onPressed: _onQuickStart,
            ),
            SizedBox(height: spacing.sm),
            RimButton(
              key: AddPlayersScreen.nextButton,
              label: l10n.next,
              onPressed: canNext ? _onNext : null,
            ),
          ] else
            BoneButton(
              key: AddPlayersScreen.nextButton,
              label: l10n.next,
              onPressed: canNext ? _onNext : null,
              disabledReason: canNext
                  ? null
                  : l10n.playersStillNeeded(SeatTokens.minPlayers - present),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return LayoutBuilder(
      builder: (context, box) {
        _rtl = Directionality.of(context) == TextDirection.rtl;
        _gap = spacing.md;
        _gridW = box.maxWidth;
        _cardW =
            (_gridW - _gap * (SeatTokens.columns - 1)) / SeatTokens.columns;
        _cardH = _cardW / SeatTokens.aspect;

        final n = _players.length;
        final slots = _full ? n : n + 1;
        final rows = math.max(1, (slots / SeatTokens.columns).ceil());
        final height = rows * _cardH + (rows - 1) * _gap;
        final order = _order;
        final still = _still;
        final need = SeatTokens.minPlayers - _present.length;

        Widget glide(Offset to, Widget child, {bool instant = false}) =>
            _Glide(offset: to, instant: instant || still, child: child);

        final cards = <Widget>[];
        // Stable child order keeps each card's state through a reorder; the
        // held card is last so it paints above the others.
        final names = [..._players];
        if (_dragName != null) {
          names
            ..remove(_dragName)
            ..add(_dragName!);
        }
        for (final name in names) {
          final slot = order.indexOf(name);
          final held = name == _dragName;
          final away = _absent.contains(name);
          final member = _groupMode && _isMember(name);
          final seat = slot + 1;
          cards.add(
            Positioned(
              key: ValueKey('seat_$name'),
              left: 0,
              top: 0,
              width: _cardW,
              height: _cardH,
              child: glide(
                held ? _dragPos : _slotOffset(slot),
                instant: held,
                _Deal(
                  delay: _players.indexOf(name),
                  child: AnimatedScale(
                    scale: held ? SeatTokens.liftScale : 1,
                    duration: still ? Duration.zero : DeckTokens.press,
                    curve: Curves.easeOutCubic,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _flipGender(name),
                      onLongPressStart: (d) =>
                          _dragStart(name, d.globalPosition),
                      onLongPressMoveUpdate: (d) => _dragMove(d.globalPosition),
                      onLongPressEnd: (_) => _dragEnd(),
                      onLongPressCancel: _dragEnd,
                      child: SeatCard(
                        name: name,
                        seat: seat,
                        gender: _genders[name] ?? PlayerGender.unspecified,
                        lifted: held,
                        away: away,
                        // A saved member is toggled, never deleted. A guest
                        // added just for tonight was never in the group, so
                        // there is nothing to protect and removal is honest.
                        cornerKey: member
                            ? AddPlayersScreen.attendanceToggleFor(seat)
                            : ValueKey('delete_player_$seat'),
                        cornerIcon: member && away ? Icons.undo : Icons.close,
                        cornerLabel: member
                            ? (away ? l10n.absentAction : l10n.presentAction)
                            : l10n.deleteAction,
                        onCorner: member
                            ? () => _toggleAttendance(name)
                            : () => _removePlayer(name),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        for (final gone in _leaving) {
          cards.add(
            Positioned(
              key: ValueKey('leaving_${gone.id}'),
              left: 0,
              top: 0,
              width: _cardW,
              height: _cardH,
              child: IgnorePointer(
                child: Transform.translate(
                  offset: gone.at,
                  child: _Flyout(
                    onDone: () {
                      if (mounted) setState(() => _leaving.remove(gone));
                    },
                    child: SeatCard(
                      name: gone.name,
                      seat: gone.seat,
                      gender: gone.gender,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (!_full) {
          cards.add(
            Positioned(
              key: const ValueKey('seat_empty'),
              left: 0,
              top: 0,
              width: _cardW,
              height: _cardH,
              child: glide(
                _slotOffset(n),
                EmptySeatCard(
                  label: need > 0
                      ? l10n.playersStillNeeded(need)
                      : l10n.seatNumber(n + 1),
                  onTap: _inputFocus.requestFocus,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          key: _gridKey,
          height: height,
          child: Stack(clipBehavior: Clip.none, children: cards),
        );
      },
    );
  }
}

class _Leaving {
  final int id;
  final String name;
  final int seat;
  final PlayerGender gender;
  final Offset at;
  const _Leaving({
    required this.id,
    required this.name,
    required this.seat,
    required this.gender,
    required this.at,
  });
}

/// Saved groups, one tap to seat their people.
class _GroupChips extends StatelessWidget {
  final List<PlayerGroup> groups;
  final int? selectedId;
  final void Function(PlayerGroup group, bool on) onPick;

  const _GroupChips({
    required this.groups,
    required this.selectedId,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return SizedBox(
      height: DeckTokens.chip,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing.sm),
        itemBuilder: (context, i) {
          final g = groups[i];
          return DeckChip(
            label: '${g.name} · ${g.memberNames.length}',
            selected: g.id == selectedId,
            onSelected: (on) => onPick(g, on),
          );
        },
      ),
    );
  }
}

/// Name field with the ولد/بنت toggle inside it, and the «+» beside it. Enter
/// adds too.
class _AddRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final PlayerGender gender;
  final ValueChanged<PlayerGender> onGender;
  final VoidCallback onAdd;
  final bool canAdd;

  const _AddRow({
    required this.controller,
    required this.focus,
    required this.gender,
    required this.onGender,
    required this.onAdd,
    required this.canAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final l10n = context.l10n;
    final type = context.typography;
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(context.radii.button),
              border: Border.all(color: DeckTokens.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    textInputAction: TextInputAction.done,
                    style: DeckTokens.body(
                      type,
                    ).copyWith(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: l10n.playerNameHint,
                      hintStyle: DeckTokens.body(
                        type,
                      ).copyWith(color: colors.textMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: spacing.md,
                        vertical: spacing.md,
                      ),
                    ),
                    onSubmitted: (_) => onAdd(),
                  ),
                ),
                _GenderToggle(value: gender, onChanged: onGender),
                SizedBox(width: spacing.sm),
              ],
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        Semantics(
          button: true,
          label: l10n.addPlayer,
          child: DeckPress(
            enabled: canAdd,
            child: SizedBox(
              width: DeckTokens.primaryHeight,
              height: DeckTokens.primaryHeight,
              child: OutlinedButton(
                key: AddPlayersScreen.addButton,
                onPressed: canAdd ? onAdd : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: colors.textPrimary,
                  side: const BorderSide(
                    color: DeckTokens.silverLight,
                    width: DeckTokens.rimBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.radii.button),
                  ),
                ),
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderToggle extends StatelessWidget {
  final PlayerGender value;
  final ValueChanged<PlayerGender> onChanged;

  const _GenderToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    Widget mark(PlayerGender g, String label, Key key) {
      final on = (value == PlayerGender.female) == (g == PlayerGender.female);
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(g),
          child: Container(
            width: SeatTokens.genderWidth,
            height: SeatTokens.genderHeight,
            alignment: Alignment.center,
            color: on ? colors.surfaceOverlay : IdentityTokens.transparent,
            child: Text(
              label,
              style: DeckTokens.meta(
                context.typography,
              ).copyWith(color: on ? colors.textPrimary : colors.textMuted),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(SeatTokens.genderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: DeckTokens.line),
          borderRadius: BorderRadius.circular(SeatTokens.genderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark(PlayerGender.male, l10n.playerMale, GenderPicker.maleKey),
            mark(
              PlayerGender.female,
              l10n.playerFemale,
              GenderPicker.femaleKey,
            ),
          ],
        ),
      ),
    );
  }
}

/// Slides its child to [offset] (transform only). While [instant] — a card
/// held under a finger — it follows without easing.
class _Glide extends StatefulWidget {
  final Offset offset;
  final bool instant;
  final Widget child;

  const _Glide({
    required this.offset,
    required this.instant,
    required this.child,
  });

  @override
  State<_Glide> createState() => _GlideState();
}

class _GlideState extends State<_Glide> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SeatTokens.slide,
    value: 1,
  );
  late Offset _from = widget.offset;
  late Offset _to = widget.offset;

  Offset get _now =>
      Offset.lerp(_from, _to, Curves.easeOutCubic.transform(_c.value))!;

  @override
  void didUpdateWidget(_Glide old) {
    super.didUpdateWidget(old);
    if (widget.offset == _to) return;
    if (widget.instant) {
      _from = _to = widget.offset;
      _c.value = 1;
    } else {
      _from = _now;
      _to = widget.offset;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(child: widget.child);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.translate(offset: _now, child: child),
      child: child,
    );
  }
}

/// A card dealt in: drops from above, turned and small, and settles.
class _Deal extends StatefulWidget {
  final int delay;
  final Widget child;
  const _Deal({required this.delay, required this.child});

  @override
  State<_Deal> createState() => _DealState();
}

class _DealState extends State<_Deal> with SingleTickerProviderStateMixin {
  late final int _beats = widget.delay.clamp(0, SeatTokens.dealStaggered);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SeatTokens.dealIn + SeatTokens.dealStagger * _beats,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      1 - SeatTokens.dealIn.inMicroseconds / _c.duration!.inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(child: widget.child);
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final k = 1 - _t.value;
        return Opacity(
          opacity: _t.value,
          child: Transform.translate(
            offset: Offset(0, -SeatTokens.dealRise * k),
            child: Transform.rotate(
              angle: -SeatTokens.dealTilt * k,
              child: Transform.scale(
                scale: 1 - (1 - SeatTokens.dealScale) * k,
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// A removed card flying out: down, turned, small, gone.
class _Flyout extends StatefulWidget {
  final VoidCallback onDone;
  final Widget child;
  const _Flyout({required this.onDone, required this.child});

  @override
  State<_Flyout> createState() => _FlyoutState();
}

class _FlyoutState extends State<_Flyout> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: SeatTokens.dealOut)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(child: widget.child);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: 1 - t,
          child: Transform.translate(
            offset: Offset(0, SeatTokens.outDrop * t),
            child: Transform.rotate(
              angle: SeatTokens.dealTilt * t,
              child: Transform.scale(
                scale: 1 - (1 - SeatTokens.dealScale) * t,
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// "Shall I remember these people?", asked once and never in the way.
///
/// An inline panel rather than a dialog, deliberately. The rule is that saving
/// must never block progress, and a modal blocks progress by definition — it
/// has to be answered before the host can reach the button they were going for.
/// This sits above that button and can simply be ignored.
class _SaveGroupPrompt extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  const _SaveGroupPrompt({required this.onSave, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    return MafiaPanel(
      key: AddPlayersScreen.saveGroupPrompt,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.saveGroupPrompt,
              style: type.bodySmall.copyWith(color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            key: AddPlayersScreen.saveGroupDismiss,
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
            ),
            child: Text(
              l10n.notNowAction,
              style: type.bodySmall.copyWith(color: colors.textMuted),
            ),
          ),
          TextButton(
            key: AddPlayersScreen.saveGroupAccept,
            onPressed: onSave,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
            ),
            child: Text(
              l10n.saveAction,
              style: type.bodySmall.copyWith(color: colors.accentGold),
            ),
          ),
        ],
      ),
    );
  }
}
