import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Public account labels kept on this device. Credentials stay with Supabase.
class RememberedAccount {
  final String userId;
  final String email;
  final String displayName;
  final String provider;
  final DateTime lastUsedAt;

  const RememberedAccount({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.provider,
    required this.lastUsedAt,
  });

  String get maskedEmail => maskEmail(email);

  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at < 1 || at == email.length - 1) return '***';
    return '${email[0]}***${email.substring(at)}';
  }

  Map<String, Object> toJson() => {
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'provider': provider,
    'lastUsedAt': lastUsedAt.toIso8601String(),
  };

  static RememberedAccount? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['userId'];
    final email = value['email'];
    final name = value['displayName'];
    final provider = value['provider'];
    final at = DateTime.tryParse('${value['lastUsedAt'] ?? ''}');
    if (id is! String ||
        id.isEmpty ||
        email is! String ||
        name is! String ||
        (provider != 'google' && provider != 'email') ||
        at == null) {
      return null;
    }
    return RememberedAccount(
      userId: id,
      email: email,
      displayName: name,
      provider: provider as String,
      lastUsedAt: at,
    );
  }
}

class RememberedAccounts {
  static const key = 'mafia.rememberedAccounts.v1';
  static const maxEntries = 5;

  Future<List<RememberedAccount>> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return [];
      final values = jsonDecode(raw);
      if (values is! List) return [];
      final entries = values
          .map(RememberedAccount.fromJson)
          .whereType<RememberedAccount>()
          .toList();
      entries.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      return entries.take(maxEntries).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(RememberedAccount account, {bool isAnonymous = false}) async {
    if (isAnonymous || account.userId.isEmpty || account.email.isEmpty) return;
    final entries = await load();
    entries.removeWhere((entry) => entry.userId == account.userId);
    entries.insert(0, account);
    await _write(entries.take(maxEntries).toList());
  }

  Future<void> remove(String userId) async {
    final entries = await load();
    entries.removeWhere((entry) => entry.userId == userId);
    await _write(entries);
  }

  Future<void> _write(List<RememberedAccount> entries) async {
    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}
