import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        rootBundle,
        SystemChrome,
        SystemUiOverlayStyle,
        SystemUiMode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/theme/app_colors.dart';
import 'data/isar/isar_match_repository.dart';
import 'data/isar/isar_player_group_repository.dart';
import 'data/match_repository.dart';
import 'data/player_group_provider.dart';
import 'data/player_group_repository.dart';
import 'data/repository_provider.dart';
import 'platform/frame_report.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The system bars are painted the app's own ground, so there is no lighter
  // band above the content or below it. On a screen this dark a default
  // system bar reads as a seam across the top of every screen, and the launch
  // window → first frame handover shows it as a flash.
  //
  // `AppColors` rather than a literal: this is the one place outside the theme
  // that has to name a surface colour, because it is talking to the OS rather
  // than to the widget tree, and a second hardcoded copy of the ground is
  // exactly how the splash and the app drifted apart before.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.groundBase,
    systemNavigationBarColor: AppColors.groundBase,
    systemNavigationBarDividerColor: AppColors.groundBase,
    // Light *icons*, for a dark bar. The naming is famously inverted.
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
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
  MatchRepository? repository;
  PlayerGroupRepository? groupRepository;
  try {
    final directory = await getApplicationDocumentsDirectory();
    final isarRepository =
        await IsarMatchRepository.open(directory: directory.path);
    repository = isarRepository;
    groupRepository = IsarPlayerGroupRepository(isarRepository.isar);
  } catch (_) {
    repository = null;
    groupRepository = null;
  }

  runApp(
    ProviderScope(
      overrides: [
        if (repository != null)
          matchRepositoryProvider.overrideWithValue(repository),
        if (groupRepository != null)
          playerGroupRepositoryProvider.overrideWithValue(groupRepository),
      ],
      child: const MafiaApp(),
    ),
  );
}
