import 'dart:math' show Random;

import 'world.dart';

/// How a table plays, from its size (docs/plans/STORIES-V2-PLAN.md §2.1).
enum StoryTableMode {
  /// One player: he is the story's detective, four suspects on the table.
  solo,

  /// 2–4: every player is a suspect; nobody knows who did it, not even him.
  allSuspects,

  /// 5–10: one player is the detective; the killer knows.
  detective,
}

StoryTableMode storyTableModeFor(int players) => players <= 1
    ? StoryTableMode.solo
    : players <= 4
    ? StoryTableMode.allSuspects
    : StoryTableMode.detective;

/// What a seat is, as the seat's own player learns it.
enum StorySeatRole { detective, killer, partner, innocent, unknown }

/// Who did it in one version, as a story session on the server chose it.
class StoryCulpritPick {
  const StoryCulpritPick({required this.culpritId, this.partnerId});

  final String culpritId;
  final String? partnerId;
}

class StoryTableSeat {
  const StoryTableSeat({required this.player, this.suspectId});

  /// The name the table typed.
  final String player;

  /// The character this seat plays; null for the detective's seat.
  final String? suspectId;

  bool get isDetective => suspectId == null;
}

/// One assembled version of a world: who sits, who did it, what each place
/// holds. Built only from authored text; it never writes a sentence.
class StoryTable {
  const StoryTable._({
    required this.world,
    required this.mode,
    required this.seats,
    required this.suspectIds,
    required this.culpritId,
    required this.partnerId,
  });

  static const soloSuspects = 4;
  static const searches = 3;

  final StoryWorld world;
  final StoryTableMode mode;

  /// Player seats in hand-off order. Solo has one seat, the detective's.
  final List<StoryTableSeat> seats;

  /// The suspects in play, in seat order (solo: the four on the table).
  final List<String> suspectIds;
  final String culpritId;
  final String? partnerId;

  /// Deals a version. The same world, players and seed always deal the same
  /// table; [recentCulprits] (this phone's last culprits for this story) are
  /// avoided while another seated suspect is left to choose.
  ///
  /// [pick] is the server's choice of who did it (story sessions): the deal
  /// seats that suspect and plays the partner exactly when the pick names
  /// one. A pick this world cannot play throws [ArgumentError].
  factory StoryTable.deal({
    required StoryWorld world,
    required List<String> players,
    required int seed,
    Set<String> recentCulprits = const {},
    StoryCulpritPick? pick,
  }) {
    if (players.isEmpty || players.length > 10) {
      throw ArgumentError.value(players.length, 'players', 'must be 1–10');
    }
    final rng = Random(seed);
    final mode = storyTableModeFor(players.length);
    final count = switch (mode) {
      StoryTableMode.solo => soloSuspects,
      StoryTableMode.allSuspects => players.length,
      StoryTableMode.detective => players.length - 1,
    };
    final pool = [for (final s in world.suspects) s.id]..shuffle(rng);
    final seated = pool.take(count).toList();

    final String culprit;
    if (pick != null) {
      if (!pool.contains(pick.culpritId)) {
        throw ArgumentError.value(pick.culpritId, 'pick', 'not in this world');
      }
      final option = world.suspect(pick.culpritId).guilty.partner;
      if (pick.partnerId != null &&
          (mode != StoryTableMode.detective ||
              option?.partnerId != pick.partnerId)) {
        throw ArgumentError.value(pick.partnerId, 'pick', 'not a partner here');
      }
      culprit = pick.culpritId;
      if (!seated.contains(culprit)) seated[rng.nextInt(count)] = culprit;
    } else {
      final fresh = [
        for (final id in seated)
          if (!recentCulprits.contains(id)) id,
      ];
      final candidates = fresh.isEmpty ? seated : fresh;
      culprit = candidates[rng.nextInt(candidates.length)];
    }

    String? partner;
    final option = world.suspect(culprit).guilty.partner;
    final withPartner = pick != null
        ? pick.partnerId != null
        : mode == StoryTableMode.detective && option != null && rng.nextBool();
    if (withPartner) {
      partner = option!.partnerId;
      if (!seated.contains(partner)) {
        final innocents = [
          for (final id in seated)
            if (id != culprit) id,
        ];
        seated[seated.indexOf(innocents[rng.nextInt(innocents.length)])] =
            partner;
      }
    }

    final seats = <StoryTableSeat>[];
    switch (mode) {
      case StoryTableMode.solo:
        seats.add(StoryTableSeat(player: players.first));
      case StoryTableMode.allSuspects:
        for (final (i, name) in players.indexed) {
          seats.add(StoryTableSeat(player: name, suspectId: seated[i]));
        }
      case StoryTableMode.detective:
        final detectiveSeat = rng.nextInt(players.length);
        var next = 0;
        for (final (i, name) in players.indexed) {
          seats.add(
            i == detectiveSeat
                ? StoryTableSeat(player: name)
                : StoryTableSeat(player: name, suspectId: seated[next++]),
          );
        }
    }

    return StoryTable._(
      world: world,
      mode: mode,
      seats: List.unmodifiable(seats),
      suspectIds: List.unmodifiable(seated),
      culpritId: culprit,
      partnerId: partner,
    );
  }

