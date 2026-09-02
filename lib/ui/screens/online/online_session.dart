import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/enums.dart';
import '../../../engine/models/match_settings.dart';
import '../../../transport/online_backend.dart';
import '../../../transport/online_transport.dart';
import '../../../transport/supabase_backend.dart';

/// Where the project lives.
///
/// Compile-time, through `--dart-define`, so a release build cannot be pointed
/// at a different server at runtime and a build with no project simply has no
/// online mode rather than a button that fails. There is no key in the
/// repository: the publishable key is not a secret in the way a service key is,
/// but it is still per-deployment, and a checked-in one is a checked-in one.
///
///   flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_KEY=…
///
/// Or, so the pair travels together and stays out of shell history:
/// copy `dart_defines.example.json` to `dart_defines.json` (git-ignored),
/// fill it in, and
///
///   flutter run --dart-define-from-file=dart_defines.json
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String key = String.fromEnvironment('SUPABASE_KEY');

  /// Whether this build has a server to talk to at all.
  static bool get isConfigured => url.isNotEmpty && key.isNotEmpty;
}

/// How the backend is made.
///
/// A provider rather than a constructor call so that a widget test can hand the
/// lobby a fake and drive the whole flow without a network — which is the only
/// way the lobby's own behaviour (a refused code, a full room, a host that
/// left) can be tested at all.
final onlineBackendFactoryProvider =
    Provider<Future<OnlineBackend> Function()>((ref) {
  return () => SupabaseBackend.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.key,
      );
});

/// How often a client says it is here, checks the host still is, and applies a
/// phase's expiry default.
///
/// Overridable so a widget test can set it to zero and leave no timer running
/// behind the tree — and so a slow network can be given a longer beat without
/// touching the transport.
final onlineHeartbeatProvider =
    Provider<Duration>((ref) => const Duration(seconds: 15));

/// What the online screens are looking at.
@immutable
class OnlineSessionState {
  /// True while a call is in flight. Drives the buttons, not a full-screen
  /// spinner: doc 11 O9 — never a blank spinner.
  final bool busy;

  /// The room this device is in, or null before it joins one.
  final RoomHandle? room;

  /// The live transport, once there is one.
  final OnlineTransport? transport;

  /// The last refusal, as a code from `_shared/api.ts`. The screens turn it
  /// into a sentence; keeping the code means the screen decides the wording and
  /// the transport never carries English.
  final String? errorCode;

  /// True when the failure was "no server" rather than "the server said no".
  final bool unreachable;
  final bool projectPaused;

  const OnlineSessionState({
    this.busy = false,
    this.room,
    this.transport,
    this.errorCode,
    this.unreachable = false,
    this.projectPaused = false,
  });

  bool get isInRoom => room != null && transport != null;

  OnlineSessionState copyWith({
    bool? busy,
    RoomHandle? room,
    OnlineTransport? transport,
    String? errorCode,
    bool? unreachable,
    bool? projectPaused,
    bool clearError = false,
  }) =>
      OnlineSessionState(
        busy: busy ?? this.busy,
        room: room ?? this.room,
        transport: transport ?? this.transport,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        unreachable: clearError ? false : (unreachable ?? this.unreachable),
        projectPaused:
            clearError ? false : (projectPaused ?? this.projectPaused),
      );
}

/// Creating, joining, starting and leaving an online room.
///
/// Everything here is a call and an error code. It holds no game state at all —
/// once a room is joined, the transport is the state and the ordinary match
/// screens render it, which is the whole point of the seam.
class OnlineSession extends Notifier<OnlineSessionState> {
  OnlineBackend? _backend;

  @override
  OnlineSessionState build() {
    ref.onDispose(() {
      unawaited(state.transport?.dispose());
    });
    return const OnlineSessionState();
  }

  Future<OnlineBackend> _ensureBackend() async =>
      _backend ??= await ref.read(onlineBackendFactoryProvider)();

