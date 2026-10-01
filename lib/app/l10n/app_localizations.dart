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

  /// No description provided for @onlineHostExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the room?'**
  String get onlineHostExitTitle;

  /// No description provided for @onlineHostExitBody.
  ///
  /// In en, this message translates to:
  /// **'Keep the room running and hand hosting to the first available player, or close it for everyone.'**
  String get onlineHostExitBody;

  /// No description provided for @onlineLeaveKeepRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave and keep playing'**
  String get onlineLeaveKeepRoom;

  /// No description provided for @voiceEnablePlayback.
  ///
  /// In en, this message translates to:
  /// **'Enable audio'**
  String get voiceEnablePlayback;

  /// No description provided for @onlineHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Online match'**
  String get onlineHistoryLabel;

  /// No description provided for @onlineMatchMeta.
  ///
  /// In en, this message translates to:
  /// **'{players} players · day {day}'**
  String onlineMatchMeta(int players, int day);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get profileTitle;

  /// No description provided for @profileHint.
  ///
  /// In en, this message translates to:
  /// **'Choose your name and character once. Saved on this device, with no sign-in.'**
  String get profileHint;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. Allow browser storage and try again.'**
  String get profileSaveFailed;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEdit;

  /// No description provided for @videoPlay.
  ///
  /// In en, this message translates to:
  /// **'Play introduction'**
  String get videoPlay;

  /// No description provided for @videoFailed.
  ///
  /// In en, this message translates to:
  /// **'The introduction could not play here.'**
  String get videoFailed;

  /// No description provided for @videoRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get videoRetry;

  /// No description provided for @voiceRetry.
  ///
  /// In en, this message translates to:
  /// **'Enable audio'**
  String get voiceRetry;

  /// No description provided for @onlineNightPrivacyHint.
  ///
  /// In en, this message translates to:
  /// **'Audio stays off during role reveal and night to protect game privacy.'**
  String get onlineNightPrivacyHint;

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
  /// **'Narrator voice'**
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
  /// **'›'**
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
  /// **'After the match, everyone in the room reads the whispers and what they said. Players see this in the lobby and before they whisper.'**
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

  /// No description provided for @onlineAlreadySeated.
  ///
  /// In en, this message translates to:
  /// **'You are still in a match'**
  String get onlineAlreadySeated;

  /// No description provided for @onlineLeaveTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave your match?'**
  String get onlineLeaveTableTitle;

  /// No description provided for @onlineLeaveTableBody.
  ///
  /// In en, this message translates to:
  /// **'You are still in a match. Joining this room takes you out of it, and the table plays on without you.'**
  String get onlineLeaveTableBody;

  /// No description provided for @onlineLeaveTableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave and join'**
  String get onlineLeaveTableConfirm;

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

  /// No description provided for @publicRoomSeats.
  ///
  /// In en, this message translates to:
  /// **'{players}/{capacity} players'**
  String publicRoomSeats(int players, int capacity);

  /// No description provided for @publicRoomMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more player needed before the host can start} other{{count} more players needed before the host can start}}'**
  String publicRoomMissing(int count);

  /// No description provided for @publicRoomReady.
  ///
  /// In en, this message translates to:
  /// **'Enough players — the host decides when to start'**
  String get publicRoomReady;

  /// No description provided for @publicRoomFullStatus.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get publicRoomFullStatus;

  /// No description provided for @publicRoomsStale.
  ///
  /// In en, this message translates to:
  /// **'Can\'t refresh the list right now. This is the last list we received and it may be out of date.'**
  String get publicRoomsStale;

  /// No description provided for @publicRoomsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server to load rooms. We\'ll keep trying.'**
  String get publicRoomsUnavailable;

  /// No description provided for @onlineRoomStarted.
  ///
  /// In en, this message translates to:
  /// **'That room has already started. Pick another one from the list.'**
  String get onlineRoomStarted;

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

  /// No description provided for @onlineReferralOffer.
  ///
  /// In en, this message translates to:
  /// **'Invite a new friend: you get +100 and they get +50 after their first match'**
  String get onlineReferralOffer;

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
  /// **'{count, plural, =1{1 player is still looking at their card} other{{count} players are still looking at their cards}}'**
  String onlineWaitingForCards(int count);

  /// No description provided for @onlineFloorOpen.
  ///
  /// In en, this message translates to:
  /// **'The floor is open'**
  String get onlineFloorOpen;

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

  /// No description provided for @settingTabletopPresentation.
  ///
  /// In en, this message translates to:
  /// **'Phone in the middle'**
  String get settingTabletopPresentation;

  /// No description provided for @settingTabletopPresentationHint.
  ///
  /// In en, this message translates to:
  /// **'Makes public screens and timers readable from across the table.'**
  String get settingTabletopPresentationHint;

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

  /// No description provided for @onlineDiscardResume.
  ///
  /// In en, this message translates to:
  /// **'Forget room'**
  String get onlineDiscardResume;

  /// No description provided for @onlineStorageWarning.
  ///
  /// In en, this message translates to:
  /// **'This device could not save. The match is unaffected, but it may not bring you back to the room on its own or keep the result.'**
  String get onlineStorageWarning;

  /// No description provided for @safetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy and data deletion'**
  String get safetyTitle;

  /// No description provided for @safetyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Developer: Eyad Syam\nSupport: eyadsyam124@gmail.com\n\nLocal play stays on your device. Online play uses a random identifier, profile, match actions and messages. Earned coins, rewards and unlocked items remain with that identity until deletion. Optional voice is encrypted in transit and is not recorded by the game. Service providers process connection data needed to operate online play. An email is collected only if you choose to protect your account.\n\nAds (Android): Google AdMob may show an app-open ad when the game launches or you come back to it after a long break; a full-screen ad between matches — before you enter a room, when you leave a finished match, before the roles are dealt and after the result of a pass-and-play game, or occasionally when you move between menus after several minutes without one (never during a match or while the phone is being passed, at most 40 a day, at least 90 seconds apart); a small labelled banner on waiting screens such as the online lobby, match history and your profile (never during play); and optional rewarded ads, only when you choose to watch one, after a completed online match (to double or triple its coins) and in the vault. To serve ads and prevent fraud, Google\'s ads SDK collects IP address, ad and app interactions, diagnostics and device identifiers such as the Advertising ID. Change ad consent in Settings, under “Ad privacy choices”. Purchases in the Play version use Google Play Billing, where we receive the order, product and purchase token to verify it, or an InstaPay / Vodafone Cash transfer, where you upload the transfer screenshot and the sender name for manual review (stored privately; the screenshot is deleted 90 days after review).\n\nFinished rooms are eligible for deletion after 24 hours. Old anonymous identities with no room membership are removed on the cleanup schedule. You can request online-data deletion below; submission is not completed deletion. Outside the app, use saidalmafia.com/delete-data with your identifier or receipt. Never send passwords or access keys.\n\nHarassment, threats, hate, sexual content, child exploitation and sharing private information are prohibited. Report abusive players, room names or messages. Blocking hides their private messages and mutes their voice for you; public game actions remain visible. Reports are reviewed by the developer and are not visible to players.'**
  String get safetyPolicy;

  /// No description provided for @safetyAgree.
  ///
  /// In en, this message translates to:
  /// **'I accept the community rules'**
  String get safetyAgree;

  /// No description provided for @safetyConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Before playing online'**
  String get safetyConsentTitle;

  /// No description provided for @safetyConsentBody.
  ///
  /// In en, this message translates to:
  /// **'Abuse, harassment, hate, sexual content and sharing private information are prohibited. Use Safety to report or block. Voice is optional. Read Privacy in Settings for data practices.'**
  String get safetyConsentBody;

  /// No description provided for @safetyReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get safetyReport;

  /// No description provided for @safetyBlock.
  ///
  /// In en, this message translates to:
  /// **'Block player messages and voice'**
  String get safetyBlock;

  /// No description provided for @safetyRoom.
  ///
  /// In en, this message translates to:
  /// **'Room name or content'**
  String get safetyRoom;

  /// No description provided for @safetyDetails.
  ///
  /// In en, this message translates to:
  /// **'Describe the abuse or message (no secret role information)'**
  String get safetyDetails;

  /// No description provided for @safetyReceipt.
  ///
  /// In en, this message translates to:
  /// **'Request received. Keep this receipt:'**
  String get safetyReceipt;

  /// No description provided for @safetyFailed.
  ///
  /// In en, this message translates to:
  /// **'Request was not sent. Retry or contact support.'**
  String get safetyFailed;

  /// No description provided for @safetyDelete.
  ///
  /// In en, this message translates to:
  /// **'Request online data deletion'**
  String get safetyDelete;

  /// No description provided for @safetyDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send a request to delete your anonymous identity and associated online data. The developer will review it within 30 days. Other players’ local copies are separate; safety evidence may be retained for a limited period. This request does not delete local files.'**
  String get safetyDeleteConfirm;

  /// No description provided for @safetyIdentity.
  ///
  /// In en, this message translates to:
  /// **'Show my data identifier'**
  String get safetyIdentity;

  /// No description provided for @safetyBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked for you.'**
  String get safetyBlocked;

  /// No description provided for @safetyNoRoom.
  ///
  /// In en, this message translates to:
  /// **'Reporting and blocking are available inside a room.'**
  String get safetyNoRoom;

  /// No description provided for @safetyTools.
  ///
  /// In en, this message translates to:
  /// **'Report and block'**
  String get safetyTools;

  /// No description provided for @onlineWelcome.
  ///
  /// In en, this message translates to:
  /// **'The table is ready. Take your seat.'**
  String get onlineWelcome;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @onlineNewRoomsPaused.
  ///
  /// In en, this message translates to:
  /// **'New rooms are temporarily paused. You can still join an existing room or play offline.'**
  String get onlineNewRoomsPaused;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help and FAQ'**
  String get helpTitle;

  /// No description provided for @helpIntro.
  ///
  /// In en, this message translates to:
  /// **'Quick answers about playing, online rooms, safety and your data.'**
  String get helpIntro;

  /// No description provided for @helpPlayQuestion.
  ///
  /// In en, this message translates to:
  /// **'How does a match work?'**
  String get helpPlayQuestion;

  /// No description provided for @helpPlayAnswer.
  ///
  /// In en, this message translates to:
  /// **'The game assigns secret roles, guides every night and day phase, and counts the vote. Citizens find the Mafia; the Mafia survives until it matches or outnumbers the town. The host can review the rules before starting.'**
  String get helpPlayAnswer;

  /// No description provided for @helpOnlineQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do online rooms work?'**
  String get helpOnlineQuestion;

  /// No description provided for @helpOnlineAnswer.
  ///
  /// In en, this message translates to:
  /// **'Create a room and share its code, join with a code, or choose a public room. The match is controlled by the game server, and host control moves to another connected player if needed.'**
  String get helpOnlineAnswer;

  /// No description provided for @helpVoiceQuestion.
  ///
  /// In en, this message translates to:
  /// **'Is voice required?'**
  String get helpVoiceQuestion;

  /// No description provided for @helpVoiceAnswer.
  ///
  /// In en, this message translates to:
  /// **'No. Voice is optional and is not recorded by the game. If microphone access or voice relay fails, the match continues with the game controls and structured text.'**
  String get helpVoiceAnswer;

  /// No description provided for @helpReconnectQuestion.
  ///
  /// In en, this message translates to:
  /// **'What if the connection drops?'**
  String get helpReconnectQuestion;

  /// No description provided for @helpReconnectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Reopen the game on the same device and use Continue room when it appears. Your seat is restored when the room still exists. Never create a second profile to recover a live seat.'**
  String get helpReconnectAnswer;

  /// No description provided for @helpSafetyQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do reporting and blocking work?'**
  String get helpSafetyQuestion;

  /// No description provided for @helpSafetyAnswer.
  ///
  /// In en, this message translates to:
  /// **'Inside a room, use the flag button to report a player or room content. Blocking immediately hides that player\'s private messages and mutes their voice for you. A report is evidence for review, not an automatic guilty decision.'**
  String get helpSafetyAnswer;

  /// No description provided for @helpCoinsQuestion.
  ///
  /// In en, this message translates to:
  /// **'What are coins?'**
  String get helpCoinsQuestion;

  /// No description provided for @helpCoinsAnswer.
  ///
  /// In en, this message translates to:
  /// **'Coins are earned from verified completed online matches and can unlock fair content. They cannot be withdrawn, transferred or used to buy votes, secret information or a better chance to win. Coins stay with this device\'s anonymous online identity.'**
  String get helpCoinsAnswer;

  /// No description provided for @helpPrivacyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where are privacy and deletion controls?'**
  String get helpPrivacyQuestion;

  /// No description provided for @helpPrivacyAnswer.
  ///
  /// In en, this message translates to:
  /// **'They are on the Settings screen under Privacy and data deletion. You can view your anonymous data identifier and request deletion there.'**
  String get helpPrivacyAnswer;

  /// No description provided for @helpAgeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who is online play intended for?'**
  String get helpAgeQuestion;

  /// No description provided for @helpAgeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Online voice and public rooms are intended for players aged 16 or older. Do not share your address, phone number, passwords or other private information in voice, names, messages or room titles.'**
  String get helpAgeAnswer;

  /// No description provided for @helpSupportQuestion.
  ///
  /// In en, this message translates to:
  /// **'How can I contact support?'**
  String get helpSupportQuestion;

  /// No description provided for @helpSupportAnswer.
  ///
  /// In en, this message translates to:
  /// **'Email eyadsyam124@gmail.com. Include a report receipt or your anonymous data identifier when relevant, but never send a password or access key.'**
  String get helpSupportAnswer;

  /// No description provided for @coinsTitle.
  ///
  /// In en, this message translates to:
  /// **'Coins and rewards'**
  String get coinsTitle;

  /// No description provided for @coinsBalance.
  ///
  /// In en, this message translates to:
  /// **'{count} coins'**
  String coinsBalance(int count);

  /// No description provided for @coinsEarnHint.
  ///
  /// In en, this message translates to:
  /// **'Complete an eligible online match to earn 100 coins. Players on the winning team earn 25 more. Rewards are verified by the game server and never affect votes, roles or the chance to win.'**
  String get coinsEarnHint;

  /// No description provided for @coinsEarnHintV3.
  ///
  /// In en, this message translates to:
  /// **'Complete an eligible online match with five or more players to earn 25 coins. Your team winning adds 10 more, and your first eligible match of the day adds 25. After the match, each award you earn also pays 5 coins, or 15 for MVP, when awards are on. The server verifies rewards; they never affect votes, roles or the chance to win.'**
  String get coinsEarnHintV3;

  /// No description provided for @coinsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Your coins could not be loaded. Nothing was spent; try again.'**
  String get coinsLoadFailed;

  /// No description provided for @coinsGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'The Mastermind\'s Notebook'**
  String get coinsGuideTitle;

  /// No description provided for @coinsGuideHint.
  ///
  /// In en, this message translates to:
  /// **'A permanent strategy guide for reading the table and defending your story. It never reveals live secret information.'**
  String get coinsGuideHint;

  /// No description provided for @coinsGuidePrice.
  ///
  /// In en, this message translates to:
  /// **'Unlock for {count} coins'**
  String coinsGuidePrice(int count);

  /// No description provided for @coinsBuyGuide.
  ///
  /// In en, this message translates to:
  /// **'Unlock the notebook?'**
  String get coinsBuyGuide;

  /// No description provided for @coinsBuyConfirm.
  ///
  /// In en, this message translates to:
  /// **'This permanently spends earned coins on this anonymous online identity. It cannot change a match or improve your odds.'**
  String get coinsBuyConfirm;

  /// No description provided for @coinsUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get coinsUnlock;

  /// No description provided for @coinsGuideOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the notebook'**
  String get coinsGuideOpen;

  /// No description provided for @coinsGuideContent.
  ///
  /// In en, this message translates to:
  /// **'CITIZEN — Track who changes a story after the vote, not who speaks the loudest. Ask for one clear reason and compare it with the next ballot.\n\nMAFIA — Build a simple position early. A complicated lie creates details you must remember. Defend a citizen sometimes; automatic aggression gives the table an easy pattern.\n\nDOCTOR — Survival is not the only goal. Think about which save would create the most trustworthy information for tomorrow.\n\nDETECTIVE — Your information is valuable only if the table can use it. Leave a believable trail before a risky accusation, without announcing your role too early.\n\nEVERY ROLE — Separate what the game confirmed from what a player claimed. The strongest argument is the one that survives the next revealed fact.'**
  String get coinsGuideContent;

  /// No description provided for @adRewardAction.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad for +{count} coins'**
  String adRewardAction(int count);

  /// No description provided for @adRewardHint.
  ///
  /// In en, this message translates to:
  /// **'Optional and shown only after the result. Your original reward stays yours if you decline or the ad fails.'**
  String get adRewardHint;

  /// No description provided for @adRewardPending.
  ///
  /// In en, this message translates to:
  /// **'Ad completed. The extra reward is being verified and will appear automatically.'**
  String get adRewardPending;

  /// No description provided for @adRewardGranted.
  ///
  /// In en, this message translates to:
  /// **'{count} extra coins added.'**
  String adRewardGranted(int count);

  /// No description provided for @adRewardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No ad is available right now. Your original reward is unchanged.'**
  String get adRewardUnavailable;

  /// No description provided for @adRewardUsed.
  ///
  /// In en, this message translates to:
  /// **'You claimed the ad reward for this match.'**
  String get adRewardUsed;

  /// No description provided for @privacyChoices.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get privacyChoices;

  /// No description provided for @privacyChoicesHint.
  ///
  /// In en, this message translates to:
  /// **'Review or change the privacy choices required by the advertising provider.'**
  String get privacyChoicesHint;

  /// No description provided for @premiumScenarioTitle.
  ///
  /// In en, this message translates to:
  /// **'Council of Shadows scenario'**
  String get premiumScenarioTitle;

  /// No description provided for @premiumScenarioHint.
  ///
  /// In en, this message translates to:
  /// **'A permanent host pack with balanced rules, whispers, confrontation and secret ballots. When the host selects it, everyone in the room plays without buying it.'**
  String get premiumScenarioHint;

  /// No description provided for @premiumScenarioBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy scenario pack'**
  String get premiumScenarioBuy;

  /// No description provided for @premiumScenarioOwned.
  ///
  /// In en, this message translates to:
  /// **'Scenario pack owned'**
  String get premiumScenarioOwned;

  /// No description provided for @premiumScenarioRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get premiumScenarioRestore;

  /// No description provided for @premiumScenarioPending.
  ///
  /// In en, this message translates to:
  /// **'The store is still processing this purchase.'**
  String get premiumScenarioPending;

  /// No description provided for @premiumScenarioFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase could not be verified. The game has not charged anything itself.'**
  String get premiumScenarioFailed;

  /// No description provided for @premiumScenarioUse.
  ///
  /// In en, this message translates to:
  /// **'Council of Shadows'**
  String get premiumScenarioUse;

  /// No description provided for @premiumScenarioUseHint.
  ///
  /// In en, this message translates to:
  /// **'A balanced scenario preset the host unlocks for the whole room.'**
  String get premiumScenarioUseHint;

  /// No description provided for @shareResult.
  ///
  /// In en, this message translates to:
  /// **'Share result'**
  String get shareResult;

  /// No description provided for @shareResultText.
  ///
  /// In en, this message translates to:
  /// **'A Mafia Master match ended with {winner} winning after {days} days. Open your room at https://saidalmafia.com'**
  String shareResultText(String winner, int days);

  /// No description provided for @playAgainWithGroup.
  ///
  /// In en, this message translates to:
  /// **'New room for the group'**
  String get playAgainWithGroup;

  /// No description provided for @setupWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Mafia Master'**
  String get setupWelcomeTitle;

  /// No description provided for @setupWelcomeHint.
  ///
  /// In en, this message translates to:
  /// **'Choose your language, name and preferences once, then play.'**
  String get setupWelcomeHint;

  /// No description provided for @setupPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get setupPreferencesTitle;

  /// No description provided for @setupPreferencesHint.
  ///
  /// In en, this message translates to:
  /// **'You can change these later in Settings.'**
  String get setupPreferencesHint;

  /// No description provided for @prefSound.
  ///
  /// In en, this message translates to:
  /// **'Game sounds'**
  String get prefSound;

  /// No description provided for @prefMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get prefMusic;

  /// No description provided for @prefReduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get prefReduceMotion;

  /// No description provided for @setupAdultConfirm.
  ///
  /// In en, this message translates to:
  /// **'I am 16 or older'**
  String get setupAdultConfirm;

  /// No description provided for @setupAdultHint.
  ///
  /// In en, this message translates to:
  /// **'Online play, voice and public rooms are for ages 16 and up.'**
  String get setupAdultHint;

  /// No description provided for @termsAcceptPrefix.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the '**
  String get termsAcceptPrefix;

  /// No description provided for @termsAcceptLink.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAcceptLink;

  /// No description provided for @termsAcceptSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get termsAcceptSuffix;

  /// No description provided for @privacyLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyLinkLabel;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsTitle;

  /// No description provided for @termsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String termsVersion(String version);

  /// No description provided for @termsBody.
  ///
  /// In en, this message translates to:
  /// **'1. Mafia Master is a party game for entertainment. Roles and outcomes are part of the game only.\n\n2. Online play, voice and public rooms are for people aged 16 or older.\n\n3. Abuse, harassment, threats, hate speech, sexual content and sharing anyone\'s private information are prohibited. You can report or block a player from the safety tools.\n\n4. Voice is optional and the game does not record audio. Other players hear what you say, and nobody can stop someone recording with another device.\n\n5. Mafia Coins are an in-game currency for unlocking cosmetic content only, such as frames, themes and narrator styles. They have no cash value, cannot be exchanged for money and never give an advantage in play, voting or roles.\n\n6. Coins, the Quiet Pass and the Starter Bundle can be bought with money: in the Android app through Google Play Billing, and in the Android app and on the website by InstaPay or Vodafone Cash transfer at the same price. Transfers are reviewed manually within 72 hours; you upload the transfer screenshot and the sender name, and the purchase is added only after the money is confirmed. A screenshot can be used for one order only. A rejected order shows its reason; an order not reviewed within 72 hours expires.\n\n7. We may remove a room or restrict a player who breaks these terms. You can request deletion of your data from Settings.\n\n8. If these terms change in an important way, we will ask for your agreement again before you continue.'**
  String get termsBody;

  /// No description provided for @privacySummaryBody.
  ///
  /// In en, this message translates to:
  /// **'• The game uses an anonymous identifier for online play and needs no phone number or birth date to play.\n\n• Your in-game name and avatar type are shown to the players in your room.\n\n• Voice is optional, encrypted in transit and never recorded by the game.\n\n• If you link an email to protect your coins, it is used only to recover your account.\n\n• Android shows Google AdMob ads: optional rewarded ads; automatic full-screen ads only between matches — before you enter a room (Create, Join or a rematch), when you leave a finished match, before the roles are dealt and after the result in pass-and-play, occasionally when you move between menus after several minutes without one, and an app-open ad on the launch screen — never during a match, at most 40 a day, at least 90 seconds apart, and none around your first match; and small banners on waiting screens (lobby, room list, history, vault, profile) — never during play. The Quiet Pass removes all automatic ads. Google\'s ads SDK collects IP address, interactions, diagnostics and device identifiers such as the Advertising ID.\n\n• Play purchases go through Google Play Billing; we keep the order, product and purchase token to verify them. InstaPay / Vodafone Cash transfer orders (Android app and website) record the product, amount, method, the transfer screenshot you upload and the sender name, only to verify the payment; the screenshot is stored privately and deleted 90 days after the order is reviewed, and the order record is kept for accounting.\n\n• Finished rooms are deleted periodically, and you can request deletion of your data from Settings.\n\n• Council rank and the weekly leaderboard: your level shows on your seat, and your in-game name, avatar type, equipped frame, level and weekly XP can appear on the public weekly leaderboard. You can hide yourself from the leaderboard in your profile. Match history behind them is kept 21 days.\n\nFull policy: saidalmafia.com/privacy'**
  String get privacySummaryBody;

  /// No description provided for @termsUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you continue'**
  String get termsUpdatedTitle;

  /// No description provided for @termsUpdatedHint.
  ///
  /// In en, this message translates to:
  /// **'Review and accept the terms once. Your profile and progress are kept.'**
  String get termsUpdatedHint;

  /// No description provided for @settingsLegalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and privacy'**
  String get settingsLegalTitle;

  /// No description provided for @launcherLabelPending.
  ///
  /// In en, this message translates to:
  /// **'The icon name will update after you close the game.'**
  String get launcherLabelPending;

  /// No description provided for @documentClose.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get documentClose;

  /// No description provided for @publicRoomWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting room ready'**
  String get publicRoomWaitingTitle;

  /// No description provided for @publicRoomWaitingStatus.
  ///
  /// In en, this message translates to:
  /// **'Empty; the first player in becomes the host'**
  String get publicRoomWaitingStatus;

  /// No description provided for @onlineShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open sharing or copy the link. Read the room code out to players.'**
  String get onlineShareFailed;

  /// No description provided for @shareTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied. Paste it anywhere to send it.'**
  String get shareTextCopied;

  /// No description provided for @shareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open sharing. Try again.'**
  String get shareUnavailable;

  /// No description provided for @coinsName.
  ///
  /// In en, this message translates to:
  /// **'Council Coins'**
  String get coinsName;

  /// No description provided for @storeTitle.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get storeTitle;

  /// No description provided for @storeTabShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get storeTabShop;

  /// No description provided for @storeTabCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get storeTabCollection;

  /// No description provided for @storeTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get storeTabHistory;

  /// No description provided for @storeTabCoins.
  ///
  /// In en, this message translates to:
  /// **'Buy coins'**
  String get storeTabCoins;

  /// No description provided for @storeEarnTime.
  ///
  /// In en, this message translates to:
  /// **'{count} coins, about {matches} online matches'**
  String storeEarnTime(int count, int matches);

  /// No description provided for @storeSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get storeSectionIdentity;

  /// No description provided for @storeSectionPacks.
  ///
  /// In en, this message translates to:
  /// **'Room presentation'**
  String get storeSectionPacks;

  /// No description provided for @storeSectionNarrator.
  ///
  /// In en, this message translates to:
  /// **'Narration styles'**
  String get storeSectionNarrator;

  /// No description provided for @storeSectionBundles.
  ///
  /// In en, this message translates to:
  /// **'Bundles'**
  String get storeSectionBundles;

  /// No description provided for @storePermanent.
  ///
  /// In en, this message translates to:
  /// **'Permanent'**
  String get storePermanent;

  /// No description provided for @storeOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get storeOwned;

  /// No description provided for @storeEquipped.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get storeEquipped;

  /// No description provided for @storeEquip.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get storeEquip;

  /// No description provided for @storeUnequip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get storeUnequip;

  /// No description provided for @storePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get storePreview;

  /// No description provided for @storeBuyFor.
  ///
  /// In en, this message translates to:
  /// **'Buy for {count}'**
  String storeBuyFor(int count);

  /// No description provided for @storeBuyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy {item}?'**
  String storeBuyConfirmTitle(String item);

  /// No description provided for @storeBuyConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{count} coins will be deducted. The content is cosmetic and permanent, and changes nothing in play.'**
  String storeBuyConfirmBody(int count);

  /// No description provided for @storeNotEnough.
  ///
  /// In en, this message translates to:
  /// **'{count} more coins needed'**
  String storeNotEnough(int count);

  /// No description provided for @storeBundleSaves.
  ///
  /// In en, this message translates to:
  /// **'Saves {count} coins'**
  String storeBundleSaves(int count);

  /// No description provided for @storeBundleOwnedAll.
  ///
  /// In en, this message translates to:
  /// **'You own everything in it'**
  String get storeBundleOwnedAll;

  /// No description provided for @storeBundleContents.
  ///
  /// In en, this message translates to:
  /// **'Includes: {items}'**
  String storeBundleContents(String items);

  /// No description provided for @storeBought.
  ///
  /// In en, this message translates to:
  /// **'Added to your collection'**
  String get storeBought;

  /// No description provided for @storeFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not go through and nothing was deducted. Try again.'**
  String get storeFailed;

  /// No description provided for @storeHostPackNote.
  ///
  /// In en, this message translates to:
  /// **'When the host picks a presentation, everyone in the room sees it without buying it.'**
  String get storeHostPackNote;

  /// No description provided for @storePresentationNote.
  ///
  /// In en, this message translates to:
  /// **'Look and sound only. It never changes rules, votes or roles.'**
  String get storePresentationNote;

  /// No description provided for @storeEmptyCollection.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get storeEmptyCollection;

  /// No description provided for @storeEmptyHistory.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get storeEmptyHistory;

  /// No description provided for @historyMatchCompletion.
  ///
  /// In en, this message translates to:
  /// **'Online match finished'**
  String get historyMatchCompletion;

  /// No description provided for @historyMatchWin.
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get historyMatchWin;

  /// No description provided for @historyCatalogSpend.
  ///
  /// In en, this message translates to:
  /// **'Bought: {item}'**
  String historyCatalogSpend(String item);

  /// No description provided for @historyCatalogRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund: {item}'**
  String historyCatalogRefund(String item);

  /// No description provided for @historyAdReward.
  ///
  /// In en, this message translates to:
  /// **'Video reward'**
  String get historyAdReward;

  /// No description provided for @historyCoinPurchase.
  ///
  /// In en, this message translates to:
  /// **'Coin purchase'**
  String get historyCoinPurchase;

  /// No description provided for @historyCoinPurchaseReversal.
  ///
  /// In en, this message translates to:
  /// **'Coin purchase reversed'**
  String get historyCoinPurchaseReversal;

  /// No description provided for @historyAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get historyAdjustment;

  /// No description provided for @cosmeticClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get cosmeticClassic;

  /// No description provided for @cosmeticFrameGilded.
  ///
  /// In en, this message translates to:
  /// **'Gilded frame'**
  String get cosmeticFrameGilded;

  /// No description provided for @cosmeticFrameGildedDesc.
  ///
  /// In en, this message translates to:
  /// **'An engraved gold frame with a small mask beneath your portrait, seen by every player.'**
  String get cosmeticFrameGildedDesc;

  /// No description provided for @cosmeticFrameCrimson.
  ///
  /// In en, this message translates to:
  /// **'Crimson frame'**
  String get cosmeticFrameCrimson;

  /// No description provided for @cosmeticFrameCrimsonDesc.
  ///
  /// In en, this message translates to:
  /// **'Dark silver with crimson enamel and a small crest below your portrait.'**
  String get cosmeticFrameCrimsonDesc;

  /// No description provided for @cosmeticFrameMoonlit.
  ///
  /// In en, this message translates to:
  /// **'Moonlit frame'**
  String get cosmeticFrameMoonlit;

  /// No description provided for @cosmeticFrameMoonlitDesc.
  ///
  /// In en, this message translates to:
  /// **'Cool silver with a small crescent moon below your portrait.'**
  String get cosmeticFrameMoonlitDesc;

  /// No description provided for @cosmeticPlateNoir.
  ///
  /// In en, this message translates to:
  /// **'Noir nameplate'**
  String get cosmeticPlateNoir;

  /// No description provided for @cosmeticPlateNoirDesc.
  ///
  /// In en, this message translates to:
  /// **'Your name on a charcoal plate in engraved silver with medallion ends.'**
  String get cosmeticPlateNoirDesc;

  /// No description provided for @cosmeticPlateGilded.
  ///
  /// In en, this message translates to:
  /// **'Gilded nameplate'**
  String get cosmeticPlateGilded;

  /// No description provided for @cosmeticPlateGildedDesc.
  ///
  /// In en, this message translates to:
  /// **'Your name on a charcoal plate with a gold edge and fan-shaped ends.'**
  String get cosmeticPlateGildedDesc;

  /// No description provided for @cosmeticPlateEmber.
  ///
  /// In en, this message translates to:
  /// **'Ember nameplate'**
  String get cosmeticPlateEmber;

  /// No description provided for @cosmeticPlateEmberDesc.
  ///
  /// In en, this message translates to:
  /// **'Your name on a charcoal plate edged in crimson and gold with pointed ends.'**
  String get cosmeticPlateEmberDesc;

  /// No description provided for @cosmeticPackManor.
  ///
  /// In en, this message translates to:
  /// **'Midnight Manor'**
  String get cosmeticPackManor;

  /// No description provided for @cosmeticPackManorDesc.
  ///
  /// In en, this message translates to:
  /// **'A candlelit manor hall behind the table with light fog, a candlelight transition between public phases, and an opening and closing line with sound. Everyone in the room sees it.'**
  String get cosmeticPackManorDesc;

  /// No description provided for @cosmeticPackOldTown.
  ///
  /// In en, this message translates to:
  /// **'Old Town'**
  String get cosmeticPackOldTown;

  /// No description provided for @cosmeticPackOldTownDesc.
  ///
  /// In en, this message translates to:
  /// **'A warm old-stone hall behind the table with drifting light, a sweeping-light transition across the table, and an opening and closing line with sound. Everyone in the room sees it.'**
  String get cosmeticPackOldTownDesc;

  /// No description provided for @cosmeticNarratorStoryteller.
  ///
  /// In en, this message translates to:
  /// **'The Storyteller'**
  String get cosmeticNarratorStoryteller;

  /// No description provided for @cosmeticNarratorStorytellerDesc.
  ///
  /// In en, this message translates to:
  /// **'A recorded storyteller voice marks every public phase with the same short line for every player. With sound off, the lines stay as text.'**
  String get cosmeticNarratorStorytellerDesc;

  /// No description provided for @cosmeticBundleCouncil.
  ///
  /// In en, this message translates to:
  /// **'Council bundle'**
  String get cosmeticBundleCouncil;

  /// No description provided for @cosmeticBundleCouncilDesc.
  ///
  /// In en, this message translates to:
  /// **'Midnight Manor, Old Town and The Storyteller together.'**
  String get cosmeticBundleCouncilDesc;

  /// No description provided for @cosmeticBundleIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity bundle'**
  String get cosmeticBundleIdentity;

  /// No description provided for @cosmeticBundleIdentityDesc.
  ///
  /// In en, this message translates to:
  /// **'All three frames and all three nameplates.'**
  String get cosmeticBundleIdentityDesc;

  /// No description provided for @packManorIntro.
  ///
  /// In en, this message translates to:
  /// **'The manor doors are shut. Nobody leaves before the truth does.'**
  String get packManorIntro;

  /// No description provided for @packManorOutro.
  ///
  /// In en, this message translates to:
  /// **'The candles are out, and the manor keeps its secrets.'**
  String get packManorOutro;

  /// No description provided for @packOldTownIntro.
  ///
  /// In en, this message translates to:
  /// **'The old town wakes to a new secret.'**
  String get packOldTownIntro;

  /// No description provided for @packOldTownOutro.
  ///
  /// In en, this message translates to:
  /// **'The streets are quiet. The story is over.'**
  String get packOldTownOutro;

  /// No description provided for @narratorNight.
  ///
  /// In en, this message translates to:
  /// **'Night falls. Everyone stays where they are.'**
  String get narratorNight;

  /// No description provided for @narratorMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning comes, and something has changed.'**
  String get narratorMorning;

  /// No description provided for @narratorDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Now we talk. Who has a case?'**
  String get narratorDiscussion;

  /// No description provided for @narratorVoting.
  ///
  /// In en, this message translates to:
  /// **'The decision belongs to the table.'**
  String get narratorVoting;

  /// No description provided for @narratorResult.
  ///
  /// In en, this message translates to:
  /// **'The story ends, and the secrets are out.'**
  String get narratorResult;

  /// No description provided for @roomPackLabel.
  ///
  /// In en, this message translates to:
  /// **'Room presentation'**
  String get roomPackLabel;

  /// No description provided for @roomNarratorLabel.
  ///
  /// In en, this message translates to:
  /// **'Narrator'**
  String get roomNarratorLabel;

  /// No description provided for @previewTransition.
  ///
  /// In en, this message translates to:
  /// **'Play transition'**
  String get previewTransition;

  /// No description provided for @previewSound.
  ///
  /// In en, this message translates to:
  /// **'Play sound'**
  String get previewSound;

  /// No description provided for @previewIntro.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get previewIntro;

  /// No description provided for @previewOutro.
  ///
  /// In en, this message translates to:
  /// **'Closing'**
  String get previewOutro;

  /// No description provided for @previewSampleName.
  ///
  /// In en, this message translates to:
  /// **'Sami'**
  String get previewSampleName;

  /// No description provided for @onlineRoomRefreshHint.
  ///
  /// In en, this message translates to:
  /// **'Updates automatically. Choose a room to join.'**
  String get onlineRoomRefreshHint;

  /// No description provided for @onlineRoomsAll.
  ///
  /// In en, this message translates to:
  /// **'All rooms'**
  String get onlineRoomsAll;

  /// No description provided for @onlineRoomsNearlyReady.
  ///
  /// In en, this message translates to:
  /// **'Need 1–2 players'**
  String get onlineRoomsNearlyReady;

  /// No description provided for @onlineRoomsNoFilterMatches.
  ///
  /// In en, this message translates to:
  /// **'No rooms need just 1–2 players right now. Browse all rooms or invite your friends.'**
  String get onlineRoomsNoFilterMatches;

  /// No description provided for @onlineRoomVoiceOn.
  ///
  /// In en, this message translates to:
  /// **'Voice enabled'**
  String get onlineRoomVoiceOn;

  /// No description provided for @onlineRoomVoiceOff.
  ///
  /// In en, this message translates to:
  /// **'Voice disabled'**
  String get onlineRoomVoiceOff;

  /// No description provided for @onlineLobbyInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Share the room invite to bring your friends to this table.'**
  String get onlineLobbyInviteHint;

  /// No description provided for @onlineLobbyHostReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Your table has enough players. Start when everyone is ready.'**
  String get onlineLobbyHostReadyHint;

  /// No description provided for @onlineLobbyGuestReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Enough players are here. Your host will start the match.'**
  String get onlineLobbyGuestReadyHint;

  /// No description provided for @onlineVoteSending.
  ///
  /// In en, this message translates to:
  /// **'Sending your vote…'**
  String get onlineVoteSending;

  /// No description provided for @onlineVoteReceived.
  ///
  /// In en, this message translates to:
  /// **'Vote received. Waiting for the ballot to close.'**
  String get onlineVoteReceived;

  /// No description provided for @onlineVoteResolving.
  ///
  /// In en, this message translates to:
  /// **'The ballot is closed. Waiting for the result.'**
  String get onlineVoteResolving;

  /// No description provided for @onlineVoteSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a player at the table, then confirm your vote.'**
  String get onlineVoteSelectHint;

  /// No description provided for @onlineConfirmSuspicion.
  ///
  /// In en, this message translates to:
  /// **'Confirm suspicion'**
  String get onlineConfirmSuspicion;

  /// No description provided for @onlineBeginVoting.
  ///
  /// In en, this message translates to:
  /// **'Open voting'**
  String get onlineBeginVoting;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account protection'**
  String get accountTitle;

  /// No description provided for @accountAnonymousHint.
  ///
  /// In en, this message translates to:
  /// **'Your coins and items are tied to this device only. Uninstalling or changing phones can lose them. Link an email to be able to recover them. Playing never needs an account.'**
  String get accountAnonymousHint;

  /// No description provided for @accountProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected with {email}'**
  String accountProtected(String email);

  /// No description provided for @accountLink.
  ///
  /// In en, this message translates to:
  /// **'Protect with email'**
  String get accountLink;

  /// No description provided for @accountRecover.
  ///
  /// In en, this message translates to:
  /// **'I already have a protected account'**
  String get accountRecover;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// No description provided for @accountSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get accountSendCode;

  /// No description provided for @accountCode.
  ///
  /// In en, this message translates to:
  /// **'Code from the email'**
  String get accountCode;

  /// No description provided for @accountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get accountConfirm;

  /// No description provided for @accountCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent an email to {email}. It holds either a 6-digit code (type it below) or a link (open it, then tap «I opened the email link»). It can take a minute; check spam if you do not see it.'**
  String accountCodeSent(String email);

  /// No description provided for @accountRecoverWarning.
  ///
  /// In en, this message translates to:
  /// **'You will sign in to your protected account. Coins on this device without an account will not move to it.'**
  String get accountRecoverWarning;

  /// No description provided for @accountErrorEmail.
  ///
  /// In en, this message translates to:
  /// **'That email does not look right.'**
  String get accountErrorEmail;

  /// No description provided for @accountErrorTaken.
  ///
  /// In en, this message translates to:
  /// **'That email belongs to another account. Use «I already have a protected account».'**
  String get accountErrorTaken;

  /// No description provided for @accountErrorCode.
  ///
  /// In en, this message translates to:
  /// **'The code is wrong or expired. Ask for a new one.'**
  String get accountErrorCode;

  /// No description provided for @accountErrorRate.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Wait a little and try again.'**
  String get accountErrorRate;

  /// No description provided for @accountErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available right now. Try later.'**
  String get accountErrorUnavailable;

  /// No description provided for @accountLinkOpened.
  ///
  /// In en, this message translates to:
  /// **'I opened the email link'**
  String get accountLinkOpened;

  /// No description provided for @accountErrorLinkPending.
  ///
  /// In en, this message translates to:
  /// **'The email is not confirmed yet. Open the link in the email, then tap again.'**
  String get accountErrorLinkPending;

  /// No description provided for @accountErrorLinkElsewhere.
  ///
  /// In en, this message translates to:
  /// **'The link signs in the browser that opened it, not this app. Use the code from the email.'**
  String get accountErrorLinkElsewhere;

  /// No description provided for @accountRecoverLinkNote.
  ///
  /// In en, this message translates to:
  /// **'On a new device only the 6-digit code can sign this app in; the email link cannot. If your email has no code, recovery by code will work once our emails are updated.'**
  String get accountRecoverLinkNote;

  /// No description provided for @coinPacksUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Buying coins is not available right now. Coins are still earned from online matches.'**
  String get coinPacksUnavailable;

  /// No description provided for @coinPacksNeedAccount.
  ///
  /// In en, this message translates to:
  /// **'Before paying, protect your account with an email so paid coins stay with you on any device.'**
  String get coinPacksNeedAccount;

  /// No description provided for @coinPackCoins.
  ///
  /// In en, this message translates to:
  /// **'{count} coins'**
  String coinPackCoins(int count);

  /// No description provided for @coinPackPrice.
  ///
  /// In en, this message translates to:
  /// **'EGP {amount}'**
  String coinPackPrice(String amount);

  /// No description provided for @coinPayMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get coinPayMethod;

  /// No description provided for @coinPayInstapay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get coinPayInstapay;

  /// No description provided for @coinPayVodafone.
  ///
  /// In en, this message translates to:
  /// **'Vodafone Cash'**
  String get coinPayVodafone;

  /// No description provided for @coinPayMethodOff.
  ///
  /// In en, this message translates to:
  /// **'Not available now'**
  String get coinPayMethodOff;

  /// No description provided for @coinManualNotice.
  ///
  /// In en, this message translates to:
  /// **'Transfers are reviewed by hand, and coins are added after the transfer is confirmed'**
  String get coinManualNotice;

  /// No description provided for @coinManualDetail.
  ///
  /// In en, this message translates to:
  /// **'The payment page opens outside the game and may switch to your bank or wallet app. Transfer the exact amount shown, then come back and enter the transaction number. Opening or returning from the link adds no coins.'**
  String get coinManualDetail;

  /// No description provided for @coinCreateOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm order: EGP {amount}'**
  String coinCreateOrder(String amount);

  /// No description provided for @coinOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order {reference}'**
  String coinOrderTitle(String reference);

  /// No description provided for @coinOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins for EGP {amount} via {method}'**
  String coinOrderSummary(int coins, String amount, String method);

  /// No description provided for @coinOpenPayment.
  ///
  /// In en, this message translates to:
  /// **'Open {method}'**
  String coinOpenPayment(String method);

  /// No description provided for @coinOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'The browser did not open the page. Allow pop-ups for this site and try again.'**
  String get coinOpenFailed;

  /// No description provided for @coinDesktopHint.
  ///
  /// In en, this message translates to:
  /// **'On a computer with the wallet app on your phone, open this site on the phone to complete the transfer.'**
  String get coinDesktopHint;

  /// No description provided for @coinSentTransfer.
  ///
  /// In en, this message translates to:
  /// **'I sent the transfer'**
  String get coinSentTransfer;

  /// No description provided for @coinTransferReference.
  ///
  /// In en, this message translates to:
  /// **'Transaction number'**
  String get coinTransferReference;

  /// No description provided for @coinPayerHint.
  ///
  /// In en, this message translates to:
  /// **'Sender name (optional)'**
  String get coinPayerHint;

  /// No description provided for @coinClaimNote.
  ///
  /// In en, this message translates to:
  /// **'This reports your transfer; it is not a confirmation. Nobody will ask for your PIN or a code.'**
  String get coinClaimNote;

  /// No description provided for @coinCancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get coinCancelOrder;

  /// No description provided for @coinStatusAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your transfer'**
  String get coinStatusAwaiting;

  /// No description provided for @coinStatusClaimed.
  ///
  /// In en, this message translates to:
  /// **'Under review. Coins are added once the money is confirmed.'**
  String get coinStatusClaimed;

  /// No description provided for @coinStatusNeedsInfo.
  ///
  /// In en, this message translates to:
  /// **'We need details: {note}'**
  String coinStatusNeedsInfo(String note);

  /// No description provided for @coinStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins added'**
  String coinStatusPaid(int coins);

  /// No description provided for @coinStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Order declined: {note}'**
  String coinStatusRejected(String note);

  /// No description provided for @coinStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get coinStatusCancelled;

  /// No description provided for @coinStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'The order expired. If you already transferred, enter the transaction number and it will be reviewed.'**
  String get coinStatusExpired;

  /// No description provided for @coinStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded: {note}'**
  String coinStatusRefunded(String note);

  /// No description provided for @coinOrderFailed.
  ///
  /// In en, this message translates to:
  /// **'The order was not recorded. Nothing was charged; try again.'**
  String get coinOrderFailed;

  /// No description provided for @adminCoinsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer review'**
  String get adminCoinsTitle;

  /// No description provided for @adminNotAdmin.
  ///
  /// In en, this message translates to:
  /// **'This account is not an admin.'**
  String get adminNotAdmin;

  /// No description provided for @adminEmpty.
  ///
  /// In en, this message translates to:
  /// **'No orders waiting for review.'**
  String get adminEmpty;

  /// No description provided for @adminProviderTxn.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID in your statement'**
  String get adminProviderTxn;

  /// No description provided for @adminReceived.
  ///
  /// In en, this message translates to:
  /// **'Amount received (EGP)'**
  String get adminReceived;

  /// No description provided for @adminNote.
  ///
  /// In en, this message translates to:
  /// **'Note to player'**
  String get adminNote;

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Received: add coins'**
  String get adminApprove;

  /// No description provided for @adminNeedsInfo.
  ///
  /// In en, this message translates to:
  /// **'Ask for details'**
  String get adminNeedsInfo;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get adminReject;

  /// No description provided for @adminRefund.
  ///
  /// In en, this message translates to:
  /// **'Money returned'**
  String get adminRefund;

  /// No description provided for @adminCheckFirst.
  ///
  /// In en, this message translates to:
  /// **'Check your bank or wallet statement yourself and match amount, method and reference before approving. If unsure, leave it under review.'**
  String get adminCheckFirst;

  /// No description provided for @adminErrorAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount does not match. Ask for details or decline.'**
  String get adminErrorAmount;

  /// No description provided for @adminErrorUsed.
  ///
  /// In en, this message translates to:
  /// **'That transaction already funded another order.'**
  String get adminErrorUsed;

  /// No description provided for @adminErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Not done. Check the fields and try again.'**
  String get adminErrorGeneric;

  /// No description provided for @adminOrderLine.
  ///
  /// In en, this message translates to:
  /// **'{reference} · {account} · EGP {amount} · {method} · player ref: {claim}'**
  String adminOrderLine(
    String reference,
    String account,
    String amount,
    String method,
    String claim,
  );

  /// No description provided for @adminFilterOpen.
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get adminFilterOpen;

  /// No description provided for @adminFilterPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get adminFilterPaid;

  /// No description provided for @arrivalIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Your seat at the table'**
  String get arrivalIdentityTitle;

  /// No description provided for @arrivalIdentityHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the name and face your friends will recognise.'**
  String get arrivalIdentityHint;

  /// No description provided for @arrivalWelcomeHint.
  ///
  /// In en, this message translates to:
  /// **'A secret role. A room full of suspects. Your story starts here.'**
  String get arrivalWelcomeHint;

  /// No description provided for @arrivalPactTitle.
  ///
  /// In en, this message translates to:
  /// **'Before the first night'**
  String get arrivalPactTitle;

  /// No description provided for @arrivalStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String arrivalStep(int step, int total);

  /// No description provided for @arrivalSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving your seat…'**
  String get arrivalSaving;

  /// No description provided for @councilInvitation.
  ///
  /// In en, this message translates to:
  /// **'Every voice has a story. Who will you believe?'**
  String get councilInvitation;

  /// No description provided for @witnessTableLoading.
  ///
  /// In en, this message translates to:
  /// **'Opening the table…'**
  String get witnessTableLoading;

  /// No description provided for @witnessTableNoActions.
  ///
  /// In en, this message translates to:
  /// **'Nobody has chosen anything at night yet'**
  String get witnessTableNoActions;

  /// No description provided for @witnessActionKill.
  ///
  /// In en, this message translates to:
  /// **'{actor} chose to kill {target}'**
  String witnessActionKill(String actor, String target);

  /// No description provided for @witnessActionProtect.
  ///
  /// In en, this message translates to:
  /// **'{actor} is protecting {target}'**
  String witnessActionProtect(String actor, String target);

  /// No description provided for @witnessActionInvestigate.
  ///
  /// In en, this message translates to:
  /// **'{actor} checked {target}'**
  String witnessActionInvestigate(String actor, String target);

  /// No description provided for @witnessActionSuspect.
  ///
  /// In en, this message translates to:
  /// **'{actor} suspects {target}'**
  String witnessActionSuspect(String actor, String target);

  /// No description provided for @onlineDiscussionLive.
  ///
  /// In en, this message translates to:
  /// **'The discussion is on'**
  String get onlineDiscussionLive;

  /// No description provided for @witnessEventNight.
  ///
  /// In en, this message translates to:
  /// **'Night: everyone chooses in secret'**
  String get witnessEventNight;

  /// No description provided for @witnessEventOpening.
  ///
  /// In en, this message translates to:
  /// **'{name} is naming a suspect'**
  String witnessEventOpening(String name);

  /// No description provided for @witnessEventDiscussion.
  ///
  /// In en, this message translates to:
  /// **'The players still in are talking'**
  String get witnessEventDiscussion;

  /// No description provided for @witnessEventVoting.
  ///
  /// In en, this message translates to:
  /// **'The vote is on'**
  String get witnessEventVoting;

  /// No description provided for @onlineAbandonedTitle.
  ///
  /// In en, this message translates to:
  /// **'Everyone else has left'**
  String get onlineAbandonedTitle;

  /// No description provided for @onlineAbandonedBody.
  ///
  /// In en, this message translates to:
  /// **'There is nobody left at the table but you, so this match is over. Head home and start a new room.'**
  String get onlineAbandonedBody;

  /// No description provided for @nightCitizenRest.
  ///
  /// In en, this message translates to:
  /// **'You are a Citizen'**
  String get nightCitizenRest;

  /// No description provided for @nightCitizenRestSupport.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do on the first night. Wait for the others to finish, and the day will come.'**
  String get nightCitizenRestSupport;

  /// No description provided for @readyToVote.
  ///
  /// In en, this message translates to:
  /// **'Ready to vote ({ready} of {living})'**
  String readyToVote(int ready, int living);

  /// No description provided for @readyToVoteWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the rest ({ready} of {living})'**
  String readyToVoteWaiting(int ready, int living);

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Match rules'**
  String get settingsRulesTitle;

  /// No description provided for @settingsRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Every new match starts from these, and you can still change them before one.'**
  String get settingsRulesHint;

  /// No description provided for @settingsSectionMore.
  ///
  /// In en, this message translates to:
  /// **'Help & privacy'**
  String get settingsSectionMore;

  /// No description provided for @onlineRoomSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Every change reaches everyone in the room right away.'**
  String get onlineRoomSettingsHint;

  /// No description provided for @vaultTitle.
  ///
  /// In en, this message translates to:
  /// **'The Council Vault'**
  String get vaultTitle;

  /// No description provided for @vaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your signature. Your council atmosphere.'**
  String get vaultSubtitle;

  /// No description provided for @storeFrames.
  ///
  /// In en, this message translates to:
  /// **'Avatar frames'**
  String get storeFrames;

  /// No description provided for @storeNameplates.
  ///
  /// In en, this message translates to:
  /// **'Nameplates'**
  String get storeNameplates;

  /// No description provided for @storeBrowseNext.
  ///
  /// In en, this message translates to:
  /// **'More products'**
  String get storeBrowseNext;

  /// No description provided for @storeBrowsePrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous products'**
  String get storeBrowsePrevious;

  /// No description provided for @cosmeticPackArchive.
  ///
  /// In en, this message translates to:
  /// **'Moonlit Archive'**
  String get cosmeticPackArchive;

  /// No description provided for @cosmeticPackArchiveDesc.
  ///
  /// In en, this message translates to:
  /// **'A moonlit archive behind the table in quiet silver, a moonlight transition between public phases, and an opening and closing line with sound. Everyone in the room sees it.'**
  String get cosmeticPackArchiveDesc;

  /// No description provided for @cosmeticNarratorKeeper.
  ///
  /// In en, this message translates to:
  /// **'Secret Keeper'**
  String get cosmeticNarratorKeeper;

  /// No description provided for @cosmeticNarratorKeeperDesc.
  ///
  /// In en, this message translates to:
  /// **'A solemn recorded keeper voice marks each public phase in an archival style, the same for every player.'**
  String get cosmeticNarratorKeeperDesc;

  /// No description provided for @cosmeticNarratorNoir.
  ///
  /// In en, this message translates to:
  /// **'Noir Narrator'**
  String get cosmeticNarratorNoir;

  /// No description provided for @cosmeticNarratorNoirDesc.
  ///
  /// In en, this message translates to:
  /// **'A terse recorded noir voice marks each public phase, the same for every player.'**
  String get cosmeticNarratorNoirDesc;

  /// No description provided for @cosmeticBundleNocturne.
  ///
  /// In en, this message translates to:
  /// **'Nocturne Collection'**
  String get cosmeticBundleNocturne;

  /// No description provided for @cosmeticBundleNocturneDesc.
  ///
  /// In en, this message translates to:
  /// **'Moonlit Archive, the Moonlit frame, the Noir nameplate and the Secret Keeper together.'**
  String get cosmeticBundleNocturneDesc;

  /// No description provided for @packArchiveIntro.
  ///
  /// In en, this message translates to:
  /// **'The archive opens its doors under the moon.'**
  String get packArchiveIntro;

  /// No description provided for @packArchiveOutro.
  ///
  /// In en, this message translates to:
  /// **'The moonlight withdraws, and the files return to their shelves.'**
  String get packArchiveOutro;

  /// No description provided for @narratorKeeperNight.
  ///
  /// In en, this message translates to:
  /// **'The ledger closes on the night\'s page.'**
  String get narratorKeeperNight;

  /// No description provided for @narratorKeeperMorning.
  ///
  /// In en, this message translates to:
  /// **'The day\'s page is open.'**
  String get narratorKeeperMorning;

  /// No description provided for @narratorKeeperDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Every word carries weight. Choose yours carefully.'**
  String get narratorKeeperDiscussion;

  /// No description provided for @narratorKeeperVoting.
  ///
  /// In en, this message translates to:
  /// **'The council records its decision.'**
  String get narratorKeeperVoting;

  /// No description provided for @narratorKeeperResult.
  ///
  /// In en, this message translates to:
  /// **'The ledger is closed; the story joins the archive.'**
  String get narratorKeeperResult;

  /// No description provided for @narratorNoirNight.
  ///
  /// In en, this message translates to:
  /// **'The city sleeps. The streets are empty.'**
  String get narratorNoirNight;

  /// No description provided for @narratorNoirMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning. Everyone is looking for the truth.'**
  String get narratorNoirMorning;

  /// No description provided for @narratorNoirDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Everyone has a story. Who is telling the truth?'**
  String get narratorNoirDiscussion;

  /// No description provided for @narratorNoirVoting.
  ///
  /// In en, this message translates to:
  /// **'Decision time. Every vote has a price.'**
  String get narratorNoirVoting;

  /// No description provided for @narratorNoirResult.
  ///
  /// In en, this message translates to:
  /// **'Case closed.'**
  String get narratorNoirResult;

  /// No description provided for @storeAboutCoins.
  ///
  /// In en, this message translates to:
  /// **'About coins'**
  String get storeAboutCoins;

  /// No description provided for @storeInside.
  ///
  /// In en, this message translates to:
  /// **'What\'s inside'**
  String get storeInside;

  /// No description provided for @storeBalance.
  ///
  /// In en, this message translates to:
  /// **'Your balance: {count} coins'**
  String storeBalance(int count);

  /// No description provided for @storeRoomArtNote.
  ///
  /// In en, this message translates to:
  /// **'The scene shows faintly behind the table in public phases only, never at night.'**
  String get storeRoomArtNote;

  /// No description provided for @profileAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address me as'**
  String get profileAddressLabel;

  /// No description provided for @profileAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Arabic speaks to men and women differently, so roles and messages are written this way.'**
  String get profileAddressHint;

  /// No description provided for @onlinePlayingAs.
  ///
  /// In en, this message translates to:
  /// **'Playing as {name}'**
  String onlinePlayingAs(String name);

  /// No description provided for @onlineNoPublicRoomsHint.
  ///
  /// In en, this message translates to:
  /// **'Create a room and send your friends the code, or refresh in a moment.'**
  String get onlineNoPublicRoomsHint;

  /// No description provided for @lobbyInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get lobbyInviteFriends;

  /// No description provided for @adStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional bonus: up to 2 ads'**
  String get adStepsTitle;

  /// No description provided for @adStepsDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Each ad you finish is verified and adds its coins; stopping after the first keeps it. Both ads together add +{total}. Your match reward stays yours either way.'**
  String adStepsDisclosure(int total);

  /// No description provided for @adStepAction.
  ///
  /// In en, this message translates to:
  /// **'Ad {step} of 2 · +{amount}'**
  String adStepAction(int step, int amount);

  /// No description provided for @adStepDone.
  ///
  /// In en, this message translates to:
  /// **'Ad {step} of 2 · +{amount} added'**
  String adStepDone(int step, int amount);

  /// No description provided for @adStepsComplete.
  ///
  /// In en, this message translates to:
  /// **'+{total} bonus coins added for this match.'**
  String adStepsComplete(int total);

  /// No description provided for @adRewardCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get adRewardCheckAgain;

  /// No description provided for @adRewardNotConsented.
  ///
  /// In en, this message translates to:
  /// **'Ads need your consent first. You can change it in Settings, under “Ad privacy choices”.'**
  String get adRewardNotConsented;

  /// No description provided for @storeTabRewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get storeTabRewards;

  /// No description provided for @dailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily rewards'**
  String get dailyTitle;

  /// No description provided for @dailyResetNote.
  ///
  /// In en, this message translates to:
  /// **'A new day starts at 00:00 UTC.'**
  String get dailyResetNote;

  /// No description provided for @dailyCofferTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily coffer'**
  String get dailyCofferTitle;

  /// No description provided for @dailyCofferBody.
  ///
  /// In en, this message translates to:
  /// **'Free once a day: +{amount} Council Coins.'**
  String dailyCofferBody(int amount);

  /// No description provided for @dailyCofferClaim.
  ///
  /// In en, this message translates to:
  /// **'Open · +{amount}'**
  String dailyCofferClaim(int amount);

  /// No description provided for @dailyCofferClaimed.
  ///
  /// In en, this message translates to:
  /// **'Opened today. Come back tomorrow.'**
  String get dailyCofferClaimed;

  /// No description provided for @dailyCofferGranted.
  ///
  /// In en, this message translates to:
  /// **'+{amount} added to your coins.'**
  String dailyCofferGranted(int amount);

  /// No description provided for @dailyWeekBonusGranted.
  ///
  /// In en, this message translates to:
  /// **'Seventh day! +{amount} bonus.'**
  String dailyWeekBonusGranted(int amount);

  /// No description provided for @dailyWheelTitle.
  ///
  /// In en, this message translates to:
  /// **'Free wheel'**
  String get dailyWheelTitle;

  /// No description provided for @dailyWheelBody.
  ///
  /// In en, this message translates to:
  /// **'One free spin each day. It costs nothing and has no cash value.'**
  String get dailyWheelBody;

  /// No description provided for @dailyWheelSpin.
  ///
  /// In en, this message translates to:
  /// **'Spin free'**
  String get dailyWheelSpin;

  /// No description provided for @dailyWheelResult.
  ///
  /// In en, this message translates to:
  /// **'The wheel landed on +{amount}.'**
  String dailyWheelResult(int amount);

  /// No description provided for @dailyWheelDone.
  ///
  /// In en, this message translates to:
  /// **'Today\'s spin: +{amount}. Next spin tomorrow.'**
  String dailyWheelDone(int amount);

  /// No description provided for @dailyWheelOdds.
  ///
  /// In en, this message translates to:
  /// **'Exact odds'**
  String get dailyWheelOdds;

  /// No description provided for @dailyWheelOddsRow.
  ///
  /// In en, this message translates to:
  /// **'+{coins} coins'**
  String dailyWheelOddsRow(int coins);

  /// No description provided for @dailyWheelPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String dailyWheelPercent(String percent);

  /// No description provided for @dailyWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Seven-day card'**
  String get dailyWeekTitle;

  /// No description provided for @dailyWeekBody.
  ///
  /// In en, this message translates to:
  /// **'{progress} of 7 opened. Every seventh day you open adds +{bonus}. A missed day resets nothing.'**
  String dailyWeekBody(int progress, int bonus);

  /// No description provided for @dailyAdTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily ad (optional)'**
  String get dailyAdTitle;

  /// No description provided for @dailyAdBody.
  ///
  /// In en, this message translates to:
  /// **'One optional ad per day for exactly +{amount} coins.'**
  String dailyAdBody(int amount);

  /// No description provided for @dailyAdAction.
  ///
  /// In en, this message translates to:
  /// **'Watch · +{amount}'**
  String dailyAdAction(int amount);

  /// No description provided for @dailyAdDone.
  ///
  /// In en, this message translates to:
  /// **'Today\'s ad reward is collected.'**
  String get dailyAdDone;

  /// No description provided for @dailyAdInMatch.
  ///
  /// In en, this message translates to:
  /// **'Available outside a match.'**
  String get dailyAdInMatch;

  /// No description provided for @dailyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the vault. Try again.'**
  String get dailyFailed;

  /// No description provided for @dailyDayChanged.
  ///
  /// In en, this message translates to:
  /// **'A new day started. Refreshed.'**
  String get dailyDayChanged;

  /// No description provided for @historyAdStep.
  ///
  /// In en, this message translates to:
  /// **'Bonus ad'**
  String get historyAdStep;

  /// No description provided for @historyDailyCoffer.
  ///
  /// In en, this message translates to:
  /// **'Daily coffer'**
  String get historyDailyCoffer;

  /// No description provided for @historyDailyWheel.
  ///
  /// In en, this message translates to:
  /// **'Free wheel'**
  String get historyDailyWheel;

  /// No description provided for @historyDailyWeek.
  ///
  /// In en, this message translates to:
  /// **'Seventh-day bonus'**
  String get historyDailyWeek;

  /// No description provided for @historyDailyAd.
  ///
  /// In en, this message translates to:
  /// **'Daily ad'**
  String get historyDailyAd;

  /// No description provided for @historyPlayCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins bought on Google Play'**
  String get historyPlayCoins;

  /// No description provided for @historyPlayReversal.
  ///
  /// In en, this message translates to:
  /// **'Google Play refund'**
  String get historyPlayReversal;

  /// No description provided for @storeTabPlay.
  ///
  /// In en, this message translates to:
  /// **'Coins & pass'**
  String get storeTabPlay;

  /// No description provided for @quietPassTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet Pass'**
  String get quietPassTitle;

  /// No description provided for @quietPassBody.
  ///
  /// In en, this message translates to:
  /// **'Permanent. Removes every automatic ad: the app-open ad, the ads before and after matches and between menus, and the waiting-room banners. Optional reward ads stay available if you want them. No gameplay advantage.'**
  String get quietPassBody;

  /// No description provided for @quietPassOwned.
  ///
  /// In en, this message translates to:
  /// **'Quiet Pass active'**
  String get quietPassOwned;

  /// No description provided for @playPackTitle.
  ///
  /// In en, this message translates to:
  /// **'{coins} Council Coins'**
  String playPackTitle(int coins);

  /// No description provided for @playBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy · {price}'**
  String playBuy(String price);

  /// No description provided for @playUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases aren\'t available on this device right now.'**
  String get playUnavailable;

  /// No description provided for @playPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending. It is added when Google confirms it.'**
  String get playPending;

  /// No description provided for @playVerified.
  ///
  /// In en, this message translates to:
  /// **'Purchase confirmed.'**
  String get playVerified;

  /// No description provided for @playFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase was not completed.'**
  String get playFailed;

  /// No description provided for @playAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'This purchase belongs to another account.'**
  String get playAccountMismatch;

  /// No description provided for @playNeedsProtection.
  ///
  /// In en, this message translates to:
  /// **'Protect your account with an email before buying, so a purchase is never lost with your phone.'**
  String get playNeedsProtection;

  /// No description provided for @playRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get playRestore;

  /// No description provided for @playCoinsNote.
  ///
  /// In en, this message translates to:
  /// **'Council Coins buy cosmetics only. They have no cash value and give no advantage.'**
  String get playCoinsNote;

  /// No description provided for @playRefundRule.
  ///
  /// In en, this message translates to:
  /// **'If a coin pack is refunded, its unspent coins are removed. Coins already spent become an amount your next coin pack pays first; earned coins and owned items are never taken.'**
  String get playRefundRule;

  /// No description provided for @playDebtNotice.
  ///
  /// In en, this message translates to:
  /// **'An earlier refund is still open: your next {coins} purchased coins settle it first.'**
  String playDebtNotice(int coins);

  /// No description provided for @quietPassRefundRule.
  ///
  /// In en, this message translates to:
  /// **'If the pass is refunded, it is removed; your coins and items stay.'**
  String get quietPassRefundRule;

  /// No description provided for @storeTabCouncil.
  ///
  /// In en, this message translates to:
  /// **'Council'**
  String get storeTabCouncil;

  /// No description provided for @councilRankTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Council rank'**
  String get councilRankTitle;

  /// No description provided for @councilLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String councilLevel(int level);

  /// No description provided for @councilXpProgress.
  ///
  /// In en, this message translates to:
  /// **'{xp} / {next} XP'**
  String councilXpProgress(int xp, int next);

  /// No description provided for @councilXpTotal.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String councilXpTotal(int xp);

  /// No description provided for @councilMaxLevel.
  ///
  /// In en, this message translates to:
  /// **'The top of the Council'**
  String get councilMaxLevel;

  /// No description provided for @councilNextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next level: +{coins}'**
  String councilNextLevel(int coins);

  /// No description provided for @councilWeekXp.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP this week'**
  String councilWeekXp(int xp);

  /// No description provided for @councilHowXp.
  ///
  /// In en, this message translates to:
  /// **'Every finished online match earns XP — a win earns more.'**
  String get councilHowXp;

  /// No description provided for @councilFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the Council. Try again.'**
  String get councilFailed;

  /// No description provided for @councilAttention.
  ///
  /// In en, this message translates to:
  /// **'Something is waiting for you in the vault'**
  String get councilAttention;

  /// No description provided for @contractsTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s contracts'**
  String get contractsTitle;

  /// No description provided for @contractsReset.
  ///
  /// In en, this message translates to:
  /// **'Renews at 00:00 UTC'**
  String get contractsReset;

  /// No description provided for @contractFinishOne.
  ///
  /// In en, this message translates to:
  /// **'Finish a match'**
  String get contractFinishOne;

  /// No description provided for @contractFinishMany.
  ///
  /// In en, this message translates to:
  /// **'Finish {count} matches'**
  String contractFinishMany(int count);

  /// No description provided for @contractTown.
  ///
  /// In en, this message translates to:
  /// **'Finish a match on the town side'**
  String get contractTown;

  /// No description provided for @contractMafia.
  ///
  /// In en, this message translates to:
  /// **'Finish a match on the mafia side'**
  String get contractMafia;

  /// No description provided for @contractWinOne.
  ///
  /// In en, this message translates to:
  /// **'Win a match'**
  String get contractWinOne;

  /// No description provided for @contractWinMany.
  ///
  /// In en, this message translates to:
  /// **'Win {count} matches'**
  String contractWinMany(int count);

  /// No description provided for @contractHost.
  ///
  /// In en, this message translates to:
  /// **'Host a match to the end'**
  String get contractHost;

  /// No description provided for @contractReunion.
  ///
  /// In en, this message translates to:
  /// **'Play again with someone you\'ve played with'**
  String get contractReunion;

  /// No description provided for @contractProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{target}'**
  String contractProgress(int done, int target);

  /// No description provided for @contractClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim +{coins}'**
  String contractClaim(int coins);

  /// No description provided for @contractClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get contractClaimed;

  /// No description provided for @contractsBonus.
  ///
  /// In en, this message translates to:
  /// **'Complete all three: +{coins}'**
  String contractsBonus(int coins);

  /// No description provided for @contractsBonusDone.
  ///
  /// In en, this message translates to:
  /// **'All three done'**
  String get contractsBonusDone;

  /// No description provided for @contractBonusGranted.
  ///
  /// In en, this message translates to:
  /// **'All three! +{coins} bonus.'**
  String contractBonusGranted(int coins);

  /// No description provided for @contractIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Not yet — finish the match first.'**
  String get contractIncomplete;

  /// No description provided for @weeklyTitle.
  ///
  /// In en, this message translates to:
  /// **'This week\'s contract'**
  String get weeklyTitle;

  /// No description provided for @weeklyBody.
  ///
  /// In en, this message translates to:
  /// **'Finish {target} online matches this week'**
  String weeklyBody(int target);

  /// No description provided for @weeklyReward.
  ///
  /// In en, this message translates to:
  /// **'+{coins} coins and {xp} XP'**
  String weeklyReward(int coins, int xp);

  /// No description provided for @weeklyRewardCoins.
  ///
  /// In en, this message translates to:
  /// **'+{coins} coins'**
  String weeklyRewardCoins(int coins);

  /// No description provided for @weeklyReset.
  ///
  /// In en, this message translates to:
  /// **'Renews Monday 00:00 UTC'**
  String get weeklyReset;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Top this week'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardOpen.
  ///
  /// In en, this message translates to:
  /// **'This week\'s board'**
  String get leaderboardOpen;

  /// No description provided for @leaderboardYou.
  ///
  /// In en, this message translates to:
  /// **'Your position: {position}'**
  String leaderboardYou(int position);

  /// No description provided for @leaderboardNone.
  ///
  /// In en, this message translates to:
  /// **'Play a match to enter the board'**
  String get leaderboardNone;

  /// No description provided for @leaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody has earned XP this week yet.'**
  String get leaderboardEmpty;

  /// No description provided for @leaderboardHidden.
  ///
  /// In en, this message translates to:
  /// **'You\'re hidden from the board; only you see your position.'**
  String get leaderboardHidden;

  /// No description provided for @leaderboardVisibleLabel.
  ///
  /// In en, this message translates to:
  /// **'Show me on the leaderboard'**
  String get leaderboardVisibleLabel;

  /// No description provided for @leaderboardVisibleBody.
  ///
  /// In en, this message translates to:
  /// **'Your name, look and rank appear on the weekly board. Nothing about your matches is shown.'**
  String get leaderboardVisibleBody;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get inviteTitle;

  /// No description provided for @inviteBody.
  ///
  /// In en, this message translates to:
  /// **'1. Send your code or room link to a friend who just installed the game (within 7 days).\n2. They open the link, or type the code under «Have an invite code?» in the Council.\n3. When they finish their first online match: you +{inviter}, they +{invitee}.'**
  String inviteBody(int inviter, int invitee);

  /// No description provided for @inviteCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get inviteCopy;

  /// No description provided for @inviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get inviteCopied;

  /// No description provided for @inviteShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get inviteShare;

  /// No description provided for @inviteShareText.
  ///
  /// In en, this message translates to:
  /// **'Join me in Mafia Master! Use my invite code {code} in the Council tab of the vault.'**
  String inviteShareText(String code);

  /// No description provided for @inviteCounters.
  ///
  /// In en, this message translates to:
  /// **'Rewarded: {rewarded}/{cap} · Waiting: {pending}'**
  String inviteCounters(int rewarded, int cap, int pending);

  /// No description provided for @inviteHaveCode.
  ///
  /// In en, this message translates to:
  /// **'Have an invite code?'**
  String get inviteHaveCode;

  /// No description provided for @inviteField.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteField;

  /// No description provided for @inviteRedeem.
  ///
  /// In en, this message translates to:
  /// **'Use code'**
  String get inviteRedeem;

  /// No description provided for @inviteRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Invite saved. Finish a match to unlock both rewards.'**
  String get inviteRedeemed;

  /// No description provided for @inviteRewarded.
  ///
  /// In en, this message translates to:
  /// **'Invite reward received.'**
  String get inviteRewarded;

  /// No description provided for @inviteSettledNoCoinsNotice.
  ///
  /// In en, this message translates to:
  /// **'{name} completed the invite conditions — it counts toward your invite progress.'**
  String inviteSettledNoCoinsNotice(String name);

  /// No description provided for @inviteNotFound.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t exist.'**
  String get inviteNotFound;

  /// No description provided for @inviteSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t use your own code.'**
  String get inviteSelf;

  /// No description provided for @inviteExpired.
  ///
  /// In en, this message translates to:
  /// **'Invite codes are for new accounts, within 7 days.'**
  String get inviteExpired;

  /// No description provided for @inviteNotNew.
  ///
  /// In en, this message translates to:
  /// **'Invite codes work before your first match.'**
  String get inviteNotNew;

  /// No description provided for @inviteAlready.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already used an invite code.'**
  String get inviteAlready;

  /// No description provided for @inviteLoop.
  ///
  /// In en, this message translates to:
  /// **'You invited this player — you can\'t use their code.'**
  String get inviteLoop;

  /// No description provided for @inviteLimit.
  ///
  /// In en, this message translates to:
  /// **'This code has reached its limit.'**
  String get inviteLimit;

  /// No description provided for @inviteRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again tomorrow.'**
  String get inviteRateLimit;

  /// No description provided for @resultContractToast.
  ///
  /// In en, this message translates to:
  /// **'Contract complete: {name} +{coins}'**
  String resultContractToast(String name, int coins);

  /// No description provided for @resultWeeklyToast.
  ///
  /// In en, this message translates to:
  /// **'Weekly contract complete: +{coins}'**
  String resultWeeklyToast(int coins);

  /// No description provided for @resultXpGained.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String resultXpGained(int xp);

  /// No description provided for @resultClaimHint.
  ///
  /// In en, this message translates to:
  /// **'Claim them in the vault\'s Council tab.'**
  String get resultClaimHint;

  /// No description provided for @levelUpTitle.
  ///
  /// In en, this message translates to:
  /// **'You rose to {title}'**
  String levelUpTitle(String title);

  /// No description provided for @levelUpBody.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · +{coins} coins'**
  String levelUpBody(int level, int coins);

  /// No description provided for @rankTier1.
  ///
  /// In en, this message translates to:
  /// **'Newcomer'**
  String get rankTier1;

  /// No description provided for @rankTier2.
  ///
  /// In en, this message translates to:
  /// **'Informant'**
  String get rankTier2;

  /// No description provided for @rankTier3.
  ///
  /// In en, this message translates to:
  /// **'Night Watch'**
  String get rankTier3;

  /// No description provided for @rankTier4.
  ///
  /// In en, this message translates to:
  /// **'Investigator'**
  String get rankTier4;

  /// No description provided for @rankTier5.
  ///
  /// In en, this message translates to:
  /// **'Notable'**
  String get rankTier5;

  /// No description provided for @rankTier6.
  ///
  /// In en, this message translates to:
  /// **'Councillor'**
  String get rankTier6;

  /// No description provided for @rankTier7.
  ///
  /// In en, this message translates to:
  /// **'Capo'**
  String get rankTier7;

  /// No description provided for @rankTier8.
  ///
  /// In en, this message translates to:
  /// **'Consigliere'**
  String get rankTier8;

  /// No description provided for @rankTier9.
  ///
  /// In en, this message translates to:
  /// **'Council Elder'**
  String get rankTier9;

  /// No description provided for @rankTier10.
  ///
  /// In en, this message translates to:
  /// **'Godfather'**
  String get rankTier10;

  /// No description provided for @rankSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title}, level {level}'**
  String rankSemantics(String title, int level);

  /// No description provided for @bundleTitle.
  ///
  /// In en, this message translates to:
  /// **'Starter Bundle'**
  String get bundleTitle;

  /// No description provided for @bundleBody.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins + the Council Seal frame, sold nowhere else. Once per account.'**
  String bundleBody(int coins);

  /// No description provided for @bundleOwned.
  ///
  /// In en, this message translates to:
  /// **'You own the Starter Bundle'**
  String get bundleOwned;

  /// No description provided for @bundleRefundRule.
  ///
  /// In en, this message translates to:
  /// **'If it is refunded, its coins are settled like a coin pack and the Council Seal frame is removed.'**
  String get bundleRefundRule;

  /// No description provided for @bundleAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'This account already has the Starter Bundle; the extra purchase is refunded by Google Play.'**
  String get bundleAlreadyOwned;

  /// No description provided for @cosmeticFrameSeal.
  ///
  /// In en, this message translates to:
  /// **'Council Seal'**
  String get cosmeticFrameSeal;

  /// No description provided for @cosmeticFrameSealDesc.
  ///
  /// In en, this message translates to:
  /// **'A wax-red seal ring with eight gold studs — the Starter Bundle\'s own frame.'**
  String get cosmeticFrameSealDesc;

  /// No description provided for @cosmeticFrameInvite.
  ///
  /// In en, this message translates to:
  /// **'Companions Frame'**
  String get cosmeticFrameInvite;

  /// No description provided for @cosmeticFrameInviteDesc.
  ///
  /// In en, this message translates to:
  /// **'An exclusive frame earned when ten friends complete your invite conditions.'**
  String get cosmeticFrameInviteDesc;

  /// No description provided for @coinPayStep.
  ///
  /// In en, this message translates to:
  /// **'Choose a pack, then tap a payment method: its page opens. Come back here with the transfer reference.'**
  String get coinPayStep;

  /// No description provided for @coinPayWith.
  ///
  /// In en, this message translates to:
  /// **'Pay with {method}'**
  String coinPayWith(String method);

  /// No description provided for @webPassTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet Pass for the Android app'**
  String get webPassTitle;

  /// No description provided for @webPassBody.
  ///
  /// In en, this message translates to:
  /// **'The website shows no ads. The pass removes every automatic ad in the Android app (app-open, after-match and banners) on this same linked account. Optional reward ads stay available.'**
  String get webPassBody;

  /// No description provided for @webPassOwned.
  ///
  /// In en, this message translates to:
  /// **'Quiet Pass active on this account'**
  String get webPassOwned;

  /// No description provided for @coinOrderPassSummary.
  ///
  /// In en, this message translates to:
  /// **'Quiet Pass · EGP {price} · {method}'**
  String coinOrderPassSummary(String price, String method);

  /// No description provided for @awardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Match awards'**
  String get awardsTitle;

  /// No description provided for @awardMvp.
  ///
  /// In en, this message translates to:
  /// **'MVP'**
  String get awardMvp;

  /// No description provided for @awardSharpEye.
  ///
  /// In en, this message translates to:
  /// **'Sharp Eye'**
  String get awardSharpEye;

  /// No description provided for @awardSurvivor.
  ///
  /// In en, this message translates to:
  /// **'Survivor'**
  String get awardSurvivor;

  /// No description provided for @awardSilverTongue.
  ///
  /// In en, this message translates to:
  /// **'Silver Tongue'**
  String get awardSilverTongue;

  /// No description provided for @awardLifesaver.
  ///
  /// In en, this message translates to:
  /// **'Lifesaver'**
  String get awardLifesaver;

  /// No description provided for @awardPerfectCrime.
  ///
  /// In en, this message translates to:
  /// **'Perfect Crime'**
  String get awardPerfectCrime;

  /// No description provided for @awardFirstBlood.
  ///
  /// In en, this message translates to:
  /// **'First Blood'**
  String get awardFirstBlood;

  /// No description provided for @awardMvpBody.
  ///
  /// In en, this message translates to:
  /// **'The winning side\'s standout'**
  String get awardMvpBody;

  /// No description provided for @awardSharpEyeBody.
  ///
  /// In en, this message translates to:
  /// **'Most votes on the Mafia'**
  String get awardSharpEyeBody;

  /// No description provided for @awardSurvivorBody.
  ///
  /// In en, this message translates to:
  /// **'Still standing at the end'**
  String get awardSurvivorBody;

  /// No description provided for @awardSilverTongueBody.
  ///
  /// In en, this message translates to:
  /// **'Brought the table along'**
  String get awardSilverTongueBody;

  /// No description provided for @awardLifesaverBody.
  ///
  /// In en, this message translates to:
  /// **'The Doctor\'s save held'**
  String get awardLifesaverBody;

  /// No description provided for @awardPerfectCrimeBody.
  ///
  /// In en, this message translates to:
  /// **'The Mafia won untouched'**
  String get awardPerfectCrimeBody;

  /// No description provided for @awardFirstBloodBody.
  ///
  /// In en, this message translates to:
  /// **'First vote that caught the Mafia'**
  String get awardFirstBloodBody;

  /// No description provided for @awardsYouEarned.
  ///
  /// In en, this message translates to:
  /// **'Your awards: +{coins} coins'**
  String awardsYouEarned(int coins);

  /// No description provided for @awardsLoading.
  ///
  /// In en, this message translates to:
  /// **'Counting the awards'**
  String get awardsLoading;

  /// No description provided for @reactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get reactionsLabel;

  /// No description provided for @reactionLaugh.
  ///
  /// In en, this message translates to:
  /// **'Laugh'**
  String get reactionLaugh;

  /// No description provided for @reactionShock.
  ///
  /// In en, this message translates to:
  /// **'Shock'**
  String get reactionShock;

  /// No description provided for @reactionSuspicious.
  ///
  /// In en, this message translates to:
  /// **'Suspicious'**
  String get reactionSuspicious;

  /// No description provided for @reactionApplause.
  ///
  /// In en, this message translates to:
  /// **'Applause'**
  String get reactionApplause;

  /// No description provided for @reactionRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get reactionRose;

  /// No description provided for @reactionSkull.
  ///
  /// In en, this message translates to:
  /// **'Skull'**
  String get reactionSkull;

  /// No description provided for @reactionCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get reactionCoffee;

  /// No description provided for @reactionCrown.
  ///
  /// In en, this message translates to:
  /// **'Crown'**
  String get reactionCrown;

  /// No description provided for @reactionFrom.
  ///
  /// In en, this message translates to:
  /// **'{name}: {reaction}'**
  String reactionFrom(String name, String reaction);

  /// No description provided for @reactionSlowDown.
  ///
  /// In en, this message translates to:
  /// **'Easy, one at a time'**
  String get reactionSlowDown;

  /// No description provided for @cofferStripReady.
  ///
  /// In en, this message translates to:
  /// **'Today\'s coffer is ready'**
  String get cofferStripReady;

  /// No description provided for @cofferStripBody.
  ///
  /// In en, this message translates to:
  /// **'Claim it right here.'**
  String get cofferStripBody;

  /// No description provided for @cofferStripClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get cofferStripClaim;

  /// No description provided for @cofferStripGot.
  ///
  /// In en, this message translates to:
  /// **'+{amount} added to your vault'**
  String cofferStripGot(int amount);

  /// No description provided for @cofferStripSpin.
  ///
  /// In en, this message translates to:
  /// **'Spin the wheel'**
  String get cofferStripSpin;

  /// No description provided for @cofferStripLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get cofferStripLater;

  /// No description provided for @welcomeBackTitle.
  ///
  /// In en, this message translates to:
  /// **'We missed you'**
  String get welcomeBackTitle;

  /// No description provided for @welcomeBackBody.
  ///
  /// In en, this message translates to:
  /// **'Your daily coffer is waiting in the vault.'**
  String get welcomeBackBody;

  /// No description provided for @welcomeBackBodyPlain.
  ///
  /// In en, this message translates to:
  /// **'The table is ready when you are.'**
  String get welcomeBackBodyPlain;

  /// No description provided for @welcomeBackOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the vault'**
  String get welcomeBackOpen;

  /// No description provided for @welcomeBackDismiss.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get welcomeBackDismiss;

  /// No description provided for @founderBadge.
  ///
  /// In en, this message translates to:
  /// **'Founder'**
  String get founderBadge;

  /// No description provided for @founderBadgeBody.
  ///
  /// In en, this message translates to:
  /// **'One of the council\'s first players'**
  String get founderBadgeBody;

  /// No description provided for @shareCardAwards.
  ///
  /// In en, this message translates to:
  /// **'Awards: {awards}'**
  String shareCardAwards(String awards);

  /// No description provided for @adBannerLabel.
  ///
  /// In en, this message translates to:
  /// **'Advertisement'**
  String get adBannerLabel;

  /// No description provided for @adExtrasTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional extras'**
  String get adExtrasTitle;

  /// No description provided for @adExtrasBody.
  ///
  /// In en, this message translates to:
  /// **'Each is one optional ad, once a day. Nothing here affects play.'**
  String get adExtrasBody;

  /// No description provided for @adExtraSpinTitle.
  ///
  /// In en, this message translates to:
  /// **'Second spin'**
  String get adExtraSpinTitle;

  /// No description provided for @adExtraSpinBody.
  ///
  /// In en, this message translates to:
  /// **'After today\'s free spin: one more, same odds, drawn by the server.'**
  String get adExtraSpinBody;

  /// No description provided for @adExtraSpinOdds.
  ///
  /// In en, this message translates to:
  /// **'Odds: {odds}'**
  String adExtraSpinOdds(String odds);

  /// No description provided for @adExtraSpinAction.
  ///
  /// In en, this message translates to:
  /// **'Watch · spin again'**
  String get adExtraSpinAction;

  /// No description provided for @adExtraSpinNotReady.
  ///
  /// In en, this message translates to:
  /// **'Spin today\'s free wheel first.'**
  String get adExtraSpinNotReady;

  /// No description provided for @adExtraSpinResult.
  ///
  /// In en, this message translates to:
  /// **'Second spin: +{amount} coins.'**
  String adExtraSpinResult(int amount);

  /// No description provided for @adExtraCofferTitle.
  ///
  /// In en, this message translates to:
  /// **'Double today\'s coffer'**
  String get adExtraCofferTitle;

  /// No description provided for @adExtraCofferAction.
  ///
  /// In en, this message translates to:
  /// **'Watch · +{amount}'**
  String adExtraCofferAction(int amount);

  /// No description provided for @adExtraCofferNotReady.
  ///
  /// In en, this message translates to:
  /// **'Open today\'s coffer first.'**
  String get adExtraCofferNotReady;

  /// No description provided for @adExtraCofferDone.
  ///
  /// In en, this message translates to:
  /// **'Coffer doubled: +{amount}'**
  String adExtraCofferDone(int amount);

  /// No description provided for @adExtraSwapTitle.
  ///
  /// In en, this message translates to:
  /// **'Swap a contract'**
  String get adExtraSwapTitle;

  /// No description provided for @adExtraSwapBody.
  ///
  /// In en, this message translates to:
  /// **'Replace one of today\'s unclaimed contracts with another.'**
  String get adExtraSwapBody;

  /// No description provided for @adExtraSwapAction.
  ///
  /// In en, this message translates to:
  /// **'Choose · watch'**
  String get adExtraSwapAction;

  /// No description provided for @adExtraSwapPick.
  ///
  /// In en, this message translates to:
  /// **'Which contract to swap?'**
  String get adExtraSwapPick;

  /// No description provided for @adExtraSwapSlot.
  ///
  /// In en, this message translates to:
  /// **'Contract {number}'**
  String adExtraSwapSlot(int number);

  /// No description provided for @adExtraSwapDone.
  ///
  /// In en, this message translates to:
  /// **'Contract swapped'**
  String get adExtraSwapDone;

  /// No description provided for @adExtraNoneLeft.
  ///
  /// In en, this message translates to:
  /// **'Nothing to swap today.'**
  String get adExtraNoneLeft;

  /// No description provided for @adExtraUsed.
  ///
  /// In en, this message translates to:
  /// **'Used today'**
  String get adExtraUsed;

  /// No description provided for @vaultOneTime.
  ///
  /// In en, this message translates to:
  /// **'One time only'**
  String get vaultOneTime;

  /// No description provided for @vaultBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get vaultBestValue;

  /// No description provided for @vaultMostCoins.
  ///
  /// In en, this message translates to:
  /// **'Most coins'**
  String get vaultMostCoins;

  /// No description provided for @coinPickPackFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick a pack above first, then how you\'ll pay.'**
  String get coinPickPackFirst;

  /// No description provided for @adDoubleTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional bonus: double or triple this match'**
  String get adDoubleTitle;

  /// No description provided for @adDoubleAction.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad · double to {total}'**
  String adDoubleAction(int total);

  /// No description provided for @adTripleAction.
  ///
  /// In en, this message translates to:
  /// **'Another ad · triple to {total}'**
  String adTripleAction(int total);

  /// No description provided for @adDoubleDone.
  ///
  /// In en, this message translates to:
  /// **'Doubled · {total} coins'**
  String adDoubleDone(int total);

  /// No description provided for @adTripleDone.
  ///
  /// In en, this message translates to:
  /// **'Tripled · {total} coins'**
  String adTripleDone(int total);

  /// No description provided for @adTripleComplete.
  ///
  /// In en, this message translates to:
  /// **'This match now pays {total} coins.'**
  String adTripleComplete(int total);

  /// No description provided for @adDoubleDisclosure.
  ///
  /// In en, this message translates to:
  /// **'This match paid {base}. One verified ad makes it {doubled}; a second makes it {tripled}. Stopping after the first keeps the double. Your match reward stays yours either way.'**
  String adDoubleDisclosure(int base, int doubled, int tripled);

  /// No description provided for @payWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Pay with Google · {price}'**
  String payWithGoogle(String price);

  /// No description provided for @pay2TabTransfer.
  ///
  /// In en, this message translates to:
  /// **'InstaPay / Vodafone Cash'**
  String get pay2TabTransfer;

  /// No description provided for @pay2AlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'This account already has it.'**
  String get pay2AlreadyOwned;

  /// No description provided for @pay2TooMany.
  ///
  /// In en, this message translates to:
  /// **'You have two orders waiting for review. A new one opens when one is reviewed.'**
  String get pay2TooMany;

  /// No description provided for @pay2Duplicate.
  ///
  /// In en, this message translates to:
  /// **'This screenshot was already used for an order. Upload the screenshot of this transfer.'**
  String get pay2Duplicate;

  /// No description provided for @pay2ProofRequired.
  ///
  /// In en, this message translates to:
  /// **'The transfer screenshot and the sender name are both required.'**
  String get pay2ProofRequired;

  /// No description provided for @pay2StepChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose the item and how to pay'**
  String get pay2StepChoose;

  /// No description provided for @pay2StepPayHint.
  ///
  /// In en, this message translates to:
  /// **'Tapping a method opens it outside the game. Send the exact amount, then come back here.'**
  String get pay2StepPayHint;

  /// No description provided for @pay2StepPay.
  ///
  /// In en, this message translates to:
  /// **'Send exactly EGP {amount} with {method}'**
  String pay2StepPay(String amount, String method);

  /// No description provided for @pay2StepProof.
  ///
  /// In en, this message translates to:
  /// **'Come back and upload the transfer screenshot'**
  String get pay2StepProof;

  /// No description provided for @pay2PickImage.
  ///
  /// In en, this message translates to:
  /// **'Choose the transfer screenshot'**
  String get pay2PickImage;

  /// No description provided for @pay2ImageChosen.
  ///
  /// In en, this message translates to:
  /// **'Screenshot ready · change'**
  String get pay2ImageChosen;

  /// No description provided for @pay2ImageFailed.
  ///
  /// In en, this message translates to:
  /// **'That image could not be read. Try another screenshot.'**
  String get pay2ImageFailed;

  /// No description provided for @pay2SenderName.
  ///
  /// In en, this message translates to:
  /// **'Sender name exactly as shown in {method}'**
  String pay2SenderName(String method);

  /// No description provided for @pay2Submit.
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get pay2Submit;

  /// No description provided for @pay2Sent.
  ///
  /// In en, this message translates to:
  /// **'Sent. We review it by hand; coins are added once the money is confirmed.'**
  String get pay2Sent;

  /// No description provided for @pay2OrderSummary.
  ///
  /// In en, this message translates to:
  /// **'{product} · EGP {amount} · {method}'**
  String pay2OrderSummary(String product, String amount, String method);

  /// No description provided for @pay2StatusAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your transfer screenshot'**
  String get pay2StatusAwaiting;

  /// No description provided for @pay2StatusPending.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get pay2StatusPending;

  /// No description provided for @pay2StatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get pay2StatusApproved;

  /// No description provided for @pay2StatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired: not reviewed within 72 hours. If you paid, contact support with the order number.'**
  String get pay2StatusExpired;

  /// No description provided for @pay2OrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Your orders'**
  String get pay2OrdersTitle;

  /// No description provided for @pay2ReviewDetail.
  ///
  /// In en, this message translates to:
  /// **'Same price as Google Play. Orders are reviewed by hand within 72 hours; a rejected order shows the reason here.'**
  String get pay2ReviewDetail;

  /// No description provided for @pay2ProofPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The screenshot and sender name are stored privately, only to verify the order, and the screenshot is deleted 90 days after review. Nobody will ask for a PIN or code.'**
  String get pay2ProofPrivacy;

  /// No description provided for @adminPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment orders'**
  String get adminPaymentsTitle;

  /// No description provided for @adminSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in with the admin email. The email holds a one-time code or a link; opening the link in this browser signs this page in.'**
  String get adminSignInHint;

  /// No description provided for @adminSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String adminSignedInAs(String email);

  /// No description provided for @adminWebOnly.
  ///
  /// In en, this message translates to:
  /// **'The admin page is available on the website only.'**
  String get adminWebOnly;

  /// No description provided for @adminFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminFilterPending;

  /// No description provided for @adminFilterApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get adminFilterApproved;

  /// No description provided for @adminFilterRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get adminFilterRejected;

  /// No description provided for @adminFilterExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get adminFilterExpired;

  /// No description provided for @adminRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (shown to the player)'**
  String get adminRejectReason;

  /// No description provided for @adminReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Write a reason first.'**
  String get adminReasonRequired;

  /// No description provided for @adminProofGone.
  ///
  /// In en, this message translates to:
  /// **'Screenshot deleted (retention)'**
  String get adminProofGone;

  /// No description provided for @adminApproveShort.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApproveShort;

  /// No description provided for @adminRejectShort.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminRejectShort;

  /// No description provided for @adminRefundShort.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get adminRefundShort;

  /// No description provided for @adminOrderMeta.
  ///
  /// In en, this message translates to:
  /// **'{product} · EGP {amount} · {method}'**
  String adminOrderMeta(String product, String amount, String method);

  /// No description provided for @adminSender.
  ///
  /// In en, this message translates to:
  /// **'Sender: {name}'**
  String adminSender(String name);

  /// No description provided for @adminPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player: {name}'**
  String adminPlayer(String name);

  /// No description provided for @adminErrorOwned.
  ///
  /// In en, this message translates to:
  /// **'The player already owns this. Reject and return the money.'**
  String get adminErrorOwned;

  /// No description provided for @adminErrorProof.
  ///
  /// In en, this message translates to:
  /// **'This order has no screenshot.'**
  String get adminErrorProof;

  /// No description provided for @bondDossiersTitle.
  ///
  /// In en, this message translates to:
  /// **'The Four Dossiers'**
  String get bondDossiersTitle;

  /// No description provided for @bondDossiersHint.
  ///
  /// In en, this message translates to:
  /// **'They remember. You are in it.'**
  String get bondDossiersHint;

  /// No description provided for @bondCaseCount.
  ///
  /// In en, this message translates to:
  /// **'Cases {count}'**
  String bondCaseCount(int count);

  /// No description provided for @bondVictoryCount.
  ///
  /// In en, this message translates to:
  /// **'Victories {count}'**
  String bondVictoryCount(int count);

  /// No description provided for @bondWitnessCount.
  ///
  /// In en, this message translates to:
  /// **'Witnesses {count}'**
  String bondWitnessCount(int count);

  /// No description provided for @bondPersonalCount.
  ///
  /// In en, this message translates to:
  /// **'Personal {count}'**
  String bondPersonalCount(int count);

  /// No description provided for @bondLockedLine.
  ///
  /// In en, this message translates to:
  /// **'Finish a case with this character at the table.'**
  String get bondLockedLine;

  /// No description provided for @bondMafiaTier1.
  ///
  /// In en, this message translates to:
  /// **'I remember this table. It knew when to keep quiet.'**
  String get bondMafiaTier1;

  /// No description provided for @bondMafiaTier2.
  ///
  /// In en, this message translates to:
  /// **'A clean story needs fewer words than a nervous one.'**
  String get bondMafiaTier2;

  /// No description provided for @bondMafiaTier3.
  ///
  /// In en, this message translates to:
  /// **'You have learned that patience can look like innocence.'**
  String get bondMafiaTier3;

  /// No description provided for @bondMafiaTier4.
  ///
  /// In en, this message translates to:
  /// **'The room changes when you enter. That is influence.'**
  String get bondMafiaTier4;

  /// No description provided for @bondDoctorTier1.
  ///
  /// In en, this message translates to:
  /// **'Not every rescue is seen. It still counts.'**
  String get bondDoctorTier1;

  /// No description provided for @bondDoctorTier2.
  ///
  /// In en, this message translates to:
  /// **'You are beginning to hear danger before it knocks.'**
  String get bondDoctorTier2;

  /// No description provided for @bondDoctorTier3.
  ///
  /// In en, this message translates to:
  /// **'Saving the right moment matters more than saving face.'**
  String get bondDoctorTier3;

  /// No description provided for @bondDoctorTier4.
  ///
  /// In en, this message translates to:
  /// **'The table breathes easier when you keep watch.'**
  String get bondDoctorTier4;

  /// No description provided for @bondDetectiveTier1.
  ///
  /// In en, this message translates to:
  /// **'One case is enough to teach the value of doubt.'**
  String get bondDetectiveTier1;

  /// No description provided for @bondDetectiveTier2.
  ///
  /// In en, this message translates to:
  /// **'A changed story leaves a clearer print than a loud one.'**
  String get bondDetectiveTier2;

  /// No description provided for @bondDetectiveTier3.
  ///
  /// In en, this message translates to:
  /// **'You notice the pause before the answer now.'**
  String get bondDetectiveTier3;

  /// No description provided for @bondDetectiveTier4.
  ///
  /// In en, this message translates to:
  /// **'Nothing escapes you except what has not happened yet.'**
  String get bondDetectiveTier4;

  /// No description provided for @bondCitizenTier1.
  ///
  /// In en, this message translates to:
  /// **'A town survives because somebody keeps listening.'**
  String get bondCitizenTier1;

  /// No description provided for @bondCitizenTier2.
  ///
  /// In en, this message translates to:
  /// **'You have learned when the simple question is strongest.'**
  String get bondCitizenTier2;

  /// No description provided for @bondCitizenTier3.
  ///
  /// In en, this message translates to:
  /// **'The table follows facts when you hold your ground.'**
  String get bondCitizenTier3;

  /// No description provided for @bondCitizenTier4.
  ///
  /// In en, this message translates to:
  /// **'You are the memory of every room you leave behind.'**
  String get bondCitizenTier4;

  /// No description provided for @bondHomeMafia.
  ///
  /// In en, this message translates to:
  /// **'The Mafia remembers a victory nobody could stop.'**
  String get bondHomeMafia;

  /// No description provided for @bondHomeDoctor.
  ///
  /// In en, this message translates to:
  /// **'The Doctor remembers the night everyone came home.'**
  String get bondHomeDoctor;

  /// No description provided for @bondHomeDetective.
  ///
  /// In en, this message translates to:
  /// **'The Detective has kept your files. It has been a while.'**
  String get bondHomeDetective;

  /// No description provided for @bondHomeCitizen.
  ///
  /// In en, this message translates to:
  /// **'The Citizen is waiting for the table to gather again.'**
  String get bondHomeCitizen;

  /// No description provided for @bondMomentMafia.
  ///
  /// In en, this message translates to:
  /// **'The Mafia closes this file with a quiet smile.'**
  String get bondMomentMafia;

  /// No description provided for @bondMomentDoctor.
  ///
  /// In en, this message translates to:
  /// **'The Doctor counts who remained standing.'**
  String get bondMomentDoctor;

  /// No description provided for @bondMomentDetective.
  ///
  /// In en, this message translates to:
  /// **'The Detective writes the last fact in the margin.'**
  String get bondMomentDetective;

  /// No description provided for @bondMomentCitizen.
  ///
  /// In en, this message translates to:
  /// **'The Citizen keeps this case for the next gathering.'**
  String get bondMomentCitizen;

  /// No description provided for @bondTitleMafia.
  ///
  /// In en, this message translates to:
  /// **'Keeper of the Quiet Room'**
  String get bondTitleMafia;

  /// No description provided for @bondTitleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Guardian of the Last Lamp'**
  String get bondTitleDoctor;

  /// No description provided for @bondTitleDetective.
  ///
  /// In en, this message translates to:
  /// **'Reader of the Unsaid'**
  String get bondTitleDetective;

  /// No description provided for @bondTitleCitizen.
  ///
  /// In en, this message translates to:
  /// **'Memory of the Table'**
  String get bondTitleCitizen;

  /// No description provided for @bondScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'They remember. You are in it.'**
  String get bondScreenSubtitle;

  /// No description provided for @bondSealedLetter.
  ///
  /// In en, this message translates to:
  /// **'Sealed letter · opens in {count} cases'**
  String bondSealedLetter(int count);

  /// No description provided for @bondLettersTitle.
  ///
  /// In en, this message translates to:
  /// **'Letters to you'**
  String get bondLettersTitle;

  /// No description provided for @bondOpenAll.
  ///
  /// In en, this message translates to:
  /// **'All dossiers'**
  String get bondOpenAll;

  /// No description provided for @bondNewLetter.
  ///
  /// In en, this message translates to:
  /// **'A new letter from {name}'**
  String bondNewLetter(String name);

  /// No description provided for @bondStrangerLine.
  ///
  /// In en, this message translates to:
  /// **'You have not sat at this table yet.'**
  String get bondStrangerLine;

  /// No description provided for @warmupTitle.
  ///
  /// In en, this message translates to:
  /// **'Setting the table…'**
  String get warmupTitle;

  /// No description provided for @warmupOnce.
  ///
  /// In en, this message translates to:
  /// **'Just this once. Instant from now on.'**
  String get warmupOnce;

  /// No description provided for @rematchHost.
  ///
  /// In en, this message translates to:
  /// **'Another round, same table'**
  String get rematchHost;

  /// No description provided for @rematchJoin.
  ///
  /// In en, this message translates to:
  /// **'The host opened the next round · Join'**
  String get rematchJoin;

  /// No description provided for @rematchWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to open the next round…'**
  String get rematchWaiting;

  /// No description provided for @friendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// No description provided for @friendsTitleWithOnline.
  ///
  /// In en, this message translates to:
  /// **'Friends · {count} at a table now'**
  String friendsTitleWithOnline(int count);

  /// No description provided for @friendsInvitedYou.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you · Join'**
  String friendsInvitedYou(String name);

  /// No description provided for @friendsInvites.
  ///
  /// In en, this message translates to:
  /// **'Invites for you'**
  String get friendsInvites;

  /// No description provided for @friendsJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get friendsJoin;

  /// No description provided for @friendsRequests.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get friendsRequests;

  /// No description provided for @friendsWantsYou.
  ///
  /// In en, this message translates to:
  /// **'Wants to be friends'**
  String get friendsWantsYou;

  /// No description provided for @friendsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get friendsDecline;

  /// No description provided for @friendsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get friendsAccept;

  /// No description provided for @friendsYours.
  ///
  /// In en, this message translates to:
  /// **'Your friends'**
  String get friendsYours;

  /// No description provided for @friendsNone.
  ///
  /// In en, this message translates to:
  /// **'None yet. People you play online with appear below.'**
  String get friendsNone;

  /// No description provided for @friendsInLobby.
  ///
  /// In en, this message translates to:
  /// **'In a room · {count} at the table'**
  String friendsInLobby(int count);

  /// No description provided for @friendsPlaying.
  ///
  /// In en, this message translates to:
  /// **'In a match now'**
  String get friendsPlaying;

  /// No description provided for @friendsAway.
  ///
  /// In en, this message translates to:
  /// **'Not around'**
  String get friendsAway;

  /// No description provided for @friendsInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get friendsInvited;

  /// No description provided for @friendsInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get friendsInvite;

  /// No description provided for @friendsRecent.
  ///
  /// In en, this message translates to:
  /// **'Played with lately'**
  String get friendsRecent;

  /// No description provided for @friendsMatchesTogether.
  ///
  /// In en, this message translates to:
  /// **'{count} matches together'**
  String friendsMatchesTogether(int count);

  /// No description provided for @friendsPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for reply'**
  String get friendsPending;

  /// No description provided for @friendsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get friendsAdd;

  /// No description provided for @friendsInviteToRoom.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get friendsInviteToRoom;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordAgain.
  ///
  /// In en, this message translates to:
  /// **'Password again'**
  String get authPasswordAgain;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPassword;

  /// No description provided for @authPasswordRule.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get authPasswordRule;

  /// No description provided for @authShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get authShow;

  /// No description provided for @authHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get authHide;

  /// No description provided for @authCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get authCode;

  /// No description provided for @authGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authGoogle;

  /// No description provided for @authGoogleContinue.
  ///
  /// In en, this message translates to:
  /// **'Finish in the browser, then come back.'**
  String get authGoogleContinue;

  /// No description provided for @authGoogleTaken.
  ///
  /// In en, this message translates to:
  /// **'That Google account already belongs to another player. Signing in to it leaves the guest profile on this device.'**
  String get authGoogleTaken;

  /// No description provided for @authGoogleUseExisting.
  ///
  /// In en, this message translates to:
  /// **'Sign in with that Google account'**
  String get authGoogleUseExisting;

  /// No description provided for @authGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your account with you'**
  String get authGuestTitle;

  /// No description provided for @authGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Your coins, items, rank and friends follow you to any phone. You can keep playing as a guest.'**
  String get authGuestBody;

  /// No description provided for @authCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreate;

  /// No description provided for @authCreateBody.
  ///
  /// In en, this message translates to:
  /// **'Everything you have now moves into the account as it is.'**
  String get authCreateBody;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I have an account · Sign in'**
  String get authHaveAccount;

  /// No description provided for @authSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authSendCode;

  /// No description provided for @authVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get authVerifyTitle;

  /// No description provided for @authVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}. Type it here or open the link in the email.'**
  String authVerifyBody(String email);

  /// No description provided for @authVerify.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get authVerify;

  /// No description provided for @authResend.
  ///
  /// In en, this message translates to:
  /// **'Send the code again'**
  String get authResend;

  /// No description provided for @authResendIn.
  ///
  /// In en, this message translates to:
  /// **'Send again in {seconds}s'**
  String authResendIn(int seconds);

  /// No description provided for @authResent.
  ///
  /// In en, this message translates to:
  /// **'Sent again.'**
  String get authResent;

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome. Your account is ready.'**
  String get authWelcome;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSignInBody.
  ///
  /// In en, this message translates to:
  /// **'You will be in your account; this device\'s guest progress does not move to it.'**
  String get authSignInBody;

  /// No description provided for @authRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get authRemember;

  /// No description provided for @authForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgot;

  /// No description provided for @authForgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we\'ll send a code to set a new password.'**
  String get authForgotBody;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authResetTitle;

  /// No description provided for @authResetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get authResetSave;

  /// No description provided for @authPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get authPasswordChanged;

  /// No description provided for @authChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get authChangePassword;

  /// No description provided for @authSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get authSetPassword;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @authVerified.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed'**
  String get authVerified;

  /// No description provided for @authViaGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get authViaGoogle;

  /// No description provided for @authViaPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authViaPassword;

  /// No description provided for @authSafe.
  ///
  /// In en, this message translates to:
  /// **'Your account is saved. On a new phone, sign in and everything comes back.'**
  String get authSafe;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'The password needs at least 8 characters.'**
  String get authWeakPassword;

  /// No description provided for @authWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Email or password is not right.'**
  String get authWrongPassword;

  /// No description provided for @authNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'That email isn\'t confirmed yet. Check the code we sent.'**
  String get authNotConfirmed;

  /// No description provided for @authSamePassword.
  ///
  /// In en, this message translates to:
  /// **'That is the same password as before.'**
  String get authSamePassword;

  /// No description provided for @authMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords don\'t match.'**
  String get authMismatch;

  /// No description provided for @authProviderOff.
  ///
  /// In en, this message translates to:
  /// **'That way in isn\'t available right now.'**
  String get authProviderOff;

  /// No description provided for @authAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get authAccount;

  /// No description provided for @authGuestBadge.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get authGuestBadge;

  /// No description provided for @authManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get authManage;

  /// No description provided for @profileStatMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get profileStatMatches;

  /// No description provided for @profileStatOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get profileStatOnline;

  /// No description provided for @profileStatLetters.
  ///
  /// In en, this message translates to:
  /// **'Character letters'**
  String get profileStatLetters;

  /// No description provided for @casebookTitle.
  ///
  /// In en, this message translates to:
  /// **'The Casebook'**
  String get casebookTitle;

  /// No description provided for @casebookTonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get casebookTonight;

  /// No description provided for @casebookSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get casebookSeason;

  /// No description provided for @casebookLegacy.
  ///
  /// In en, this message translates to:
  /// **'Legacy'**
  String get casebookLegacy;

  /// No description provided for @casebookDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{The season closes today} =1{1 day left in the season} other{{n} days left in the season}}'**
  String casebookDaysLeft(int n);

  /// No description provided for @casebookWeekly.
  ///
  /// In en, this message translates to:
  /// **'Case of the week'**
  String get casebookWeekly;

  /// No description provided for @casebookBonus.
  ///
  /// In en, this message translates to:
  /// **'Close all three for more'**
  String get casebookBonus;

  /// No description provided for @casebookBonusTaken.
  ///
  /// In en, this message translates to:
  /// **'Every case closed today'**
  String get casebookBonusTaken;

  /// No description provided for @casebookFrom.
  ///
  /// In en, this message translates to:
  /// **'From the {name}'**
  String casebookFrom(String name);

  /// No description provided for @casebookClaim.
  ///
  /// In en, this message translates to:
  /// **'Take it'**
  String get casebookClaim;

  /// No description provided for @casebookClaimed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get casebookClaimed;

  /// No description provided for @casebookClaimError.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Try again'**
  String get casebookClaimError;

  /// No description provided for @casebookLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String casebookLevel(int n);

  /// No description provided for @casebookXp.
  ///
  /// In en, this message translates to:
  /// **'{xp} / {next}'**
  String casebookXp(int xp, int next);

  /// No description provided for @casebookXpGain.
  ///
  /// In en, this message translates to:
  /// **'+{n} XP'**
  String casebookXpGain(int n);

  /// No description provided for @casebookSeasonDone.
  ///
  /// In en, this message translates to:
  /// **'Season complete'**
  String get casebookSeasonDone;

  /// No description provided for @casebookTitleReward.
  ///
  /// In en, this message translates to:
  /// **'New title'**
  String get casebookTitleReward;

  /// No description provided for @casebookItemReward.
  ///
  /// In en, this message translates to:
  /// **'New cosmetic'**
  String get casebookItemReward;

  /// No description provided for @casebookRank.
  ///
  /// In en, this message translates to:
  /// **'Council rank {n}'**
  String casebookRank(int n);

  /// No description provided for @casebookAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get casebookAchievements;

  /// No description provided for @casebookReady.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 reward to take} other{{n} rewards to take}}'**
  String casebookReady(int n);

  /// No description provided for @casebookFailed.
  ///
  /// In en, this message translates to:
  /// **'The casebook can\'t open right now'**
  String get casebookFailed;

  /// No description provided for @casebookRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get casebookRetry;

  /// No description provided for @casebookResult.
  ///
  /// In en, this message translates to:
  /// **'Your casebook moved · open it'**
  String get casebookResult;

  /// No description provided for @caseFinish.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Finish an online match} other{Finish {n} online matches}}'**
  String caseFinish(int n);

  /// No description provided for @caseWin.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Win a match} other{Win {n} matches}}'**
  String caseWin(int n);

  /// No description provided for @caseHost.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Host a table to the end} other{Host {n} tables to the end}}'**
  String caseHost(int n);

  /// No description provided for @caseReunion.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Play again with someone you\'ve sat with} other{Play again with {n} people you\'ve sat with}}'**
  String caseReunion(int n);

  /// No description provided for @casePublic.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Sit at a public table} other{Sit at {n} public tables}}'**
  String casePublic(int n);

  /// No description provided for @caseInvite.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Bring a friend to play} other{Bring {n} friends to play}}'**
  String caseInvite(int n);

  /// No description provided for @caseStreak.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Play today} other{Play {n} days in a row}}'**
  String caseStreak(int n);

  /// No description provided for @caseDailies.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Close a full day of cases} other{Close {n} full days of cases}}'**
  String caseDailies(int n);

  /// No description provided for @caseLevel.
  ///
  /// In en, this message translates to:
  /// **'Reach season level {n}'**
  String caseLevel(int n);

  /// No description provided for @casebookProgress.
  ///
  /// In en, this message translates to:
  /// **'{progress} of {target}'**
  String casebookProgress(int progress, int target);

  /// No description provided for @onlineRoomUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This table isn\'t available to you.'**
  String get onlineRoomUnavailable;

  /// No description provided for @onlineNameNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'That name isn\'t allowed. Pick another one.'**
  String get onlineNameNotAllowed;

  /// No description provided for @onlineAccountRestricted.
  ///
  /// In en, this message translates to:
  /// **'Your account can\'t join this right now.'**
  String get onlineAccountRestricted;

  /// No description provided for @safetyCategory.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get safetyCategory;

  /// No description provided for @safetyCatHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get safetyCatHarassment;

  /// No description provided for @safetyCatHate.
  ///
  /// In en, this message translates to:
  /// **'Hate or racism'**
  String get safetyCatHate;

  /// No description provided for @safetyCatSexual.
  ///
  /// In en, this message translates to:
  /// **'Sexual content'**
  String get safetyCatSexual;

  /// No description provided for @safetyCatThreat.
  ///
  /// In en, this message translates to:
  /// **'Threat'**
  String get safetyCatThreat;

  /// No description provided for @safetyCatSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get safetyCatSpam;

  /// No description provided for @safetyCatCheating.
  ///
  /// In en, this message translates to:
  /// **'Cheating'**
  String get safetyCatCheating;

  /// No description provided for @safetyCatName.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate name'**
  String get safetyCatName;

  /// No description provided for @safetyCatOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get safetyCatOther;

  /// No description provided for @safetyLimited.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s limit.'**
  String get safetyLimited;

  /// No description provided for @safetyNoticeWarn.
  ///
  /// In en, this message translates to:
  /// **'You were reported and warned. Keep the table fair and kind.'**
  String get safetyNoticeWarn;

  /// No description provided for @safetyNoticeVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice is off for your account.'**
  String get safetyNoticeVoice;

  /// No description provided for @safetyNoticePublic.
  ///
  /// In en, this message translates to:
  /// **'Public tables are closed to your account.'**
  String get safetyNoticePublic;

  /// No description provided for @safetyNoticeSuspend.
  ///
  /// In en, this message translates to:
  /// **'Online play is closed to your account.'**
  String get safetyNoticeSuspend;

  /// No description provided for @safetyNoticeUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}.'**
  String safetyNoticeUntil(String date);

  /// No description provided for @safetyNoticeForever.
  ///
  /// In en, this message translates to:
  /// **'Permanently.'**
  String get safetyNoticeForever;

  /// No description provided for @safetyNoticeOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get safetyNoticeOk;

  /// No description provided for @adminSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminSafetyTitle;

  /// No description provided for @adminSafetyOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get adminSafetyOpen;

  /// No description provided for @adminSafetyActioned.
  ///
  /// In en, this message translates to:
  /// **'Actioned'**
  String get adminSafetyActioned;

  /// No description provided for @adminSafetyDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get adminSafetyDismissed;

  /// No description provided for @adminSafetyCtxLobby.
  ///
  /// In en, this message translates to:
  /// **'Lobby'**
  String get adminSafetyCtxLobby;

  /// No description provided for @adminSafetyCtxMatch.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get adminSafetyCtxMatch;

  /// No description provided for @adminSafetyCtxResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get adminSafetyCtxResult;

  /// No description provided for @adminSafetyCtxFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get adminSafetyCtxFriends;

  /// No description provided for @adminSafetyTarget.
  ///
  /// In en, this message translates to:
  /// **'{name} · {open} open · {actioned} actioned'**
  String adminSafetyTarget(String name, int open, int actioned);

  /// No description provided for @adminSafetyDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get adminSafetyDismiss;

  /// No description provided for @adminSafetyWarn.
  ///
  /// In en, this message translates to:
  /// **'Warn'**
  String get adminSafetyWarn;

  /// No description provided for @adminSafetyNoVoice.
  ///
  /// In en, this message translates to:
  /// **'No voice, 7 days'**
  String get adminSafetyNoVoice;

  /// No description provided for @adminSafetyNoPublic.
  ///
  /// In en, this message translates to:
  /// **'No public tables, 7 days'**
  String get adminSafetyNoPublic;

  /// No description provided for @adminSafetySuspendDays.
  ///
  /// In en, this message translates to:
  /// **'Suspend {days} days'**
  String adminSafetySuspendDays(int days);

  /// No description provided for @adminSafetySuspendForever.
  ///
  /// In en, this message translates to:
  /// **'Suspend permanently'**
  String get adminSafetySuspendForever;

  /// No description provided for @adminSafetyPurge.
  ///
  /// In en, this message translates to:
  /// **'Apply retention now'**
  String get adminSafetyPurge;

  /// No description provided for @adminSafetyMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get adminSafetyMore;

  /// No description provided for @adminSafetyOpenQueue.
  ///
  /// In en, this message translates to:
  /// **'Reports queue'**
  String get adminSafetyOpenQueue;

  /// No description provided for @witnessWhispersTitle.
  ///
  /// In en, this message translates to:
  /// **'Whispers'**
  String get witnessWhispersTitle;

  /// No description provided for @witnessWhisperLine.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String witnessWhisperLine(String from, String to);

  /// No description provided for @witnessWhisperMasked.
  ///
  /// In en, this message translates to:
  /// **'Hidden: you blocked the sender.'**
  String get witnessWhisperMasked;

  /// No description provided for @witnessWhisperReport.
  ///
  /// In en, this message translates to:
  /// **'Report this whisper'**
  String get witnessWhisperReport;

  /// No description provided for @witnessWhispersDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Players who are out can read the whispers.'**
  String get witnessWhispersDisclosure;

  /// No description provided for @thursdayNight.
  ///
  /// In en, this message translates to:
  /// **'Thursday Night'**
  String get thursdayNight;

  /// No description provided for @thursdayProgress.
  ///
  /// In en, this message translates to:
  /// **'Matches: {count}/2'**
  String thursdayProgress(int count);

  /// No description provided for @thursdayLine.
  ///
  /// In en, this message translates to:
  /// **'Every Thursday from 8 PM: two matches here = 40 season points and a stamp.'**
  String get thursdayLine;

  /// No description provided for @thursdayOpensLater.
  ///
  /// In en, this message translates to:
  /// **'Opens at 8 PM'**
  String get thursdayOpensLater;

  /// No description provided for @thursdayOpenRoom.
  ///
  /// In en, this message translates to:
  /// **'Open a Thursday room'**
  String get thursdayOpenRoom;

  /// No description provided for @thursdayJoinRoom.
  ///
  /// In en, this message translates to:
  /// **'Join the Thursday room'**
  String get thursdayJoinRoom;

  /// No description provided for @thursdayDone.
  ///
  /// In en, this message translates to:
  /// **'Thursday stamp earned. Play on as usual.'**
  String get thursdayDone;

  /// No description provided for @lobbyReadyAction.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get lobbyReadyAction;

  /// No description provided for @lobbyUnreadyAction.
  ///
  /// In en, this message translates to:
  /// **'Not ready'**
  String get lobbyUnreadyAction;

  /// No description provided for @lobbyReadyCount.
  ///
  /// In en, this message translates to:
  /// **'{ready} of {total} ready'**
  String lobbyReadyCount(int ready, int total);

  /// No description provided for @witnessSeatQuiet.
  ///
  /// In en, this message translates to:
  /// **'Nothing has touched this seat yet'**
  String get witnessSeatQuiet;

  /// No description provided for @witnessNightTitle.
  ///
  /// In en, this message translates to:
  /// **'At night'**
  String get witnessNightTitle;

  /// No description provided for @witnessWhisperReported.
  ///
  /// In en, this message translates to:
  /// **'Report received'**
  String get witnessWhisperReported;

  /// No description provided for @witnessManageSeat.
  ///
  /// In en, this message translates to:
  /// **'Manage seat'**
  String get witnessManageSeat;

  /// No description provided for @witnessLetterOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the whisper'**
  String get witnessLetterOpen;

  /// No description provided for @onlineWeatherRetry.
  ///
  /// In en, this message translates to:
  /// **'Try now'**
  String get onlineWeatherRetry;

  /// No description provided for @xpUnit.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get xpUnit;

  /// No description provided for @inviteFirstMatchNotice.
  ///
  /// In en, this message translates to:
  /// **'{name} played their first match — you got {coins} coins'**
  String inviteFirstMatchNotice(String name, int coins);

  /// No description provided for @inviteProgressNotice.
  ///
  /// In en, this message translates to:
  /// **'Your friend played {count} of 3'**
  String inviteProgressNotice(int count);

  /// No description provided for @inviteSettledNotice.
  ///
  /// In en, this message translates to:
  /// **'{name} finished three matches — you got {coins} coins'**
  String inviteSettledNotice(String name, int coins);

  /// No description provided for @inviteSettledCounter.
  ///
  /// In en, this message translates to:
  /// **'Settled invites: {season}/{seasonCap} this season · {lifetime}/{lifetimeCap} all time'**
  String inviteSettledCounter(
    int season,
    int seasonCap,
    int lifetime,
    int lifetimeCap,
  );

  /// No description provided for @inviteNoticeFriend.
  ///
  /// In en, this message translates to:
  /// **'Your friend'**
  String get inviteNoticeFriend;

  /// No description provided for @partnerDetective.
  ///
  /// In en, this message translates to:
  /// **'Detective'**
  String get partnerDetective;

  /// No description provided for @partnerDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get partnerDoctor;

  /// No description provided for @partnerMafia.
  ///
  /// In en, this message translates to:
  /// **'Mafia'**
  String get partnerMafia;

  /// No description provided for @partnerCitizen.
  ///
  /// In en, this message translates to:
  /// **'Citizen'**
  String get partnerCitizen;

  /// No description provided for @partnerBusy.
  ///
  /// In en, this message translates to:
  /// **'You can change your partner after the match'**
  String get partnerBusy;

  /// No description provided for @titlesNone.
  ///
  /// In en, this message translates to:
  /// **'No titles yet — they come from the season and invites'**
  String get titlesNone;

  /// No description provided for @titlesUnequip.
  ///
  /// In en, this message translates to:
  /// **'No title'**
  String get titlesUnequip;

  /// No description provided for @passInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'You still have rewards today'**
  String get passInventoryTitle;

  /// No description provided for @passInventoryDailyAd.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rewarded ad'**
  String get passInventoryDailyAd;

  /// No description provided for @passInventoryExtraSpin.
  ///
  /// In en, this message translates to:
  /// **'An extra wheel spin'**
  String get passInventoryExtraSpin;

  /// No description provided for @passInventoryExtraCoffer.
  ///
  /// In en, this message translates to:
  /// **'An extra coffer'**
  String get passInventoryExtraCoffer;

  /// No description provided for @passInventoryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open rewards'**
  String get passInventoryOpen;

  /// No description provided for @profilePlatePreview.
  ///
  /// In en, this message translates to:
  /// **'Your name shows as:'**
  String get profilePlatePreview;

  /// No description provided for @storeRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'It\'s yours'**
  String get storeRevealTitle;

  /// No description provided for @storeEquipNow.
  ///
  /// In en, this message translates to:
  /// **'Wear it now'**
  String get storeEquipNow;

  /// No description provided for @storeEquipLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get storeEquipLater;

  /// No description provided for @storeRevealDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get storeRevealDone;

  /// No description provided for @storeChangesFrame.
  ///
  /// In en, this message translates to:
  /// **'Shows around your portrait at the table, on your profile, for your friends and on the Council board'**
  String get storeChangesFrame;

  /// No description provided for @storeChangesPlate.
  ///
  /// In en, this message translates to:
  /// **'Your name shows on it at the table, on your profile, for your friends and on the result'**
  String get storeChangesPlate;

  /// No description provided for @storeChangesPack.
  ///
  /// In en, this message translates to:
  /// **'Dresses rooms you host: the public phases\' backdrop and transitions, online and in pass-and-play'**
  String get storeChangesPack;

  /// No description provided for @storeChangesNarrator.
  ///
  /// In en, this message translates to:
  /// **'The narrator\'s recorded voice, lines and look at every public phase, online and in pass-and-play'**
  String get storeChangesNarrator;

  /// No description provided for @storeChangesBundle.
  ///
  /// In en, this message translates to:
  /// **'Everything in it is yours; wear any part from your collection'**
  String get storeChangesBundle;

  /// No description provided for @storeTryOn.
  ///
  /// In en, this message translates to:
  /// **'Try it on'**
  String get storeTryOn;

  /// No description provided for @storeWearing.
  ///
  /// In en, this message translates to:
  /// **'Wearing now'**
  String get storeWearing;

  /// No description provided for @titlesHeading.
  ///
  /// In en, this message translates to:
  /// **'Your titles'**
  String get titlesHeading;

  /// No description provided for @partnerCasebookLine.
  ///
  /// In en, this message translates to:
  /// **'{who}: every case you close is written here'**
  String partnerCasebookLine(String who);

  /// No description provided for @lobbyReadyCountdown.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s left to confirm you\'re ready'**
  String lobbyReadyCountdown(int seconds);

  /// No description provided for @inviteSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite players'**
  String get inviteSheetTitle;

  /// No description provided for @inviteTabFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get inviteTabFriends;

  /// No description provided for @inviteTabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get inviteTabSearch;

  /// No description provided for @inviteTabNearby.
  ///
  /// In en, this message translates to:
  /// **'People near you'**
  String get inviteTabNearby;

  /// No description provided for @inviteSend.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get inviteSend;

  /// No description provided for @inviteSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get inviteSent;

  /// No description provided for @inviteFailed.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t go through, try again'**
  String get inviteFailed;

  /// No description provided for @inviteSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Type a name or @username'**
  String get inviteSearchHint;

  /// No description provided for @inviteSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody by that name'**
  String get inviteSearchEmpty;

  /// No description provided for @inviteSearchShort.
  ///
  /// In en, this message translates to:
  /// **'Type at least two letters'**
  String get inviteSearchShort;

  /// No description provided for @inviteNearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody here right now'**
  String get inviteNearbyEmpty;

  /// No description provided for @inviteFriendsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friends yet — search by name'**
  String get inviteFriendsEmpty;

  /// No description provided for @inviteFilterNear.
  ///
  /// In en, this message translates to:
  /// **'Near you'**
  String get inviteFilterNear;

  /// No description provided for @inviteFilterOnline.
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get inviteFilterOnline;

  /// No description provided for @inviteFilterPlayed.
  ///
  /// In en, this message translates to:
  /// **'Played with'**
  String get inviteFilterPlayed;

  /// No description provided for @inviteFilterLevel.
  ///
  /// In en, this message translates to:
  /// **'Your level'**
  String get inviteFilterLevel;

  /// No description provided for @inviteStateOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get inviteStateOnline;

  /// No description provided for @inviteStateLobby.
  ///
  /// In en, this message translates to:
  /// **'In a lobby'**
  String get inviteStateLobby;

  /// No description provided for @inviteStatePlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get inviteStatePlaying;

  /// No description provided for @inviteStateAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get inviteStateAway;

  /// No description provided for @inviteLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String inviteLevel(int level);

  /// No description provided for @inviteMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get inviteMore;

  /// No description provided for @inviteIncomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Game invite'**
  String get inviteIncomingTitle;

  /// No description provided for @inviteIncomingBody.
  ///
  /// In en, this message translates to:
  /// **'{name} invites you to play together'**
  String inviteIncomingBody(String name);

  /// No description provided for @inviteIncomingCode.
  ///
  /// In en, this message translates to:
  /// **'Room {code}'**
  String inviteIncomingCode(String code);

  /// No description provided for @inviteEnter.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get inviteEnter;

  /// No description provided for @inviteLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get inviteLater;

  /// No description provided for @inviteRoomGone.
  ///
  /// In en, this message translates to:
  /// **'That room already started or closed'**
  String get inviteRoomGone;

  /// No description provided for @profileHandleLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileHandleLabel;

  /// No description provided for @profileHandleHint.
  ///
  /// In en, this message translates to:
  /// **'3–20 letters, digits or _'**
  String get profileHandleHint;

  /// No description provided for @profileHandleSave.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get profileHandleSave;

  /// No description provided for @profileHandleTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is taken'**
  String get profileHandleTaken;

  /// No description provided for @profileHandleWait.
  ///
  /// In en, this message translates to:
  /// **'You can change it again later'**
  String get profileHandleWait;

  /// No description provided for @profileHandleRefused.
  ///
  /// In en, this message translates to:
  /// **'That username isn\'t allowed'**
  String get profileHandleRefused;

  /// No description provided for @profileHandleInvalid.
  ///
  /// In en, this message translates to:
  /// **'Letters, digits or _ only, 3 to 20'**
  String get profileHandleInvalid;

  /// No description provided for @profileHideFromSearch.
  ///
  /// In en, this message translates to:
  /// **'Hide me from search'**
  String get profileHideFromSearch;

  /// No description provided for @profileMuteStrangers.
  ///
  /// In en, this message translates to:
  /// **'No invites from people who aren\'t friends'**
  String get profileMuteStrangers;

  /// No description provided for @pushChannelInvites.
  ///
  /// In en, this message translates to:
  /// **'Game invites'**
  String get pushChannelInvites;

  /// No description provided for @pushChannelInvitesDesc.
  ///
  /// In en, this message translates to:
  /// **'When someone invites you to their room'**
  String get pushChannelInvitesDesc;

  /// No description provided for @pushChannelSocial.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get pushChannelSocial;

  /// No description provided for @pushChannelSocialDesc.
  ///
  /// In en, this message translates to:
  /// **'Friend requests and accepted requests'**
  String get pushChannelSocialDesc;

  /// No description provided for @revealWhispersNotice.
  ///
  /// In en, this message translates to:
  /// **'In this room, whispers are shown to everyone after the match'**
  String get revealWhispersNotice;

  /// No description provided for @revealWhispersButton.
  ///
  /// In en, this message translates to:
  /// **'Whispers'**
  String get revealWhispersButton;

  /// No description provided for @revealWhispersTitle.
  ///
  /// In en, this message translates to:
  /// **'The match\'s whispers'**
  String get revealWhispersTitle;

  /// No description provided for @revealWhispersEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody whispered this match'**
  String get revealWhispersEmpty;

  /// No description provided for @revealWhispersMasked.
  ///
  /// In en, this message translates to:
  /// **'A whisper from a player you blocked'**
  String get revealWhispersMasked;

  /// No description provided for @revealWhispersFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the whispers'**
  String get revealWhispersFailed;

  /// No description provided for @onboardAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your progress?'**
  String get onboardAccountTitle;

  /// No description provided for @onboardAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google or email so your coins, rank and friends follow you to any phone. Or continue without signing in; you can link an account later from your profile without losing anything.'**
  String get onboardAccountHint;

  /// No description provided for @onboardAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in (Google or email)'**
  String get onboardAccountSignIn;

  /// No description provided for @onboardAccountGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue without signing in'**
  String get onboardAccountGuest;

  /// No description provided for @onboardAccountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String onboardAccountSignedIn(String email);

  /// No description provided for @onboardAccountSignedInPlain.
  ///
  /// In en, this message translates to:
  /// **'You are signed in'**
  String get onboardAccountSignedInPlain;

  /// No description provided for @deleteAccountRow.
  ///
  /// In en, this message translates to:
  /// **'Delete my account and data'**
  String get deleteAccountRow;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'We will erase your account, coins, items, rank, friends and all your online data from the server, and it cannot be brought back. What is on your phone (old match history) stays there; clear it from the app\'s data in your phone settings.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountKept.
  ///
  /// In en, this message translates to:
  /// **'Abuse reports that are still needed and payment records are kept for a limited time, no longer tied to your account.'**
  String get deleteAccountKept;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'I understand this is final'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get deleteAccountAction;

  /// No description provided for @deleteAccountCancel.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get deleteAccountCancel;

  /// No description provided for @deleteAccountDone.
  ///
  /// In en, this message translates to:
  /// **'Your account and data were deleted'**
  String get deleteAccountDone;

  /// No description provided for @deleteAccountDoneHint.
  ///
  /// In en, this message translates to:
  /// **'If you go online again you start as a new player.'**
  String get deleteAccountDoneHint;

  /// No description provided for @deleteAccountInRoom.
  ///
  /// In en, this message translates to:
  /// **'You are still in a room. Leave it first, then delete your account.'**
  String get deleteAccountInRoom;

  /// No description provided for @deleteAccountOrder.
  ///
  /// In en, this message translates to:
  /// **'A payment of yours is still under review. Wait until it is closed, then delete your account.'**
  String get deleteAccountOrder;

  /// No description provided for @deleteAccountWebTitle.
  ///
  /// In en, this message translates to:
  /// **'Or ask for deletion on the website'**
  String get deleteAccountWebTitle;

  /// No description provided for @deleteAccountWebOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the data deletion page'**
  String get deleteAccountWebOpen;

  /// No description provided for @deleteAccountWebCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get deleteAccountWebCopied;

  /// No description provided for @accountLegalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and privacy'**
  String get accountLegalTitle;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server right now. Check your connection and try again.'**
  String get errOffline;

  /// No description provided for @errRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get errRetry;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests too fast. Wait a little and try again.'**
  String get errRateLimited;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Try again in a moment.'**
  String get errGeneric;

  /// No description provided for @errSession.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Close the game and open it again.'**
  String get errSession;

  /// No description provided for @errCoins.
  ///
  /// In en, this message translates to:
  /// **'You do not have enough coins.'**
  String get errCoins;

  /// No description provided for @errUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This is not available right now. Try again later.'**
  String get errUnavailable;

  /// No description provided for @errNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You cannot do that right now.'**
  String get errNotAllowed;

  /// No description provided for @errNotHost.
  ///
  /// In en, this message translates to:
  /// **'Only the host can do that.'**
  String get errNotHost;

  /// No description provided for @errAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'You already have this.'**
  String get errAlreadyOwned;

  /// No description provided for @errInRoom.
  ///
  /// In en, this message translates to:
  /// **'You are still in a room. Leave it first.'**
  String get errInRoom;

  /// No description provided for @errOrderOpen.
  ///
  /// In en, this message translates to:
  /// **'You still have a payment order open.'**
  String get errOrderOpen;

  /// No description provided for @errPurchaseRequired.
  ///
  /// In en, this message translates to:
  /// **'This needs a purchase first.'**
  String get errPurchaseRequired;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update the app'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'There is a newer version of the game and you need to update to keep playing. This version will not work any more.'**
  String get updateRequiredBody;

  /// No description provided for @updateRequiredStore.
  ///
  /// In en, this message translates to:
  /// **'Open Google Play'**
  String get updateRequiredStore;

  /// No description provided for @updateRequiredReload.
  ///
  /// In en, this message translates to:
  /// **'Reload the page'**
  String get updateRequiredReload;

  /// No description provided for @webAdAppCta.
  ///
  /// In en, this message translates to:
  /// **'Download the app — fewer ads'**
  String get webAdAppCta;

  /// No description provided for @webAdPlayCaption.
  ///
  /// In en, this message translates to:
  /// **'Mafia Master on Google Play'**
  String get webAdPlayCaption;

  /// No description provided for @webAdCouncilTitle.
  ///
  /// In en, this message translates to:
  /// **'The Council and vault await'**
  String get webAdCouncilTitle;

  /// No description provided for @webAdPlayBody.
  ///
  /// In en, this message translates to:
  /// **'Play with friends on Android with fewer ads.'**
  String get webAdPlayBody;

  /// No description provided for @webAdCouncilBody.
  ///
  /// In en, this message translates to:
  /// **'Collect coins and unlock a new look for the table.'**
  String get webAdCouncilBody;

  /// No description provided for @webAdOpenPlay.
  ///
  /// In en, this message translates to:
  /// **'Open Google Play'**
  String get webAdOpenPlay;

  /// No description provided for @webAdContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue playing'**
  String get webAdContinue;

  /// No description provided for @webAdCountdown.
  ///
  /// In en, this message translates to:
  /// **'You can close this ad in a moment'**
  String get webAdCountdown;
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
