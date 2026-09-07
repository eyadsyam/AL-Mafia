/// Match presets — doc 13 §5.
///
/// *"Groups differ."* Three named shapes plus custom, so that a table which
/// has never played can start a fifteen-minute game with two mechanics in it,
/// and a table on its twentieth match can start one with no Doctor and a
/// two-minute clock.
///
/// ## What a preset is and is not
///
/// It is a [MatchSettings] and a role split. It is not a mode: nothing in the
/// engine branches on which preset produced the settings it was handed, and
/// nothing stores which one was used. Picking «قاسية» and then turning the
/// whisper back on leaves you with a custom match, and that is the correct
/// outcome rather than an inconsistency to guard against — presets are a
/// starting point, and doc 13 §7's rule is that every individual switch stays
/// reachable.
library engine.presets;

import 'models/enums.dart';
import 'models/match_settings.dart';

/// Doc 13 §5's three, in the order the settings screen offers them.
enum MatchPreset {
  /// «سريعة» — the on-ramp. Bullets off, fewer rules, and the night victim's
  /// role announced, because a group's first match should be easier to follow
  /// than it is to win. Around fifteen minutes.
  fast,

  /// «كلاسيكية» — everything doc 09 and doc 13 build, at the tempo they were
  /// designed at. The default.
  classic,

  /// «قاسية» — no Doctor, a third of the table is Mafia, no whispers, a second
  /// confrontation every day, and a two-minute clock. The safety net is gone.
  brutal;

  /// The stable code stored with a group's remembered configuration and used
  /// as an l10n key. Never the index: a preset inserted in the middle would
  /// silently rename everybody's saved choice.
  String get code => name;

  /// The smallest table this preset is offered at.
  ///
  /// «قاسية» takes a third of the table and gives back no Doctor. At six
  /// players a third is two, which is a third of the room in the family before
  /// a single night has been played, and the balance harness measures the
  /// result at close to four matches in five for the Mafia. There is no
  /// integer that fixes it — one Mafia in six is the *other* preset — so the
  /// preset is simply not offered there. Doc 13 §5 describes «قاسية» as the
  /// shape for a group on its twentieth match, and a group on its twentieth
  /// match is not a group of six.
  int get minimumPlayers => this == MatchPreset.brutal ? 8 : 5;

  /// Whether this preset may be offered for a table of [playerCount].
  bool availableFor(int playerCount) => playerCount >= minimumPlayers;

  /// This preset's settings.
  ///
  /// Every field doc 13 §5's table names is set explicitly, including the ones
  /// that happen to match the default — the table is the specification, and a
  /// field left implicit here is a field that changes meaning the next time a
  /// default moves.
  MatchSettings get settings => switch (this) {
    MatchPreset.fast => const MatchSettings(
      speechSeconds: 30,
      discussionSeconds: 180,
      traceEnabled: true,
      whisperEnabled: true,
      bulletsEnabled: false,
      midDiscussionConfrontation: false,
      revealNightVictimRole: true,
      // The curve would clamp a 30-second turn to 20 at three players,
      // which is right for a group that knows the game and hurried for
      // one meeting it. Off here; on everywhere else.
      pressureCurveEnabled: false,
    ),
    MatchPreset.classic => const MatchSettings(
      speechSeconds: 45,
      discussionSeconds: 300,
      traceEnabled: true,
      whisperEnabled: true,
      bulletsEnabled: true,
      midDiscussionConfrontation: false,
      revealNightVictimRole: false,
      pressureCurveEnabled: true,
    ),
    MatchPreset.brutal => const MatchSettings(
      speechSeconds: 30,
      discussionSeconds: 120,
      traceEnabled: true,
      whisperEnabled: false,
      bulletsEnabled: true,
      midDiscussionConfrontation: true,
      revealNightVictimRole: false,
      pressureCurveEnabled: true,
    ),
  };

