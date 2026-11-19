import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'online_session.dart' show onlineBackendFactoryProvider;

/// O1 «استناني» and O2 «ليلة اللعب»: the `match_queue` edge function.
///
/// The queue lives on the server and survives the app being closed: five
/// queued players get a «الأوضة كملت» push and 60 seconds to say «أنا جاهز».
/// Nothing here holds game state; a matched player is simply told which room
/// he is now seated in ([QueueStatus.room]) and enters it like any other.

/// A room the server has seated this player in.
@immutable
class QueueRoom {
  final String roomId;
  final String code;
  final int seat;
  const QueueRoom({
    required this.roomId,
    required this.code,
    required this.seat,
  });

  static QueueRoom? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final roomId = raw['roomId'];
    final code = raw['code'];
    final seat = raw['seat'];
    if (roomId is! String || code is! String || seat is! num) return null;
    return QueueRoom(roomId: roomId, code: code, seat: seat.toInt());
  }
}

/// The open «جاهز؟» round this player is part of.
@immutable
class QueueRound {
  final String id;
  final DateTime deadline;
  final int confirmed;
  final int total;
  const QueueRound({
    required this.id,
    required this.deadline,
    required this.confirmed,
    required this.total,
  });

  static QueueRound? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final deadline = DateTime.tryParse('${raw['deadline']}');
    if (id is! String || deadline == null) return null;
    return QueueRound(
      id: id,
      deadline: deadline,
      confirmed: (raw['confirmed'] as num?)?.toInt() ?? 0,
      total: (raw['total'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class QueueStatus {
  final bool queued;
  final int count;
  final QueueRound? round;
  final bool meConfirmed;
  final QueueRoom? room;
  const QueueStatus({
    required this.queued,
    required this.count,
    this.round,
    this.meConfirmed = false,
    this.room,
  });

  static const idle = QueueStatus(queued: false, count: 0);

  factory QueueStatus.fromJson(Map<String, dynamic> json) => QueueStatus(
    queued: json['queued'] == true,
    count: (json['count'] as num?)?.toInt() ?? 0,
    round: QueueRound.fromJson(json['round']),
    meConfirmed: (json['me'] is Map) && (json['me'] as Map)['confirmed'] == true,
    room: QueueRoom.fromJson(json['room']),
  );
}

/// Today's (or the next) «ليلة اللعب» window, 21:00–22:00 Cairo time.
@immutable
class PlayNight {
  final DateTime startsAt;
  final DateTime endsAt;
  final bool active;
  final bool reminded;

  /// Only when five or more asked to be reminded; otherwise null.
  final int? remindedCount;
  final int queueCount;
  const PlayNight({
    required this.startsAt,
    required this.endsAt,
    required this.active,
    required this.reminded,
    required this.remindedCount,
    required this.queueCount,
  });

  static PlayNight? fromJson(Map<String, dynamic> json) {
    final starts = DateTime.tryParse('${json['startsAt']}');
    final ends = DateTime.tryParse('${json['endsAt']}');
    if (starts == null || ends == null) return null;
    return PlayNight(
      startsAt: starts,
      endsAt: ends,
      active: json['active'] == true,
      reminded: json['reminded'] == true,
      remindedCount: (json['remindedCount'] as num?)?.toInt(),
      queueCount: (json['queueCount'] as num?)?.toInt() ?? 0,
    );
  }

  PlayNight copyWith({bool? reminded}) => PlayNight(
    startsAt: startsAt,
    endsAt: endsAt,
    active: active,
    reminded: reminded ?? this.reminded,
    remindedCount: remindedCount,
    queueCount: queueCount,
  );
}

class MatchQueueApi {
  final Ref _ref;
  MatchQueueApi(this._ref);

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final backend = await _ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('match_queue', body);
  }

  Future<QueueStatus> status() async =>
      QueueStatus.fromJson(await _call({'action': 'status'}));

  Future<void> leave() => _call({'action': 'leave'});

  /// True when this player is now confirmed for the round.
  Future<bool> ready(String roundId, {required bool yes}) async {
    final answer = await _call({
      'action': 'ready',
      'roundId': roundId,
      'yes': yes,
    });
    return answer['confirmed'] == true;
  }

  Future<PlayNight?> playNight() async =>
      PlayNight.fromJson(await _call({'action': 'playNightStatus'}));

  Future<bool> remindPlayNight(bool on) async {
    final answer = await _call({'action': 'playNightRemind', 'on': on});
    return answer['reminded'] == true;
  }
}

final matchQueueApiProvider = Provider<MatchQueueApi>(MatchQueueApi.new);
