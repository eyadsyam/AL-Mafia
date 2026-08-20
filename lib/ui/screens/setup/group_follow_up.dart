import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player_group_provider.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import 'setup_draft.dart';

/// Asks, once, whether tonight's changes should be kept in the saved group.
///
/// ## Why this is at the end of the match rather than the start
///
/// Two questions only have answers once the match is over. "Should Karim join
/// the group?" is unanswerable before you know whether Karim is a regular or
/// someone's cousin who was passing through; "should this seating order stick?"
/// is unanswerable before anyone has actually sat in it. Asking either at setup
/// time would be asking the host to predict the evening, and would put a
/// decision in the one place this feature exists to remove decisions from.
///
/// ## Why it is a wrapper and not part of the result screen
///
/// The result screen is a post-game surface with its own tests, its own
/// role-colour usage, and its own place in the leakage story. Nothing about
/// saved groups belongs in it. This wraps it instead, renders its child
/// unchanged, and puts a dialog over the top after the frame — so removing the
/// feature is deleting one widget from one build method.
///
/// ## Leakage
///
/// Nothing here can leak. It runs only after [ResultScreen] has already made
/// every role public to the whole table, and the only data it handles is
/// names — which were never secret — and a roster order.
class GroupFollowUp extends ConsumerStatefulWidget {
  final Widget child;

  const GroupFollowUp({super.key, required this.child});

  @override
  ConsumerState<GroupFollowUp> createState() => _GroupFollowUpState();
}

class _GroupFollowUpState extends ConsumerState<GroupFollowUp> {
  @override
  void initState() {
    super.initState();
    // Post-frame: this runs over a screen that has to be on screen first, and
    // `showDialog` during build is an error.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    final draft = ref.read(setupDraftProvider);
    final group = draft.group;
    if (group == null || !group.isSaved) return;

    final guests = draft.guests;
    final orderChanged = draft.seatingOrderChanged;
    if (guests.isEmpty && !orderChanged) return;

    // Detach first, whatever the host answers. This question belongs to this
    // match; a rebuild of the result screen, or a second visit to it from
    // analytics, must not ask it again.
    ref.read(setupDraftProvider.notifier).setGroup(null);

    var roster = [...group.memberNames];
    var changed = false;

    if (guests.isNotEmpty) {
      final l10n = context.l10n;
      final accepted = await _confirm(
        title: l10n.addGuestsToGroupTitle,
        body: l10n.addGuestsToGroupBody(
          guests.join(l10n.listSeparator),
          group.name,
        ),
        confirmLabel: l10n.addAction,
      );
      if (!mounted) return;
      // Guests join at the end of the roster. Their seat *tonight* was a
      // one-off; where they sit as members is a question for the next match,
      // where the players screen can reorder them and offer to save it.
      if (accepted) {
        roster = [...roster, ...guests];
        changed = true;
      }
    }

    if (orderChanged) {
      final l10n = context.l10n;
      final accepted = await _confirm(
        title: l10n.saveGroupOrderTitle,
        body: l10n.saveGroupOrderBody(group.name),
        confirmLabel: l10n.saveAction,
      );
      if (!mounted) return;
      if (accepted) {
        roster = _reorder(roster, draft.playedMembers);
        changed = true;
      }
    }

    if (!changed) return;

    // Saving is an upsert, so a group deleted during the match would be
    // *recreated* by this write — the host would delete a roster, play the
    // night out, accept a prompt about it, and find it back in the list.
    //
    // Asked of the repository rather than of the cached provider state: a
    // cache that has not loaded yet is indistinguishable from an empty one,
    // and answering "deleted" to "don't know" would silently drop a legitimate
    // save. The database always knows.
    final live = await ref.read(playerGroupRepositoryProvider).listGroups();
    if (!live.any((g) => g.id == group.id)) return;

    await ref
        .read(playerGroupsProvider.notifier)
        .save(group.copyWith(memberNames: roster));
  }

  /// Rewrites [members] so the ones who played sit in [played]'s order, while
  /// anyone absent keeps the slot they already had.
  ///
  /// The alternative — replacing the roster with tonight's order outright —
  /// would drop every absent member, which is precisely the loss the attendance
  /// toggle exists to prevent. Absent players are not reordered because nobody
  /// observed where they would have sat.
  static List<String> _reorder(List<String> members, List<String> played) {
    final queue = [...played];
    return [
      for (final member in members)
        if (played.contains(member) && queue.isNotEmpty)
          queue.removeAt(0)
        else
          member,
    ];
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final colors = context.colors;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.dialog),
        ),
        title: Text(
          title,
          style: type.title.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          body,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            key: const ValueKey('group_follow_up_dismiss'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.notNowAction,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
          ),
          TextButton(
            key: const ValueKey('group_follow_up_accept'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: type.body.copyWith(color: colors.accentGold),
            ),
          ),
        ],
      ),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
