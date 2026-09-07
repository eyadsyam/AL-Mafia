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
  String get whisperArrow => '→';

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
      'The graph is always revealed. This is about the words.';

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
  String onlineWaitingForCards(String names) {
    return 'Waiting for: $names';
  }

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
}
