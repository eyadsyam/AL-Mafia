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
}
