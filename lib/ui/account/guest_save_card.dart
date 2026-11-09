import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../transport/account_auth.dart' show AccountProfile;
import '../../transport/account_service.dart' show AccountFailure;
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/deck/deck_buttons.dart';
import 'account_sheet.dart'
    show
        AccountStep,
        accountAuthProvider,
        accountProfileProvider,
        showAccountSheet;
import 'embedded_browser_sheet.dart' show sentToRealBrowser;
import 'onboarding_account_step.dart' show accountsAvailableProvider;

/// The same Google path the first-run screen takes. True when it failed.
Future<bool> signInWithGoogle(BuildContext context, WidgetRef ref) async {
  if (await sentToRealBrowser(context, ref)) return false;
  try {
    await ref.read(accountAuthProvider).google();
    return false;
  } on AccountFailure {
    return true;
  }
}

/// Device-side memory of the «احفظ اسمك وفلوسك» card: how many matches have
/// finished here, when the player last closed the card, and whether they ever
/// signed in (then it never returns).
abstract final class GuestNudge {
  static const finishedKey = 'mafia.guestCard.finished.v1';
  static const closedAtKey = 'mafia.guestCard.closedAt.v1';
  static const doneKey = 'mafia.guestCard.done.v1';

  /// A match finished on this device (pass-and-play or online).
  static Future<void> matchFinished() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(finishedKey, (prefs.getInt(finishedKey) ?? 0) + 1);
    } catch (_) {
      // The card may come back a match late; nothing else depends on it.
    }
  }

  static Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(doneKey) == true) return false;
      final closedAt = prefs.getInt(closedAtKey);
      if (closedAt == null) return true;
      return (prefs.getInt(finishedKey) ?? 0) - closedAt >=
          HomeTokens.guestCardReturnAfter;
    } catch (_) {
      return true;
    }
  }

  static Future<void> close() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(closedAtKey, prefs.getInt(finishedKey) ?? 0);
    } catch (_) {
      // Shown again next visit.
    }
  }

  static Future<void> signedIn() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(doneKey, true);
    } catch (_) {
      // Hidden anyway while signed in.
    }
  }
}

/// Whether Home should speak to a guest: this build has accounts and the
/// player is not signed in to one.
bool _isGuest(WidgetRef ref) {
  if (!ref.watch(accountsAvailableProvider)) return false;
  final profile =
      ref.watch(accountProfileProvider).valueOrNull ?? AccountProfile.guest;
  return !profile.signedIn;
}

/// «ضيف — مش متسجل» under the player's row on Home, for guests only.
class GuestStatusLine extends ConsumerWidget {
  const GuestStatusLine({super.key});

  static const lineKey = ValueKey('home_guest_status');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isGuest(ref)) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.xs),
      child: Text(
        context.l10n.guestStatusLine,
        key: lineKey,
        style: context.typography.caption.copyWith(
          color: context.colors.textMuted,
        ),
      ),
    );
  }
}

/// «احفظ اسمك وفلوسك»: the top card of Home for a player who is not signed in.
///
/// Closing hides it until three more matches have finished; signing in removes
/// it for good. A build without accounts never shows it.
class GuestSaveCard extends ConsumerStatefulWidget {
  const GuestSaveCard({super.key});

  static const cardKey = ValueKey('home_guest_card');
  static const googleKey = ValueKey('home_guest_google');
  static const emailKey = ValueKey('home_guest_email');
  static const closeKey = ValueKey('home_guest_close');

  @override
  ConsumerState<GuestSaveCard> createState() => _GuestSaveCardState();
}

class _GuestSaveCardState extends ConsumerState<GuestSaveCard> {
  bool _show = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    GuestNudge.shouldShow().then((value) {
      if (mounted) setState(() => _show = value);
    });
  }

  Future<void> _close() async {
    setState(() => _show = false);
    await GuestNudge.close();
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await signInWithGoogle(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(accountsAvailableProvider) &&
        (ref.watch(accountProfileProvider).valueOrNull?.signedIn ?? false)) {
      GuestNudge.signedIn();
    }
    if (!_show || !_isGuest(ref)) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final compact =
        MediaQuery.sizeOf(context).height < HomeTokens.guestCardCompactBelow;
    final google = BoneButton(
      key: GuestSaveCard.googleKey,
      label: l.accountSaveGoogle,
      onPressed: _busy ? null : _google,
    );
    final email = TextButton(
      key: GuestSaveCard.emailKey,
      onPressed: () => showAccountSheet(context, initial: AccountStep.signUp),
      child: Text(l.accountSaveEmail),
    );
    return Padding(
      padding: EdgeInsets.only(top: s.xs),
      child: DecoratedBox(
        key: GuestSaveCard.cardKey,
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border.all(color: colors.borderSubtle),
          borderRadius: BorderRadius.circular(context.radii.card),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(s.sm, s.xs, s.xs, s.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.guestCardTitle,
                      style: type.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  IconButton(
                    key: GuestSaveCard.closeKey,
                    tooltip: l.guestCardClose,
                    onPressed: _close,
                    iconSize: HomeTokens.ribbonIcon,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (!compact)
                Padding(
                  padding: EdgeInsetsDirectional.only(end: s.sm, bottom: s.sm),
                  child: Text(
                    l.guestCardLine,
                    style: type.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
              if (compact)
                Row(
                  children: [
                    Expanded(child: google),
                    SizedBox(width: s.xs),
                    email,
                  ],
                )
              else ...[
                Padding(
                  padding: EdgeInsetsDirectional.only(end: s.xs),
                  child: google,
                ),
                email,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
