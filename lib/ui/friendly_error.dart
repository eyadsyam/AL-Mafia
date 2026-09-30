import '../app/l10n/app_localizations.dart';
import '../transport/account_service.dart' show AccountFailure;
import '../transport/online_backend.dart';

/// The one place a server or network failure becomes a sentence a player can
/// read. No caller ever shows an exception, a code or a server message.
///
/// The codes are `ErrorCode` in `supabase/functions/_shared/api.ts`; a test
/// reads that union and requires every one of them to land here on a real
/// sentence, so a code added on the server cannot reach a player as silence or
/// as English.
///
/// A screen with a better, situation-specific sentence for a code (the room
/// list has its own for a full room) keeps it and asks this only for the rest.
String friendlyCode(
  AppLocalizations l,
  String code, {
  bool projectPaused = false,
}) => switch (code) {
  // The network, or a server that is not answering.
  'UNREACHABLE' => projectPaused ? l.onlineProjectPaused : l.errOffline,
  'UNAUTHENTICATED' => l.errSession,
  'RATE_LIMITED' => l.errRateLimited,

  // Rooms.
  'ROOM_NOT_FOUND' => l.onlineRoomNotFound,
  'ROOM_FULL' => l.onlineRoomFull,
  'ROOM_FINISHED' => l.onlineRoomFinished,
  'ROOM_UNAVAILABLE' => l.onlineRoomUnavailable,
  'PHASE_CLOSED' => l.onlineRoomStarted,
  'NOT_A_MEMBER' => l.onlineKickedByHost,
  'ALREADY_JOINED' || 'ALREADY_SEATED' => l.onlineAlreadySeated,
  'NEW_ROOMS_PAUSED' => l.onlineNewRoomsPaused,
  'NOT_HOST' => l.errNotHost,
  'IN_MATCH' => l.errInRoom,
  'NAME_NOT_ALLOWED' => l.onlineNameNotAllowed,
  'ACCOUNT_RESTRICTED' => l.onlineAccountRestricted,

  // Coins and the store.
  'INSUFFICIENT_COINS' => l.errCoins,
  'PURCHASE_REQUIRED' => l.errPurchaseRequired,
  'ALREADY_OWNED' => l.errAlreadyOwned,
  'ORDER_OPEN' => l.errOrderOpen,

  // Switched off, or not configured on the server yet.
  'NOT_CONFIGURED' ||
  'SALES_DISABLED' ||
  'FEATURE_OFF' ||
  'PACK_UNAVAILABLE' ||
  'METHOD_UNAVAILABLE' ||
  'DAILY_PAUSED' ||
  'PRODUCT_UNKNOWN' => l.errUnavailable,

  // Not this player's to do right now.
  'WRONG_ROLE' ||
  'NOT_ALIVE' ||
  'NOT_ADMIN' ||
  'WITNESS_ONLY' => l.errNotAllowed,

  // Everything else is the server saying "not like that": the honest player
  // sentence is that something failed and trying again is fine.
  _ => l.errGeneric,
};

/// [friendlyCode] for whatever was thrown: a server refusal, an unreachable
/// network, an account failure, or anything unexpected.
String friendlyError(AppLocalizations l, Object? error) {
  if (error is BackendException) return friendlyCode(l, error.code);
  if (error is BackendUnreachable) {
    return friendlyCode(l, 'UNREACHABLE', projectPaused: error.projectPaused);
  }
  if (error is AccountFailure) {
    return friendlyCode(
      l,
      error.code == 'UNAVAILABLE' ? 'FEATURE_OFF' : error.code,
    );
  }
  return l.errGeneric;
}
