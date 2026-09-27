// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get onlineHostExitTitle => 'هتخرج من الأوضة؟';

  @override
  String get onlineHostExitBody =>
      'الأوضة تقدر تكمل والهوست ينتقل لأول لاعب موجود. قفل الأوضة بينهيها للجميع.';

  @override
  String get onlineLeaveKeepRoom => 'اخرج والأوضة تكمل';

  @override
  String get voiceEnablePlayback => 'تشغيل الصوت';

  @override
  String get onlineHistoryLabel => 'ماتش أونلاين';

  @override
  String onlineMatchMeta(int players, int day) {
    return '$players لاعبين · اليوم $day';
  }

  @override
  String get profileTitle => 'بروفايلك';

  @override
  String get profileHint =>
      'اختار اسمك وشخصيتك مرة واحدة. هنفتكرهم على الجهاز ده من غير تسجيل دخول.';

  @override
  String get profileSaveFailed =>
      'مقدرناش نحفظ البروفايل. اسمح بالتخزين في المتصفح وجرب تاني.';

  @override
  String get profileEdit => 'عدّل البروفايل';

  @override
  String get videoPlay => 'شغّل الشرح';

  @override
  String get videoFailed => 'الشرح مش راضي يشتغل هنا.';

  @override
  String get videoRetry => 'جرّب تاني';

  @override
  String get voiceRetry => 'شغّل الصوت';

  @override
  String get onlineNightPrivacyHint =>
      'الصوت مقفول وقت كشف الأدوار والليل لحماية سرية اللعب.';

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
  String get holdToRevealRole => 'دوس ثانيتين عشان تشوف كارتك';

  @override
  String teammatesLine(String names) {
    return 'معاك في المافيا: $names';
  }

  @override
  String get passPhoneTo => 'سلم الموبايل لـ';

  @override
  String iAmHoldInstruction(String name) {
    return 'أنا $name — دوس ثانيتين';
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
  String get holdToConfirmIdentity => 'دوس ثانيتين عشان تشوف كارتك';

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
  String get onlineNeedFivePlayers => 'محتاجين 5 لاعبين على الأقل';

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
  String publicRoomSeats(int players, int capacity) {
    return '$players/$capacity لاعب';
  }

  @override
  String publicRoomMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ناقص $count لاعب عشان المضيف يقدر يبدأ',
      few: 'ناقص $count لاعبين عشان المضيف يقدر يبدأ',
      two: 'ناقص لاعبين عشان المضيف يقدر يبدأ',
      one: 'ناقص لاعب واحد عشان المضيف يقدر يبدأ',
    );
    return '$_temp0';
  }

  @override
  String get publicRoomReady => 'العدد كفاية — البداية بقرار المضيف';

  @override
  String get publicRoomFullStatus => 'مليانة';

  @override
  String get publicRoomsStale =>
      'مش قادرين نحدّث القايمة دلوقتي. اللي قدامك آخر نسخة وصلتنا وممكن تكون قديمة.';

  @override
  String get publicRoomsUnavailable =>
      'مش قادرين نوصل للسيرفر عشان نجيب الأوض. هنحاول تاني لوحدنا.';

  @override
  String get onlineRoomStarted =>
      'الأوضة دي بدأت خلاص. اختار أوضة تانية من القايمة.';

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
  String get onlineFloorOpen => 'الكلام مفتوح، اطلب الدور';

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
  String get witnessTabTable => 'الترابيزة';

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

  @override
  String get onlineDiscardResume => 'انسى الأوضة';

  @override
  String get onlineStorageWarning =>
      'الجهاز مش قادر يحفظ. اللعبة شغالة عادي، بس ممكن ما يرجّعكش للأوضة لوحده ولا يحتفظ بالنتيجة.';

  @override
  String get safetyTitle => 'الخصوصية وحذف البيانات';

  @override
  String get safetyPolicy =>
      'المطوّر: Eyad Syam\nالدعم: eyadsyam124@gmail.com\n\nاللعب المحلي بيفضل على جهازك. الأونلاين يستخدم معرّفًا عشوائيًا والبروفايل وأفعال الماتش والرسائل. العملات والمكافآت والمحتوى المفتوح بيتحفظوا مع الهوية دي لحد الحذف. الصوت اختياري ومشفّر أثناء النقل واللعبة مبتسجلوش. خدمات التشغيل بتعالج بيانات الاتصال اللازمة للأونلاين. الإيميل بيتجمع بس لو اخترت تحمي حسابك.\n\nالإعلانات (أندرويد): Google AdMob ممكن يعرض إعلان عند فتح اللعبة أو لما ترجعلها بعد غياب طويل، وإعلان بملء الشاشة بين الماتشات — قبل ما تدخل أوضة، ولما تسيب ماتش خلص، وقبل توزيع الأدوار وبعد النتيجة في اللعب على موبايل واحد، أو أحيانًا وإنت بتتنقل بين القوايم بعد كام دقيقة من غير إعلان (أبدًا في نص الماتش ولا والموبايل بيتلف، بحد أقصى 40 في اليوم وبينهم 90 ثانية على الأقل)، وبانر صغير عليه علامة إعلان في شاشات الانتظار زي لوبي الأونلاين وسجل الماتشات والبروفايل (أبدًا أثناء اللعب)، وإعلانات مكافأة اختيارية بس لما تختار تتفرج عليها، بعد ماتش أونلاين مكتمل (عشان تضاعف عملاته أو تخليها 3 أضعاف) وفي الخزنة. عشان يعرض الإعلانات ويمنع الاحتيال، مكتبة إعلانات Google بتجمع عنوان الإنترنت والتفاعل مع الإعلانات والتطبيق وبيانات الأعطال ومعرّفات الجهاز زي Advertising ID. تقدر تغيّر موافقة الإعلانات من الإعدادات ← اختيارات خصوصية الإعلانات. الشراء في نسخة Play بيتم عن طريق Google Play Billing، وبنستلم رقم الطلب والمنتج ورمز الشراء عشان نتحقق منه، أو بتحويل إنستا باي / فودافون كاش، وفيه بترفع صورة التحويل واسم المحوِّل للمراجعة اليدوية (بيتخزنوا بشكل خاص، والصورة بتتمسح بعد 90 يوم من المراجعة).\n\nالغرف المنتهية مؤهلة للحذف بعد 24 ساعة، والهويات القديمة من غير غرف بتتحذف مع دورة التنظيف. تقدر تطلب حذف بيانات الأونلاين هنا؛ إرسال الطلب مش معناه إن الحذف اكتمل. من خارج التطبيق استخدم almafia.vercel.app/delete-data مع معرّفك أو رقم الطلب. متبعتش كلمة سر أو مفتاح وصول.\n\nممنوع التحرش والتهديد والكراهية والمحتوى الجنسي واستغلال الأطفال ومشاركة المعلومات الخاصة. بلّغ عن اللاعب أو اسم الغرفة أو الرسالة المسيئة. الحظر يخفي رسائله الخاصة ويكتم صوته عندك؛ أفعال اللعبة العامة تفضل ظاهرة. المطوّر بيراجع البلاغات وهي مش بتظهر للاعبين.';

  @override
  String get safetyAgree => 'أوافق على قواعد الاستخدام';

  @override
  String get safetyConsentTitle => 'قبل اللعب أونلاين';

  @override
  String get safetyConsentBody =>
      'ممنوع الإساءة والتحرّش والكراهية والمحتوى الجنسي ومشاركة البيانات الخاصة. تقدر تبلغ وتحظر من زر الأمان. الصوت اختياري؛ راجع الخصوصية في الإعدادات لمعرفة البيانات المستخدمة.';

  @override
  String get safetyReport => 'إرسال بلاغ';

  @override
  String get safetyBlock => 'حظر رسائل وصوت اللاعب';

  @override
  String get safetyRoom => 'اسم الغرفة أو محتواها';

  @override
  String get safetyDetails => 'وصف الإساءة أو الرسالة (بدون أسرار الدور)';

  @override
  String get safetyReceipt => 'تم استلام الطلب. احتفظ بالرقم:';

  @override
  String get safetyFailed => 'الطلب لم يُرسل. حاول مرة أخرى أو راسل الدعم.';

  @override
  String get safetyDelete => 'طلب حذف بيانات الأونلاين';

  @override
  String get safetyDeleteConfirm =>
      'سيتم إرسال طلب لحذف هويتك المجهولة وبيانات الأونلاين المرتبطة بها. سيُراجع المطوّر الطلب خلال 30 يومًا. نسخ اللاعبين على أجهزتهم منفصلة؛ البلاغات اللازمة لمنع الإساءة قد تُحتفظ بها لفترة محدودة. ملفاتك المحلية لا تُحذف بهذا الطلب.';

  @override
  String get safetyIdentity => 'عرض معرّف بياناتي';

  @override
  String get safetyBlocked => 'تم الحظر عندك.';

  @override
  String get safetyNoRoom => 'الإبلاغ والحظر متاحان داخل الغرفة.';

  @override
  String get safetyTools => 'الإبلاغ والحظر';

  @override
  String get onlineWelcome => 'الكراسي جاهزة. ناقصكم أنتم.';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get onlineNewRoomsPaused =>
      'إنشاء الغرف متوقف مؤقتًا. ما زال بإمكانك الانضمام لغرفة موجودة أو اللعب بدون إنترنت.';

  @override
  String get helpTitle => 'المساعدة والأسئلة الشائعة';

  @override
  String get helpIntro =>
      'إجابات سريعة عن اللعب والغرف الأونلاين والأمان وبياناتك.';

  @override
  String get helpPlayQuestion => 'الماتش بيمشي إزاي؟';

  @override
  String get helpPlayAnswer =>
      'اللعبة بتوزع الأدوار السرية وبتدير مراحل الليل والنهار وبتحسب التصويت. أهل البلد يحاولوا يكتشفوا المافيا، والمافيا تحاول تفضل لحد ما عددها يساوي أو يزيد عن أهل البلد. الهوست يقدر يراجع القواعد قبل البداية.';

  @override
  String get helpOnlineQuestion => 'الغرف الأونلاين بتشتغل إزاي؟';

  @override
  String get helpOnlineAnswer =>
      'اعمل غرفة وابعت الكود لصحابك، ادخل بكود، أو اختار غرفة عامة. السيرفر بيدير الماتش، ولو الهوست خرج التحكم بينتقل للاعب متصل تاني.';

  @override
  String get helpVoiceQuestion => 'الصوت إجباري؟';

  @override
  String get helpVoiceAnswer =>
      'لا. الصوت اختياري واللعبة مبتسجلوش. لو إذن الميكروفون أو نقل الصوت فشل، الماتش يكمل بأزرار اللعبة والنص المنظم.';

  @override
  String get helpReconnectQuestion => 'أعمل إيه لو الاتصال قطع؟';

  @override
  String get helpReconnectAnswer =>
      'افتح اللعبة تاني على نفس الجهاز واستخدم «كمّل الغرفة» لما تظهر. كرسيك بيرجع لو الغرفة لسه موجودة. متعملش بروفايل تاني عشان تسترجع كرسي في ماتش شغال.';

  @override
  String get helpSafetyQuestion => 'البلاغ والحظر بيعملوا إيه؟';

  @override
  String get helpSafetyAnswer =>
      'جوا الغرفة استخدم علامة البلاغ للإبلاغ عن لاعب أو محتوى الغرفة. الحظر بيخفي رسائله الخاصة ويكتم صوته عندك فورًا. البلاغ دليل للمراجعة، مش حكم آلي إن اللاعب مذنب.';

  @override
  String get helpCoinsQuestion => 'إيه هي العملات؟';

  @override
  String get helpCoinsAnswer =>
      'بتكسب العملات من ماتشات أونلاين مكتملة ومتحقق منها، وبتفتح محتوى عادل. مينفعش تسحبها أو تحولها أو تشتري بيها صوت أو معلومة سرية أو فرصة أكبر للفوز. العملات مرتبطة بهوية الأونلاين المجهولة على الجهاز ده.';

  @override
  String get helpPrivacyQuestion => 'الخصوصية وحذف البيانات فين؟';

  @override
  String get helpPrivacyAnswer =>
      'موجودين في شاشة الإعدادات تحت «الخصوصية وحذف البيانات». تقدر تشوف معرّف بياناتك المجهول وتطلب الحذف من هناك.';

  @override
  String get helpAgeQuestion => 'اللعب الأونلاين مناسب لمين؟';

  @override
  String get helpAgeAnswer =>
      'الصوت والغرف العامة الأونلاين موجهين لسن 16 سنة فأكتر. متشاركش عنوانك أو رقم تليفونك أو كلمات السر أو أي معلومات خاصة في الصوت أو الاسم أو الرسائل أو اسم الغرفة.';

  @override
  String get helpSupportQuestion => 'أتواصل مع الدعم إزاي؟';

  @override
  String get helpSupportAnswer =>
      'ابعت على eyadsyam124@gmail.com. ضيف رقم إيصال البلاغ أو معرّف بياناتك المجهول لو له علاقة بالمشكلة، ومتبعتش كلمة سر أو مفتاح وصول.';

  @override
  String get coinsTitle => 'العملات والمكافآت';

  @override
  String coinsBalance(int count) {
    return '$count عملة';
  }

  @override
  String get coinsEarnHint =>
      'كمّل ماتش أونلاين مؤهل واكسب 100 عملة، وكل لاعب في الفريق الفائز يكسب 25 زيادة. السيرفر هو اللي بيتأكد من المكافأة، ومبتغيرش التصويت أو الدور أو فرصة الفوز.';

  @override
  String get coinsLoadFailed =>
      'مقدرناش نحمّل عملاتك. مفيش حاجة اتخصمت؛ جرّب تاني.';

  @override
  String get coinsGuideTitle => 'مذكرة العقل المدبر';

  @override
  String get coinsGuideHint =>
      'دليل استراتيجي دائم لقراءة الترابيزة والدفاع عن قصتك، من غير ما يكشف أي معلومة سرية في ماتش شغال.';

  @override
  String coinsGuidePrice(int count) {
    return 'افتحها مقابل $count عملة';
  }

  @override
  String get coinsBuyGuide => 'تفتح المذكرة؟';

  @override
  String get coinsBuyConfirm =>
      'العملات المكتسبة هتتخصم نهائيًا من هوية الأونلاين المجهولة على الجهاز ده. المذكرة مبتغيرش الماتش ولا تزود فرصتك.';

  @override
  String get coinsUnlock => 'افتح';

  @override
  String get coinsGuideOpen => 'افتح المذكرة';

  @override
  String get coinsGuideContent =>
      'المواطن — تابع مين بيغير كلامه بعد التصويت، مش مين صوته أعلى. اطلب سبب واحد واضح وقارنه بالتصويت اللي بعده.\n\nالمافيا — خليك على موقف بسيط من بدري؛ الكذبة المعقدة بتعمل تفاصيل لازم تفتكرها. دافع عن مواطن أحيانًا، لأن الهجوم المستمر بيعمل نمط سهل.\n\nالدكتور — النجاة مش الهدف الوحيد. فكر أي حماية هتطلع معلومة مفيدة وواضحة لبكرة.\n\nالمحقق — معلومتك ملهاش قيمة لو الترابيزة مش هتعرف تستخدمها. سيب أثر منطقي قبل اتهام خطر، من غير ما تعلن دورك بدري.\n\nكل الأدوار — افصل بين اللي اللعبة أكدته واللي لاعب ادعاه. أقوى حجة هي اللي تفضل صحيحة بعد ظهور المعلومة اللي بعدها.';

  @override
  String adRewardAction(int count) {
    return 'شاهد إعلان وخد +$count عملة';
  }

  @override
  String get adRewardHint =>
      'اختياري بعد النتيجة فقط. مكافأتك الأصلية محفوظة حتى لو رفضت أو الإعلان فشل.';

  @override
  String get adRewardPending =>
      'الإعلان اكتمل. المكافأة الإضافية قيد تأكيد آمن وهتظهر تلقائيًا.';

  @override
  String adRewardGranted(int count) {
    return 'اتضافت $count عملة إضافية.';
  }

  @override
  String get adRewardUnavailable =>
      'مفيش إعلان متاح دلوقتي. مكافأتك الأصلية زي ما هي.';

  @override
  String get adRewardUsed => 'خدت مكافأة الإعلان للماتش ده.';

  @override
  String get privacyChoices => 'اختيارات خصوصية الإعلانات';

  @override
  String get privacyChoicesHint =>
      'راجع أو غيّر اختيارات الخصوصية اللي بيطلبها مزود الإعلانات.';

  @override
  String get premiumScenarioTitle => 'سيناريو مجلس الظلال';

  @override
  String get premiumScenarioHint =>
      'حزمة دائمة للمضيف: قواعد متوازنة، همسات ومواجهة وتصويت سري. لما المضيف يختارها كل الموجودين بيلعبوا السيناريو من غير ما يشتروا.';

  @override
  String get premiumScenarioBuy => 'اشترِ الحزمة';

  @override
  String get premiumScenarioOwned => 'الحزمة عندك';

  @override
  String get premiumScenarioRestore => 'استرجع مشترياتك';

  @override
  String get premiumScenarioPending => 'الشراء لسه قيد المعالجة في المتجر.';

  @override
  String get premiumScenarioFailed =>
      'مقدرناش نتحقق من الشراء. مفيش مبلغ هيتخصم من داخل اللعبة.';

  @override
  String get premiumScenarioUse => 'مجلس الظلال';

  @override
  String get premiumScenarioUseHint =>
      'إعدادات سيناريو متوازنة يفتحها المضيف لكل الغرفة.';

  @override
  String get shareResult => 'شارك النتيجة';

  @override
  String shareResultText(String winner, int days) {
    return 'ماتش سيد المافيا انتهى بفوز $winner بعد $days يوم. افتح رومك على https://almafia.vercel.app';
  }

  @override
  String get playAgainWithGroup => 'روم جديدة للشلة';

  @override
  String get setupWelcomeTitle => 'أهلاً بيك في سيد المافيا';

  @override
  String get setupWelcomeHint =>
      'اختار لغتك واسمك وتفضيلاتك مرة واحدة، وبعدها تلعب على طول.';

  @override
  String get setupPreferencesTitle => 'التفضيلات';

  @override
  String get setupPreferencesHint => 'تقدر تغيّرها بعدين من الإعدادات.';

  @override
  String get prefSound => 'أصوات اللعبة';

  @override
  String get prefMusic => 'الموسيقى';

  @override
  String get prefReduceMotion => 'تقليل الحركة';

  @override
  String get setupAdultConfirm => 'عمري 16 سنة أو أكتر';

  @override
  String get setupAdultHint =>
      'الأونلاين والصوت والأوض العامة لسن 16 سنة فأكتر.';

  @override
  String get termsAcceptPrefix => 'قرأت ';

  @override
  String get termsAcceptLink => 'الشروط والأحكام';

  @override
  String get termsAcceptSuffix => ' وأوافق عليها';

  @override
  String get privacyLinkLabel => 'سياسة الخصوصية';

  @override
  String get termsTitle => 'الشروط والأحكام';

  @override
  String termsVersion(String version) {
    return 'إصدار $version';
  }

  @override
  String get termsBody =>
      '1. سيد المافيا لعبة جماعية للتسلية. الأدوار والنتائج جزء من اللعبة وبس.\n\n2. اللعب الأونلاين والصوت والأوض العامة لمن عمرهم 16 سنة أو أكتر.\n\n3. ممنوع الإساءة والتحرش والتهديد وخطاب الكراهية والمحتوى الجنسي ونشر معلومات خاصة بأي حد. تقدر تبلّغ عن لاعب أو تحظره من أدوات الأمان.\n\n4. الصوت اختياري، واللعبة ما بتسجّلش الصوت. اللي بتقوله بيسمعه اللاعبين معاك، وما نقدرش نمنع حد من التسجيل بجهاز تاني.\n\n5. عملات المافيا عملة داخل اللعبة لفتح محتوى شكلي بس، زي الإطارات والثيمات وأسلوب الراوي. ملهاش قيمة نقدية، وما بتتحوّلش لفلوس، وما بتدّيش أي ميزة في اللعب أو التصويت أو الأدوار.\n\n6. تقدر تشتري العملات وممر الهدوء وحزمة البداية بالفلوس: في تطبيق أندرويد عن طريق Google Play Billing، وفي تطبيق أندرويد والموقع بتحويل إنستا باي أو فودافون كاش بنفس السعر. التحويل بيتراجع يدويًا خلال 72 ساعة؛ بترفع صورة التحويل واسم المحوِّل، والشراء بيتضاف بعد التأكد من وصول الفلوس بس. الصورة الواحدة تنفع لطلب واحد بس. الطلب المرفوض بيظهر سببه، والطلب اللي ما يتراجعش خلال 72 ساعة بينتهي.\n\n7. ممكن نوقف أوضة أو لاعب بيخالف الشروط. تقدر تطلب مسح بياناتك من الإعدادات.\n\n8. لو الشروط اتغيّرت تغيير مهم، هنطلب موافقتك تاني قبل ما تكمل.';

  @override
  String get privacySummaryBody =>
      '• اللعبة بتستخدم معرّف مجهول للأونلاين، ومش محتاجة رقم تليفون ولا تاريخ ميلاد عشان تلعب.\n\n• اسمك في اللعبة ونوع الصورة بيظهروا للاعبين معاك في الأوضة.\n\n• الصوت اختياري ومشفّر أثناء النقل، واللعبة ما بتسجّلهوش.\n\n• لو ربطت حسابك بإيميل عشان تحمي عملاتك، الإيميل بيستخدم لاستعادة الحساب بس.\n\n• نسخة أندرويد فيها إعلانات Google AdMob: إعلانات مكافأة اختيارية؛ وإعلانات تلقائية بملء الشاشة بين الماتشات بس — قبل ما تدخل أوضة (إنشاء، انضمام، أو روم جديدة للشلة)، ولما تسيب ماتش خلص، وقبل توزيع الأدوار وبعد النتيجة في اللعب على موبايل واحد، وأحيانًا وإنت بتتنقل بين القوايم بعد كام دقيقة من غير إعلان، وإعلان فتح على شاشة البداية — أبدًا أثناء الماتش، بحد أقصى 40 في اليوم وبينهم 90 ثانية على الأقل، ومفيش ولا واحد حوالين أول ماتش ليك؛ وبانرات صغيرة في شاشات الانتظار (اللوبي، قايمة الأوض، السجل، الخزنة، البروفايل) — أبدًا مش أثناء اللعب. ممر الهدوء بيشيل كل الإعلانات التلقائية. مكتبة إعلانات Google بتجمع عنوان الإنترنت والتفاعل وبيانات الأعطال ومعرّفات الجهاز زي Advertising ID.\n\n• الشراء في نسخة Play بيتم عن طريق Google Play Billing، وبنحتفظ برقم الطلب والمنتج ورمز الشراء عشان نتحقق منه. طلبات تحويل إنستا باي وفودافون كاش (في تطبيق أندرويد والموقع) بتتسجل بالمنتج والمبلغ والوسيلة وصورة التحويل اللي بترفعها واسم المحوِّل، للتحقق من الدفع بس؛ الصورة بتتخزن بشكل خاص وبتتمسح بعد 90 يوم من مراجعة الطلب، وسجل الطلب نفسه بيتحفظ للحسابات.\n\n• الأوض المنتهية بتتمسح بشكل دوري، وتقدر تطلب مسح بياناتك من الإعدادات.\n\n• رتبة المجلس وترتيب الأسبوع: مستواك بيظهر على كرسيك، واسمك في اللعبة ونوع الصورة والإطار ومستواك ونقط خبرة الأسبوع ممكن يظهروا في ترتيب الأسبوع العام. تقدر تخفي نفسك من الترتيب من صفحة البروفايل. سجل الماتشات اللي وراهم بيتحفظ 21 يوم.\n\nالسياسة الكاملة: almafia.vercel.app/privacy';

  @override
  String get termsUpdatedTitle => 'قبل ما تكمل';

  @override
  String get termsUpdatedHint =>
      'راجع الشروط ووافق عليها مرة واحدة. بياناتك وتقدمك محفوظين.';

  @override
  String get settingsLegalTitle => 'الشروط والخصوصية';

  @override
  String get launcherLabelPending => 'اسم الأيقونة هيتغير بعد ما تقفل اللعبة.';

  @override
  String get documentClose => 'رجوع';

  @override
  String get publicRoomWaitingTitle => 'أوضة انتظار جاهزة';

  @override
  String get publicRoomWaitingStatus => 'فاضية، وأول واحد يدخل هيبقى المضيف';

  @override
  String get onlineShareFailed =>
      'ماقدرناش نفتح المشاركة ولا ننسخ اللينك. قول كود الأوضة للاعبين.';

  @override
  String get coinsName => 'عملات المجلس';

  @override
  String get storeTitle => 'المتجر';

  @override
  String get storeTabShop => 'المتجر';

  @override
  String get storeTabCollection => 'مجموعتي';

  @override
  String get storeTabHistory => 'السجل';

  @override
  String get storeTabCoins => 'شراء عملات';

  @override
  String storeEarnTime(int count, int matches) {
    return '$count عملة = حوالي $matches ماتش أونلاين';
  }

  @override
  String get storeSectionIdentity => 'الهوية';

  @override
  String get storeSectionPacks => 'أجواء الأوضة';

  @override
  String get storeSectionNarrator => 'أساليب الحكاية';

  @override
  String get storeSectionBundles => 'الباقات';

  @override
  String get storePermanent => 'دائم';

  @override
  String get storeOwned => 'عندك';

  @override
  String get storeEquipped => 'مستخدم';

  @override
  String get storeEquip => 'استخدم';

  @override
  String get storeUnequip => 'شيل';

  @override
  String get storePreview => 'معاينة';

  @override
  String storeBuyFor(int count) {
    return 'اشتري بـ $count';
  }

  @override
  String storeBuyConfirmTitle(String item) {
    return 'تشتري $item؟';
  }

  @override
  String storeBuyConfirmBody(int count) {
    return 'هيتخصم $count عملة. المحتوى شكلي ودائم، وما بيغيّرش أي حاجة في اللعب.';
  }

  @override
  String storeNotEnough(int count) {
    return 'ناقصك $count عملة';
  }

  @override
  String storeBundleSaves(int count) {
    return 'بتوفّر $count عملة';
  }

  @override
  String get storeBundleOwnedAll => 'كل اللي فيها عندك';

  @override
  String storeBundleContents(String items) {
    return 'فيها: $items';
  }

  @override
  String get storeBought => 'اتضاف لمجموعتك';

  @override
  String get storeFailed => 'العملية ما تمّتش، ومفيش حاجة اتخصمت. جرّب تاني.';

  @override
  String get storeHostPackNote =>
      'لما المضيف يختار الأجواء، بتظهر لكل اللي في الأوضة من غير ما حد تاني يشتريها.';

  @override
  String get storePresentationNote =>
      'شكل وصوت بس. ما بيغيّرش القواعد ولا التصويت ولا الأدوار.';

  @override
  String get storeEmptyCollection => 'لسه ما اشتريتش حاجة.';

  @override
  String get storeEmptyHistory => 'لسه مفيش حركة.';

  @override
  String get historyMatchCompletion => 'ماتش أونلاين خلص';

  @override
  String get historyMatchWin => 'فوز';

  @override
  String historyCatalogSpend(String item) {
    return 'شراء: $item';
  }

  @override
  String historyCatalogRefund(String item) {
    return 'استرجاع: $item';
  }

  @override
  String get historyAdReward => 'مكافأة فيديو';

  @override
  String get historyCoinPurchase => 'شراء عملات';

  @override
  String get historyCoinPurchaseReversal => 'إلغاء شراء عملات';

  @override
  String get historyAdjustment => 'تعديل من الإدارة';

  @override
  String get cosmeticClassic => 'الكلاسيكي';

  @override
  String get cosmeticFrameGilded => 'إطار مذهّب';

  @override
  String get cosmeticFrameGildedDesc =>
      'إطار دهب منقوش بقناع صغير تحت صورتك، يشوفه كل اللاعبين.';

  @override
  String get cosmeticFrameCrimson => 'إطار قرمزي';

  @override
  String get cosmeticFrameCrimsonDesc =>
      'إطار فضي غامق بمينا قرمزي ودرع صغير تحت الصورة.';

  @override
  String get cosmeticFrameMoonlit => 'إطار ضوء القمر';

  @override
  String get cosmeticFrameMoonlitDesc => 'إطار فضي بارد بهلال صغير تحت الصورة.';

  @override
  String get cosmeticPlateNoir => 'لافتة نوار';

  @override
  String get cosmeticPlateNoirDesc =>
      'اسمك على لافتة فحمي بإطار فضي منقوش وطرفين دايريين.';

  @override
  String get cosmeticPlateGilded => 'لافتة مذهّبة';

  @override
  String get cosmeticPlateGildedDesc =>
      'اسمك على لافتة فحمي بحافة دهب وطرفين زي المروحة.';

  @override
  String get cosmeticPlateEmber => 'لافتة الجمر';

  @override
  String get cosmeticPlateEmberDesc =>
      'اسمك على لافتة فحمي بحافة قرمزي ودهب وطرفين مدببين.';

  @override
  String get cosmeticPackManor => 'القصر الليلي';

  @override
  String get cosmeticPackManorDesc =>
      'قاعة القصر بالشموع خلف الترابيزة مع ضباب خفيف، وانتقال ضوء شمعة بين المراحل العامة، وجملة افتتاح وختام مع صوت. بيظهر لكل اللي في الأوضة.';

  @override
  String get cosmeticPackOldTown => 'المدينة القديمة';

  @override
  String get cosmeticPackOldTownDesc =>
      'قاعة المدينة القديمة بلون حجر دافي خلف الترابيزة مع ضوء متطاير، وانتقال شعاع بيعدّي على الترابيزة، وجملة افتتاح وختام مع صوت. بيظهر لكل اللي في الأوضة.';

  @override
  String get cosmeticNarratorStoryteller => 'الحكّاء';

  @override
  String get cosmeticNarratorStorytellerDesc =>
      'راوي بيعلّق على كل مرحلة عامة بجملة قصيرة على الشاشة، نفس الجملة لكل اللاعبين. لو الصوت مقفول بتفضل الجمل مكتوبة.';

  @override
  String get cosmeticBundleCouncil => 'باقة المجلس';

  @override
  String get cosmeticBundleCouncilDesc =>
      'القصر الليلي والمدينة القديمة والحكّاء مع بعض.';

  @override
  String get cosmeticBundleIdentity => 'باقة الهوية';

  @override
  String get cosmeticBundleIdentityDesc =>
      'الإطارات التلاتة واللافتات التلاتة.';

  @override
  String get packManorIntro =>
      'أبواب القصر اتقفلت. محدش هيخرج قبل ما الحقيقة تبان.';

  @override
  String get packManorOutro => 'الشموع طفت، والقصر احتفظ بأسراره.';

  @override
  String get packOldTownIntro => 'المدينة القديمة صحيت على سر جديد.';

  @override
  String get packOldTownOutro => 'الشوارع هديت، والحكاية خلصت.';

  @override
  String get narratorNight => 'الليل نزل، وكل واحد في مكانه.';

  @override
  String get narratorMorning => 'النهار طلع، وفيه حاجات اتغيّرت.';

  @override
  String get narratorDiscussion => 'دلوقتي الكلام. مين عنده حجة؟';

  @override
  String get narratorVoting => 'القرار في إيد الجماعة.';

  @override
  String get narratorResult => 'الحكاية خلصت، والأسرار بانت.';

  @override
  String get roomPackLabel => 'أجواء الأوضة';

  @override
  String get roomNarratorLabel => 'الراوي';

  @override
  String get previewTransition => 'شوف الانتقال';

  @override
  String get previewSound => 'اسمع الصوت';

  @override
  String get previewIntro => 'الافتتاح';

  @override
  String get previewOutro => 'الختام';

  @override
  String get previewSampleName => 'سامي';

  @override
  String get onlineRoomRefreshHint =>
      'الأوض بتتحدّث تلقائيًا. اختار الأوضة اللي تناسبك.';

  @override
  String get onlineRoomsAll => 'كل الأوض';

  @override
  String get onlineRoomsNearlyReady => 'ناقص لاعب أو اتنين';

  @override
  String get onlineRoomsNoFilterMatches =>
      'مفيش أوض ناقصها لاعب أو اتنين دلوقتي. شوف كل الأوض أو اعزم صحابك.';

  @override
  String get onlineRoomVoiceOn => 'الصوت متاح';

  @override
  String get onlineRoomVoiceOff => 'الصوت مقفول';

  @override
  String get onlineLobbyInviteHint =>
      'شارك دعوة الأوضة مع صحابك عشان ينضمّوا لنفس الطاولة.';

  @override
  String get onlineLobbyHostReadyHint =>
      'العدد كافي. ابدأ لما الكل يبقى مستعد.';

  @override
  String get onlineLobbyGuestReadyHint =>
      'العدد كافي. مستنيين المضيف يبدأ الماتش.';

  @override
  String get onlineVoteSending => 'جاري إرسال صوتك…';

  @override
  String get onlineVoteReceived => 'صوتك اتسجّل. مستنيين التصويت يقفل.';

  @override
  String get onlineVoteResolving => 'التصويت اتقفل. مستنيين النتيجة.';

  @override
  String get onlineVoteSelectHint => 'اختار لاعب من الطاولة، وبعدها أكّد صوتك.';

  @override
  String get onlineConfirmSuspicion => 'تأكيد الاتهام';

  @override
  String get onlineBeginVoting => 'ابدأ التصويت';

  @override
  String get accountTitle => 'حماية الحساب';

  @override
  String get accountAnonymousHint =>
      'عملاتك ومشترياتك مربوطة بالجهاز ده بس. لو مسحت اللعبة أو غيّرت الموبايل ممكن تضيع. اربط إيميل عشان تقدر ترجعها. اللعب نفسه مش محتاج حساب.';

  @override
  String accountProtected(String email) {
    return 'حسابك محمي بـ $email';
  }

  @override
  String get accountLink => 'احمِ حسابي بإيميل';

  @override
  String get accountRecover => 'عندي حساب محمي قبل كده';

  @override
  String get accountEmail => 'الإيميل';

  @override
  String get accountSendCode => 'ابعت الكود';

  @override
  String get accountCode => 'الكود اللي وصلك على الإيميل';

  @override
  String get accountConfirm => 'تأكيد';

  @override
  String accountCodeSent(String email) {
    return 'بعتنا إيميل لـ $email. فيه يا كود من 6 أرقام (اكتبه تحت) يا لينك (افتحه وبعدين دوس «فتحت اللينك من الإيميل»). ممكن ياخد دقيقة، وبص في السبام لو ما لقيتوش.';
  }

  @override
  String get accountRecoverWarning =>
      'هتدخل على حسابك المحمي. العملات اللي على الجهاز ده من غير حساب مش هتتنقل له.';

  @override
  String get accountErrorEmail => 'الإيميل ده مش مكتوب صح.';

  @override
  String get accountErrorTaken =>
      'الإيميل ده مربوط بحساب تاني. استخدم «عندي حساب محمي قبل كده».';

  @override
  String get accountErrorCode => 'الكود مش صح أو خلص وقته. اطلب كود جديد.';

  @override
  String get accountErrorRate => 'طلبات كتير. استنى شوية وجرّب تاني.';

  @override
  String get accountErrorUnavailable => 'الخدمة مش متاحة دلوقتي. جرّب بعدين.';

  @override
  String get accountLinkOpened => 'فتحت اللينك من الإيميل';

  @override
  String get accountErrorLinkPending =>
      'الإيميل لسه ما اتأكدش. افتح اللينك اللي في الإيميل وبعدين دوس تاني.';

  @override
  String get accountErrorLinkElsewhere =>
      'اللينك بيدخّل المتصفح اللي فتحه، مش التطبيق ده. استخدم الكود اللي في الإيميل.';

  @override
  String get accountRecoverLinkNote =>
      'على جهاز جديد، الكود اللي من 6 أرقام بس هو اللي يدخّل التطبيق، واللينك مش هيدخّله. لو الإيميل مفيهوش كود، الاسترجاع بالكود هيشتغل أول ما نحدّث إيميلاتنا.';

  @override
  String get coinPacksUnavailable =>
      'شراء العملات مش متاح دلوقتي. العملات بتتكسب من الماتشات الأونلاين زي ما هي.';

  @override
  String get coinPacksNeedAccount =>
      'قبل أي دفع لازم تحمي حسابك بإيميل، عشان العملات المدفوعة تفضل معاك لو غيّرت الجهاز.';

  @override
  String coinPackCoins(int count) {
    return '$count عملة';
  }

  @override
  String coinPackPrice(String amount) {
    return '$amount جنيه';
  }

  @override
  String get coinPayMethod => 'طريقة الدفع';

  @override
  String get coinPayInstapay => 'إنستا باي';

  @override
  String get coinPayVodafone => 'فودافون كاش';

  @override
  String get coinPayMethodOff => 'مش متاحة دلوقتي';

  @override
  String get coinManualNotice =>
      'التحويل بيتراجع يدويًا، والعملات بتضاف بعد التأكد من وصوله';

  @override
  String get coinManualDetail =>
      'هتفتح صفحة الدفع برّه اللعبة، وممكن يفتح تطبيق البنك أو المحفظة. حوّل المبلغ المكتوب بالظبط، وارجع هنا اكتب رقم العملية. فتح الرابط أو الرجوع منه مش بيضيف عملات.';

  @override
  String coinCreateOrder(String amount) {
    return 'أكّد الطلب بـ $amount جنيه';
  }

  @override
  String coinOrderTitle(String reference) {
    return 'طلب $reference';
  }

  @override
  String coinOrderSummary(int coins, String amount, String method) {
    return '$coins عملة مقابل $amount جنيه عن طريق $method';
  }

  @override
  String coinOpenPayment(String method) {
    return 'افتح $method';
  }

  @override
  String get coinOpenFailed =>
      'المتصفح ما فتحش الصفحة. اسمح بالنوافذ الجديدة للموقع وجرّب تاني.';

  @override
  String get coinDesktopHint =>
      'لو على كمبيوتر وتطبيق المحفظة على موبايلك، افتح الموقع من الموبايل عشان تكمل التحويل.';

  @override
  String get coinSentTransfer => 'أرسلت التحويل';

  @override
  String get coinTransferReference => 'رقم العملية';

  @override
  String get coinPayerHint => 'اسم المحوِّل (اختياري)';

  @override
  String get coinClaimNote =>
      'ده بلاغ بإنك حوّلت، مش تأكيد. محدش هيطلب منك رقم سري أو كود.';

  @override
  String get coinCancelOrder => 'إلغاء الطلب';

  @override
  String get coinStatusAwaiting => 'مستني التحويل';

  @override
  String get coinStatusClaimed =>
      'تحت المراجعة. العملات هتتضاف بعد التأكد من وصول المبلغ.';

  @override
  String coinStatusNeedsInfo(String note) {
    return 'محتاجين توضيح: $note';
  }

  @override
  String coinStatusPaid(int coins) {
    return 'اتضافت $coins عملة';
  }

  @override
  String coinStatusRejected(String note) {
    return 'الطلب اترفض: $note';
  }

  @override
  String get coinStatusCancelled => 'الطلب اتلغى';

  @override
  String get coinStatusExpired =>
      'الطلب خلص وقته. لو كنت حوّلت بالفعل، اكتب رقم العملية وهيتراجع.';

  @override
  String coinStatusRefunded(String note) {
    return 'المبلغ اترجع: $note';
  }

  @override
  String get coinOrderFailed => 'الطلب ما اتسجلش. مفيش حاجة اتخصمت؛ جرّب تاني.';

  @override
  String get adminCoinsTitle => 'مراجعة التحويلات';

  @override
  String get adminNotAdmin => 'الحساب ده مش من حسابات الإدارة.';

  @override
  String get adminEmpty => 'مفيش طلبات مستنية مراجعة.';

  @override
  String get adminProviderTxn => 'رقم العملية في كشف الحساب';

  @override
  String get adminReceived => 'المبلغ اللي وصل (جنيه)';

  @override
  String get adminNote => 'ملاحظة للاعب';

  @override
  String get adminApprove => 'وصل، ضيف العملات';

  @override
  String get adminNeedsInfo => 'اطلب توضيح';

  @override
  String get adminReject => 'ارفض';

  @override
  String get adminRefund => 'رجّعت الفلوس';

  @override
  String get adminCheckFirst =>
      'راجع كشف البنك أو المحفظة بنفسك وطابق المبلغ والطريقة ورقم العملية قبل الموافقة. لو مش متأكد سيبه تحت المراجعة.';

  @override
  String get adminErrorAmount => 'المبلغ مش مطابق. اطلب توضيح أو ارفض.';

  @override
  String get adminErrorUsed => 'رقم العملية ده اتستخدم في طلب تاني.';

  @override
  String get adminErrorGeneric => 'ما اتنفذش. راجع الحقول وجرّب تاني.';

  @override
  String adminOrderLine(
    String reference,
    String account,
    String amount,
    String method,
    String claim,
  ) {
    return '$reference · $account · $amount جنيه · $method · مرجع اللاعب: $claim';
  }

  @override
  String get adminFilterOpen => 'للمراجعة';

  @override
  String get adminFilterPaid => 'المدفوعة';

  @override
  String get arrivalIdentityTitle => 'كرسيك وسط الحكاية';

  @override
  String get arrivalIdentityHint =>
      'اختار الاسم والشكل اللي أصحابك هيعرفوك بيهم.';

  @override
  String get arrivalWelcomeHint =>
      'دور سرّي. وشكوك حوالين الترابيزة. حكايتك بتبدأ هنا.';

  @override
  String get arrivalPactTitle => 'قبل أول ليلة';

  @override
  String arrivalStep(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get arrivalSaving => 'بنجهّز كرسيك…';

  @override
  String get councilInvitation => 'كل واحد عنده حكاية. هتصدّق مين؟';

  @override
  String get witnessTableLoading => 'بنفتحلك الترابيزة…';

  @override
  String get witnessTableNoActions => 'لسه محدش اختار حاجة بالليل';

  @override
  String witnessActionKill(String actor, String target) {
    return '$actor اختار يقتل $target';
  }

  @override
  String witnessActionProtect(String actor, String target) {
    return '$actor بيحمي $target';
  }

  @override
  String witnessActionInvestigate(String actor, String target) {
    return '$actor كشف على $target';
  }

  @override
  String witnessActionSuspect(String actor, String target) {
    return '$actor شاكك في $target';
  }

  @override
  String get onlineDiscussionLive => 'النقاش شغّال';

  @override
  String get witnessEventNight => 'الليل: كل واحد بيختار في السر';

  @override
  String witnessEventOpening(String name) {
    return '$name بيقول هو شاكك في مين';
  }

  @override
  String get witnessEventDiscussion => 'اللي لسه لاعبين بيتناقشوا';

  @override
  String get witnessEventVoting => 'التصويت شغّال';

  @override
  String get onlineAbandonedTitle => 'كل اللاعبين خرجوا';

  @override
  String get onlineAbandonedBody =>
      'مفيش حد فاضل على الترابيزة غيرك، فالماتش ده خلص. ارجع للرئيسية وابدأ أوضة جديدة.';

  @override
  String get nightCitizenRest => 'انت مواطن';

  @override
  String get nightCitizenRestSupport =>
      'أول ليلة مفيش عليك حاجة. استنى لحد ما الباقي يخلصوا، والنهار هيطلع.';

  @override
  String readyToVote(int ready, int living) {
    return 'جاهز للتصويت ($ready من $living)';
  }

  @override
  String readyToVoteWaiting(int ready, int living) {
    return 'مستني الباقي ($ready من $living)';
  }

  @override
  String get settingsSectionGeneral => 'عام';

  @override
  String get settingsRulesTitle => 'قواعد اللعب';

  @override
  String get settingsRulesHint =>
      'كل ماتش جديد بيبدأ بيها، وتقدر تغيّرها قبل أي ماتش.';

  @override
  String get settingsSectionMore => 'المساعدة والخصوصية';

  @override
  String get onlineRoomSettingsHint =>
      'أي تغيير بيوصل لكل اللي في الأوضة على طول.';

  @override
  String get vaultTitle => 'خزنة المجلس';

  @override
  String get vaultSubtitle => 'بصمتك في المجلس. أجواء على ذوقك.';

  @override
  String get storeFrames => 'إطارات الهوية';

  @override
  String get storeNameplates => 'لوحات الأسماء';

  @override
  String get storeBrowseNext => 'المزيد من المنتجات';

  @override
  String get storeBrowsePrevious => 'المنتجات السابقة';

  @override
  String get cosmeticPackArchive => 'أرشيف القمر';

  @override
  String get cosmeticPackArchiveDesc =>
      'أرشيف تحت ضوء القمر خلف الترابيزة بلون فضي هادي، وانتقال ضوء قمر بين المراحل العامة، وجملة افتتاح وختام مع صوت. بيظهر لكل اللي في الأوضة.';

  @override
  String get cosmeticNarratorKeeper => 'حارس الأسرار';

  @override
  String get cosmeticNarratorKeeperDesc =>
      'راوي رزين بلغة الأرشيف: جملة قصيرة مكتوبة مع نغمة في كل مرحلة عامة، نفس الجملة لكل اللاعبين. كلام مكتوب، مش صوت متسجّل.';

  @override
  String get cosmeticNarratorNoir => 'راوي الظلال';

  @override
  String get cosmeticNarratorNoirDesc =>
      'راوي نوار مختصر: جملة قصيرة مكتوبة مع نغمة في كل مرحلة عامة، نفس الجملة لكل اللاعبين. كلام مكتوب، مش صوت متسجّل.';

  @override
  String get cosmeticBundleNocturne => 'مجموعة الليل';

  @override
  String get cosmeticBundleNocturneDesc =>
      'أرشيف القمر وإطار ضوء القمر ولافتة نوار وحارس الأسرار مع بعض.';

  @override
  String get packArchiveIntro => 'الأرشيف فتح أبوابه تحت ضوء القمر.';

  @override
  String get packArchiveOutro => 'ضوء القمر انسحب، والملفات رجعت لرفوفها.';

  @override
  String get narratorKeeperNight => 'الدفتر اتقفل على صفحة الليل.';

  @override
  String get narratorKeeperMorning => 'صفحة النهار اتفتحت.';

  @override
  String get narratorKeeperDiscussion => 'كل كلمة ليها وزن. اتكلموا بحساب.';

  @override
  String get narratorKeeperVoting => 'المجلس هيسجّل قراره.';

  @override
  String get narratorKeeperResult => 'الدفتر اتقفل، والحكاية دخلت الأرشيف.';

  @override
  String get narratorNoirNight => 'المدينة نامت. الشوارع فاضية.';

  @override
  String get narratorNoirMorning => 'الصبح طلع. وكل واحد بيدوّر على الحقيقة.';

  @override
  String get narratorNoirDiscussion =>
      'كل واحد عنده حكاية. مين اللي بيقول الحق؟';

  @override
  String get narratorNoirVoting => 'لحظة القرار. كل صوت له تمن.';

  @override
  String get narratorNoirResult => 'القضية اتقفلت.';

  @override
  String get storeAboutCoins => 'عن العملات';

  @override
  String get storeInside => 'اللي جوّه';

  @override
  String storeBalance(int count) {
    return 'رصيدك $count عملة';
  }

  @override
  String get storeRoomArtNote =>
      'المشهد بيظهر خفيف ورا الترابيزة في المراحل العامة بس، وعمره ما بيظهر بالليل.';

  @override
  String get profileAddressLabel => 'نكلّمك بصيغة';

  @override
  String get profileAddressHint =>
      'العربي بيفرّق بين الولد والبنت، فبنكتب لك الأدوار والرسايل بالصيغة دي.';

  @override
  String onlinePlayingAs(String name) {
    return 'هتلعب باسم $name';
  }

  @override
  String get onlineNoPublicRoomsHint =>
      'اعمل أوضة وابعت الكود لصحابك، أو حدّث القائمة بعد شوية.';

  @override
  String get lobbyInviteFriends => 'ادعي صحابك';

  @override
  String get adStepsTitle => 'مكافأة اختيارية: لحد إعلانين';

  @override
  String adStepsDisclosure(int total) {
    return 'كل إعلان تكمّله بيتأكد وبيضيف عملاته، ولو وقفت بعد الأول بتفضل مكافأته ليك. الإعلانين مع بعض بيضيفوا +$total. مكافأة الماتش نفسها بتاعتك في كل الأحوال.';
  }

  @override
  String adStepAction(int step, int amount) {
    return 'إعلان $step من 2 · +$amount';
  }

  @override
  String adStepDone(int step, int amount) {
    return 'إعلان $step من 2 · اتضاف +$amount';
  }

  @override
  String adStepsComplete(int total) {
    return 'اتضافت +$total عملة مكافأة للماتش ده.';
  }

  @override
  String get adRewardCheckAgain => 'اتأكد تاني';

  @override
  String get adRewardNotConsented =>
      'الإعلانات محتاجة موافقتك الأول. تقدر تغيّرها من الإعدادات ← اختيارات خصوصية الإعلانات.';

  @override
  String get storeTabRewards => 'المكافآت';

  @override
  String get dailyTitle => 'مكافآت اليوم';

  @override
  String get dailyResetNote => 'اليوم الجديد بيبدأ الساعة 00:00 بتوقيت UTC.';

  @override
  String get dailyCofferTitle => 'صندوق اليوم';

  @override
  String dailyCofferBody(int amount) {
    return 'مجاني مرة كل يوم: +$amount من عملات المجلس.';
  }

  @override
  String dailyCofferClaim(int amount) {
    return 'افتح · +$amount';
  }

  @override
  String get dailyCofferClaimed => 'اتفتح النهارده. ارجع بكرة.';

  @override
  String dailyCofferGranted(int amount) {
    return 'اتضاف +$amount لعملاتك.';
  }

  @override
  String dailyWeekBonusGranted(int amount) {
    return 'اليوم السابع! +$amount مكافأة.';
  }

  @override
  String get dailyWheelTitle => 'العجلة المجانية';

  @override
  String get dailyWheelBody =>
      'لفة مجانية كل يوم. مابتكلفش حاجة وملهاش قيمة نقدية.';

  @override
  String get dailyWheelSpin => 'لف مجانًا';

  @override
  String dailyWheelResult(int amount) {
    return 'العجلة وقفت على +$amount.';
  }

  @override
  String dailyWheelDone(int amount) {
    return 'لفة النهارده: +$amount. اللفة الجاية بكرة.';
  }

  @override
  String get dailyWheelOdds => 'الاحتمالات بالظبط';

  @override
  String dailyWheelOddsRow(int coins) {
    return '+$coins عملة';
  }

  @override
  String dailyWheelPercent(String percent) {
    return '$percent٪';
  }

  @override
  String get dailyWeekTitle => 'كارت السبع أيام';

  @override
  String dailyWeekBody(int progress, int bonus) {
    return 'فتحت $progress من 7. كل يوم سابع تفتحه بيضيف +$bonus. اليوم اللي يفوتك مابيصفّرش حاجة.';
  }

  @override
  String get dailyAdTitle => 'إعلان اليوم (اختياري)';

  @override
  String dailyAdBody(int amount) {
    return 'إعلان اختياري واحد في اليوم مقابل +$amount عملة بالظبط.';
  }

  @override
  String dailyAdAction(int amount) {
    return 'اتفرج · +$amount';
  }

  @override
  String get dailyAdDone => 'خدت مكافأة إعلان النهارده.';

  @override
  String get dailyAdInMatch => 'متاح برّه الماتش.';

  @override
  String get dailyFailed => 'مقدرناش نوصل للخزنة. جرّب تاني.';

  @override
  String get dailyDayChanged => 'يوم جديد بدأ. اتحدّثت.';

  @override
  String get historyAdStep => 'إعلان مكافأة';

  @override
  String get historyDailyCoffer => 'صندوق اليوم';

  @override
  String get historyDailyWheel => 'العجلة المجانية';

  @override
  String get historyDailyWeek => 'مكافأة اليوم السابع';

  @override
  String get historyDailyAd => 'إعلان اليوم';

  @override
  String get historyPlayCoins => 'عملات اتشرت من Google Play';

  @override
  String get historyPlayReversal => 'استرداد Google Play';

  @override
  String get storeTabPlay => 'العملات والممر';

  @override
  String get quietPassTitle => 'ممر الهدوء';

  @override
  String get quietPassBody =>
      'دائم. بيشيل كل الإعلانات التلقائية: إعلان الفتح، والإعلانات قبل وبعد الماتشات وبين القوايم، وبانرات شاشات الانتظار. إعلانات المكافأة الاختيارية بتفضل موجودة لو عايزها. مفيش أي ميزة في اللعب.';

  @override
  String get quietPassOwned => 'ممر الهدوء مفعّل';

  @override
  String playPackTitle(int coins) {
    return '$coins من عملات المجلس';
  }

  @override
  String playBuy(String price) {
    return 'اشتري · $price';
  }

  @override
  String get playUnavailable => 'الشراء مش متاح على الجهاز ده دلوقتي.';

  @override
  String get playPending => 'الدفع قيد الانتظار. هيتضاف لما Google تأكده.';

  @override
  String get playVerified => 'الشراء اتأكد.';

  @override
  String get playFailed => 'الشراء ماكملش.';

  @override
  String get playAccountMismatch => 'الشراء ده تابع لحساب تاني.';

  @override
  String get playNeedsProtection =>
      'احمي حسابك بإيميل قبل الشراء، عشان أي حاجة تشتريها ماتضيعش لو غيّرت موبايلك.';

  @override
  String get playRestore => 'استرجاع المشتريات';

  @override
  String get playCoinsNote =>
      'عملات المجلس بتشتري حاجات شكلية بس. ملهاش قيمة نقدية ومابتدّيش أي ميزة.';

  @override
  String get playRefundRule =>
      'لو باقة عملات اترجع تمنها، عملاتها اللي ماتصرفتش بتتشال. اللي اتصرف منها بيبقى مبلغ الباقة الجاية بتسدّده الأول؛ العملات المكتسبة والحاجات اللي عندك ماحدش بياخدها.';

  @override
  String playDebtNotice(int coins) {
    return 'فيه استرداد قديم لسه مفتوح: أول $coins عملة تشتريها بتسدّده الأول.';
  }

  @override
  String get quietPassRefundRule =>
      'لو تمن الممر اترجع، الممر بيتشال؛ عملاتك وحاجاتك بتفضل زي ما هي.';

  @override
  String get storeTabCouncil => 'المجلس';

  @override
  String get councilRankTitle => 'رتبتك في المجلس';

  @override
  String councilLevel(int level) {
    return 'المستوى $level';
  }

  @override
  String councilXpProgress(int xp, int next) {
    return '$xp / $next نقطة خبرة';
  }

  @override
  String councilXpTotal(int xp) {
    return '$xp نقطة خبرة';
  }

  @override
  String get councilMaxLevel => 'قمة المجلس';

  @override
  String councilNextLevel(int coins) {
    return 'المستوى الجاي: +$coins';
  }

  @override
  String councilWeekXp(int xp) {
    return '$xp نقطة خبرة الأسبوع ده';
  }

  @override
  String get councilHowXp =>
      'كل ماتش أونلاين بتخلّصه بيجيبلك نقط خبرة، والفوز بيجيب أكتر.';

  @override
  String get councilFailed => 'مقدرناش نوصل للمجلس. جرّب تاني.';

  @override
  String get councilAttention => 'في حاجة مستنياك في الخزنة';

  @override
  String get contractsTitle => 'عقود النهارده';

  @override
  String get contractsReset => 'بتتجدد الساعة 00:00 بتوقيت UTC';

  @override
  String get contractFinishOne => 'خلّص ماتش';

  @override
  String contractFinishMany(int count) {
    return 'خلّص $count ماتشات';
  }

  @override
  String get contractTown => 'خلّص ماتش في صف المدينة';

  @override
  String get contractMafia => 'خلّص ماتش في صف المافيا';

  @override
  String get contractWinOne => 'اكسب ماتش';

  @override
  String contractWinMany(int count) {
    return 'اكسب $count ماتشات';
  }

  @override
  String get contractHost => 'استضيف ماتش لحد آخره';

  @override
  String get contractReunion => 'العب تاني مع حد لعبت معاه قبل كده';

  @override
  String contractProgress(int done, int target) {
    return '$done/$target';
  }

  @override
  String contractClaim(int coins) {
    return 'استلم +$coins';
  }

  @override
  String get contractClaimed => 'اتستلم';

  @override
  String contractsBonus(int coins) {
    return 'خلّص التلاتة: +$coins';
  }

  @override
  String get contractsBonusDone => 'التلاتة خلصوا';

  @override
  String contractBonusGranted(int coins) {
    return 'التلاتة! +$coins مكافأة.';
  }

  @override
  String get contractIncomplete => 'لسه — خلّص الماتش الأول.';

  @override
  String get weeklyTitle => 'عقد الأسبوع';

  @override
  String weeklyBody(int target) {
    return 'خلّص $target ماتشات أونلاين الأسبوع ده';
  }

  @override
  String weeklyReward(int coins, int xp) {
    return '+$coins عملة و$xp نقطة خبرة';
  }

  @override
  String weeklyRewardCoins(int coins) {
    return '+$coins عملة';
  }

  @override
  String get weeklyReset => 'بيتجدد يوم الاتنين 00:00 بتوقيت UTC';

  @override
  String get leaderboardTitle => 'الأعلى الأسبوع ده';

  @override
  String get leaderboardOpen => 'ترتيب الأسبوع';

  @override
  String leaderboardYou(int position) {
    return 'ترتيبك: $position';
  }

  @override
  String get leaderboardNone => 'العب ماتش عشان تدخل الترتيب';

  @override
  String get leaderboardEmpty => 'لسه محدش جاب نقط خبرة الأسبوع ده.';

  @override
  String get leaderboardHidden =>
      'انت مخفي من الترتيب؛ ترتيبك بيظهر ليك انت بس.';

  @override
  String get leaderboardVisibleLabel => 'اظهر في ترتيب الأسبوع';

  @override
  String get leaderboardVisibleBody =>
      'اسمك وشكلك ورتبتك بيظهروا في ترتيب الأسبوع. مفيش أي حاجة عن ماتشاتك بتظهر.';

  @override
  String get inviteTitle => 'ادعي صاحبك';

  @override
  String inviteBody(int inviter, int invitee) {
    return 'لما صاحبك يخلّص أول ماتش أونلاين: انت +$inviter وهو +$invitee.';
  }

  @override
  String get inviteCopy => 'انسخ الكود';

  @override
  String get inviteCopied => 'الكود اتنسخ';

  @override
  String get inviteShare => 'شارك';

  @override
  String inviteShareText(String code) {
    return 'تعالى العب معايا مافيا! استخدم كود الدعوة $code من تبويب المجلس في الخزنة.';
  }

  @override
  String inviteCounters(int rewarded, int cap, int pending) {
    return 'مكافآت: $rewarded/$cap · مستنيين: $pending';
  }

  @override
  String get inviteHaveCode => 'معاك كود دعوة؟';

  @override
  String get inviteField => 'كود الدعوة';

  @override
  String get inviteRedeem => 'استخدم الكود';

  @override
  String get inviteRedeemed =>
      'الدعوة اتسجلت. خلّص ماتش عشان المكافأتين يتفتحوا.';

  @override
  String get inviteRewarded => 'مكافأة الدعوة وصلت.';

  @override
  String get inviteNotFound => 'الكود ده مش موجود.';

  @override
  String get inviteSelf => 'مينفعش تستخدم الكود بتاعك.';

  @override
  String get inviteExpired => 'أكواد الدعوة للحسابات الجديدة بس، خلال 7 أيام.';

  @override
  String get inviteNotNew => 'أكواد الدعوة بتشتغل قبل أول ماتش ليك.';

  @override
  String get inviteAlready => 'انت استخدمت كود دعوة قبل كده.';

  @override
  String get inviteLoop =>
      'انت اللي دعيت اللاعب ده، مينفعش تستخدم الكود بتاعه.';

  @override
  String get inviteLimit => 'الكود ده وصل للحد الأقصى.';

  @override
  String get inviteRateLimit => 'محاولات كتير. جرّب بكرة.';

  @override
  String resultContractToast(String name, int coins) {
    return 'عقد خلص: $name +$coins';
  }

  @override
  String resultWeeklyToast(int coins) {
    return 'عقد الأسبوع خلص: +$coins';
  }

  @override
  String resultXpGained(int xp) {
    return '+$xp نقطة خبرة';
  }

  @override
  String get resultClaimHint => 'استلمهم من تبويب المجلس في الخزنة.';

  @override
  String levelUpTitle(String title) {
    return 'بقيت $title';
  }

  @override
  String levelUpBody(int level, int coins) {
    return 'المستوى $level · +$coins عملة';
  }

  @override
  String get rankTier1 => 'مبتدئ';

  @override
  String get rankTier2 => 'مخبر';

  @override
  String get rankTier3 => 'حارس الليل';

  @override
  String get rankTier4 => 'محقق';

  @override
  String get rankTier5 => 'وجيه';

  @override
  String get rankTier6 => 'عضو المجلس';

  @override
  String get rankTier7 => 'كابو';

  @override
  String get rankTier8 => 'مستشار';

  @override
  String get rankTier9 => 'شيخ المجلس';

  @override
  String get rankTier10 => 'عرّاب';

  @override
  String rankSemantics(String title, int level) {
    return '$title، المستوى $level';
  }

  @override
  String get bundleTitle => 'حزمة البداية';

  @override
  String bundleBody(int coins) {
    return '$coins عملة + إطار ختم المجلس، مش موجود في أي مكان تاني. مرة واحدة لكل حساب.';
  }

  @override
  String get bundleOwned => 'حزمة البداية عندك';

  @override
  String get bundleRefundRule =>
      'لو اترجعت فلوسها، العملات بتتحسب زي باقات العملات وإطار ختم المجلس بيتشال.';

  @override
  String get bundleAlreadyOwned =>
      'الحساب ده عنده حزمة البداية بالفعل؛ الشراء الزيادة Google Play بترجّع فلوسه.';

  @override
  String get cosmeticFrameSeal => 'ختم المجلس';

  @override
  String get cosmeticFrameSealDesc =>
      'حلقة ختم بلون الشمع الأحمر وتمن مسامير دهب — الإطار الخاص بحزمة البداية.';

  @override
  String get coinPayStep =>
      'اختار الباقة، وبعدين دوس على طريقة الدفع: صفحتها هتفتح. ارجع هنا برقم العملية.';

  @override
  String coinPayWith(String method) {
    return 'ادفع بـ$method';
  }

  @override
  String get webPassTitle => 'ممر الهدوء لتطبيق أندرويد';

  @override
  String get webPassBody =>
      'الموقع مفيهوش إعلانات. الممر بيشيل كل الإعلانات التلقائية في تطبيق أندرويد (إعلان الفتح، وبعد الماتش، والبانرات) على نفس الحساب المربوط. إعلانات المكافأة الاختيارية بتفضل موجودة.';

  @override
  String get webPassOwned => 'ممر الهدوء شغال على الحساب ده';

  @override
  String coinOrderPassSummary(String price, String method) {
    return 'ممر الهدوء · $price جنيه · $method';
  }

  @override
  String get awardsTitle => 'جوايز الماتش';

  @override
  String get awardMvp => 'نجم الماتش';

  @override
  String get awardSharpEye => 'العين الحادة';

  @override
  String get awardSurvivor => 'الناجي';

  @override
  String get awardSilverTongue => 'اللسان الذهبي';

  @override
  String get awardLifesaver => 'المنقذ';

  @override
  String get awardPerfectCrime => 'الجريمة الكاملة';

  @override
  String get awardFirstBlood => 'أول كشف';

  @override
  String get awardMvpBody => 'أحسن لاعب في الفريق الكسبان';

  @override
  String get awardSharpEyeBody => 'أكتر واحد صوّت على المافيا';

  @override
  String get awardSurvivorBody => 'فضل لحد الآخر';

  @override
  String get awardSilverTongueBody => 'أقنع الترابيزة معاه';

  @override
  String get awardLifesaverBody => 'الدكتور أنقذ حد';

  @override
  String get awardPerfectCrimeBody => 'المافيا كسبت من غير ما حد يتكشف';

  @override
  String get awardFirstBloodBody => 'أول صوت كشف المافيا';

  @override
  String awardsYouEarned(int coins) {
    return 'جوايزك: +$coins عملة';
  }

  @override
  String get awardsLoading => 'بنحسب الجوايز';

  @override
  String get reactionsLabel => 'ريأكشنز';

  @override
  String get reactionLaugh => 'ضحك';

  @override
  String get reactionShock => 'صدمة';

  @override
  String get reactionSuspicious => 'شاكك';

  @override
  String get reactionApplause => 'تسقيف';

  @override
  String get reactionRose => 'وردة';

  @override
  String get reactionSkull => 'جمجمة';

  @override
  String get reactionCoffee => 'قهوة';

  @override
  String get reactionCrown => 'تاج';

  @override
  String reactionFrom(String name, String reaction) {
    return '$name: $reaction';
  }

  @override
  String get reactionSlowDown => 'بالراحة، واحدة واحدة';

  @override
  String get welcomeBackTitle => 'وحشتنا';

  @override
  String get welcomeBackBody => 'صندوقك اليومي مستنيك في الخزنة.';

  @override
  String get welcomeBackBodyPlain => 'الترابيزة جاهزة وقت ما تحب.';

  @override
  String get welcomeBackOpen => 'افتح الخزنة';

  @override
  String get welcomeBackDismiss => 'بعدين';

  @override
  String get founderBadge => 'مؤسس';

  @override
  String get founderBadgeBody => 'من أوائل لاعبين المجلس';

  @override
  String shareCardAwards(String awards) {
    return 'الجوايز: $awards';
  }

  @override
  String get adBannerLabel => 'إعلان';

  @override
  String get adExtrasTitle => 'إضافات اختيارية';

  @override
  String get adExtrasBody =>
      'كل واحدة إعلان اختياري واحد، مرة في اليوم. مفيش حاجة هنا بتأثر على اللعب.';

  @override
  String get adExtraSpinTitle => 'لفة تانية';

  @override
  String get adExtraSpinBody =>
      'بعد لفة النهارده المجانية: لفة كمان، بنفس الاحتمالات، والسيرفر هو اللي بيختار.';

  @override
  String adExtraSpinOdds(String odds) {
    return 'الاحتمالات: $odds';
  }

  @override
  String get adExtraSpinAction => 'اتفرج · لف تاني';

  @override
  String get adExtraSpinNotReady => 'لف العجلة المجانية بتاعة النهارده الأول.';

  @override
  String adExtraSpinResult(int amount) {
    return 'اللفة التانية: +$amount عملة.';
  }

  @override
  String get adExtraCofferTitle => 'ضاعف خزنة النهارده';

  @override
  String adExtraCofferAction(int amount) {
    return 'اتفرج · +$amount';
  }

  @override
  String get adExtraCofferNotReady => 'افتح خزنة النهارده الأول.';

  @override
  String adExtraCofferDone(int amount) {
    return 'الخزنة اتضاعفت: +$amount';
  }

  @override
  String get adExtraSwapTitle => 'بدّل عقد';

  @override
  String get adExtraSwapBody =>
      'بدّل عقد من عقود النهارده اللي لسه ما خدتش مكافأته بعقد تاني.';

  @override
  String get adExtraSwapAction => 'اختار · اتفرج';

  @override
  String get adExtraSwapPick => 'تبدّل أنهي عقد؟';

  @override
  String adExtraSwapSlot(int number) {
    return 'العقد $number';
  }

  @override
  String get adExtraSwapDone => 'العقد اتبدّل';

  @override
  String get adExtraNoneLeft => 'مفيش حاجة تتبدّل النهارده.';

  @override
  String get adExtraUsed => 'اتستخدمت النهارده';

  @override
  String get vaultOneTime => 'مرة واحدة بس';

  @override
  String get vaultBestValue => 'الأوفر';

  @override
  String get vaultMostCoins => 'أكبر باقة';

  @override
  String get coinPickPackFirst =>
      'اختار باقة من فوق الأول، وبعدين طريقة الدفع.';

  @override
  String get adDoubleTitle => 'مكافأة اختيارية: ضاعف الماتش ده أو خليه 3 أضعاف';

  @override
  String adDoubleAction(int total) {
    return 'اتفرج على إعلان · ضاعفها لـ $total';
  }

  @override
  String adTripleAction(int total) {
    return 'إعلان كمان · 3 أضعاف لـ $total';
  }

  @override
  String adDoubleDone(int total) {
    return 'اتضاعفت · $total عملة';
  }

  @override
  String adTripleDone(int total) {
    return 'بقت 3 أضعاف · $total عملة';
  }

  @override
  String adTripleComplete(int total) {
    return 'الماتش ده بقى بـ $total عملة.';
  }

  @override
  String adDoubleDisclosure(int base, int doubled, int tripled) {
    return 'الماتش ده جابلك $base. إعلان واحد يتأكد يخليها $doubled، والتاني يخليها $tripled. لو وقفت بعد الأول الضعف بيفضل ليك. مكافأة الماتش نفسها بتاعتك في كل الأحوال.';
  }

  @override
  String payWithGoogle(String price) {
    return 'ادفع بجوجل · $price';
  }

  @override
  String get pay2TabTransfer => 'إنستا باي / فودافون كاش';

  @override
  String get pay2AlreadyOwned => 'الحساب ده عنده ده بالفعل.';

  @override
  String get pay2TooMany =>
      'عندك طلبين مستنيين المراجعة. تقدر تعمل طلب جديد لما واحد فيهم يتراجع.';

  @override
  String get pay2Duplicate =>
      'الصورة دي اتستخدمت في طلب قبل كده. ارفع صورة التحويل ده بالذات.';

  @override
  String get pay2ProofRequired => 'لازم صورة التحويل واسم المحوِّل الاتنين.';

  @override
  String get pay2StepChoose => 'اختار المنتج وطريقة الدفع';

  @override
  String get pay2StepPayHint =>
      'لما تدوس على طريقة الدفع هتفتح برّه اللعبة. حوّل المبلغ بالظبط وارجع هنا.';

  @override
  String pay2StepPay(String amount, String method) {
    return 'حوّل $amount جنيه بالظبط من $method';
  }

  @override
  String get pay2StepProof => 'ارجع هنا وارفع صورة التحويل';

  @override
  String get pay2PickImage => 'اختار صورة التحويل';

  @override
  String get pay2ImageChosen => 'الصورة جاهزة · غيّرها';

  @override
  String get pay2ImageFailed => 'ما قدرناش نقرأ الصورة دي. جرّب صورة تانية.';

  @override
  String pay2SenderName(String method) {
    return 'اسم المحوِّل زي ما ظاهر في $method بالظبط';
  }

  @override
  String get pay2Submit => 'ابعت للمراجعة';

  @override
  String get pay2Sent =>
      'اتبعت. بنراجعه بإيدينا، والعملات بتتضاف بعد التأكد من وصول المبلغ.';

  @override
  String pay2OrderSummary(String product, String amount, String method) {
    return '$product · $amount جنيه · $method';
  }

  @override
  String get pay2StatusAwaiting => 'مستني صورة التحويل';

  @override
  String get pay2StatusPending => 'تحت المراجعة';

  @override
  String get pay2StatusApproved => 'اتقبل';

  @override
  String get pay2StatusExpired =>
      'انتهت مهلته: ما اتراجعش خلال 72 ساعة. لو كنت دفعت، كلّم الدعم برقم الطلب.';

  @override
  String get pay2OrdersTitle => 'طلباتك';

  @override
  String get pay2ReviewDetail =>
      'نفس سعر جوجل بلاي. الطلبات بتتراجع بإيد خلال 72 ساعة، ولو اترفض الطلب السبب بيظهر هنا.';

  @override
  String get pay2ProofPrivacy =>
      'الصورة واسم المحوِّل بيتخزنوا بشكل خاص للتحقق من الطلب بس، والصورة بتتمسح بعد 90 يوم من المراجعة. محدش هيطلب منك رقم سري أو كود.';

  @override
  String get adminPaymentsTitle => 'طلبات الدفع';

  @override
  String get adminSignInHint =>
      'سجّل دخول بإيميل الإدارة. الإيميل فيه يا كود لمرة واحدة يا لينك؛ لو فتحت اللينك في المتصفح ده الصفحة هتدخل لوحدها.';

  @override
  String adminSignedInAs(String email) {
    return 'داخل باسم $email';
  }

  @override
  String get adminWebOnly => 'صفحة الإدارة متاحة على الموقع بس.';

  @override
  String get adminFilterPending => 'للمراجعة';

  @override
  String get adminFilterApproved => 'المقبولة';

  @override
  String get adminFilterRejected => 'المرفوضة';

  @override
  String get adminFilterExpired => 'المنتهية';

  @override
  String get adminRejectReason => 'سبب الرفض (هيظهر للاعب)';

  @override
  String get adminReasonRequired => 'اكتب السبب الأول.';

  @override
  String get adminProofGone => 'الصورة اتمسحت (مدة الاحتفاظ)';

  @override
  String get adminApproveShort => 'قبول';

  @override
  String get adminRejectShort => 'رفض';

  @override
  String get adminRefundShort => 'استرجاع';

  @override
  String adminOrderMeta(String product, String amount, String method) {
    return '$product · $amount جنيه · $method';
  }

  @override
  String adminSender(String name) {
    return 'المحوِّل: $name';
  }

  @override
  String adminPlayer(String name) {
    return 'اللاعب: $name';
  }

  @override
  String get adminErrorOwned => 'اللاعب عنده ده بالفعل. ارفض ورجّع الفلوس.';

  @override
  String get adminErrorProof => 'الطلب ده مفيهوش صورة.';
}
