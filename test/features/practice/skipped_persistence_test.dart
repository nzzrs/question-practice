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

  test(
    'a skipped question stays in the cards queue after the review',
    () async {
      final practice = await harness.seedPractice(count: 1);
      final start = await sessions.startPractice(practice.practiceId);
      await sessions.submitAnswer(
        start: start,
        item: start.items.single,
        selectedIndexes: const [],
        reasoning: 'I did not study this topic.',
        distracted: false,
      );

      final queued = await harness.cards.watchUnhandledSkippedQuestions().first;
      expect(queued, hasLength(1));
      expect(queued.single.reasoning, 'I did not study this topic.');
      expect(queued.single.question, start.items.single.question.prompt);

      final data = await review.load(start.session.id);
      final step = data!.steps.whereType<SkippedReviewStep>().single;
      expect(step.skippedQuestionId, queued.single.id);

      await review.createBasicCard(
        sessionId: start.session.id,
        questionId: step.question.id,
        question: 'What was the correct answer?',
        answer: step.question.correctAnswer,
        context: step.question.prompt,
        topicName: step.topicName,
        skippedQuestionId: step.skippedQuestionId,
      );

      expect(
        await harness.cards.watchUnhandledSkippedQuestions().first,
        isEmpty,
      );
      final manuals = await harness.cards.watchManualCards().first;
      expect(manuals.single.context, step.question.prompt);
      expect(manuals.single.questionId, step.question.id);
      final afterReview = await review.load(start.session.id);
      expect(afterReview!.steps.whereType<SkippedReviewStep>(), isEmpty);
    },
  );

  test('unmarking unknown removes the skipped record', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );
    await sessions.setUnknown(
      start: start,
      item: start.items.single,
      unknown: true,
    );
    expect(
      await harness.cards.watchUnhandledSkippedQuestions().first,
      hasLength(1),
    );

    await sessions.setUnknown(
      start: start,
      item: start.items.single,
      unknown: false,
    );
    expect(await harness.cards.watchUnhandledSkippedQuestions().first, isEmpty);
  });

  test('finishing early with skipped questions queues each one', () async {
    final practice = await harness.seedPractice(count: 2);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.first,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );

    await sessions.finishEarly(start: start, markSkipped: true);

    final queued = await harness.cards.watchUnhandledSkippedQuestions().first;
    expect(queued, hasLength(1));
    expect(queued.single.questionId, start.items.last.question.id);
  });

  test('late reasoning updates the queued skipped question', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [],
      reasoning: '',
      distracted: false,
    );

    await sessions.updateReasoning(
      start: start,
      item: start.items.single,
      reasoning: 'I had never seen this term.',
    );

    final queued = await harness.cards.watchUnhandledSkippedQuestions().first;
    expect(queued.single.reasoning, 'I had never seen this term.');
  });
}
