import 'dart:async';

import '../engine/models/enums.dart';
import 'online_backend.dart';

/// One night choice, as the dead see it: who chose what, about whom.
class WitnessAction {
  final int night;
  final int seat;

  /// `kill`, `protect`, `investigate` or `suspect` — the server's own words.
  final String action;
  final int targetSeat;

  const WitnessAction({
    required this.night,
    required this.seat,
    required this.action,
    required this.targetSeat,
  });
}

/// The whole table, open. Only ever handed to an eliminated player: the
/// server's `witness_view` refuses everyone alive (owner decision 2026-09-23,
/// recorded in doc 12 §4.1).
class WitnessTable {
  final Map<int, Role> roles;
  final List<WitnessAction> actions;

  const WitnessTable({required this.roles, required this.actions});

  static WitnessTable fromJson(Map<String, dynamic> json) {
    Role? role(Object? name) =>
        Role.values.where((r) => r.name == name).firstOrNull;
    return WitnessTable(
      roles: {
        for (final row in (json['roles'] as List? ?? const []).cast<Map>())
          if (row['seat'] is int && role(row['role']) != null)
            row['seat'] as int: role(row['role'])!,
      },
      actions: [
        for (final row in (json['actions'] as List? ?? const []).cast<Map>())
          if (row['night'] is int &&
              row['seat'] is int &&
              row['targetSeat'] is int &&
              row['action'] is String)
            WitnessAction(
              night: row['night'] as int,
              seat: row['seat'] as int,
              action: row['action'] as String,
              targetSeat: row['targetSeat'] as int,
            ),
      ],
    );
  }
}

/// One thing said in the graveyard.
class GhostMessage {
  final String id;

  /// The seat that said it, or null when the author has left the roster
  /// entirely — which is a thing that can happen to a lobby departure and must
  /// render as a message from nobody rather than as a crash.
  final int? seat;

  final String authorName;
  final String body;
  final DateTime at;

  /// True when this device wrote it.
  final bool mine;

  const GhostMessage({
    required this.id,
    required this.seat,
    required this.authorName,
    required this.body,
    required this.at,
    required this.mine,
  });
}

/// Witness mode's half of the transport (doc 12 §4).
///
/// ## Why it is a separate interface, exactly like [VoiceLink]
///
/// For the same reason and with the same shape. A transport hands back a
/// `WitnessChannel?`, and offline it hands back null — because offline an
/// eliminated player is *still sitting at the table*, which is the whole
/// premise doc 12 §4 opens with. There is nothing to replace and nothing to
/// simulate.
///
/// The nullability is doing real work beyond that. Ghost chat and the
/// prediction panel are the two features in the app with no bearing whatsoever
/// on the rules: no method on [GameTransport] can fail because this one is
/// broken, no [GameSnapshot] field carries anything from it, and a match plays
/// to its end with every call below throwing. That is not an accident of the
/// design; it is the reason the design is this shape.
///
/// ## The wall
///
/// Doc 12 §4.1: *"Hard-walled: no channel from dead to living exists in the
/// app."* This interface is where a client could break that, so it does not
/// offer the means: there is no method to send anywhere but the graveyard, no
/// method to read a living player's view, and [messages] is a stream the server
/// refuses to a living subscriber. The enforcement is in
/// `ghost_messages_dead_read` and in `ghost_say`; this file is only careful not
/// to hand anybody a door.
abstract class WitnessChannel {
  /// Everything said in the graveyard, oldest first, and everything said from
  /// now on.
  ///
  /// Empty and silent for a living player — not filtered, refused: the read
  /// policy returns no rows and the subscription delivers none.
  Stream<List<GhostMessage>> messages();

  /// Says one thing. Refused by the server if this client is still alive.
  Future<void> say(String body);

  /// This device's locked-in call, or null if it has not made one.
  Future<Prediction?> myPrediction();

  /// Locks a call in. Returns false when one was already lodged — which is an
  /// ordinary answer, not a failure: doc 12 §4.1 says locked once submitted.
  Future<bool> predict(Prediction prediction);

  /// Every role and every night choice so far, or null when the server
  /// refuses (this player is alive) or cannot be reached. Never throws.
  Future<WitnessTable?> table();

  /// Stops listening. Called when the match ends or the screen goes away.
  Future<void> dispose();
}

/// The live one, over the room's backend.
class BackendWitnessChannel implements WitnessChannel {
  final OnlineBackend backend;
  final String roomId;
  final Set<String> Function()? blocked;
  List<GhostRow> _rows = const [];

  /// Seat and display name for a user id, re-read from the roster each time a
  /// batch arrives. A message from a player who joined after this channel was
  /// built still renders with their name.
  final Map<String, ({int seat, String name})> Function() roster;

  BackendWitnessChannel({
    required this.backend,
    required this.roomId,
    required this.roster,
    this.blocked,
  });

  StreamSubscription<List<GhostRow>>? _feed;
  StreamController<List<GhostMessage>>? _out;

  @override
  Stream<List<GhostMessage>> messages() {
    final existing = _out;
    if (existing != null) return existing.stream;

    final out = StreamController<List<GhostMessage>>.broadcast(
      onCancel: () => _feed?.cancel(),
    );
    _out = out;
    _feed = backend.ghostMessages(roomId).listen(
      (rows) {
        _rows = rows;
        if (out.isClosed) return;
        final who = roster();
        out.add([
          for (final row in rows)
            if (!(blocked?.call().contains(row.authorId) ?? false))
              GhostMessage(
                id: row.id,
                seat: who[row.authorId]?.seat,
                authorName: who[row.authorId]?.name ?? '',
                body: row.body,
                at: row.at,
                mine: row.authorId == backend.userId,
              ),
        ]);
      },
      // A graveyard that stopped updating is a quiet graveyard, not a broken
      // match. Nothing above this is allowed to care.
      onError: (_) {},
    );
    return out.stream;
  }

  @override
  Future<void> say(String body) =>
      backend.call('ghost_say', {'roomId': roomId, 'body': body}).then((_) {});

  void refreshBlocks() {
    final out = _out;
    if (out == null || out.isClosed) return;
    final who = roster();
    out.add([
      for (final row in _rows)
        if (!(blocked?.call().contains(row.authorId) ?? false))
          GhostMessage(
            id: row.id,
            seat: who[row.authorId]?.seat,
            authorName: who[row.authorId]?.name ?? '',
            body: row.body,
            at: row.at,
            mine: row.authorId == backend.userId,
          ),
    ]);
  }

  @override
  Future<Prediction?> myPrediction() => backend.myPrediction(roomId);

  @override
  Future<bool> predict(Prediction prediction) async {
    try {
      await backend.call('submit_prediction', {
        'roomId': roomId,
        'winner': prediction.winner.name,
        'mafiaSeats': prediction.mafiaSeats.toList()..sort(),
      });
      return true;
    } on BackendException catch (e) {
      // The only refusal a screen can act on: one was already lodged.
      if (e.code == 'RATE_LIMITED') return false;
      rethrow;
    }
  }

  @override
  Future<WitnessTable?> table() async {
    try {
      final json = await backend.call('witness_view', {'roomId': roomId});
      return WitnessTable.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await _feed?.cancel();
    _feed = null;
    await _out?.close();
    _out = null;
  }
}
