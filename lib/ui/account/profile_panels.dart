import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/character_bonds.dart';
import '../../data/online_match_history.dart';
import '../../data/repository_provider.dart';
import '../../engine/models/enums.dart' show Role;
import '../../transport/account_auth.dart';
import '../economy/council_art.dart' show RasterOr;
import '../l10n_ext.dart';
import 'onboarding_account_step.dart' show accountsAvailableProvider;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/feathered_art.dart';
import 'account_sheet.dart';

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
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final guest = !profile.signedIn;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.sm),
      child: Material(
        color: colors.surfaceRaised.withValues(
          alpha: UiPolishTokens.caseSurfaceOpacity,
        ),
        borderRadius: BorderRadius.circular(context.radii.card),
        child: InkWell(
          key: cardKey,
          borderRadius: BorderRadius.circular(context.radii.card),
          onTap: () => showAccountSheet(context),
          child: Container(
            padding: EdgeInsets.all(s.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radii.card),
              border: Border.all(
                color: guest ? colors.accentGold : colors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  guest ? Icons.shield_outlined : Icons.verified_user_rounded,
                  color: colors.accentGold,
                ),
                SizedBox(width: s.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guest ? l.authGuestTitle : l.authAccount,
                        style: type.body.emphasised.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        guest ? l.authGuestBadge : (profile.email ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  guest ? l.authCreate : l.authManage,
                  style: type.caption.copyWith(color: colors.accentGold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A player's record at a glance, from what this device knows: matches on
/// one phone, matches online, and the characters' letters opened.
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

class ProfileStats extends ConsumerWidget {
  const ProfileStats({super.key});

  static const statsKey = ValueKey('profile_stats');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final counts = ref.watch(profileStatsProvider).valueOrNull ?? (0, 0);
    final ledger = ref.watch(characterBondLedgerProvider).valueOrNull;
    final letters = ledger == null
        ? 0
        : Role.values.fold<int>(0, (sum, r) => sum + ledger.bond(r).tier);
    return Padding(
      key: statsKey,
      padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
      child: Row(
        children: [
          _Stat(
            art: 'assets/images/profile/stat_matches.webp',
            value: '${counts.$1 + counts.$2}',
            label: l.profileStatMatches,
          ),
          _Stat(
            art: 'assets/images/profile/stat_wins.webp',
            value: '${counts.$2}',
            label: l.profileStatOnline,
          ),
          _Stat(
            art: 'assets/images/profile/stat_streak.webp',
            value: '$letters/${Role.values.length * bondTierThresholds.length}',
            label: l.profileStatLetters,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String art;
  final String value;
  final String label;
  const _Stat({required this.art, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    return Expanded(
      child: Column(
        children: [
          SizedBox.square(
            dimension: ProfileTokens.statArt,
            child: FeatheredArt(
              feather: Feather.portrait,
              child: RasterOr(
                path: art,
                width: ProfileTokens.statArt,
                height: ProfileTokens.statArt,
                fallback: const SizedBox.shrink(),
              ),
            ),
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: type.title.copyWith(color: colors.textPrimary),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: type.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
