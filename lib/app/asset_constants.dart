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

/// Doc 15's council furniture: seat rings, backdrops, the timer ornament and the two victory emblems. Every one of them is a tintable alpha mask or a full-bleed ground — none carries a role, and none may.
abstract final class AppCouncilArt {
  static const String avatarFemale = 'assets/images/online/avatar_female_transparent.png';
  static const String avatarMale = 'assets/images/online/avatar_male_transparent.png';
  static const String backdropDawn = 'assets/images/online/backdrop_dawn.webp';
  static const String backdropDay = 'assets/images/online/backdrop_day.webp';
  static const String backdropNight = 'assets/images/online/backdrop_night.webp';
  static const String backdropVerdict = 'assets/images/online/backdrop_verdict.webp';
  static const String casebookHeader = 'assets/images/online/casebook_header.webp';
  static const String fogOverlay = 'assets/images/online/fog_overlay.webp';
  static const String lightMote = 'assets/images/online/light_mote.png';
  static const String onlineWelcome = 'assets/images/online/online_welcome.webp';
  static const String panelCorner = 'assets/images/online/panel_corner.png';
  static const String seatRingCracked = 'assets/images/online/seat_ring_cracked.png';
  static const String seatRingEmpty = 'assets/images/online/seat_ring_empty.png';
  static const String seatRingIdle = 'assets/images/online/seat_ring_idle.png';
  static const String spotlight = 'assets/images/online/spotlight.png';
  static const String timerRing = 'assets/images/online/timer_ring.png';
  static const String victoryMafia = 'assets/images/online/victory_mafia.png';
  static const String victoryTown = 'assets/images/online/victory_town.png';
  static const String whisperSeal = 'assets/images/online/whisper_seal.png';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    avatarFemale,
    avatarMale,
    backdropDawn,
    backdropDay,
    backdropNight,
    backdropVerdict,
    casebookHeader,
    fogOverlay,
    lightMote,
    onlineWelcome,
    panelCorner,
    seatRingCracked,
    seatRingEmpty,
    seatRingIdle,
    spotlight,
    timerRing,
    victoryMafia,
    victoryTown,
    whisperSeal,
  ];
}

