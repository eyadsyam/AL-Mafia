import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A refusal from an Edge Function is a *sentence*, not a broken cable.
///
/// `functions.invoke` throws on any non-2xx rather than returning a response
/// with a status on it, so the `if (status >= 400)` the backend used to run was
/// unreachable and every refusal fell through to the catch-all as
/// [BackendUnreachable]. A player who tapped half a second after the phase
/// closed was told the connection had dropped and that their choice was not
/// saved, when the truth was that the room had simply moved on and the client
/// should have resynced onto it.
void main() {
  test('a phase that closed is an event, not a disconnection', () {
    final refusal = SupabaseBackend.refusalFor(
      const FunctionsHttpException(
        status: 400,
        details: {'error': 'PHASE_CLOSED', 'message': 'the night is closed'},
      ),
    );
    expect(refusal, isA<BackendException>());
    expect((refusal as BackendException).code, equals('PHASE_CLOSED'));
    expect(refusal.isPhaseClosed, isTrue);
  });

  test('every other coded refusal keeps its code', () {
    for (final code in const [
      'NOT_HOST',
      'WRONG_ROLE',
      'NOT_ALIVE',
      'ROOM_FULL',
      'RATE_LIMITED',
      'NOT_A_MEMBER',
    ]) {
      final refusal = SupabaseBackend.refusalFor(
        FunctionsHttpException(
          status: 403,
          details: {'error': code, 'message': 'no'},
        ),
      );
      expect(refusal, isA<BackendException>());
      expect((refusal as BackendException).code, equals(code));
    }
  });

  test('a body with no code is still a refusal, not a dead network', () {
    final refusal = SupabaseBackend.refusalFor(
      const FunctionsHttpException(status: 400, details: 'nope'),
    );
    expect(refusal, isA<BackendException>());
    expect((refusal as BackendException).code, equals('BAD_REQUEST'));
  });

  test('a 5xx really is the server being away', () {
    final refusal = SupabaseBackend.refusalFor(
      const FunctionsHttpException(status: 503, details: 'project is paused'),
    );
    expect(refusal, isA<BackendUnreachable>());
    expect((refusal as BackendUnreachable).projectPaused, isTrue);
  });
}
