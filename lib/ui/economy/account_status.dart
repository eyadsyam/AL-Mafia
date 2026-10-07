import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/account_service.dart';
import '../screens/online/online_session.dart';

final accountServiceProvider = Provider<AccountService>(
  (ref) => SupabaseAccountService(ref.read(onlineBackendFactoryProvider)),
);

final accountStatusProvider = FutureProvider<AccountStatus>(
  (ref) => ref.read(accountServiceProvider).status(),
);
