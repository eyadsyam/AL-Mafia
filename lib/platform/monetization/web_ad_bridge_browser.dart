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

@JS('mafiaBannerShow')
external void _bannerShow(
  JSString client,
  JSString slot,
  JSNumber left,
  JSNumber top,
  JSNumber width,
  JSNumber height,
  JSFunction onFilled,
);

@JS('mafiaBannerHide')
external void _bannerHide();

final _publisher = RegExp(r'^ca-pub-[0-9]{16}$');
final _slotShape = RegExp(r'^[0-9]{5,20}$');

Future<bool> tryH5Break(String client, String type, String name) async {
  if (!_publisher.hasMatch(client)) return false;
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

void showGoogleBanner(
  String client,
  String slot,
  double left,
  double top,
  double width,
  double height,
  void Function(bool filled) onFilled,
) {
  if (!_publisher.hasMatch(client) || !_slotShape.hasMatch(slot)) {
    onFilled(false);
    return;
  }
  try {
    _bannerShow(
      client.toJS,
      slot.toJS,
      left.toJS,
      top.toJS,
      width.toJS,
      height.toJS,
      ((JSBoolean filled) => onFilled(filled.toDart)).toJS,
    );
  } catch (_) {
    // Blockers must leave the house slot intact.
    onFilled(false);
  }
}

void hideGoogleBanner() {
  try {
    _bannerHide();
  } catch (_) {}
}
