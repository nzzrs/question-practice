import 'package:flutter_test/flutter_test.dart';
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
    expect(summary.progress, 0.5);
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
