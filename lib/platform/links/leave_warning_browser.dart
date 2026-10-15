import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.EventListener? _listener;

void setLeaveWarning(bool on) {
  try {
    if (on && _listener == null) {
      final listener = ((web.Event event) {
        event.preventDefault();
        // Older browsers show the prompt only when a value is set.
        (event as web.BeforeUnloadEvent).returnValue = '';
      }).toJS;
      _listener = listener;
      web.window.addEventListener('beforeunload', listener);
    } else if (!on && _listener != null) {
      web.window.removeEventListener('beforeunload', _listener);
      _listener = null;
    }
  } catch (_) {
    /* A browser without the event simply never asks. */
  }
}
