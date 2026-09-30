import 'dart:async';
import 'dart:js_interop';

import '../../ui/theme/design_tokens.dart';

@JS('mafiaH5Break')
external void _h5Break(
  JSString client,
  JSString type,
  JSString name,
  JSFunction done,
);

@JS('mafiaH5Banner')
external void _h5Banner(JSString client, JSString slot, JSFunction done);
@JS('mafiaH5HideBanner')
external void _hideBanner();

Future<bool> tryH5Break(String client, String type, String name) async {
  if (!RegExp(r'^ca-pub-[0-9]{16}$').hasMatch(client)) return false;
  final done = Completer<bool>();
  try {
    _h5Break(
      client.toJS,
      type.toJS,
      name.toJS,
      ((JSBoolean shown) {
        if (!done.isCompleted) done.complete(shown.toDart);
      }).toJS,
    );
    return await done.future.timeout(
      WebAdTokens.googleBreakTimeout,
      onTimeout: () => false,
    );
  } catch (_) {
    return false;
  }
}

Future<bool> tryH5Banner(String client, String slot) async {
  if (!RegExp(r'^ca-pub-[0-9]{16}$').hasMatch(client) ||
      !RegExp(r'^[0-9]{5,20}$').hasMatch(slot)) {
    return false;
  }
  final done = Completer<bool>();
  try {
    _h5Banner(
      client.toJS,
      slot.toJS,
      ((JSBoolean shown) {
        if (!done.isCompleted) done.complete(shown.toDart);
      }).toJS,
    );
    return await done.future.timeout(
      WebAdTokens.googleBannerTimeout,
      onTimeout: () => false,
    );
  } catch (_) {
    return false;
  }
}

void hideH5Banner() {
  try {
    _hideBanner();
  } catch (_) {}
}
