import 'dart:async';
import '../../../data/online_match_history.dart';
import '../../../data/online_session_store.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/enums.dart';
import '../../../engine/models/match_settings.dart';
import '../../../transport/game_snapshot.dart';
import '../../../transport/online_backend.dart';
import '../../../transport/online_transport.dart';
import '../../../transport/supabase_backend.dart';
import '../../theme/design_tokens.dart';

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
final onlineBackendFactoryProvider = Provider<Future<OnlineBackend> Function()>(
  (ref) {
    return () => SupabaseBackend.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.key,
    );
  },
);

/// How often a client says it is here, checks the host still is, and applies a
/// phase's expiry default. Ordinary roster and room events arrive immediately
/// through Realtime; this ten-second beat is only the liveness safety net.
///
/// Overridable so a widget test can set it to zero and leave no timer running
/// behind the tree — and so a slow network can be given a longer beat without
/// touching the transport.
final onlineHeartbeatProvider = Provider<Duration>(
  (ref) => MafiaTiming.onlineHeartbeat,
);

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

  /// Set when this device's storage refused a write the match does not depend
  /// on — the resume pointer or the finished-match summary. The match goes on;
  /// the player is told, once, that this device may not bring them back to the
  /// room by itself or keep the result. Cleared by [OnlineSession.dismissStorageWarning].
  final bool storageWarning;
  const OnlineSessionState({
    this.busy = false,
    this.room,
    this.transport,
    this.errorCode,
    this.unreachable = false,
    this.projectPaused = false,
    this.storageWarning = false,
  });

  bool get isInRoom => room != null && transport != null;

  OnlineSessionState copyWith({
    bool? busy,
    RoomHandle? room,
    OnlineTransport? transport,
    String? errorCode,
    bool? unreachable,
    bool? projectPaused,
    bool? storageWarning,
    bool clearError = false,
  }) => OnlineSessionState(
    busy: busy ?? this.busy,
    room: room ?? this.room,
    transport: transport ?? this.transport,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    unreachable: clearError ? false : (unreachable ?? this.unreachable),
    projectPaused: clearError ? false : (projectPaused ?? this.projectPaused),
    storageWarning: storageWarning ?? this.storageWarning,
  );
}

/// Creating, joining, starting and leaving an online room.
///
/// Everything here is a call and an error code. It holds no game state at all —
/// once a room is joined, the transport is the state and the ordinary match
/// screens render it, which is the whole point of the seam.
class OnlineSession extends Notifier<OnlineSessionState> {
  StreamSubscription<GameSnapshot>? _history;
  OnlineBackend? _backend;

  @override
  OnlineSessionState build() {
    ref.onDispose(() {
      _dropLifecycle();
      unawaited(_history?.cancel());
      unawaited(state.transport?.dispose());
    });
    return const OnlineSessionState();
  }

  Future<OnlineBackend> _ensureBackend() async =>
      _backend ??= await ref.read(onlineBackendFactoryProvider)();

  /// Hosts a new room and takes seat 0.
  Future<void> host(
    String name, {
    String gender = 'unspecified',
    Map<String, dynamic>? configuration,
  }) => _enter((backend) async {
    if (configuration != null) {
      final result = await backend.call('create_room', {
        ...configuration,
        'name': name.trim(),
        'gender': gender,
      });
      return RoomHandle(
        roomId: result['roomId'] as String,
        code: result['code'] as String,
        seat: 0,
      );
    }
    final handle = await backend.createRoom(name: name.trim(), gender: gender);
    return handle;
  });

  /// Joins by code, or rejoins a seat this user already holds (O4).
  Future<void> join({
    required String code,
    required String name,
    String gender = 'unspecified',
  }) async {
    await _enter((backend) async {
      final handle = await backend.joinRoom(
        code: code.trim().toUpperCase(),
        name: name.trim(),
        gender: gender,
      );
      return handle;
    });
    // A pointer to a room that no longer has a seat for this player — gone,
    // finished, closed to newcomers, or one they were removed from — is not a
    // pointer worth offering again. Only the server can say which it is, and
    // it just did.
    if (_obsoleteAfter.contains(state.errorCode)) {
      final stored = await OnlineSessionStore.load();
      if (stored != null && stored.code == code.trim().toUpperCase()) {
        await OnlineSessionStore.clear();
      }
    }
  }

  static const _obsoleteAfter = {
    'ROOM_NOT_FOUND',
    'ROOM_FINISHED',
    'NOT_A_MEMBER',
    'PHASE_CLOSED',
  };

