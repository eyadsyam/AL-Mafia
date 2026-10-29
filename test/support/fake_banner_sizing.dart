import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mafia_master/platform/monetization/ad_formats.dart';

/// A stand-in for Google's size lookup: the large anchored adaptive height is
/// a function of width and orientation only, never of an ad. [primed] false
/// models a session whose first size has not been resolved yet; the answer
/// then comes when [answer] completes.
class FakeSizing implements BannerSizing {
  final bool primed;
  final Completer<void> answer = Completer<void>();

  /// Added to every height, to model a taller or shorter answer.
  final int tall;
  int resolves = 0;

  FakeSizing({this.primed = true, this.tall = 0});

  /// Portrait: about a quarter of the width; landscape: a shallow strip.
  static int heightOf(int width, Orientation o) =>
      o == Orientation.landscape ? 60 : (width * 0.27).round();

  int _height(int width, Orientation o) => heightOf(width, o) + tall;

  @override
  BannerSize? peek(int width, Orientation o) =>
      primed ? BannerSize(width, _height(width, o)) : null;

  @override
  Future<BannerSize?> resolve(int width, Orientation o) async {
    resolves++;
    if (!primed) await answer.future;
    return BannerSize(width, _height(width, o));
  }
}
