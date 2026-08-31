import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Application name, shown on Home.
  ///
  /// In en, this message translates to:
  /// **'Mafia Master'**
  String get appTitle;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// Joins names in a list. Arabic uses an Arabic comma, so this is translated rather than hardcoded.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @newMatch.
  ///
  /// In en, this message translates to:
  /// **'New match'**
  String get newMatch;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addPlayersTitle.
  ///
  /// In en, this message translates to:
  /// **'Add players'**
  String get addPlayersTitle;

  /// No description provided for @seatingOrderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In seating order'**
  String get seatingOrderSubtitle;

  /// No description provided for @playerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Player name'**
  String get playerNameHint;

  /// No description provided for @addPlayer.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addPlayer;

  /// No description provided for @playerCountLine.
  ///
  /// In en, this message translates to:
  /// **'Players: {count}'**
  String playerCountLine(int count);

  /// No description provided for @noPlayersYet.
  ///
  /// In en, this message translates to:
  /// **'No players added yet'**
  String get noPlayersYet;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @seatNumber.
  ///
  /// In en, this message translates to:
  /// **'Seat #{seat}'**
  String seatNumber(int seat);

  /// No description provided for @rolesTitle.
  ///
  /// In en, this message translates to:
  /// **'Role setup'**
  String get rolesTitle;

  /// No description provided for @playerCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count} players'**
  String playerCountShort(int count);

  /// No description provided for @roleGroupMafia.
  ///
  /// In en, this message translates to:
  /// **'Mafia'**
  String get roleGroupMafia;

  /// No description provided for @roleGroupDetective.
  ///
  /// In en, this message translates to:
  /// **'Detective'**
  String get roleGroupDetective;

  /// No description provided for @roleGroupDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get roleGroupDoctor;

  /// No description provided for @roleGroupCitizen.
  ///
  /// In en, this message translates to:
  /// **'Citizen'**
  String get roleGroupCitizen;

  /// No description provided for @balanceValid.
  ///
  /// In en, this message translates to:
  /// **'Balanced setup'**
  String get balanceValid;

  /// No description provided for @balancePlayerCountTooLow.
  ///
  /// In en, this message translates to:
  /// **'You need at least 5 players'**
  String get balancePlayerCountTooLow;

  /// No description provided for @balancePlayerCountTooHigh.
  ///
  /// In en, this message translates to:
  /// **'You cannot have more than 20 players'**
  String get balancePlayerCountTooHigh;

  /// No description provided for @balanceNegativeRoleCount.
  ///
  /// In en, this message translates to:
  /// **'A role count cannot be negative'**
  String get balanceNegativeRoleCount;

  /// No description provided for @balanceRoleCountMismatch.
  ///
  /// In en, this message translates to:
  /// **'Role counts must add up to the number of players'**
  String get balanceRoleCountMismatch;

  /// No description provided for @balanceNoMafia.
  ///
  /// In en, this message translates to:
  /// **'There must be at least one Mafia'**
  String get balanceNoMafia;

  /// No description provided for @balanceMafiaTooMany.
  ///
  /// In en, this message translates to:
  /// **'Mafia must be fewer than half the players'**
  String get balanceMafiaTooMany;

  /// No description provided for @balanceRecommendThreeMafia.
  ///
  /// In en, this message translates to:
  /// **'3 Mafia is recommended at 9 or more players'**
  String get balanceRecommendThreeMafia;

  /// No description provided for @balanceTwoDetectivesLowPlayerCount.
  ///
  /// In en, this message translates to:
  /// **'Warning: two Detectives below 11 players heavily favours the town'**
  String get balanceTwoDetectivesLowPlayerCount;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @speechSecondsLabel.
  ///
  /// In en, this message translates to:
  /// **'Speaking time (seconds)'**
  String get speechSecondsLabel;

  /// No description provided for @secondsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String secondsSuffix(int seconds);

  /// No description provided for @discussionModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Discussion mode'**
  String get discussionModeLabel;

  /// No description provided for @discussionStructured.
  ///
  /// In en, this message translates to:
  /// **'Structured (turn by turn)'**
  String get discussionStructured;

  /// No description provided for @discussionFree.
  ///
  /// In en, this message translates to:
  /// **'Free (no turns)'**
  String get discussionFree;

  /// No description provided for @dayTieRuleLabel.
  ///
  /// In en, this message translates to:
  /// **'Day tie rule'**
  String get dayTieRuleLabel;

  /// No description provided for @tieRevote.
  ///
  /// In en, this message translates to:
  /// **'Revote'**
  String get tieRevote;

  /// No description provided for @tieNoElimination.
  ///
  /// In en, this message translates to:
  /// **'No elimination'**
  String get tieNoElimination;

  /// No description provided for @narrationEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable narration'**
  String get narrationEnabledLabel;

  /// No description provided for @abstainAllowedLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow abstaining'**
  String get abstainAllowedLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @nightApproaching.
  ///
  /// In en, this message translates to:
  /// **'Night is falling'**
  String get nightApproaching;

  /// No description provided for @nightLabel.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get nightLabel;

  /// No description provided for @aliveCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Players alive'**
  String get aliveCountLabel;

  /// No description provided for @placePhoneOnTable.
  ///
  /// In en, this message translates to:
  /// **'Put the phone on the table and wait for the signal'**
  String get placePhoneOnTable;

  /// No description provided for @beginNight.
  ///
  /// In en, this message translates to:
  /// **'Begin night'**
  String get beginNight;

  /// No description provided for @distributionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Role distribution'**
  String get distributionSubtitle;

  /// No description provided for @roleMafia.
  ///
  /// In en, this message translates to:
  /// **'Mafia'**
  String get roleMafia;

  /// No description provided for @roleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get roleDoctor;

  /// No description provided for @roleDetective.
  ///
  /// In en, this message translates to:
  /// **'Detective'**
  String get roleDetective;

  /// No description provided for @roleCitizen.
  ///
  /// In en, this message translates to:
  /// **'Citizen'**
  String get roleCitizen;

  /// No description provided for @roleMafiaDescription.
  ///
  /// In en, this message translates to:
  /// **'Each night you agree with the rest of the mafia on someone to kill. Let nobody find out.'**
  String get roleMafiaDescription;

  /// No description provided for @roleDoctorDescription.
  ///
  /// In en, this message translates to:
  /// **'Each night you protect one player — and never the same person two nights running.'**
  String get roleDoctorDescription;

  /// No description provided for @roleDetectiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Each night you uncover one player\'s role. Only you see the result, and only once.'**
  String get roleDetectiveDescription;

  /// No description provided for @roleCitizenDescription.
  ///
  /// In en, this message translates to:
  /// **'You have no special power. Observation and argument are your weapons.'**
  String get roleCitizenDescription;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @holdToRevealRole.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to reveal your role'**
  String get holdToRevealRole;

  /// No description provided for @teammatesLine.
  ///
  /// In en, this message translates to:
  /// **'With you in the mafia: {names}'**
  String teammatesLine(String names);

  /// No description provided for @passPhoneTo.
  ///
  /// In en, this message translates to:
  /// **'Pass the phone to'**
  String get passPhoneTo;

  /// No description provided for @iAmHoldInstruction.
  ///
  /// In en, this message translates to:
  /// **'I am {name} — press and hold'**
  String iAmHoldInstruction(String name);

  /// No description provided for @notYouNamed.
  ///
  /// In en, this message translates to:
  /// **'Not {name}?'**
  String notYouNamed(String name);

  /// No description provided for @yourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get yourTurn;

  /// No description provided for @holdToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to confirm'**
  String get holdToConfirm;

  /// No description provided for @notYou.
  ///
  /// In en, this message translates to:
  /// **'Not you?'**
  String get notYou;

  /// No description provided for @takeYourTime.
  ///
  /// In en, this message translates to:
  /// **'Take your time reading'**
  String get takeYourTime;

  /// No description provided for @choosePlayer.
  ///
  /// In en, this message translates to:
  /// **'Choose a player'**
  String get choosePlayer;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @choiceRecorded.
  ///
  /// In en, this message translates to:
  /// **'Your choice is recorded'**
  String get choiceRecorded;

  /// No description provided for @keepPhoneUntilUnlock.
  ///
  /// In en, this message translates to:
  /// **'Keep the phone until the pass button unlocks'**
  String get keepPhoneUntilUnlock;

  /// No description provided for @passPhone.
  ///
  /// In en, this message translates to:
  /// **'Pass the phone'**
  String get passPhone;

  /// No description provided for @waitEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Wait…'**
  String get waitEllipsis;

  /// MUST NOT name any role — a screen reader says this aloud (Constitution VII). Keep all four night prompts the same rendered length so no role's screen is brighter (L-05).
  ///
  /// In en, this message translates to:
  /// **'Who do you kill tonight?'**
  String get nightPromptMafia;

  /// No description provided for @nightPromptDoctor.
  ///
  /// In en, this message translates to:
  /// **'Who do you want to protect tonight?'**
  String get nightPromptDoctor;

  /// No description provided for @nightPromptDetective.
  ///
  /// In en, this message translates to:
  /// **'Whose cards do you want to see tonight?'**
  String get nightPromptDetective;

  /// No description provided for @nightPromptCitizen.
  ///
  /// In en, this message translates to:
  /// **'Whose behaviour do you doubt tonight?'**
  String get nightPromptCitizen;

  /// No description provided for @notEveryoneSurvived.
  ///
  /// In en, this message translates to:
  /// **'Not everyone made it'**
  String get notEveryoneSurvived;

  /// No description provided for @lostPlayerLastNight.
  ///
  /// In en, this message translates to:
  /// **'{name} was killed last night.'**
  String lostPlayerLastNight(String name);

  /// No description provided for @quietNight.
  ///
  /// In en, this message translates to:
  /// **'A quiet night'**
  String get quietNight;

  /// No description provided for @someoneSavedBody.
  ///
  /// In en, this message translates to:
  /// **'The mafia tried to kill, but someone survived. We will not say who.'**
  String get someoneSavedBody;

  /// No description provided for @noLossesBody.
  ///
  /// In en, this message translates to:
  /// **'The night passed without losses.'**
  String get noLossesBody;

  /// No description provided for @morningOfDay.
  ///
  /// In en, this message translates to:
  /// **'Morning of day {day}'**
  String morningOfDay(int day);

  /// No description provided for @startDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Start discussion'**
  String get startDiscussion;

  /// No description provided for @discussionTitle.
  ///
  /// In en, this message translates to:
  /// **'Discussion'**
  String get discussionTitle;

  /// No description provided for @discussionFreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Open discussion'**
  String get discussionFreeTitle;

  /// No description provided for @currentSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaking now'**
  String get currentSpeaker;

  /// No description provided for @speakersRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {count}'**
  String speakersRemaining(int count);

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @endDiscussion.
  ///
  /// In en, this message translates to:
  /// **'End discussion'**
  String get endDiscussion;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @votingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Voting'**
  String get votingSubtitle;

  /// No description provided for @whoDoYouVoteOut.
  ///
  /// In en, this message translates to:
  /// **'Who do you vote out?'**
  String get whoDoYouVoteOut;

  /// No description provided for @abstain.
  ///
  /// In en, this message translates to:
  /// **'Abstain'**
  String get abstain;

  /// No description provided for @confirmVote.
  ///
  /// In en, this message translates to:
  /// **'Confirm vote'**
  String get confirmVote;

  /// No description provided for @eliminatedHeadline.
  ///
  /// In en, this message translates to:
  /// **'{name} is out'**
  String eliminatedHeadline(String name);

  /// No description provided for @tieRevoteHeadline.
  ///
  /// In en, this message translates to:
  /// **'Tied — revote'**
  String get tieRevoteHeadline;

  /// No description provided for @tieNoEliminationHeadline.
  ///
  /// In en, this message translates to:
  /// **'Tied — nobody is out'**
  String get tieNoEliminationHeadline;

  /// No description provided for @nobodyEliminated.
  ///
  /// In en, this message translates to:
  /// **'Nobody is out'**
  String get nobodyEliminated;

  /// No description provided for @wasRole.
  ///
  /// In en, this message translates to:
  /// **'Was {role}'**
  String wasRole(String role);

  /// No description provided for @revote.
  ///
  /// In en, this message translates to:
  /// **'Revote'**
  String get revote;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'Game over'**
  String get gameOver;

  /// No description provided for @mafiaWins.
  ///
  /// In en, this message translates to:
  /// **'The Mafia wins'**
  String get mafiaWins;

  /// No description provided for @townWins.
  ///
  /// In en, this message translates to:
  /// **'The town wins'**
  String get townWins;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @homeAction.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeAction;

  /// No description provided for @endMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'End the match?'**
  String get endMatchTitle;

  /// No description provided for @endMatchBody.
  ///
  /// In en, this message translates to:
  /// **'You will lose this match\'s progress and it will not appear in History.'**
  String get endMatchBody;

  /// No description provided for @keepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get keepPlaying;

  /// No description provided for @endAction.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endAction;

  /// No description provided for @endMatchTooltip.
  ///
  /// In en, this message translates to:
  /// **'End the match'**
  String get endMatchTooltip;

  /// No description provided for @unfinishedMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'You have an unfinished match'**
  String get unfinishedMatchTitle;

  /// No description provided for @unfinishedMatchBody.
  ///
  /// In en, this message translates to:
  /// **'{count} players. {where}'**
  String unfinishedMatchBody(int count, String where);

  /// No description provided for @resumeFromPassTo.
  ///
  /// In en, this message translates to:
  /// **'It will resume by passing the phone to {name}.'**
  String resumeFromPassTo(String name);

  /// No description provided for @resumeFromDay.
  ///
  /// In en, this message translates to:
  /// **'It will resume from day {day}.'**
  String resumeFromDay(int day);

  /// No description provided for @endMatch.
  ///
  /// In en, this message translates to:
  /// **'End the match'**
  String get endMatch;

  /// No description provided for @resumeAction.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeAction;

  /// No description provided for @nightNumbered.
  ///
  /// In en, this message translates to:
  /// **'Night {number}'**
  String nightNumbered(int number);

  /// No description provided for @dayNumbered.
  ///
  /// In en, this message translates to:
  /// **'Day {number}'**
  String dayNumbered(int number);

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this match\'s analytics'**
  String get analyticsLoadFailed;

  /// No description provided for @seatFallback.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat}'**
  String seatFallback(int seat);

  /// No description provided for @tabEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get tabEvents;

  /// No description provided for @tabPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get tabPlayers;

  /// No description provided for @tabSuspicions.
  ///
  /// In en, this message translates to:
  /// **'Suspicions'**
  String get tabSuspicions;

  /// No description provided for @tabAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get tabAchievements;

  /// No description provided for @timelineMafiaVote.
  ///
  /// In en, this message translates to:
  /// **'{actor} voted for {target}'**
  String timelineMafiaVote(String actor, String target);

  /// No description provided for @timelineProtect.
  ///
  /// In en, this message translates to:
  /// **'{actor} protected {target}'**
  String timelineProtect(String actor, String target);

  /// No description provided for @timelineInvestigate.
  ///
  /// In en, this message translates to:
  /// **'{actor} investigated {target}'**
  String timelineInvestigate(String actor, String target);

  /// No description provided for @timelineSuspect.
  ///
  /// In en, this message translates to:
  /// **'{actor} suspected {target}'**
  String timelineSuspect(String actor, String target);

  /// No description provided for @timelineNightKill.
  ///
  /// In en, this message translates to:
  /// **'{target} was killed in the night'**
  String timelineNightKill(String target);

  /// No description provided for @timelineSaved.
  ///
  /// In en, this message translates to:
  /// **'{target} survived an attempt'**
  String timelineSaved(String target);

  /// No description provided for @timelineDayElimination.
  ///
  /// In en, this message translates to:
  /// **'The town voted {target} out'**
  String timelineDayElimination(String target);

  /// No description provided for @noEventsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No events recorded'**
  String get noEventsRecorded;

  /// No description provided for @noPlayerData.
  ///
  /// In en, this message translates to:
  /// **'No player data'**
  String get noPlayerData;

  /// No description provided for @noSuspicionsByPlayer.
  ///
  /// In en, this message translates to:
  /// **'Recorded no suspicions'**
  String get noSuspicionsByPlayer;

  /// No description provided for @suspicionAccuracyLine.
  ///
  /// In en, this message translates to:
  /// **'Suspicion accuracy: {correct}/{total}'**
  String suspicionAccuracyLine(int correct, int total);

  /// No description provided for @noSuspicionsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No suspicions were recorded'**
  String get noSuspicionsRecorded;

  /// No description provided for @noAchievements.
  ///
  /// In en, this message translates to:
  /// **'No achievements'**
  String get noAchievements;

  /// No description provided for @achievementSharpestEye.
  ///
  /// In en, this message translates to:
  /// **'Sharpest Eye'**
  String get achievementSharpestEye;

  /// No description provided for @achievementSharpestEyeDescription.
  ///
  /// In en, this message translates to:
  /// **'Highest suspicion accuracy through the nights'**
  String get achievementSharpestEyeDescription;

  /// No description provided for @achievementUntouchable.
  ///
  /// In en, this message translates to:
  /// **'Survivor'**
  String get achievementUntouchable;

  /// No description provided for @achievementUntouchableDescription.
  ///
  /// In en, this message translates to:
  /// **'Survived to the end of the game'**
  String get achievementUntouchableDescription;

  /// No description provided for @achievementGuardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get achievementGuardian;

  /// No description provided for @achievementGuardianDescription.
  ///
  /// In en, this message translates to:
  /// **'Blocked a Mafia attack with a protection'**
  String get achievementGuardianDescription;

  /// No description provided for @achievementFirstBlood.
  ///
  /// In en, this message translates to:
  /// **'First Blood'**
  String get achievementFirstBlood;

  /// No description provided for @achievementFirstBloodDescription.
  ///
  /// In en, this message translates to:
  /// **'The first player lost in the night'**
  String get achievementFirstBloodDescription;

  /// No description provided for @achievementSurvivors.
  ///
  /// In en, this message translates to:
  /// **'Survivors'**
  String get achievementSurvivors;

  /// No description provided for @achievementSurvivorsDescription.
  ///
  /// In en, this message translates to:
  /// **'The game is over'**
  String get achievementSurvivorsDescription;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @deleteMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this match?'**
  String get deleteMatchTitle;

  /// No description provided for @deleteMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Its analytics will be permanently removed.'**
  String get deleteMatchBody;

  /// No description provided for @noPastMatches.
  ///
  /// In en, this message translates to:
  /// **'No past matches'**
  String get noPastMatches;

  /// No description provided for @mafiaWon.
  ///
  /// In en, this message translates to:
  /// **'Mafia won'**
  String get mafiaWon;

  /// No description provided for @townWon.
  ///
  /// In en, this message translates to:
  /// **'Town won'**
  String get townWon;

  /// No description provided for @endedWithoutResult.
  ///
  /// In en, this message translates to:
  /// **'Ended without a result'**
  String get endedWithoutResult;

  /// No description provided for @matchMeta.
  ///
  /// In en, this message translates to:
  /// **'{players} players · {nights} nights'**
  String matchMeta(int players, int nights);

  /// No description provided for @holdToConfirmIdentity.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to see your card'**
  String get holdToConfirmIdentity;

  /// No description provided for @swipeToReveal.
  ///
  /// In en, this message translates to:
  /// **'Swipe the card any way to flip it'**
  String get swipeToReveal;

  /// No description provided for @passThePhone.
  ///
  /// In en, this message translates to:
  /// **'Pass the phone'**
  String get passThePhone;

  /// No description provided for @phaseNightFalls.
  ///
  /// In en, this message translates to:
  /// **'Darkness falls on the town… everyone close your eyes'**
  String get phaseNightFalls;

  /// No description provided for @phaseMorningSomeoneDied.
  ///
  /// In en, this message translates to:
  /// **'Morning has come… and the town woke to bad news'**
  String get phaseMorningSomeoneDied;

  /// No description provided for @phaseMorningNobodyDied.
  ///
  /// In en, this message translates to:
  /// **'Morning has come… nobody died today'**
  String get phaseMorningNobodyDied;

  /// No description provided for @phaseVoting.
  ///
  /// In en, this message translates to:
  /// **'The people will decide… and there is no going back'**
  String get phaseVoting;

  /// No description provided for @phaseMafiaWins.
  ///
  /// In en, this message translates to:
  /// **'The Mafia took over the town'**
  String get phaseMafiaWins;

  /// No description provided for @phaseTownWins.
  ///
  /// In en, this message translates to:
  /// **'The people have won'**
  String get phaseTownWins;

  /// No description provided for @identityHoldLabel.
  ///
  /// In en, this message translates to:
  /// **'Hold time before the card'**
  String get identityHoldLabel;

  /// No description provided for @identityHoldSuffix.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String identityHoldSuffix(int seconds);

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start the game'**
  String get startGame;

  /// No description provided for @howToPlay.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlay;

  /// No description provided for @tapCardHint.
  ///
  /// In en, this message translates to:
  /// **'Tap any card to see what it does'**
  String get tapCardHint;

  /// No description provided for @howToPlayTitle.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlayTitle;

  /// No description provided for @rulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Game rules'**
  String get rulesTitle;

  /// No description provided for @rulesGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'The goal'**
  String get rulesGoalTitle;

  /// No description provided for @rulesGoalBody.
  ///
  /// In en, this message translates to:
  /// **'The townspeople look for the mafia and vote them out.\nThe mafia kill one person a night until the town is finished.'**
  String get rulesGoalBody;

  /// No description provided for @rulesRolesTitle.
  ///
  /// In en, this message translates to:
  /// **'The roles'**
  String get rulesRolesTitle;

  /// No description provided for @rulesDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Day phase'**
  String get rulesDayTitle;

  /// No description provided for @rulesDayBody.
  ///
  /// In en, this message translates to:
  /// **'1. Discussion: everyone speaks and defends themselves.\n2. Accusation: everyone points their suspicion at someone.\n3. Vote: the group decides who goes.'**
  String get rulesDayBody;

  /// No description provided for @rulesNightTitle.
  ///
  /// In en, this message translates to:
  /// **'Night phase'**
  String get rulesNightTitle;

  /// No description provided for @rulesNightBody.
  ///
  /// In en, this message translates to:
  /// **'Each player takes the phone alone and does their part:\n— Mafia: agree on someone to kill.\n— Detective: choose someone to check.\n— Doctor: choose someone to protect.\n— Citizen: pass the phone on without doing anything.'**
  String get rulesNightBody;

  /// No description provided for @rulesWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Winning'**
  String get rulesWinTitle;

  /// No description provided for @rulesWinBody.
  ///
  /// In en, this message translates to:
  /// **'The town wins if every mafia is voted out.\nThe mafia win once they equal the number of townspeople.'**
  String get rulesWinBody;

  /// No description provided for @rulesTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get rulesTipsTitle;

  /// No description provided for @rulesTipsBody.
  ///
  /// In en, this message translates to:
  /// **'— Watch how people react while they talk.\n— Do not reveal yourself early if you are the detective or the doctor.\n— If you are mafia, steer suspicion elsewhere.\n— The doctor may not protect the same person twice running.\n— Never look at anyone else\'s screen, and never hand the phone on with a card showing.'**
  String get rulesTipsBody;

  /// No description provided for @audioSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audioSettingsLabel;

  /// No description provided for @muteAllAudio.
  ///
  /// In en, this message translates to:
  /// **'Mute all sounds'**
  String get muteAllAudio;

  /// No description provided for @scoreEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Background score'**
  String get scoreEnabledLabel;

  /// No description provided for @muteNarrator.
  ///
  /// In en, this message translates to:
  /// **'Mute narrator'**
  String get muteNarrator;

  /// No description provided for @narratorPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Voice will be recorded later'**
  String get narratorPlaceholder;

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is playing?'**
  String get groupsTitle;

  /// No description provided for @newGroupAction.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroupAction;

  /// No description provided for @groupMeta.
  ///
  /// In en, this message translates to:
  /// **'{members} players · played {plays} times'**
  String groupMeta(int members, int plays);

  /// No description provided for @groupMetaNeverPlayed.
  ///
  /// In en, this message translates to:
  /// **'{members} players · not played yet'**
  String groupMetaNeverPlayed(int members);

  /// No description provided for @saveGroupPrompt.
  ///
  /// In en, this message translates to:
  /// **'Save these as a group?'**
  String get saveGroupPrompt;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @notNowAction.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNowAction;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameHint;

  /// No description provided for @groupNameDefault.
  ///
  /// In en, this message translates to:
  /// **'Group {number}'**
  String groupNameDefault(int number);

  /// No description provided for @saveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this group'**
  String get saveGroupTitle;

  /// No description provided for @renameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameAction;

  /// No description provided for @renameGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get renameGroupTitle;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group?'**
  String get deleteGroupTitle;

  /// No description provided for @deleteGroupBody.
  ///
  /// In en, this message translates to:
  /// **'The roster is removed. Past matches are not affected.'**
  String get deleteGroupBody;

  /// No description provided for @quickStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start now'**
  String get quickStartAction;

  /// No description provided for @presentAction.
  ///
  /// In en, this message translates to:
  /// **'Here'**
  String get presentAction;

  /// No description provided for @absentAction.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get absentAction;

  /// No description provided for @attendanceHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a name to mark them away tonight. They stay in the group.'**
  String get attendanceHint;

  /// No description provided for @playingTonight.
  ///
  /// In en, this message translates to:
  /// **'Playing tonight: {count}'**
  String playingTonight(int count);

  /// No description provided for @addGuestsToGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to the group?'**
  String get addGuestsToGroupTitle;

  /// No description provided for @addGuestsToGroupBody.
  ///
  /// In en, this message translates to:
  /// **'{names} played tonight but are not in {group}.'**
  String addGuestsToGroupBody(String names, String group);

  /// No description provided for @saveGroupOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Save the new seating order?'**
  String get saveGroupOrderTitle;

  /// No description provided for @saveGroupOrderBody.
  ///
  /// In en, this message translates to:
  /// **'Tonight {group} sat in a different order.'**
  String saveGroupOrderBody(String group);

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addAction;

  /// Title of the onboarding deck screen.
  ///
  /// In en, this message translates to:
  /// **'First round'**
  String get onboardingTitle;

  /// Advance to the next onboarding card.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Primary action on the last onboarding card.
  ///
  /// In en, this message translates to:
  /// **'Start your first match'**
  String get onboardingStart;

  /// Secondary action on the last onboarding card; opens the rules screen.
  ///
  /// In en, this message translates to:
  /// **'Read the full rules'**
  String get onboardingReadRules;

  /// Screen-reader label for the onboarding progress pips.
  ///
  /// In en, this message translates to:
  /// **'Card {current} of {total}'**
  String onboardingProgress(int current, int total);

  /// No description provided for @onboardingStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'The story'**
  String get onboardingStoryTitle;

  /// No description provided for @onboardingStoryBody.
  ///
  /// In en, this message translates to:
  /// **'A small town goes to sleep every night and wakes up one person short.\nSome of the people at this table are not who they say they are — and the rest have to find them before the town is gone.'**
  String get onboardingStoryBody;

  /// No description provided for @onboardingRolesTitle.
  ///
  /// In en, this message translates to:
  /// **'The roles'**
  String get onboardingRolesTitle;

  /// No description provided for @onboardingRolesBody.
  ///
  /// In en, this message translates to:
  /// **'Four cards. Everyone gets exactly one, and nobody sees anyone else\'s.\nTap any card below to see what it does.'**
  String get onboardingRolesBody;

  /// No description provided for @onboardingNightTitle.
  ///
  /// In en, this message translates to:
  /// **'The night'**
  String get onboardingNightTitle;

  /// No description provided for @onboardingNightBody.
  ///
  /// In en, this message translates to:
  /// **'The phone goes round the table one person at a time. Each player opens it alone, takes their turn, closes it and passes it on.\nThe mafia pick someone, the doctor protects someone, the detective checks someone.'**
  String get onboardingNightBody;

  /// No description provided for @onboardingDayTitle.
  ///
  /// In en, this message translates to:
  /// **'The day'**
  String get onboardingDayTitle;

  /// No description provided for @onboardingDayBody.
  ///
  /// In en, this message translates to:
  /// **'In the morning the phone goes in the middle of the table and says who is gone.\nThen the talking is open, on a timer, and it ends in a vote — the app does the counting.'**
  String get onboardingDayBody;

  /// No description provided for @onboardingPassTitle.
  ///
  /// In en, this message translates to:
  /// **'The phone'**
  String get onboardingPassTitle;

  /// No description provided for @onboardingPassBody.
  ///
  /// In en, this message translates to:
  /// **'This is the part that is won and lost in your hands, not on the screen:\n— Hold the phone tilted towards you, with its back to the rest of the table.\n— Never look at the phone while someone else is holding it.\n— Do not change your face while your card is showing.\n— Never hand the phone on with anything open on it.'**
  String get onboardingPassBody;

  /// Heading of the onboarding card about what the app itself keeps secret.
  ///
  /// In en, this message translates to:
  /// **'Nothing leaks'**
  String get onboardingSecrecyTitle;

  /// Body of the onboarding card about what the app itself keeps secret.
  ///
  /// In en, this message translates to:
  /// **'The app has one job while a match is running: give nothing away. The only way to cheat at this game is to learn something nobody told you.\n— Every turn takes the same time, holds the same screen brightness and shows the same layout, whatever card you drew.\n— The phone makes no sound at all while it is in somebody\'s hand.\n— Your card hides itself after a few seconds, and the phone never passes on with anything still open.\n— A saved group remembers names and seating order. It never remembers who was what.'**
  String get onboardingSecrecyBody;

  /// No description provided for @onboardingWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Winning'**
  String get onboardingWinTitle;

  /// No description provided for @onboardingWinBody.
  ///
  /// In en, this message translates to:
  /// **'The town wins when the last mafia is voted out.\nThe mafia win once there are as many of them as there are townspeople.\nThat is all of it — the rest is talk and suspicion.'**
  String get onboardingWinBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