  bool isGuilty(String suspectId) =>
      suspectId == culpritId || suspectId == partnerId;

  /// The seat playing [suspectId], or null when nobody plays him (solo).
  StoryTableSeat? seatOf(String suspectId) =>
      seats.where((s) => s.suspectId == suspectId).firstOrNull;

  StoryTableSeat? get detectiveSeat => mode == StoryTableMode.detective
      ? seats.firstWhere((s) => s.isDetective)
      : null;

  /// What [seat]'s own player is told. Only the 5–10 table has secrets.
  StorySeatRole roleOf(StoryTableSeat seat) {
    if (seat.isDetective) return StorySeatRole.detective;
    if (mode != StoryTableMode.detective) return StorySeatRole.unknown;
    if (seat.suspectId == culpritId) return StorySeatRole.killer;
    if (seat.suspectId == partnerId) return StorySeatRole.partner;
    return StorySeatRole.innocent;
  }

  /// Read at the start: what everyone knows, and why each suspect in play
  /// could have done it.
  List<String> get caseFacts => [
    ...world.baseFacts,
    for (final id in suspectIds) world.suspect(id).hook,
  ];

  /// Everything a search of [placeId] shows in this version.
  List<String> tracesAt(String placeId) {
    final found = [world.place(placeId).baseTrace];
    for (final id in suspectIds) {
      if (isGuilty(id)) continue;
      final trace = world.suspect(id).innocentTrace;
      if (trace.placeId == placeId) found.add(trace.text);
    }
    final guilt = world.suspect(culpritId).guilty;
    for (final trace in guilt.traces) {
      if (trace.placeId == placeId) found.add(trace.text);
    }
    if (partnerId != null) {
      for (final trace in guilt.partner!.traces) {
        if (trace.placeId == placeId) found.add(trace.text);
      }
    }
    return found;
  }

  /// The truth of this version, shown on screen after the decision.
  List<String> get reveal {
    final guilt = world.suspect(culpritId).guilty;
    return [guilt.reveal, if (partnerId != null) guilt.partner!.reveal];
  }

  /// Solo's why and how choices: the guilty modules of the suspects on the
  /// table, in a seeded order so the right one is not always first.
  List<WorldLabel> motives(int seed) => _shuffled([
    for (final id in suspectIds) world.suspect(id).guilty.motive,
  ], seed);

  List<WorldLabel> methods(int seed) => _shuffled([
    for (final id in suspectIds) world.suspect(id).guilty.method,
  ], seed + 1);

  static List<T> _shuffled<T>(List<T> items, int seed) =>
      List<T>.of(items)..shuffle(Random(seed));
}
