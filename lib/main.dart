import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, SystemChrome, SystemUiOverlayStyle, SystemUiMode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart' show usePathUrlStrategy;

import 'app/app.dart';
import 'app/locale_controller.dart';
import 'core/theme/app_colors.dart';
import 'data/local_stores.dart';
import 'data/local_stores_io.dart'
    if (dart.library.js_interop) 'data/local_stores_web.dart';
import 'data/player_group_provider.dart';
import 'data/repository_provider.dart';
import 'data/whisper_store.dart';
import 'platform/frame_report.dart';
import 'data/motion_preference.dart';
import 'platform/launcher_label.dart';
import 'platform/push/firebase_push_service.dart';
import 'platform/push/push_service.dart';
import 'app/l10n/app_localizations.dart';
import 'ui/theme/design_tokens.dart' show InviteTokens;
import 'ui/screens/setup/setup_draft.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // `/join/CODE`, not `#/join/CODE`.
  //
  // The invite is an Android App Link now, and Android matches App Links on
  // the path: everything after `#` is stripped before the intent filter ever
  // sees it, so a hash link can only ever open a browser. The host serves
  // index.html for unknown paths, which is the one thing the hash strategy was
  // working around. No-op off the web.
  if (kIsWeb) usePathUrlStrategy();

  // The system bars are painted the app's own ground, so there is no lighter
  // band above the content or below it. On a screen this dark a default
  // system bar reads as a seam across the top of every screen, and the launch
  // window → first frame handover shows it as a flash.
  //
  // `AppColors` rather than a literal: this is the one place outside the theme
  // that has to name a surface colour, because it is talking to the OS rather
  // than to the widget tree, and a second hardcoded copy of the ground is
  // exactly how the splash and the app drifted apart before.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.groundBase,
      systemNavigationBarColor: AppColors.groundBase,
      systemNavigationBarDividerColor: AppColors.groundBase,
      // Light *icons*, for a dark bar. The naming is famously inverted.
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // No-op unless built with --dart-define=FRAME_REPORT=true.
  FrameReport.install();

  // The bundled typefaces are all SIL OFL 1.1, which requires the licence to
  // travel with the software. Registering it here surfaces it in the standard
  // Flutter licence page instead of leaving it as an unreferenced asset.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const <String>['fonts'], text);
  });

  // Storage is best-effort at startup. If the database cannot be opened the app
  // still runs on the in-memory repository from `repository_provider.dart`:
  // losing history for a session is bad, but refusing to start a game night
  // because of it would be worse.
  // Both repositories come out of the same `Isar.open`, and both fall back
  // together: if the database will not open, the app runs entirely on the
  // in-memory stores declared in the providers.
  final LocalStores? stores = await openLocalStores();
  final savedSettings = await stores?.matches.loadDefaultSettings();

  final savedLocale = await loadSavedLocale();
  final reduceMotion = await loadReduceMotionPreference();
  // Heals an interrupted switch and restores the icon name after an update.
  // A switch that would close this launch is left pending natively.
  unawaited(LauncherLabel.apply(savedLocale.languageCode));
  // Invite push: null (push off) without Firebase configuration
  // (docs/PUSH-SETUP.md). Never asks for permission here, and never holds the
  // launch longer than a moment.
  final text = lookupAppLocalizations(savedLocale);
  final push = await FirebasePushService.start(
    inviteVibration: InviteTokens.longVibration,
    socialVibration: InviteTokens.shortVibration,
    text: PushChannelText(
      invites: text.pushChannelInvites,
      invitesDescription: text.pushChannelInvitesDesc,
      social: text.pushChannelSocial,
      socialDescription: text.pushChannelSocialDesc,
    ),
  ).timeout(InviteTokens.pushStart, onTimeout: () => null);
  runApp(
    ProviderScope(
      overrides: [
        initialLocaleProvider.overrideWithValue(savedLocale),
        initialReduceMotionProvider.overrideWithValue(reduceMotion),
        if (savedSettings != null)
          initialMatchSettingsProvider.overrideWithValue(savedSettings),
        if (stores != null) ...[
          matchRepositoryProvider.overrideWithValue(stores.matches),
          playerGroupRepositoryProvider.overrideWithValue(stores.groups),
          whisperStoreProvider.overrideWithValue(stores.whispers),
        ],
        if (push != null) pushServiceProvider.overrideWithValue(push),
      ],
      child: const MafiaApp(),
    ),
  );
}
