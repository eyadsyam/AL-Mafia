import 'enums.dart';

/// Settings that customize a match's behavior.
/// Reference: data-model.md §4
class MatchSettings {
  final int speechSeconds;
  final DiscussionMode discussionMode;

  /// What happens when the day's vote ties.
  ///
  /// **Defaults to [DayTieRule.noElimination], and that is a change.** It used
  /// to default to a revote, which is the more familiar table rule and the
  /// worse default for this app: a revote narrows the ballot to exactly the
  /// seats that tied, so a table that split evenly once has every reason to
  /// split evenly again, and each round costs another full pass of the phone.
  /// The engine caps the rounds, so the ceremony always ends — but it ends in
  /// no elimination anyway, several minutes later, having spent them on a
  /// ballot whose outcome the room had already argued to a standstill.
  ///
  /// Nobody dies on a tied vote is also the safer default in the sense the rest
  /// of this app cares about: it is the outcome that adds no information. A
  /// revote asks the same people to vote again knowing exactly who was tied,
  /// which is a second round of public signalling that the first round did not
  /// have.
  ///
  /// The revote is still one tap away on the settings screen for tables that
  /// prefer it.
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

  // ---------------------------------------------------------------------------
  // The Information Engine (doc 09 §7).
  //
  // Every one of these is togglable, and that is a rule rather than a courtesy:
  // *"Groups differ, and a mechanic that a group dislikes should be removable
  // rather than endured."* With all four of the first flags off, the match is
  // classic Mafia and the generators never run.
  // ---------------------------------------------------------------------------

  /// Layer 1. The one true forensic observation published each morning.
  final bool traceEnabled;

  /// Layer 2. The single daily confrontation, Day 2 onward.
  final bool confrontationEnabled;

  /// Layer 3. One private message per living player per day.
  ///
  /// **Off by default offline**, per doc 09 §7: at the table a whisper waits
  /// for the recipient's next night turn, so it lands a full phase after it was
  /// written and reads as an odd delayed note rather than a live channel. The
  /// online transport turns it on, where delivery is immediate and the layer is
  /// the thing that makes online richer than offline.
  final bool whisperEnabled;

  /// Whether the post-match screen shows whisper *bodies* as well as the graph.
  ///
  /// The graph is always revealed; this is only about content, and it is off by
  /// default because a player writes a whisper believing one other person will
  /// read it.
  final bool revealWhisperContent;

  /// Day 1's «اسم واحد» round.
  final bool openingRoundEnabled;

  /// `C11` («الناجي»).
  ///
  /// **Off, and it should stay off for most tables.** It announces that a save
  /// occurred *and* names who was saved, which narrows the Doctor to whoever
  /// could plausibly have been protecting that seat. Doc 09 §2.3 lists it "for
  /// completeness only".
  final bool survivorConfrontationEnabled;

  /// How long the confronted player holds the floor. 30 / 45 / 60.
  final int confrontationSeconds;

  const MatchSettings({
    this.speechSeconds = 60,
    this.discussionMode = DiscussionMode.structured,
    this.dayTieRule = DayTieRule.noElimination,
    this.narrationEnabled = true,
    this.abstainAllowed = false,
    this.identityHoldSeconds = 5,
    this.muteAllAudio = false,
    this.scoreEnabled = true,
    this.traceEnabled = true,
    this.confrontationEnabled = true,
    this.whisperEnabled = false,
    this.revealWhisperContent = false,
    this.openingRoundEnabled = true,
    this.survivorConfrontationEnabled = false,
    this.confrontationSeconds = 45,
  });

  /// Default settings constructor.
  const MatchSettings.defaults()
      : speechSeconds = 60,
        discussionMode = DiscussionMode.structured,
        dayTieRule = DayTieRule.noElimination,
        narrationEnabled = true,
        abstainAllowed = false,
        identityHoldSeconds = 5,
        muteAllAudio = false,
        scoreEnabled = true,
        traceEnabled = true,
        confrontationEnabled = true,
        whisperEnabled = false,
        revealWhisperContent = false,
        openingRoundEnabled = true,
        survivorConfrontationEnabled = false,
        confrontationSeconds = 45;

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
    bool? traceEnabled,
    bool? confrontationEnabled,
    bool? whisperEnabled,
    bool? revealWhisperContent,
    bool? openingRoundEnabled,
    bool? survivorConfrontationEnabled,
    int? confrontationSeconds,
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
        traceEnabled: traceEnabled ?? this.traceEnabled,
        confrontationEnabled:
            confrontationEnabled ?? this.confrontationEnabled,
        whisperEnabled: whisperEnabled ?? this.whisperEnabled,
        revealWhisperContent:
            revealWhisperContent ?? this.revealWhisperContent,
        openingRoundEnabled: openingRoundEnabled ?? this.openingRoundEnabled,
        survivorConfrontationEnabled:
            survivorConfrontationEnabled ?? this.survivorConfrontationEnabled,
        confrontationSeconds:
            confrontationSeconds ?? this.confrontationSeconds,
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
          scoreEnabled == other.scoreEnabled &&
          traceEnabled == other.traceEnabled &&
          confrontationEnabled == other.confrontationEnabled &&
          whisperEnabled == other.whisperEnabled &&
          revealWhisperContent == other.revealWhisperContent &&
          openingRoundEnabled == other.openingRoundEnabled &&
          survivorConfrontationEnabled == other.survivorConfrontationEnabled &&
          confrontationSeconds == other.confrontationSeconds;

  @override
  int get hashCode => Object.hash(
        speechSeconds,
        discussionMode,
        dayTieRule,
        narrationEnabled,
        abstainAllowed,
        identityHoldSeconds,
        muteAllAudio,
        scoreEnabled,
        traceEnabled,
        confrontationEnabled,
        whisperEnabled,
        revealWhisperContent,
        openingRoundEnabled,
        survivorConfrontationEnabled,
        confrontationSeconds,
      );

  @override
  String toString() =>
      'MatchSettings(speechSeconds=$speechSeconds, discussionMode=$discussionMode, '
      'dayTieRule=$dayTieRule, narrationEnabled=$narrationEnabled, abstainAllowed=$abstainAllowed, '
      'identityHoldSeconds=$identityHoldSeconds, muteAllAudio=$muteAllAudio, '
      'scoreEnabled=$scoreEnabled, traceEnabled=$traceEnabled, '
      'confrontationEnabled=$confrontationEnabled, whisperEnabled=$whisperEnabled, '
      'revealWhisperContent=$revealWhisperContent, openingRoundEnabled=$openingRoundEnabled, '
      'survivorConfrontationEnabled=$survivorConfrontationEnabled, '
      'confrontationSeconds=$confrontationSeconds)';
}
