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
  ///
  /// **Off, and doc 14 §4.2 is why it changed.** It solved a real problem — a
  /// first day with nothing in it — by imposing ten silent seconds and a bare
  /// name on every table whether or not they wanted the ceremony. A round that
  /// good tables opt into is worth more than one every table sits through.
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

  /// Whether ballots are visible to the table while the day's vote is open
  /// (doc 12 §3.6).
  ///
  /// **Off by default, which is the offline game's rule and doc 10 §4's.** A
  /// running count is a coordination channel a table around a real deck does
  /// not have, and the `votes` table is read-restricted until the phase closes
  /// for exactly that reason.
  ///
  /// Doc 12 turns that restriction into a choice, and is explicit that it is
  /// doing so: *"vote intention is public and changeable until the timer ends,
  /// then locked... This deliberately differs from offline (secret ballot) —
  /// and that difference is a feature of online, not an inconsistency."*
  ///
  /// So this is a room setting rather than a mode. Off, every client sees
  /// exactly what doc 10 built. On, the ballot becomes the thing only an online
  /// game can show: ten lines of intent accumulating on a table, and somebody
  /// visibly changing their mind under pressure.
  ///
  /// It never affects *counting*. The tally is resolved from the same rows
  /// either way; this decides only whether they may be read early.
  final bool openVoting;

  /// How long the whole discussion runs, before the pressure curve is applied.
  ///
  /// Only free discussion has ever had a total; the structured mode's length is
  /// [speechSeconds] times the number of people still alive, which shrinks on
  /// its own as the table does. This is the number doc 13 §3's curve tightens,
  /// and the number «سريعة» and «قاسية» differ on most visibly.
  final int discussionSeconds;

  // ---------------------------------------------------------------------------
  // «الطلقة الواحدة» (doc 13 §2) and the pressure curve (§3).
  //
  // Same rule as the Information Engine's flags above, for the same reason:
  // *"a mechanic that a group dislikes should be removable rather than
  // endured."* With [bulletsEnabled] off, the four controls are not built — not
  // built and refused, which would be a control whose presence varies between
  // matches and therefore a thing to read.
  // ---------------------------------------------------------------------------

  /// The master switch. Off is the game exactly as it was before doc 13.
  final bool bulletsEnabled;

  /// مافيا — «الليلة الهادية».
  ///
  /// Turning this on also makes every quiet morning ambiguous: with it
  /// available, the morning stops distinguishing "the Doctor blocked a kill"
  /// from "nobody died", and the `T2` trace stops being published at all. Both
  /// are required — a bullet whose use the table can detect is not a bluff, it
  /// is an announcement. See `NightResolver` and `selectTrace`.
  final bool quietNightEnabled;

  /// طبيب — «حماية النفس». The single night a Doctor may cover themselves.
  final bool selfProtectEnabled;

  /// Doc 13 §3. The clock closes as the table shrinks.
  ///
  /// It only ever tightens: a host who set a short discussion keeps it. See
  /// [PressureCurve.discussionSeconds].
  final bool pressureCurveEnabled;

  /// Whether the morning names the role of whoever the Mafia killed.
  ///
  /// **Off**, and off is the interesting default. A day elimination is public
  /// (FR-019) because the table chose it; a night victim's role is a free gift
  /// of information that nobody paid for, and «سريعة» turns it on only because
  /// a group's first match should be easier to follow than it is to win.
  final bool revealNightVictimRole;

  /// Doc 13 §4.2 — the one-line hints that teach the app.
  final bool interfaceHintsEnabled;

  /// Doc 13 §4.3 — the hints that teach the game, in dead time only.
  final bool playHintsEnabled;

  /// Doc 13 §4.4 — «كان ممكن», after the match.
  final bool postMatchCoachingEnabled;

  /// A second confrontation, opened from inside the discussion.
  ///
  /// Doc 13 §3 hands this to the tightest band of the pressure curve — four
  /// living players and fewer — and doc 13 §5 hands it to «قاسية» at every
  /// count. So it is a setting rather than a consequence: the curve raises it
  /// when the table shrinks, a preset can raise it from the start, and neither
  /// one has to know about the other.
  final bool midDiscussionConfrontation;

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
    this.openingRoundEnabled = false,
    this.survivorConfrontationEnabled = false,
    this.confrontationSeconds = 45,
    this.openVoting = false,
    this.discussionSeconds = 300,
    this.bulletsEnabled = true,
    this.quietNightEnabled = true,
    this.selfProtectEnabled = true,
    this.pressureCurveEnabled = true,
    this.revealNightVictimRole = false,
    this.interfaceHintsEnabled = true,
    this.playHintsEnabled = true,
    this.postMatchCoachingEnabled = true,
    this.midDiscussionConfrontation = false,
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
        openingRoundEnabled = false,
        survivorConfrontationEnabled = false,
        confrontationSeconds = 45,
        openVoting = false,
        discussionSeconds = 300,
        bulletsEnabled = true,
        quietNightEnabled = true,
        selfProtectEnabled = true,
        pressureCurveEnabled = true,
        revealNightVictimRole = false,
        interfaceHintsEnabled = true,
        playHintsEnabled = true,
        postMatchCoachingEnabled = true,
        midDiscussionConfrontation = false;

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
    bool? openVoting,
    int? discussionSeconds,
    bool? bulletsEnabled,
    bool? quietNightEnabled,
    bool? selfProtectEnabled,
    bool? pressureCurveEnabled,
    bool? revealNightVictimRole,
    bool? interfaceHintsEnabled,
    bool? playHintsEnabled,
    bool? postMatchCoachingEnabled,
    bool? midDiscussionConfrontation,
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
        openVoting: openVoting ?? this.openVoting,
        discussionSeconds: discussionSeconds ?? this.discussionSeconds,
        bulletsEnabled: bulletsEnabled ?? this.bulletsEnabled,
        quietNightEnabled: quietNightEnabled ?? this.quietNightEnabled,
        selfProtectEnabled: selfProtectEnabled ?? this.selfProtectEnabled,
        pressureCurveEnabled: pressureCurveEnabled ?? this.pressureCurveEnabled,
        revealNightVictimRole: revealNightVictimRole ?? this.revealNightVictimRole,
        interfaceHintsEnabled: interfaceHintsEnabled ?? this.interfaceHintsEnabled,
        playHintsEnabled: playHintsEnabled ?? this.playHintsEnabled,
        postMatchCoachingEnabled: postMatchCoachingEnabled ?? this.postMatchCoachingEnabled,
        midDiscussionConfrontation:
            midDiscussionConfrontation ?? this.midDiscussionConfrontation,
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
          confrontationSeconds == other.confrontationSeconds &&
          openVoting == other.openVoting &&
          discussionSeconds == other.discussionSeconds &&
          bulletsEnabled == other.bulletsEnabled &&
          quietNightEnabled == other.quietNightEnabled &&
          selfProtectEnabled == other.selfProtectEnabled &&
          pressureCurveEnabled == other.pressureCurveEnabled &&
          revealNightVictimRole == other.revealNightVictimRole &&
          interfaceHintsEnabled == other.interfaceHintsEnabled &&
          playHintsEnabled == other.playHintsEnabled &&
          postMatchCoachingEnabled == other.postMatchCoachingEnabled &&
          midDiscussionConfrontation == other.midDiscussionConfrontation;

  @override
  int get hashCode => Object.hashAll([
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
        openVoting,
        discussionSeconds,
        bulletsEnabled,
        quietNightEnabled,
        selfProtectEnabled,
        pressureCurveEnabled,
        revealNightVictimRole,
        interfaceHintsEnabled,
        playHintsEnabled,
        postMatchCoachingEnabled,
        midDiscussionConfrontation,
      ]);

  @override
  String toString() =>
      'MatchSettings(speechSeconds=$speechSeconds, discussionMode=$discussionMode, '
      'dayTieRule=$dayTieRule, narrationEnabled=$narrationEnabled, abstainAllowed=$abstainAllowed, '
      'identityHoldSeconds=$identityHoldSeconds, muteAllAudio=$muteAllAudio, '
      'scoreEnabled=$scoreEnabled, traceEnabled=$traceEnabled, '
      'confrontationEnabled=$confrontationEnabled, whisperEnabled=$whisperEnabled, '
      'revealWhisperContent=$revealWhisperContent, openingRoundEnabled=$openingRoundEnabled, '
      'survivorConfrontationEnabled=$survivorConfrontationEnabled, '
      'confrontationSeconds=$confrontationSeconds, openVoting=$openVoting, '
      'discussionSeconds=$discussionSeconds, bullets=$bulletsEnabled, '
      'pressureCurve=$pressureCurveEnabled, revealNightVictimRole=$revealNightVictimRole)';
}
