import 'package:mafia_master/transport/witness_whisper.dart';
import 'package:test/test.dart';

/// The whispers a dead witness reads back (owner, 2026-09-28: the dead see
/// everything, whispers included) — parsed defensively, and a masked row
/// never carries its words onto the device.
void main() {
  Map<String, Object?> row({
    Object? id = 'w1',
    Object? day = 2,
    Object? from = 1,
    Object? to = 4,
    Object? text = 'سرّ',
    Object? masked = false,
  }) => {
    'id': id,
    'day': day,
    'fromSeat': from,
    'toSeat': to,
    'text': text,
    'masked': masked,
  };

  test('a plain row keeps its words and seats', () {
    final [w] = WitnessWhisper.listFromJson([row()]);
    expect(w.id, 'w1');
    expect(w.day, 2);
    expect(w.fromSeat, 1);
    expect(w.toSeat, 4);
    expect(w.text, 'سرّ');
    expect(w.masked, isFalse);
  });

  test('a masked row drops its words even if the server sent them', () {
    final [w] = WitnessWhisper.listFromJson([row(masked: true)]);
    expect(w.masked, isTrue);
    expect(w.text, isNull);
  });

  test('a row with no text is still a whisper', () {
    final [w] = WitnessWhisper.listFromJson([row(text: null)]);
    expect(w.text, isNull);
    expect(w.masked, isFalse);
  });

  test('malformed rows are skipped, the good ones kept in order', () {
    final list = WitnessWhisper.listFromJson([
      row(id: 'a'),
      row(id: 7),
      row(id: 'b', day: '2'),
      row(id: 'c', from: null),
      row(id: 'd', to: 1.5),
      row(id: 'e'),
    ]);
    expect(list.map((w) => w.id), ['a', 'e']);
  });

  test('anything that is not a list reads as no whispers', () {
    expect(WitnessWhisper.listFromJson(null), isEmpty);
    expect(WitnessWhisper.listFromJson('x'), isEmpty);
    expect(WitnessWhisper.listFromJson({'id': 'w1'}), isEmpty);
    expect(WitnessWhisper.listFromJson(const []), isEmpty);
  });
}
