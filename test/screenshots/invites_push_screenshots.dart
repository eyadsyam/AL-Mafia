/// Renders the invite surfaces for the owner to look at: the «ادعي صحابك»
/// sheet (three tabs), the incoming popup, and a mock of the Android
/// notification (drawn from the same payload strings the server sends).
///
/// **Not a test** (no `_test` suffix, asserts nothing), like
/// `store_truth_screenshots.dart`.
///
///     flutter test test/screenshots/invites_push_screenshots.dart
///
/// Writes 390 px wide PNGs to `build/screens_invites/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/ui/economy/cosmetic_paint.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/screens/online/invite_sheet.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:mafia_master/ui/social/friends.dart';
import 'package:mafia_master/ui/social/incoming_invite.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/player_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

const _phone = Size(390, 844);

const _rows = [
  DirectoryRow(
    handle: 'nour_hassan',
    name: 'نور حسن',
    gender: 'female',
    level: 14,
    presence: DirectoryPresence.online,
    frame: 'frame_gilded',
    plate: 'plate_ember',
  ),
  DirectoryRow(
    handle: 'karim_22',
    name: 'كريم',
    gender: 'male',
    level: 11,
    presence: DirectoryPresence.lobby,
    frame: 'frame_crimson',
  ),
  DirectoryRow(
    handle: 'salma',
    name: 'سلمى',
    gender: 'female',
    level: 9,
    presence: DirectoryPresence.playing,
    plate: 'plate_noir',
  ),
  DirectoryRow(handle: 'omar', name: 'عمر', level: 12),
];

class _Api extends DirectoryApi {
  _Api(super.ref);
  @override
  Future<DirectoryPage> search(String query, {int page = 0}) async =>
      const DirectoryPage(_rows);
  @override
  Future<DirectoryPage> discover(DiscoverFilter? f, {int page = 0}) async =>
      const DirectoryPage(_rows, more: true);
  @override
  Future<bool> inviteHandle(String handle, String roomId) async => true;
}

class _Friends extends FriendsController {
  @override
  Future<FriendsState?> build() async => FriendsState.fromJson({
    'friends': [
      {
        'id': 'a',
        'name': 'ليلى',
        'gender': 'female',
        'frame': 'frame_moonlit',
        'plate': 'plate_gilded',
        'presence': {'state': 'lobby', 'code': 'K7M2QP', 'players': 4},
      },
      {'id': 'b', 'name': 'يوسف', 'gender': 'male', 'frame': 'frame_crimson'},
      {
        'id': 'c',
        'name': 'مريم',
        'gender': 'female',
        'presence': {'state': 'playing'},
      },
    ],
  });
  @override
  Future<void> refresh() async {}
  @override
  Future<bool> invite(String id, String roomId) async => true;
}

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

/// The Android notification as the shade draws it, from the payload the
/// server builds (`supabase/functions/_shared/push.ts`): our gold hat as the
/// small icon, the app name, the title, the body and the sender's avatar.
class _AndroidNotificationMock extends StatelessWidget {
  const _AndroidNotificationMock();

  @override
  Widget build(BuildContext context) {
    const shade = Color(0xFF1F1F23);
    const ink = Color(0xFFE8E8EA);
    const dim = Color(0xFFA0A0A6);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: shade,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.theater_comedy, size: 16, color: InviteTokens.accent),
                      SizedBox(width: 6),
                      Text('سيد المافيا · دلوقتي',
                          style: TextStyle(color: dim, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('دعوة للعب',
                      style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('إياد بيدعوك تلعبوا مع بعض — أوضة K7M2QP',
                      style: TextStyle(color: ink, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('ادخل',
                          style: TextStyle(
                              color: InviteTokens.accent.withValues(alpha: 1),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 24),
                      const Text('بعدين', style: TextStyle(color: dim)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const CosmeticFrameRing(
              frame: 'frame_crimson',
              diameter: 48,
              child: PlayerAvatar(
                name: 'إياد',
                gender: PlayerGender.male,
                diameter: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  final out = Directory('build/screens_invites')..createSync(recursive: true);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    Future<void> Function(WidgetTester)? act,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(_fonts);
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: [
            directoryApiProvider.overrideWith(_Api.new),
            friendsProvider.overrideWith(_Friends.new),
            economyCapabilitiesProvider.overrideWith(
              (ref) async => const EconomyCapabilities(friends: true),
            ),
          ],
          child: localizedApp(child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (act != null) await act(tester);
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage(
            (element.widget as Image).image,
            element,
          ).timeout(const Duration(seconds: 2), onTimeout: () {});
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 300));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 1);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  Widget lobby(Widget over) => Scaffold(
    body: Stack(children: [const Center(child: Text('K7M2QP')), over]),
  );

  const sheet = InviteSheet(visible: true, roomId: 'r', onDismiss: _noop);

  testWidgets('sheet: friends', (tester) async {
    await shoot(
      tester,
      'invite_sheet_friends_ar',
      lobby(sheet),
      act: (t) => t.tap(find.byKey(InviteSheet.buttonKey('a'))),
    );
  });

  testWidgets('sheet: search', (tester) async {
    await shoot(
      tester,
      'invite_sheet_search_ar',
      lobby(sheet),
      act: (t) async {
        await t.tap(find.byKey(InviteSheet.tabKey(1)));
        await t.pumpAndSettle();
        await t.enterText(find.byKey(InviteSheet.searchField), 'نور');
        await t.pump(InviteTokens.searchDebounce);
        await t.pumpAndSettle();
        await t.tap(find.byKey(InviteSheet.buttonKey('nour_hassan')));
      },
    );
  });

  testWidgets('sheet: near you', (tester) async {
    await shoot(
      tester,
      'invite_sheet_nearby_ar',
      lobby(sheet),
      act: (t) async {
        await t.tap(find.byKey(InviteSheet.tabKey(2)));
        await t.pumpAndSettle();
        await t.tap(find.byKey(InviteSheet.filterKey(DiscoverFilter.near)));
      },
    );
  });

  testWidgets('incoming popup', (tester) async {
    await shoot(
      tester,
      'incoming_invite_ar',
      Scaffold(
        body: IncomingInvitePopup(
          invite: const IncomingInvite(
            id: 'i',
            code: 'K7M2QP',
            name: 'إياد',
            handle: 'eyad',
            gender: 'male',
            frame: 'frame_crimson',
            plate: 'plate_gilded',
          ),
          onEnter: () async => 'K7M2QP',
          onLater: () {},
        ),
      ),
    );
  });

  testWidgets('android notification mock', (tester) async {
    await shoot(
      tester,
      'android_notification_mock_ar',
      const Scaffold(
        backgroundColor: Color(0xFF0B0B0D),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topCenter,
              child: _AndroidNotificationMock(),
            ),
          ),
        ),
      ),
    );
  });
}

void _noop() {}