  /// Forgets a stored room without going back into it.
  ///
  /// The seat is given up properly — `leave_room` frees a lobby seat and marks
  /// a playing one `left` — so the room is not left waiting on a player who
  /// has decided not to return. A room that refuses (already gone, already
  /// finished) is forgotten all the same; the refusal is the answer.
  Future<void> discardResume(OnlineRoomResume resume) async {
    try {
      final backend = await _ensureBackend();
      await backend.ensureSession();
      await backend.call('leave_room', {'roomId': resume.roomId});
    } catch (_) {
      // Nothing the player can act on: the pointer is what they asked to drop.
    }
    await OnlineSessionStore.clear();
  }

  void dismissStorageWarning() {
    if (!state.storageWarning) return;
    state = state.copyWith(storageWarning: false);
  }

  /// Drops a transport this session no longer stands behind. Idempotent.
  ///
  /// Called before a new room is entered as well as on leave: a device that
  /// went Home from a result or was removed from a room and then joined
  /// another used to keep the first transport alive — heartbeats to a room it
  /// had left, a second Realtime channel, and a voice link nobody could hear.
  Future<void> _teardown() async {
    await _history?.cancel();
    _history = null;
    _dropLifecycle();
    final transport = state.transport;
    if (transport == null) return;
    await transport.dispose();
    // The transport took its backend's channels with it; the next room gets
    // a fresh one, exactly as it would after `leave()`.
    _backend = null;
    // Nothing on the screens may keep rendering a transport that is gone.
    state = OnlineSessionState(
      busy: state.busy,
      storageWarning: state.storageWarning,
    );
  }

  /// Puts a refusal away without doing anything else.
  ///
  /// The entry screen shows one sentence per failure and asks two questions in
  /// order, so a refusal earned answering the second one must not still be on
  /// screen when the player steps back to the first. Nothing else about the
  /// session changes: a room already joined stays joined.
  void clearError() {
    if (state.errorCode == null) return;
    state = state.copyWith(clearError: true);
  }

