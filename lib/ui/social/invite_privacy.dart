import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while this phone shows something private: a role card, a night
/// turn, a hand-off, a pass-and-play vote (Doc 05). An incoming invite never
/// interrupts that; it waits in the queue for the next public moment.
///
/// Written by the two match flows (pass-and-play and online) after each
/// frame, read by [IncomingInviteHost].
final privateMomentProvider = StateProvider<bool>((_) => false);

/// Schedules [private] for after this frame (a provider cannot change while
/// the tree builds). Only writes on a change.
void reportPrivateMoment(WidgetRef ref, bool private) {
  final notifier = ref.read(privateMomentProvider.notifier);
  if (notifier.state == private) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (notifier.state != private) notifier.state = private;
  });
}
