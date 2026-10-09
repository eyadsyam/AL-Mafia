import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/stories/story_session.dart';

void main() {
  late StoryDefinition story;

  setUpAll(() {
    story = StoryDefinition.decode(
      File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
    );
  });

  test(
    'solo spends budget, reveals only authored clues and scores accusation',
    () {
      var session = StorySession.start(story: story, playerCount: 1, seed: 17);
      session = session.performSoloAction('interview');
      expect(session.remainingBudget, story.actionBudget - 2);
      expect(session.revealedClueIds, contains('culprit_lane'));
      expect(() => session.performSoloAction('interview'), throwsStateError);

      session = session.submitSoloAccusation(
        StoryAccusation(
          culprit: story.truth.primaryCulprit,
          motive: story.truth.motive,
          method: story.truth.method,
        ),
      );
      expect(session.phase, StoryPhase.reenactment);
      expect(session.score!.total, greaterThan(1000));
      expect(session.finishReenactment().phase, StoryPhase.complete);
    },
  );

  test(
    'group runs three private/discussion/investigation rounds then votes',
    () {
      var session = StorySession.start(story: story, playerCount: 3, seed: 91);
      for (var round = 0; round < 3; round++) {
        for (var player = 0; player < 3; player++) {
          session = session.revealPrivateCard();
          expect(session.phase, StoryPhase.groupPrivateClue);
          session = session.coverPrivateCard();
        }
        expect(session.phase, StoryPhase.groupDiscussion);
        session = session.finishDiscussion();
        session = session.pickSharedInvestigation(story.actions[round].id);
      }
      expect(session.phase, StoryPhase.groupVoteHandoff);
      for (var player = 0; player < 3; player++) {
        session = session.revealVoteCard();
        session = session.submitSecretVote(
          StoryAccusation(
            culprit: story.truth.primaryCulprit,
            motive: story.truth.motive,
            method: story.truth.method,
          ),
        );
      }
      expect(session.phase, StoryPhase.reenactment);
      expect(session.votes, hasLength(3));
      expect(session.score!.total, greaterThan(0));
    },
  );

  test('invalid phase transition fails loudly', () {
    final session = StorySession.start(story: story, playerCount: 2, seed: 1);
    expect(session.finishDiscussion, throwsStateError);
  });

  test('the same seed seats the same table, other seeds seat others', () {
    List<String> table(int seed) => StorySession.start(
      story: story,
      playerCount: 6,
      seed: seed,
    ).seated.map((c) => c.id).toList();

    expect(table(7), table(7));
    final orders = {for (var seed = 0; seed < 20; seed++) table(seed).join()};
    expect(orders.length, greaterThan(1));
    // Always the same six characters, only the seats move.
    final expected = story.characters.take(6).map((c) => c.id).toSet();
    for (var seed = 0; seed < 20; seed++) {
      expect(table(seed).toSet(), expected);
    }
    final session = StorySession.start(story: story, playerCount: 6, seed: 3);
    expect(session.currentCharacter.id, session.seated.first.id);
  });

  test('a wrong accusation earns no efficiency points', () {
    var session = StorySession.start(story: story, playerCount: 1, seed: 1);
    session = session.submitSoloAccusation(
      StoryAccusation(
        culprit: story.characters
            .firstWhere((c) => c.id != story.truth.primaryCulprit)
            .id,
        motive: story.truth.motive,
        method: story.truth.method,
      ),
    );
    expect(session.score!.efficiencyPoints, 0);
    expect(session.score!.total, 500);
  });

  test('an interruption covers a private page without losing the seat', () {
    var session = StorySession.start(story: story, playerCount: 3, seed: 2);
    session = session.revealPrivateCard();
    final covered = session.coverForInterruption();
    expect(covered.phase, StoryPhase.groupHandoff);
    expect(covered.currentPlayer, session.currentPlayer);
    expect(covered.round, session.round);
    expect(covered.coverForInterruption().phase, StoryPhase.groupHandoff);
  });

  test('minimum group seats at least two non-culprit voters', () {
    for (final file in Directory('assets/stories').listSync().whereType<File>()) {
      final s = StoryDefinition.decode(file.readAsStringSync());
      final culprit = s.characters.indexWhere(
        (c) => c.id == s.truth.primaryCulprit,
      );
      final min = s.minGroupPlayers;
      expect(min, inInclusiveRange(2, 3), reason: s.id);
      final voters = min - (culprit < min ? 1 : 0);
      expect(voters, greaterThanOrEqualTo(2), reason: s.id);
    }
    expect(story.minGroupPlayers, 3);
  });

  test('shared searches that give a table nothing are not offered', () {
    // Real stories no longer have such a search (the checker forbids it), so
    // the fixture takes one away from the two-player table.
    final raw = jsonDecode(
      File('assets/stories/mahal_el_dahab.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final clue in raw['clues'] as List) {
      if ((clue as Map)['id'] == 'flavor_cheque') {
        clue['buckets'] = ['5-6', '7-8', '9-10'];
      }
    }
    final s = StoryDefinition.decode(jsonEncode(raw));
    expect(
      s.sharedActions(2).map((a) => a.id),
      isNot(contains('court_papers')),
    );
    expect(s.sharedActions(9).map((a) => a.id), contains('court_papers'));
    var session = StorySession.start(story: s, playerCount: 2, seed: 1);
    for (var seat = 0; seat < 2; seat++) {
      session = session.revealPrivateCard().coverPrivateCard();
    }
    session = session.finishDiscussion();
    expect(session.skipSharedInvestigation().round, 2);
  });
}
