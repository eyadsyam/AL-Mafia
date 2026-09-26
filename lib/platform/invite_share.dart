import 'package:flutter/widgets.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'clipboard.dart';

/// What happened when the host shared an invite. Nothing here ever means
/// "delivered": the system sheet does not tell anyone that.
enum InviteShareOutcome {
  /// The system sheet (Android) or Web Share (browser) took it, or was closed.
  /// The lobby says nothing; the player saw the sheet themselves.
  handedOver,

  /// No share sheet here; the link is on the clipboard instead.
  copied,

  /// Neither worked. The code is still on screen to be read out.
  failed,
}

typedef ShareSheet = Future<ShareResult> Function(ShareParams params);
typedef CopyText = Future<bool> Function(String text);

/// The OS share sheet for a room invite, with an honest copy fallback.
///
/// Android: the system chooser. The chosen app may open (that is how Android
/// sharing works); dismissing it returns to the same lobby, whose membership
/// and voice do not depend on the app being in front. Web: the Web Share API
/// from the tap itself; a browser without it gets the link copied instead.
class InviteSharer {
  final ShareSheet _share;
  final CopyText _copy;
  InviteSharer({ShareSheet? share, CopyText? copy})
    : _share = share ?? SharePlus.instance.share,
      _copy = copy ?? AppClipboard.copy;

  Future<InviteShareOutcome> share({
    required String text,
    required String subject,
    Rect? origin,
  }) async {
    try {
      await _share(
        ShareParams(
          text: text,
          subject: subject,
          sharePositionOrigin: origin,
          // No mail app detour on the web: copy instead.
          mailToFallbackEnabled: false,
          downloadFallbackEnabled: false,
        ),
      );
      // success, dismissed, and the web's post-share "unavailable" all mean
      // the sheet was shown. None of them is a delivery receipt.
      return InviteShareOutcome.handedOver;
    } catch (_) {
      return await _copy(text)
          ? InviteShareOutcome.copied
          : InviteShareOutcome.failed;
    }
  }
}

final inviteSharerProvider = Provider<InviteSharer>((ref) => InviteSharer());
