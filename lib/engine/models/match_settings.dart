import 'enums.dart';

/// Settings that customize a match's behavior.
/// Reference: data-model.md §4
class MatchSettings {
  final int speechSeconds;
  final DiscussionMode discussionMode;
  final DayTieRule dayTieRule;
  final bool narrationEnabled;
  final bool abstainAllowed;

  /// The continuous score — one loop, running for the whole match.
  ///
  /// Separate from [muteAllAudio] because it is a separate taste: some tables
  /// want the cues and no bed, some want the bed and nothing else. Under a
  /// master mute neither plays.
  final bool scoreEnabled;

  /// Master mute. When true the app makes no sound at all.
  ///
  /// Independent of [narrationEnabled], which only silences the spoken lines.
  /// Nothing in the game depends on hearing anything: every announcement puts
  /// its own words on screen, and no cue has ever been allowed to fire while
  /// the phone is in a hand.
  final bool muteAllAudio;

  /// How long a player must hold the identity pad before their card appears.
  ///
  /// This is not a fidget gate. It is the turn-length equaliser: the hold runs
  /// for the same number of seconds whatever the player drew, so the time a
  /// person spends with the phone says nothing about their role (L-08). It is
  /// also what confirms the right person is holding it — long enough that a
  /// phone handed to the wrong seat gets noticed and handed back.
  ///
  /// **Five seconds, not twenty.** Twenty was tried on a real table and is far
  /// too long: it is the single gate every player passes through before every
  /// card, so it multiplies by the size of the table, and a hold that outlasts
  /// the holder's patience gets released early and re-tried, which defeats the
  /// point. Five is long enough to be deliberate.
  final int identityHoldSeconds;

  const MatchSettings({
    this.speechSeconds = 60,
    this.discussionMode = DiscussionMode.structured,
    this.dayTieRule = DayTieRule.revote,
    this.narrationEnabled = true,
    this.abstainAllowed = false,
    this.identityHoldSeconds = 5,
    this.muteAllAudio = false,
    this.scoreEnabled = true,
  });

  /// Default settings constructor.
  const MatchSettings.defaults()
      : speechSeconds = 60,
        discussionMode = DiscussionMode.structured,
        dayTieRule = DayTieRule.revote,
        narrationEnabled = true,
        abstainAllowed = false,
        identityHoldSeconds = 5,
        muteAllAudio = false,
        scoreEnabled = true;

  /// Create a copy with optional field overrides.
  MatchSettings copyWith({
    int? speechSeconds,
    DiscussionMode? discussionMode,
    DayTieRule? dayTieRule,
    bool? narrationEnabled,
    bool? abstainAllowed,
    int? identityHoldSeconds,
    bool? muteAllAudio,
    bool? scoreEnabled,
  }) =>
      MatchSettings(
        speechSeconds: speechSeconds ?? this.speechSeconds,
        discussionMode: discussionMode ?? this.discussionMode,
        dayTieRule: dayTieRule ?? this.dayTieRule,
        narrationEnabled: narrationEnabled ?? this.narrationEnabled,
        abstainAllowed: abstainAllowed ?? this.abstainAllowed,
        identityHoldSeconds: identityHoldSeconds ?? this.identityHoldSeconds,
        muteAllAudio: muteAllAudio ?? this.muteAllAudio,
        scoreEnabled: scoreEnabled ?? this.scoreEnabled,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchSettings &&
          runtimeType == other.runtimeType &&
          speechSeconds == other.speechSeconds &&
          discussionMode == other.discussionMode &&
          dayTieRule == other.dayTieRule &&
          narrationEnabled == other.narrationEnabled &&
          abstainAllowed == other.abstainAllowed &&
          identityHoldSeconds == other.identityHoldSeconds &&
          muteAllAudio == other.muteAllAudio &&
          scoreEnabled == other.scoreEnabled;

  @override
  int get hashCode =>
      speechSeconds.hashCode ^
      discussionMode.hashCode ^
      dayTieRule.hashCode ^
      narrationEnabled.hashCode ^
      abstainAllowed.hashCode ^
      identityHoldSeconds.hashCode ^
      muteAllAudio.hashCode ^
      scoreEnabled.hashCode;

  @override
  String toString() =>
      'MatchSettings(speechSeconds=$speechSeconds, discussionMode=$discussionMode, '
      'dayTieRule=$dayTieRule, narrationEnabled=$narrationEnabled, abstainAllowed=$abstainAllowed, '
      'identityHoldSeconds=$identityHoldSeconds, muteAllAudio=$muteAllAudio, '
      'scoreEnabled=$scoreEnabled)';
}
