import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/online_backend.dart';
import '../screens/online/online_session.dart';

/// Find and invite anyone (`friends` edge function, 20260930000100_invites_push.sql).
///
/// Rows carry public identity only: handle, name, gender, level, a coarse
/// state, and the frame and plate the person equipped. No user id: an invite
/// to someone who is not a friend names their handle.

enum DirectoryPresence { away, online, lobby, playing }

class DirectoryRow {
  final String handle;
  final String name;
  final String gender;
  final int level;
  final DirectoryPresence presence;
  final bool friend;
  final String? frame;
  final String? plate;
  const DirectoryRow({
    required this.handle,
    required this.name,
    this.gender = 'unspecified',
    this.level = 1,
    this.presence = DirectoryPresence.away,
    this.friend = false,
    this.frame,
    this.plate,
  });

  static DirectoryRow? fromJson(Object? json) {
    if (json is! Map || json['handle'] is! String) return null;
    return DirectoryRow(
      handle: json['handle'] as String,
      name: (json['name'] as String?) ?? '?',
      gender: (json['gender'] as String?) ?? 'unspecified',
      level: (json['level'] as num?)?.toInt() ?? 1,
      presence: switch (json['state']) {
        'online' => DirectoryPresence.online,
        'lobby' => DirectoryPresence.lobby,
        'playing' => DirectoryPresence.playing,
        _ => DirectoryPresence.away,
      },
      friend: json['friend'] == true,
      frame: json['frame'] is String ? json['frame'] as String : null,
      plate: json['plate'] is String ? json['plate'] as String : null,
    );
  }
}

class DirectoryPage {
  final List<DirectoryRow> rows;
  final bool more;
  const DirectoryPage(this.rows, {this.more = false});
  static const empty = DirectoryPage([]);

  static DirectoryPage fromJson(Map<String, dynamic> json) => DirectoryPage([
    for (final row in (json['rows'] is List ? json['rows'] as List : const []))
      ?DirectoryRow.fromJson(row),
  ], more: json['more'] == true);
}

/// «ناس قريبة» filter chips.
enum DiscoverFilter { near, online, played, level }

/// The caller's own entry: handle and the two switches.
class DirectoryMe {
  final String? handle;
  final bool searchable;
  final bool strangerInvites;
  final DateTime? handleChangeAt;
  const DirectoryMe({
    this.handle,
    this.searchable = true,
    this.strangerInvites = true,
    this.handleChangeAt,
  });

  static DirectoryMe fromJson(Object? json) {
    if (json is! Map) return const DirectoryMe();
    return DirectoryMe(
      handle: json['handle'] is String ? json['handle'] as String : null,
      searchable: json['searchable'] != false,
      strangerInvites: json['strangerInvites'] != false,
      handleChangeAt: json['handleChangeAt'] is String
          ? DateTime.tryParse(json['handleChangeAt'] as String)
          : null,
    );
  }
}

/// Why a handle change was refused.
enum HandleRefusal { taken, tooSoon, refused, invalid, failed }

/// An invite waiting for this player.
class IncomingInvite {
  final String id;
  final String code;
  final String name;
  final String? handle;
  final String gender;
  final String? frame;
  final String? plate;
  const IncomingInvite({
    required this.id,
    required this.code,
    required this.name,
    this.handle,
    this.gender = 'unspecified',
    this.frame,
    this.plate,
  });

  static IncomingInvite? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String || json['code'] is! String) {
      return null;
    }
    return IncomingInvite(
      id: json['id'] as String,
      code: json['code'] as String,
      name: (json['name'] as String?) ?? '?',
      handle: json['handle'] is String ? json['handle'] as String : null,
      gender: (json['gender'] as String?) ?? 'unspecified',
      frame: json['frame'] is String ? json['frame'] as String : null,
      plate: json['plate'] is String ? json['plate'] as String : null,
    );
  }
}

/// The calls. Overridden in tests; never called from a build method.
class DirectoryApi {
  final Ref _ref;
  DirectoryApi(this._ref);

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final backend = await _ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('friends', body);
  }

  Future<DirectoryPage> search(String query, {int page = 0}) async =>
      DirectoryPage.fromJson(
        await _call({'action': 'search', 'query': query, 'page': page}),
      );

  Future<DirectoryPage> discover(DiscoverFilter? filter, {int page = 0}) async =>
      DirectoryPage.fromJson(
        await _call({
          'action': 'discover',
          'filter': ?filter?.name,
          'page': page,
        }),
      );

  /// True when the invite was accepted by the server.
  Future<bool> inviteHandle(String handle, String roomId) async {
    try {
      await _call({'action': 'invite', 'handle': handle, 'roomId': roomId});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DirectoryMe> hello({
    required String name,
    required String gender,
    required String tz,
    required String locale,
  }) async => DirectoryMe.fromJson(
    await _call({
      'action': 'hello',
      'name': name,
      'gender': gender,
      'tz': tz,
      'locale': locale,
    }),
  );

  Future<DirectoryMe> me() async =>
      DirectoryMe.fromJson(await _call({'action': 'me'}));

  /// The new entry, or why not.
  Future<(DirectoryMe?, HandleRefusal?)> setHandle(String handle) async {
    try {
      return (
        DirectoryMe.fromJson(
          await _call({'action': 'setHandle', 'handle': handle}),
        ),
        null,
      );
    } on BackendException catch (e) {
      return (
        null,
        switch (e.message) {
          'HANDLE_TAKEN' => HandleRefusal.taken,
          'RATE_LIMITED' => HandleRefusal.tooSoon,
          'NAME_NOT_ALLOWED' => HandleRefusal.refused,
          'invalid request' || 'BAD_REQUEST' => HandleRefusal.invalid,
          _ => HandleRefusal.failed,
        },
      );
    } catch (_) {
      return (null, HandleRefusal.failed);
    }
  }

  Future<DirectoryMe> prefs({bool? searchable, bool? strangerInvites}) async =>
      DirectoryMe.fromJson(
        await _call({
          'action': 'prefs',
          'searchable': ?searchable,
          'strangerInvites': ?strangerInvites,
        }),
      );

  Future<List<IncomingInvite>> inbox() async {
    final json = await _call({'action': 'inbox'});
    final rows = json['invites'];
    return [
      for (final row in (rows is List ? rows : const [])) ?IncomingInvite.fromJson(row),
    ];
  }

  /// The room code to open, or null when the room already started or closed.
  Future<String?> respond(String inviteId, {required bool accept}) async {
    final json = await _call({
      'action': 'respondInvite',
      'inviteId': inviteId,
      'accept': accept,
    });
    return json['open'] == true && json['code'] is String
        ? json['code'] as String
        : null;
  }

  Future<void> registerPush(String token, String platform) =>
      _call({'action': 'registerPush', 'token': token, 'platform': platform});
}

final directoryApiProvider = Provider<DirectoryApi>(DirectoryApi.new);
