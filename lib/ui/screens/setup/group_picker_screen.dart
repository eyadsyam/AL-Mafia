import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player_group.dart';
import '../../../data/player_group_provider.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/textured_surface.dart';
import 'setup_draft.dart';

/// Group picker (S-02a) — the first screen of a rematch.
///
/// ## What this screen is for
///
/// Everything about it serves one number: a rematch with a known group has to
/// reach role distribution in **three taps from launch**. Tap one is "مباراة
/// جديدة" on Home, tap two is a row here, tap three is "ابدأ فوراً" on the
/// pre-filled players screen. Anything that adds a fourth tap to that path —
/// a confirmation, an intermediate menu, a "which group?" step — defeats the
/// feature, because the friction it removes is measured in seconds at the
/// moment nobody has any.
///
/// ## Why there is no empty state
///
/// There is none because this screen is never reached without groups. The Home
/// route decides, synchronously, from the already-loaded group list: no groups
/// means straight to the empty players screen, exactly as the app behaved
/// before this feature existed. A first-run host must not meet an empty list
/// asking them to pick from nothing. The redirect in [build] is the belt to
/// that braces — it covers deleting the last group while standing here.
///
/// ## Leakage
///
/// Clean, and structurally so. Nothing has been dealt, nobody is holding
/// anything private, and every string on this screen is a name the whole table
/// said out loud while sitting down. The one rule worth keeping is that the
/// counts stay *group*-level: "played 12 times" is safe, "Ahmed was mafia 4
/// times" would be a tell that survives between evenings, and no such number is
/// stored to display (see [PlayerGroup]).
class GroupPickerScreen extends ConsumerWidget {
  /// Selecting a group — straight to the pre-filled players screen.
  final void Function(PlayerGroup group) onSelect;

  /// "مجموعة جديدة" — the empty players screen, the old behaviour.
  final VoidCallback onNewGroup;

  final VoidCallback onBack;

  /// Called when the last group is deleted, so the route can fall back to the
  /// empty players screen rather than leave the host on a list of nothing.
  final VoidCallback onEmpty;

  const GroupPickerScreen({
    super.key,
    required this.onSelect,
    required this.onNewGroup,
    required this.onBack,
    required this.onEmpty,
  });

  static const Key list = ValueKey('group_picker_list');
  static const Key newGroupButton = ValueKey('group_picker_new');

