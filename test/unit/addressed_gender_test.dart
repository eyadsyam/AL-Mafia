import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/information/records.dart';
import 'package:mafia_master/engine/models/information_enums.dart';
import 'package:mafia_master/ui/information_text.dart';

import '../support/localized.dart';

/// Lines put to one player are said the way that player asked to be
/// addressed: a woman is asked «قلتي…», told «إنتي متسكّتة…».
void main() {
  const names = {1: 'منى', 2: 'كريم'};

  test('a confrontation is put in the feminine to a woman', () {
    for (final type in [
      ConfrontationType.c1,
      ConfrontationType.c4,
      ConfrontationType.c5,
      ConfrontationType.c6,
      ConfrontationType.c7,
      ConfrontationType.c8,
    ]) {
      final c = Confrontation(
        type: type,
        targetSeat: 0,
        evidenceSeat: 1,
        evidenceSeat2: 2,
        count: 3,
      );
      final him = InformationText.confrontation(arStrings, c, names);
      final her =
          InformationText.confrontation(arStrings, c, names, female: true);
      expect(her, isNotNull, reason: '$type');
      expect(her, isNot(him), reason: '$type');
    }
  });

  test('the silenced voter is told in her own form', () {
    expect(
      InformationText.silencedCannotVote(arStrings, female: true),
      arStrings.silencedCannotVoteFemale,
    );
    expect(
      InformationText.silencedCannotVote(arStrings, female: false),
      arStrings.silencedCannotVote,
    );
  });
}
