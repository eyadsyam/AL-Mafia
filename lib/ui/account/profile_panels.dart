import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/online_match_history.dart';
import '../../data/player_profile.dart';
import '../../data/repository_provider.dart';
import '../../engine/models/player.dart' show PlayerGender;
import '../../transport/account_auth.dart';
import '../economy/cosmetic_paint.dart';
import '../economy/my_cosmetics.dart';
import '../economy/wallet.dart';
import '../l10n_ext.dart';
import '../social/titles_partner.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/deck/deck_buttons.dart' show DeckPress;
import '../widgets/deck/deck_paper.dart';
import '../widgets/deck/seat_card.dart';
import '../widgets/player_avatar.dart';
import 'account_sheet.dart';
import 'onboarding_account_step.dart' show accountsAvailableProvider;

/// One line of the profile's list: a title (with a count badge when something
/// waits), what is behind it in a few words, and the chevron. Opens a sheet.
class ProfileRow extends StatelessWidget {
  final String title;
  final String? meta;

  /// A count of what waits (friend requests). Zero draws no badge.
  final int badge;
  final VoidCallback? onTap;

  const ProfileRow({
    super.key,
    required this.title,
    this.meta,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return InkWell(
      onTap: onTap,
      highlightColor: colors.surfaceOverlay,
      splashColor: IdentityTokens.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: DeckTokens.rowOne),
        // The deck's press: the row's content sinks a little under a finger.
        child: DeckPress(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DeckTokens.body(type).copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badge > 0) ...[
                  SizedBox(width: s.xs),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: s.sm),
                    decoration: const ShapeDecoration(
                      color: DeckTokens.bone,
                      shape: StadiumBorder(),
                    ),
                    child: Text(
                      '$badge',
                      textDirection: TextDirection.ltr,
                      style: type.caption.copyWith(
                        color: DeckTokens.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                SizedBox(width: s.sm),
                Expanded(
                  child: Text(
                    meta ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: type.caption.copyWith(color: colors.textMuted),
                  ),
                ),
                SizedBox(width: s.xs),
                Icon(
                  rtl ? Icons.chevron_left : Icons.chevron_right,
                  size: DeckTokens.chevron,
                  color: DeckTokens.silver,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The rows as one raised panel with hairlines between them.
class ProfileRowList extends StatelessWidget {
  final List<Widget> rows;
  const ProfileRowList({super.key, required this.rows});

  static const listKey = ValueKey('profile_rows');

  @override
  Widget build(BuildContext context) {
    return DeckPanel(
      key: listKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DeckTokens.panelRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.colors.borderSubtle),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Who you are on this device: a guest (with the way to keep it) or an
/// account (with the way to manage it). Opens the account sheet either way.
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  static const cardKey = ValueKey('profile_account_card');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(accountsAvailableProvider)) return const SizedBox.shrink();
    final profile =
        ref.watch(accountProfileProvider).valueOrNull ?? AccountProfile.guest;
    final l = context.l10n;
    return ProfileRow(
      key: cardKey,
      title: l.authAccount,
      meta: !profile.signedIn
          ? l.authGuestBadge
          : (profile.google ? l.profileAccountGoogle : l.profileAccountEmail),
      onTap: () => showAccountSheet(context),
    );
  }
}

/// The identity block: the avatar on a small card, the name as the table
/// shows it, and what to tap to change it.
class ProfileIdentityHeader extends ConsumerWidget {
  final VoidCallback onEdit;
  const ProfileIdentityHeader({super.key, required this.onEdit});

  static const headerKey = ValueKey('profile_identity');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(playerProfileProvider).valueOrNull;
    final mine = ref.watch(myCosmeticsProvider);
    // Read only once something already asked for the hub (the titles row).
    final title = ref.exists(titleHubProvider)
        ? ref.watch(titleHubProvider).valueOrNull?.equippedTitle
        : null;
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final name = saved?.name ?? '';
    final gender = saved?.gender ?? PlayerGender.unspecified;
    final hint = title == null
        ? l.profileEditHint
        : l.profileEditHintTitled(title.name(Localizations.localeOf(context)));
    return Semantics(
      button: true,
      label: '$name. $hint',
      excludeSemantics: true,
      child: InkWell(
        key: headerKey,
        onTap: onEdit,
        borderRadius: BorderRadius.circular(DeckTokens.panelRadius),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: s.xs),
          child: Row(
            children: [
              SizedBox.fromSize(
                size: ProfileTokens.identityPhoto,
                child: SeatCardFrame(
                  child: Center(
                    child: CosmeticFrameRing(
                      frame: mine.frame,
                      diameter: ProfileTokens.identityAvatar,
                      child: PlayerAvatar(
                        name: name,
                        gender: gender,
                        diameter: ProfileTokens.identityAvatar,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: s.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CosmeticNameplate(
                      name: name,
                      plate: mine.plate,
                      style: type.title.copyWith(color: colors.textPrimary),
                    ),
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_outlined,
                size: DeckTokens.icon,
                color: DeckTokens.silverLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A player's record at a glance, from what this device knows: matches on
/// one phone and matches online.
final profileStatsProvider = FutureProvider<(int, int)>((ref) async {
  var local = 0;
  var online = 0;
  try {
    local = (await ref.read(matchRepositoryProvider).listHistory()).length;
  } catch (_) {}
  try {
    online = (await OnlineMatchHistory.load()).length;
  } catch (_) {}
  return (local, online);
});

/// When the last match on this phone was played, or null for none.
final profileLastMatchProvider = FutureProvider<DateTime?>((ref) async {
  try {
    final all = await ref.read(matchRepositoryProvider).listHistory();
    DateTime? last;
    for (final m in all) {
      if (last == null || m.createdAt.isAfter(last)) last = m.createdAt;
    }
    return last;
  } catch (_) {
    return null;
  }
});

/// «النهاردة» is whatever this says; a test replaces it.
final profileClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The history row's few words: how long ago the last match on this phone was.
String lastMatchLine(BuildContext context, DateTime? last, DateTime now) {
  final l = context.l10n;
  if (last == null) return l.profileNoMatches;
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(last.year, last.month, last.day)).inDays;
  if (days <= 0) return l.profileLastMatchToday;
  if (days == 1) return l.profileLastMatchYesterday;
  return l.profileLastMatchDays(days);
}

/// Three real numbers: matches on this phone, matches online, coins.
class ProfileStats extends ConsumerWidget {
  const ProfileStats({super.key});

  static const statsKey = ValueKey('profile_stats');
  static const hereKey = ValueKey('profile_stat_here');
  static const onlineKey = ValueKey('profile_stat_online');
  static const coinsKey = ValueKey('profile_stat_coins');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final counts = ref.watch(profileStatsProvider).valueOrNull ?? (0, 0);
    final wallet = ref.watch(walletProvider).valueOrNull;
    final s = context.spacing;
    // The three tiles are as tall as the tallest, whatever their label does.
    return IntrinsicHeight(
      key: statsKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stat(key: hereKey, value: '${counts.$1}', label: l.profileStatHere),
          SizedBox(width: s.sm),
          _Stat(
            key: onlineKey,
            value: '${counts.$2}',
            label: l.profileStatOnlineMatches,
          ),
          SizedBox(width: s.sm),
          _Stat(
            key: coinsKey,
            value: wallet == null ? '—' : '${wallet.balance}',
            label: l.profileStatCoins,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    return Expanded(
      child: DeckPanel(
        radius: DeckTokens.statRadius,
        padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: s.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.title.copyWith(color: colors.textPrimary),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.caption.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
