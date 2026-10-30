import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app_build.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/social/directory.dart';

import '../support/fake_backend.dart';

/// Find and invite anyone: the `friends` calls and what comes back. Rows carry
/// public identity only; anything malformed is dropped rather than shown.
void main() {
  late FakeBackend backend;
  late DirectoryApi api;

  setUp(() {
    backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby', status: 'lobby'),
      players: roster(1),
    );
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      ],
    );
    addTearDown(container.dispose);
    api = container.read(directoryApiProvider);
  });

  Map<String, dynamic> sent(String action) => backend.calls
      .lastWhere((c) => c.function == 'friends' && c.body['action'] == action)
      .body;

  group('parsing', () {
    test('a row reads its identity, presence and looks', () {
      final row = DirectoryRow.fromJson({
        'handle': 'sara',
        'name': 'سارة',
        'gender': 'female',
        'level': 7.0,
        'state': 'playing',
        'friend': true,
        'frame': 'frame_gilded',
        'plate': 3,
      })!;
      expect(row.handle, 'sara');
      expect(row.level, 7);
      expect(row.presence, DirectoryPresence.playing);
      expect(row.friend, isTrue);
      expect(row.frame, 'frame_gilded');
      expect(row.plate, isNull);
    });

    test('a row with no handle is nobody; defaults fill the rest', () {
      expect(DirectoryRow.fromJson({'name': 'x'}), isNull);
      expect(DirectoryRow.fromJson('x'), isNull);
      final row = DirectoryRow.fromJson({'handle': 'k'})!;
      expect(row.name, '?');
      expect(row.level, 1);
      expect(row.presence, DirectoryPresence.away);
      expect(row.friend, isFalse);
    });

    test('every presence the server sends', () {
      for (final (state, presence) in [
        ('online', DirectoryPresence.online),
        ('lobby', DirectoryPresence.lobby),
        ('playing', DirectoryPresence.playing),
        ('ghost', DirectoryPresence.away),
      ]) {
        expect(
          DirectoryRow.fromJson({'handle': 'h', 'state': state})!.presence,
          presence,
        );
      }
    });

    test('a page keeps the good rows and whether there is more', () {
      final page = DirectoryPage.fromJson({
        'rows': [
          {'handle': 'a'},
          {'nope': 1},
          {'handle': 'b'},
        ],
        'more': true,
      });
      expect(page.rows.map((r) => r.handle), ['a', 'b']);
      expect(page.more, isTrue);
      expect(DirectoryPage.fromJson({'rows': 'x'}).rows, isEmpty);
    });

    test('my entry: switches default on, a bad date is no date', () {
      final me = DirectoryMe.fromJson({
        'handle': 'me',
        'searchable': false,
        'handleChangeAt': 'not a date',
      });
      expect(me.handle, 'me');
      expect(me.searchable, isFalse);
      expect(me.strangerInvites, isTrue);
      expect(me.handleChangeAt, isNull);
      expect(DirectoryMe.fromJson(null).searchable, isTrue);
      expect(
        DirectoryMe.fromJson({
          'handleChangeAt': '2026-11-01T10:00:00Z',
        }).handleChangeAt,
        DateTime.utc(2026, 11, 1, 10),
      );
    });

    test('an invite needs its id and its room code', () {
      expect(IncomingInvite.fromJson({'id': 'i'}), isNull);
      expect(IncomingInvite.fromJson({'code': 'ABCDEF'}), isNull);
      final invite = IncomingInvite.fromJson({
        'id': 'i1',
        'code': 'ABCDEF',
        'handle': 'k',
      })!;
      expect(invite.name, '?');
      expect(invite.handle, 'k');
    });
  });

  group('calls', () {
    test('search and discover send what was asked', () async {
      backend.responses['friends'] = {
        'rows': [
          {'handle': 'a'},
        ],
      };
      expect((await api.search('سا', page: 2)).rows.single.handle, 'a');
      expect(sent('search'), containsPair('query', 'سا'));
      expect(sent('search'), containsPair('page', 2));
      await api.discover(DiscoverFilter.online);
      expect(sent('discover'), containsPair('filter', 'online'));
      await api.discover(null);
      expect(sent('discover').containsKey('filter'), isFalse);
    });

    test('an invite is true only when the server took it', () async {
      backend.responses['friends'] = const {};
      expect(await api.inviteHandle('k', 'room-1'), isTrue);
      expect(sent('invite'), containsPair('roomId', 'room-1'));
      backend.refusals['friends'] = const BackendException('BLOCKED', 'no');
      expect(await api.inviteHandle('k', 'room-1'), isFalse);
    });

    for (final (message, refusal) in [
      ('HANDLE_TAKEN', HandleRefusal.taken),
      ('RATE_LIMITED', HandleRefusal.tooSoon),
      ('NAME_NOT_ALLOWED', HandleRefusal.refused),
      ('BAD_REQUEST', HandleRefusal.invalid),
      ('invalid request', HandleRefusal.invalid),
      ('SOMETHING', HandleRefusal.failed),
    ]) {
      test('a handle refused with $message reads as ${refusal.name}', () async {
        backend.refusals['friends'] = BackendException('REFUSED', message);
        final (me, why) = await api.setHandle('new');
        expect(me, isNull);
        expect(why, refusal);
      });
    }

    test('a handle accepted comes back as the new entry', () async {
      backend.responses['friends'] = {'handle': 'new'};
      final (me, why) = await api.setHandle('new');
      expect(me?.handle, 'new');
      expect(why, isNull);
    });

    test('prefs send only the switch that changed', () async {
      backend.responses['friends'] = {'searchable': false};
      final me = await api.prefs(searchable: false);
      expect(me.searchable, isFalse);
      expect(sent('prefs').containsKey('strangerInvites'), isFalse);
    });

    test('the inbox keeps whole invites only', () async {
      backend.responses['friends'] = {
        'invites': [
          {'id': 'i1', 'code': 'ABCDEF'},
          {'id': 'i2'},
        ],
      };
      expect((await api.inbox()).map((i) => i.id), ['i1']);
    });

    test('accepting opens the room only while it is still open', () async {
      backend.responses['friends'] = {'open': true, 'code': 'ABCDEF'};
      expect(await api.respond('i1', accept: true), 'ABCDEF');
      expect(sent('respondInvite'), containsPair('accept', true));
      backend.responses['friends'] = {'open': false, 'code': 'ABCDEF'};
      expect(await api.respond('i1', accept: true), isNull);
    });

    test('push registration names the token and the platform', () async {
      backend.responses['friends'] = const {};
      await api.registerPush('tok', 'android');
      expect(sent('registerPush'), containsPair('platform', 'android'));
      expect(sent('registerPush'), containsPair('build', kAppBuildNumber));
      await api.unregisterPush('tok');
      expect(sent('unregisterPush'), containsPair('token', 'tok'));
    });
  });
}
