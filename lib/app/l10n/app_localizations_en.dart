// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mafia Master';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteAction => 'Delete';

  @override
  String get continueAction => 'Continue';

  @override
  String get listSeparator => ', ';

  @override
  String get newMatch => 'New match';

  @override
  String get history => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get addPlayersTitle => 'Add players';

  @override
  String get seatingOrderSubtitle => 'In seating order';

  @override
  String get playerNameHint => 'Player name';

  @override
  String get addPlayer => 'Add';

  @override
  String playerCountLine(int count) {
    return 'Players: $count';
  }

  @override
  String get noPlayersYet => 'No players added yet';

  @override
  String get next => 'Next';

  @override
  String seatNumber(int seat) {
    return 'Seat #$seat';
  }

  @override
  String get rolesTitle => 'Role setup';

  @override
  String playerCountShort(int count) {
    return '$count players';
  }

  @override
  String get roleGroupMafia => 'Mafia';

  @override
  String get roleGroupDetective => 'Detective';

  @override
  String get roleGroupDoctor => 'Doctor';

  @override
  String get roleGroupCitizen => 'Citizen';

  @override
  String get balanceValid => 'Balanced setup';

  @override
  String get balancePlayerCountTooLow => 'You need at least 5 players';

  @override
  String get balancePlayerCountTooHigh =>
      'You cannot have more than 20 players';

  @override
  String get balanceNegativeRoleCount => 'A role count cannot be negative';

  @override
  String get balanceRoleCountMismatch =>
      'Role counts must add up to the number of players';

  @override
  String get balanceNoMafia => 'There must be at least one Mafia';

  @override
  String get balanceMafiaTooMany => 'Mafia must be fewer than half the players';

  @override
  String get balanceRecommendThreeMafia =>
      '3 Mafia is recommended at 9 or more players';

  @override
  String get balanceTwoDetectivesLowPlayerCount =>
      'Warning: two Detectives below 11 players heavily favours the town';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get speechSecondsLabel => 'Speaking time (seconds)';

  @override
  String secondsSuffix(int seconds) {
    return '${seconds}s';
  }

  @override
  String get discussionModeLabel => 'Discussion mode';

  @override
  String get discussionStructured => 'Structured (turn by turn)';

  @override
  String get discussionFree => 'Free (no turns)';

  @override
  String get dayTieRuleLabel => 'Day tie rule';

  @override
  String get tieRevote => 'Revote';

  @override
  String get tieNoElimination => 'No elimination';

  @override
  String get narrationEnabledLabel => 'Enable narration';

  @override
  String get abstainAllowedLabel => 'Allow abstaining';

  @override
  String get save => 'Save';

  @override
  String get nightApproaching => 'Night is falling';

  @override
  String get nightLabel => 'Night';

  @override
  String get aliveCountLabel => 'Players alive';

  @override
  String get placePhoneOnTable =>
      'Put the phone on the table and wait for the signal';

  @override
  String get beginNight => 'Begin night';

  @override
  String get distributionSubtitle => 'Role distribution';

  @override
  String get roleMafia => 'Mafia';

  @override
  String get roleDoctor => 'Doctor';

  @override
  String get roleDetective => 'Detective';

  @override
  String get roleCitizen => 'Citizen';

  @override
  String get roleMafiaDescription =>
      'Each night you agree with the rest of the mafia on someone to kill. Let nobody find out.';

  @override
  String get roleDoctorDescription =>
      'Each night you protect one player — and never the same person two nights running.';

  @override
  String get roleDetectiveDescription =>
      'Each night you uncover one player\'s role. Only you see the result, and only once.';

  @override
  String get roleCitizenDescription =>
      'You have no special power. Observation and argument are your weapons.';

  @override
  String get gotIt => 'Got it';

  @override
  String get holdToRevealRole => 'Press and hold to reveal your role';

  @override
  String teammatesLine(String names) {
    return 'With you in the mafia: $names';
  }

  @override
  String get passPhoneTo => 'Pass the phone to';

  @override
  String iAmHoldInstruction(String name) {
    return 'I am $name — press and hold';
  }

  @override
  String notYouNamed(String name) {
    return 'Not $name?';
  }

  @override
  String get yourTurn => 'Your turn';

  @override
  String get holdToConfirm => 'Press and hold to confirm';

  @override
  String get notYou => 'Not you?';

  @override
  String get takeYourTime => 'Take your time reading';

  @override
  String get choosePlayer => 'Choose a player';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get choiceRecorded => 'Your choice is recorded';

  @override
  String get keepPhoneUntilUnlock =>
      'Keep the phone until the pass button unlocks';

  @override
  String get passPhone => 'Pass the phone';

  @override
  String get waitEllipsis => 'Wait…';

  @override
  String get nightPromptMafia => 'Who do you kill tonight?';

  @override
  String get nightPromptDoctor => 'Who do you want to protect tonight?';

  @override
  String get nightPromptDetective => 'Whose cards do you want to see tonight?';

  @override
  String get nightPromptCitizen => 'Whose behaviour do you doubt tonight?';

  @override
  String get notEveryoneSurvived => 'Not everyone made it';

  @override
  String lostPlayerLastNight(String name) {
    return '$name was killed last night.';
  }

  @override
  String get quietNight => 'A quiet night';

  @override
  String get someoneSavedBody =>
      'The mafia tried to kill, but someone survived. We will not say who.';

  @override
  String get noLossesBody => 'The night passed without losses.';

  @override
  String morningOfDay(int day) {
    return 'Morning of day $day';
  }

  @override
  String get startDiscussion => 'Start discussion';

  @override
  String get discussionTitle => 'Discussion';

  @override
  String get discussionFreeTitle => 'Open discussion';

  @override
  String get currentSpeaker => 'Speaking now';

  @override
  String speakersRemaining(int count) {
    return 'Remaining: $count';
  }

  @override
  String get skip => 'Skip';

  @override
  String get endDiscussion => 'End discussion';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get votingSubtitle => 'Voting';

  @override
  String get whoDoYouVoteOut => 'Who do you vote out?';

  @override
  String get abstain => 'Abstain';

  @override
  String get confirmVote => 'Confirm vote';

  @override
  String eliminatedHeadline(String name) {
    return '$name is out';
  }

  @override
  String get tieRevoteHeadline => 'Tied — revote';

  @override
  String get tieNoEliminationHeadline => 'Tied — nobody is out';

  @override
  String get nobodyEliminated => 'Nobody is out';

  @override
  String wasRole(String role) {
    return 'Was $role';
  }

  @override
  String get revote => 'Revote';

  @override
  String get gameOver => 'Game over';

  @override
  String get mafiaWins => 'The Mafia wins';

  @override
  String get townWins => 'The town wins';

  @override
  String get analytics => 'Analytics';

  @override
  String get homeAction => 'Home';

  @override
  String get endMatchTitle => 'End the match?';

  @override
  String get endMatchBody =>
      'You will lose this match\'s progress and it will not appear in History.';

  @override
  String get keepPlaying => 'Keep playing';

  @override
  String get endAction => 'End';

  @override
  String get endMatchTooltip => 'End the match';

  @override
  String get unfinishedMatchTitle => 'You have an unfinished match';

  @override
  String unfinishedMatchBody(int count, String where) {
    return '$count players. $where';
  }

  @override
  String resumeFromPassTo(String name) {
    return 'It will resume by passing the phone to $name.';
  }

  @override
  String resumeFromDay(int day) {
    return 'It will resume from day $day.';
  }

  @override
  String get endMatch => 'End the match';

  @override
  String get resumeAction => 'Resume';

  @override
  String nightNumbered(int number) {
    return 'Night $number';
  }

  @override
  String dayNumbered(int number) {
    return 'Day $number';
  }

  @override
  String get analyticsTitle => 'Analytics';

  @override
  String get analyticsLoadFailed => 'Could not open this match\'s analytics';

  @override
  String seatFallback(int seat) {
    return 'Seat $seat';
  }

  @override
  String get tabEvents => 'Events';

  @override
  String get tabPlayers => 'Players';

  @override
  String get tabSuspicions => 'Suspicions';

  @override
  String get tabAchievements => 'Achievements';

  @override
  String timelineMafiaVote(String actor, String target) {
    return '$actor voted for $target';
  }

  @override
  String timelineProtect(String actor, String target) {
    return '$actor protected $target';
  }

  @override
  String timelineInvestigate(String actor, String target) {
    return '$actor investigated $target';
  }

  @override
  String timelineSuspect(String actor, String target) {
    return '$actor suspected $target';
  }

  @override
  String timelineNightKill(String target) {
    return '$target was killed in the night';
  }

  @override
  String timelineSaved(String target) {
    return '$target survived an attempt';
  }

  @override
  String timelineDayElimination(String target) {
    return 'The town voted $target out';
  }

  @override
  String get noEventsRecorded => 'No events recorded';

  @override
  String get noPlayerData => 'No player data';

  @override
  String get noSuspicionsByPlayer => 'Recorded no suspicions';

  @override
  String suspicionAccuracyLine(int correct, int total) {
    return 'Suspicion accuracy: $correct/$total';
  }

  @override
  String get noSuspicionsRecorded => 'No suspicions were recorded';

  @override
  String get noAchievements => 'No achievements';

  @override
  String get achievementSharpestEye => 'Sharpest Eye';

  @override
  String get achievementSharpestEyeDescription =>
      'Highest suspicion accuracy through the nights';

  @override
  String get achievementUntouchable => 'Survivor';

  @override
  String get achievementUntouchableDescription =>
      'Survived to the end of the game';

  @override
  String get achievementGuardian => 'Guardian';

  @override
  String get achievementGuardianDescription =>
      'Blocked a Mafia attack with a protection';

  @override
  String get achievementFirstBlood => 'First Blood';

  @override
  String get achievementFirstBloodDescription =>
      'The first player lost in the night';

  @override
  String get achievementSurvivors => 'Survivors';

  @override
  String get achievementSurvivorsDescription => 'The game is over';

  @override
  String get historyTitle => 'History';

  @override
  String get deleteMatchTitle => 'Delete this match?';

  @override
  String get deleteMatchBody => 'Its analytics will be permanently removed.';

  @override
  String get noPastMatches => 'No past matches';

  @override
  String get mafiaWon => 'Mafia won';

  @override
  String get townWon => 'Town won';

  @override
  String get endedWithoutResult => 'Ended without a result';

  @override
  String matchMeta(int players, int nights) {
    return '$players players · $nights nights';
  }

  @override
  String get holdToConfirmIdentity => 'Press and hold to see your card';

  @override
  String get swipeToReveal => 'Swipe right to flip the card';

  @override
  String get passThePhone => 'Pass the phone';

  @override
  String get phaseNightFalls =>
      'Darkness falls on the town… everyone close your eyes';

  @override
  String get phaseMorningSomeoneDied =>
      'Morning has come… and the town woke to bad news';

  @override
  String get phaseMorningNobodyDied => 'Morning has come… nobody died today';

  @override
  String get phaseVoting =>
      'The people will decide… and there is no going back';

  @override
  String get phaseMafiaWins => 'The Mafia took over the town';

  @override
  String get phaseTownWins => 'The people have won';

  @override
  String get identityHoldLabel => 'Hold time before the card';

  @override
  String identityHoldSuffix(int seconds) {
    return '${seconds}s';
  }

  @override
  String get startGame => 'Start the game';

  @override
  String get howToPlay => 'How to play';

  @override
  String get tapCardHint => 'Tap any card to see what it does';

  @override
  String get howToPlayTitle => 'How to play';

  @override
  String get rulesTitle => 'Game rules';

  @override
  String get rulesGoalTitle => 'The goal';

  @override
  String get rulesGoalBody =>
      'The townspeople look for the mafia and vote them out.\nThe mafia kill one person a night until the town is finished.';

  @override
  String get rulesRolesTitle => 'The roles';

  @override
  String get rulesDayTitle => 'Day phase';

  @override
  String get rulesDayBody =>
      '1. Discussion: everyone speaks and defends themselves.\n2. Accusation: everyone points their suspicion at someone.\n3. Vote: the group decides who goes.';

  @override
  String get rulesNightTitle => 'Night phase';

  @override
  String get rulesNightBody =>
      'Each player takes the phone alone and does their part:\n— Mafia: agree on someone to kill.\n— Detective: choose someone to check.\n— Doctor: choose someone to protect.\n— Citizen: pass the phone on without doing anything.';

  @override
  String get rulesWinTitle => 'Winning';

  @override
  String get rulesWinBody =>
      'The town wins if every mafia is voted out.\nThe mafia win once they equal the number of townspeople.';

  @override
  String get rulesTipsTitle => 'Tips';

  @override
  String get rulesTipsBody =>
      '— Watch how people react while they talk.\n— Do not reveal yourself early if you are the detective or the doctor.\n— If you are mafia, steer suspicion elsewhere.\n— The doctor may not protect the same person twice running.\n— Never look at anyone else\'s screen, and never hand the phone on with a card showing.';

  @override
  String get audioSettingsLabel => 'Audio';

  @override
  String get muteAllAudio => 'Mute all sounds';

  @override
  String get scoreEnabledLabel => 'Background score';

  @override
  String get muteNarrator => 'Mute narrator';

  @override
  String get narratorPlaceholder => 'Voice will be recorded later';

  @override
  String get groupsTitle => 'Who is playing?';

  @override
  String get newGroupAction => 'New group';

  @override
  String groupMeta(int members, int plays) {
    return '$members players · played $plays times';
  }

  @override
  String groupMetaNeverPlayed(int members) {
    return '$members players · not played yet';
  }

  @override
  String get saveGroupPrompt => 'Save these as a group?';

  @override
  String get saveAction => 'Save';

  @override
  String get notNowAction => 'Not now';

  @override
  String get groupNameHint => 'Group name';

  @override
  String groupNameDefault(int number) {
    return 'Group $number';
  }

  @override
  String get saveGroupTitle => 'Name this group';

  @override
  String get renameAction => 'Rename';

  @override
  String get renameGroupTitle => 'Rename group';

  @override
  String get deleteGroupTitle => 'Delete group?';

  @override
  String get deleteGroupBody =>
      'The roster is removed. Past matches are not affected.';

  @override
  String get quickStartAction => 'Start now';

  @override
  String get presentAction => 'Here';

  @override
  String get absentAction => 'Away';

  @override
  String get attendanceHint =>
      'Tap a name to mark them away tonight. They stay in the group.';

  @override
  String playingTonight(int count) {
    return 'Playing tonight: $count';
  }

  @override
  String get addGuestsToGroupTitle => 'Add to the group?';

  @override
  String addGuestsToGroupBody(String names, String group) {
    return '$names played tonight but are not in $group.';
  }

  @override
  String get saveGroupOrderTitle => 'Save the new seating order?';

  @override
  String saveGroupOrderBody(String group) {
    return 'Tonight $group sat in a different order.';
  }

  @override
  String get addAction => 'Add';

  @override
  String get onboardingTitle => 'First round';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Start your first match';

  @override
  String get onboardingReadRules => 'Read the full rules';

  @override
  String onboardingProgress(int current, int total) {
    return 'Card $current of $total';
  }

  @override
  String get onboardingStoryTitle => 'The story';

  @override
  String get onboardingStoryBody =>
      'A small town goes to sleep every night and wakes up one person short.\nSome of the people at this table are not who they say they are — and the rest have to find them before the town is gone.';

  @override
  String get onboardingRolesTitle => 'The roles';

  @override
  String get onboardingRolesBody =>
      'Four cards. Everyone gets exactly one, and nobody sees anyone else\'s.\nTap any card below to see what it does.';

  @override
  String get onboardingNightTitle => 'The night';

  @override
  String get onboardingNightBody =>
      'The phone goes round the table one person at a time. Each player opens it alone, takes their turn, closes it and passes it on.\nThe mafia pick someone, the doctor protects someone, the detective checks someone.';

  @override
  String get onboardingDayTitle => 'The day';

  @override
  String get onboardingDayBody =>
      'In the morning the phone goes in the middle of the table and says who is gone.\nThen the talking is open, on a timer, and it ends in a vote — the app does the counting.';

  @override
  String get onboardingPassTitle => 'The phone';

  @override
  String get onboardingPassBody =>
      'This is the part that is won and lost in your hands, not on the screen:\n— Hold the phone tilted towards you, with its back to the rest of the table.\n— Never look at the phone while someone else is holding it.\n— Do not change your face while your card is showing.\n— Never hand the phone on with anything open on it.';

  @override
  String get onboardingWinTitle => 'Winning';

  @override
  String get onboardingWinBody =>
      'The town wins when the last mafia is voted out.\nThe mafia win once there are as many of them as there are townspeople.\nThat is all of it — the rest is talk and suspicion.';
}
