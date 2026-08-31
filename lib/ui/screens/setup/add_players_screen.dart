import 'package:flutter/material.dart';
import '../../../data/player_group.dart';
import '../../../engine/balance_guard.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/textured_surface.dart';

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
    this.group,
    this.savedGroups = const [],
    this.onQuickStart,
    this.onSaveGroup,
  });

  static const Key quickStartButton = ValueKey('players_quick_start');
  static const Key nextButton = ValueKey('players_next');
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

  /// Members sitting tonight out. Held by name rather than by index so a
  /// reorder cannot silently mark the wrong person away.
  final Set<String> _absent = {};

  final TextEditingController _inputController = TextEditingController();

  /// The save-group prompt is offered once. Dismissing or accepting it retires
  /// it for this visit — it is a suggestion, not a demand.
  bool _savePromptClosed = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  bool get _groupMode => widget.group != null;

  bool _isMember(String name) =>
      widget.group?.memberNames.contains(name) ?? false;

  /// Seating order, present players only. This is what starts a match.
  List<String> get _present =>
      [for (final name in _players) if (!_absent.contains(name)) name];

  /// Adds a player name, auto-suffixing duplicates.
  void _addPlayer() {
    final name = _inputController.text.trim();
    if (name.isEmpty) return;

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
    });
  }

  void _removePlayer(int index) {
    setState(() {
      final removed = _players.removeAt(index);
      _absent.remove(removed);
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

  bool get _canNext => _present.length >= 5;

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
    final counts = widget.group?.lastRoleCounts;
    if (counts == null) return false;

    final present = _present.length;
    if (counts.values.fold(0, (a, b) => a + b) != present) return false;

    return BalanceGuard.evaluate(playerCount: present, roleCounts: counts)
        .valid;
  }

  /// Whether to offer to remember this roster.
  ///
  /// Suppressed in group mode (already saved), below the minimum table size
  /// (not yet a roster), once closed, and — the one that matters — when some
  /// saved group already has these same people.
  bool get _showSavePrompt {
    if (widget.onSaveGroup == null) return false;
    if (_groupMode || _savePromptClosed) return false;
    if (_present.length < 5) return false;
    final present = _present;
    return !widget.savedGroups.any((g) => g.hasSameMembers(present));
  }

  void _onNext() => widget.onNext(_present);

  void _onQuickStart() => widget.onQuickStart!(_present);

  void _onSaveGroup() {
    setState(() => _savePromptClosed = true);
    widget.onSaveGroup!(_present);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    final canNext = _canNext;
    final canQuickStart = _canQuickStart;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
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
                    ScreenHeader(
                      title: widget.group?.name ?? l10n.addPlayersTitle,
                      onBack: widget.onBack,
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      _groupMode
                          ? l10n.attendanceHint
                          : l10n.seatingOrderSubtitle,
                      style: type.body.copyWith(color: colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.lg),

                    // Input row: text field + add button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            style: type.body.copyWith(
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.playerNameHint,
                              hintStyle: type.body.copyWith(
                                color: colors.textMuted,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: spacing.md,
                                vertical: spacing.sm,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  radii.button,
                                ),
                                borderSide: BorderSide(
                                  color: colors.borderSubtle,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  radii.button,
                                ),
                                borderSide: BorderSide(
                                  color: colors.borderSubtle,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  radii.button,
                                ),
                                borderSide: BorderSide(
                                  color: colors.accentGold,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _addPlayer(),
                          ),
                        ),
                        SizedBox(width: spacing.sm),
                        FilledButton(
                          onPressed: _addPlayer,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.accentGold,
                            foregroundColor: colors.surfaceBase,
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.lg,
                              vertical: spacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radii.button),
                            ),
                          ),
                          child: Text(
                            l10n.addPlayer,
                            style: type.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.lg),

                    // Player count. In group mode this counts who is actually
                    // playing, not who is on the roster — the second number is
                    // the one that has to match the role distribution.
                    Text(
                      _groupMode
                          ? l10n.playingTonight(_present.length)
                          : l10n.playerCountLine(_players.length),
                      style: type.body.copyWith(color: colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.md),

                    // Reorderable list of players
                    Expanded(
                      child: _players.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noPlayersYet,
                                style: type.body.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            )
                          : ReorderableListView.builder(
                              buildDefaultDragHandles: true,
                              onReorderItem: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex -= 1;
                                final player = _players.removeAt(oldIndex);
                                _players.insert(newIndex, player);
                                setState(() {});
                              },
                              itemCount: _players.length,
                              itemBuilder: (context, index) {
                                final name = _players[index];
                                final absent = _absent.contains(name);
                                return _PlayerTile(
                                  key: ValueKey(name + index.toString()),
                                  index: index + 1, // 1-based seating
                                  name: name,
                                  absent: absent,
                                  // A saved member is toggled, never deleted.
                                  // A guest added just for tonight was never in
                                  // the group, so there is nothing to protect
                                  // and delete is the honest control.
                                  onToggleAttendance:
                                      _groupMode && _isMember(name)
                                          ? () => _toggleAttendance(name)
                                          : null,
                                  onDelete: () => _removePlayer(index),
                                );
                              },
                            ),
                    ),
                    SizedBox(height: spacing.md),

                    if (_showSavePrompt) ...[
                      _SaveGroupPrompt(
                        onSave: _onSaveGroup,
                        onDismiss: () =>
                            setState(() => _savePromptClosed = true),
                      ),
                      SizedBox(height: spacing.md),
                    ],

                    // Quick start, when the group's saved configuration still
                    // fits. This is the third and last tap of a rematch.
                    if (canQuickStart) ...[
                      FilledButton(
                        key: AddPlayersScreen.quickStartButton,
                        onPressed: _onQuickStart,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accentGold,
                          foregroundColor: colors.surfaceBase,
                          padding: EdgeInsets.symmetric(vertical: spacing.lg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radii.button),
                          ),
                        ),
                        child: Text(l10n.quickStartAction, style: type.title),
                      ),
                      SizedBox(height: spacing.sm),
                    ],

                    // Next button. Demoted to an outline when quick start is
                    // present, so the two full-weight buttons do not compete
                    // for the same glance.
                    canQuickStart
                        ? OutlinedButton(
                            key: AddPlayersScreen.nextButton,
                            onPressed: canNext ? _onNext : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.textSecondary,
                              disabledForegroundColor: colors.textMuted,
                              side: BorderSide(color: colors.borderSubtle),
                              padding:
                                  EdgeInsets.symmetric(vertical: spacing.md),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(radii.button),
                              ),
                            ),
                            child: Text(l10n.next, style: type.body),
                          )
                        : FilledButton(
                            key: AddPlayersScreen.nextButton,
                            onPressed: canNext ? _onNext : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.accentGold,
                              foregroundColor: colors.surfaceBase,
                              disabledBackgroundColor: colors.surfaceOverlay,
                              disabledForegroundColor: colors.textMuted,
                              padding:
                                  EdgeInsets.symmetric(vertical: spacing.lg),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(radii.button),
                              ),
                            ),
                            child: Text(l10n.next, style: type.title),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    return Container(
      key: AddPlayersScreen.saveGroupPrompt,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radii.card),
        border: Border.all(color: colors.borderSubtle),
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

