import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/read_whisper_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saved receipts come back for the same room and player only', () async {
    await ReadWhisperStore.save('room', 'me', {'w1', 'w2'});
    expect(await ReadWhisperStore.load('room', 'me'), {'w1', 'w2'});
    expect(await ReadWhisperStore.load('other room', 'me'), isEmpty);
    expect(await ReadWhisperStore.load('room', 'someone else'), isEmpty);
  });

  test('only the newest 128 receipts are kept', () async {
    final ids = {for (var i = 0; i < 130; i++) 'w$i'};
    await ReadWhisperStore.save('room', 'me', ids);
    final loaded = await ReadWhisperStore.load('room', 'me');
    expect(loaded, hasLength(128));
    expect(loaded, isNot(contains('w0')));
    expect(loaded, isNot(contains('w1')));
    expect(loaded, containsAll(['w2', 'w129']));
  });

  test('a new room replaces the receipts of the previous one', () async {
    await ReadWhisperStore.save('old', 'me', {'w1'});
    await ReadWhisperStore.save('new', 'me', {'w2'});
    expect(await ReadWhisperStore.load('old', 'me'), isEmpty);
    expect(await ReadWhisperStore.load('new', 'me'), {'w2'});
  });

  test('clear forgets the matching room and leaves any other alone', () async {
    await ReadWhisperStore.save('room', 'me', {'w1'});
    await ReadWhisperStore.clear('other room', 'me');
    expect(await ReadWhisperStore.load('room', 'me'), {'w1'});
    await ReadWhisperStore.clear('room', 'me');
    expect(await ReadWhisperStore.load('room', 'me'), isEmpty);
  });

  test('a damaged record reads as no receipts', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.mafia.readWhispers.v1': 'not json',
    });
    expect(await ReadWhisperStore.load('room', 'me'), isEmpty);

    SharedPreferences.setMockInitialValues({
      'flutter.mafia.readWhispers.v1':
          '{"roomId":"room","userId":"me","ids":["w1",7,null,"w2"]}',
    });
    expect(await ReadWhisperStore.load('room', 'me'), {'w1', 'w2'});
  });
}
