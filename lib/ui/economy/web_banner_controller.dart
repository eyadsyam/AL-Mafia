import 'dart:ui' show Rect;

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/monetization/web_ad_bridge.dart';

/// The one Google banner element in the page. Tests replace it with a fake.
abstract interface class WebBannerHost {
  void show(
    String client,
    String slot,
    Rect rect,
    void Function(bool filled) onFilled,
  );
  void hide();
}

class JsWebBannerHost implements WebBannerHost {
  const JsWebBannerHost();

  @override
  void show(
    String client,
    String slot,
    Rect rect,
    void Function(bool filled) onFilled,
  ) => showGoogleBanner(
    client,
    slot,
    rect.left,
    rect.top,
    rect.width,
    rect.height,
    onFilled,
  );

  @override
  void hide() => hideGoogleBanner();
}

/// One mounted [WebAdBanner]'s wish to own the Google overlay.
class WebBannerClaim {
  final String client;
  final String slot;

  /// Where the reserved slot is on screen right now, or null before layout.
  final Rect? Function() rect;

  /// Whether Google currently fills the unit this claim owns. Called only for
  /// the owner, and with false when ownership moves away.
  final void Function(bool filled) onFilled;

  WebBannerClaim({
    required this.client,
    required this.slot,
    required this.rect,
    required this.onFilled,
  });
}

/// The page has a single banner element but several banner widgets can be
/// mounted at once (Settings over Home, a waiting banner under a screen). The
/// controller keeps them in claim order: only the newest claim owns the
/// element, and when it goes away the one beneath gets it back, instead of the
/// element being hidden and leaving a blank gap on the screen underneath.
///
/// Nothing here runs inside a build. Claims and releases mark the controller
/// dirty and ask for a frame; the work happens after the frame has laid out,
/// where the slot's real position is known and widgets may be marked dirty.
class WebBannerController {
  WebBannerController(this._host);

  final WebBannerHost _host;
  final List<WebBannerClaim> _claims = [];
  WebBannerClaim? _owner;
  Rect? _placed;
  bool _dirty = false;
  bool _disposed = false;
  bool _pumping = false;

  /// Claims currently registered, newest last. For tests.
  int get claimCount => _claims.length;
  WebBannerClaim? get owner => _owner;

  void claim(WebBannerClaim claim) {
    _claims.remove(claim);
    _claims.add(claim);
    _markDirty();
  }

  void release(WebBannerClaim claim) {
    if (_claims.remove(claim)) _markDirty();
  }

  void _markDirty() {
    _dirty = true;
    _startPump();
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _startPump() {
    if (_pumping) return;
    _pumping = true;
    // Persistent callbacks cannot be removed, and run only when a frame is
    // produced anyway, so this adds no frames of its own.
    SchedulerBinding.instance.addPersistentFrameCallback((_) => sync());
  }

  /// Applies pending claim changes and follows the owner's slot. Runs after
  /// every frame while any claim exists.
  void sync() {
    if (_disposed) return;
    if (!_dirty && _owner == null) return;
    _dirty = false;
    final top = _claims.isEmpty ? null : _claims.last;
    if (top == null) {
      if (_owner != null) {
        _owner = null;
        _placed = null;
        _host.hide();
      }
      return;
    }
    if (!identical(top, _owner)) {
      final previous = _owner;
      if (previous != null && _claims.contains(previous)) {
        previous.onFilled(false);
      }
      _owner = top;
      _placed = null;
    }
    final rect = top.rect();
    if (rect == null || rect.isEmpty) return;
    if (rect == _placed) return;
    _placed = rect;
    _host.show(top.client, top.slot, rect, (filled) {
      if (_disposed || !identical(_owner, top) || !_claims.contains(top)) {
        return;
      }
      top.onFilled(filled);
    });
  }

  void dispose() {
    _disposed = true;
    _claims.clear();
    _owner = null;
    _host.hide();
  }
}

final webBannerHostProvider = Provider<WebBannerHost>(
  (_) => const JsWebBannerHost(),
);

final webBannerControllerProvider = Provider<WebBannerController>((ref) {
  final controller = WebBannerController(ref.watch(webBannerHostProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
