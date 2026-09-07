// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'سيد المافيا';

  @override
  String get actionNotSaved => 'اختيارك متسجلش جرب تاني';

  @override
  String get back => 'رجوع';

  @override
  String get cancel => 'الغاء';

  @override
  String get deleteAction => 'امسح';

  @override
  String get continueAction => 'كمل';

  @override
  String get listSeparator => '، ';

  @override
  String get newMatch => 'مباراة جديدة';

  @override
  String get history => 'السجل';

  @override
  String get settings => 'الإعدادات';

  @override
  String get addPlayersTitle => 'ضيف اللاعبين';

  @override
  String get seatingOrderSubtitle => 'اسحب الاسم عشان تغير ترتيبه';

  @override
  String get playerNameHint => 'اسم اللاعب';

  @override
  String get addPlayer => 'ضيف';

  @override
  String playerCountLine(int count) {
    return 'عدد اللاعبين: $count';
  }

  @override
  String get noPlayersYet => 'ضيف أول لاعب';

  @override
  String get next => 'كمل';

  @override
  String seatNumber(int seat) {
    return 'الكرسي #$seat';
  }

  @override
  String get rolesTitle => 'توزيع الأدوار';

  @override
  String playerCountShort(int count) {
    return '$count لاعب';
  }

  @override
  String get roleGroupMafia => 'المافيا';

  @override
  String get roleGroupDetective => 'المحقق';

  @override
  String get roleGroupDoctor => 'الدكتور';

  @override
  String get roleGroupCitizen => 'المواطن';

  @override
  String get balanceValid => 'التوزيع جاهز';

  @override
  String get balancePlayerCountTooLow => 'محتاجين 5 لاعبين على الأقل';

  @override
  String get balancePlayerCountTooHigh => 'الحد الأقصى 20 لاعب';

  @override
  String get balanceNegativeRoleCount => 'عدد الأدوار مينفعش يبقى بالسالب';

  @override
  String get balanceRoleCountMismatch =>
      'مجموع الأدوار لازم يساوي عدد اللاعبين';

  @override
  String get balanceNoMafia => 'لازم يكون في مافيا واحد على الأقل';

  @override
  String get balanceMafiaTooMany => 'عدد المافيا لازم يكون أقل من نص اللاعبين';

  @override
  String get balanceRecommendThreeMafia =>
      'الأفضل تختار 3 مافيا لما تكونوا 9 لاعبين أو أكتر';

  @override
  String get balanceTwoDetectivesLowPlayerCount =>
      'محققين مع أقل من 11 لاعب بيقووا فريق المواطنين';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get speechSecondsLabel => 'وقت كل لاعب';

  @override
  String secondsSuffix(int seconds) {
    return '$seconds ث';
  }

  @override
  String get discussionModeLabel => 'طريقة النقاش';

  @override
  String get discussionStructured => 'بالدور';

  @override
  String get discussionFree => 'حر';

  @override
  String get dayTieRuleLabel => 'قاعدة التعادل في النهار';

  @override
  String get tieRevote => 'تصويت تاني';

  @override
  String get tieNoElimination => 'محدش يخرج';

  @override
  String get narrationEnabledLabel => 'صوت بداية النهار';

  @override
  String get abstainAllowedLabel => 'السماح بعدم التصويت';

  @override
  String get save => 'حفظ';

  @override
  String get nightApproaching => 'الليل يقترب';

  @override
  String get nightLabel => 'الليلة';

  @override
  String get aliveCountLabel => 'لاعبين لسه في اللعبة';

  @override
  String get placePhoneOnTable => 'ضع الهاتف على الطاولة وانتظر الإشارة';

  @override
  String get beginNight => 'ابدأ الليل';

  @override
  String get distributionSubtitle => 'توزيع الأدوار';

  @override
  String get roleMafia => 'مافيا';

  @override
  String get roleDoctor => 'دكتور';

  @override
  String get roleDetective => 'محقق';

  @override
  String get roleCitizen => 'مواطن';

  @override
  String get roleMafiaDescription => 'كل ليلة بتختار مين يتقتل';

  @override
  String get roleDoctorDescription =>
      'كل ليلة بتحمي لاعب وحماية نفسك متاحة مرة في المباراة';

  @override
  String get roleDetectiveDescription =>
      'كل ليلة بتكشف عن شخصية واحد من اللاعبين';

  @override
  String get roleCitizenDescription =>
      'ملاكش ميزة خاصة بتحاول تفهم ايه اللي بيحصل ';

  @override
  String get gotIt => 'فهمت';

  @override
  String get holdToRevealRole => 'دوس عشان تشوف كارتك';

  @override
  String teammatesLine(String names) {
    return 'معاك في المافيا: $names';
  }

  @override
  String get passPhoneTo => 'سلم الموبايل لـ';

  @override
  String iAmHoldInstruction(String name) {
    return 'أنا $name — دوس';
  }

  @override
  String notYouNamed(String name) {
    return 'مش $name؟';
  }

  @override
  String get yourTurn => 'دورك';

  @override
  String get holdToConfirm => 'دوس ثانيتين عشان تكمل';

  @override
  String get notYou => 'مش انت؟';

  @override
  String get choosePlayer => 'اختار لاعب';

  @override
  String get confirmAction => 'أكد';

  @override
  String get choiceRecorded => 'اختيارك اتسجل';

  @override
  String get passPhone => 'سلم الموبايل';

  @override
  String get waitEllipsis => 'استنى';

  @override
  String get nightPromptMafia => 'مين عايز تقتله الليلة؟';

  @override
  String get nightPromptDoctor => 'مين عايز تحميه الليلة؟';

  @override
  String get nightPromptDetective => 'مين عايز تفحصه الليلة؟';

  @override
  String get nightPromptCitizen => 'مين شاكك فيه الليلة دي؟';

  @override
  String get notEveryoneSurvived => 'فيه لاعبين خرجوا';

  @override
  String lostPlayerLastNight(String name) {
    return '$name اتقتل بالليل';
  }

  @override
  String get quietNight => 'محدش مات';

  @override
  String get someoneSavedBody => 'حد نجا من محاولة قتل';

  @override
  String get noLossesBody => 'محدش مات الليلة دي';

  @override
  String morningOfDay(int day) {
    return 'صباح اليوم $day';
  }

  @override
  String get startDiscussion => 'ابدأ النقاش';

  @override
  String get discussionTitle => 'النقاش';

  @override
  String get discussionFreeTitle => 'النقاش الحر';

  @override
  String get currentSpeaker => 'الدور على';

  @override
  String speakersRemaining(int count) {
    return 'فاضل $count';
  }

  @override
  String get skip => 'تخطي';

  @override
  String get endDiscussion => 'خلص النقاش';

  @override
  String get resume => 'متابعة';

  @override
  String get pause => 'وقف';

  @override
  String get votingSubtitle => 'التصويت';

  @override
  String get whoDoYouVoteOut => 'مين يخرج؟';

  @override
  String get abstain => 'امتناع';

  @override
  String get confirmVote => 'أكد صوتك';

  @override
  String eliminatedHeadline(String name) {
    return 'خرج $name';
  }

  @override
  String get tieRevoteHeadline => 'تعادل هنصوت تاني';

  @override
  String get tieNoEliminationHeadline => 'تعادل ومحدش خرج';

  @override
  String get nobodyEliminated => 'محدش خرج';

  @override
  String wasRole(String role) {
    return 'كان $role';
  }

  @override
  String get revote => 'صوتوا تاني';

  @override
  String get gameOver => 'المباراة خلصت';

  @override
  String get mafiaWins => 'المافيا كسبت';

  @override
  String get townWins => 'الشعب كسب';

  @override
  String get analytics => 'التحليلات';

  @override
  String get homeAction => 'الرئيسية';

  @override
  String get endMatchTitle => 'تنهي المباراة؟';

  @override
  String get endMatchBody => 'المباراة مش هتتحفظ في السجل';

  @override
  String get keepPlaying => 'كمل اللعب';

  @override
  String get endAction => 'خلص';

  @override
  String get endMatchTooltip => 'انهي المباراة';

  @override
  String get unfinishedMatchTitle => 'فيه مباراة لسه مخلصتش';

  @override
  String unfinishedMatchBody(int count, String where) {
    return '$count لاعبين. $where';
  }

  @override
  String resumeFromPassTo(String name) {
    return 'هنكمل من دور $name';
  }

  @override
  String resumeFromDay(int day) {
    return 'هنكمل من اليوم $day';
  }

  @override
  String get endMatch => 'انهي المباراة';

  @override
  String get resumeAction => 'كمل';

  @override
  String nightNumbered(int number) {
    return 'الليلة $number';
  }

  @override
  String dayNumbered(int number) {
    return 'اليوم $number';
  }

  @override
  String get analyticsTitle => 'التحليلات';

  @override
  String get analyticsLoadFailed => 'مش قادرين نفتح التحليلات دلوقتي';

  @override
  String seatFallback(int seat) {
    return 'مقعد $seat';
  }

  @override
  String get tabEvents => 'الأحداث';

  @override
  String get tabPlayers => 'اللاعبين';

  @override
  String get tabSuspicions => 'الشكوك';

  @override
  String get tabAchievements => 'الإنجازات';

  @override
  String timelineMafiaVote(String actor, String target) {
    return '$actor صوت على $target';
  }

  @override
  String timelineProtect(String actor, String target) {
    return '$actor حمى $target';
  }

  @override
  String timelineInvestigate(String actor, String target) {
    return '$actor كشف $target';
  }

  @override
  String timelineSuspect(String actor, String target) {
    return '$actor شك في $target';
  }

  @override
  String timelineNightKill(String target) {
    return '$target اتقتل بالليل';
  }

  @override
  String timelineSaved(String target) {
    return '$target نجا من القتل';
  }

  @override
  String timelineDayElimination(String target) {
    return 'الشعب صوّت على طرد $target';
  }

  @override
  String get noEventsRecorded => 'مفيش أحداث متسجلة';

  @override
  String get noPlayerData => 'مفيش بيانات للاعبين';

  @override
  String get noSuspicionsByPlayer => 'مسجلش شكوك';

  @override
  String suspicionAccuracyLine(int correct, int total) {
    return 'شكوك صح: $correct/$total';
  }

  @override
  String get noSuspicionsRecorded => 'مفيش شكوك متسجلة';

  @override
  String get noAchievements => 'مفيش انجازات';

  @override
  String get achievementSharpestEye => 'العين الثاقبة';

  @override
  String get achievementSharpestEyeDescription => 'أعلى دقة في الشكوك';

  @override
  String get achievementUntouchable => 'الناجي';

  @override
  String get achievementUntouchableDescription => 'كمل للآخر';

  @override
  String get achievementGuardian => 'الحامي';

  @override
  String get achievementGuardianDescription => 'منع هجوم المافيا بالحماية';

  @override
  String get achievementFirstBlood => 'أول ضحية';

  @override
  String get achievementFirstBloodDescription =>
      'أول لاعب مات في الليلة الأولى';

  @override
  String get achievementSurvivors => 'اللي كملوا للآخر';

  @override
  String get achievementSurvivorsDescription => 'فضلوا في اللعبة لحد النهاية';

  @override
  String get historyTitle => 'السجل';

  @override
  String get deleteMatchTitle => 'تمسح المباراة؟';

  @override
  String get deleteMatchBody => 'التحليلات هتتمسح نهائي';

  @override
  String get noPastMatches => 'لسه مفيش مباريات';

  @override
  String get mafiaWon => 'المافيا كسبت';

  @override
  String get townWon => 'الشعب كسب';

  @override
  String get endedWithoutResult => 'خلصت من غير نتيجة';

  @override
  String matchMeta(int players, int nights) {
    return '$players لاعبين · $nights ليالي';
  }

  @override
  String get holdToConfirmIdentity => 'دوس عشان تشوف كارتك';

  @override
  String get swipeToReveal => 'اسحب الكارت في أي اتجاه عشان يتقلب';

  @override
  String get passThePhone => 'سلّم الموبايل';

  @override
  String get phaseNightFalls => 'الضلمة نزلت على البلد… كله يغمّض';

  @override
  String get phaseMorningSomeoneDied => 'نتيجة الليل';

  @override
  String get phaseMorningNobodyDied => 'محدش مات الليلة دي';

  @override
  String get phaseVoting => 'وقت التصويت';

  @override
  String get phaseMafiaWins => 'المافيا خلصت على البلد';

  @override
  String get phaseTownWins => 'الشعب انتصر';

  @override
  String get identityHoldLabel => 'مدة الضغط قبل الكارت';

  @override
  String identityHoldSuffix(int seconds) {
    return '$seconds ثانية';
  }

  @override
  String get startGame => 'ابدأ اللعبة';

  @override
  String get howToPlay => 'إزاي نلعب';

  @override
  String get tapCardHint => 'دوس على أي كارت تعرف بيعمل إيه';

  @override
  String get howToPlayTitle => 'إزاي نلعب';

  @override
  String get rulesTitle => 'قوانين اللعبة';

  @override
  String get rulesGoalTitle => 'هدف اللعبة';

  @override
  String get rulesGoalBody =>
      'المواطنين بيحاولوا يخرجوا المافيا بالتصويت والمافيا بتحاول تقلل عدد المواطنين';

  @override
  String get rulesRolesTitle => 'الأدوار';

  @override
  String get rulesDayTitle => 'مرحلة النهار';

  @override
  String get rulesDayBody =>
      'الصبح بتظهر نتيجة الليل وبعد النقاش كل لاعب بيصوت على مين يخرج';

  @override
  String get rulesNightTitle => 'مرحلة الليل';

  @override
  String get rulesNightBody =>
      'بالليل كل لاعب بيسجل اختياره: المافيا بتختار ضحية والدكتور بيحمي والمحقق بيكشف والمواطن بيسجل شكه';

  @override
  String get rulesWinTitle => 'شروط الفوز';

  @override
  String get rulesWinBody =>
      'المواطنين بيكسبوا لما كل المافيا يخرجوا والمافيا بتكسب لما عددهم يساوي باقي اللاعبين';

  @override
  String get rulesTipsTitle => 'نصايح';

  @override
  String get rulesTipsBody =>
      '— راقب ردود فعل الناس وهما بيتكلموا.\n— متكشفش دورك بسرعة لو إنت محقق أو دكتور.\n— لو إنت مافيا، حاول توجّه الشك لغيرك.\n— الدكتور مينفعش يحمي نفس الشخص مرتين ورا بعض.\n— متبصّش في موبايل حد تاني، ومتسلّمش الموبايل وهو مفتوح على كارت.';

  @override
  String get audioSettingsLabel => 'الصوت';

  @override
  String get muteAllAudio => 'اقفل كل الأصوات';

  @override
  String get scoreEnabledLabel => 'الموسيقى';

  @override
  String get muteNarrator => 'كتم الراوي';

  @override
  String get narratorPlaceholder => 'صوت الراوي هيتسجّل بعدين';

  @override
  String get groupsTitle => 'مين بيلعب؟';

  @override
  String get newGroupAction => 'مجموعة جديدة';

  @override
  String groupMeta(int members, int plays) {
    return '$members لاعبين · لعبتوا $plays مرة';
  }

  @override
  String groupMetaNeverPlayed(int members) {
    return '$members لاعبين · لسه ملعبوش';
  }

  @override
  String get saveGroupPrompt => 'احفظ دول كمجموعة؟';

  @override
  String get saveAction => 'احفظ';

  @override
  String get notNowAction => 'مش دلوقتي';

  @override
  String get groupNameHint => 'اسم المجموعة';

  @override
  String groupNameDefault(int number) {
    return 'مجموعة $number';
  }

  @override
  String get saveGroupTitle => 'اسم المجموعة';

  @override
  String get renameAction => 'غير الاسم';

  @override
  String get renameGroupTitle => 'غير اسم المجموعة';

  @override
  String get deleteGroupTitle => 'حذف المجموعة؟';

  @override
  String get deleteGroupBody => 'هتتشال خالص. المباريات القديمة مش هتتأثر.';

  @override
  String get quickStartAction => 'ابدأ';

  @override
  String get presentAction => 'موجود';

  @override
  String get absentAction => 'مش موجود';

  @override
  String get attendanceHint =>
      'دوس على أي اسم لو مش موجود النهارده. هيفضل في المجموعة.';

  @override
  String playingTonight(int count) {
    return 'بيلعبوا النهارده: $count';
  }

  @override
  String get addGuestsToGroupTitle => 'تضيفهم للمجموعة؟';

  @override
  String addGuestsToGroupBody(String names, String group) {
    return '$names لعبوا النهارده ومش في $group.';
  }

  @override
  String get saveGroupOrderTitle => 'تحفظ ترتيب اللاعبين؟';

  @override
  String saveGroupOrderBody(String group) {
    return 'ترتيب اللاعبين في $group اتغير';
  }

  @override
  String get addAction => 'ضيف';

  @override
  String get onboardingTitle => 'أول جولة';

  @override
  String get onboardingNext => 'كمل';

  @override
  String get onboardingStart => 'ابدأ أول مباراة';

  @override
  String get onboardingReadRules => 'القواعد بالتفصيل';

  @override
  String onboardingProgress(int current, int total) {
    return 'كارت $current من $total';
  }

  @override
  String get onboardingStoryTitle => 'الحكاية';

  @override
  String get onboardingStoryBody =>
      'لعبة أدوار سرية فريق المواطنين ضد فريق المافيا';

  @override
  String get onboardingRolesTitle => 'الأدوار';

  @override
  String get onboardingRolesBody =>
      'كل لاعب ليه كارت واحد دوس على الكارت عشان تعرف دوره';

  @override
  String get onboardingNightTitle => 'الليل';

  @override
  String get onboardingNightBody =>
      'المافيا بتختار ضحية والدكتور بيحمي والمحقق بيكشف والمواطن بيسجل شكه';

  @override
  String get onboardingDayTitle => 'النهار';

  @override
  String get onboardingDayBody =>
      'الصبح بتظهر نتيجة الليل وبعد النقاش بيبدأ التصويت';

  @override
  String get onboardingPassTitle => 'الموبايل';

  @override
  String get onboardingPassBody =>
      'دوس ثانيتين على اسمك واسحب الكارت عشان تشوفه الكارت بيتقفل لوحده قبل ما تسلم الموبايل';

  @override
  String get onboardingSecrecyTitle => 'السرّ محفوظ';

  @override
  String get onboardingSecrecyBody =>
      'لو قفلت التطبيق وقت دورك هترجع لشاشة اسمك النتيجة الخاصة مش بتظهر تاني';

  @override
  String get onboardingWinTitle => 'الفوز';

  @override
  String get onboardingWinBody =>
      'المواطنين بيكسبوا لما كل المافيا يخرجوا والمافيا بتكسب لما عددهم يساوي باقي اللاعبين';

  @override
  String get traceLabel => 'الأثر';

  @override
  String get traceNone => 'الليلة دي ماسابتش أي أثر';

  @override
  String traceLastSuspicion(String victim, String target) {
    return 'آخر حاجة سجّلها $victim: كان شاكك في «$target»';
  }

  @override
  String get traceSomeoneSurvived => 'حد اتحمى الليلة دي… ونجا';

  @override
  String traceAgreement(int count) {
    return '$count لاعبين شكّوا في نفس الشخص الليلة دي';
  }

  @override
  String traceShift(int count) {
    return '$count غيّر شكّه الليلة دي';
  }

  @override
  String get traceShadow => 'فيه لاعب لسه محدش شك فيه ولا مرة';

  @override
  String get traceSilence => 'فيه لاعب رفض يسجّل شكّه الليلة دي';

  @override
  String get traceCircle => 'اتنين شاكّين في بعض';

  @override
  String get traceConsensus => 'أغلب الطاولة شكّت في نفس الشخص';

  @override
  String get openingRoundTitle => 'اسم واحد';

  @override
  String get openingRoundBody => 'اختار اسم قبل ما الوقت يخلص';

  @override
  String openingRoundPrompt(String name) {
    return 'مين شاكك فيه، يا $name؟';
  }

  @override
  String get confrontationLabel => 'المواجهة';

  @override
  String get confrontationExplain => 'ردك';

  @override
  String get confrontationDone => 'خلصت';

  @override
  String confrontationC1(String x, String y) {
    return 'قلت انك شاكك في $x وصوت لـ$y';
  }

  @override
  String get confrontationC4 => 'محدش شك فيك لحد دلوقتي';

  @override
  String confrontationC5(String x, int count) {
    return 'انت و$x صوتوا نفس التصويت $count مرات';
  }

  @override
  String get confrontationC6 => 'انت أقل واحد اتكلم في المباراة ردك؟';

  @override
  String get confrontationC7 => 'آخر واحد مات كان شاكك فيك ردك؟';

  @override
  String confrontationC8(String x) {
    return 'بتهمس لـ$x كل يوم ليه؟';
  }

  @override
  String get confrontationC11 => 'حد حاول يوصلك وماعرفش';

  @override
  String get whisperLabel => 'الهمس';

  @override
  String whisperFrom(String name) {
    return 'من $name';
  }

  @override
  String get whisperCompose => 'ابعت همسة';

  @override
  String get whisperPickRecipient => 'لمين؟';

  @override
  String get whisperBodyHint => 'لغاية ١٢٠ حرف';

  @override
  String get whisperSend => 'ابعت';

  @override
  String get whisperSent => 'اتبعتت';

  @override
  String get whisperAlreadySentToday => 'بعت همستك النهارده';

  @override
  String get whisperUndelivered => 'الهمسة ماوصلتش';

  @override
  String whisperGraphTitle(int day) {
    return 'همسات النهار $day';
  }

  @override
  String get whisperGraphEmpty => 'محدش همس النهارده';

  @override
  String whisperNobodySent(String names) {
    return '($names مابعتوش)';
  }

  @override
  String get whisperArrow => '←';

  @override
  String whisperTooLong(int count) {
    return 'زايد $count حرف';
  }

  @override
  String get whisperLanguageWarning => 'الرسالة فيها لفظ مسيء تبعتها؟';

  @override
  String get whisperReport => 'امنع همسات اللاعب';

  @override
  String get whisperReported => 'مش هتوصلك همسات من اللاعب ده';

  @override
  String get informationEngineSection => 'معلومات المباراة';

  @override
  String get settingTrace => 'الأثر';

  @override
  String get settingTraceHint => 'معلومة من أحداث المباراة لو فيه أثر متاح';

  @override
  String get settingConfrontation => 'المواجهة';

  @override
  String get settingConfrontationHint => 'سؤال مبني على اللي حصل في المباراة';

  @override
  String get settingOpeningRound => 'اختيار اسم في أول يوم';

  @override
  String get settingOpeningRoundHint => '10 ثواني لكل لاعب';

  @override
  String get settingWhisper => 'الهمس';

  @override
  String get settingWhisperHint => 'رسالة خاصة واحدة في اليوم';

  @override
  String get settingRevealWhispers => 'اكشف محتوى الهمسات بعد المباراة';

  @override
  String get settingRevealWhispersHint => 'اظهار الرسائل في التحليلات';

  @override
  String get onlineMatch => 'العب أونلاين';

  @override
  String get onlineCreateRoom => 'اعمل أوضة';

  @override
  String get onlineJoinRoom => 'ادخل أوضة';

  @override
  String get onlineCreateRoomHint => 'هتاخد كود وتبعته للباقي';

  @override
  String get onlineJoinRoomHint => 'معاك كود من حد؟';

  @override
  String get onlineRoomCode => 'كود الأوضة';

  @override
  String get onlineRoomCodeHint => 'ست خانات';

  @override
  String get onlineShareCode => 'ابعت الكود';

  @override
  String get onlineWaitingForPlayers => 'مستني اللاعبين';

  @override
  String get onlineStartMatch => 'يلا نبدأ';

  @override
  String get onlineConnecting => 'بنرجع الاتصال';

  @override
  String get onlineDisconnected => 'مفيش اتصال';

  @override
  String get onlineNotConnected => 'غير متصل';

  @override
  String onlineHostLeft(String name) {
    return 'صاحب الأوضة خرج. $name بقى هو المسؤول دلوقتي.';
  }

  @override
  String get onlineRoomFull => 'الأوضة مليانة';

  @override
  String get onlineRoomFinished => 'المباراة دي خلصت';

  @override
  String get onlineRoomNotFound => 'مفيش أوضة بالكود ده';

  @override
  String get onlineUnreachable => 'مش قادرين نتصل جرب تاني';

  @override
  String get onlineProjectPaused => 'الأونلاين مش متاح دلوقتي جرب كمان دقيقة';

  @override
  String get onlinePlayOffline => 'العب أوفلاين';

  @override
  String get onlineHeadphonesWarning =>
      'لو قاعدين في نفس الأوضة، استخدموا سماعات';

  @override
  String get voiceMicOff => 'المايك مقفول';

  @override
  String get voiceMuteMe => 'اقفل المايك';

  @override
  String get voiceUnmuteMe => 'افتح المايك';

  @override
  String get voiceSelfMuted => 'قافل مايكك';

  @override
  String get voiceMicOn => 'المايك شغال';

  @override
  String get voiceTextMode => 'الصوت مش متاح';

  @override
  String get voiceMicDenied => 'اسمح بالمايك عشان تتكلم';

  @override
  String get whoAreYou => 'مين فيكم؟';

  @override
  String get onlineYourName => 'اسمك';

  @override
  String get onlineHostBadge => 'المسؤول';

  @override
  String get onlineYou => 'أنت';

  @override
  String get onlineNeedFivePlayers => 'محتاجين ٥ لاعبين على الأقل';

  @override
  String get onlineLeave => 'اخرج من الأوضة';

  @override
  String get onlineCodeCopied => 'الكود اتنسخ';

  @override
  String get onlinePublicRooms => 'أوض عامة';

  @override
  String get onlinePublicRoomsHint => 'ادخل أوضة مفتوحة من غير كود';

  @override
  String get onlineNoPublicRooms => 'مفيش أوض عامة مفتوحة دلوقتي';

  @override
  String onlinePublicRoomPlayers(int count) {
    return '$count لاعب';
  }

  @override
  String get onlineUntitledRoom => 'أوضة من غير اسم';

  @override
  String get onlineRoomSettings => 'إعدادات الأوضة';

  @override
  String get onlineSettingsRoom => 'الأوضة';

  @override
  String get onlineSettingsVoice => 'الصوت';

  @override
  String get onlineSettingsPlay => 'اللعب';

  @override
  String get onlineSettingsInfo => 'المعلومات';

  @override
  String get onlineRoomVisibility => 'نوع الأوضة';

  @override
  String get onlineRoomVisibilityHint =>
      'الخاصة بالكود بس. العامة بتظهر في القايمة لأي حد.';

  @override
  String get onlineRoomPrivate => 'خاصة';

  @override
  String get onlineRoomPublic => 'عامة';

  @override
  String get onlineRoomTitle => 'اسم الأوضة';

  @override
  String get onlineRoomTitleHint => 'الاسم اللي هيشوفه الناس في القايمة.';

  @override
  String get onlineMaxPlayers => 'أقصى عدد لاعبين';

  @override
  String get onlineMaxPlayersHint => 'الأوضة بتتقفل لما العدد ده يكتمل.';

  @override
  String get onlineVoiceEnabled => 'الصوت';

  @override
  String get onlineVoiceEnabledHint => 'من غيره المباراة شغالة عادي بالكتابة.';

  @override
  String get onlineMuteAtNight => 'كتم الكل عند الليل';

  @override
  String get onlineMuteAtNightHint => 'الصوت في الليل بيقول مين صاحي.';

  @override
  String get onlineSpeakDuration => 'مدة الكلام';

  @override
  String get onlineSpeakDurationHint => 'الوقت اللي كل واحد بيتكلم فيه لوحده.';

  @override
  String get onlineDiscussDuration => 'مدة النقاش';

  @override
  String get onlineDiscussDurationHint => 'الوقت المفتوح قبل التصويت.';

  @override
  String get onlineOpenVoting => 'تصويت مكشوف';

  @override
  String get onlineOpenVotingHint =>
      'الكل بيشوف صوت مين راح لمين قبل ما القفل ينزل.';

  @override
  String get onlineTrace => 'الأثر';

  @override
  String get onlineTraceHint => 'الصبح بيقول أثر واحد عن حركة الليل.';

  @override
  String get onlineConfrontation => 'المواجهة';

  @override
  String get onlineConfrontationHint =>
      'اتنين بيتواجهوا قدام الأوضة قبل التصويت.';

  @override
  String get onlineWhispers => 'الهمسات';

  @override
  String get onlineWhispersHint =>
      'رسالة خاصة لواحد بس، والأوضة بتعرف إنها اتبعتت.';

  @override
  String get onlineSeconds => 'ثانية';

  @override
  String get onlineMinutes => 'دقايق';

  @override
  String get onlineLinkCopied => 'لينك الأوضة اتنسخ';

  @override
  String get onlineWaitingForHost => 'مستني المسؤول';

  @override
  String get voiceTakeFloor => 'اتكلم';

  @override
  String get voiceYieldFloor => 'خلصت';

  @override
  String get voiceFloorTaken => 'فيه لاعب بيتكلم دلوقتي';

  @override
  String get onlineWeatherConnecting => 'بنتصل';

  @override
  String get onlineWeatherReconnecting => 'بنرجع الاتصال';

  @override
  String get onlineWeatherUnreachable => 'مفيش اتصال هنكمل لما يرجع';

  @override
  String get onlineCopy => 'نسخ';

  @override
  String get onlineShare => 'مشاركة';

  @override
  String onlinePlayersOfMax(int count, int max) {
    return '$count / $max لاعبين';
  }

  @override
  String get onlineVoiceConnecting => 'الصوت: بيتصل…';

  @override
  String get onlineVoiceConnected => 'الصوت: متصل';

  @override
  String get onlineVoiceUnavailable => 'الصوت مش متاح والمباراة شغالة';

  @override
  String onlineShareInvite(String code) {
    return 'العب معانا مافيا. كود الأوضة: $code';
  }

  @override
  String get onlineGhostRule => 'اللي بيخرج ما يتكلمش مع اللي لسه لاعب';

  @override
  String onlineChosen(String name) {
    return 'اخترت: $name';
  }

  @override
  String onlineUpNext(String names) {
    return 'بعدها: $names';
  }

  @override
  String get onlineLeftRoom => 'خرج';

  @override
  String onlineNewHost(String name) {
    return '$name بقى الهوست';
  }

  @override
  String get onlineCloseRoom => 'اقفل الأوضة';

  @override
  String get onlineCloseRoomBody => 'الأوضة هتقفل لكل اللي فيها. أكيد؟';

  @override
  String get onlineCloseRoomConfirm => 'اقفل';

  @override
  String get onlineRoomClosed => 'الهوست قفل الأوضة';

  @override
  String get onlineKick => 'اطرد';

  @override
  String get onlineMute => 'اكتم';

  @override
  String get onlineUnmute => 'شيل الكتم';

  @override
  String get onlineKickedByHost => 'الهوست طردك من الأوضة';

  @override
  String onlineWaitingForCards(String names) {
    return 'مستنيين: $names';
  }

  @override
  String onlineRaisedHands(String names) {
    return 'رافعين إيدهم: $names';
  }

  @override
  String get onlineRaiseHand => 'دوري';

  @override
  String get onlineHandRaised => 'إيدك مرفوعة';

  @override
  String get onlineSeeRoles => 'شوف الأدوار';

  @override
  String onlineRosterOf(int index, int total) {
    return '$index من $total';
  }

  @override
  String get onlinePickFromTable => 'اختار لاعب';

  @override
  String get onlineWaitingForTheRest => 'مستني باقي اللاعبين';

  @override
  String get onlineConfirmHold => 'دوس ثانيتين عشان تأكد';

  @override
  String get confrontationSilent => 'مفيش رد';

  @override
  String get confrontationAudience => 'بتسمع';

  @override
  String get settingVoteVisibility => 'التصويت';

  @override
  String get settingOpenVoting => 'تصويت مكشوف';

  @override
  String get settingSecretVoting => 'تصويت سري';

  @override
  String get settingOpenVotingHint => 'الأصوات بتظهر للكل أول بأول';

  @override
  String get witnessTitle => 'الشاهد';

  @override
  String get witnessEliminated => 'خرجت من المباراة';

  @override
  String get witnessSpectating => 'بتتفرج';

  @override
  String get witnessTabTable => 'الطاولة';

  @override
  String get witnessTabChat => 'الخارجين';

  @override
  String get witnessTabPrediction => 'توقعك';

  @override
  String get witnessTabRecord => 'اختياراتك';

  @override
  String get witnessChatHint => 'اكتب للخارجين…';

  @override
  String get witnessChatEmpty => 'مفيش كلام لسه';

  @override
  String get witnessChatWalled => 'اللي لسه لاعب مش هيشوف الكلام ده';

  @override
  String get witnessChatSend => 'ابعت';

  @override
  String get witnessPredictionWinner => 'مين هيكسب؟';

  @override
  String get witnessPredictionMafia => 'ومين المافيا؟';

  @override
  String get witnessPredictionLock => 'أكد توقعك';

  @override
  String get witnessPredictionLocked => 'توقعك اتسجل';

  @override
  String witnessPredictionScore(int correct, int total) {
    return 'توقعاتك الصح: $correct من $total';
  }

  @override
  String get witnessRecordEmpty => 'مفيش اختيارات متسجلة';

  @override
  String get onlineIntroPhoneTitle => 'دورك على شاشتك';

  @override
  String get onlineIntroPhoneBody =>
      'كارتك واختياراتك بيظهروا ليك بس كل واحد بيلعب من جهازه بكود الغرفة؛ الأوفلاين جهاز واحد بيتنقل بينكم ومن غير إنترنت.';

  @override
  String get onlineIntroNightTitle => 'الليل للكل في نفس الوقت';

  @override
  String get onlineIntroNightBody =>
      'اختار قبل ما العداد يخلص بالنهار تناقشوا وصوّتوا؛ المافيا تكسب لما عددها يبقى قد باقي الأحياء، والمواطنين يكسبوا بخروج كل المافيا. الصوت اختياري، واللعبة بتكمل من غيره.';

  @override
  String get onlineIntroWhisperTitle => 'رسالة خاصة';

  @override
  String get onlineIntroWhisperBody =>
      'الكل بيشوف مين بعت لمين والمستلم بس بيقرا الرسالة الرسائل الخاصة للأونلاين بس، ومش موجودة في الأوفلاين.';

  @override
  String get onlineIntroWitnessTitle => 'بعد الخروج';

  @override
  String get onlineIntroWitnessBody =>
      'تقدر تتابع المباراة وتكتب للاعبين اللي خرجوا ده متاح أونلاين؛ في الأوفلاين اللاعب اللي خرج مش بيمسك الجهاز تاني أثناء اللعب.';

  @override
  String get onlineIntroSkip => 'تخطي';

  @override
  String get onlineIntroStart => 'يلا';

  @override
  String get modeTitle => 'اختار طريقة اللعب';

  @override
  String get modeSubtitle => 'تقدروا تغيّروها المرة الجاية.';

  @override
  String get modeOnePhoneTitle => 'اوفلاين';

  @override
  String get modeOnePhoneBody => 'من 5 لـ15 لاعب';

  @override
  String get modeOnlineTitle => 'اونلاين';

  @override
  String get modeOnlineBody => 'من 5 لـ10 لاعبين';

  @override
  String get modeNoServer => 'الأونلاين مش متاح في النسخة دي';

  @override
  String get bulletMafia => 'الليلة الهادية';

  @override
  String get bulletDoctor => 'حماية النفس مرة';

  @override
  String testimonyGiven(String name, String suspect) {
    return 'شهادة $name: شكه كان على $suspect الليلة اللي فاتت.';
  }

  @override
  String testimonyNobody(String name) {
    return 'شهادة $name: ماشكش في حد الليلة اللي فاتت.';
  }

  @override
  String fileOpenedTitle(String name) {
    return '$name فتح الملف.';
  }

  @override
  String fileOpenedEntry(String name, String role) {
    return '$name — $role';
  }

  @override
  String get fileOpenedEmpty => 'الملف كان فاضي.';

  @override
  String get hintTalkers => 'اللي بيتكلم كتير مش دايمًا اللي بيخبّي.';

  @override
  String get hintQuickAgreement =>
      'خلي بالك مين بيوافق على طول من غير ما يفكر.';

  @override
  String get hintSilence => 'الصمت مش دليل. بس هو معلومة.';

  @override
  String get hintChangesMind => 'مين بيغيّر رأيه بسرعة لما يتضغط؟';

  @override
  String get hintEarlyAccuser => 'المافيا الشاطرة بتتهم بدري عشان تبان بريئة.';

  @override
  String get hintMajorityComfort =>
      'التصويت مع الأغلبية مريح. وده بالظبط اللي بيعتمدوا عليه.';

  @override
  String get hintWhoBenefited => 'مين استفاد من اللي مات امبارح؟';

  @override
  String get hintMafiaSuspicionSpreads =>
      'متقتلش اللي بيشك فيك على طول — شكه هيتنشر';

  @override
  String get hintMafiaQuietNight =>
      'الليلة الهادية بتجوّع الطاولة من المعلومات';

  @override
  String get hintMafiaSpeak => 'اتكلم. المافيا الساكتة بتموت';

  @override
  String get hintDoctorNoRepeat => 'متحميش نفس الشخص مرتين ورا بعض';

  @override
  String get hintDoctorSelf => 'حماية النفس معاك مرة واحدة — استناها';

  @override
  String get hintDoctorSaveReveals =>
      'لو نجحت في الحماية، المافيا هتعرف إن فيه دكتور';

  @override
  String get hintDetectiveInvestigateLoud =>
      'حقق في اللي بيتكلم كتير، مش في اللي ساكت';

  @override
  String get hintCitizenSuspicionCounts => 'شكك مش رايح على فاضي — بيتسجّل';

  @override
  String coachStuckOnInnocent(String name, int count) {
    return 'شكيت في $name $count ليالي وهو مواطن. جرب تغيّر رأيك أسرع لما الدليل ما يجيش.';
  }

  @override
  String coachConformity(int count, int total) {
    return 'صوّت مع الأغلبية $count من $total. جرب تكوّن رأيك قبل ما تسمع الباقي.';
  }

  @override
  String coachUnusedBullet(String bullet) {
    return 'ماستخدمتش «$bullet». كانت معاك من أول ليلة.';
  }

  @override
  String get coachNeverWhispered => 'ماهمستش ولا مرة. الهمسة بتبني تحالفات.';

  @override
  String coachAbandonedRead(String name) {
    return 'كنت شاكك في $name من أول الليالي وهو كان مافيا — وبعدين سبته. ثق في قراءتك الأولى.';
  }

  @override
  String coachQuiet(int seconds) {
    return 'اتكلمت $seconds ثانية في المباراة كلها — من أقل اللي اتكلموا. الصمت بيخلي الطاولة تشك فيك.';
  }

  @override
  String get coachSurvivedAsMafia => 'عشت للآخر من غير ما الطاولة تمسكك.';

  @override
  String get coachingTitle => 'كان ممكن';

  @override
  String get coachingEmpty => 'مفيش حاجة تتقال. لعبتها زي ما جت.';

  @override
  String get presetFast => 'سريعة';

  @override
  String get presetClassic => 'كلاسيكية';

  @override
  String get presetBrutal => 'قاسية';

  @override
  String get presetCustom => 'مخصصة';

  @override
  String get presetFastHint => 'وقت أقل وقواعد أبسط';

  @override
  String get presetClassicHint => 'دكتور ومحقق ووقت نقاش كامل';

  @override
  String get presetBrutalHint => 'مافيا أكتر ومن غير دكتور أو همس';

  @override
  String get presetLabel => 'نمط اللعب';

  @override
  String get settingPressureCurve => 'وقت أقل مع خروج اللاعبين';

  @override
  String get settingPressureCurveHint =>
      'مدة الكلام والنقاش بتقل مع عدد اللاعبين';

  @override
  String get settingDiscussionSeconds => 'مدة النقاش';

  @override
  String get settingPlayHints => 'تلميحات اللعب';

  @override
  String get settingCoaching => '«كان ممكن» بعد المباراة';

  @override
  String get settingRevealVictimRole => 'دور ضحية الليل';

  @override
  String get settingRevealVictimRoleHint => 'اظهار دور اللاعب اللي مات بالليل';

  @override
  String victimWasRole(String name, String role) {
    return '$name كان $role.';
  }

  @override
  String get nightSpecialMafia => 'مش هقتل الليلة';

  @override
  String get nightSpecialDoctor => 'احمي نفسك حالا';

  @override
  String get nightSpecialDetective => 'مش هحقق الليلة';

  @override
  String get nightSpecialCitizen => 'مش شاكك الليلة';

  @override
  String get settingsSectionPace => 'وقت اللعب';

  @override
  String get settingsSectionInformation => 'قواعد ومعلومات';

  @override
  String get settingsSectionReveal => 'اظهار الأدوار والرسائل';

  @override
  String get settingsSectionVoting => 'التصويت';

  @override
  String get settingsSectionAudio => 'الصوت';

  @override
  String get settingsOnlineOnly => 'في الأونلاين بس';

  @override
  String get settingSpeechSecondsHint => 'في النقاش بالدور';

  @override
  String get settingDiscussionSecondsHint => 'في النقاش الحر';

  @override
  String get settingIdentityHoldHint =>
      'نفس المدة لكل لاعب، عشان طول الدور ميقولش على الدور.';

  @override
  String get settingDiscussionModeHint => 'بالدور لكل لاعب وقت محدد';

  @override
  String get settingAbstainHint => 'تقدر تعدي من غير ما تصوت لحد';

  @override
  String get settingPlayHintsHint =>
      'سطر قصير في اللوبي والإعدادات بس. ولا حاجة جوه المباراة.';

  @override
  String get settingCoachingHint =>
      'بعد ما تخلصوا، التطبيق بيقول لكل واحد كان ممكن يعمل إيه.';

  @override
  String get settingMuteAllHint => 'الموسيقى والمؤثرات';

  @override
  String minutesSuffix(int minutes) {
    return '$minutes د';
  }

  @override
  String whisperFromTitle(String name) {
    return 'همسة من «$name»';
  }

  @override
  String get whisperDismiss => 'تمام';

  @override
  String get playerMale => 'ولد';

  @override
  String get playerFemale => 'بنت';

  @override
  String timelineMafiaVoteFemale(String actor, String target) {
    return '$actor صوتت على $target';
  }

  @override
  String timelineProtectFemale(String actor, String target) {
    return '$actor حمت $target';
  }

  @override
  String timelineInvestigateFemale(String actor, String target) {
    return '$actor كشفت $target';
  }

  @override
  String timelineSuspectFemale(String actor, String target) {
    return '$actor شكت في $target';
  }
}
