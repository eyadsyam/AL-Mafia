import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'wallet.dart';

/// The owner grant, as the server's last wallet answer states it. The wallet
/// is re-read on every account change, so a sign-out or a switch closes it;
/// an unread wallet grants nothing. Store items need no check here: the
/// server already lists them as owned for a granted account.
final allAccessProvider = Provider<bool>(
  (ref) => ref.watch(walletProvider).valueOrNull?.allAccess ?? false,
);
