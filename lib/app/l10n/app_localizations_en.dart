// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onlineHostExitTitle => 'Leave the room?';

  @override
  String get onlineHostExitBody =>
      'Keep the room running and hand hosting to the first available player, or close it for everyone.';

  @override
  String get onlineLeaveKeepRoom => 'Leave and keep playing';

  @override
  String get voiceEnablePlayback => 'Enable audio';

  @override
  String get onlineHistoryLabel => 'Online match';

  @override
  String onlineMatchMeta(int players, int day) {
    return '$players players · day $day';
  }

  @override
  String get profileTitle => 'Your profile';

  @override
  String get profileHint =>
      'Choose your name and character once. Saved on this device, with no sign-in.';

  @override
  String get profileSaveFailed =>
      'Could not save your profile. Allow browser storage and try again.';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String get videoPlay => 'Play introduction';

  @override
  String get videoFailed => 'The introduction could not play here.';

  @override
  String get videoRetry => 'Try again';

  @override
  String get voiceRetry => 'Enable audio';

  @override
  String get onlineNightPrivacyHint =>
      'Audio stays off during role reveal and night to protect game privacy.';

  @override
  String get appTitle => 'Mafia Master';

  @override
  String get actionNotSaved => 'Your choice was not saved. Try again.';

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
  String get narrationEnabledLabel => 'Narrator voice';

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
  String get holdToRevealRole => 'Hold for 2 seconds to see your card';

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
  String get holdToConfirm => 'Hold for 2 seconds to continue';

  @override
  String get notYou => 'Not you?';

  @override
  String get choosePlayer => 'Choose a player';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get choiceRecorded => 'Your choice is recorded';

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
  String get holdToConfirmIdentity => 'Hold for 2 seconds to see your card';

  @override
  String get swipeToReveal => 'Swipe the card any way to flip it';

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
  String get onboardingSecrecyTitle => 'Nothing leaks';

  @override
  String get onboardingSecrecyBody =>
      'The app has one job while a match is running: give nothing away. The only way to cheat at this game is to learn something nobody told you.\n— Every turn takes the same time, holds the same screen brightness and shows the same layout, whatever card you drew.\n— The phone makes no sound at all while it is in somebody\'s hand.\n— Your card hides itself after a few seconds, and the phone never passes on with anything still open.\n— A saved group remembers names and seating order. It never remembers who was what.';

  @override
  String get onboardingWinTitle => 'Winning';

  @override
  String get onboardingWinBody =>
      'The town wins when the last mafia is voted out.\nThe mafia win once there are as many of them as there are townspeople.\nThat is all of it — the rest is talk and suspicion.';

  @override
  String get traceLabel => 'The trace';

  @override
  String get traceNone => 'This night left no trace';

  @override
  String traceLastSuspicion(String victim, String target) {
    return 'The last thing $victim recorded: they suspected «$target»';
  }

  @override
  String get traceSomeoneSurvived => 'Somebody was covered tonight… and lived';

  @override
  String traceAgreement(int count) {
    return '$count players suspected the same person tonight';
  }

  @override
  String traceShift(int count) {
    return '$count changed who they suspect tonight';
  }

  @override
  String get traceShadow => 'There is a player nobody has ever suspected';

  @override
  String get traceSilence => 'Somebody refused to record a suspicion tonight';

  @override
  String get traceCircle => 'Two of you suspect each other';

  @override
  String get traceConsensus => 'Most of the table suspected the same person';

  @override
  String get openingRoundTitle => 'One name';

  @override
  String get openingRoundBody =>
      'One name each, in seating order. No explaining.';

  @override
  String openingRoundPrompt(String name) {
    return 'Who do you suspect, $name?';
  }

  @override
  String get confrontationLabel => 'The confrontation';

  @override
  String get confrontationExplain => 'Explain.';

  @override
  String get confrontationDone => 'Done';

  @override
  String confrontationC1(String x, String y) {
    return 'You said you suspected $x, and you voted for $y.';
  }

  @override
  String get confrontationC4 =>
      'Nobody has suspected you once. Why do you think that is?';

  @override
  String confrontationC5(String x, int count) {
    return 'You and $x voted the same way $count times. Coincidence?';
  }

  @override
  String get confrontationC6 =>
      'You have talked the least of anyone. Anything to say?';

  @override
  String get confrontationC7 =>
      'The last person to die suspected you. Your answer?';

  @override
  String confrontationC8(String x) {
    return 'You whisper to $x every day. Why him in particular?';
  }

  @override
  String get confrontationC11 =>
      'Somebody tried to reach you and failed. Who would protect you?';

  @override
  String get whisperLabel => 'Whisper';

  @override
  String whisperFrom(String name) {
    return 'From $name';
  }

  @override
  String get whisperCompose => 'Send a whisper';

  @override
  String get whisperPickRecipient => 'To whom?';

  @override
  String get whisperBodyHint => 'Up to 120 characters';

  @override
  String get whisperSend => 'Send';

  @override
  String get whisperSent => 'Sent';

  @override
  String get whisperAlreadySentToday => 'You have already whispered today';

  @override
  String get whisperUndelivered => 'Your whisper never arrived';

  @override
  String whisperGraphTitle(int day) {
    return 'Whispers, day $day';
  }

  @override
  String get whisperGraphEmpty => 'Nobody whispered today';

  @override
  String whisperNobodySent(String names) {
    return '($names did not send one)';
  }

  @override
  String get whisperArrow => '›';

  @override
  String whisperTooLong(int count) {
    return 'Too long by $count';
  }

  @override
  String get whisperLanguageWarning =>
      'That reads harsher than you may mean. Send anyway?';

  @override
  String get whisperReport => 'Report';

  @override
  String get whisperReported =>
      'Reported. You will not see whispers from them again.';

  @override
  String get informationEngineSection => 'Information engine';

  @override
  String get settingTrace => 'The trace';

  @override
  String get settingTraceHint =>
      'One true observation each morning. Off restores classic Mafia.';

  @override
  String get settingConfrontation => 'The confrontation';

  @override
  String get settingConfrontationHint =>
      'One player answers for their own behaviour, once a day.';

  @override
  String get settingOpeningRound => '«One name» on day 1';

  @override
  String get settingOpeningRoundHint =>
      'Ten seconds each, in seating order, to name one suspect.';

  @override
  String get settingWhisper => 'The whisper';

  @override
  String get settingWhisperHint =>
      'One private message a day. Who wrote to whom is public; what they wrote is not.';

  @override
  String get settingRevealWhispers => 'Reveal whisper text after the match';

  @override
  String get settingRevealWhispersHint =>
      'After the match, everyone in the room reads the whispers and what they said. Players see this in the lobby and before they whisper.';

  @override
  String get onlineMatch => 'Play online';

  @override
  String get onlineCreateRoom => 'Create a room';

  @override
  String get onlineJoinRoom => 'Join a room';

  @override
  String get onlineCreateRoomHint => 'You get a code to send the others';

  @override
  String get onlineJoinRoomHint => 'Somebody sent you a code?';

  @override
  String get onlineRoomCode => 'Room code';

  @override
  String get onlineRoomCodeHint => 'Six characters';

  @override
  String get onlineShareCode => 'Share the code';

  @override
  String get onlineWaitingForPlayers => 'Waiting for players…';

  @override
  String get onlineStartMatch => 'Start';

  @override
  String get onlineConnecting => 'Reconnecting…';

  @override
  String get onlineDisconnected => 'No connection';

  @override
  String get onlineNotConnected => 'Offline';

  @override
  String onlineHostLeft(String name) {
    return 'The host left. $name is hosting now.';
  }

  @override
  String get onlineRoomFull => 'That room is full';

  @override
  String get onlineRoomFinished => 'That match has already finished';

  @override
  String get onlineAlreadySeated => 'You are still in a match';

  @override
  String get onlineLeaveTableTitle => 'Leave your match?';

  @override
  String get onlineLeaveTableBody =>
      'You are still in a match. Joining this room takes you out of it, and the table plays on without you.';

  @override
  String get onlineLeaveTableConfirm => 'Leave and join';

  @override
  String get onlineRoomNotFound => 'No room with that code';

  @override
  String get onlineUnreachable =>
      'Cannot reach the server. Play offline instead?';

  @override
  String get onlineProjectPaused =>
      'The server is asleep. Try again in a minute.';

  @override
  String get onlinePlayOffline => 'Play offline';

  @override
  String get onlineHeadphonesWarning =>
      'If you are in the same room, use headphones';

  @override
  String get voiceMicOff => 'Microphone off';

  @override
  String get voiceMuteMe => 'Mute me';

  @override
  String get voiceUnmuteMe => 'Unmute me';

  @override
  String get voiceSelfMuted => 'You are muted';

  @override
  String get voiceMicOn => 'Microphone on';

  @override
  String get voiceTextMode => 'Voice unavailable — text mode';

  @override
  String get voiceMicDenied => 'No microphone. You can still hear everyone.';

  @override
  String get whoAreYou => 'Who are you?';

  @override
  String get onlineYourName => 'Your name';

  @override
  String get onlineHostBadge => 'Host';

  @override
  String get onlineYou => 'You';

  @override
  String get onlineNeedFivePlayers => 'At least five players';

  @override
  String get onlineLeave => 'Leave the room';

  @override
  String get onlineCodeCopied => 'Code copied';

  @override
  String get onlinePublicRooms => 'Public rooms';

  @override
  String get onlinePublicRoomsHint => 'Join an open room without a code';

  @override
  String get onlineNoPublicRooms => 'No public rooms open right now';

  @override
  String publicRoomSeats(int players, int capacity) {
    return '$players/$capacity players';
  }

  @override
  String publicRoomMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more players needed before the host can start',
      one: '1 more player needed before the host can start',
    );
    return '$_temp0';
  }

  @override
  String get publicRoomReady =>
      'Enough players — the host decides when to start';

  @override
  String get publicRoomFullStatus => 'Full';

  @override
  String get publicRoomsStale =>
      'Can\'t refresh the list right now. This is the last list we received and it may be out of date.';

  @override
  String get publicRoomsUnavailable =>
      'Can\'t reach the server to load rooms. We\'ll keep trying.';

  @override
  String get onlineRoomStarted =>
      'That room has already started. Pick another one from the list.';

  @override
  String onlinePublicRoomPlayers(int count) {
    return '$count players';
  }

  @override
  String get onlineUntitledRoom => 'Unnamed room';

  @override
  String get onlineRoomSettings => 'Room settings';

  @override
  String get onlineSettingsRoom => 'Room';

  @override
  String get onlineSettingsVoice => 'Voice';

  @override
  String get onlineSettingsPlay => 'Play';

  @override
  String get onlineSettingsInfo => 'Information';

  @override
  String get onlineRoomVisibility => 'Room type';

  @override
  String get onlineRoomVisibilityHint =>
      'Private rooms take a code. Public ones are listed for anybody.';

  @override
  String get onlineRoomPrivate => 'Private';

  @override
  String get onlineRoomPublic => 'Public';

  @override
  String get onlineRoomTitle => 'Room name';

  @override
  String get onlineRoomTitleHint => 'What people see in the list.';

  @override
  String get onlineMaxPlayers => 'Maximum players';

  @override
  String get onlineMaxPlayersHint => 'The room closes once it is this full.';

  @override
  String get onlineVoiceEnabled => 'Voice';

  @override
  String get onlineVoiceEnabledHint => 'The match plays fine without it.';

  @override
  String get onlineMuteAtNight => 'Mute everyone at night';

  @override
  String get onlineMuteAtNightHint => 'A voice at night says who is awake.';

  @override
  String get onlineSpeakDuration => 'Speaking time';

  @override
  String get onlineSpeakDurationHint =>
      'How long each player holds the floor alone.';

  @override
  String get onlineDiscussDuration => 'Discussion time';

  @override
  String get onlineDiscussDurationHint => 'The open argument before the vote.';

  @override
  String get onlineOpenVoting => 'Open voting';

  @override
  String get onlineOpenVotingHint =>
      'Everyone sees who voted for whom until the ballot locks.';

  @override
  String get onlineTrace => 'Trace';

  @override
  String get onlineTraceHint =>
      'The morning names one trace of the night\'s movement.';

  @override
  String get onlineConfrontation => 'Confrontation';

  @override
  String get onlineConfrontationHint =>
      'Two players face each other before the vote.';

  @override
  String get onlineWhispers => 'Whispers';

  @override
  String get onlineWhispersHint =>
      'A private line to one player; the room knows it was sent.';

  @override
  String get onlineSeconds => 'seconds';

  @override
  String get onlineMinutes => 'minutes';

  @override
  String get onlineLinkCopied => 'Room link copied';

  @override
  String get onlineWaitingForHost => 'Waiting for the host…';

  @override
  String get voiceTakeFloor => 'Speak';

  @override
  String get voiceYieldFloor => 'Done';

  @override
  String get voiceFloorTaken => 'Someone else has the floor';

  @override
  String get onlineWeatherConnecting => 'Connecting…';

  @override
  String get onlineWeatherReconnecting => 'Weak connection — trying';

  @override
  String get onlineWeatherUnreachable => 'No connection. The match is saved.';

  @override
  String get onlineCopy => 'Copy';

  @override
  String get onlineShare => 'Share';

  @override
  String onlinePlayersOfMax(int count, int max) {
    return '$count / $max players';
  }

  @override
  String get onlineVoiceConnecting => 'Voice: connecting…';

  @override
  String get onlineVoiceConnected => 'Voice: connected';

  @override
  String get onlineVoiceUnavailable =>
      'Voice is unavailable — the game plays normally';

  @override
  String onlineShareInvite(String code) {
    return 'Play Mafia with us. Room code: $code';
  }

  @override
  String get onlineReferralOffer =>
      'Invite a new friend: you get +100 and they get +50 after their first match';

  @override
  String get onlineGhostRule =>
      'Whoever is out does not talk to whoever is still playing';

  @override
  String onlineChosen(String name) {
    return 'Chosen: $name';
  }

  @override
  String onlineUpNext(String names) {
    return 'Up next: $names';
  }

  @override
  String get onlineLeftRoom => 'Left';

  @override
  String onlineNewHost(String name) {
    return '$name is the host now';
  }

  @override
  String get onlineCloseRoom => 'Close the room';

  @override
  String get onlineCloseRoomBody =>
      'This ends the match for everyone in the room. Are you sure?';

  @override
  String get onlineCloseRoomConfirm => 'Close';

  @override
  String get onlineRoomClosed => 'The host closed the room';

  @override
  String get onlineKick => 'Remove';

  @override
  String get onlineMute => 'Mute';

  @override
  String get onlineUnmute => 'Unmute';

  @override
  String get onlineKickedByHost => 'The host removed you from the room';

  @override
  String onlineWaitingForCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count players are still looking at their cards',
      one: '1 player is still looking at their card',
    );
    return '$_temp0';
  }

  @override
  String get onlineFloorOpen => 'The floor is open';

  @override
  String onlineRaisedHands(String names) {
    return 'Hands up: $names';
  }

  @override
  String get onlineRaiseHand => 'My turn';

  @override
  String get onlineHandRaised => 'Hand up';

  @override
  String get onlineSeeRoles => 'See the roles';

  @override
  String onlineRosterOf(int index, int total) {
    return '$index of $total';
  }

  @override
  String get onlinePickFromTable => 'Choose from the table';

  @override
  String get onlineWaitingForTheRest => 'Done. Waiting for the rest…';

  @override
  String get onlineConfirmHold => 'Confirm — press and hold';

  @override
  String get confrontationSilent => 'Silence.';

  @override
  String get confrontationAudience => 'Listening';

  @override
  String get settingVoteVisibility => 'Voting';

  @override
  String get settingOpenVoting => 'Open voting';

  @override
  String get settingSecretVoting => 'Secret ballot';

  @override
  String get settingOpenVotingHint =>
      'You watch each vote land, and you see who changes their mind';

  @override
  String get witnessTitle => 'The Witness';

  @override
  String get witnessEliminated =>
      'You are out of the game. But you are still watching.';

  @override
  String get witnessSpectating => 'Watching';

  @override
  String get witnessTabTable => 'The table';

  @override
  String get witnessTabChat => 'Those who are out';

  @override
  String get witnessTabPrediction => 'Your call';

  @override
  String get witnessTabRecord => 'Your record';

  @override
  String get witnessChatHint => 'Write to the others who are out…';

  @override
  String get witnessChatEmpty => 'Nothing said yet';

  @override
  String get witnessChatWalled => 'Nobody still playing can see this';

  @override
  String get witnessChatSend => 'Send';

  @override
  String get witnessPredictionWinner => 'Who wins?';

  @override
  String get witnessPredictionMafia => 'And who is Mafia?';

  @override
  String get witnessPredictionLock => 'Lock it in';

  @override
  String get witnessPredictionLocked => 'Locked. We will see at the end.';

  @override
  String witnessPredictionScore(int correct, int total) {
    return 'Your call: $correct of $total';
  }

  @override
  String get witnessRecordEmpty => 'You did not write anything down';

  @override
  String get onlineIntroPhoneTitle => 'Your phone is your turn';

  @override
  String get onlineIntroPhoneBody =>
      'Nothing is passed around. Everything you do, you do here. Each player uses a device and a room code. Offline uses one shared phone and needs no internet.';

  @override
  String get onlineIntroNightTitle => 'The night happens all at once';

  @override
  String get onlineIntroNightBody =>
      'Everybody acts together, on their own screen. It takes under a minute. Discuss and vote by day. Town wins by eliminating all Mafia; Mafia wins at parity with the remaining town. Voice is optional; play continues without it.';

  @override
  String get onlineIntroWhisperTitle => 'A whisper shows who, never what';

  @override
  String get onlineIntroWhisperBody =>
      'The table sees a light cross it. Only one person reads the words. Private messages are online only, unavailable offline.';

  @override
  String get onlineIntroWitnessTitle =>
      'If you are out, you are still watching';

  @override
  String get onlineIntroWitnessBody =>
      'You keep the table, you talk to the others who are out, and you call the ending. This spectator area is online only. Offline, eliminated players stop taking private turns.';

  @override
  String get onlineIntroSkip => 'Skip';

  @override
  String get onlineIntroStart => 'Let\'s go';

  @override
  String get modeTitle => 'How are you playing?';

  @override
  String get modeSubtitle => 'You can change this next time.';

  @override
  String get modeOnePhoneTitle => 'One phone, passed around';

  @override
  String get modeOnePhoneBody =>
      'Everybody in the same room. The phone goes from hand to hand.';

  @override
  String get modeOnlineTitle => 'Everybody on their own phone';

  @override
  String get modeOnlineBody =>
      'Same room or anywhere. Nothing is passed, and nobody waits their turn to look.';

  @override
  String get modeNoServer =>
      'This build has no server. Rebuild it with a project configured.';

  @override
  String get bulletMafia => 'The quiet night';

  @override
  String get bulletDoctor => 'Cover yourself, once';

  @override
  String testimonyGiven(String name, String suspect) {
    return '$name testifies: their suspicion last night was $suspect.';
  }

  @override
  String testimonyNobody(String name) {
    return '$name testifies: they suspected nobody last night.';
  }

  @override
  String fileOpenedTitle(String name) {
    return '$name opened the file.';
  }

  @override
  String fileOpenedEntry(String name, String role) {
    return '$name — $role';
  }

  @override
  String get fileOpenedEmpty => 'The file was empty.';

  @override
  String get hintTalkers =>
      'Whoever talks most is not always whoever is hiding.';

  @override
  String get hintQuickAgreement =>
      'Watch who agrees immediately without thinking.';

  @override
  String get hintSilence => 'Silence is not evidence. But it is information.';

  @override
  String get hintChangesMind => 'Who changes their mind fast under pressure?';

  @override
  String get hintEarlyAccuser =>
      'Good mafia accuse early so they look innocent.';

  @override
  String get hintMajorityComfort =>
      'Voting with the majority is comfortable. That is exactly what they count on.';

  @override
  String get hintWhoBenefited => 'Who gained from whoever died last night?';

  @override
  String get hintMafiaSuspicionSpreads =>
      'Do not kill whoever suspects you straight away — their suspicion gets published.';

  @override
  String get hintMafiaQuietNight =>
      'The quiet night starves the table of information.';

  @override
  String get hintMafiaSpeak => 'Talk. Silent mafia die.';

  @override
  String get hintDoctorNoRepeat =>
      'Do not cover the same person two nights running.';

  @override
  String get hintDoctorSelf => 'You get to cover yourself once — save it.';

  @override
  String get hintDoctorSaveReveals =>
      'If a save lands, the mafia learn there is a doctor.';

  @override
  String get hintDetectiveInvestigateLoud =>
      'Investigate whoever talks most, not whoever is quiet.';

  @override
  String get hintCitizenSuspicionCounts =>
      'Your suspicion is not going nowhere — it gets recorded.';

  @override
  String coachStuckOnInnocent(String name, int count) {
    return 'You suspected $name on $count nights and they were a citizen. Try changing your mind faster when the evidence does not arrive.';
  }

  @override
  String coachConformity(int count, int total) {
    return 'You voted with the majority $count times out of $total. Try forming your own view before you hear everybody else\'s.';
  }

  @override
  String coachUnusedBullet(String bullet) {
    return 'You never used «$bullet». It was there from the first night.';
  }

  @override
  String get coachNeverWhispered =>
      'You never whispered once. A whisper builds alliances.';

  @override
  String coachAbandonedRead(String name) {
    return 'You suspected $name on the first nights and they were mafia — then you let it go. Trust your first read.';
  }

  @override
  String coachQuiet(int seconds) {
    return 'You spoke for $seconds seconds all match — among the least at the table. Silence makes a table suspect you.';
  }

  @override
  String get coachSurvivedAsMafia =>
      'You lived to the end without the table catching you.';

  @override
  String get coachingTitle => 'It could have gone otherwise';

  @override
  String get coachingEmpty => 'Nothing to add. You played it as it came.';

  @override
  String get presetFast => 'Quick';

  @override
  String get presetClassic => 'Classic';

  @override
  String get presetBrutal => 'Brutal';

  @override
  String get presetCustom => 'Custom';

  @override
  String get presetFastHint =>
      'Around fifteen minutes, fewer rules. Best for a group\'s first match.';

  @override
  String get presetClassicHint =>
      'Everything on, at the pace it was designed at.';

  @override
  String get presetBrutalHint =>
      'No doctor, more mafia, no whispers, a brutal clock.';

  @override
  String get presetLabel => 'Preset';

  @override
  String get settingPressureCurve => 'The pressure curve';

  @override
  String get settingPressureCurveHint =>
      'The clock closes as the table shrinks. It only ever tightens.';

  @override
  String get settingTabletopPresentation => 'Phone in the middle';

  @override
  String get settingTabletopPresentationHint =>
      'Makes public screens and timers readable from across the table.';

  @override
  String get settingDiscussionSeconds => 'Discussion length';

  @override
  String get settingPlayHints => 'Play hints';

  @override
  String get settingCoaching =>
      '«It could have gone otherwise», after the match';

  @override
  String get settingRevealVictimRole => 'The night victim\'s role';

  @override
  String get settingRevealVictimRoleHint =>
      'A day elimination is always public. This is about the night.';

  @override
  String victimWasRole(String name, String role) {
    return '$name was $role.';
  }

  @override
  String get nightSpecialMafia => 'No kill tonight';

  @override
  String get nightSpecialDoctor => 'Protect yourself';

  @override
  String get nightSpecialDetective => 'No check tonight';

  @override
  String get nightSpecialCitizen => 'No read tonight';

  @override
  String get settingsSectionPace => 'Pace';

  @override
  String get settingsSectionInformation => 'Information';

  @override
  String get settingsSectionReveal => 'Reveals';

  @override
  String get settingsSectionVoting => 'Voting';

  @override
  String get settingsSectionAudio => 'Sound and motion';

  @override
  String get settingsOnlineOnly => 'Online only';

  @override
  String get settingSpeechSecondsHint =>
      'How long one player speaks in a structured discussion.';

  @override
  String get settingDiscussionSecondsHint =>
      'How long the whole discussion runs when it is free.';

  @override
  String get settingIdentityHoldHint =>
      'The same for every player, so turn length says nothing about a role.';

  @override
  String get settingDiscussionModeHint =>
      'Structured: one at a time, in order. Free: everyone at once.';

  @override
  String get settingAbstainHint => 'A player may cast no vote at all.';

  @override
  String get settingPlayHintsHint =>
      'One line, in the lobby and settings only. Never inside a match.';

  @override
  String get settingCoachingHint =>
      'After the match, one honest note per player.';

  @override
  String get settingMuteAllHint =>
      'No sound at all. Nothing in the game depends on hearing it.';

  @override
  String minutesSuffix(int minutes) {
    return '$minutes min';
  }

  @override
  String whisperFromTitle(String name) {
    return 'Whisper from $name';
  }

  @override
  String get whisperDismiss => 'Got it';

  @override
  String get playerMale => 'Male';

  @override
  String get playerFemale => 'Female';

  @override
  String timelineMafiaVoteFemale(String actor, String target) {
    return '$actor voted for $target';
  }

  @override
  String timelineProtectFemale(String actor, String target) {
    return '$actor protected $target';
  }

  @override
  String timelineInvestigateFemale(String actor, String target) {
    return '$actor investigated $target';
  }

  @override
  String timelineSuspectFemale(String actor, String target) {
    return '$actor suspected $target';
  }

  @override
  String get onlineDiscardResume => 'Forget room';

  @override
  String get onlineStorageWarning =>
      'This device could not save. The match is unaffected, but it may not bring you back to the room on its own or keep the result.';

  @override
  String get safetyTitle => 'Privacy and data deletion';

  @override
  String get safetyPolicy =>
      'Developer: Eyad Syam\nSupport: eyadsyam124@gmail.com\n\nLocal play stays on your device. Online play uses a random identifier, profile, match actions and messages. Earned coins, rewards and unlocked items remain with that identity until deletion. Optional voice is encrypted in transit and is not recorded by the game. Service providers process connection data needed to operate online play. An email is collected only if you choose to protect your account.\n\nAds (Android): Google AdMob may show an app-open ad when the game launches or you come back to it after a long break; a full-screen ad between matches — before you enter a room, when you leave a finished match, before the roles are dealt and after the result of a pass-and-play game, or occasionally when you move between menus after several minutes without one (never during a match or while the phone is being passed, at most 40 a day, at least 90 seconds apart); a small labelled banner on waiting screens such as the online lobby, match history and your profile (never during play); and optional rewarded ads, only when you choose to watch one, after a completed online match (to double or triple its coins) and in the vault. To serve ads and prevent fraud, Google\'s ads SDK collects IP address, ad and app interactions, diagnostics and device identifiers such as the Advertising ID. Change ad consent in Settings, under “Ad privacy choices”. Purchases in the Play version use Google Play Billing, where we receive the order, product and purchase token to verify it, or an InstaPay / Vodafone Cash transfer, where you upload the transfer screenshot and the sender name for manual review (stored privately; the screenshot is deleted 90 days after review).\n\nFinished rooms are eligible for deletion after 24 hours. Old anonymous identities with no room membership are removed on the cleanup schedule. You can request online-data deletion below; submission is not completed deletion. Outside the app, use saidalmafia.com/delete-data with your identifier or receipt. Never send passwords or access keys.\n\nHarassment, threats, hate, sexual content, child exploitation and sharing private information are prohibited. Report abusive players, room names or messages. Blocking hides their private messages and mutes their voice for you; public game actions remain visible. Reports are reviewed by the developer and are not visible to players.';

  @override
  String get safetyAgree => 'I accept the community rules';

  @override
  String get safetyConsentTitle => 'Before playing online';

  @override
  String get safetyConsentBody =>
      'Abuse, harassment, hate, sexual content and sharing private information are prohibited. Use Safety to report or block. Voice is optional. Read Privacy in Settings for data practices.';

  @override
  String get safetyReport => 'Submit report';

  @override
  String get safetyBlock => 'Block player messages and voice';

  @override
  String get safetyRoom => 'Room name or content';

  @override
  String get safetyDetails =>
      'Describe the abuse or message (no secret role information)';

  @override
  String get safetyReceipt => 'Request received. Keep this receipt:';

  @override
  String get safetyFailed => 'Request was not sent. Retry or contact support.';

  @override
  String get safetyDelete => 'Request online data deletion';

  @override
  String get safetyDeleteConfirm =>
      'Send a request to delete your anonymous identity and associated online data. The developer will review it within 30 days. Other players’ local copies are separate; safety evidence may be retained for a limited period. This request does not delete local files.';

  @override
  String get safetyIdentity => 'Show my data identifier';

  @override
  String get safetyBlocked => 'Blocked for you.';

  @override
  String get safetyNoRoom =>
      'Reporting and blocking are available inside a room.';

  @override
  String get safetyTools => 'Report and block';

  @override
  String get onlineWelcome => 'The table is ready. Take your seat.';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get onlineNewRoomsPaused =>
      'New rooms are temporarily paused. You can still join an existing room or play offline.';

  @override
  String get helpTitle => 'Help and FAQ';

  @override
  String get helpIntro =>
      'Quick answers about playing, online rooms, safety and your data.';

  @override
  String get helpPlayQuestion => 'How does a match work?';

  @override
  String get helpPlayAnswer =>
      'The game assigns secret roles, guides every night and day phase, and counts the vote. Citizens find the Mafia; the Mafia survives until it matches or outnumbers the town. The host can review the rules before starting.';

  @override
  String get helpOnlineQuestion => 'How do online rooms work?';

  @override
  String get helpOnlineAnswer =>
      'Create a room and share its code, join with a code, or choose a public room. The match is controlled by the game server, and host control moves to another connected player if needed.';

  @override
  String get helpVoiceQuestion => 'Is voice required?';

  @override
  String get helpVoiceAnswer =>
      'No. Voice is optional and is not recorded by the game. If microphone access or voice relay fails, the match continues with the game controls and structured text.';

  @override
  String get helpReconnectQuestion => 'What if the connection drops?';

  @override
  String get helpReconnectAnswer =>
      'Reopen the game on the same device and use Continue room when it appears. Your seat is restored when the room still exists. Never create a second profile to recover a live seat.';

  @override
  String get helpSafetyQuestion => 'How do reporting and blocking work?';

  @override
  String get helpSafetyAnswer =>
      'Inside a room, use the flag button to report a player or room content. Blocking immediately hides that player\'s private messages and mutes their voice for you. A report is evidence for review, not an automatic guilty decision.';

  @override
  String get helpCoinsQuestion => 'What are coins?';

  @override
  String get helpCoinsAnswer =>
      'Coins are earned from verified completed online matches and can unlock fair content. They cannot be withdrawn, transferred or used to buy votes, secret information or a better chance to win. Coins stay with this device\'s anonymous online identity.';

  @override
  String get helpPrivacyQuestion => 'Where are privacy and deletion controls?';

  @override
  String get helpPrivacyAnswer =>
      'They are on the Settings screen under Privacy and data deletion. You can view your anonymous data identifier and request deletion there.';

  @override
  String get helpAgeQuestion => 'Who is online play intended for?';

  @override
  String get helpAgeAnswer =>
      'Online voice and public rooms are intended for players aged 16 or older. Do not share your address, phone number, passwords or other private information in voice, names, messages or room titles.';

  @override
  String get helpSupportQuestion => 'How can I contact support?';

  @override
  String get helpSupportAnswer =>
      'Email eyadsyam124@gmail.com. Include a report receipt or your anonymous data identifier when relevant, but never send a password or access key.';

  @override
  String get coinsTitle => 'Coins and rewards';

  @override
  String coinsBalance(int count) {
    return '$count coins';
  }

  @override
  String get coinsEarnHint =>
      'Complete an eligible online match to earn 100 coins. Players on the winning team earn 25 more. Rewards are verified by the game server and never affect votes, roles or the chance to win.';

  @override
  String get coinsEarnHintV3 =>
      'Complete an eligible online match with five or more players to earn 25 coins. Your team winning adds 10 more, and your first eligible match of the day adds 25. After the match, each award you earn also pays 5 coins, or 15 for MVP, when awards are on. The server verifies rewards; they never affect votes, roles or the chance to win.';

  @override
  String get coinsLoadFailed =>
      'Your coins could not be loaded. Nothing was spent; try again.';

  @override
  String get coinsGuideTitle => 'The Mastermind\'s Notebook';

  @override
  String get coinsGuideHint =>
      'A permanent strategy guide for reading the table and defending your story. It never reveals live secret information.';

  @override
  String coinsGuidePrice(int count) {
    return 'Unlock for $count coins';
  }

  @override
  String get coinsBuyGuide => 'Unlock the notebook?';

  @override
  String get coinsBuyConfirm =>
      'This permanently spends earned coins on this anonymous online identity. It cannot change a match or improve your odds.';

  @override
  String get coinsUnlock => 'Unlock';

  @override
  String get coinsGuideOpen => 'Open the notebook';

  @override
  String get coinsGuideContent =>
      'CITIZEN — Track who changes a story after the vote, not who speaks the loudest. Ask for one clear reason and compare it with the next ballot.\n\nMAFIA — Build a simple position early. A complicated lie creates details you must remember. Defend a citizen sometimes; automatic aggression gives the table an easy pattern.\n\nDOCTOR — Survival is not the only goal. Think about which save would create the most trustworthy information for tomorrow.\n\nDETECTIVE — Your information is valuable only if the table can use it. Leave a believable trail before a risky accusation, without announcing your role too early.\n\nEVERY ROLE — Separate what the game confirmed from what a player claimed. The strongest argument is the one that survives the next revealed fact.';

  @override
  String adRewardAction(int count) {
    return 'Watch an ad for +$count coins';
  }

  @override
  String get adRewardHint =>
      'Optional and shown only after the result. Your original reward stays yours if you decline or the ad fails.';

  @override
  String get adRewardPending =>
      'Ad completed. The extra reward is being verified and will appear automatically.';

  @override
  String adRewardGranted(int count) {
    return '$count extra coins added.';
  }

  @override
  String get adRewardUnavailable =>
      'No ad is available right now. Your original reward is unchanged.';

  @override
  String get adRewardUsed => 'You claimed the ad reward for this match.';

  @override
  String get privacyChoices => 'Ad privacy choices';

  @override
  String get privacyChoicesHint =>
      'Review or change the privacy choices required by the advertising provider.';

  @override
  String get premiumScenarioTitle => 'Council of Shadows scenario';

  @override
  String get premiumScenarioHint =>
      'A permanent host pack with balanced rules, whispers, confrontation and secret ballots. When the host selects it, everyone in the room plays without buying it.';

  @override
  String get premiumScenarioBuy => 'Buy scenario pack';

  @override
  String get premiumScenarioOwned => 'Scenario pack owned';

  @override
  String get premiumScenarioRestore => 'Restore purchases';

  @override
  String get premiumScenarioPending =>
      'The store is still processing this purchase.';

  @override
  String get premiumScenarioFailed =>
      'The purchase could not be verified. The game has not charged anything itself.';

  @override
  String get premiumScenarioUse => 'Council of Shadows';

  @override
  String get premiumScenarioUseHint =>
      'A balanced scenario preset the host unlocks for the whole room.';

  @override
  String get shareResult => 'Share result';

  @override
  String shareResultText(String winner, int days) {
    return 'A Mafia Master match ended with $winner winning after $days days. Open your room at https://saidalmafia.com';
  }

  @override
  String get playAgainWithGroup => 'New room for the group';

  @override
  String get setupWelcomeTitle => 'Welcome to Mafia Master';

  @override
  String get setupWelcomeHint =>
      'Choose your language, name and preferences once, then play.';

  @override
  String get setupPreferencesTitle => 'Preferences';

  @override
  String get setupPreferencesHint => 'You can change these later in Settings.';

  @override
  String get prefSound => 'Game sounds';

  @override
  String get prefMusic => 'Music';

  @override
  String get prefReduceMotion => 'Reduce motion';

  @override
  String get setupAdultConfirm => 'I am 16 or older';

  @override
  String get setupAdultHint =>
      'Online play, voice and public rooms are for ages 16 and up.';

  @override
  String get termsAcceptPrefix => 'I have read and agree to the ';

  @override
  String get termsAcceptLink => 'Terms and Conditions';

  @override
  String get termsAcceptSuffix => '.';

  @override
  String get privacyLinkLabel => 'Privacy policy';

  @override
  String get termsTitle => 'Terms and Conditions';

  @override
  String termsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get termsBody =>
      '1. Mafia Master is a party game for entertainment. Roles and outcomes are part of the game only.\n\n2. Online play, voice and public rooms are for people aged 16 or older.\n\n3. Abuse, harassment, threats, hate speech, sexual content and sharing anyone\'s private information are prohibited. You can report or block a player from the safety tools.\n\n4. Voice is optional and the game does not record audio. Other players hear what you say, and nobody can stop someone recording with another device.\n\n5. Mafia Coins are an in-game currency for unlocking cosmetic content only, such as frames, themes and narrator styles. They have no cash value, cannot be exchanged for money and never give an advantage in play, voting or roles.\n\n6. Coins, the Quiet Pass and the Starter Bundle can be bought with money: in the Android app through Google Play Billing, and in the Android app and on the website by InstaPay or Vodafone Cash transfer at the same price. Transfers are reviewed manually within 72 hours; you upload the transfer screenshot and the sender name, and the purchase is added only after the money is confirmed. A screenshot can be used for one order only. A rejected order shows its reason; an order not reviewed within 72 hours expires.\n\n7. We may remove a room or restrict a player who breaks these terms. You can request deletion of your data from Settings.\n\n8. If these terms change in an important way, we will ask for your agreement again before you continue.';

  @override
  String get privacySummaryBody =>
      '• The game uses an anonymous identifier for online play and needs no phone number or birth date to play.\n\n• Your in-game name and avatar type are shown to the players in your room.\n\n• Voice is optional, encrypted in transit and never recorded by the game.\n\n• If you link an email to protect your coins, it is used only to recover your account.\n\n• Android shows Google AdMob ads: optional rewarded ads; automatic full-screen ads only between matches — before you enter a room (Create, Join or a rematch), when you leave a finished match, before the roles are dealt and after the result in pass-and-play, occasionally when you move between menus after several minutes without one, and an app-open ad on the launch screen — never during a match, at most 40 a day, at least 90 seconds apart, and none around your first match; and small banners on waiting screens (lobby, room list, history, vault, profile) — never during play. The Quiet Pass removes all automatic ads. Google\'s ads SDK collects IP address, interactions, diagnostics and device identifiers such as the Advertising ID.\n\n• Play purchases go through Google Play Billing; we keep the order, product and purchase token to verify them. InstaPay / Vodafone Cash transfer orders (Android app and website) record the product, amount, method, the transfer screenshot you upload and the sender name, only to verify the payment; the screenshot is stored privately and deleted 90 days after the order is reviewed, and the order record is kept for accounting.\n\n• Finished rooms are deleted periodically, and you can request deletion of your data from Settings.\n\n• Council rank and the weekly leaderboard: your level shows on your seat, and your in-game name, avatar type, equipped frame, level and weekly XP can appear on the public weekly leaderboard. You can hide yourself from the leaderboard in your profile. Match history behind them is kept 21 days.\n\nFull policy: saidalmafia.com/privacy';

  @override
  String get termsUpdatedTitle => 'Before you continue';

  @override
  String get termsUpdatedHint =>
      'Review and accept the terms once. Your profile and progress are kept.';

  @override
  String get settingsLegalTitle => 'Terms and privacy';

  @override
  String get launcherLabelPending =>
      'The icon name will update after you close the game.';

  @override
  String get documentClose => 'Back';

  @override
  String get publicRoomWaitingTitle => 'Waiting room ready';

  @override
  String get publicRoomWaitingStatus =>
      'Empty; the first player in becomes the host';

  @override
  String get onlineShareFailed =>
      'Couldn\'t open sharing or copy the link. Read the room code out to players.';

  @override
  String get shareTextCopied => 'Copied. Paste it anywhere to send it.';

  @override
  String get shareUnavailable => 'Couldn\'t open sharing. Try again.';

  @override
  String get coinsName => 'Council Coins';

  @override
  String get storeTitle => 'Store';

  @override
  String get storeTabShop => 'Shop';

  @override
  String get storeTabCollection => 'Collection';

  @override
  String get storeTabHistory => 'History';

  @override
  String get storeTabCoins => 'Buy coins';

  @override
  String storeEarnTime(int count, int matches) {
    return '$count coins, about $matches online matches';
  }

  @override
  String get storeSectionIdentity => 'Identity';

  @override
  String get storeSectionPacks => 'Room presentation';

  @override
  String get storeSectionNarrator => 'Narration styles';

  @override
  String get storeSectionBundles => 'Bundles';

  @override
  String get storePermanent => 'Permanent';

  @override
  String get storeOwned => 'Owned';

  @override
  String get storeEquipped => 'In use';

  @override
  String get storeEquip => 'Use';

  @override
  String get storeUnequip => 'Remove';

  @override
  String get storePreview => 'Preview';

  @override
  String storeBuyFor(int count) {
    return 'Buy for $count';
  }

  @override
  String storeBuyConfirmTitle(String item) {
    return 'Buy $item?';
  }

  @override
  String storeBuyConfirmBody(int count) {
    return '$count coins will be deducted. The content is cosmetic and permanent, and changes nothing in play.';
  }

  @override
  String storeNotEnough(int count) {
    return '$count more coins needed';
  }

  @override
  String storeBundleSaves(int count) {
    return 'Saves $count coins';
  }

  @override
  String get storeBundleOwnedAll => 'You own everything in it';

  @override
  String storeBundleContents(String items) {
    return 'Includes: $items';
  }

  @override
  String get storeBought => 'Added to your collection';

  @override
  String get storeFailed =>
      'That did not go through and nothing was deducted. Try again.';

  @override
  String get storeHostPackNote =>
      'When the host picks a presentation, everyone in the room sees it without buying it.';

  @override
  String get storePresentationNote =>
      'Look and sound only. It never changes rules, votes or roles.';

  @override
  String get storeEmptyCollection => 'Nothing here yet.';

  @override
  String get storeEmptyHistory => 'No activity yet.';

  @override
  String get historyMatchCompletion => 'Online match finished';

  @override
  String get historyMatchWin => 'Win';

  @override
  String historyCatalogSpend(String item) {
    return 'Bought: $item';
  }

  @override
  String historyCatalogRefund(String item) {
    return 'Refund: $item';
  }

  @override
  String get historyAdReward => 'Video reward';

  @override
  String get historyCoinPurchase => 'Coin purchase';

  @override
  String get historyCoinPurchaseReversal => 'Coin purchase reversed';

  @override
  String get historyAdjustment => 'Adjustment';

  @override
  String get cosmeticClassic => 'Classic';

  @override
  String get cosmeticFrameGilded => 'Gilded frame';

  @override
  String get cosmeticFrameGildedDesc =>
      'An engraved gold frame with a small mask beneath your portrait, seen by every player.';

  @override
  String get cosmeticFrameCrimson => 'Crimson frame';

  @override
  String get cosmeticFrameCrimsonDesc =>
      'Dark silver with crimson enamel and a small crest below your portrait.';

  @override
  String get cosmeticFrameMoonlit => 'Moonlit frame';

  @override
  String get cosmeticFrameMoonlitDesc =>
      'Cool silver with a small crescent moon below your portrait.';

  @override
  String get cosmeticPlateNoir => 'Noir nameplate';

  @override
  String get cosmeticPlateNoirDesc =>
      'Your name on a charcoal plate in engraved silver with medallion ends.';

  @override
  String get cosmeticPlateGilded => 'Gilded nameplate';

  @override
  String get cosmeticPlateGildedDesc =>
      'Your name on a charcoal plate with a gold edge and fan-shaped ends.';

  @override
  String get cosmeticPlateEmber => 'Ember nameplate';

  @override
  String get cosmeticPlateEmberDesc =>
      'Your name on a charcoal plate edged in crimson and gold with pointed ends.';

  @override
  String get cosmeticPackManor => 'Midnight Manor';

  @override
  String get cosmeticPackManorDesc =>
      'A candlelit manor hall behind the table with light fog, a candlelight transition between public phases, and an opening and closing line with sound. Everyone in the room sees it.';

  @override
  String get cosmeticPackOldTown => 'Old Town';

  @override
  String get cosmeticPackOldTownDesc =>
      'A warm old-stone hall behind the table with drifting light, a sweeping-light transition across the table, and an opening and closing line with sound. Everyone in the room sees it.';

  @override
  String get cosmeticNarratorStoryteller => 'The Storyteller';

  @override
  String get cosmeticNarratorStorytellerDesc =>
      'A recorded storyteller voice marks every public phase with the same short line for every player. With sound off, the lines stay as text.';

  @override
  String get cosmeticBundleCouncil => 'Council bundle';

  @override
  String get cosmeticBundleCouncilDesc =>
      'Midnight Manor, Old Town and The Storyteller together.';

  @override
  String get cosmeticBundleIdentity => 'Identity bundle';

  @override
  String get cosmeticBundleIdentityDesc =>
      'All three frames and all three nameplates.';

  @override
  String get packManorIntro =>
      'The manor doors are shut. Nobody leaves before the truth does.';

  @override
  String get packManorOutro =>
      'The candles are out, and the manor keeps its secrets.';

  @override
  String get packOldTownIntro => 'The old town wakes to a new secret.';

  @override
  String get packOldTownOutro => 'The streets are quiet. The story is over.';

  @override
  String get narratorNight => 'Night falls. Everyone stays where they are.';

  @override
  String get narratorMorning => 'Morning comes, and something has changed.';

  @override
  String get narratorDiscussion => 'Now we talk. Who has a case?';

  @override
  String get narratorVoting => 'The decision belongs to the table.';

  @override
  String get narratorResult => 'The story ends, and the secrets are out.';

  @override
  String get roomPackLabel => 'Room presentation';

  @override
  String get roomNarratorLabel => 'Narrator';

  @override
  String get previewTransition => 'Play transition';

  @override
  String get previewSound => 'Play sound';

  @override
  String get previewIntro => 'Opening';

  @override
  String get previewOutro => 'Closing';

  @override
  String get previewSampleName => 'Sami';

  @override
  String get onlineRoomRefreshHint =>
      'Updates automatically. Choose a room to join.';

  @override
  String get onlineRoomsAll => 'All rooms';

  @override
  String get onlineRoomsNearlyReady => 'Need 1–2 players';

  @override
  String get onlineRoomsNoFilterMatches =>
      'No rooms need just 1–2 players right now. Browse all rooms or invite your friends.';

  @override
  String get onlineRoomVoiceOn => 'Voice enabled';

  @override
  String get onlineRoomVoiceOff => 'Voice disabled';

  @override
  String get onlineLobbyInviteHint =>
      'Share the room invite to bring your friends to this table.';

  @override
  String get onlineLobbyHostReadyHint =>
      'Your table has enough players. Start when everyone is ready.';

  @override
  String get onlineLobbyGuestReadyHint =>
      'Enough players are here. Your host will start the match.';

  @override
  String get onlineVoteSending => 'Sending your vote…';

  @override
  String get onlineVoteReceived =>
      'Vote received. Waiting for the ballot to close.';

  @override
  String get onlineVoteResolving =>
      'The ballot is closed. Waiting for the result.';

  @override
  String get onlineVoteSelectHint =>
      'Tap a player at the table, then confirm your vote.';

  @override
  String get onlineConfirmSuspicion => 'Confirm suspicion';

  @override
  String get onlineBeginVoting => 'Open voting';

  @override
  String get accountTitle => 'Account protection';

  @override
  String get accountAnonymousHint =>
      'Your coins and items are tied to this device only. Uninstalling or changing phones can lose them. Link an email to be able to recover them. Playing never needs an account.';

  @override
  String accountProtected(String email) {
    return 'Protected with $email';
  }

  @override
  String get accountLink => 'Protect with email';

  @override
  String get accountRecover => 'I already have a protected account';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountSendCode => 'Send code';

  @override
  String get accountCode => 'Code from the email';

  @override
  String get accountConfirm => 'Confirm';

  @override
  String accountCodeSent(String email) {
    return 'We sent an email to $email. It holds either a 6-digit code (type it below) or a link (open it, then tap «I opened the email link»). It can take a minute; check spam if you do not see it.';
  }

  @override
  String get accountRecoverWarning =>
      'You will sign in to your protected account. Coins on this device without an account will not move to it.';

  @override
  String get accountErrorEmail => 'That email does not look right.';

  @override
  String get accountErrorTaken =>
      'That email belongs to another account. Use «I already have a protected account».';

  @override
  String get accountErrorCode =>
      'The code is wrong or expired. Ask for a new one.';

  @override
  String get accountErrorRate =>
      'Too many requests. Wait a little and try again.';

  @override
  String get accountErrorUnavailable => 'Not available right now. Try later.';

  @override
  String get accountLinkOpened => 'I opened the email link';

  @override
  String get accountErrorLinkPending =>
      'The email is not confirmed yet. Open the link in the email, then tap again.';

  @override
  String get accountErrorLinkElsewhere =>
      'The link signs in the browser that opened it, not this app. Use the code from the email.';

  @override
  String get accountRecoverLinkNote =>
      'On a new device only the 6-digit code can sign this app in; the email link cannot. If your email has no code, recovery by code will work once our emails are updated.';

  @override
  String get coinPacksUnavailable =>
      'Buying coins is not available right now. Coins are still earned from online matches.';

  @override
  String get coinPacksNeedAccount =>
      'Before paying, protect your account with an email so paid coins stay with you on any device.';

  @override
  String coinPackCoins(int count) {
    return '$count coins';
  }

  @override
  String coinPackPrice(String amount) {
    return 'EGP $amount';
  }

  @override
  String get coinPayMethod => 'Payment method';

  @override
  String get coinPayInstapay => 'InstaPay';

  @override
  String get coinPayVodafone => 'Vodafone Cash';

  @override
  String get coinPayMethodOff => 'Not available now';

  @override
  String get coinManualNotice =>
      'Transfers are reviewed by hand, and coins are added after the transfer is confirmed';

  @override
  String get coinManualDetail =>
      'The payment page opens outside the game and may switch to your bank or wallet app. Transfer the exact amount shown, then come back and enter the transaction number. Opening or returning from the link adds no coins.';

  @override
  String coinCreateOrder(String amount) {
    return 'Confirm order: EGP $amount';
  }

  @override
  String coinOrderTitle(String reference) {
    return 'Order $reference';
  }

  @override
  String coinOrderSummary(int coins, String amount, String method) {
    return '$coins coins for EGP $amount via $method';
  }

  @override
  String coinOpenPayment(String method) {
    return 'Open $method';
  }

  @override
  String get coinOpenFailed =>
      'The browser did not open the page. Allow pop-ups for this site and try again.';

  @override
  String get coinDesktopHint =>
      'On a computer with the wallet app on your phone, open this site on the phone to complete the transfer.';

  @override
  String get coinSentTransfer => 'I sent the transfer';

  @override
  String get coinTransferReference => 'Transaction number';

  @override
  String get coinPayerHint => 'Sender name (optional)';

  @override
  String get coinClaimNote =>
      'This reports your transfer; it is not a confirmation. Nobody will ask for your PIN or a code.';

  @override
  String get coinCancelOrder => 'Cancel order';

  @override
  String get coinStatusAwaiting => 'Waiting for your transfer';

  @override
  String get coinStatusClaimed =>
      'Under review. Coins are added once the money is confirmed.';

  @override
  String coinStatusNeedsInfo(String note) {
    return 'We need details: $note';
  }

  @override
  String coinStatusPaid(int coins) {
    return '$coins coins added';
  }

  @override
  String coinStatusRejected(String note) {
    return 'Order declined: $note';
  }

  @override
  String get coinStatusCancelled => 'Order cancelled';

  @override
  String get coinStatusExpired =>
      'The order expired. If you already transferred, enter the transaction number and it will be reviewed.';

  @override
  String coinStatusRefunded(String note) {
    return 'Refunded: $note';
  }

  @override
  String get coinOrderFailed =>
      'The order was not recorded. Nothing was charged; try again.';

  @override
  String get adminCoinsTitle => 'Transfer review';

  @override
  String get adminNotAdmin => 'This account is not an admin.';

  @override
  String get adminEmpty => 'No orders waiting for review.';

  @override
  String get adminProviderTxn => 'Transaction ID in your statement';

  @override
  String get adminReceived => 'Amount received (EGP)';

  @override
  String get adminNote => 'Note to player';

  @override
  String get adminApprove => 'Received: add coins';

  @override
  String get adminNeedsInfo => 'Ask for details';

  @override
  String get adminReject => 'Decline';

  @override
  String get adminRefund => 'Money returned';

  @override
  String get adminCheckFirst =>
      'Check your bank or wallet statement yourself and match amount, method and reference before approving. If unsure, leave it under review.';

  @override
  String get adminErrorAmount =>
      'Amount does not match. Ask for details or decline.';

  @override
  String get adminErrorUsed => 'That transaction already funded another order.';

  @override
  String get adminErrorGeneric => 'Not done. Check the fields and try again.';

  @override
  String adminOrderLine(
    String reference,
    String account,
    String amount,
    String method,
    String claim,
  ) {
    return '$reference · $account · EGP $amount · $method · player ref: $claim';
  }

  @override
  String get adminFilterOpen => 'To review';

  @override
  String get adminFilterPaid => 'Paid';

  @override
  String get arrivalIdentityTitle => 'Your seat at the table';

  @override
  String get arrivalIdentityHint =>
      'Choose the name and face your friends will recognise.';

  @override
  String get arrivalWelcomeHint =>
      'A secret role. A room full of suspects. Your story starts here.';

  @override
  String get arrivalPactTitle => 'Before the first night';

  @override
  String arrivalStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get arrivalSaving => 'Saving your seat…';

  @override
  String get councilInvitation =>
      'Every voice has a story. Who will you believe?';

  @override
  String get witnessTableLoading => 'Opening the table…';

  @override
  String get witnessTableNoActions => 'Nobody has chosen anything at night yet';

  @override
  String witnessActionKill(String actor, String target) {
    return '$actor chose to kill $target';
  }

  @override
  String witnessActionProtect(String actor, String target) {
    return '$actor is protecting $target';
  }

  @override
  String witnessActionInvestigate(String actor, String target) {
    return '$actor checked $target';
  }

  @override
  String witnessActionSuspect(String actor, String target) {
    return '$actor suspects $target';
  }

  @override
  String get onlineDiscussionLive => 'The discussion is on';

  @override
  String get witnessEventNight => 'Night: everyone chooses in secret';

  @override
  String witnessEventOpening(String name) {
    return '$name is naming a suspect';
  }

  @override
  String get witnessEventDiscussion => 'The players still in are talking';

  @override
  String get witnessEventVoting => 'The vote is on';

  @override
  String get onlineAbandonedTitle => 'Everyone else has left';

  @override
  String get onlineAbandonedBody =>
      'There is nobody left at the table but you, so this match is over. Head home and start a new room.';

  @override
  String get nightCitizenRest => 'You are a Citizen';

  @override
  String get nightCitizenRestSupport =>
      'Nothing to do on the first night. Wait for the others to finish, and the day will come.';

  @override
  String readyToVote(int ready, int living) {
    return 'Ready to vote ($ready of $living)';
  }

  @override
  String readyToVoteWaiting(int ready, int living) {
    return 'Waiting for the rest ($ready of $living)';
  }

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsRulesTitle => 'Match rules';

  @override
  String get settingsRulesHint =>
      'Every new match starts from these, and you can still change them before one.';

  @override
  String get settingsSectionMore => 'Help & privacy';

  @override
  String get onlineRoomSettingsHint =>
      'Every change reaches everyone in the room right away.';

  @override
  String get vaultTitle => 'The Council Vault';

  @override
  String get vaultSubtitle => 'Your signature. Your council atmosphere.';

  @override
  String get storeFrames => 'Avatar frames';

  @override
  String get storeNameplates => 'Nameplates';

  @override
  String get storeBrowseNext => 'More products';

  @override
  String get storeBrowsePrevious => 'Previous products';

  @override
  String get cosmeticPackArchive => 'Moonlit Archive';

  @override
  String get cosmeticPackArchiveDesc =>
      'A moonlit archive behind the table in quiet silver, a moonlight transition between public phases, and an opening and closing line with sound. Everyone in the room sees it.';

  @override
  String get cosmeticNarratorKeeper => 'Secret Keeper';

  @override
  String get cosmeticNarratorKeeperDesc =>
      'A solemn recorded keeper voice marks each public phase in an archival style, the same for every player.';

  @override
  String get cosmeticNarratorNoir => 'Noir Narrator';

  @override
  String get cosmeticNarratorNoirDesc =>
      'A terse recorded noir voice marks each public phase, the same for every player.';

  @override
  String get cosmeticBundleNocturne => 'Nocturne Collection';

  @override
  String get cosmeticBundleNocturneDesc =>
      'Moonlit Archive, the Moonlit frame, the Noir nameplate and the Secret Keeper together.';

  @override
  String get packArchiveIntro => 'The archive opens its doors under the moon.';

  @override
  String get packArchiveOutro =>
      'The moonlight withdraws, and the files return to their shelves.';

  @override
  String get narratorKeeperNight => 'The ledger closes on the night\'s page.';

  @override
  String get narratorKeeperMorning => 'The day\'s page is open.';

  @override
  String get narratorKeeperDiscussion =>
      'Every word carries weight. Choose yours carefully.';

  @override
  String get narratorKeeperVoting => 'The council records its decision.';

  @override
  String get narratorKeeperResult =>
      'The ledger is closed; the story joins the archive.';

  @override
  String get narratorNoirNight => 'The city sleeps. The streets are empty.';

  @override
  String get narratorNoirMorning =>
      'Morning. Everyone is looking for the truth.';

  @override
  String get narratorNoirDiscussion =>
      'Everyone has a story. Who is telling the truth?';

  @override
  String get narratorNoirVoting => 'Decision time. Every vote has a price.';

  @override
  String get narratorNoirResult => 'Case closed.';

  @override
  String get storeAboutCoins => 'About coins';

  @override
  String get storeInside => 'What\'s inside';

  @override
  String storeBalance(int count) {
    return 'Your balance: $count coins';
  }

  @override
  String get storeRoomArtNote =>
      'The scene shows faintly behind the table in public phases only, never at night.';

  @override
  String get profileAddressLabel => 'Address me as';

  @override
  String get profileAddressHint =>
      'Arabic speaks to men and women differently, so roles and messages are written this way.';

  @override
  String onlinePlayingAs(String name) {
    return 'Playing as $name';
  }

  @override
  String get onlineNoPublicRoomsHint =>
      'Create a room and send your friends the code, or refresh in a moment.';

  @override
  String get lobbyInviteFriends => 'Invite friends';

  @override
  String get adStepsTitle => 'Optional bonus: up to 2 ads';

  @override
  String adStepsDisclosure(int total) {
    return 'Each ad you finish is verified and adds its coins; stopping after the first keeps it. Both ads together add +$total. Your match reward stays yours either way.';
  }

  @override
  String adStepAction(int step, int amount) {
    return 'Ad $step of 2 · +$amount';
  }

  @override
  String adStepDone(int step, int amount) {
    return 'Ad $step of 2 · +$amount added';
  }

  @override
  String adStepsComplete(int total) {
    return '+$total bonus coins added for this match.';
  }

  @override
  String get adRewardCheckAgain => 'Check again';

  @override
  String get adRewardNotConsented =>
      'Ads need your consent first. You can change it in Settings, under “Ad privacy choices”.';

  @override
  String get storeTabRewards => 'Rewards';

  @override
  String get dailyTitle => 'Daily rewards';

  @override
  String get dailyResetNote => 'A new day starts at 00:00 UTC.';

  @override
  String get dailyCofferTitle => 'Daily coffer';

  @override
  String dailyCofferBody(int amount) {
    return 'Free once a day: +$amount Council Coins.';
  }

  @override
  String dailyCofferClaim(int amount) {
    return 'Open · +$amount';
  }

  @override
  String get dailyCofferClaimed => 'Opened today. Come back tomorrow.';

  @override
  String dailyCofferGranted(int amount) {
    return '+$amount added to your coins.';
  }

  @override
  String dailyWeekBonusGranted(int amount) {
    return 'Seventh day! +$amount bonus.';
  }

  @override
  String get dailyWheelTitle => 'Free wheel';

  @override
  String get dailyWheelBody =>
      'One free spin each day. It costs nothing and has no cash value.';

  @override
  String get dailyWheelSpin => 'Spin free';

  @override
  String dailyWheelResult(int amount) {
    return 'The wheel landed on +$amount.';
  }

  @override
  String dailyWheelDone(int amount) {
    return 'Today\'s spin: +$amount. Next spin tomorrow.';
  }

  @override
  String get dailyWheelOdds => 'Exact odds';

  @override
  String dailyWheelOddsRow(int coins) {
    return '+$coins coins';
  }

  @override
  String dailyWheelPercent(String percent) {
    return '$percent%';
  }

  @override
  String get dailyWeekTitle => 'Seven-day card';

  @override
  String dailyWeekBody(int progress, int bonus) {
    return '$progress of 7 opened. Every seventh day you open adds +$bonus. A missed day resets nothing.';
  }

  @override
  String get dailyAdTitle => 'Daily ad (optional)';

  @override
  String dailyAdBody(int amount) {
    return 'One optional ad per day for exactly +$amount coins.';
  }

  @override
  String dailyAdAction(int amount) {
    return 'Watch · +$amount';
  }

  @override
  String get dailyAdDone => 'Today\'s ad reward is collected.';

  @override
  String get dailyAdInMatch => 'Available outside a match.';

  @override
  String get dailyFailed => 'Couldn\'t reach the vault. Try again.';

  @override
  String get dailyDayChanged => 'A new day started. Refreshed.';

  @override
  String get historyAdStep => 'Bonus ad';

  @override
  String get historyDailyCoffer => 'Daily coffer';

  @override
  String get historyDailyWheel => 'Free wheel';

  @override
  String get historyDailyWeek => 'Seventh-day bonus';

  @override
  String get historyDailyAd => 'Daily ad';

  @override
  String get historyPlayCoins => 'Coins bought on Google Play';

  @override
  String get historyPlayReversal => 'Google Play refund';

  @override
  String get storeTabPlay => 'Coins & pass';

  @override
  String get quietPassTitle => 'Quiet Pass';

  @override
  String get quietPassBody =>
      'Permanent. Removes every automatic ad: the app-open ad, the ads before and after matches and between menus, and the waiting-room banners. Optional reward ads stay available if you want them. No gameplay advantage.';

  @override
  String get quietPassOwned => 'Quiet Pass active';

  @override
  String playPackTitle(int coins) {
    return '$coins Council Coins';
  }

  @override
  String playBuy(String price) {
    return 'Buy · $price';
  }

  @override
  String get playUnavailable =>
      'Purchases aren\'t available on this device right now.';

  @override
  String get playPending =>
      'Payment pending. It is added when Google confirms it.';

  @override
  String get playVerified => 'Purchase confirmed.';

  @override
  String get playFailed => 'The purchase was not completed.';

  @override
  String get playAccountMismatch => 'This purchase belongs to another account.';

  @override
  String get playNeedsProtection =>
      'Protect your account with an email before buying, so a purchase is never lost with your phone.';

  @override
  String get playRestore => 'Restore purchases';

  @override
  String get playCoinsNote =>
      'Council Coins buy cosmetics only. They have no cash value and give no advantage.';

  @override
  String get playRefundRule =>
      'If a coin pack is refunded, its unspent coins are removed. Coins already spent become an amount your next coin pack pays first; earned coins and owned items are never taken.';

  @override
  String playDebtNotice(int coins) {
    return 'An earlier refund is still open: your next $coins purchased coins settle it first.';
  }

  @override
  String get quietPassRefundRule =>
      'If the pass is refunded, it is removed; your coins and items stay.';

  @override
  String get storeTabCouncil => 'Council';

  @override
  String get councilRankTitle => 'Your Council rank';

  @override
  String councilLevel(int level) {
    return 'Level $level';
  }

  @override
  String councilXpProgress(int xp, int next) {
    return '$xp / $next XP';
  }

  @override
  String councilXpTotal(int xp) {
    return '$xp XP';
  }

  @override
  String get councilMaxLevel => 'The top of the Council';

  @override
  String councilNextLevel(int coins) {
    return 'Next level: +$coins';
  }

  @override
  String councilWeekXp(int xp) {
    return '$xp XP this week';
  }

  @override
  String get councilHowXp =>
      'Every finished online match earns XP — a win earns more.';

  @override
  String get councilFailed => 'Couldn\'t reach the Council. Try again.';

  @override
  String get councilAttention => 'Something is waiting for you in the vault';

  @override
  String get contractsTitle => 'Today\'s contracts';

  @override
  String get contractsReset => 'Renews at 00:00 UTC';

  @override
  String get contractFinishOne => 'Finish a match';

  @override
  String contractFinishMany(int count) {
    return 'Finish $count matches';
  }

  @override
  String get contractTown => 'Finish a match on the town side';

  @override
  String get contractMafia => 'Finish a match on the mafia side';

  @override
  String get contractWinOne => 'Win a match';

  @override
  String contractWinMany(int count) {
    return 'Win $count matches';
  }

  @override
  String get contractHost => 'Host a match to the end';

  @override
  String get contractReunion => 'Play again with someone you\'ve played with';

  @override
  String contractProgress(int done, int target) {
    return '$done/$target';
  }

  @override
  String contractClaim(int coins) {
    return 'Claim +$coins';
  }

  @override
  String get contractClaimed => 'Claimed';

  @override
  String contractsBonus(int coins) {
    return 'Complete all three: +$coins';
  }

  @override
  String get contractsBonusDone => 'All three done';

  @override
  String contractBonusGranted(int coins) {
    return 'All three! +$coins bonus.';
  }

  @override
  String get contractIncomplete => 'Not yet — finish the match first.';

  @override
  String get weeklyTitle => 'This week\'s contract';

  @override
  String weeklyBody(int target) {
    return 'Finish $target online matches this week';
  }

  @override
  String weeklyReward(int coins, int xp) {
    return '+$coins coins and $xp XP';
  }

  @override
  String weeklyRewardCoins(int coins) {
    return '+$coins coins';
  }

  @override
  String get weeklyReset => 'Renews Monday 00:00 UTC';

  @override
  String get leaderboardTitle => 'Top this week';

  @override
  String get leaderboardOpen => 'This week\'s board';

  @override
  String leaderboardYou(int position) {
    return 'Your position: $position';
  }

  @override
  String get leaderboardNone => 'Play a match to enter the board';

  @override
  String get leaderboardEmpty => 'Nobody has earned XP this week yet.';

  @override
  String get leaderboardHidden =>
      'You\'re hidden from the board; only you see your position.';

  @override
  String get leaderboardVisibleLabel => 'Show me on the leaderboard';

  @override
  String get leaderboardVisibleBody =>
      'Your name, look and rank appear on the weekly board. Nothing about your matches is shown.';

  @override
  String get inviteTitle => 'Invite a friend';

  @override
  String inviteBody(int inviter, int invitee) {
    return '1. Send your code or room link to a friend who just installed the game (within 7 days).\n2. They open the link, or type the code under «Have an invite code?» in the Council.\n3. When they finish their first online match: you +$inviter, they +$invitee.';
  }

  @override
  String get inviteCopy => 'Copy code';

  @override
  String get inviteCopied => 'Code copied';

  @override
  String get inviteShare => 'Share';

  @override
  String inviteShareText(String code) {
    return 'Join me in Mafia Master! Use my invite code $code in the Council tab of the vault.';
  }

  @override
  String inviteCounters(int rewarded, int cap, int pending) {
    return 'Rewarded: $rewarded/$cap · Waiting: $pending';
  }

  @override
  String get inviteHaveCode => 'Have an invite code?';

  @override
  String get inviteField => 'Invite code';

  @override
  String get inviteRedeem => 'Use code';

  @override
  String get inviteRedeemed =>
      'Invite saved. Finish a match to unlock both rewards.';

  @override
  String get inviteRewarded => 'Invite reward received.';

  @override
  String inviteSettledNoCoinsNotice(String name) {
    return '$name completed the invite conditions — it counts toward your invite progress.';
  }

  @override
  String get inviteNotFound => 'That code doesn\'t exist.';

  @override
  String get inviteSelf => 'You can\'t use your own code.';

  @override
  String get inviteExpired =>
      'Invite codes are for new accounts, within 7 days.';

  @override
  String get inviteNotNew => 'Invite codes work before your first match.';

  @override
  String get inviteAlready => 'You\'ve already used an invite code.';

  @override
  String get inviteLoop =>
      'You invited this player — you can\'t use their code.';

  @override
  String get inviteLimit => 'This code has reached its limit.';

  @override
  String get inviteRateLimit => 'Too many tries. Try again tomorrow.';

  @override
  String resultContractToast(String name, int coins) {
    return 'Contract complete: $name +$coins';
  }

  @override
  String resultWeeklyToast(int coins) {
    return 'Weekly contract complete: +$coins';
  }

  @override
  String resultXpGained(int xp) {
    return '+$xp XP';
  }

  @override
  String get resultClaimHint => 'Claim them in the vault\'s Council tab.';

  @override
  String levelUpTitle(String title) {
    return 'You rose to $title';
  }

  @override
  String levelUpBody(int level, int coins) {
    return 'Level $level · +$coins coins';
  }

  @override
  String get rankTier1 => 'Newcomer';

  @override
  String get rankTier2 => 'Informant';

  @override
  String get rankTier3 => 'Night Watch';

  @override
  String get rankTier4 => 'Investigator';

  @override
  String get rankTier5 => 'Notable';

  @override
  String get rankTier6 => 'Councillor';

  @override
  String get rankTier7 => 'Capo';

  @override
  String get rankTier8 => 'Consigliere';

  @override
  String get rankTier9 => 'Council Elder';

  @override
  String get rankTier10 => 'Godfather';

  @override
  String rankSemantics(String title, int level) {
    return '$title, level $level';
  }

  @override
  String get bundleTitle => 'Starter Bundle';

  @override
  String bundleBody(int coins) {
    return '$coins coins + the Council Seal frame, sold nowhere else. Once per account.';
  }

  @override
  String get bundleOwned => 'You own the Starter Bundle';

  @override
  String get bundleRefundRule =>
      'If it is refunded, its coins are settled like a coin pack and the Council Seal frame is removed.';

  @override
  String get bundleAlreadyOwned =>
      'This account already has the Starter Bundle; the extra purchase is refunded by Google Play.';

  @override
  String get cosmeticFrameSeal => 'Council Seal';

  @override
  String get cosmeticFrameSealDesc =>
      'A wax-red seal ring with eight gold studs — the Starter Bundle\'s own frame.';

  @override
  String get cosmeticFrameInvite => 'Companions Frame';

  @override
  String get cosmeticFrameInviteDesc =>
      'An exclusive frame earned when ten friends complete your invite conditions.';

  @override
  String get coinPayStep =>
      'Choose a pack, then tap a payment method: its page opens. Come back here with the transfer reference.';

  @override
  String coinPayWith(String method) {
    return 'Pay with $method';
  }

  @override
  String get webPassTitle => 'Quiet Pass for the Android app';

  @override
  String get webPassBody =>
      'The website shows no ads. The pass removes every automatic ad in the Android app (app-open, after-match and banners) on this same linked account. Optional reward ads stay available.';

  @override
  String get webPassOwned => 'Quiet Pass active on this account';

  @override
  String coinOrderPassSummary(String price, String method) {
    return 'Quiet Pass · EGP $price · $method';
  }

  @override
  String get awardsTitle => 'Match awards';

  @override
  String get awardMvp => 'MVP';

  @override
  String get awardSharpEye => 'Sharp Eye';

  @override
  String get awardSurvivor => 'Survivor';

  @override
  String get awardSilverTongue => 'Silver Tongue';

  @override
  String get awardLifesaver => 'Lifesaver';

  @override
  String get awardPerfectCrime => 'Perfect Crime';

  @override
  String get awardFirstBlood => 'First Blood';

  @override
  String get awardMvpBody => 'The winning side\'s standout';

  @override
  String get awardSharpEyeBody => 'Most votes on the Mafia';

  @override
  String get awardSurvivorBody => 'Still standing at the end';

  @override
  String get awardSilverTongueBody => 'Brought the table along';

  @override
  String get awardLifesaverBody => 'The Doctor\'s save held';

  @override
  String get awardPerfectCrimeBody => 'The Mafia won untouched';

  @override
  String get awardFirstBloodBody => 'First vote that caught the Mafia';

  @override
  String awardsYouEarned(int coins) {
    return 'Your awards: +$coins coins';
  }

  @override
  String get awardsLoading => 'Counting the awards';

  @override
  String get reactionsLabel => 'Reactions';

  @override
  String get reactionLaugh => 'Laugh';

  @override
  String get reactionShock => 'Shock';

  @override
  String get reactionSuspicious => 'Suspicious';

  @override
  String get reactionApplause => 'Applause';

  @override
  String get reactionRose => 'Rose';

  @override
  String get reactionSkull => 'Skull';

  @override
  String get reactionCoffee => 'Coffee';

  @override
  String get reactionCrown => 'Crown';

  @override
  String reactionFrom(String name, String reaction) {
    return '$name: $reaction';
  }

  @override
  String get reactionSlowDown => 'Easy, one at a time';

  @override
  String get cofferStripReady => 'Today\'s coffer is ready';

  @override
  String get cofferStripBody => 'Claim it right here.';

  @override
  String get cofferStripClaim => 'Claim';

  @override
  String cofferStripGot(int amount) {
    return '+$amount added to your vault';
  }

  @override
  String get cofferStripSpin => 'Spin the wheel';

  @override
  String get cofferStripLater => 'Later';

  @override
  String get welcomeBackTitle => 'We missed you';

  @override
  String get welcomeBackBody => 'Your daily coffer is waiting in the vault.';

  @override
  String get welcomeBackBodyPlain => 'The table is ready when you are.';

  @override
  String get welcomeBackOpen => 'Open the vault';

  @override
  String get welcomeBackDismiss => 'Later';

  @override
  String get founderBadge => 'Founder';

  @override
  String get founderBadgeBody => 'One of the council\'s first players';

  @override
  String shareCardAwards(String awards) {
    return 'Awards: $awards';
  }

  @override
  String get adBannerLabel => 'Advertisement';

  @override
  String get adExtrasTitle => 'Optional extras';

  @override
  String get adExtrasBody =>
      'Each is one optional ad, once a day. Nothing here affects play.';

  @override
  String get adExtraSpinTitle => 'Second spin';

  @override
  String get adExtraSpinBody =>
      'After today\'s free spin: one more, same odds, drawn by the server.';

  @override
  String adExtraSpinOdds(String odds) {
    return 'Odds: $odds';
  }

  @override
  String get adExtraSpinAction => 'Watch · spin again';

  @override
  String get adExtraSpinNotReady => 'Spin today\'s free wheel first.';

  @override
  String adExtraSpinResult(int amount) {
    return 'Second spin: +$amount coins.';
  }

  @override
  String get adExtraCofferTitle => 'Double today\'s coffer';

  @override
  String adExtraCofferAction(int amount) {
    return 'Watch · +$amount';
  }

  @override
  String get adExtraCofferNotReady => 'Open today\'s coffer first.';

  @override
  String adExtraCofferDone(int amount) {
    return 'Coffer doubled: +$amount';
  }

  @override
  String get adExtraSwapTitle => 'Swap a contract';

  @override
  String get adExtraSwapBody =>
      'Replace one of today\'s unclaimed contracts with another.';

  @override
  String get adExtraSwapAction => 'Choose · watch';

  @override
  String get adExtraSwapPick => 'Which contract to swap?';

  @override
  String adExtraSwapSlot(int number) {
    return 'Contract $number';
  }

  @override
  String get adExtraSwapDone => 'Contract swapped';

  @override
  String get adExtraNoneLeft => 'Nothing to swap today.';

  @override
  String get adExtraUsed => 'Used today';

  @override
  String get vaultOneTime => 'One time only';

  @override
  String get vaultBestValue => 'Best value';

  @override
  String get vaultMostCoins => 'Most coins';

  @override
  String get coinPickPackFirst =>
      'Pick a pack above first, then how you\'ll pay.';

  @override
  String get adDoubleTitle => 'Optional bonus: double or triple this match';

  @override
  String adDoubleAction(int total) {
    return 'Watch an ad · double to $total';
  }

  @override
  String adTripleAction(int total) {
    return 'Another ad · triple to $total';
  }

  @override
  String adDoubleDone(int total) {
    return 'Doubled · $total coins';
  }

  @override
  String adTripleDone(int total) {
    return 'Tripled · $total coins';
  }

  @override
  String adTripleComplete(int total) {
    return 'This match now pays $total coins.';
  }

  @override
  String adDoubleDisclosure(int base, int doubled, int tripled) {
    return 'This match paid $base. One verified ad makes it $doubled; a second makes it $tripled. Stopping after the first keeps the double. Your match reward stays yours either way.';
  }

  @override
  String payWithGoogle(String price) {
    return 'Pay with Google · $price';
  }

  @override
  String get pay2TabTransfer => 'InstaPay / Vodafone Cash';

  @override
  String get pay2AlreadyOwned => 'This account already has it.';

  @override
  String get pay2TooMany =>
      'You have two orders waiting for review. A new one opens when one is reviewed.';

  @override
  String get pay2Duplicate =>
      'This screenshot was already used for an order. Upload the screenshot of this transfer.';

  @override
  String get pay2ProofRequired =>
      'The transfer screenshot and the sender name are both required.';

  @override
  String get pay2StepChoose => 'Choose the item and how to pay';

  @override
  String get pay2StepPayHint =>
      'Tapping a method opens it outside the game. Send the exact amount, then come back here.';

  @override
  String pay2StepPay(String amount, String method) {
    return 'Send exactly EGP $amount with $method';
  }

  @override
  String get pay2StepProof => 'Come back and upload the transfer screenshot';

  @override
  String get pay2PickImage => 'Choose the transfer screenshot';

  @override
  String get pay2ImageChosen => 'Screenshot ready · change';

  @override
  String get pay2ImageFailed =>
      'That image could not be read. Try another screenshot.';

  @override
  String pay2SenderName(String method) {
    return 'Sender name exactly as shown in $method';
  }

  @override
  String get pay2Submit => 'Send for review';

  @override
  String get pay2Sent =>
      'Sent. We review it by hand; coins are added once the money is confirmed.';

  @override
  String pay2OrderSummary(String product, String amount, String method) {
    return '$product · EGP $amount · $method';
  }

  @override
  String get pay2StatusAwaiting => 'Waiting for your transfer screenshot';

  @override
  String get pay2StatusPending => 'Under review';

  @override
  String get pay2StatusApproved => 'Approved';

  @override
  String get pay2StatusExpired =>
      'Expired: not reviewed within 72 hours. If you paid, contact support with the order number.';

  @override
  String get pay2OrdersTitle => 'Your orders';

  @override
  String get pay2ReviewDetail =>
      'Same price as Google Play. Orders are reviewed by hand within 72 hours; a rejected order shows the reason here.';

  @override
  String get pay2ProofPrivacy =>
      'The screenshot and sender name are stored privately, only to verify the order, and the screenshot is deleted 90 days after review. Nobody will ask for a PIN or code.';

  @override
  String get adminPaymentsTitle => 'Payment orders';

  @override
  String get adminSignInHint =>
      'Sign in with the admin email. The email holds a one-time code or a link; opening the link in this browser signs this page in.';

  @override
  String adminSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get adminWebOnly => 'The admin page is available on the website only.';

  @override
  String get adminFilterPending => 'Pending';

  @override
  String get adminFilterApproved => 'Approved';

  @override
  String get adminFilterRejected => 'Rejected';

  @override
  String get adminFilterExpired => 'Expired';

  @override
  String get adminRejectReason => 'Reason (shown to the player)';

  @override
  String get adminReasonRequired => 'Write a reason first.';

  @override
  String get adminProofGone => 'Screenshot deleted (retention)';

  @override
  String get adminApproveShort => 'Approve';

  @override
  String get adminRejectShort => 'Reject';

  @override
  String get adminRefundShort => 'Refund';

  @override
  String adminOrderMeta(String product, String amount, String method) {
    return '$product · EGP $amount · $method';
  }

  @override
  String adminSender(String name) {
    return 'Sender: $name';
  }

  @override
  String adminPlayer(String name) {
    return 'Player: $name';
  }

  @override
  String get adminErrorOwned =>
      'The player already owns this. Reject and return the money.';

  @override
  String get adminErrorProof => 'This order has no screenshot.';

  @override
  String get bondDossiersTitle => 'The Four Dossiers';

  @override
  String get bondDossiersHint => 'They remember. You are in it.';

  @override
  String bondCaseCount(int count) {
    return 'Cases $count';
  }

  @override
  String bondVictoryCount(int count) {
    return 'Victories $count';
  }

  @override
  String bondWitnessCount(int count) {
    return 'Witnesses $count';
  }

  @override
  String bondPersonalCount(int count) {
    return 'Personal $count';
  }

  @override
  String get bondLockedLine =>
      'Finish a case with this character at the table.';

  @override
  String get bondMafiaTier1 =>
      'I remember this table. It knew when to keep quiet.';

  @override
  String get bondMafiaTier2 =>
      'A clean story needs fewer words than a nervous one.';

  @override
  String get bondMafiaTier3 =>
      'You have learned that patience can look like innocence.';

  @override
  String get bondMafiaTier4 =>
      'The room changes when you enter. That is influence.';

  @override
  String get bondDoctorTier1 => 'Not every rescue is seen. It still counts.';

  @override
  String get bondDoctorTier2 =>
      'You are beginning to hear danger before it knocks.';

  @override
  String get bondDoctorTier3 =>
      'Saving the right moment matters more than saving face.';

  @override
  String get bondDoctorTier4 =>
      'The table breathes easier when you keep watch.';

  @override
  String get bondDetectiveTier1 =>
      'One case is enough to teach the value of doubt.';

  @override
  String get bondDetectiveTier2 =>
      'A changed story leaves a clearer print than a loud one.';

  @override
  String get bondDetectiveTier3 =>
      'You notice the pause before the answer now.';

  @override
  String get bondDetectiveTier4 =>
      'Nothing escapes you except what has not happened yet.';

  @override
  String get bondCitizenTier1 =>
      'A town survives because somebody keeps listening.';

  @override
  String get bondCitizenTier2 =>
      'You have learned when the simple question is strongest.';

  @override
  String get bondCitizenTier3 =>
      'The table follows facts when you hold your ground.';

  @override
  String get bondCitizenTier4 =>
      'You are the memory of every room you leave behind.';

  @override
  String get bondHomeMafia =>
      'The Mafia remembers a victory nobody could stop.';

  @override
  String get bondHomeDoctor =>
      'The Doctor remembers the night everyone came home.';

  @override
  String get bondHomeDetective =>
      'The Detective has kept your files. It has been a while.';

  @override
  String get bondHomeCitizen =>
      'The Citizen is waiting for the table to gather again.';

  @override
  String get bondMomentMafia =>
      'The Mafia closes this file with a quiet smile.';

  @override
  String get bondMomentDoctor => 'The Doctor counts who remained standing.';

  @override
  String get bondMomentDetective =>
      'The Detective writes the last fact in the margin.';

  @override
  String get bondMomentCitizen =>
      'The Citizen keeps this case for the next gathering.';

  @override
  String get bondTitleMafia => 'Keeper of the Quiet Room';

  @override
  String get bondTitleDoctor => 'Guardian of the Last Lamp';

  @override
  String get bondTitleDetective => 'Reader of the Unsaid';

  @override
  String get bondTitleCitizen => 'Memory of the Table';

  @override
  String get bondScreenSubtitle => 'They remember. You are in it.';

  @override
  String bondSealedLetter(int count) {
    return 'Sealed letter · opens in $count cases';
  }

  @override
  String get bondLettersTitle => 'Letters to you';

  @override
  String get bondOpenAll => 'All dossiers';

  @override
  String bondNewLetter(String name) {
    return 'A new letter from $name';
  }

  @override
  String get bondStrangerLine => 'You have not sat at this table yet.';

  @override
  String get warmupTitle => 'Setting the table…';

  @override
  String get warmupOnce => 'Just this once. Instant from now on.';

  @override
  String get rematchHost => 'Another round, same table';

  @override
  String get rematchJoin => 'The host opened the next round · Join';

  @override
  String get rematchWaiting => 'Waiting for the host to open the next round…';

  @override
  String get friendsTitle => 'Friends';

  @override
  String friendsTitleWithOnline(int count) {
    return 'Friends · $count at a table now';
  }

  @override
  String friendsInvitedYou(String name) {
    return '$name invited you · Join';
  }

  @override
  String get friendsInvites => 'Invites for you';

  @override
  String get friendsJoin => 'Join';

  @override
  String get friendsRequests => 'Friend requests';

  @override
  String get friendsWantsYou => 'Wants to be friends';

  @override
  String get friendsDecline => 'Decline';

  @override
  String get friendsAccept => 'Accept';

  @override
  String get friendsYours => 'Your friends';

  @override
  String get friendsNone =>
      'None yet. People you play online with appear below.';

  @override
  String friendsInLobby(int count) {
    return 'In a room · $count at the table';
  }

  @override
  String get friendsPlaying => 'In a match now';

  @override
  String get friendsAway => 'Not around';

  @override
  String get friendsInvited => 'Invited';

  @override
  String get friendsInvite => 'Invite';

  @override
  String get friendsRecent => 'Played with lately';

  @override
  String friendsMatchesTogether(int count) {
    return '$count matches together';
  }

  @override
  String get friendsPending => 'Waiting for reply';

  @override
  String get friendsAdd => 'Add';

  @override
  String get friendsInviteToRoom => 'Invite friends';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordAgain => 'Password again';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authPasswordRule => 'At least 8 characters';

  @override
  String get authShow => 'Show';

  @override
  String get authHide => 'Hide';

  @override
  String get authCode => 'Code';

  @override
  String get authGoogle => 'Continue with Google';

  @override
  String get authGoogleContinue => 'Finish in the browser, then come back.';

  @override
  String get authGoogleTaken =>
      'That Google account already belongs to another player. Signing in to it leaves the guest profile on this device.';

  @override
  String get authGoogleUseExisting => 'Sign in with that Google account';

  @override
  String get authGuestTitle => 'Keep your account with you';

  @override
  String get authGuestBody =>
      'Your coins, items, rank and friends follow you to any phone. You can keep playing as a guest.';

  @override
  String get authCreate => 'Create account';

  @override
  String get authCreateBody =>
      'Everything you have now moves into the account as it is.';

  @override
  String get authHaveAccount => 'I have an account · Sign in';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authVerifyTitle => 'Confirm your email';

  @override
  String authVerifyBody(String email) {
    return 'We sent a 6-digit code to $email. Type it here or open the link in the email.';
  }

  @override
  String get authVerify => 'Confirm';

  @override
  String get authResend => 'Send the code again';

  @override
  String authResendIn(int seconds) {
    return 'Send again in ${seconds}s';
  }

  @override
  String get authResent => 'Sent again.';

  @override
  String get authWelcome => 'Welcome. Your account is ready.';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignInBody =>
      'You will be in your account; this device\'s guest progress does not move to it.';

  @override
  String get authRemember => 'Remember me';

  @override
  String get authForgot => 'Forgot password?';

  @override
  String get authForgotBody =>
      'Enter your account email and we\'ll send a code to set a new password.';

  @override
  String get authResetTitle => 'New password';

  @override
  String get authResetSave => 'Save';

  @override
  String get authPasswordChanged => 'Password changed.';

  @override
  String get authChangePassword => 'Change password';

  @override
  String get authSetPassword => 'Set a password';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authVerified => 'Email confirmed';

  @override
  String get authViaGoogle => 'Google';

  @override
  String get authViaPassword => 'Password';

  @override
  String get authSafe =>
      'Your account is saved. On a new phone, sign in and everything comes back.';

  @override
  String get authWeakPassword => 'The password needs at least 8 characters.';

  @override
  String get authWrongPassword => 'Email or password is not right.';

  @override
  String get authNotConfirmed =>
      'That email isn\'t confirmed yet. Check the code we sent.';

  @override
  String get authSamePassword => 'That is the same password as before.';

  @override
  String get authMismatch => 'The two passwords don\'t match.';

  @override
  String get authProviderOff => 'That way in isn\'t available right now.';

  @override
  String get authAccount => 'Account';

  @override
  String get authGuestBadge => 'Guest';

  @override
  String get authManage => 'Manage';

  @override
  String get profileStatMatches => 'Matches';

  @override
  String get profileStatOnline => 'Online';

  @override
  String get profileStatLetters => 'Character letters';

  @override
  String get casebookTitle => 'The Casebook';

  @override
  String get casebookTonight => 'Tonight';

  @override
  String get casebookSeason => 'Season';

  @override
  String get casebookLegacy => 'Legacy';

  @override
  String casebookDaysLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days left in the season',
      one: '1 day left in the season',
      zero: 'The season closes today',
    );
    return '$_temp0';
  }

  @override
  String get casebookWeekly => 'Case of the week';

  @override
  String get casebookBonus => 'Close all three for more';

  @override
  String get casebookBonusTaken => 'Every case closed today';

  @override
  String casebookFrom(String name) {
    return 'From the $name';
  }

  @override
  String get casebookClaim => 'Take it';

  @override
  String get casebookClaimed => 'Closed';

  @override
  String get casebookClaimError => 'That didn\'t go through. Try again';

  @override
  String casebookLevel(int n) {
    return 'Level $n';
  }

  @override
  String casebookXp(int xp, int next) {
    return '$xp / $next';
  }

  @override
  String casebookXpGain(int n) {
    return '+$n XP';
  }

  @override
  String get casebookSeasonDone => 'Season complete';

  @override
  String get casebookTitleReward => 'New title';

  @override
  String get casebookItemReward => 'New cosmetic';

  @override
  String casebookRank(int n) {
    return 'Council rank $n';
  }

  @override
  String get casebookAchievements => 'Achievements';

  @override
  String casebookReady(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n rewards to take',
      one: '1 reward to take',
    );
    return '$_temp0';
  }

  @override
  String get casebookFailed => 'The casebook can\'t open right now';

  @override
  String get casebookRetry => 'Try again';

  @override
  String get casebookResult => 'Your casebook moved · open it';

  @override
  String caseFinish(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Finish $n online matches',
      one: 'Finish an online match',
    );
    return '$_temp0';
  }

  @override
  String caseWin(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Win $n matches',
      one: 'Win a match',
    );
    return '$_temp0';
  }

  @override
  String caseHost(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Host $n tables to the end',
      one: 'Host a table to the end',
    );
    return '$_temp0';
  }

  @override
  String caseReunion(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Play again with $n people you\'ve sat with',
      one: 'Play again with someone you\'ve sat with',
    );
    return '$_temp0';
  }

  @override
  String casePublic(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Sit at $n public tables',
      one: 'Sit at a public table',
    );
    return '$_temp0';
  }

  @override
  String caseInvite(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Bring $n friends to play',
      one: 'Bring a friend to play',
    );
    return '$_temp0';
  }

  @override
  String caseStreak(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Play $n days in a row',
      one: 'Play today',
    );
    return '$_temp0';
  }

  @override
  String caseDailies(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Close $n full days of cases',
      one: 'Close a full day of cases',
    );
    return '$_temp0';
  }

  @override
  String caseLevel(int n) {
    return 'Reach season level $n';
  }

  @override
  String casebookProgress(int progress, int target) {
    return '$progress of $target';
  }

  @override
  String get onlineRoomUnavailable => 'This table isn\'t available to you.';

  @override
  String get onlineNameNotAllowed =>
      'That name isn\'t allowed. Pick another one.';

  @override
  String get onlineAccountRestricted =>
      'Your account can\'t join this right now.';

  @override
  String get safetyCategory => 'What happened?';

  @override
  String get safetyCatHarassment => 'Harassment';

  @override
  String get safetyCatHate => 'Hate or racism';

  @override
  String get safetyCatSexual => 'Sexual content';

  @override
  String get safetyCatThreat => 'Threat';

  @override
  String get safetyCatSpam => 'Spam';

  @override
  String get safetyCatCheating => 'Cheating';

  @override
  String get safetyCatName => 'Inappropriate name';

  @override
  String get safetyCatOther => 'Something else';

  @override
  String get safetyLimited => 'You\'ve reached today\'s limit.';

  @override
  String get safetyNoticeWarn =>
      'You were reported and warned. Keep the table fair and kind.';

  @override
  String get safetyNoticeVoice => 'Voice is off for your account.';

  @override
  String get safetyNoticePublic => 'Public tables are closed to your account.';

  @override
  String get safetyNoticeSuspend => 'Online play is closed to your account.';

  @override
  String safetyNoticeUntil(String date) {
    return 'Until $date.';
  }

  @override
  String get safetyNoticeForever => 'Permanently.';

  @override
  String get safetyNoticeOk => 'OK';

  @override
  String get adminSafetyTitle => 'Reports';

  @override
  String get adminSafetyOpen => 'Open';

  @override
  String get adminSafetyActioned => 'Actioned';

  @override
  String get adminSafetyDismissed => 'Dismissed';

  @override
  String get adminSafetyCtxLobby => 'Lobby';

  @override
  String get adminSafetyCtxMatch => 'Match';

  @override
  String get adminSafetyCtxResult => 'Result';

  @override
  String get adminSafetyCtxFriends => 'Friends';

  @override
  String adminSafetyTarget(String name, int open, int actioned) {
    return '$name · $open open · $actioned actioned';
  }

  @override
  String get adminSafetyDismiss => 'Dismiss';

  @override
  String get adminSafetyWarn => 'Warn';

  @override
  String get adminSafetyNoVoice => 'No voice, 7 days';

  @override
  String get adminSafetyNoPublic => 'No public tables, 7 days';

  @override
  String adminSafetySuspendDays(int days) {
    return 'Suspend $days days';
  }

  @override
  String get adminSafetySuspendForever => 'Suspend permanently';

  @override
  String get adminSafetyPurge => 'Apply retention now';

  @override
  String get adminSafetyMore => 'Load more';

  @override
  String get adminSafetyOpenQueue => 'Reports queue';

  @override
  String get witnessWhispersTitle => 'Whispers';

  @override
  String witnessWhisperLine(String from, String to) {
    return '$from to $to';
  }

  @override
  String get witnessWhisperMasked => 'Hidden: you blocked the sender.';

  @override
  String get witnessWhisperReport => 'Report this whisper';

  @override
  String get witnessWhispersDisclosure =>
      'Players who are out can read the whispers.';

  @override
  String get thursdayNight => 'Thursday Night';

  @override
  String thursdayProgress(int count) {
    return 'Matches: $count/2';
  }

  @override
  String get thursdayLine =>
      'Every Thursday from 8 PM: two matches here = 40 season points and a stamp.';

  @override
  String get thursdayOpensLater => 'Opens at 8 PM';

  @override
  String get thursdayOpenRoom => 'Open a Thursday room';

  @override
  String get thursdayJoinRoom => 'Join the Thursday room';

  @override
  String get thursdayDone => 'Thursday stamp earned. Play on as usual.';

  @override
  String get lobbyReadyAction => 'Ready';

  @override
  String get lobbyUnreadyAction => 'Not ready';

  @override
  String lobbyReadyCount(int ready, int total) {
    return '$ready of $total ready';
  }

  @override
  String get witnessSeatQuiet => 'Nothing has touched this seat yet';

  @override
  String get witnessNightTitle => 'At night';

  @override
  String get witnessWhisperReported => 'Report received';

  @override
  String get witnessManageSeat => 'Manage seat';

  @override
  String get witnessLetterOpen => 'Open the whisper';

  @override
  String get onlineWeatherRetry => 'Try now';

  @override
  String get xpUnit => 'XP';

  @override
  String inviteFirstMatchNotice(String name, int coins) {
    return '$name played their first match — you got $coins coins';
  }

  @override
  String inviteProgressNotice(int count) {
    return 'Your friend played $count of 3';
  }

  @override
  String inviteSettledNotice(String name, int coins) {
    return '$name finished three matches — you got $coins coins';
  }

  @override
  String inviteSettledCounter(
    int season,
    int seasonCap,
    int lifetime,
    int lifetimeCap,
  ) {
    return 'Settled invites: $season/$seasonCap this season · $lifetime/$lifetimeCap all time';
  }

  @override
  String get inviteNoticeFriend => 'Your friend';

  @override
  String get partnerDetective => 'Detective';

  @override
  String get partnerDoctor => 'Doctor';

  @override
  String get partnerMafia => 'Mafia';

  @override
  String get partnerCitizen => 'Citizen';

  @override
  String get partnerBusy => 'You can change your partner after the match';

  @override
  String get titlesNone =>
      'No titles yet — they come from the season and invites';

  @override
  String get titlesUnequip => 'No title';

  @override
  String get passInventoryTitle => 'You still have rewards today';

  @override
  String get passInventoryDailyAd => 'Today\'s rewarded ad';

  @override
  String get passInventoryExtraSpin => 'An extra wheel spin';

  @override
  String get passInventoryExtraCoffer => 'An extra coffer';

  @override
  String get passInventoryOpen => 'Open rewards';

  @override
  String get profilePlatePreview => 'Your name shows as:';

  @override
  String get storeRevealTitle => 'It\'s yours';

  @override
  String get storeEquipNow => 'Wear it now';

  @override
  String get storeEquipLater => 'Later';

  @override
  String get storeRevealDone => 'Done';

  @override
  String get storeChangesFrame =>
      'Shows around your portrait at the table, on your profile, for your friends and on the Council board';

  @override
  String get storeChangesPlate =>
      'Your name shows on it at the table, on your profile, for your friends and on the result';

  @override
  String get storeChangesPack =>
      'Dresses rooms you host: the public phases\' backdrop and transitions, online and in pass-and-play';

  @override
  String get storeChangesNarrator =>
      'The narrator\'s recorded voice, lines and look at every public phase, online and in pass-and-play';

  @override
  String get storeChangesBundle =>
      'Everything in it is yours; wear any part from your collection';

  @override
  String get storeTryOn => 'Try it on';

  @override
  String get storeWearing => 'Wearing now';

  @override
  String get titlesHeading => 'Your titles';

  @override
  String partnerCasebookLine(String who) {
    return '$who: every case you close is written here';
  }

  @override
  String lobbyReadyCountdown(int seconds) {
    return '${seconds}s left to confirm you\'re ready';
  }

  @override
  String get inviteSheetTitle => 'Invite players';

  @override
  String get inviteTabFriends => 'Friends';

  @override
  String get inviteTabSearch => 'Search by name';

  @override
  String get inviteTabNearby => 'People near you';

  @override
  String get inviteSend => 'Invite';

  @override
  String get inviteSent => 'Sent';

  @override
  String get inviteFailed => 'Didn\'t go through, try again';

  @override
  String get inviteSearchHint => 'Type a name or @username';

  @override
  String get inviteSearchEmpty => 'Nobody by that name';

  @override
  String get inviteSearchShort => 'Type at least two letters';

  @override
  String get inviteNearbyEmpty => 'Nobody here right now';

  @override
  String get inviteFriendsEmpty => 'No friends yet — search by name';

  @override
  String get inviteFilterNear => 'Near you';

  @override
  String get inviteFilterOnline => 'Online now';

  @override
  String get inviteFilterPlayed => 'Played with';

  @override
  String get inviteFilterLevel => 'Your level';

  @override
  String get inviteStateOnline => 'Online';

  @override
  String get inviteStateLobby => 'In a lobby';

  @override
  String get inviteStatePlaying => 'Playing';

  @override
  String get inviteStateAway => 'Away';

  @override
  String inviteLevel(int level) {
    return 'Level $level';
  }

  @override
  String get inviteMore => 'Load more';

  @override
  String get inviteIncomingTitle => 'Game invite';

  @override
  String inviteIncomingBody(String name) {
    return '$name invites you to play together';
  }

  @override
  String inviteIncomingCode(String code) {
    return 'Room $code';
  }

  @override
  String get inviteEnter => 'Join';

  @override
  String get inviteLater => 'Later';

  @override
  String get inviteRoomGone => 'That room already started or closed';

  @override
  String get profileHandleLabel => 'Username';

  @override
  String get profileHandleHint => '3–20 letters, digits or _';

  @override
  String get profileHandleSave => 'Change';

  @override
  String get profileHandleTaken => 'That username is taken';

  @override
  String get profileHandleWait => 'You can change it again later';

  @override
  String get profileHandleRefused => 'That username isn\'t allowed';

  @override
  String get profileHandleInvalid => 'Letters, digits or _ only, 3 to 20';

  @override
  String get profileHideFromSearch => 'Hide me from search';

  @override
  String get profileMuteStrangers =>
      'No invites from people who aren\'t friends';

  @override
  String get pushChannelInvites => 'Game invites';

  @override
  String get pushChannelInvitesDesc => 'When someone invites you to their room';

  @override
  String get pushChannelSocial => 'Friends';

  @override
  String get pushChannelSocialDesc => 'Friend requests and accepted requests';

  @override
  String get revealWhispersNotice =>
      'In this room, whispers are shown to everyone after the match';

  @override
  String get revealWhispersButton => 'Whispers';

  @override
  String get revealWhispersTitle => 'The match\'s whispers';

  @override
  String get revealWhispersEmpty => 'Nobody whispered this match';

  @override
  String get revealWhispersMasked => 'A whisper from a player you blocked';

  @override
  String get revealWhispersFailed => 'Couldn\'t load the whispers';

  @override
  String get onboardAccountTitle => 'Keep your progress?';

  @override
  String get onboardAccountHint =>
      'Sign in with Google or email so your coins, rank and friends follow you to any phone. Or continue without signing in; you can link an account later from your profile without losing anything.';

  @override
  String get onboardAccountSignIn => 'Sign in (Google or email)';

  @override
  String get onboardAccountGuest => 'Continue without signing in';

  @override
  String onboardAccountSignedIn(String email) {
    return 'Signed in as $email';
  }

  @override
  String get onboardAccountSignedInPlain => 'You are signed in';

  @override
  String get deleteAccountRow => 'Delete my account and data';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'We will erase your account, coins, items, rank, friends and all your online data from the server, and it cannot be brought back. What is on your phone (old match history) stays there; clear it from the app\'s data in your phone settings.';

  @override
  String get deleteAccountKept =>
      'Abuse reports that are still needed and payment records are kept for a limited time, no longer tied to your account.';

  @override
  String get deleteAccountConfirm => 'I understand this is final';

  @override
  String get deleteAccountAction => 'Delete for good';

  @override
  String get deleteAccountCancel => 'Not now';

  @override
  String get deleteAccountDone => 'Your account and data were deleted';

  @override
  String get deleteAccountDoneHint =>
      'If you go online again you start as a new player.';

  @override
  String get deleteAccountInRoom =>
      'You are still in a room. Leave it first, then delete your account.';

  @override
  String get deleteAccountOrder =>
      'A payment of yours is still under review. Wait until it is closed, then delete your account.';

  @override
  String get deleteAccountWebTitle => 'Or ask for deletion on the website';

  @override
  String get deleteAccountWebOpen => 'Open the data deletion page';

  @override
  String get deleteAccountWebCopied => 'Link copied';

  @override
  String get accountLegalTitle => 'Terms and privacy';

  @override
  String get errOffline =>
      'Cannot reach the server right now. Check your connection and try again.';

  @override
  String get errRetry => 'Try again';

  @override
  String get errRateLimited =>
      'Too many requests too fast. Wait a little and try again.';

  @override
  String get errGeneric =>
      'Something went wrong on our side. Try again in a moment.';

  @override
  String get errSession =>
      'Your session ended. Close the game and open it again.';

  @override
  String get errCoins => 'You do not have enough coins.';

  @override
  String get errUnavailable =>
      'This is not available right now. Try again later.';

  @override
  String get errNotAllowed => 'You cannot do that right now.';

  @override
  String get errNotHost => 'Only the host can do that.';

  @override
  String get errAlreadyOwned => 'You already have this.';

  @override
  String get errInRoom => 'You are still in a room. Leave it first.';

  @override
  String get errOrderOpen => 'You still have a payment order open.';

  @override
  String get errPurchaseRequired => 'This needs a purchase first.';

  @override
  String get updateRequiredTitle => 'Update the app';

  @override
  String get updateRequiredBody =>
      'There is a newer version of the game and you need to update to keep playing. This version will not work any more.';

  @override
  String get updateRequiredStore => 'Open Google Play';

  @override
  String get updateRequiredReload => 'Reload the page';

  @override
  String get webAdAppCta => 'Download the app — fewer ads';

  @override
  String get webAdPlayCaption => 'Mafia Master on Google Play';

  @override
  String get webAdCouncilTitle => 'The Council and vault await';

  @override
  String get webAdPlayBody => 'Play with friends on Android with fewer ads.';

  @override
  String get webAdCouncilBody =>
      'Collect coins and unlock a new look for the table.';

  @override
  String get webAdOpenPlay => 'Open Google Play';

  @override
  String get webAdContinue => 'Continue playing';

  @override
  String get webAdCountdown => 'You can close this ad in a moment';
}
