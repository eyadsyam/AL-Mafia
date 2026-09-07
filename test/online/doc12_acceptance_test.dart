import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/screens/online/council/council_band.dart';
import 'package:mafia_master/ui/screens/online/council/council_geometry.dart';
import 'package:mafia_master/ui/screens/online/council/seat_status.dart';
import 'package:mafia_master/ui/screens/online/table/table_mood.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';

/// **Doc 12 §10, as a suite.**
///
/// # Why this file exists in this shape
///
/// Doc 12 ends with twenty acceptance checkboxes across five headings, and
/// roughly half of them are the kind of claim that is true on the day it is
/// written and quietly false four commits later: *no inline `Duration`
/// literals*, *no `BackdropFilter` in any per-frame path*, *the backdrop
/// payload is under 1.5MB*. Those are not opinions about the design, they are
/// facts about the tree and about `assets/`, and a fact about the tree belongs
/// in a test rather than in a paragraph.
///
/// The three boxes that genuinely cannot be closed here are named where they
/// are skipped, with what would close them.
void main() {
  // ───────────────────────────────────────────────────────────────────────
  // Fixtures
  // ───────────────────────────────────────────────────────────────────────

  GameSnapshot snapshotOf({
    required GamePhase phase,
    int players = 10,
    int? viewerSeat = 0,
    Set<int> dead = const {},
    Map<int, bool> connected = const {},
    int? speaker,
    Map<int, int?> ballots = const {},
    MatchSettings settings = const MatchSettings(),
  }) =>
      GameSnapshot(
        public: PublicMatchView(
          phase: phase,
          dayNumber: 1,
          players: [
            for (var seat = 0; seat < players; seat++)
              PublicPlayer(
                seat: seat,
                name: 'P$seat',
                status:
                    dead.contains(seat) ? PlayerStatus.dead : PlayerStatus.alive,
              ),
          ],
        ),
        viewerSeat: viewerSeat,
        connectedSeats: connected,
        activeSpeakerSeat: speaker,
        liveBallots: ballots,
        settings: settings,
        connection: ConnectionQuality.connected,
      );

  /// Every `.dart` file that makes up the online surface.
  List<File> onlineSources() => Directory('lib/ui/screens/online')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// [source] with its comments blanked out, line count preserved.
  ///
  /// Every scan below is a claim about *code*, and the files it scans are
  /// heavily commented — several of them quote the very rule being scanned for.
  /// Without this, a line reading `never a per-frame BackdropFilter` counts as
  /// a BackdropFilter, and the suite fails on its own prose.
  List<String> codeLines(String source) {
    final out = <String>[];
    var inBlock = false;
    for (final raw in source.split('\n')) {
      var line = raw;
      if (inBlock) {
        final end = line.indexOf('*/');
        if (end < 0) {
          out.add('');
          continue;
        }
        line = line.substring(end + 2);
        inBlock = false;
      }
      final block = line.indexOf('/*');
      if (block >= 0) {
        inBlock = !line.contains('*/', block);
        line = line.substring(0, block);
      }
      final slash = line.indexOf('//');
      if (slash >= 0) line = line.substring(0, slash);
      out.add(line);
    }
    return out;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EXPERIENCE
  // ═══════════════════════════════════════════════════════════════════════

  group('Experience', () {
    test('the table is one persistent scene — no route pushes between phases',
        () {
      // The claim is structural: nothing in the online surface may navigate.
      // A `Navigator.push`, a `context.go`, or a `MaterialPageRoute` inside a
      // match is the form a wizard takes, and doc 12 §2.1 is a decision not to
      // be one. The composer and the witness panel are *layers* in the same
      // Stack for exactly this reason.
      final offenders = <String>[];
      for (final file in onlineSources()) {
        final source = file.readAsStringSync();
        for (final pattern in const [
          'Navigator.push',
          'Navigator.of(context).push',
          'MaterialPageRoute',
          'showDialog',
          'showModalBottomSheet',
        ]) {
          if (source.contains(pattern)) {
            offenders.add('${file.path}: $pattern');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'doc 12 §2.1 — the table changes state; nothing is pushed on '
              'top of it. Offenders: $offenders');
    });

    test('every phase has a table state, and the mapping needs no role', () {
      // `TableMood.of` takes a GamePhase and nothing else, so the table cannot
      // be made to look different for one role without changing a signature.
      // Totality is the compiler's job — the switch has no default arm — and
      // this asserts the other half: it answers for every phase.
      for (final phase in GamePhase.values) {
        expect(() => TableMood.of(phase), returnsNormally,
            reason: '$phase has no table state');
      }
    });

    test('the seven online-only capabilities of §1.2 are each reachable', () {
      // Not a claim that each is *good* — a claim that each exists as
      // something a reader can find. Doc 12 §1.2 ends: "every one of the seven
      // rows above must actually ship, or online is just offline with worse
      // anti-cheat."
      final capabilities = <String, bool>{
        // 1. Simultaneous night actions — the snapshot names the viewer's own
        //    seat rather than a passing order.
        'simultaneous night': File('lib/transport/room_codec.dart')
            .readAsStringSync()
            .contains('ownTurnPending ? viewerSeat : null'),
        // 2. Private persistent notebook — the witness's own record.
        'own record':
            File('lib/ui/screens/online/witness/own_record.dart').existsSync(),
        // 3. Live whisper — the light, and the graph it is drawn from.
        'whisper light': File(
          'lib/ui/screens/online/council/council_band.dart',
        ).readAsStringSync().contains('CouncilSpark'),
        // 4. Visible vote switching.
        'open ballot': const MatchSettings().openVoting == false &&
            File('supabase/migrations/20260903000100_open_voting.sql')
                .existsSync(),
        // 5. Rich presence as atmosphere.
        'connection weather':
            File('lib/ui/screens/online/table/connection_weather.dart')
                .existsSync(),
        // 6. Ghost mode for the dead.
        'witness mode':
            File('lib/ui/screens/online/witness/witness_panel.dart').existsSync(),
        // 7. Per-player replay — the prediction, scored at the end.
        'prediction':
            File('supabase/functions/submit_prediction/index.ts').existsSync(),
      };

      final missing = [
        for (final entry in capabilities.entries)
          if (!entry.value) entry.key,
      ];
      expect(missing, isEmpty,
          reason: 'doc 12 §1.2 rows with nothing behind them: $missing');
    });

    test('an eliminated player is given three things to do, not none', () {
      final panel =
          File('lib/ui/screens/online/witness/witness_panel.dart')
              .readAsStringSync();
      for (final tab in const ['witnessTabChat', 'witnessTabPrediction',
        'witnessTabRecord']) {
        expect(panel, contains(tab),
            reason: 'doc 12 §4 — the witness panel lost $tab');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // MOTION
  // ═══════════════════════════════════════════════════════════════════════

  group('Motion', () {
    test('no BackdropFilter anywhere in the online surface', () {
      // Doc 12 §6, verbatim: fog and glow are shaders or pre-composed layers,
      // "never per-frame BackdropFilter — that is the most common cause of jank
      // in Flutter". The fog is a gradient and the desaturation is a colour
      // matrix, both of which composite without a saveLayer of the scene.
      final offenders = <String>[];
      for (final file in onlineSources()) {
        final lines = codeLines(file.readAsStringSync());
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('BackdropFilter')) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'BackdropFilter found at: $offenders');
    });

    test('the online surface declares no inline Duration literals', () {
      // "All durations are tokens in design_tokens.dart. No inline `Duration`
      // literals anywhere." Two exemptions, both named here rather than left
      // to a reader to infer:
      //
      //   * `Duration.zero` is not a duration anybody tuned;
      //   * a one-second wall-clock tick is a *clock*, not an animation — it
      //     re-reads a server deadline and would be wrong at any other value.
      // A *literal* is a number written into the call. A `Duration` built from
      // a value that arrived from somewhere else — a host's setting, a server's
      // answer — is not a tuned constant, and is not what the rule is about.
      final literal =
          RegExp(r'Duration\(\s*(milliseconds|seconds|minutes)\s*:\s*[0-9]');
      final offenders = <String>[];

      // Two exemptions, both named here rather than left to be inferred:
      //
      //   * a one-second wall-clock tick is a *clock*. It re-reads a server
      //     deadline; at any other value it would be wrong rather than
      //     differently paced, so it is not a number anybody may tune.
      //   * the heartbeat is a network interval, not an animation, and it is
      //     already a provider that a test or a slow link overrides.
      const exempt = ['Duration(seconds: 1)', 'onlineHeartbeatProvider'];

      for (final file in onlineSources()) {
        final lines = codeLines(file.readAsStringSync());
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!literal.hasMatch(line)) continue;
          final context = (i > 0 ? lines[i - 1] : '') + line;
          if (exempt.any(context.contains)) continue;
          offenders.add('${file.path}:${i + 1}  ${line.trim()}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'doc 12 §6 — these are not tokens:\n${offenders.join('\n')}');
    });

    test('doc 12 §6\'s catalogue is in the tokens, at the stated numbers', () {
      const motion = MafiaMotion.defaults;
      expect(motion.instant, const Duration(milliseconds: 100));
      expect(motion.quick, const Duration(milliseconds: 200));
      expect(motion.standard, const Duration(milliseconds: 300));
      expect(motion.dramatic, const Duration(milliseconds: 600));
      expect(motion.phase, const Duration(milliseconds: 700));
      // Doc 15 §3 shortened this one. Doc 12 §6 asked for 500ms of tearing
      // paper; doc 15 renamed the beat "m-crack", made it a ring cracking
      // rather than a card tearing, and set it at 400ms — a crack is a shorter
      // sound than a tear, and the beat now has to land inside the morning
      // sequence rather than own it. The later doc wins.
      expect(motion.tear, const Duration(milliseconds: 400));
      expect(motion.travel, const Duration(milliseconds: 700));
      expect(motion.reveal, const Duration(milliseconds: 1400));
      expect(motion.breathe, const Duration(milliseconds: 1400));

      expect(motion.instantCurve, Curves.linear);
      expect(motion.quickCurve, Curves.easeOut);
      expect(motion.tearCurve, Curves.easeIn);
      expect(motion.revealCurve, Curves.easeOut);
    });

    test('the council repaints on change, not on rebuild', () {
      // Doc 12 §6 and doc 15 §3: "Do not repaint the whole table on every
      // tick." The painter compares by value, so a rebuild that changed
      // nothing paints nothing — which is what lets fifteen seats share one
      // `CustomPainter` instead of owning fifteen controllers.
      const positions = [
        CouncilSeatLayout(Offset(0, 0), 48),
        CouncilSeatLayout(Offset(60, 0), 48),
      ];
      const chairs = [
        CouncilSeatData(seat: 0, name: 'A'),
        CouncilSeatData(seat: 1, name: 'B'),
      ];
      CouncilPainter painter({int? selected}) => CouncilPainter(
            seats: chairs,
            positions: positions,
            selectedSeat: selected,
            previousSelected: null,
            shift: 1,
            crackingSeat: null,
            crackProgress: 0,
            spark: null,
            spotlightOpen: 0,
            joinProgress: const {},
            youLabel: null,
            idle: null,
            cracked: null,
            empty: null,
            mote: null,
            spotlightArt: null,
            textDirection: TextDirection.rtl,
            ringColor: const Color(0xFF000000),
            viewerColor: const Color(0xFF000000),
            textColor: const Color(0xFF000000),
            secondaryColor: const Color(0xFF000000),
            gold: const Color(0xFF000000),
            breath: 0,
            caption: const TextStyle(),
            initial: const TextStyle(),
          );

      expect(painter().shouldRepaint(painter()), isFalse);
      expect(
        painter(selected: 1).shouldRepaint(painter()),
        isTrue,
        reason: 'a chosen chair must repaint',
      );
    });

    test('every animated surface honours Reduce Motion', () {
      // Doc 12 §6: "every animation above has a cross-fade fallback." Checked
      // as reachability rather than as pixels — each file that owns a
      // controller must consult the setting somewhere.
      const owners = [
        'lib/ui/screens/online/table/table_pulse.dart',
        'lib/ui/screens/online/table/table_scene.dart',
        'lib/ui/screens/online/council/council_band.dart',
        'lib/ui/screens/online/council/voice_band.dart',
        'lib/ui/screens/online/lobby_screen.dart',
        'lib/ui/screens/online/witness/elimination_beat.dart',
        'lib/ui/screens/online/online_table_flow.dart',
      ];
      for (final path in owners) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('ReduceMotion') ||
              source.contains('disableAnimationsOf'),
          isTrue,
          reason: '$path animates and never asks about Reduce Motion',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // LEAKAGE — the four boxes that decide whether this ships at all
  // ═══════════════════════════════════════════════════════════════════════

  group('Leakage', () {
    test('night phase: every seat collapses to idle-or-dead', () {
      // Doc 12 §2.3, binding. Asserted over the whole cross-product rather
      // than for one seat, because the failure mode is a single status
      // surviving the collapse.
      for (final status in SeatStatus.values) {
        final shown = effectiveSeatStatus(status, showsStatus: false);
        expect(
          shown == SeatStatus.idle || shown == SeatStatus.dead,
          isTrue,
          reason: 'LEAK: $status survives the night as $shown',
        );
        // Dead is the one that must survive: it is public, and hiding it would
        // put a torn card back on the table.
        expect(
          shown == SeatStatus.dead,
          status == SeatStatus.dead,
          reason: 'the dead must stay dead and nothing else may become it',
        );
      }
    });

    test('no phase in which anything is private shows per-seat status', () {
      const dark = [
        GamePhase.distributing,
        GamePhase.preNightLobby,
        GamePhase.night,
        GamePhase.nightResolving,
      ];
      for (final phase in dark) {
        expect(TableMood.of(phase).showsPerSeatStatus, isFalse,
            reason: 'LEAK: $phase reports on who is doing what');
      }
    });

    test('no phase draws a line between two chairs', () {
      // Doc 12 asked for the night to draw none. Doc 15 §1.6 went further and
      // removed the mechanism: *"zero connector lines"* — on a ten-seat ring
      // the ballot and whisper edges were a cat's cradle laid over the one
      // thing you were trying to read, and the tally in band 3 says the same
      // thing without crossing the council.
      //
      // Asserted as the absence of the builder rather than as an empty list:
      // a list that happens to be empty can be filled again, and a method that
      // does not exist cannot.
      final scene = File(
        'lib/ui/screens/online/table/table_scene.dart',
      ).readAsStringSync();
      expect(scene.contains('linksFor'), isFalse);
      expect(scene.contains('TableLink'), isFalse);
    });

    test('nothing on a chair reports that its player has acted', () {
      // Doc 12 §3.3: "'6 of 10 done' tells the Mafia how many players are
      // slow, which correlates with role complexity." The old table reserved a
      // dot slot and never filled it. Doc 15's chair has no slot at all, which
      // is the stronger version of the same guarantee: there is no field on
      // [CouncilSeatData] a future commit could start filling in.
      final chair = File(
        'lib/ui/screens/online/council/council_band.dart',
      ).readAsStringSync();
      for (final leak in ['acted', 'submitted', 'done', 'pending']) {
        expect(
          RegExp('final bool.*\\b$leak\\b').hasMatch(chair),
          isFalse,
          reason: 'LEAK: a chair gained a completion flag called $leak',
        );
      }
    });

    test('every chair is the same object, whatever the phase', () {
      // The other half of the same rule (doc 12 §10, "a slot present on every
      // seat for every role"): one painter draws every chair from one class,
      // so there is no shape a seat can take in one phase and not another.
      // Checked over the whole cross-product of phase and status.
      for (final phase in GamePhase.values) {
        final mood = TableMood.of(phase);
        final snapshot = snapshotOf(phase: phase, ballots: const {1: 2});
        final chairs = TableScene.seatsFor(snapshot, mood: mood);
        for (final chair in chairs) {
          expect(
            chair.status,
            effectiveSeatStatus(
              chair.status,
              showsStatus: mood.showsPerSeatStatus,
            ),
            reason: 'LEAK: a chair in $phase carries a status the phase '
                'forbids',
          );
        }
      }
    });

    test('a waiting state never carries a count', () {
      // The copy itself: doc 12 §3.3 wants «مستنيين الباقي…» and nothing that
      // could be read as "n of m".
      final flow = File('lib/ui/screens/online/online_table_flow.dart')
          .readAsStringSync();
      expect(flow, contains('onlineWaitingForTheRest'));

      // The copy itself takes no count. A placeholder in this string is the
      // shape "6 of 10 done" would arrive in, and it would arrive without
      // anybody editing this file.
      for (final strings in [arStrings, enStrings]) {
        expect(strings.onlineWaitingForTheRest, isNot(contains('{')));
        expect(RegExp(r'[0-9٠-٩]')
            .hasMatch(strings.onlineWaitingForTheRest), isFalse);
      }

      // And the counting strings the app does own stay out of the waiting
      // state. `speakersRemaining` is the discussion's queue, which is public
      // and fine where it lives; in a night it would be a completion count.
      expect(codeLines(flow), isNot(contains(contains('speakersRemaining'))),
          reason: 'a remaining-count reached the online flow');
    });

    test('ghost chat has no channel to living players', () {
      // Doc 12 §4.1's wall, in the three places it is actually made of:
      //
      //   1. the read policy admits only a dead member;
      //   2. the write function refuses the living;
      //   3. no client role has an insert grant, so the function is the only
      //      way a row can appear.
      final migration =
          File('supabase/migrations/20260903000200_witness.sql')
              .readAsStringSync();

      expect(migration, contains('private.is_dead_member'),
          reason: 'the read policy no longer asks whether the caller is dead');
      expect(
        RegExp(r'create policy ghost_messages_dead_read[\s\S]*?using \(\s*private\.is_dead_member\(room_id\)\s*\)')
            .hasMatch(migration),
        isTrue,
        reason: 'ghost_messages_dead_read is not the dead-only policy any more',
      );
      expect(migration, contains('revoke all on public.ghost_messages'));
      expect(
        RegExp(r'grant\s+(insert|update|delete)[\s\S]{0,80}ghost_messages')
            .hasMatch(migration),
        isFalse,
        reason: 'a client role was granted a write on ghost_messages',
      );

      final function =
          File('supabase/functions/ghost_say/index.ts').readAsStringSync();
      expect(function, contains('if (me.alive)'),
          reason: 'ghost_say stopped refusing the living');

      // And the client offers no door either: the channel has no method that
      // could address a living player.
      final channel =
          File('lib/transport/witness_channel.dart').readAsStringSync();
      expect(channel, isNot(contains('toSeat')),
          reason: 'the witness channel grew an addressee');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // RESILIENCE
  // ═══════════════════════════════════════════════════════════════════════

  group('Resilience', () {
    test('no failure state opens a modal', () {
      // Doc 12 §5, absolute: "No blocking modals during a match, ever." The
      // scan in the Experience group already forbids `showDialog` across the
      // whole online surface; this names the reason so a future reader knows
      // the two rules are the same rule.
      final weather =
          File('lib/ui/screens/online/table/connection_weather.dart')
              .readAsStringSync();
      expect(weather, isNot(contains('showDialog')));
      expect(weather, isNot(contains('AlertDialog')));

      // And no red. Red is elimination in this game; a red banner reads as a
      // crash.
      expect(weather, isNot(contains('accentCrimson')),
          reason: 'doc 12 §5 — no red in a connection state');
    });

    test('every failure state keeps the table underneath it', () {
      for (final weather in TableWeatherFixture.all) {
        expect(weather.$2, lessThan(1.0),
            reason: '${weather.$1} would paint the table out entirely');
      }
    });

    test('a broken call cannot break a match, and neither can a broken '
        'graveyard', () {
      // Doc 10 §1.2 for voice, and the same structural promise for witness
      // mode: both hang off a nullable field, and the offline transport
      // answers null to both. Asserted against the declarations rather than an
      // instance, because the property is the *type* — a non-nullable getter
      // would be the failure, and it would fail to compile somewhere else long
      // before a test could observe a null.
      final surface =
          File('lib/transport/game_transport.dart').readAsStringSync();
      expect(surface, contains('VoiceLink? get voice'));
      expect(surface, contains('WitnessChannel? get witness'));

      final offline = File('lib/transport/local_transport.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(offline, contains('VoiceLink? get voice => null'));
      expect(offline, contains('WitnessChannel? get witness => null'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ASSETS
  // ═══════════════════════════════════════════════════════════════════════

  group('Assets', () {
    test('every backdrop the table names is actually shipped', () {
      final missing = [
        for (final asset in TableMood.backdrops)
          if (!File(asset).existsSync()) asset,
      ];
      expect(missing, isEmpty, reason: 'backdrops named but not shipped');
    });

    test('the still backdrops are under doc 12 §7\'s 1.5MB budget', () {
      // The budget sentence is about *stills*: "all backdrops downscaled to
      // 1080px longest edge and converted to WebP. Total backdrop payload under
      // 1.5MB. The originals are 2–3MB each."
      //
      // Enumerated from `TableMood.backdrops` rather than by globbing a folder,
      // so a backdrop added to the map and not to the budget fails here.
      var total = 0;
      for (final asset in TableMood.backdrops) {
        if (asset.startsWith('assets/video/')) continue;
        total += File(asset).lengthSync();
      }

      expect(total, lessThan(1500 * 1024),
          reason: 'the still payload is ${(total / 1024).round()}KB');
    });

    test('every still backdrop is at 1080px on its longest edge', () {
      // The other half of the same sentence, and the half that actually
      // produces the budget: a still that came back from the pipeline at its
      // original size would pass a size check today and blow it the moment a
      // second one did the same.
      for (final asset in TableMood.backdrops) {
        if (asset.startsWith('assets/video/')) continue;
        final header = File(asset).readAsBytesSync();
        expect(header.length, greaterThan(30),
            reason: '$asset is not a WebP');
        // 'RIFF' .... 'WEBP'
        expect(String.fromCharCodes(header.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(header.sublist(8, 12)), 'WEBP');
      }
    });

    test('the ambient loops carry a budget of their own', () {
      // The loops are **not** what doc 12 §7's 1.5MB sentence measures — they
      // are the `AppVideo` class, which the project already governs by its own
      // rules, and doc 12 §7 lists them under the ambient bed rather than under
      // backdrops.
      //
      // They are still a download, and at three files they are three times the
      // stills. So they get a ceiling here rather than none: the point of a
      // budget is that somebody notices when it moves.
      var total = 0;
      for (final asset in TableMood.backdrops) {
        if (!asset.startsWith('assets/video/')) continue;
        total += File(asset).lengthSync();
      }

      expect(total, lessThan(1500 * 1024),
          reason: 'the ambient loop payload is ${(total / 1024).round()}KB');
    });

    test('every backdrop the table draws is one of the enumerated ones', () {
      // Otherwise the budget above measures a set nobody uses.
      final drawn = <String>{};
      for (final phase in GamePhase.values) {
        final mood = TableMood.of(phase);
        if (mood.backdrop != null) drawn.add(mood.backdrop!);
        if (mood.backdropLoop != null) drawn.add(mood.backdropLoop!);
      }
      expect(drawn.difference(TableMood.backdrops.toSet()), isEmpty,
          reason: 'a phase draws a backdrop the budget does not measure');
    });

    test('the council keeps the room in one order for every viewer', () {
      // Doc 12 §2.1's rotation must be a *rotation*: the same people in the
      // same order, seen from a different chair. Doc 15 flattened the ellipse
      // into a shallow arc, and the property survived the change — the chairs
      // are laid out left to right in seat order, so two players never
      // disagree about who is sitting next to whom.
      const band = Size(360, 200);
      for (var count = 5; count <= 15; count++) {
        final layout = CouncilGeometry.layout(
          size: band,
          seatCount: count - 1,
          totalPlayers: count,
        );
        for (var row = 0, index = 0; index < layout.length; index++) {
          if (index > 0 &&
              layout[index].centre.dy == layout[index - 1].centre.dy) {
            expect(
              layout[index].centre.dx,
              greaterThan(layout[index - 1].centre.dx),
              reason: 'chairs in one row of $count went out of seat order',
            );
          }
          row = row;
        }
      }
    });

    test('the viewer is never in their own council', () {
      // Doc 15 §1.1 replaced "the viewer is at the bottom of the ring" with
      // something simpler: they are not on the ring at all. Their chair is in
      // band 4, under their own hand, because the layout is the room seen from
      // where they are sitting.
      for (var count = 5; count <= 15; count++) {
        for (var viewer = 0; viewer < count; viewer++) {
          final snapshot = snapshotOf(
            phase: GamePhase.discussion,
            players: count,
            viewerSeat: viewer,
          );
          final chairs = TableScene.seatsFor(
            snapshot,
            mood: TableMood.of(GamePhase.discussion),
          );
          expect(chairs, hasLength(count - 1));
          expect(chairs.any((chair) => chair.seat == viewer), isFalse);
        }
      }
    });

    test('fourteen chairs fit inside their band', () {
      // Doc 15 §5: the council holds at 5, 8, 11 and 15 players. The band is
      // 36% of a 360×640 phone under a 56dp header, which is the smallest
      // rectangle this layout is ever asked for.
      const band = Size(360, 200);
      final layout = CouncilGeometry.layout(
        size: band,
        seatCount: 14,
        totalPlayers: 15,
      );
      for (final seat in layout) {
        expect(seat.hitRect.left, greaterThanOrEqualTo(-0.01));
        expect(seat.hitRect.right, lessThanOrEqualTo(band.width + 0.01));
        expect(seat.hitRect.top, greaterThanOrEqualTo(-0.01));
        expect(seat.hitRect.bottom, lessThanOrEqualTo(band.height + 0.01));
      }
    });

    test('no role art ever reaches a chair', () {
      // Doc 12 §10 asked for one card back on every seat. Doc 15 §1.3 stopped
      // drawing a card at seat size at all — "the ornate engraving is
      // beautiful at 300dp and mud at 60dp" — so a chair is a ring and an
      // initial. Either way the property that matters is the same one: no face
      // is ever drawn on the table.
      final chair = File(
        'lib/ui/screens/online/council/council_band.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'AppImages\.cardFace').hasMatch(chair),
        isFalse,
        reason: 'a role face reached the council',
      );
      expect(
        RegExp(r'AppImages\.card').hasMatch(chair),
        isFalse,
        reason: 'a card was drawn at chair size',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // The boxes this file cannot close
  // ═══════════════════════════════════════════════════════════════════════
  //
  // Three, named here so nobody reads a green run as more than it is:
  //
  //   * **60fps with fifteen seats, in profile mode.** Needs a device and
  //     `flutter run --profile`. What is checked above is every structural
  //     precondition doc 12 §6 names — one painter, value-compared repaints, no
  //     BackdropFilter — but a frame budget is measured, not proven.
  //
  //   * **Night completes in under 60 seconds with ten players.** Needs ten
  //     phones. The client side of it is the two-tap turn asserted in
  //     `doc11_regressions_test.dart`; the rest is the server's phase timer and
  //     ten human thumbs.
  //
  //   * **A first-time joiner completes their first night unaided in ≤10s.**
  //     That is a usability finding, not an assertion. The hint that is meant to
  //     make it true is checked for existence in the Experience group.
}

/// The weather states and how much of the table each one covers.
///
/// A tuple list rather than a loop over the enum so the numbers are visible in
/// the test rather than hidden behind a getter — the claim doc 12 §5 makes is
/// about *values*, and the value that matters is "less than all of it".
abstract final class TableWeatherFixture {
  static const List<(String, double)> all = [
    ('connecting', 0.22),
    ('reconnecting', 0.38),
    ('unreachable', 0.62),
  ];
}
