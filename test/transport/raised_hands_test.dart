/// Doc 15 §1.4, resolved 2026-09-07 — the discussion line is a floor, not a
/// queue.
///
/// The section it replaces asked band 3 for *"the next two in queue"*. There
/// was never a queue: `micPolicyFor` grants the floor to whoever claims it and
/// is allowed to have it, and the server records one holder and nothing behind
/// them. These are the tests for the two things that *are* real, and for the
/// one property that keeps the queue from growing back — that nothing, at any
/// layer, orders a raised hand by when it went up.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/room_codec.dart';

void main() {
  final now = DateTime.utc(2026, 9, 7, 20);

  RoomState stateWith({String phase = 'discuss', String? speaker}) => RoomState(
    phase: phase,
    phaseNumber: 2,
    phaseEndsAt: now.add(const Duration(minutes: 3)),
    activeSpeaker: speaker,
    publicData: const {},
    status: 'playing',
    settings: const {},
    hostId: 'u0',
    code: 'ABCD',
    serverNow: now,
  );

  /// Five players. Hands went up in the reverse of seat order on purpose: if
  /// anything anywhere sorts by request time, these tests come out backwards.
  List<RoomPlayer> roster({
    Set<int> hands = const {},
    Set<int> dead = const {},
  }) => [
    for (var seat = 0; seat < 5; seat++)
      RoomPlayer(
        userId: 'u$seat',
        seat: seat,
        name: 'P$seat',
        alive: !dead.contains(seat),
        handRaisedAt: hands.contains(seat)
            ? now.subtract(Duration(seconds: seat))
            : null,
      ),
  ];

  GameSnapshot decode({
    Set<int> hands = const {},
    Set<int> dead = const {},
    String? speaker,
    String phase = 'discuss',
  }) => snapshotFrom(
    state: stateWith(phase: phase, speaker: speaker),
    players: roster(hands: hands, dead: dead),
    viewerSeat: 0,
    isHost: false,
    connection: ConnectionQuality.connected,
    skew: Duration.zero,
  );

  test('a hand that went up arrives as a seat', () {
    expect(decode(hands: const {2, 4}).raisedHands, {2, 4});
  });

  test('no hands is an empty set, not a null and not a blank name', () {
    // Band 3 renders one element instead of two when this is empty, which is
    // §1.4's "maximum two text elements" holding rather than a headline over a
    // blank line.
    expect(decode().raisedHands, isEmpty);
  });

  test('the speaker is never also asking to speak', () {
    // The server lowers a hand the instant it grants that hand the floor, so
    // this state should not arrive at all. The filter is here for the snapshot
    // that lands mid-write, and this is the test that it works.
    expect(decode(hands: const {1, 3}, speaker: 'u1').raisedHands, {3});
  });

  test('the dead do not have hands up', () {
    // `raise_hand` refuses a dead player and a phase change clears the room,
    // so this is belt and braces — but a hand left behind by somebody who was
    // voted out mid-discussion would put a name on the screen that its owner
    // can no longer act on.
    expect(decode(hands: const {2, 3}, dead: const {3}).raisedHands, {2});
  });

  test('the set is exactly the seats, and carries no order with it', () {
    // The heart of the resolution. Hands went up in descending seat order; the
    // snapshot's type cannot express that, and this asserts the type rather
    // than the contents — a `List` here would pass a contents check and still
    // be the queue doc 15 §1.4 removed.
    final hands = decode(hands: const {4, 1, 3}).raisedHands;
    expect(hands, isA<Set<int>>());
    expect(hands, {1, 3, 4});
  });

  test('the night records nobody asking, because nobody may ask', () {
    // `micPolicyFor` refuses the floor in every dark phase, so `claim_floor`
    // never reaches `raise_hand` and the column stays null. A hand up at night
    // would be a request the server would never honour, rendered as though it
    // might be.
    // Hands are deliberately *present* in the roster here. The server should
    // never have written them, and the point of the assertion is that the
    // client draws nothing even when it did — the same rule that collapses
    // every other per-seat fact at night.
    expect(decode(hands: const {1, 2, 3}, phase: 'night').raisedHands, isEmpty);
    expect(decode(hands: const {1, 2, 3}, phase: 'vote').raisedHands, isEmpty);
  });

  test('clearing the floor clears the hands with it', () {
    // A phase change is a release, both here and in the server's trigger. The
    // two must agree: a client that kept the hands would show yesterday's
    // requests over tonight's council.
    final held = decode(hands: const {2, 4});
    expect(held.copyWith(clearSpeaker: true).raisedHands, isEmpty);
  });
}