/// Transparent animated sprites (animated WebP with alpha) that play ON a surface: sparks, a spinning coin, a wax seal, a flame. Decorative only; hidden under reduced motion. See MotionSprite.
abstract final class AppMotion {
  static const String candleFlame = 'assets/images/motion/candle_flame.webp';
  static const String coinSpin = 'assets/images/motion/coin_spin.webp';
  static const String crowTakeoff = 'assets/images/motion/crow_takeoff.webp';
  static const String daggerStrike = 'assets/images/motion/dagger_strike.webp';
  static const String emberDrift = 'assets/images/motion/ember_drift.webp';
  static const String goldBurst = 'assets/images/motion/gold_burst.webp';
  static const String lanternSwing = 'assets/images/motion/lantern_swing.webp';
  static const String letterFly = 'assets/images/motion/letter_fly.webp';
  static const String levelUpSeal = 'assets/images/motion/level_up_seal.webp';
  static const String magnifierSweep = 'assets/images/motion/magnifier_sweep.webp';
  static const String shieldGlow = 'assets/images/motion/shield_glow.webp';
  static const String smokeWisp = 'assets/images/motion/smoke_wisp.webp';
  static const String voteStamp = 'assets/images/motion/vote_stamp.webp';
  static const String waxSealStamp = 'assets/images/motion/wax_seal_stamp.webp';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    candleFlame,
    coinSpin,
    crowTakeoff,
    daggerStrike,
    emberDrift,
    goldBurst,
    lanternSwing,
    letterFly,
    levelUpSeal,
    magnifierSweep,
    shieldGlow,
    smokeWisp,
    voteStamp,
    waxSealStamp,
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
  static const String academyGraduation = 'assets/audio/academy_graduation.ogg';
  static const String academyTokenPlace = 'assets/audio/academy_token_place.ogg';
  static const String academyWrongReturn = 'assets/audio/academy_wrong_return.ogg';
  static const String brandMotif = 'assets/audio/brand_motif.ogg';
  static const String cardFlip = 'assets/audio/card_flip.ogg';
  static const String caseAccuseGavel = 'assets/audio/case_accuse_gavel.ogg';
  static const String caseRevealSwell = 'assets/audio/case_reveal_swell.ogg';
  static const String caseWrongCrack = 'assets/audio/case_wrong_crack.ogg';
  static const String casebookLevelSting = 'assets/audio/casebook_level_sting.ogg';
  static const String casebookPaperSlide = 'assets/audio/casebook_paper_slide.ogg';
  static const String casebookStringPluck = 'assets/audio/casebook_string_pluck.ogg';
  static const String casebookWaxPress = 'assets/audio/casebook_wax_press.ogg';
  static const String chapterEnvelopeOpen = 'assets/audio/chapter_envelope_open.ogg';
  static const String chapterSealPress = 'assets/audio/chapter_seal_press.ogg';
  static const String confrontationSwell = 'assets/audio/confrontation_swell.ogg';
  static const String deathTear = 'assets/audio/death_tear.ogg';
  static const String eliminationReveal = 'assets/audio/elimination_reveal.ogg';
  static const String founderLetterOpen = 'assets/audio/founder_letter_open.ogg';
  static const String inviteKnock = 'assets/audio/invite_knock.ogg';
  static const String inviteSeal = 'assets/audio/invite_seal.ogg';
  static const String joinChime = 'assets/audio/join_chime.ogg';
  static const String leaveChime = 'assets/audio/leave_chime.ogg';
  static const String lobbyReadyTick = 'assets/audio/lobby_ready_tick.ogg';
  static const String morning = 'assets/audio/morning.ogg';
  static const String nightFalls = 'assets/audio/night_falls.ogg';
  static const String partnerPick = 'assets/audio/partner_pick.ogg';
  static const String scenarioTokenDrop = 'assets/audio/scenario_token_drop.ogg';
  static const String scoreLoop = 'assets/audio/score_loop.ogg';
  static const String seasonPassUnlock = 'assets/audio/season_pass_unlock.ogg';
  static const String seriesFinalSting = 'assets/audio/series_final_sting.ogg';
  static const String seriesScorePeg = 'assets/audio/series_score_peg.ogg';
  static const String sharePaperEject = 'assets/audio/share_paper_eject.ogg';
  static const String speakerChange = 'assets/audio/speaker_change.ogg';
  static const String thursdaySting = 'assets/audio/thursday_sting.ogg';
  static const String timerEnd = 'assets/audio/timer_end.ogg';
  static const String timerWarning = 'assets/audio/timer_warning.ogg';
  static const String titleEquip = 'assets/audio/title_equip.ogg';
  static const String voteTick = 'assets/audio/vote_tick.ogg';
  static const String whisperReceive = 'assets/audio/whisper_receive.ogg';
  static const String whisperSend = 'assets/audio/whisper_send.ogg';
  static const String win = 'assets/audio/win.ogg';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    academyGraduation,
    academyTokenPlace,
    academyWrongReturn,
    brandMotif,
    cardFlip,
    caseAccuseGavel,
    caseRevealSwell,
    caseWrongCrack,
    casebookLevelSting,
    casebookPaperSlide,
    casebookStringPluck,
    casebookWaxPress,
    chapterEnvelopeOpen,
    chapterSealPress,
    confrontationSwell,
    deathTear,
    eliminationReveal,
    founderLetterOpen,
    inviteKnock,
    inviteSeal,
    joinChime,
    leaveChime,
    lobbyReadyTick,
    morning,
    nightFalls,
    partnerPick,
    scenarioTokenDrop,
    scoreLoop,
    seasonPassUnlock,
    seriesFinalSting,
    seriesScorePeg,
    sharePaperEject,
    speakerChange,
    thursdaySting,
    timerEnd,
    timerWarning,
    titleEquip,
    voteTick,
    whisperReceive,
    whisperSend,
    win,
  ];
}

/// Public, on-table motion assets. Ambient loops use animated WebP; the first-run introduction is an MP4. None may be used on an in-hand surface.
abstract final class AppVideo {
  static const String skeletonLungesAtViewer20260910114646 = 'assets/video/Skeleton_lunges_at_viewer_20260910114646.mp4';
  static const String bgHomeLoop = 'assets/video/bg_home_loop.webp';
  static const String bgNightLoop = 'assets/video/bg_night_loop.webp';
  static const String bgVoteLoop = 'assets/video/bg_vote_loop.webp';
  static const String killJumpscare = 'assets/video/kill_jumpscare.mp4';
  static const String onboarding = 'assets/video/onboarding.mp4';
  static const String outcomeDeathLoop = 'assets/video/outcome_death_loop.webp';
  static const String outcomeMafiaWinLoop = 'assets/video/outcome_mafia_win_loop.webp';
  static const String outcomeSavedLoop = 'assets/video/outcome_saved_loop.webp';
  static const String outcomeTownWinLoop = 'assets/video/outcome_town_win_loop.webp';

  /// Every asset in this group, for preloading and for the manifest test.
  static const List<String> values = <String>[
    skeletonLungesAtViewer20260910114646,
    bgHomeLoop,
    bgNightLoop,
    bgVoteLoop,
    killJumpscare,
    onboarding,
    outcomeDeathLoop,
    outcomeMafiaWinLoop,
    outcomeSavedLoop,
    outcomeTownWinLoop,
  ];
}

/// «عملات المافيا». Derived from raw_assets/store/economy-v1/mafia-coin.png
/// (cropped square, alpha kept); the vault concept is not shipped.
abstract final class AppEconomyArt {
  static const String coinSmall = 'assets/images/economy/mafia_coin_96.webp';
  static const String coinLarge = 'assets/images/economy/mafia_coin_256.webp';

  static const List<String> values = <String>[coinSmall, coinLarge];
}
