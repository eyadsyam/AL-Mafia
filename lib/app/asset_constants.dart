// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Regenerate with:  python tool/generate_asset_constants.py
//
// Every path below is declared in pubspec.yaml via its parent
// directory, so adding a file to assets/ and re-running this script is
// all that is needed to make it reachable from Dart.

/// Full-bleed textures and backdrops.
abstract final class AppImages {
  static const String bgDay = 'assets/images/bg_day.webp';
  static const String bgHome = 'assets/images/bg_home.webp';
  static const String bgNight = 'assets/images/bg_night.webp';
  static const String bgVote = 'assets/images/bg_vote.webp';
  static const String canvasTexture = 'assets/images/canvas_texture.webp';
  static const String cardBack = 'assets/images/card_back.webp';
  static const String cardFaceCitizen = 'assets/images/card_face_citizen.webp';
  static const String cardFaceDetective = 'assets/images/card_face_detective.webp';
  static const String cardFaceDoctor = 'assets/images/card_face_doctor.webp';
  static const String cardFaceMafia = 'assets/images/card_face_mafia.webp';
  static const String homeBackdrop = 'assets/images/home_backdrop.webp';
  static const String onboardingDay = 'assets/images/onboarding_day.webp';
  static const String onboardingNight = 'assets/images/onboarding_night.webp';
  static const String onboardingPass = 'assets/images/onboarding_pass.webp';
  static const String onboardingStory = 'assets/images/onboarding_story.webp';
  static const String onboardingWin = 'assets/images/onboarding_win.webp';
  static const String outcomeDeath = 'assets/images/outcome_death.webp';
  static const String outcomeMafiaWin = 'assets/images/outcome_mafia_win.webp';
  static const String outcomeSaved = 'assets/images/outcome_saved.webp';
  static const String outcomeTownWin = 'assets/images/outcome_town_win.webp';
  static const String splashMask = 'assets/images/splash_mask.webp';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    bgDay,
    bgHome,
    bgNight,
    bgVote,
    canvasTexture,
    cardBack,
    cardFaceCitizen,
    cardFaceDetective,
    cardFaceDoctor,
    cardFaceMafia,
    homeBackdrop,
    onboardingDay,
    onboardingNight,
    onboardingPass,
    onboardingStory,
    onboardingWin,
    outcomeDeath,
    outcomeMafiaWin,
    outcomeSaved,
    outcomeTownWin,
    splashMask,
  ];
}

/// Post-game role art. Full colour, and deliberately NOT luminance-matched across roles — these must never be referenced from a surface reachable while the phone is in a player's hand. handoff_purity_test.dart enforces that.
abstract final class AppGallery {
  static const String galleryCitizen = 'assets/images/gallery/gallery_citizen.webp';
  static const String galleryDetective = 'assets/images/gallery/gallery_detective.webp';
  static const String galleryDoctor = 'assets/images/gallery/gallery_doctor.webp';
  static const String galleryMafia = 'assets/images/gallery/gallery_mafia.webp';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    galleryCitizen,
    galleryDetective,
    galleryDoctor,
    galleryMafia,
  ];
}

/// Tintable alpha masks. These carry no colour of their own; the widget layer supplies it.
abstract final class AppIcons {
  static const String badgeFrame = 'assets/icons/badge_frame.webp';
  static const String roleCitizen = 'assets/icons/role_citizen.webp';
  static const String roleDetective = 'assets/icons/role_detective.webp';
  static const String roleDoctor = 'assets/icons/role_doctor.webp';
  static const String roleMafia = 'assets/icons/role_mafia.webp';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    badgeFrame,
    roleCitizen,
    roleDetective,
    roleDoctor,
    roleMafia,
  ];
}

/// Table cues. Never played while the phone is in a player's hand — see AudioDirector.
abstract final class AppAudio {
  static const String cardFlip = 'assets/audio/card_flip.ogg';
  static const String eliminationReveal = 'assets/audio/elimination_reveal.ogg';
  static const String morning = 'assets/audio/morning.ogg';
  static const String nightFalls = 'assets/audio/night_falls.ogg';
  static const String scoreLoop = 'assets/audio/score_loop.ogg';
  static const String speakerChange = 'assets/audio/speaker_change.ogg';
  static const String timerEnd = 'assets/audio/timer_end.ogg';
  static const String timerWarning = 'assets/audio/timer_warning.ogg';
  static const String win = 'assets/audio/win.ogg';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    cardFlip,
    eliminationReveal,
    morning,
    nightFalls,
    scoreLoop,
    speakerChange,
    timerEnd,
    timerWarning,
    win,
  ];
}

/// Ambient loops, as animated WebP played by Image.asset — no video_player, no platform view. ON-TABLE ONLY: a moving image is brightness that changes frame to frame, so on an in-hand surface it breaks the +/-2% luminance budget on nearly every frame and its loop position is a timing channel besides. Every *_loop has a *_still beside it, which is what Reduce Motion renders — animated WebP has no pause API.
abstract final class AppVideo {
  static const String bgHomeLoop = 'assets/video/bg_home_loop.webp';
  static const String bgNightLoop = 'assets/video/bg_night_loop.webp';
  static const String bgVoteLoop = 'assets/video/bg_vote_loop.webp';
  static const String outcomeDeathLoop = 'assets/video/outcome_death_loop.webp';
  static const String outcomeMafiaWinLoop = 'assets/video/outcome_mafia_win_loop.webp';
  static const String outcomeSavedLoop = 'assets/video/outcome_saved_loop.webp';
  static const String outcomeTownWinLoop = 'assets/video/outcome_town_win_loop.webp';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    bgHomeLoop,
    bgNightLoop,
    bgVoteLoop,
    outcomeDeathLoop,
    outcomeMafiaWinLoop,
    outcomeSavedLoop,
    outcomeTownWinLoop,
  ];
}
