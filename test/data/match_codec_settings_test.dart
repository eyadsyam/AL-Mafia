import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/match_codec.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

/// Every field of MatchSettings survives a save and a load, and an old blob
/// that predates a field still decodes to that field default.
void main() {
  // Each field set to the opposite of its default (or a different number).
  const flipped = MatchSettings(
    speechSeconds: 45,
    discussionMode: DiscussionMode.free,
    dayTieRule: DayTieRule.revote,
    narrationEnabled: false,
    abstainAllowed: true,
    identityHoldSeconds: 9,
    muteAllAudio: true,
    scoreEnabled: false,
    traceEnabled: false,
    confrontationEnabled: false,
    whisperEnabled: true,
    revealWhisperContent: true,
    openingRoundEnabled: true,
    survivorConfrontationEnabled: true,
    confrontationSeconds: 60,
    openVoting: true,
    discussionSeconds: 120,
    bulletsEnabled: false,
    quietNightEnabled: false,
    selfProtectEnabled: false,
    silencerEnabled: true,
    elderEnabled: true,
    sniperEnabled: true,
    pressureCurveEnabled: false,
    revealNightVictimRole: true,
    interfaceHintsEnabled: false,
    playHintsEnabled: false,
    postMatchCoachingEnabled: false,
    midDiscussionConfrontation: true,
    tabletopPresentation: false,
  );

  test('every field round-trips', () {
    final json = MatchCodec.encodeSettings(flipped);
    final back = MatchCodec.decodeSettings(json);
    expect(MatchCodec.encodeSettings(back), json);
    expect(back.bulletsEnabled, isFalse);
    expect(back.quietNightEnabled, isFalse);
    expect(back.selfProtectEnabled, isFalse);
    expect(back.pressureCurveEnabled, isFalse);
    expect(back.midDiscussionConfrontation, isTrue);
    expect(back.interfaceHintsEnabled, isFalse);
    expect(back.playHintsEnabled, isFalse);
    expect(back.postMatchCoachingEnabled, isFalse);
    expect(back.discussionSeconds, 120);
    expect(back.tabletopPresentation, isFalse);
    expect(back.sniperEnabled, isTrue);
  });

  test('the encoded map carries every field the model has', () {
    // 30 constructor parameters; a field added to the model without the codec
    // shows up as a count mismatch here.
    expect(MatchCodec.encodeSettings(flipped).length, 30);
  });

  test('an old blob without the newer fields decodes to their defaults', () {
    final old = MatchCodec.encodeSettings(const MatchSettings.defaults())
      ..remove('bulletsEnabled')
      ..remove('quietNightEnabled')
      ..remove('selfProtectEnabled')
      ..remove('pressureCurveEnabled')
      ..remove('midDiscussionConfrontation')
      ..remove('interfaceHintsEnabled')
      ..remove('playHintsEnabled')
      ..remove('postMatchCoachingEnabled');
    final back = MatchCodec.decodeSettings(old);
    const d = MatchSettings.defaults();
    expect(back.bulletsEnabled, d.bulletsEnabled);
    expect(back.quietNightEnabled, d.quietNightEnabled);
    expect(back.selfProtectEnabled, d.selfProtectEnabled);
    expect(back.pressureCurveEnabled, d.pressureCurveEnabled);
    expect(back.midDiscussionConfrontation, d.midDiscussionConfrontation);
    expect(back.interfaceHintsEnabled, d.interfaceHintsEnabled);
    expect(back.playHintsEnabled, d.playHintsEnabled);
    expect(back.postMatchCoachingEnabled, d.postMatchCoachingEnabled);
  });
}
