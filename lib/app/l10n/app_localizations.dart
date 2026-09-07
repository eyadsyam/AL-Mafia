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

  /// No description provided for @actionNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Your choice was not saved. Try again.'**
  String get actionNotSaved;

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
  /// **'Hold for 2 seconds to see your card'**
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
  /// **'Hold for 2 seconds to continue'**
  String get holdToConfirm;

  /// No description provided for @notYou.
  ///
  /// In en, this message translates to:
  /// **'Not you?'**
  String get notYou;

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
  /// **'Hold for 2 seconds to see your card'**
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

  /// Divider caption above the morning's forensic observation (doc 09 S-10).
  ///
  /// In en, this message translates to:
  /// **'The trace'**
  String get traceLabel;

  /// No description provided for @traceNone.
  ///
  /// In en, this message translates to:
  /// **'This night left no trace'**
  String get traceNone;

  /// No description provided for @traceLastSuspicion.
  ///
  /// In en, this message translates to:
  /// **'The last thing {victim} recorded: they suspected «{target}»'**
  String traceLastSuspicion(String victim, String target);

  /// No description provided for @traceSomeoneSurvived.
  ///
  /// In en, this message translates to:
  /// **'Somebody was covered tonight… and lived'**
  String get traceSomeoneSurvived;

  /// No description provided for @traceAgreement.
  ///
  /// In en, this message translates to:
  /// **'{count} players suspected the same person tonight'**
  String traceAgreement(int count);

  /// No description provided for @traceShift.
  ///
  /// In en, this message translates to:
  /// **'{count} changed who they suspect tonight'**
  String traceShift(int count);

  /// No description provided for @traceShadow.
  ///
  /// In en, this message translates to:
  /// **'There is a player nobody has ever suspected'**
  String get traceShadow;

  /// No description provided for @traceSilence.
  ///
  /// In en, this message translates to:
  /// **'Somebody refused to record a suspicion tonight'**
  String get traceSilence;

  /// No description provided for @traceCircle.
  ///
  /// In en, this message translates to:
  /// **'Two of you suspect each other'**
  String get traceCircle;

  /// No description provided for @traceConsensus.
  ///
  /// In en, this message translates to:
  /// **'Most of the table suspected the same person'**
  String get traceConsensus;

  /// No description provided for @openingRoundTitle.
  ///
  /// In en, this message translates to:
  /// **'One name'**
  String get openingRoundTitle;

  /// No description provided for @openingRoundBody.
  ///
  /// In en, this message translates to:
  /// **'One name each, in seating order. No explaining.'**
  String get openingRoundBody;

  /// No description provided for @openingRoundPrompt.
  ///
  /// In en, this message translates to:
  /// **'Who do you suspect, {name}?'**
  String openingRoundPrompt(String name);

  /// No description provided for @confrontationLabel.
  ///
  /// In en, this message translates to:
  /// **'The confrontation'**
  String get confrontationLabel;

  /// No description provided for @confrontationExplain.
  ///
  /// In en, this message translates to:
  /// **'Explain.'**
  String get confrontationExplain;

  /// No description provided for @confrontationDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get confrontationDone;

  /// No description provided for @confrontationC1.
  ///
  /// In en, this message translates to:
  /// **'You said you suspected {x}, and you voted for {y}.'**
  String confrontationC1(String x, String y);

  /// No description provided for @confrontationC4.
  ///
  /// In en, this message translates to:
  /// **'Nobody has suspected you once. Why do you think that is?'**
  String get confrontationC4;

  /// No description provided for @confrontationC5.
  ///
  /// In en, this message translates to:
  /// **'You and {x} voted the same way {count} times. Coincidence?'**
  String confrontationC5(String x, int count);

  /// No description provided for @confrontationC6.
  ///
  /// In en, this message translates to:
  /// **'You have talked the least of anyone. Anything to say?'**
  String get confrontationC6;

  /// No description provided for @confrontationC7.
  ///
  /// In en, this message translates to:
  /// **'The last person to die suspected you. Your answer?'**
  String get confrontationC7;

  /// No description provided for @confrontationC8.
  ///
  /// In en, this message translates to:
  /// **'You whisper to {x} every day. Why him in particular?'**
  String confrontationC8(String x);

  /// No description provided for @confrontationC11.
  ///
  /// In en, this message translates to:
  /// **'Somebody tried to reach you and failed. Who would protect you?'**
  String get confrontationC11;

  /// No description provided for @whisperLabel.
  ///
  /// In en, this message translates to:
  /// **'Whisper'**
  String get whisperLabel;

  /// No description provided for @whisperFrom.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String whisperFrom(String name);

  /// No description provided for @whisperCompose.
  ///
  /// In en, this message translates to:
  /// **'Send a whisper'**
  String get whisperCompose;

  /// No description provided for @whisperPickRecipient.
  ///
  /// In en, this message translates to:
  /// **'To whom?'**
  String get whisperPickRecipient;

  /// No description provided for @whisperBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Up to 120 characters'**
  String get whisperBodyHint;

  /// No description provided for @whisperSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get whisperSend;

  /// No description provided for @whisperSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get whisperSent;

  /// No description provided for @whisperAlreadySentToday.
  ///
  /// In en, this message translates to:
  /// **'You have already whispered today'**
  String get whisperAlreadySentToday;

  /// No description provided for @whisperUndelivered.
  ///
  /// In en, this message translates to:
  /// **'Your whisper never arrived'**
  String get whisperUndelivered;

  /// No description provided for @whisperGraphTitle.
  ///
  /// In en, this message translates to:
  /// **'Whispers, day {day}'**
  String whisperGraphTitle(int day);

  /// No description provided for @whisperGraphEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody whispered today'**
  String get whisperGraphEmpty;

  /// No description provided for @whisperNobodySent.
  ///
  /// In en, this message translates to:
  /// **'({names} did not send one)'**
  String whisperNobodySent(String names);

  /// No description provided for @whisperArrow.
  ///
  /// In en, this message translates to:
  /// **'→'**
  String get whisperArrow;

  /// No description provided for @whisperTooLong.
  ///
  /// In en, this message translates to:
  /// **'Too long by {count}'**
  String whisperTooLong(int count);

  /// No description provided for @whisperLanguageWarning.
  ///
  /// In en, this message translates to:
  /// **'That reads harsher than you may mean. Send anyway?'**
  String get whisperLanguageWarning;

  /// No description provided for @whisperReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get whisperReport;

  /// No description provided for @whisperReported.
  ///
  /// In en, this message translates to:
  /// **'Reported. You will not see whispers from them again.'**
  String get whisperReported;

  /// No description provided for @informationEngineSection.
  ///
  /// In en, this message translates to:
  /// **'Information engine'**
  String get informationEngineSection;

  /// No description provided for @settingTrace.
  ///
  /// In en, this message translates to:
  /// **'The trace'**
  String get settingTrace;

  /// No description provided for @settingTraceHint.
  ///
  /// In en, this message translates to:
  /// **'One true observation each morning. Off restores classic Mafia.'**
  String get settingTraceHint;

  /// No description provided for @settingConfrontation.
  ///
  /// In en, this message translates to:
  /// **'The confrontation'**
  String get settingConfrontation;

  /// No description provided for @settingConfrontationHint.
  ///
  /// In en, this message translates to:
  /// **'One player answers for their own behaviour, once a day.'**
  String get settingConfrontationHint;

  /// No description provided for @settingOpeningRound.
  ///
  /// In en, this message translates to:
  /// **'«One name» on day 1'**
  String get settingOpeningRound;

  /// No description provided for @settingOpeningRoundHint.
  ///
  /// In en, this message translates to:
  /// **'Ten seconds each, in seating order, to name one suspect.'**
  String get settingOpeningRoundHint;

  /// No description provided for @settingWhisper.
  ///
  /// In en, this message translates to:
  /// **'The whisper'**
  String get settingWhisper;

  /// No description provided for @settingWhisperHint.
  ///
  /// In en, this message translates to:
  /// **'One private message a day. Who wrote to whom is public; what they wrote is not.'**
  String get settingWhisperHint;

  /// No description provided for @settingRevealWhispers.
  ///
  /// In en, this message translates to:
  /// **'Reveal whisper text after the match'**
  String get settingRevealWhispers;

  /// No description provided for @settingRevealWhispersHint.
  ///
  /// In en, this message translates to:
  /// **'The graph is always revealed. This is about the words.'**
  String get settingRevealWhispersHint;

  /// No description provided for @onlineMatch.
  ///
  /// In en, this message translates to:
  /// **'Play online'**
  String get onlineMatch;

  /// No description provided for @onlineCreateRoom.
  ///
  /// In en, this message translates to:
  /// **'Create a room'**
  String get onlineCreateRoom;

  /// No description provided for @onlineJoinRoom.
  ///
  /// In en, this message translates to:
  /// **'Join a room'**
  String get onlineJoinRoom;

  /// No description provided for @onlineCreateRoomHint.
  ///
  /// In en, this message translates to:
  /// **'You get a code to send the others'**
  String get onlineCreateRoomHint;

  /// No description provided for @onlineJoinRoomHint.
  ///
  /// In en, this message translates to:
  /// **'Somebody sent you a code?'**
  String get onlineJoinRoomHint;

  /// No description provided for @onlineRoomCode.
  ///
  /// In en, this message translates to:
  /// **'Room code'**
  String get onlineRoomCode;

  /// No description provided for @onlineRoomCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Six characters'**
  String get onlineRoomCodeHint;

  /// No description provided for @onlineShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share the code'**
  String get onlineShareCode;

  /// No description provided for @onlineWaitingForPlayers.
  ///
  /// In en, this message translates to:
  /// **'Waiting for players…'**
  String get onlineWaitingForPlayers;

  /// No description provided for @onlineStartMatch.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onlineStartMatch;

  /// No description provided for @onlineConnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get onlineConnecting;

  /// No description provided for @onlineDisconnected.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get onlineDisconnected;

  /// No description provided for @onlineNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get onlineNotConnected;

  /// No description provided for @onlineHostLeft.
  ///
  /// In en, this message translates to:
  /// **'The host left. {name} is hosting now.'**
  String onlineHostLeft(String name);

  /// No description provided for @onlineRoomFull.
  ///
  /// In en, this message translates to:
  /// **'That room is full'**
  String get onlineRoomFull;

  /// No description provided for @onlineRoomFinished.
  ///
  /// In en, this message translates to:
  /// **'That match has already finished'**
  String get onlineRoomFinished;

  /// No description provided for @onlineRoomNotFound.
  ///
  /// In en, this message translates to:
  /// **'No room with that code'**
  String get onlineRoomNotFound;

  /// No description provided for @onlineUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Play offline instead?'**
  String get onlineUnreachable;

  /// No description provided for @onlineProjectPaused.
  ///
  /// In en, this message translates to:
  /// **'The server is asleep. Try again in a minute.'**
  String get onlineProjectPaused;

  /// No description provided for @onlinePlayOffline.
  ///
  /// In en, this message translates to:
  /// **'Play offline'**
  String get onlinePlayOffline;

  /// No description provided for @onlineHeadphonesWarning.
  ///
  /// In en, this message translates to:
  /// **'If you are in the same room, use headphones'**
  String get onlineHeadphonesWarning;

  /// No description provided for @voiceMicOff.
  ///
  /// In en, this message translates to:
  /// **'Microphone off'**
  String get voiceMicOff;

  /// No description provided for @voiceMuteMe.
  ///
  /// In en, this message translates to:
  /// **'Mute me'**
  String get voiceMuteMe;

  /// No description provided for @voiceUnmuteMe.
  ///
  /// In en, this message translates to:
  /// **'Unmute me'**
  String get voiceUnmuteMe;

  /// No description provided for @voiceSelfMuted.
  ///
  /// In en, this message translates to:
  /// **'You are muted'**
  String get voiceSelfMuted;

  /// No description provided for @voiceMicOn.
  ///
  /// In en, this message translates to:
  /// **'Microphone on'**
  String get voiceMicOn;

  /// No description provided for @voiceTextMode.
  ///
  /// In en, this message translates to:
  /// **'Voice unavailable — text mode'**
  String get voiceTextMode;

  /// No description provided for @voiceMicDenied.
  ///
  /// In en, this message translates to:
  /// **'No microphone. You can still hear everyone.'**
  String get voiceMicDenied;

  /// No description provided for @whoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get whoAreYou;

  /// No description provided for @onlineYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get onlineYourName;

  /// No description provided for @onlineHostBadge.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get onlineHostBadge;

  /// No description provided for @onlineYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get onlineYou;

  /// No description provided for @onlineNeedFivePlayers.
  ///
  /// In en, this message translates to:
  /// **'At least five players'**
  String get onlineNeedFivePlayers;

  /// No description provided for @onlineLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave the room'**
  String get onlineLeave;

  /// No description provided for @onlineCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get onlineCodeCopied;

  /// No description provided for @onlinePublicRooms.
  ///
  /// In en, this message translates to:
  /// **'Public rooms'**
  String get onlinePublicRooms;

  /// No description provided for @onlinePublicRoomsHint.
  ///
  /// In en, this message translates to:
  /// **'Join an open room without a code'**
  String get onlinePublicRoomsHint;

  /// No description provided for @onlineNoPublicRooms.
  ///
  /// In en, this message translates to:
  /// **'No public rooms open right now'**
  String get onlineNoPublicRooms;

  /// No description provided for @onlinePublicRoomPlayers.
  ///
  /// In en, this message translates to:
  /// **'{count} players'**
  String onlinePublicRoomPlayers(int count);

  /// No description provided for @onlineUntitledRoom.
  ///
  /// In en, this message translates to:
  /// **'Unnamed room'**
  String get onlineUntitledRoom;

  /// No description provided for @onlineRoomSettings.
  ///
  /// In en, this message translates to:
  /// **'Room settings'**
  String get onlineRoomSettings;

  /// No description provided for @onlineSettingsRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get onlineSettingsRoom;

  /// No description provided for @onlineSettingsVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get onlineSettingsVoice;

  /// No description provided for @onlineSettingsPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get onlineSettingsPlay;

  /// No description provided for @onlineSettingsInfo.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get onlineSettingsInfo;

  /// No description provided for @onlineRoomVisibility.
  ///
  /// In en, this message translates to:
  /// **'Room type'**
  String get onlineRoomVisibility;

  /// No description provided for @onlineRoomVisibilityHint.
  ///
  /// In en, this message translates to:
  /// **'Private rooms take a code. Public ones are listed for anybody.'**
  String get onlineRoomVisibilityHint;

  /// No description provided for @onlineRoomPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get onlineRoomPrivate;

  /// No description provided for @onlineRoomPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get onlineRoomPublic;

  /// No description provided for @onlineRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get onlineRoomTitle;

  /// No description provided for @onlineRoomTitleHint.
  ///
  /// In en, this message translates to:
  /// **'What people see in the list.'**
  String get onlineRoomTitleHint;

  /// No description provided for @onlineMaxPlayers.
  ///
  /// In en, this message translates to:
  /// **'Maximum players'**
  String get onlineMaxPlayers;

  /// No description provided for @onlineMaxPlayersHint.
  ///
  /// In en, this message translates to:
  /// **'The room closes once it is this full.'**
  String get onlineMaxPlayersHint;

  /// No description provided for @onlineVoiceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get onlineVoiceEnabled;

  /// No description provided for @onlineVoiceEnabledHint.
  ///
  /// In en, this message translates to:
  /// **'The match plays fine without it.'**
  String get onlineVoiceEnabledHint;

  /// No description provided for @onlineMuteAtNight.
  ///
  /// In en, this message translates to:
  /// **'Mute everyone at night'**
  String get onlineMuteAtNight;

  /// No description provided for @onlineMuteAtNightHint.
  ///
  /// In en, this message translates to:
  /// **'A voice at night says who is awake.'**
  String get onlineMuteAtNightHint;

  /// No description provided for @onlineSpeakDuration.
  ///
  /// In en, this message translates to:
  /// **'Speaking time'**
  String get onlineSpeakDuration;

  /// No description provided for @onlineSpeakDurationHint.
  ///
  /// In en, this message translates to:
  /// **'How long each player holds the floor alone.'**
  String get onlineSpeakDurationHint;

  /// No description provided for @onlineDiscussDuration.
  ///
  /// In en, this message translates to:
  /// **'Discussion time'**
  String get onlineDiscussDuration;

  /// No description provided for @onlineDiscussDurationHint.
  ///
  /// In en, this message translates to:
  /// **'The open argument before the vote.'**
  String get onlineDiscussDurationHint;

  /// No description provided for @onlineOpenVoting.
  ///
  /// In en, this message translates to:
  /// **'Open voting'**
  String get onlineOpenVoting;

  /// No description provided for @onlineOpenVotingHint.
  ///
  /// In en, this message translates to:
  /// **'Everyone sees who voted for whom until the ballot locks.'**
  String get onlineOpenVotingHint;

  /// No description provided for @onlineTrace.
  ///
  /// In en, this message translates to:
  /// **'Trace'**
  String get onlineTrace;

  /// No description provided for @onlineTraceHint.
  ///
  /// In en, this message translates to:
  /// **'The morning names one trace of the night\'s movement.'**
  String get onlineTraceHint;

  /// No description provided for @onlineConfrontation.
  ///
  /// In en, this message translates to:
  /// **'Confrontation'**
  String get onlineConfrontation;

  /// No description provided for @onlineConfrontationHint.
  ///
  /// In en, this message translates to:
  /// **'Two players face each other before the vote.'**
  String get onlineConfrontationHint;

  /// No description provided for @onlineWhispers.
  ///
  /// In en, this message translates to:
  /// **'Whispers'**
  String get onlineWhispers;

  /// No description provided for @onlineWhispersHint.
  ///
  /// In en, this message translates to:
  /// **'A private line to one player; the room knows it was sent.'**
  String get onlineWhispersHint;

  /// No description provided for @onlineSeconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get onlineSeconds;

  /// No description provided for @onlineMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get onlineMinutes;

  /// No description provided for @onlineLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Room link copied'**
  String get onlineLinkCopied;

  /// No description provided for @onlineWaitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host…'**
  String get onlineWaitingForHost;

  /// No description provided for @voiceTakeFloor.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get voiceTakeFloor;

  /// No description provided for @voiceYieldFloor.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get voiceYieldFloor;

  /// No description provided for @voiceFloorTaken.
  ///
  /// In en, this message translates to:
  /// **'Someone else has the floor'**
  String get voiceFloorTaken;

  /// No description provided for @onlineWeatherConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get onlineWeatherConnecting;

  /// No description provided for @onlineWeatherReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Weak connection — trying'**
  String get onlineWeatherReconnecting;

  /// No description provided for @onlineWeatherUnreachable.
  ///
  /// In en, this message translates to:
  /// **'No connection. The match is saved.'**
  String get onlineWeatherUnreachable;

  /// No description provided for @onlineCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get onlineCopy;

  /// No description provided for @onlineShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get onlineShare;

  /// No description provided for @onlinePlayersOfMax.
  ///
  /// In en, this message translates to:
  /// **'{count} / {max} players'**
  String onlinePlayersOfMax(int count, int max);

  /// No description provided for @onlineVoiceConnecting.
  ///
  /// In en, this message translates to:
  /// **'Voice: connecting…'**
  String get onlineVoiceConnecting;

  /// No description provided for @onlineVoiceConnected.
  ///
  /// In en, this message translates to:
  /// **'Voice: connected'**
  String get onlineVoiceConnected;

  /// No description provided for @onlineVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice is unavailable — the game plays normally'**
  String get onlineVoiceUnavailable;

  /// No description provided for @onlineShareInvite.
  ///
  /// In en, this message translates to:
  /// **'Play Mafia with us. Room code: {code}'**
  String onlineShareInvite(String code);

  /// No description provided for @onlineGhostRule.
  ///
  /// In en, this message translates to:
  /// **'Whoever is out does not talk to whoever is still playing'**
  String get onlineGhostRule;

  /// No description provided for @onlineChosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen: {name}'**
  String onlineChosen(String name);

  /// No description provided for @onlineUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up next: {names}'**
  String onlineUpNext(String names);

  /// No description provided for @onlineLeftRoom.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get onlineLeftRoom;

  /// No description provided for @onlineNewHost.
  ///
  /// In en, this message translates to:
  /// **'{name} is the host now'**
  String onlineNewHost(String name);

  /// No description provided for @onlineCloseRoom.
  ///
  /// In en, this message translates to:
  /// **'Close the room'**
  String get onlineCloseRoom;

  /// No description provided for @onlineCloseRoomBody.
  ///
  /// In en, this message translates to:
  /// **'This ends the match for everyone in the room. Are you sure?'**
  String get onlineCloseRoomBody;

  /// No description provided for @onlineCloseRoomConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get onlineCloseRoomConfirm;

  /// No description provided for @onlineRoomClosed.
  ///
  /// In en, this message translates to:
  /// **'The host closed the room'**
  String get onlineRoomClosed;

  /// No description provided for @onlineKick.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get onlineKick;

  /// No description provided for @onlineMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get onlineMute;

  /// No description provided for @onlineUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get onlineUnmute;

  /// No description provided for @onlineKickedByHost.
  ///
  /// In en, this message translates to:
  /// **'The host removed you from the room'**
  String get onlineKickedByHost;

  /// No description provided for @onlineWaitingForCards.
  ///
  /// In en, this message translates to:
  /// **'Waiting for: {names}'**
  String onlineWaitingForCards(String names);

  /// Doc 15 §1.4. Who has asked for the floor, in seat order. Never a queue: no position numbers, and never sorted by who asked first.
  ///
  /// In en, this message translates to:
  /// **'Hands up: {names}'**
  String onlineRaisedHands(String names);

  /// No description provided for @onlineRaiseHand.
  ///
  /// In en, this message translates to:
  /// **'My turn'**
  String get onlineRaiseHand;

  /// No description provided for @onlineHandRaised.
  ///
  /// In en, this message translates to:
  /// **'Hand up'**
  String get onlineHandRaised;

  /// No description provided for @onlineSeeRoles.
  ///
  /// In en, this message translates to:
  /// **'See the roles'**
  String get onlineSeeRoles;

  /// No description provided for @onlineRosterOf.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String onlineRosterOf(int index, int total);

  /// No description provided for @onlinePickFromTable.
  ///
  /// In en, this message translates to:
  /// **'Choose from the table'**
  String get onlinePickFromTable;

  /// No description provided for @onlineWaitingForTheRest.
  ///
  /// In en, this message translates to:
  /// **'Done. Waiting for the rest…'**
  String get onlineWaitingForTheRest;

  /// No description provided for @onlineConfirmHold.
  ///
  /// In en, this message translates to:
  /// **'Confirm — press and hold'**
  String get onlineConfirmHold;

  /// No description provided for @confrontationSilent.
  ///
  /// In en, this message translates to:
  /// **'Silence.'**
  String get confrontationSilent;

  /// No description provided for @confrontationAudience.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get confrontationAudience;

  /// No description provided for @settingVoteVisibility.
  ///
  /// In en, this message translates to:
  /// **'Voting'**
  String get settingVoteVisibility;

  /// No description provided for @settingOpenVoting.
  ///
  /// In en, this message translates to:
  /// **'Open voting'**
  String get settingOpenVoting;

  /// No description provided for @settingSecretVoting.
  ///
  /// In en, this message translates to:
  /// **'Secret ballot'**
  String get settingSecretVoting;

  /// No description provided for @settingOpenVotingHint.
  ///
  /// In en, this message translates to:
  /// **'You watch each vote land, and you see who changes their mind'**
  String get settingOpenVotingHint;

  /// No description provided for @witnessTitle.
  ///
  /// In en, this message translates to:
  /// **'The Witness'**
  String get witnessTitle;

  /// No description provided for @witnessEliminated.
  ///
  /// In en, this message translates to:
  /// **'You are out of the game. But you are still watching.'**
  String get witnessEliminated;

  /// No description provided for @witnessSpectating.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get witnessSpectating;

  /// No description provided for @witnessTabTable.
  ///
  /// In en, this message translates to:
  /// **'The table'**
  String get witnessTabTable;

  /// No description provided for @witnessTabChat.
  ///
  /// In en, this message translates to:
  /// **'Those who are out'**
  String get witnessTabChat;

  /// No description provided for @witnessTabPrediction.
  ///
  /// In en, this message translates to:
  /// **'Your call'**
  String get witnessTabPrediction;

  /// No description provided for @witnessTabRecord.
  ///
  /// In en, this message translates to:
  /// **'Your record'**
  String get witnessTabRecord;

  /// No description provided for @witnessChatHint.
  ///
  /// In en, this message translates to:
  /// **'Write to the others who are out…'**
  String get witnessChatHint;

  /// No description provided for @witnessChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing said yet'**
  String get witnessChatEmpty;

  /// No description provided for @witnessChatWalled.
  ///
  /// In en, this message translates to:
  /// **'Nobody still playing can see this'**
  String get witnessChatWalled;

  /// No description provided for @witnessChatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get witnessChatSend;

  /// No description provided for @witnessPredictionWinner.
  ///
  /// In en, this message translates to:
  /// **'Who wins?'**
  String get witnessPredictionWinner;

  /// No description provided for @witnessPredictionMafia.
  ///
  /// In en, this message translates to:
  /// **'And who is Mafia?'**
  String get witnessPredictionMafia;

  /// No description provided for @witnessPredictionLock.
  ///
  /// In en, this message translates to:
  /// **'Lock it in'**
  String get witnessPredictionLock;

  /// No description provided for @witnessPredictionLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked. We will see at the end.'**
  String get witnessPredictionLocked;

  /// No description provided for @witnessPredictionScore.
  ///
  /// In en, this message translates to:
  /// **'Your call: {correct} of {total}'**
  String witnessPredictionScore(int correct, int total);

  /// No description provided for @witnessRecordEmpty.
  ///
  /// In en, this message translates to:
  /// **'You did not write anything down'**
  String get witnessRecordEmpty;

  /// No description provided for @onlineIntroPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone is your turn'**
  String get onlineIntroPhoneTitle;

  /// No description provided for @onlineIntroPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is passed around. Everything you do, you do here. Each player uses a device and a room code. Offline uses one shared phone and needs no internet.'**
  String get onlineIntroPhoneBody;

  /// No description provided for @onlineIntroNightTitle.
  ///
  /// In en, this message translates to:
  /// **'The night happens all at once'**
  String get onlineIntroNightTitle;

  /// No description provided for @onlineIntroNightBody.
  ///
  /// In en, this message translates to:
  /// **'Everybody acts together, on their own screen. It takes under a minute. Discuss and vote by day. Town wins by eliminating all Mafia; Mafia wins at parity with the remaining town. Voice is optional; play continues without it.'**
  String get onlineIntroNightBody;

  /// No description provided for @onlineIntroWhisperTitle.
  ///
  /// In en, this message translates to:
  /// **'A whisper shows who, never what'**
  String get onlineIntroWhisperTitle;

  /// No description provided for @onlineIntroWhisperBody.
  ///
  /// In en, this message translates to:
  /// **'The table sees a light cross it. Only one person reads the words. Private messages are online only, unavailable offline.'**
  String get onlineIntroWhisperBody;

  /// No description provided for @onlineIntroWitnessTitle.
  ///
  /// In en, this message translates to:
  /// **'If you are out, you are still watching'**
  String get onlineIntroWitnessTitle;

  /// No description provided for @onlineIntroWitnessBody.
  ///
  /// In en, this message translates to:
  /// **'You keep the table, you talk to the others who are out, and you call the ending. This spectator area is online only. Offline, eliminated players stop taking private turns.'**
  String get onlineIntroWitnessBody;

  /// No description provided for @onlineIntroSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onlineIntroSkip;

  /// No description provided for @onlineIntroStart.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go'**
  String get onlineIntroStart;

  /// No description provided for @modeTitle.
  ///
  /// In en, this message translates to:
  /// **'How are you playing?'**
  String get modeTitle;

  /// No description provided for @modeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this next time.'**
  String get modeSubtitle;

  /// No description provided for @modeOnePhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'One phone, passed around'**
  String get modeOnePhoneTitle;

  /// No description provided for @modeOnePhoneBody.
  ///
  /// In en, this message translates to:
  /// **'Everybody in the same room. The phone goes from hand to hand.'**
  String get modeOnePhoneBody;

  /// No description provided for @modeOnlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Everybody on their own phone'**
  String get modeOnlineTitle;

  /// No description provided for @modeOnlineBody.
  ///
  /// In en, this message translates to:
  /// **'Same room or anywhere. Nothing is passed, and nobody waits their turn to look.'**
  String get modeOnlineBody;

  /// No description provided for @modeNoServer.
  ///
  /// In en, this message translates to:
  /// **'This build has no server. Rebuild it with a project configured.'**
  String get modeNoServer;

  /// No description provided for @bulletMafia.
  ///
  /// In en, this message translates to:
  /// **'The quiet night'**
  String get bulletMafia;

  /// No description provided for @bulletDoctor.
  ///
  /// In en, this message translates to:
  /// **'Cover yourself, once'**
  String get bulletDoctor;

  /// No description provided for @testimonyGiven.
  ///
  /// In en, this message translates to:
  /// **'{name} testifies: their suspicion last night was {suspect}.'**
  String testimonyGiven(String name, String suspect);

  /// No description provided for @testimonyNobody.
  ///
  /// In en, this message translates to:
  /// **'{name} testifies: they suspected nobody last night.'**
  String testimonyNobody(String name);

  /// No description provided for @fileOpenedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} opened the file.'**
  String fileOpenedTitle(String name);

  /// No description provided for @fileOpenedEntry.
  ///
  /// In en, this message translates to:
  /// **'{name} — {role}'**
  String fileOpenedEntry(String name, String role);

  /// No description provided for @fileOpenedEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file was empty.'**
  String get fileOpenedEmpty;

  /// No description provided for @hintTalkers.
  ///
  /// In en, this message translates to:
  /// **'Whoever talks most is not always whoever is hiding.'**
  String get hintTalkers;

  /// No description provided for @hintQuickAgreement.
  ///
  /// In en, this message translates to:
  /// **'Watch who agrees immediately without thinking.'**
  String get hintQuickAgreement;

  /// No description provided for @hintSilence.
  ///
  /// In en, this message translates to:
  /// **'Silence is not evidence. But it is information.'**
  String get hintSilence;

  /// No description provided for @hintChangesMind.
  ///
  /// In en, this message translates to:
  /// **'Who changes their mind fast under pressure?'**
  String get hintChangesMind;

  /// No description provided for @hintEarlyAccuser.
  ///
  /// In en, this message translates to:
  /// **'Good mafia accuse early so they look innocent.'**
  String get hintEarlyAccuser;

  /// No description provided for @hintMajorityComfort.
  ///
  /// In en, this message translates to:
  /// **'Voting with the majority is comfortable. That is exactly what they count on.'**
  String get hintMajorityComfort;

  /// No description provided for @hintWhoBenefited.
  ///
  /// In en, this message translates to:
  /// **'Who gained from whoever died last night?'**
  String get hintWhoBenefited;

  /// No description provided for @hintMafiaSuspicionSpreads.
  ///
  /// In en, this message translates to:
  /// **'Do not kill whoever suspects you straight away — their suspicion gets published.'**
  String get hintMafiaSuspicionSpreads;

  /// No description provided for @hintMafiaQuietNight.
  ///
  /// In en, this message translates to:
  /// **'The quiet night starves the table of information.'**
  String get hintMafiaQuietNight;

  /// No description provided for @hintMafiaSpeak.
  ///
  /// In en, this message translates to:
  /// **'Talk. Silent mafia die.'**
  String get hintMafiaSpeak;

  /// No description provided for @hintDoctorNoRepeat.
  ///
  /// In en, this message translates to:
  /// **'Do not cover the same person two nights running.'**
  String get hintDoctorNoRepeat;

  /// No description provided for @hintDoctorSelf.
  ///
  /// In en, this message translates to:
  /// **'You get to cover yourself once — save it.'**
  String get hintDoctorSelf;

  /// No description provided for @hintDoctorSaveReveals.
  ///
  /// In en, this message translates to:
  /// **'If a save lands, the mafia learn there is a doctor.'**
  String get hintDoctorSaveReveals;

  /// No description provided for @hintDetectiveInvestigateLoud.
  ///
  /// In en, this message translates to:
  /// **'Investigate whoever talks most, not whoever is quiet.'**
  String get hintDetectiveInvestigateLoud;

  /// No description provided for @hintCitizenSuspicionCounts.
  ///
  /// In en, this message translates to:
  /// **'Your suspicion is not going nowhere — it gets recorded.'**
  String get hintCitizenSuspicionCounts;

  /// No description provided for @coachStuckOnInnocent.
  ///
  /// In en, this message translates to:
  /// **'You suspected {name} on {count} nights and they were a citizen. Try changing your mind faster when the evidence does not arrive.'**
  String coachStuckOnInnocent(String name, int count);

  /// No description provided for @coachConformity.
  ///
  /// In en, this message translates to:
  /// **'You voted with the majority {count} times out of {total}. Try forming your own view before you hear everybody else\'s.'**
  String coachConformity(int count, int total);

  /// No description provided for @coachUnusedBullet.
  ///
  /// In en, this message translates to:
  /// **'You never used «{bullet}». It was there from the first night.'**
  String coachUnusedBullet(String bullet);

  /// No description provided for @coachNeverWhispered.
  ///
  /// In en, this message translates to:
  /// **'You never whispered once. A whisper builds alliances.'**
  String get coachNeverWhispered;

  /// No description provided for @coachAbandonedRead.
  ///
  /// In en, this message translates to:
  /// **'You suspected {name} on the first nights and they were mafia — then you let it go. Trust your first read.'**
  String coachAbandonedRead(String name);

  /// No description provided for @coachQuiet.
  ///
  /// In en, this message translates to:
  /// **'You spoke for {seconds} seconds all match — among the least at the table. Silence makes a table suspect you.'**
  String coachQuiet(int seconds);

  /// No description provided for @coachSurvivedAsMafia.
  ///
  /// In en, this message translates to:
  /// **'You lived to the end without the table catching you.'**
  String get coachSurvivedAsMafia;

  /// No description provided for @coachingTitle.
  ///
  /// In en, this message translates to:
  /// **'It could have gone otherwise'**
  String get coachingTitle;

  /// No description provided for @coachingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to add. You played it as it came.'**
  String get coachingEmpty;

  /// No description provided for @presetFast.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get presetFast;

  /// No description provided for @presetClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get presetClassic;

  /// No description provided for @presetBrutal.
  ///
  /// In en, this message translates to:
  /// **'Brutal'**
  String get presetBrutal;

  /// No description provided for @presetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get presetCustom;

  /// No description provided for @presetFastHint.
  ///
  /// In en, this message translates to:
  /// **'Around fifteen minutes, fewer rules. Best for a group\'s first match.'**
  String get presetFastHint;

  /// No description provided for @presetClassicHint.
  ///
  /// In en, this message translates to:
  /// **'Everything on, at the pace it was designed at.'**
  String get presetClassicHint;

  /// No description provided for @presetBrutalHint.
  ///
  /// In en, this message translates to:
  /// **'No doctor, more mafia, no whispers, a brutal clock.'**
  String get presetBrutalHint;

  /// No description provided for @presetLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get presetLabel;

  /// No description provided for @settingPressureCurve.
  ///
  /// In en, this message translates to:
  /// **'The pressure curve'**
  String get settingPressureCurve;

  /// No description provided for @settingPressureCurveHint.
  ///
  /// In en, this message translates to:
  /// **'The clock closes as the table shrinks. It only ever tightens.'**
  String get settingPressureCurveHint;

  /// No description provided for @settingDiscussionSeconds.
  ///
  /// In en, this message translates to:
  /// **'Discussion length'**
  String get settingDiscussionSeconds;

  /// No description provided for @settingPlayHints.
  ///
  /// In en, this message translates to:
  /// **'Play hints'**
  String get settingPlayHints;

  /// No description provided for @settingCoaching.
  ///
  /// In en, this message translates to:
  /// **'«It could have gone otherwise», after the match'**
  String get settingCoaching;

  /// No description provided for @settingRevealVictimRole.
  ///
  /// In en, this message translates to:
  /// **'The night victim\'s role'**
  String get settingRevealVictimRole;

  /// No description provided for @settingRevealVictimRoleHint.
  ///
  /// In en, this message translates to:
  /// **'A day elimination is always public. This is about the night.'**
  String get settingRevealVictimRoleHint;

  /// No description provided for @victimWasRole.
  ///
  /// In en, this message translates to:
  /// **'{name} was {role}.'**
  String victimWasRole(String name, String role);

  /// No description provided for @nightSpecialMafia.
  ///
  /// In en, this message translates to:
  /// **'No kill tonight'**
  String get nightSpecialMafia;

  /// No description provided for @nightSpecialDoctor.
  ///
  /// In en, this message translates to:
  /// **'Protect yourself'**
  String get nightSpecialDoctor;

  /// No description provided for @nightSpecialDetective.
  ///
  /// In en, this message translates to:
  /// **'No check tonight'**
  String get nightSpecialDetective;

  /// No description provided for @nightSpecialCitizen.
  ///
  /// In en, this message translates to:
  /// **'No read tonight'**
  String get nightSpecialCitizen;

  /// No description provided for @settingsSectionPace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get settingsSectionPace;

  /// No description provided for @settingsSectionInformation.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get settingsSectionInformation;

  /// No description provided for @settingsSectionReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveals'**
  String get settingsSectionReveal;

  /// No description provided for @settingsSectionVoting.
  ///
  /// In en, this message translates to:
  /// **'Voting'**
  String get settingsSectionVoting;

  /// No description provided for @settingsSectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Sound and motion'**
  String get settingsSectionAudio;

  /// No description provided for @settingsOnlineOnly.
  ///
  /// In en, this message translates to:
  /// **'Online only'**
  String get settingsOnlineOnly;

  /// No description provided for @settingSpeechSecondsHint.
  ///
  /// In en, this message translates to:
  /// **'How long one player speaks in a structured discussion.'**
  String get settingSpeechSecondsHint;

  /// No description provided for @settingDiscussionSecondsHint.
  ///
  /// In en, this message translates to:
  /// **'How long the whole discussion runs when it is free.'**
  String get settingDiscussionSecondsHint;

  /// No description provided for @settingIdentityHoldHint.
  ///
  /// In en, this message translates to:
  /// **'The same for every player, so turn length says nothing about a role.'**
  String get settingIdentityHoldHint;

  /// No description provided for @settingDiscussionModeHint.
  ///
  /// In en, this message translates to:
  /// **'Structured: one at a time, in order. Free: everyone at once.'**
  String get settingDiscussionModeHint;

  /// No description provided for @settingAbstainHint.
  ///
  /// In en, this message translates to:
  /// **'A player may cast no vote at all.'**
  String get settingAbstainHint;

  /// No description provided for @settingPlayHintsHint.
  ///
  /// In en, this message translates to:
  /// **'One line, in the lobby and settings only. Never inside a match.'**
  String get settingPlayHintsHint;

  /// No description provided for @settingCoachingHint.
  ///
  /// In en, this message translates to:
  /// **'After the match, one honest note per player.'**
  String get settingCoachingHint;

  /// No description provided for @settingMuteAllHint.
  ///
  /// In en, this message translates to:
  /// **'No sound at all. Nothing in the game depends on hearing it.'**
  String get settingMuteAllHint;

  /// No description provided for @minutesSuffix.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesSuffix(int minutes);

  /// No description provided for @whisperFromTitle.
  ///
  /// In en, this message translates to:
  /// **'Whisper from {name}'**
  String whisperFromTitle(String name);

  /// No description provided for @whisperDismiss.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get whisperDismiss;

  /// No description provided for @playerMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get playerMale;

  /// No description provided for @playerFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get playerFemale;

  /// No description provided for @timelineMafiaVoteFemale.
  ///
  /// In en, this message translates to:
  /// **'{actor} voted for {target}'**
  String timelineMafiaVoteFemale(String actor, String target);

  /// No description provided for @timelineProtectFemale.
  ///
  /// In en, this message translates to:
  /// **'{actor} protected {target}'**
  String timelineProtectFemale(String actor, String target);

  /// No description provided for @timelineInvestigateFemale.
  ///
  /// In en, this message translates to:
  /// **'{actor} investigated {target}'**
  String timelineInvestigateFemale(String actor, String target);

  /// No description provided for @timelineSuspectFemale.
  ///
  /// In en, this message translates to:
  /// **'{actor} suspected {target}'**
  String timelineSuspectFemale(String actor, String target);
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
