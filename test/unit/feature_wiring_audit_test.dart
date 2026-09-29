import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';

void main() {
  test('every release feature flag in the capability envelope is parsed', () {
    final caps = EconomyCapabilities.fromJson({
      'version': 2,
      'adSteps': true,
      'daily': true,
      'dailyAd': true,
      'creator': true,
      'recoverable': true,
      'caseOfDay': true,
      'metrics': true,
      'reviewPrompt': true,
      'lobbyReady': true,
      'missions': true,
      'thursday': true,
      'titles': true,
      'partner': true,
      'economy': {'version': 3},
      'council': {
        'contracts': true,
        'rank': true,
        'leaderboard': true,
        'invites': true,
        'starterBundle': true,
      },
      'ads': {
        'banner': {'enabled': true},
        'appOpen': {'enabled': true},
        'extras': {'spin': true, 'coffer': true, 'swap': true},
      },
      'fun': {
        'awards': true,
        'reactions': true,
        'founder': true,
        'characterBonds': true,
      },
      'social': {
        'friends': true,
        'directory': true,
        'pushInvites': true,
        'missions': true,
      },
      'safety': {'v11': true},
      'witness': {'whispers': true},
    });

    expect(caps.adSteps, isTrue);
    expect(caps.daily && caps.dailyAd, isTrue);
    expect(caps.creator && caps.recoverable, isTrue);
    expect(caps.caseOfDay && caps.metrics && caps.reviewPrompt, isTrue);
    expect(caps.lobbyReady && caps.missions && caps.thursday, isTrue);
    expect(caps.titles && caps.partner && caps.economyV3, isTrue);
    expect(caps.council.contracts && caps.council.rank, isTrue);
    expect(caps.council.leaderboard && caps.council.invites, isTrue);
    expect(caps.council.starterBundle, isTrue);
    expect(caps.ads.banner && caps.ads.extras, isTrue);
    expect(caps.ads.appOpen.enabled, isTrue);
    expect(caps.fun.awards && caps.fun.reactions && caps.fun.founder, isTrue);
    expect(caps.fun.characterBonds, isTrue);
    expect(caps.friends && caps.directory && caps.pushInvites, isTrue);
    expect(caps.safetyV11 && caps.witnessWhispers, isTrue);
  });
}