  Future<void> _enter(
    Future<RoomHandle> Function(OnlineBackend backend) action,
  ) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _teardown();
      final backend = await _ensureBackend();
      await backend.ensureSession();
      final handle = await action(backend);
      // The server already owns the authoritative match. This pointer lets a
      // restarted client rejoin that same membership by code without storing
      // any role, private action, auth token, or voice credential locally.
      var storageWarning = false;
      try {
        await OnlineSessionStore.save(
          OnlineRoomResume(roomId: handle.roomId, code: handle.code),
        );
      } catch (_) {
        // Losing local resume storage must never prevent a successful join —
        // but the player is told, because the thing they lost is the way back.
        storageWarning = true;
      }
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: handle.roomId,
        heartbeatInterval: ref.read(onlineHeartbeatProvider),
      );
      _watchLifecycle(transport);
      await _history?.cancel();
      var saved = false;
      var saving = false;
      // `watch()` replays the current snapshot first, so a device that
      // reconnects to a room already on its result still writes the summary.
      _history = transport.watch().listen((snapshot) async {
        if (saved ||
            saving ||
            snapshot.outcome == null ||
            snapshot.phase != GamePhase.result)
          return;
        saving = true;
        try {
          await OnlineMatchHistory.save(
            roomId: handle.roomId,
            names: snapshot.public.players.map((p) => p.name).toList(),
            winner: snapshot.outcome!.winner.name,
            days: snapshot.dayNumber,
          );

          saved = true;
        } catch (_) {
          // History failure must never stop the match — it is over anyway —
          // but a result this device could not keep is worth one sentence.
          saved = true;
          state = state.copyWith(storageWarning: true);
        }
        try {
          await backend.call('economy', {'action': 'sync'});
        } catch (_) {
          // Rewards are idempotent and can be recovered when the player opens
          // the coin screen. A reward service outage never blocks a result.
        } finally {
          await OnlineSessionStore.clear();
          saving = false;
        }
      });
      state = OnlineSessionState(
        room: handle,
        transport: transport,
        storageWarning: storageWarning,
      );
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
    } catch (_) {
      // A 200 whose body is not the shape this client expects — a room with no
      // id, a snapshot that will not decode. Not a refusal and not "no
      // server"; still a sentence and a button that works again, rather than
      // a spinner that never stops.
      state = state.copyWith(busy: false, errorCode: 'BAD_RESPONSE');
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
      state = state.copyWith(
        busy: false,
        errorCode: 'UNREACHABLE',
        unreachable: true,
      );
      return false;
    }
  }

  /// The «أوض عامة» list: the only way a player picks a public room.
  ///
  /// Read-only on the server — looking never seats anybody. The entry screen
  /// re-reads it on a timer while it is visible (see `MafiaTiming`), and it
  /// throws on failure so that screen can keep the last good list and say it
  /// is out of date, rather than claim there are no rooms.
  Future<List<PublicRoom>> browse() async {
    final backend = await _ensureBackend();
    await backend.ensureSession();
    final result = await backend.call('browse_rooms', const {});
    return PublicRoom.ordered([
      for (final row in (result['rooms'] as List? ?? const []))
        PublicRoom.fromJson(Map<String, dynamic>.from(row as Map)),
    ]);
  }

  /// Leaves the room. In the lobby that is a departure and the seats re-pack;
  /// mid-match it is only a disconnection and the seat is kept (O4, O5).
  Future<void> leave() async {
    await _history?.cancel();
    _history = null;
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
    // Said before the transport goes, so the room learns it from this device
    // rather than from a clock ninety seconds later.
    try {
      await transport?.setPresence('left');
    } catch (_) {
      // A transport that is already gone has nothing left to say.
    }
    _dropLifecycle();
    await transport?.dispose();
    await OnlineSessionStore.clear();
    _backend = null;
    state = const OnlineSessionState();
  }

  _PresenceObserver? _lifecycle;

  /// Reports foreground and background straight to the room.
  ///
  /// Registered with the transport rather than in a widget, because the fact
  /// being reported is about the *app* and not about whichever screen happens
  /// to be mounted: a player who backgrounds the app from the vote screen and
  /// a player who backgrounds it from the lobby have both stepped away.
  void _watchLifecycle(OnlineTransport transport) {
    _dropLifecycle();
    final observer = _PresenceObserver(transport);
    _lifecycle = observer;
    WidgetsBinding.instance.addObserver(observer);
  }

  void _dropLifecycle() {
    final observer = _lifecycle;
    if (observer == null) return;
    _lifecycle = null;
    WidgetsBinding.instance.removeObserver(observer);
  }

  /// The subset of the rules the server needs to know about. Deliberately not
  /// the whole object: the audio settings, the haptics and the hold duration
  /// are properties of a *device*, and sending them would invite a client to
  /// think another client's are its business.
  Map<String, dynamic> _settingsJson(MatchSettings settings) => {
    'speechSeconds': settings.speechSeconds,
    'discussionSeconds': settings.discussionSeconds,
    // The server reads this too: the mic policy for `discuss` is "one at a
    // time" in a structured discussion and "open" in a free one, and it is
    // refusing the floor against the same table the client mutes against.
    'discussionMode': settings.discussionMode.name,
    'confrontationSeconds': settings.confrontationSeconds,
    // Doc 12 §3.6. The server reads it too: it decides whether the
    // ballot may be read while it is still open, so a client that lied
    // about it locally would still be refused the rows.
    'openVoting': settings.openVoting,
    'abstainAllowed': settings.abstainAllowed,
    'whisperEnabled': settings.whisperEnabled,
    'traceEnabled': settings.traceEnabled,
    'confrontationEnabled': settings.confrontationEnabled,
    'openingRoundEnabled': settings.openingRoundEnabled,
    'survivorConfrontationEnabled': settings.survivorConfrontationEnabled,
    // «الطلقة الواحدة» (doc 13 §2). The server reads these for itself:
    // `submit_night_action` validates a bullet against the *room's*
    // settings, so a client that lied about its own would be refused the
    // move rather than granted it.
    'bulletsEnabled': settings.bulletsEnabled,
    'quietNightEnabled': settings.quietNightEnabled,
    'selfProtectEnabled': settings.selfProtectEnabled,
    'dayTieRule': settings.dayTieRule.name,
  };
}

/// Turns the app's own lifecycle into the room's three presence states.
///
/// `paused` and `detached` are both "not looking at this" — the difference
/// between them is whether the process is still alive, which is not something
/// the table cares about. `hidden` and `inactive` are deliberately not here:
/// they fire for a notification shade being pulled down and for the app switcher
/// being opened, and emptying somebody's ring because they glanced at a
/// notification would make the signal meaningless.
class _PresenceObserver extends WidgetsBindingObserver {
  final OnlineTransport transport;

  _PresenceObserver(this.transport);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(transport.setPresence('connected'));
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(transport.setPresence('away'));
      case AppLifecycleState.inactive:
        break;
    }
  }
}

final onlineSessionProvider =
    NotifierProvider<OnlineSession, OnlineSessionState>(OnlineSession.new);