  /// [base], with doc 13 5's nine rows replaced by this preset's.
  ///
  /// A preset speaks for the shape of the *game* and for nothing else. It does
  /// not know whether this table wants narration, how long the identity hold
  /// is, or what happens on a tied vote  those are the host's, and a preset
  /// that quietly reset them would be a preset that punishes curiosity.
  ///
  /// The exact inverse of [_alignedTo], and deliberately the same list: if a
  /// row is added to doc 13 5's table it has to appear in both, and a row in
  /// one but not the other shows up immediately as a chip that will not stay
  /// lit after it is tapped.
  MatchSettings applyTo(MatchSettings base) => base.copyWith(
    speechSeconds: settings.speechSeconds,
    discussionSeconds: settings.discussionSeconds,
    traceEnabled: settings.traceEnabled,
    whisperEnabled: settings.whisperEnabled,
    bulletsEnabled: settings.bulletsEnabled,
    midDiscussionConfrontation: settings.midDiscussionConfrontation,
    revealNightVictimRole: settings.revealNightVictimRole,
    pressureCurveEnabled: settings.pressureCurveEnabled,
  );

  /// This preset's role split for [playerCount].
  ///
  /// Doc 13 §5's last two rows. «قاسية» takes a third of the table as Mafia
  /// and no Doctor at all; the other two take the app's standing
  /// recommendation, which is a quarter and one of each.
  ///
  /// Always returns a legal split: the Mafia count is capped strictly below
  /// half the table, because at half the table the match is over before the
  /// first night.
  Map<Role, int> roleCounts(int playerCount) {
    final n = playerCount.clamp(5, 20);

    if (this != MatchPreset.brutal) {
      // Doc 13 §5's row: a quarter. `(n + 1) ~/ 4` rather than a bare
      // rounding, because a bare rounding puts two Mafia in a table of six —
      // two of six is a third, the match is at parity before the first night,
      // and the balance harness sees it immediately. Deliberately *not*
      // `BalanceGuard.recommended`, which flattens to three Mafia from nine
      // players all the way to twenty — a rule that is two Mafia too many at
      // nine and two too few at twenty. The balance harness measures this
      // number, so it is the doc's number and not the older heuristic.
      final mafia = ((n + 1) ~/ 4).clamp(1, (n - 1) ~/ 2);
      return {
        Role.mafia: mafia,
        Role.detective: 1,
        Role.doctor: 1,
        Role.citizen: n - mafia - 2,
      };
    }

    // A third, rounded down, and never enough to reach parity on night zero.
    // «قاسية» has no Doctor at all, and the key is *omitted* rather than mapped
    // to zero: the setup path treats an absent role and a role with zero
    // players as the same thing, and the engine's balance guard reads keys.
    var mafia = n ~/ 3;
    if (mafia < 1) mafia = 1;
    final ceiling = (n - 1) ~/ 2;
    if (mafia > ceiling) mafia = ceiling;

    return {Role.mafia: mafia, Role.detective: 1, Role.citizen: n - mafia - 1};
  }

  /// Whether [settings] and [counts] still are this preset.
  ///
  /// Used by the settings screen to decide which chip is lit, and by nothing
  /// else. A match that no longer matches any preset is custom, which is a
  /// perfectly good thing for a match to be.
  bool matches(MatchSettings other, {Map<Role, int>? counts, int? players}) {
    if (settings != _alignedTo(other)) return false;
    if (counts == null || players == null) return true;
    final mine = roleCounts(players);
    for (final role in Role.values) {
      if ((mine[role] ?? 0) != (counts[role] ?? 0)) return false;
    }
    return true;
  }

  /// [other], with every field this preset does *not* speak for copied from
  /// this preset — so the comparison in [matches] is about the nine rows of
  /// doc 13 §5's table and not about the audio settings.
  MatchSettings _alignedTo(MatchSettings other) => settings.copyWith(
    speechSeconds: other.speechSeconds,
    discussionSeconds: other.discussionSeconds,
    traceEnabled: other.traceEnabled,
    whisperEnabled: other.whisperEnabled,
    bulletsEnabled: other.bulletsEnabled,
    midDiscussionConfrontation: other.midDiscussionConfrontation,
    revealNightVictimRole: other.revealNightVictimRole,
    pressureCurveEnabled: other.pressureCurveEnabled,
  );

  /// The preset [settings] came from, or null when it came from none of them.
  static MatchPreset? identify(
    MatchSettings settings, {
    Map<Role, int>? counts,
    int? players,
  }) {
    for (final preset in MatchPreset.values) {
      if (players != null && !preset.availableFor(players)) continue;
      if (preset.matches(settings, counts: counts, players: players)) {
        return preset;
      }
    }
    return null;
  }
}
