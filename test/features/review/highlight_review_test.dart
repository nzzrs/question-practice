import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/domain/review_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late SessionService sessions;
  late ReviewService review;

  setUp(() {
    harness = TestHarness();
    sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    review = ReviewService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
  });

  tearDown(() async {
    await harness.close();
  });

  Future<int> seedHighlight(SessionStart start, int questionId) {
    return harness.cards.createHighlight(
      sessionId: start.session.id,
      questionId: questionId,
      text: 'managed service',
      context: start.items.single.question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
  }

  test(
    'highlights wait in the review and keeping one closes the step',
    () async {
      final practice = await harness.seedPractice(count: 1);
      final start = await sessions.startPractice(practice.practiceId);
      await sessions.submitAnswer(
        start: start,
        item: start.items.single,
        selectedIndexes: const [0],
        reasoning: '',
        distracted: false,
      );
      await seedHighlight(start, start.items.single.question.id);

      final data = await review.load(start.session.id);
      final step = data!.steps.whereType<HighlightReviewStep>().single;
      expect(step.highlight.text, 'managed service');

      await review.keepHighlight(step.highlight.id);
      final after = await review.load(start.session.id);
      expect(after!.steps.whereType<HighlightReviewStep>(), isEmpty);
      final saved = await harness.cards.highlightsForSession(start.session.id);
      expect(saved.single.isKept, isTrue);
    },
  );

  test('a highlight can become a concept card', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    final highlightId = await seedHighlight(
      start,
      start.items.single.question.id,
    );
    final data = await review.load(start.session.id);
    final step = data!.steps.whereType<HighlightReviewStep>().single;

    await review.createConcept(
      sessionId: start.session.id,
      questionId: step.highlight.questionId,
      term: step.highlight.text,
      definition: 'A cloud service run by the provider.',
      context: step.highlight.context,
      topicName: step.highlight.topicName,
      source: ConceptSource.manual,
    );
    await review.markHighlightConverted(step.highlight.id);

    final concepts = await harness.cards.watchConcepts().first;
    expect(concepts.single.term, 'managed service');
    final saved = await harness.cards.highlightsForSession(start.session.id);
    expect(saved.single.hasCard, isTrue);
    final after = await review.load(start.session.id);
    expect(after!.steps.whereType<HighlightReviewStep>(), isEmpty);
    expect(highlightId, step.highlight.id);
  });

  test('deleting a highlight removes it from the review', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    final id = await seedHighlight(start, start.items.single.question.id);
    await harness.cards.deleteHighlight(id);

    final data = await review.load(start.session.id);
    expect(data!.steps.whereType<HighlightReviewStep>(), isEmpty);
  });
}
