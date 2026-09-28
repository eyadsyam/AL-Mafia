import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/witness_channel.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';

/// F21a — the dead read whispers; the client only parses what it is sent.
void main() {
  test('whispers parse as seats, and a masked one carries no text', () {
    final table = WitnessTable.fromJson({
      'roles': const [],
      'actions': const [],
      'whispers': [
        {
          'id': 'w1',
          'day': 1,
          'fromSeat': 1,
          'toSeat': 2,
          'text': '<b>هو ده</b>',
          'masked': false,
        },
        {
          'id': 'w2',
          'day': 2,
          'fromSeat': 2,
          'toSeat': 1,
          'text': 'leak',
          'masked': true,
        },
        {'id': 'bad', 'day': 'x'},
      ],
    });
    expect(table.whispers.map((w) => w.id), ['w1', 'w2']);
    expect(table.whispers.first.text, '<b>هو ده</b>');
    expect(table.whispers.last.masked, isTrue);
    expect(table.whispers.last.text, isNull, reason: 'masked text is dropped');
  });

  test('an older server with no whispers field is an empty list', () {
    expect(
      WitnessTable.fromJson({'roles': [], 'actions': []}).whispers,
      isEmpty,
    );
  });

  test('the disclosure follows witness.whispers', () {
    expect(
      EconomyCapabilities.fromJson({
        'version': 3,
        'witness': {'whispers': true},
      }).witnessWhispers,
      isTrue,
    );
    expect(
      EconomyCapabilities.fromJson({'version': 3}).witnessWhispers,
      isFalse,
    );
  });
}
