// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Regenerate with:  python tool/generate_asset_constants.py
//
// Every path below is declared in pubspec.yaml via its parent
// directory, so adding a file to assets/ and re-running this script is
// all that is needed to make it reachable from Dart.

/// Full-bleed textures and backdrops.
abstract final class AppImages {
  static const String canvasTexture = 'assets/images/canvas_texture.webp';
  static const String cardBack = 'assets/images/card_back.webp';
  static const String cardFaceCitizen = 'assets/images/card_face_citizen.webp';
  static const String cardFaceDetective = 'assets/images/card_face_detective.webp';
  static const String cardFaceDoctor = 'assets/images/card_face_doctor.webp';
  static const String cardFaceMafia = 'assets/images/card_face_mafia.webp';
  static const String homeBackdrop = 'assets/images/home_backdrop.webp';
  static const String splashMask = 'assets/images/splash_mask.webp';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    canvasTexture,
    cardBack,
    cardFaceCitizen,
    cardFaceDetective,
    cardFaceDoctor,
    cardFaceMafia,
    homeBackdrop,
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
  static const String roleCitizen = 'assets/icons/role_citizen.webp';
  static const String roleDetective = 'assets/icons/role_detective.webp';
  static const String roleDoctor = 'assets/icons/role_doctor.webp';
  static const String roleMafia = 'assets/icons/role_mafia.webp';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
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
