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
  String get back => 'رجوع';

  @override
  String get cancel => 'إلغاء';

  @override
  String get deleteAction => 'حذف';

  @override
  String get continueAction => 'متابعة';

  @override
  String get listSeparator => '، ';

  @override
  String get newMatch => 'مباراة جديدة';

  @override
  String get history => 'السجل';

  @override
  String get settings => 'الإعدادات';

  @override
  String get addPlayersTitle => 'أضف اللاعبين';

  @override
  String get seatingOrderSubtitle => 'بالترتيب الجلوس';

  @override
  String get playerNameHint => 'اسم اللاعب';

  @override
  String get addPlayer => 'إضافة';

  @override
  String playerCountLine(int count) {
    return 'عدد اللاعبين: $count';
  }

  @override
  String get noPlayersYet => 'لم تضف أي لاعب بعد';

  @override
  String get next => 'التالي';

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
  String get balanceValid => 'التوزيع صحيح!';

  @override
  String get balancePlayerCountTooLow => 'يجب أن يكون عدد اللاعبين 5 على الأقل';

  @override
  String get balancePlayerCountTooHigh => 'يجب ألا يتجاوز عدد اللاعبين 20';

  @override
  String get balanceNegativeRoleCount => 'لا يمكن أن يكون عدد الأدوار سالبًا';

  @override
  String get balanceRoleCountMismatch =>
      'مجموع الأدوار يجب أن يساوي عدد اللاعبين';

  @override
  String get balanceNoMafia => 'لازم يكون في مافيا واحد على الأقل';

  @override
  String get balanceMafiaTooMany => 'عدد المافيا لازم يكون أقل من نص اللاعبين';

  @override
  String get balanceRecommendThreeMafia =>
      'الأفضل تختار 3 مافيا لما تكونوا 9 لاعبين أو أكتر';

  @override
  String get balanceTwoDetectivesLowPlayerCount =>
      'تحذير: اختيار اثنين من المحققين مع أقل من 11 لاعبًا قد يعطي فرصة عالية جدًا للمدينة';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get speechSecondsLabel => 'وقت الكلام (بالثواني)';

  @override
  String secondsSuffix(int seconds) {
    return '$seconds ث';
  }

  @override
  String get discussionModeLabel => 'طريقة النقاش';

  @override
  String get discussionStructured => 'منظم (أدوار محددة)';

  @override
  String get discussionFree => 'حر (بدون أدوار)';

  @override
  String get dayTieRuleLabel => 'قاعدة التعادل في النهار';

  @override
  String get tieRevote => 'إعادة تصويت';

  @override
  String get tieNoElimination => 'بدون إقصاء';

  @override
  String get narrationEnabledLabel => 'تفعيل السرد الصوتي';

  @override
  String get abstainAllowedLabel => 'السماح بعدم التصويت';

  @override
  String get save => 'حفظ';

  @override
  String get nightApproaching => 'الليل يقترب';

  @override
  String get nightLabel => 'الليلة';

  @override
  String get aliveCountLabel => 'لاعبون على الحياة';

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
  String get roleMafiaDescription =>
      'كل ليلة تتفق مع باقي المافيا على حد تقتلوه. وميعرفش عنك حد.';

  @override
  String get roleDoctorDescription =>
      'كل ليلة تحمي لاعب واحد — ومينفعش تحمي نفس الشخص ليلتين ورا بعض.';

  @override
  String get roleDetectiveDescription =>
      'كل ليلة تكشف لاعب واحد وتعرف لو مافيا. النتيجة تظهرلك إنت بس، ومرة واحدة.';

  @override
  String get roleCitizenDescription =>
      'مالكش قدرة خاصة. سلاحك إنك تلاحظ وتتكلم.';

  @override
  String get gotIt => 'فهمت';

  @override
  String get holdToRevealRole => 'اضغط مع الاستمرار لكشف دورك';

  @override
  String teammatesLine(String names) {
    return 'معاك في المافيا: $names';
  }

  @override
  String get passPhoneTo => 'مرّر الهاتف إلى';

  @override
  String iAmHoldInstruction(String name) {
    return 'أنا $name — اضغط مع الاستمرار';
  }

  @override
  String notYouNamed(String name) {
    return 'لست $name؟';
  }

  @override
  String get yourTurn => 'دورك';

  @override
  String get holdToConfirm => 'اضغط مع الاستمرار للتأكيد';

  @override
  String get notYou => 'لست أنت؟';

  @override
  String get takeYourTime => 'خذ وقتك في القراءة';

  @override
  String get choosePlayer => 'اختر لاعبًا';

  @override
  String get confirmAction => 'تأكيد';

  @override
  String get choiceRecorded => 'تم تسجيل اختيارك';

  @override
  String get keepPhoneUntilUnlock => 'أبقِ الهاتف معك حتى يُفتح زر التمرير';

  @override
  String get passPhone => 'مرّر الهاتف';

  @override
  String get waitEllipsis => 'انتظر…';

  @override
  String get nightPromptMafia => 'مين عايز تقتله الليلة؟';

  @override
  String get nightPromptDoctor => 'مين عايز تحميه الليلة؟';

  @override
  String get nightPromptDetective => 'مين عايز تكشفه الليلة؟';

  @override
  String get nightPromptCitizen => 'مين شاكك فيه الليلة دي؟';

  @override
  String get notEveryoneSurvived => 'لم ينجُ الجميع';

  @override
  String lostPlayerLastNight(String name) {
    return '$name اتقتل الليلة اللي فاتت.';
  }

  @override
  String get quietNight => 'ليلة هادئة';

  @override
  String get someoneSavedBody => 'المافيا حاولت تقتل، بس حد نجا. مش هنقول مين.';

  @override
  String get noLossesBody => 'مرّت الليلة دون خسائر.';

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
  String get currentSpeaker => 'المتحدث الآن';

  @override
  String speakersRemaining(int count) {
    return 'متبقي: $count';
  }

  @override
  String get skip => 'تخطي';

  @override
  String get endDiscussion => 'إنهاء النقاش';

  @override
  String get resume => 'متابعة';

  @override
  String get pause => 'إيقاف';

  @override
  String get votingSubtitle => 'التصويت';

  @override
  String get whoDoYouVoteOut => 'مين تصوّت على طرده؟';

  @override
  String get abstain => 'امتناع';

  @override
  String get confirmVote => 'تأكيد الصوت';

  @override
  String eliminatedHeadline(String name) {
    return 'خرج $name';
  }

  @override
  String get tieRevoteHeadline => 'تعادل — إعادة التصويت';

  @override
  String get tieNoEliminationHeadline => 'تعادل — لم يخرج أحد';

  @override
  String get nobodyEliminated => 'لم يخرج أحد';

  @override
  String wasRole(String role) {
    return 'كان $role';
  }

  @override
  String get revote => 'إعادة التصويت';

  @override
  String get gameOver => 'نهاية اللعبة';

  @override
  String get mafiaWins => 'المافيا كسبت';

  @override
  String get townWins => 'الشعب كسب';

  @override
  String get analytics => 'التحليلات';

  @override
  String get homeAction => 'الرئيسية';

  @override
  String get endMatchTitle => 'إنهاء المباراة؟';

  @override
  String get endMatchBody => 'ستفقد تقدّم هذه المباراة ولن تظهر في السجل.';

  @override
  String get keepPlaying => 'متابعة اللعب';

  @override
  String get endAction => 'إنهاء';

  @override
  String get endMatchTooltip => 'إنهاء المباراة';

  @override
  String get unfinishedMatchTitle => 'لديك مباراة غير مكتملة';

  @override
  String unfinishedMatchBody(int count, String where) {
    return '$count لاعبين. $where';
  }

  @override
  String resumeFromPassTo(String name) {
    return 'ستُستأنف من تمرير الهاتف إلى $name.';
  }

  @override
  String resumeFromDay(int day) {
    return 'ستُستأنف من اليوم $day.';
  }

  @override
  String get endMatch => 'إنهاء المباراة';

  @override
  String get resumeAction => 'استئناف';

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
  String get analyticsLoadFailed => 'تعذّر فتح تحليلات المباراة';

  @override
  String seatFallback(int seat) {
    return 'مقعد $seat';
  }

  @override
  String get tabEvents => 'الأحداث';

  @override
  String get tabPlayers => 'اللاعبون';

  @override
  String get tabSuspicions => 'الشكوك';

  @override
  String get tabAchievements => 'الإنجازات';

  @override
  String timelineMafiaVote(String actor, String target) {
    return '$actor صوّت على $target';
  }

  @override
  String timelineProtect(String actor, String target) {
    return '$actor حمى $target';
  }

  @override
  String timelineInvestigate(String actor, String target) {
    return '$actor حقّق مع $target';
  }

  @override
  String timelineSuspect(String actor, String target) {
    return '$actor اشتبه في $target';
  }

  @override
  String timelineNightKill(String target) {
    return 'قُتل $target ليلًا';
  }

  @override
  String timelineSaved(String target) {
    return 'نجا $target من محاولة اغتيال';
  }

  @override
  String timelineDayElimination(String target) {
    return 'الشعب صوّت على طرد $target';
  }

  @override
  String get noEventsRecorded => 'لا توجد أحداث مسجّلة';

  @override
  String get noPlayerData => 'لا توجد بيانات لاعبين';

  @override
  String get noSuspicionsByPlayer => 'لم يسجّل أي اشتباه';

  @override
  String suspicionAccuracyLine(int correct, int total) {
    return 'دقة الاشتباه: $correct/$total';
  }

  @override
  String get noSuspicionsRecorded => 'لم يُسجَّل أي اشتباه';

  @override
  String get noAchievements => 'لا توجد إنجازات';

  @override
  String get achievementSharpestEye => 'العين الثاقبة';

  @override
  String get achievementSharpestEyeDescription =>
      'أعلى دقة في الاشتباهات خلال الليل';

  @override
  String get achievementUntouchable => 'الناجي';

  @override
  String get achievementUntouchableDescription => 'نجا حتى نهاية اللعبة';

  @override
  String get achievementGuardian => 'الحامي';

  @override
  String get achievementGuardianDescription => 'منع هجوم المافيا بالحماية';

  @override
  String get achievementFirstBlood => 'أول ضحية';

  @override
  String get achievementFirstBloodDescription =>
      'أول من تم القضاء عليه في الليل الأول';

  @override
  String get achievementSurvivors => 'الناجون';

  @override
  String get achievementSurvivorsDescription => 'انتهت اللعبة';

  @override
  String get historyTitle => 'السجل';

  @override
  String get deleteMatchTitle => 'حذف المباراة؟';

  @override
  String get deleteMatchBody => 'سيتم حذف التحليلات نهائيًا.';

  @override
  String get noPastMatches => 'لا توجد مباريات سابقة';

  @override
  String get mafiaWon => 'المافيا كسبت';

  @override
  String get townWon => 'الشعب كسب';

  @override
  String get endedWithoutResult => 'انتهت دون نتيجة';

  @override
  String matchMeta(int players, int nights) {
    return '$players لاعبين · $nights ليالٍ';
  }

  @override
  String get holdToConfirmIdentity => 'دوس واستني عشان تشوف كارتك';

  @override
  String get swipeToReveal => 'اسحب الكارت في أي اتجاه عشان يتقلب';

  @override
  String get passThePhone => 'سلّم الموبايل';

  @override
  String get phaseNightFalls => 'الضلمة نزلت على البلد… كله يغمّض';

  @override
  String get phaseMorningSomeoneDied => 'الصبح جه… والبلد صحيت على خبر وحش';

  @override
  String get phaseMorningNobodyDied => 'الصبح جه… ومحدش مات النهارده';

  @override
  String get phaseVoting => 'الشعب هيقرر… ومفيش رجوع';

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
      'المواطنين بيدوروا على المافيا ويصوّتوا يطلعوهم برّه.\nوالمافيا بتقتل واحد كل ليلة لحد ما تخلص على البلد.';

  @override
  String get rulesRolesTitle => 'الأدوار';

  @override
  String get rulesDayTitle => 'مرحلة النهار';

  @override
  String get rulesDayBody =>
      '1. النقاش: كل واحد بيتكلم ويدافع عن نفسه.\n2. الاتهام: كل واحد بيوجّه شكّه لحد.\n3. التصويت: الجماعة بتقرر مين يطلع برّه.';

  @override
  String get rulesNightTitle => 'مرحلة الليل';

  @override
  String get rulesNightBody =>
      'كل واحد بياخد الموبايل لوحده وبيعمل دوره:\n— المافيا: بيتفقوا على حد يقتلوه.\n— المحقق: بيختار حد يكشفه.\n— الدكتور: بيختار حد يحميه.\n— المواطن: بيمرّر الموبايل من غير ما يعمل حاجة.';

  @override
  String get rulesWinTitle => 'شروط الفوز';

  @override
  String get rulesWinBody =>
      'المواطنين بيكسبوا: لو كل المافيا طلعوا برّه.\nالمافيا بتكسب: لو عددهم بقى قد المواطنين.';

  @override
  String get rulesTipsTitle => 'نصايح';

  @override
  String get rulesTipsBody =>
      '— راقب ردود فعل الناس وهما بيتكلموا.\n— متكشفش دورك بسرعة لو إنت محقق أو دكتور.\n— لو إنت مافيا، حاول توجّه الشك لغيرك.\n— الدكتور مينفعش يحمي نفس الشخص مرتين ورا بعض.\n— متبصّش في موبايل حد تاني، ومتسلّمش الموبايل وهو مفتوح على كارت.';

  @override
  String get audioSettingsLabel => 'الصوتيات';

  @override
  String get muteAllAudio => 'اقفل كل الأصوات';

  @override
  String get scoreEnabledLabel => 'الموسيقى ورا اللعب';

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
  String get saveGroupTitle => 'سمّي المجموعة';

  @override
  String get renameAction => 'إعادة تسمية';

  @override
  String get renameGroupTitle => 'إعادة تسمية المجموعة';

  @override
  String get deleteGroupTitle => 'حذف المجموعة؟';

  @override
  String get deleteGroupBody => 'هتتشال خالص. المباريات القديمة مش هتتأثر.';

  @override
  String get quickStartAction => 'ابدأ فوراً';

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
  String get saveGroupOrderTitle => 'تحفظ ترتيب القعدة الجديد؟';

  @override
  String saveGroupOrderBody(String group) {
    return 'النهارده $group قعدوا بترتيب تاني.';
  }

  @override
  String get addAction => 'ضيف';

  @override
  String get onboardingTitle => 'أول جولة';

  @override
  String get onboardingNext => 'التالي';

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
      'بلد صغيرة بتنام كل ليلة، وتصحى الصبح ناقصة واحد.\nفيه ناس بينهم مش زي ما بيقولوا — والباقي لازم يكشفوهم قبل ما البلد تخلص.';

  @override
  String get onboardingRolesTitle => 'الأدوار';

  @override
  String get onboardingRolesBody =>
      'أربع كروت. كل واحد بياخد كارت واحد ومحدش يعرف كارت التاني.\nدوس على أي كارت تحت تعرف بيعمل إيه.';

  @override
  String get onboardingNightTitle => 'الليل';

  @override
  String get onboardingNightBody =>
      'الموبايل بيلف على الكل واحد واحد. كل واحد بيفتحه لوحده، يعمل دوره، ويقفله ويمرّره.\nالمافيا بتختار حد، الدكتور بيحمي حد، والمحقق بيكشف حد.';

  @override
  String get onboardingDayTitle => 'النهار';

  @override
  String get onboardingDayBody =>
      'الصبح الموبايل بيتحط في نص الترابيزة ويقول مين راح.\nبعدها الكلام مفتوح بمؤقّت، وفي الآخر تصويت — والتطبيق هو اللي بيعدّ.';

  @override
  String get onboardingPassTitle => 'الموبايل';

  @override
  String get onboardingPassBody =>
      'دي اللعبة اللي بتتكسب وتتخسر من إيدك مش من الشاشة:\n— امسك الموبايل مايل ناحيتك، وخلي ضهره لباقي الترابيزة.\n— متبصّش في موبايل حد وهو ماسكه.\n— متغيّرش وشّك وإنت شايف كارتك.\n— متسلّمش الموبايل وهو مفتوح على حاجة.';

  @override
  String get onboardingSecrecyTitle => 'السرّ محفوظ';

  @override
  String get onboardingSecrecyBody =>
      'التطبيق شغلته الوحيدة طول المباراة إنه ميفضحش حاجة. الغش في اللعبة دي مالوش طريق غير إنك تعرف حاجة محدش قالهالك.\n— كل دور بياخد نفس الوقت، وبنفس إضاءة الشاشة، وبنفس الشكل، مهما كان الكارت اللي معاك.\n— الموبايل مبيطلّعش أي صوت وهو في إيد حد.\n— الكارت بيتقفل لوحده بعد كام ثانية، والموبايل عمره ما بيتسلّم وهو مفتوح على حاجة.\n— المجموعة المحفوظة بتفتكر الأسامي والترتيب بس. عمرها ما بتفتكر مين كان إيه.';

  @override
  String get onboardingWinTitle => 'الفوز';

  @override
  String get onboardingWinBody =>
      'المواطنين بيكسبوا لما آخر مافيا يطلع برّه بالتصويت.\nوالمافيا بتكسب لما عددهم يبقى قد المواطنين.\nكده إنت عارف كل حاجة — الباقي كلام وشكّ.';
}