/// A single player tile in the reorderable list.
class _PlayerTile extends StatelessWidget {
  final int index; // 1-based seating order
  final String name;

  /// Away tonight. Dimmed, still listed, still in the group.
  final bool absent;

  /// Non-null for saved members: the row offers attendance instead of deletion.
  final VoidCallback? onToggleAttendance;

  final VoidCallback onDelete;

  const _PlayerTile({
    super.key,
    required this.index,
    required this.name,
    required this.absent,
    required this.onToggleAttendance,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Container(
        height: spacing.xxl + spacing.md,
        decoration: BoxDecoration(
          // Dimming an absent row is done by dropping it to the ground colour
          // rather than by lowering opacity: `Opacity` forces an offscreen
          // buffer, and this list rebuilds on every toggle and every drag.
          color: absent ? colors.surfaceBase : colors.surfaceRaised,
          borderRadius: BorderRadius.circular(radii.card),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            // Drag handle (built-in by ReorderableListView)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md),
              // Three rules, not `Icons.drag_handle`. A drag affordance has to
              // read as "grab here" and nothing else, and the app does not
              // borrow glyphs — see the note on `BackAction`.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(height: 3),
                    SizedBox(
                      width: 16,
                      height: 1.5,
                      child: ColoredBox(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),

            // Seat number and name
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: type.body.emphasised.copyWith(
                      color: absent ? colors.textMuted : colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    context.l10n.seatNumber(index),
                    style: type.caption.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),

            // Attendance toggle for saved members; delete for everyone else.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.md),
              child: onToggleAttendance != null
                  ? TextButton(
                      key: AddPlayersScreen.attendanceToggleFor(index),
                      onPressed: onToggleAttendance,
                      style: TextButton.styleFrom(
                        // Article VII's 48dp floor.
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                      ),
                      child: Text(
                        absent
                            ? context.l10n.absentAction
                            : context.l10n.presentAction,
                        style: type.bodySmall.copyWith(
                          color: absent
                              ? colors.textMuted
                              : colors.textSecondary,
                        ),
                      ),
                    )
                  : TextButton(
                      key: ValueKey('delete_player_$index'),
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        // Article VII's 48dp floor.
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                      ),
                      child: Text(context.l10n.deleteAction,
                          style: type.bodySmall.copyWith(
                            color: colors.textMuted,
                          )),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
