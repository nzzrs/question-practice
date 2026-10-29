import 'package:flutter_test/flutter_test.dart';
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

  test('leaving questions unanswered keeps them out of the score', () async {
    final practice = await harness.seedPractice(count: 3);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );

    final summary = await sessions.finishEarly(
      start: start,
      markSkipped: false,
    );

    expect(summary.session.total, 1);
    expect(summary.session.correct, 1);
    expect(summary.session.skipped, 0);
    expect(summary.session.score, 1);
    expect(summary.wrongCount, 0);

    final practices = await harness.practices
        .watchPracticeSummaries(practice.topicId)
        .first;
    expect(practices.single.lastScore, 1);
  });

  test('marking unanswered questions skipped records attempts', () async {
    final practice = await harness.seedPractice(count: 3);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );

    final summary = await sessions.finishEarly(start: start, markSkipped: true);

    expect(summary.session.total, 3);
    expect(summary.session.correct, 0);
    expect(summary.session.skipped, 2);
    expect(summary.session.score, 0);

    final steps = await review.load(start.session.id);
    expect(steps!.steps.whereType<SkippedReviewStep>(), hasLength(2));
  });

  test('exported error cards do not return to the end review', () async {
    final practice = await harness.seedPractice(count: 2);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [1],
      reasoning: 'I guessed.',
      distracted: false,
    );
    final card = await harness.cards.activeErrorForQuestion(
      start.items[0].question.id,
    );
    await harness.cards.updateErrorCardDetails(
      id: card!.id,
      bias: 'I guessed the familiar name.',
      vaccine: 'Read what the service actually does.',
      completedAt: harness.clock.now().toUtc(),
    );
    await harness.cards.markExported(
      conceptIds: const [],
      errorCardIds: [card.id],
      manualCardIds: const [],
      exportedAt: harness.clock.now().toUtc(),
    );

    final data = await review.load(start.session.id);
    expect(data!.steps.whereType<ErrorReviewStep>(), isEmpty);
    final summary = await sessions.summaryFor(start.session.id);
    expect(summary.errorCardsNeedingNotes, 0);
  });
}
