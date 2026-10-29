import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late SessionService service;

  setUp(() {
    harness = TestHarness();
    service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
  });

  tearDown(() async {
    await harness.close();
  });

  test('scores correct, wrong and skipped answers', () async {
    final practice = await harness.seedPractice(count: 3);
    final start = await service.startPractice(practice.practiceId);
    expect(start.items, hasLength(3));

    final first = await service.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [1],
      reasoning: 'I guessed',
      distracted: false,
    );
    expect(first.attempt.isCorrect, isFalse);
    expect(first.summary, isNull);

    await service.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [0],
      reasoning: 'I know this',
      distracted: false,
    );
    final third = await service.submitAnswer(
      start: start,
      item: start.items[2],
      selectedIndexes: const [],
      reasoning: '',
      distracted: false,
    );

    expect(third.summary, isNotNull);
    expect(third.summary!.session.correct, 1);
    expect(third.summary!.session.skipped, 1);
    expect(third.summary!.wrongCount, 1);
    expect(third.summary!.session.score, closeTo(1 / 3, 0.0001));
    final stored = await harness.sessions.sessionById(start.session.id);
    expect(stored!.status, SessionStatus.completed);
  });

  test(
    'wrong answers create a card that is due after exactly 48 hours',
    () async {
      final practice = await harness.seedPractice(count: 1);
      final start = await service.startPractice(practice.practiceId);
      await service.submitAnswer(
        start: start,
        item: start.items.single,
        selectedIndexes: const [1],
        reasoning: 'Wrong reasoning',
        distracted: false,
      );

      final active = await harness.cards.watchErrorCards().first;
      expect(active, hasLength(1));
      expect(active.single.dueAt, harness.clock.now().add(errorReviewDelay));
      expect(await harness.cards.dueErrors(), isEmpty);

      harness.clock.advance(errorReviewDelay);
      final due = await harness.cards.dueErrors();
      expect(due, hasLength(1));
      expect(due.single.reasoning, 'Wrong reasoning');
    },
  );

  test('distracted wrong answers create no error card', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await service.startPractice(practice.practiceId);
    final outcome = await service.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: '',
      distracted: true,
    );

    expect(outcome.attempt.distracted, isTrue);
    expect(outcome.summary!.session.distracted, 1);
    expect(await harness.cards.watchErrorCards().first, isEmpty);
  });

  test('multiple correct answers require every correct alternative', () async {
    final topicId = await harness.practices.createTopic(
      name: 'Multi',
      description: '',
      priority: null,
      createdAt: harness.clock.now().toUtc(),
    );
    final practiceId = await harness.practices.createPractice(
      topicId: topicId,
      name: 'Multi practice',
      description: '',
      contentHash: 'multi-hash',
      importedAt: harness.clock.now().toUtc(),
    );
    await harness.practices.createQuestions(practiceId, const [
      QuestionDraft(
        prompt: 'Pick both correct answers',
        alternatives: ['A', 'B', 'C', 'D'],
        correctIndexes: [0, 2],
        explanation: 'A and C are correct.',
        alternativeExplanations: ['A', 'B', 'C', 'D'],
      ),
      QuestionDraft(
        prompt: 'Pick both again',
        alternatives: ['A', 'B', 'C', 'D'],
        correctIndexes: [1, 3],
        explanation: 'B and D are correct.',
        alternativeExplanations: ['A', 'B', 'C', 'D'],
      ),
    ]);
    final start = await service.startPractice(practiceId);

    final partial = await service.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [0],
      reasoning: 'Missed one',
      distracted: false,
    );
    expect(partial.attempt.isCorrect, isFalse);
    final card = (await harness.cards.watchErrorCards().first).single;
    expect(card.correctIndexes, [0, 2]);
    expect(card.wrongIndexes, [0]);

    final complete = await service.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [3, 1],
      reasoning: 'Both',
      distracted: false,
    );
    expect(complete.attempt.isCorrect, isTrue);
    expect(complete.summary!.session.correct, 1);
  });

  test(
    'distraction can be marked after feedback and removes the card',
    () async {
      final practice = await harness.seedPractice(count: 1);
      final start = await service.startPractice(practice.practiceId);
      await service.submitAnswer(
        start: start,
        item: start.items.single,
        selectedIndexes: const [1],
        reasoning: 'Read it too fast',
        distracted: false,
      );
      expect(await harness.cards.watchErrorCards().first, hasLength(1));

      final updated = await service.setDistracted(
        start: start,
        item: start.items.single,
        distracted: true,
      );
      expect(updated.distracted, isTrue);
      expect(await harness.cards.watchErrorCards().first, isEmpty);
      final session = await harness.sessions.sessionById(start.session.id);
      expect(session!.distracted, 1);

      final restored = await service.setDistracted(
        start: start,
        item: start.items.single,
        distracted: false,
      );
      expect(restored.distracted, isFalse);
      expect(await harness.cards.watchErrorCards().first, hasLength(1));
    },
  );

  test('skipped answers create no error card and are counted', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await service.startPractice(practice.practiceId);
    final outcome = await service.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [],
      reasoning: '',
      distracted: false,
    );

    expect(outcome.attempt.isSkipped, isTrue);
    expect(outcome.summary!.session.skipped, 1);
    expect(await harness.cards.watchErrorCards().first, isEmpty);
  });

  test('past-error session resolves a card when answered correctly', () async {
    final practice = await harness.seedPractice(count: 1);
    final first = await service.startPractice(practice.practiceId);
    await service.submitAnswer(
      start: first,
      item: first.items.single,
      selectedIndexes: const [1],
      reasoning: 'Wrong',
      distracted: false,
    );
    harness.clock.advance(errorReviewDelay);

    final past = await service.startPastErrors();
    expect(past.session.mode, SessionMode.pastErrors);
    expect(past.errorCards, hasLength(1));
    final outcome = await service.submitAnswer(
      start: past,
      item: past.items.single,
      selectedIndexes: const [0],
      reasoning: 'Now I know',
      distracted: false,
    );

    expect(outcome.summary!.session.correct, 1);
    expect(await harness.cards.dueErrors(), isEmpty);
    final history = await harness.cards.watchResolvedErrors().first;
    expect(history, hasLength(1));
    expect(history.single.status, ErrorCardStatus.resolved);
  });

  test(
    'a wrong past-error answer schedules the next attempt in 48 hours',
    () async {
      final practice = await harness.seedPractice(count: 1);
      final first = await service.startPractice(practice.practiceId);
      await service.submitAnswer(
        start: first,
        item: first.items.single,
        selectedIndexes: const [1],
        reasoning: 'Wrong',
        distracted: false,
      );
      harness.clock.advance(errorReviewDelay);

      final past = await service.startPastErrors();
      harness.clock.advance(const Duration(minutes: 10));
      await service.submitAnswer(
        start: past,
        item: past.items.single,
        selectedIndexes: const [1],
        reasoning: 'Still wrong',
        distracted: false,
      );

      expect(await harness.cards.dueErrors(), isEmpty);
      harness.clock.advance(errorReviewDelay);
      expect(await harness.cards.dueErrors(), hasLength(1));
    },
  );

  test('resume returns the first unanswered question', () async {
    final practice = await harness.seedPractice(count: 2);
    final start = await service.startPractice(practice.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.first,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );

    final resumed = await service.resume(start.session.id);
    expect(resumed.answeredCount, 1);
    expect(resumed.currentItem!.question.id, start.items.last.question.id);
    await service.submitAnswer(
      start: resumed,
      item: resumed.currentItem!,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    expect(
      (await harness.sessions.sessionById(start.session.id))!.status,
      SessionStatus.completed,
    );
  });

  test('discard deletes the session and its error cards', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await service.startPractice(practice.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );
    expect(await harness.cards.watchErrorCards().first, hasLength(1));

    await service.discard(start.session.id);
    expect(await harness.sessions.sessionById(start.session.id), isNull);
    expect(await harness.cards.watchErrorCards().first, isEmpty);
  });

  test('mixed session takes questions from every practice', () async {
    await harness.seedPractice(topicName: 'A', practiceName: 'One', count: 2);
    await harness.seedPractice(topicName: 'B', practiceName: 'Two', count: 1);

    final start = await service.startMixed();
    expect(start.session.mode, SessionMode.mixed);
    expect(start.items, hasLength(3));
    expect(start.items.map((item) => item.topicName).toSet(), {'A', 'B'});
  });

  test('summary counts distinct looked-up terms', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await service.startPractice(practice.practiceId);
    await harness.cards.createConcept(
      sessionId: start.session.id,
      questionId: start.items.single.question.id,
      term: 'GCP',
      definition: 'Google Cloud Platform',
      context: 'Question',
      topicName: 'Topic',
      source: ConceptSource.ai,
      createdAt: harness.clock.now().toUtc(),
    );
    await harness.cards.createConcept(
      sessionId: start.session.id,
      questionId: start.items.single.question.id,
      term: 'GCP',
      definition: 'Google Cloud Platform',
      context: 'Question',
      topicName: 'Topic',
      source: ConceptSource.ai,
      createdAt: harness.clock.now().toUtc(),
    );
    final outcome = await service.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );

    expect(outcome.summary!.lookupCount, 1);
    expect(outcome.summary!.conceptCount, 2);
  });
}
