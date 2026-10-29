import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart' show Routes;
import '../../app/update_gate.dart' show BannerMode, bannerModeProvider;
import '../../platform/monetization/ad_formats.dart';
import '../fun/loaded_capabilities.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import 'waiting_banner.dart';

/// Whether the shell band may be on screen at [path]: the waiting surfaces
/// and nothing else.
///
/// An allowlist of the menu paths, so every other route (a match, offline or
/// online, every pass-the-phone screen, setup, the analytics) has no band by
/// default. The set never looks at who is playing or what role they hold, so
/// the band cannot differ by seat (doc 05).
bool shellBannerRoute(String path) {
  final clean = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return _shellRoutes.contains(clean) || clean.startsWith('/join/');
}

const _shellRoutes = {
  Routes.home,
  Routes.profile,
  Routes.characters,
  Routes.mode,
  Routes.stories,
  Routes.online,
  Routes.lobby,
  Routes.history,
};

/// WP4, `banner_mode = shell`: the one banner of the app, above the router.
///
/// Lays out `Column[Expanded(router), band]`, so a bottom sheet or a dialog
/// opens over the router's area and above the band, and the ad never covers
/// content. The band is there on a waiting surface and gone on every other
/// route and while the keyboard is open; hiding it does not unmount the
/// host's ad owner, so the ad loads once for the session.
///
/// Outside shell mode (and on the web) this is a pass-through column with no
/// band, so a change of mode never rebuilds the app underneath.
class ShellBannerHost extends ConsumerStatefulWidget {
  final Widget child;

  /// The router's current path and a notifier of its changes (like
  /// `UpdateGate`). Without a path there is never a band.
  final String Function()? currentPath;
  final Listenable? routeChanges;

  const ShellBannerHost({
    super.key,
    required this.child,
    this.currentPath,
    this.routeChanges,
  });

  static const bandKey = ValueKey('shell_banner_band');
  static const bodyKey = ValueKey('shell_banner_body');

  @override
  ConsumerState<ShellBannerHost> createState() => _ShellBannerHostState();
}

class _ShellBannerHostState extends ConsumerState<ShellBannerHost> {
  @override
  void initState() {
    super.initState();
    widget.routeChanges?.addListener(_routeChanged);
  }

  @override
  void didUpdateWidget(ShellBannerHost old) {
    super.didUpdateWidget(old);
    if (old.routeChanges != widget.routeChanges) {
      old.routeChanges?.removeListener(_routeChanged);
      widget.routeChanges?.addListener(_routeChanged);
    }
  }

  @override
  void dispose() {
    widget.routeChanges?.removeListener(_routeChanged);
    super.dispose();
  }

  // The router can notify in the middle of a build: look after the frame.
  void _routeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ads = ref.watch(shellBannerAdsProvider);
    final shell =
        !kIsWeb &&
        ads.configured &&
        ref.watch(bannerModeProvider) == BannerMode.shell;

    // Same rule as every waiting surface: never starts a capabilities read.
    final caps = loadedCapabilities(ref);
    if (shell && caps == null) recheckCapabilitiesAfterFrame(this);

    final media = MediaQuery.of(context);
    final path = widget.currentPath?.call();
    final visible =
        shell &&
        shouldShowWaitingBanner(caps) &&
        path != null &&
        shellBannerRoute(path) &&
        // Never over the keyboard.
        media.viewInsets.bottom == 0 &&
        // A phone on its side has no room under the lobby's Start button.
        !(path.startsWith(Routes.lobby) &&
            media.size.height < AdTokens.bannerMinLobbyHeight);

    // With the band under it, the body no longer reaches the bottom edge: the
    // band keeps the system inset, so the body must not repeat it.
    final body = visible
        ? MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(bottom: 0),
              viewPadding: media.viewPadding.copyWith(bottom: 0),
            ),
            child: widget.child,
          )
        : MediaQuery(data: media, child: widget.child);

    return Column(
      children: [
        Expanded(key: ShellBannerHost.bodyKey, child: body),
        ads.band(
          key: ShellBannerHost.bandKey,
          label: context.l10n.adBannerLabel,
          visible: visible,
        ),
      ],
    );
  }
}
