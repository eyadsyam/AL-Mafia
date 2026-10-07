import 'dart:async';

typedef ExternalLinkOpener = FutureOr<bool> Function(String url);

/// A browser tab reserved synchronously by the original tap.
///
/// The destination is supplied only after the server accepts the operation.
/// Cancelling closes the reserved tab, so a refused order never leaves a page
/// behind. Native launchers use a deferred reservation and open on [commit].
class ExternalLinkReservation {
  final FutureOr<bool> Function() _commit;
  final void Function() _cancel;
  bool _finished = false;

  ExternalLinkReservation({
    required FutureOr<bool> Function() commit,
    required void Function() cancel,
  }) : _commit = commit,
       _cancel = cancel;

  Future<bool> commit() async {
    if (_finished) return false;
    _finished = true;
    return await _commit();
  }

  void cancel() {
    if (_finished) return;
    _finished = true;
    _cancel();
  }
}

typedef ExternalLinkReserver = ExternalLinkReservation Function(String url);
