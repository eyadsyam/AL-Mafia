import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';

/// The server's own envelope with every `economy_config.*_enabled` flag on,
/// generated from the migrations by supabase/tests/capabilities_wiring.test.mjs
/// (which also proves each flag changes the envelope). If the server renames
/// a key, that test rewrites the fixture and this one fails.
Map<String, dynamic> _allOn() =>
    jsonDecode(File('test/fixtures/capabilities_all_on.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('every server flag, all on, is on in the client', () {
    final caps = EconomyCapabilities.fromJson(_allOn());
    final on = <String, bool>{
      'adSteps': caps.adSteps,
      'daily': caps.daily,
      'dailyAd': caps.dailyAd,
      'caseOfDay': caps.caseOfDay,
      'metrics': caps.metrics,
      'reviewPrompt': caps.reviewPrompt,
      'lobbyReady': caps.lobbyReady,
      'missions': caps.missions,
      'thursday': caps.thursday,
      'titles': caps.titles,
      'partner': caps.partner,
      'economyV3': caps.economyV3,
      'council.contracts': caps.council.contracts,
      'council.rank': caps.council.rank,
      'council.leaderboard': caps.council.leaderboard,
      'council.invites': caps.council.invites,
      'council.starterBundle': caps.council.starterBundle,
      'ads.banner': caps.ads.banner,
      'ads.extras': caps.ads.extras,
      'ads.appOpen': caps.ads.appOpen.enabled,
      'interstitial': caps.interstitial.enabled,
      'fun.awards': caps.fun.awards,
      'fun.reactions': caps.fun.reactions,
      'fun.founder': caps.fun.founder,
      'fun.characterBonds': caps.fun.characterBonds,
      'social.friends': caps.friends,
      'social.directory': caps.directory,
      'social.pushInvites': caps.pushInvites,
      'safety.v11': caps.safetyV11,
      'witness.whispers': caps.witnessWhispers,
    };
    expect(
      on.entries.where((e) => !e.value).map((e) => e.key),
      isEmpty,
      reason: 'a server flag the client never turns on',
    );
  });

  test('every true leaf the server sends is a key the client reads', () {
    // The envelope is parsed here, and the interstitial rules in the policy
    // file (read only: that file is not this lane's).
    final source = [
      'lib/ui/economy/economy_capabilities.dart',
      'lib/platform/monetization/interstitial_policy.dart',
    ].map((path) => File(path).readAsStringSync()).join();
    final unread = <String>[];
    void walk(Map<String, dynamic> map, String path) {
      map.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          walk(value, '$path$key.');
        } else if (value == true && !source.contains("'$key'")) {
          unread.add('$path$key');
        }
      });
    }

    walk(_allOn(), '');
    expect(unread, isEmpty);
  });
}
