import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';

import '../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late SessionService sessions;

  setUp(() {
    harness = TestHarness();
    sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
  });

  tearDown(() async {
    await harness.close();
  });

  test('topic stats update from completed sessions and due errors', () async {
    final practice = await harness.seedPractice(count: 2);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );

    var summary = (await harness.practices.watchTopicSummaries().first).single;
    expect(summary.sessionCount, 1);
    expect(summary.answeredCount, 2);
    expect(summary.correctCount, 1);
    expect(summary.correctQuestionCount, 1);
    expect(summary.accuracy, 0.5);
    expect(summary.progress, 1);
    expect(summary.activeErrorCount, 1);
    expect(summary.dueErrorCount, 0);

    harness.clock.advance(errorReviewDelay);
    summary = (await harness.practices.watchTopicSummaries().first).single;
    expect(summary.dueErrorCount, 1);

    final home = await harness.practices.watchHomeStats().first;
    expect(home.dueErrors, 1);
    expect(home.activeErrors, 1);
    expect(home.unexportedCards, 0);
  });

  test('topic progress records completed session history', () async {
    final practice = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 2,
    );
    var start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    harness.clock.advance(const Duration(hours: 1));

    start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );

    final progress = await harness.practices
        .watchTopicProgress(practice.topicId)
        .first;
    expect(progress, hasLength(2));
    expect(progress.first.practiceName, 'Core');
    expect(progress.first.score, 1);
    expect(progress.last.score, 0);
    expect(
      progress.first.finishedAt.isBefore(progress.last.finishedAt),
      isTrue,
    );
  });

  test(
    'progress counts answered questions over total minus unanswered',
    () async {
      final practice = await harness.seedPractice(count: 3);
      final extraPracticeId = await harness.practices.createPractice(
        topicId: practice.topicId,
        name: 'Untouched',
        description: '',
        contentHash: 'untouched-hash',
        importedAt: harness.clock.now().toUtc(),
      );
      await harness.practices.createQuestions(extraPracticeId, const [
        QuestionDraft(
          prompt: 'Never seen 1?',
          alternatives: ['Correct', 'Wrong'],
          correctIndexes: [0],
          explanation: 'Because it is correct.',
          alternativeExplanations: ['Correct.', 'Wrong.'],
        ),
        QuestionDraft(
          prompt: 'Never seen 2?',
          alternatives: ['Correct', 'Wrong'],
          correctIndexes: [0],
          explanation: 'Because it is correct.',
          alternativeExplanations: ['Correct.', 'Wrong.'],
        ),
      ]);
      final start = await sessions.startPractice(practice.practiceId);
      await sessions.submitAnswer(
        start: start,
        item: start.items.first,
        selectedIndexes: const [1],
        reasoning: '',
        distracted: false,
      );
      await sessions.finishEarly(start: start, markSkipped: false);

      final summary =
          (await harness.practices.watchTopicSummaries().first).single;
      expect(summary.questionCount, 5);
      expect(summary.attemptedQuestionCount, 1);
      expect(summary.unansweredQuestionCount, 2);
      expect(summary.relevantQuestionCount, 3);
      expect(summary.answeredCount, 1);
      expect(summary.correctCount, 0);
      expect(summary.accuracy, 0);
      expect(summary.progress, closeTo(1 / 3, 0.0001));
    },
  );

  test('subtopic statistics group accuracy and progress', () async {
    final practice = await harness.seedPractice(
      count: 4,
      subtopics: const ['Algebra', 'Algebra', 'Geometry', ''],
    );
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[2],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[3],
      selectedIndexes: const [],
      reasoning: '',
      distracted: false,
    );

    final stats = await harness.practices
        .watchSubtopicStats(practice.topicId)
        .first;

    expect(stats.map((stat) => stat.label), [
      'Algebra',
      'Geometry',
      'Uncategorized',
    ]);
    final algebra = stats.firstWhere((stat) => stat.label == 'Algebra');
    expect(algebra.questionCount, 2);
    expect(algebra.attemptedQuestionCount, 2);
    expect(algebra.answeredCount, 2);
    expect(algebra.correctCount, 1);
    expect(algebra.accuracy, 0.5);
    expect(algebra.progress, 1);

    final geometry = stats.firstWhere((stat) => stat.label == 'Geometry');
    expect(geometry.accuracy, 1);
    expect(geometry.progress, 1);

    final uncategorized = stats.firstWhere((stat) => stat.isUncategorized);
    expect(uncategorized.questionCount, 1);
    expect(uncategorized.attemptedQuestionCount, 0);
    expect(uncategorized.answeredCount, 0);
    expect(uncategorized.progress, 0);
  });

  test('questions without a subtopic form one uncategorized bucket', () async {
    final practice = await harness.seedPractice(count: 2);
    final stats = await harness.practices
        .watchSubtopicStats(practice.topicId)
        .first;

    expect(stats, hasLength(1));
    expect(stats.single.isUncategorized, isTrue);
    expect(stats.single.questionCount, 2);
  });

  test('deleting a practice removes its answers, cards and stats', () async {
    final practice = await harness.seedPractice(count: 2);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );

    var summary = (await harness.practices.watchTopicSummaries().first).single;
    expect(summary.answeredCount, 2);
    expect(summary.correctCount, 1);
    expect(summary.activeErrorCount, 1);
    expect(
      await harness.practices.watchTopicProgress(practice.topicId).first,
      hasLength(1),
    );
    expect((await harness.practices.watchHomeStats().first).activeErrors, 1);

    await harness.practices.deletePractice(practice.practiceId);

    summary = (await harness.practices.watchTopicSummaries().first).single;
    expect(summary.questionCount, 0);
    expect(summary.answeredCount, 0);
    expect(summary.correctCount, 0);
    expect(summary.activeErrorCount, 0);
    expect(summary.sessionCount, 0);
    expect(summary.progress, 0);
    expect(
      await harness.practices.watchTopicProgress(practice.topicId).first,
      isEmpty,
    );
    expect(
      await harness.practices.watchSubtopicStats(practice.topicId).first,
      isEmpty,
    );
    expect(await harness.practices.watchHomeStats().first, isNotNull);
    expect((await harness.practices.watchHomeStats().first).activeErrors, 0);
    expect(
      await harness.database.select(harness.database.attempts).get(),
      isEmpty,
    );
    expect(
      await harness.database.select(harness.database.errorCards).get(),
      isEmpty,
    );
    expect(
      await harness.database.select(harness.database.sessionQuestions).get(),
      isEmpty,
    );

    await harness.practices.deleteTopic(practice.topicId);
    expect(await harness.practices.watchTopicSummaries().first, isEmpty);
    expect(await harness.practices.watchHomeStats().first, isNotNull);
  });

  test('unfinished sessions do not affect stats', () async {
    final practice = await harness.seedPractice(count: 2);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.first,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    final summary =
        (await harness.practices.watchTopicSummaries().first).single;
    expect(summary.sessionCount, 0);
    expect(summary.answeredCount, 0);
    expect(summary.progress, 0);
  });
}
