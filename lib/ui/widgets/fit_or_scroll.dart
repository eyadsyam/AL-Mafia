import 'package:flutter/material.dart';

/// Lays [child] (usually a [Column], which may hold an [Expanded]) out to fill
/// the height it is given, and lets it scroll when its content is taller than
/// that. On a short screen (a phone on its side) the content stays whole and
/// reachable instead of overflowing; on a tall one it looks exactly as before.
///
/// It measures [child] to do that, so everything inside must be able to say
/// how tall it is: a [LayoutBuilder] or a shrink-wrapped list cannot. For a
/// child that has one, use [CentredScroll].
///
/// Nothing here depends on what is inside, so a screen that reads the same for
/// every player scrolls the same for every player.
class FitOrScroll extends StatelessWidget {
  final Widget child;

  const FitOrScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

/// [child] centred in the height it is given, scrolling when it is taller.
/// Unlike [FitOrScroll] it never measures [child], so it takes anything that
/// has no [Expanded] in it.
class CentredScroll extends StatelessWidget {
  final Widget child;

  const CentredScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
