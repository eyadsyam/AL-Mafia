import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/room_codec.dart';

void main() {
  test('last word decodes only with both public seats', () {
    expect(
      lastWordFromJson({
        'lastWord': {'seat': 1, 'target': 2},
      }),
      (seat: 1, target: 2),
    );
    expect(
      lastWordFromJson({
        'lastWord': {'seat': 1},
      }),
      isNull,
    );
    expect(lastWordFromJson({}), isNull);
  });

  test('morning decodes the unnamed save flag', () {
    expect(
      morningFromJson({'someoneSavedUnnamed': true})?.someoneSavedUnnamed,
      isTrue,
    );
    expect(
      morningFromJson({'someoneSavedUnnamed': false})?.someoneSavedUnnamed,
      isFalse,
    );
  });
}