  static Key tileFor(int groupId) => ValueKey('group_tile_$groupId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    final groups = ref.watch(playerGroupsProvider).valueOrNull;

    // Still loading, or emptied out from under us. Either way there is nothing
    // to choose between, and an empty picker is the one state this screen must
    // never show.
    if (groups != null && groups.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onEmpty());
    }

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
                    ScreenHeader(title: l10n.groupsTitle, onBack: onBack),
                    SizedBox(height: spacing.lg),
                    Expanded(
                      child: groups == null || groups.isEmpty
                          ? const SizedBox.shrink()
                          : ListView.separated(
                              key: list,
                              itemCount: groups.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: spacing.sm),
                              itemBuilder: (context, index) => _GroupTile(
                                group: groups[index],
                                onTap: () => onSelect(groups[index]),
                                onLongPress: () =>
                                    _showActions(context, ref, groups[index]),
                              ),
                            ),
                    ),
                    SizedBox(height: spacing.md),

                    // Primary action, bottom third. A host with a new set of
                    // people must not have to hunt for the way past a list of
                    // people who are not here.
                    FilledButton(
                      key: newGroupButton,
                      onPressed: onNewGroup,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentGold,
                        foregroundColor: colors.surfaceBase,
                        padding: EdgeInsets.symmetric(vertical: spacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(l10n.newGroupAction, style: type.title),
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

  /// Long-press menu. Words, not glyphs — the icon exception this app grants
  /// covers navigation chrome, and neither renaming nor deleting is navigation.
  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    PlayerGroup group,
  ) async {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    final action = await showDialog<_GroupAction>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.dialog),
        ),
        title: Text(
          group.name,
          style: type.title.copyWith(color: colors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          SimpleDialogOption(
            key: const ValueKey('group_action_rename'),
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_GroupAction.rename),
            child: Text(
              l10n.renameAction,
              style: type.body.copyWith(color: colors.textPrimary),
            ),
          ),
          SimpleDialogOption(
            key: const ValueKey('group_action_delete'),
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_GroupAction.delete),
            child: Text(
              l10n.deleteAction,
              style: type.body.copyWith(color: colors.accentCrimson),
            ),
          ),
        ],
      ),
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _GroupAction.rename:
        final name = await promptForGroupName(
          context,
          title: l10n.renameGroupTitle,
          initial: group.name,
        );
        if (name == null) return;
        await ref.read(playerGroupsProvider.notifier).rename(group, name);
      case _GroupAction.delete:
        final confirmed = await _confirmDelete(context, group);
        if (!confirmed) return;
        // Detach before deleting if this is the group the host had already
        // selected — reached by picking it, going back, and deleting it. A
        // draft pointing at a deleted row would carry the dead group into the
        // roster screen and, at match end, write it back.
        if (ref.read(setupDraftProvider).group?.id == group.id) {
          ref.read(setupDraftProvider.notifier).setGroup(null);
        }
        await ref.read(playerGroupsProvider.notifier).delete(group.id);
    }
  }

  /// Deleting a group throws away a roster that took a minute to type and is
  /// the whole reason this feature exists, so it always asks first.
  Future<bool> _confirmDelete(BuildContext context, PlayerGroup group) async {
    final colors = context.colors;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.dialog),
        ),
        title: Text(
          l10n.deleteGroupTitle,
          style: type.title.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          l10n.deleteGroupBody,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            key: const ValueKey('group_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancel,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
          ),
          TextButton(
            key: const ValueKey('group_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.deleteAction,
              style: type.body.copyWith(color: colors.accentCrimson),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

enum _GroupAction { rename, delete }

/// One saved group.
///
/// Deliberately the same visual language as the player tiles on the roster
/// screen — `surfaceRaised`, the card radius, a hairline border, a title line
/// and a muted meta line. A group *is* a roster; inventing a second card style
/// for it would make the two screens look like they came from different apps.
class _GroupTile extends StatelessWidget {
  final PlayerGroup group;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GroupTile({
    required this.group,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: GroupPickerScreen.tileFor(group.id),
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(radii.card),
        child: Container(
          // Not a fixed height: the two lines plus generous padding is what
          // sets it, so a long Arabic name wraps to the ellipsis rather than
          // being clipped by a hard box.
          constraints: BoxConstraints(minHeight: spacing.xxl + spacing.md),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(radii.card),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: type.body.copyWith(color: colors.textPrimary),
                // Text scaling is pinned at 1.0 app-wide, so one line plus an
                // ellipsis is a bound that actually holds rather than a hope.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: spacing.xs),
              Text(
                group.playCount == 0
                    ? l10n.groupMetaNeverPlayed(group.memberCount)
                    : l10n.groupMeta(group.memberCount, group.playCount),
                style: type.caption.copyWith(color: colors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One text field and two words: the whole naming interaction.
///
/// Shared by "save these as a group" and "rename", because they are the same
/// question asked at two moments and a second dialog would be a second place
/// for the default-name logic to drift.
///
/// Returns null if the host backed out, and never returns an empty string — a
/// group with a blank name is unpickable in a list.
Future<String?> promptForGroupName(
  BuildContext context, {
  required String title,
  required String initial,
}) =>
    showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _GroupNameDialog(title: title, initial: initial),
    );

/// The naming dialog, stateful so that it owns its [TextEditingController].
///
/// This is not incidental. `showDialog`'s future completes the moment `pop` is
/// called, while the dialog is still animating *out* — so disposing the
/// controller alongside that future kills it mid-transition and the exiting
/// `TextField` rebuilds against a dead controller ("A TextEditingController was
/// used after being disposed"). Letting the dialog's own `State` hold it ties
/// the lifetime to the widget rather than to the future, which is the only
/// place that knows when the animation is actually finished.
class _GroupNameDialog extends StatefulWidget {
  final String title;
  final String initial;

  const _GroupNameDialog({required this.title, required this.initial});

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  )..selection = TextSelection(
      // Pre-selected, so the single most likely action — replacing the
      // suggested name outright — is one keystroke rather than a hold-and-
      // delete on a phone at a dim table.
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A blank name is refused silently rather than with an error: the field is
  /// visibly empty, so the only thing an error message would add is a second
  /// thing to dismiss.
  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    return AlertDialog(
      backgroundColor: colors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.dialog),
      ),
      title: Text(
        widget.title,
        style: type.title.copyWith(color: colors.textPrimary),
      ),
      content: TextField(
        key: const ValueKey('group_name_field'),
        controller: _controller,
        autofocus: true,
        style: type.body.copyWith(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: l10n.groupNameHint,
          hintStyle: type.body.copyWith(color: colors.textMuted),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.borderSubtle),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.accentGold),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          key: const ValueKey('group_name_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.cancel,
            style: type.body.copyWith(color: colors.textSecondary),
          ),
        ),
        TextButton(
          key: const ValueKey('group_name_confirm'),
          onPressed: _submit,
          child: Text(
            l10n.saveAction,
            style: type.body.copyWith(color: colors.accentGold),
          ),
        ),
      ],
    );
  }
}
