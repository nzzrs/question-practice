import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';

import '../helpers/test_harness.dart';

Future<int> completeSession(
  SessionService sessions,
  int practiceId, {
  int? answers,
  bool Function(int index)? correct,
}) async {
  final start = await sessions.startPractice(practiceId);
  final count = answers ?? start.items.length;
  for (var index = 0; index < count; index++) {
    await sessions.submitAnswer(
      start: start,
      item: start.items[index],
      selectedIndexes: [(correct?.call(index) ?? true) ? 0 : 1],
      reasoning: '',
      distracted: false,
    );
  }
  await sessions.finishEarly(start: start, markSkipped: false);
  return start.session.id;
}

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

  test(
    'readiness counts correct, wrong, skipped and unknown attempts',
    () async {
      final practice = await harness.seedPractice(count: 6);
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
        selectedIndexes: const [],
        reasoning: '',
        distracted: false,
      );
      await sessions.submitAnswer(
        start: start,
        item: start.items[3],
        selectedIndexes: const [1],
        reasoning: '',
        distracted: false,
      );
      await sessions.setUnknown(
        start: start,
        item: start.items[3],
        unknown: true,
      );
      await sessions.finishEarly(start: start, markSkipped: false);

      final readiness = await harness.practices
          .watchTopicReadiness(practice.topicId)
          .first;
      expect(readiness.answeredCount, 4);
      expect(readiness.correctCount, 1);
      expect(readiness.hasAnswers, isTrue);
      expect(readiness.value, closeTo(0.25, 1e-9));
    },
  );

  test('readiness ignores non-completed sessions', () async {
    final practice = await harness.seedPractice(count: 2);
    await completeSession(sessions, practice.practiceId);

    final inProgress = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: inProgress,
      item: inProgress.items.first,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );

    final abandoned = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: abandoned,
      item: abandoned.items.first,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await harness.sessions.abandonSession(abandoned.session.id);

    final readiness = await harness.practices
        .watchTopicReadiness(practice.topicId)
        .first;
    expect(readiness.answeredCount, 2);
    expect(readiness.correctCount, 2);
    expect(readiness.value, 1);
  });

  test('readiness uses every attempt when fewer than 100 exist', () async {
    final practice = await harness.seedPractice(count: 2);
    await completeSession(
      sessions,
      practice.practiceId,
      answers: 2,
      correct: (index) => index == 0,
    );
    harness.clock.advance(const Duration(hours: 1));
    await completeSession(
      sessions,
      practice.practiceId,
      answers: 1,
      correct: (_) => true,
    );

    final readiness = await harness.practices
        .watchTopicReadiness(practice.topicId)
        .first;
    expect(readiness.answeredCount, 3);
    expect(readiness.correctCount, 2);
    expect(readiness.value, closeTo(2 / 3, 1e-9));
  });

  test(
    'readiness uses the last 100 attempts and the tail of the oldest session',
    () async {
      // 132 attempts across sessions of 40, 2 and 90 questions.
      final practice = await harness.seedPractice(count: 132);
      await completeSession(
        sessions,
        practice.practiceId,
        answers: 40,
        correct: (index) => index >= 32,
      );
      harness.clock.advance(const Duration(hours: 1));
      await completeSession(
        sessions,
        practice.practiceId,
        answers: 2,
        correct: (_) => true,
      );
      harness.clock.advance(const Duration(hours: 1));
      await completeSession(
        sessions,
        practice.practiceId,
        answers: 90,
        correct: (index) => index < 50,
      );

      final readiness = await harness.practices
          .watchTopicReadiness(practice.topicId)
          .first;
      expect(readiness.answeredCount, 100);
      expect(readiness.correctCount, 60);
      expect(readiness.value, closeTo(0.6, 1e-9));
    },
  );

  test('readiness is empty without completed attempts', () async {
    final practice = await harness.seedPractice(count: 2);

    final readiness = await harness.practices
        .watchTopicReadiness(practice.topicId)
        .first;
    expect(readiness.answeredCount, 0);
    expect(readiness.correctCount, 0);
    expect(readiness.hasAnswers, isFalse);
    expect(readiness.value, 0);
  });

  test('deleting selected sessions cascades their captured records', () async {
    final practice = await harness.seedPractice(count: 4);
    final questions = await harness.practices.questionsForPractice(
      practice.practiceId,
    );

    final first = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: first,
      item: first.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: first,
      item: first.items[1],
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: first,
      item: first.items[2],
      selectedIndexes: const [],
      reasoning: '',
      distracted: false,
    );
    await sessions.finishEarly(start: first, markSkipped: false);
    await harness.cards.createConcept(
      sessionId: first.session.id,
      questionId: questions[0].id,
      term: 'TCP',
      definition: 'Transmission Control Protocol',
      context: 'Context',
      topicName: 'Topic',
      source: ConceptSource.manual,
      createdAt: harness.clock.now().toUtc(),
    );
    await harness.cards.createNote(
      sessionId: first.session.id,
      questionId: questions[0].id,
      text: 'Saved phrase',
      context: 'Context',
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    await harness.cards.createManualCard(
      sessionId: first.session.id,
      questionId: questions[0].id,
      question: 'Basic front',
      answer: 'Basic back',
      topicName: 'Topic',
      createdAt: harness.clock.now().toUtc(),
    );
    harness.clock.advance(const Duration(hours: 1));

    final second = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: second,
      item: second.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await sessions.finishEarly(start: second, markSkipped: false);
    harness.clock.advance(const Duration(hours: 1));

    final kept = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: kept,
      item: kept.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await sessions.finishEarly(start: kept, markSkipped: false);

    final inProgress = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: inProgress,
      item: inProgress.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );

    final deleted = await harness.sessions.deleteSessions([
      first.session.id,
      second.session.id,
      inProgress.session.id,
    ]);
    expect(deleted, 2);

    final sessionsRows = await harness.database
        .select(harness.database.sessions)
        .get();
    expect(
      sessionsRows
          .where((row) => row.status == SessionStatus.completed.name)
          .map((row) => row.id),
      [kept.session.id],
    );
    expect(
      await harness.sessions.sessionById(inProgress.session.id),
      isNotNull,
    );

    final sessionQuestions = await harness.database
        .select(harness.database.sessionQuestions)
        .get();
    expect(
      sessionQuestions.where(
        (row) =>
            row.sessionId == first.session.id ||
            row.sessionId == second.session.id,
      ),
      isEmpty,
    );
    final attempts = await harness.database
        .select(harness.database.attempts)
        .get();
    expect(
      attempts.where(
        (row) =>
            row.sessionId == first.session.id ||
            row.sessionId == second.session.id,
      ),
      isEmpty,
    );
    expect(attempts, isNotEmpty);
    expect(
      await harness.database.select(harness.database.errorCards).get(),
      isEmpty,
    );
    expect(
      await harness.database.select(harness.database.skippedQuestions).get(),
      isEmpty,
    );
    expect(
      await harness.database.select(harness.database.concepts).get(),
      isEmpty,
    );
    expect(
      await harness.database.select(harness.database.notes).get(),
      isEmpty,
    );
    expect(
      await harness.database.select(harness.database.manualCards).get(),
      isEmpty,
    );
  });
}