  /// Hosts a new room and takes seat 0.
  Future<void> host(String name) => _enter((backend) async {
        final handle = await backend.createRoom(name: name.trim());
        return handle;
      });

  /// Joins by code, or rejoins a seat this user already holds (O4).
  Future<void> join({required String code, required String name}) =>
      _enter((backend) async {
        final handle = await backend.joinRoom(
          code: code.trim().toUpperCase(),
          name: name.trim(),
        );
        return handle;
      });

  Future<void> _enter(
    Future<RoomHandle> Function(OnlineBackend backend) action,
  ) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final backend = await _ensureBackend();
      await backend.ensureSession();
      final handle = await action(backend);
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: handle.roomId,
        heartbeatInterval: ref.read(onlineHeartbeatProvider),
      );
      state = OnlineSessionState(room: handle, transport: transport);
    } on BackendException catch (e) {
      state = state.copyWith(busy: false, errorCode: e.code);
    } on BackendUnreachable catch (e) {
      // O9 and O11 — a distinct, actionable message, and the offer of a game
      // that does not need a server at all.
      state = state.copyWith(
        busy: false,
        errorCode: 'UNREACHABLE',
        unreachable: true,
        projectPaused: e.projectPaused,
      );
    }
  }

  /// Deals the roles and starts the match. Host only; the server checks.
  Future<bool> start({
    required Map<Role, int> roleCounts,
    required MatchSettings settings,
  }) async {
    final room = state.room;
    final backend = _backend;
    if (room == null || backend == null) return false;

    state = state.copyWith(busy: true, clearError: true);
    try {
      await backend.call('start_match', {
        'roomId': room.roomId,
        'roles': {
          for (final entry in roleCounts.entries) entry.key.name: entry.value,
        },
        'settings': _settingsJson(settings),
      });
      // The reveal phase is now open. Every client finds out from Realtime,
      // including this one — the host does not get a private head start.
      state = state.copyWith(busy: false);
      return true;
    } on BackendException catch (e) {
      state = state.copyWith(busy: false, errorCode: e.code);
      return false;
    } on BackendUnreachable {
      state = state.copyWith(busy: false, errorCode: 'UNREACHABLE', unreachable: true);
      return false;
    }
  }

  /// Leaves the room. In the lobby that is a departure and the seats re-pack;
  /// mid-match it is only a disconnection and the seat is kept (O4, O5).
  Future<void> leave() async {
    final room = state.room;
    final backend = _backend;
    final transport = state.transport;
    if (room != null && backend != null) {
      try {
        await backend.call('leave_room', {'roomId': room.roomId});
      } catch (_) {
        // Leaving is not a thing that can fail in a way the player can act on.
        // If the call did not land, the room notices in thirty seconds.
      }
    }
    await transport?.dispose();
    _backend = null;
    state = const OnlineSessionState();
  }

  /// The subset of the rules the server needs to know about. Deliberately not
  /// the whole object: the audio settings, the haptics and the hold duration
  /// are properties of a *device*, and sending them would invite a client to
  /// think another client's are its business.
  Map<String, dynamic> _settingsJson(MatchSettings settings) => {
        'speechSeconds': settings.speechSeconds,
        // The server reads this too: the mic policy for `discuss` is "one at a
        // time" in a structured discussion and "open" in a free one, and it is
        // refusing the floor against the same table the client mutes against.
        'discussionMode': settings.discussionMode.name,
        'confrontationSeconds': settings.confrontationSeconds,
        'abstainAllowed': settings.abstainAllowed,
        'whisperEnabled': settings.whisperEnabled,
        'traceEnabled': settings.traceEnabled,
        'confrontationEnabled': settings.confrontationEnabled,
        'openingRoundEnabled': settings.openingRoundEnabled,
        'survivorConfrontationEnabled': settings.survivorConfrontationEnabled,
        'dayTieRule': settings.dayTieRule.name,
      };
}

final onlineSessionProvider =
    NotifierProvider<OnlineSession, OnlineSessionState>(OnlineSession.new);
