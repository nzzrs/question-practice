import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';

import '../../helpers/test_harness.dart';

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

  Future<void> completeSession(int practiceId, {int wrongAt = -1}) async {
    final start = await sessions.startPractice(practiceId);
    for (var index = 0; index < start.items.length; index++) {
      await sessions.submitAnswer(
        start: start,
        item: start.items[index],
        selectedIndexes: [index == wrongAt ? 1 : 0],
        reasoning: '',
        distracted: false,
      );
    }
  }

  Future<void> expectHistoryCounts({
    required int attempts,
    required int sessionsCount,
    required int cards,
  }) async {
    expect(
      await harness.database.select(harness.database.attempts).get(),
      hasLength(attempts),
    );
    expect(
      await harness.database.select(harness.database.sessions).get(),
      hasLength(sessionsCount),
    );
    expect(
      await harness.database.select(harness.database.errorCards).get(),
      hasLength(cards),
    );
  }

  test('renameSubtopic renames only matching questions in the topic', () async {
    final main = await harness.seedPractice(
      topicName: 'Networking',
      count: 4,
      subtopics: const ['Alpha', 'Alpha', 'Beta', ''],
    );
    final other = await harness.seedPractice(
      topicName: 'Other',
      count: 2,
      subtopics: const ['Alpha', 'Alpha'],
    );
    await completeSession(main.practiceId, wrongAt: 0);
    final before = await harness.practices.questionsForPractice(
      main.practiceId,
    );
    await expectHistoryCounts(attempts: 4, sessionsCount: 1, cards: 1);

    await harness.practices.renameSubtopic(main.topicId, 'Alpha', 'Gamma');

    final after = await harness.practices.questionsForPractice(main.practiceId);
    expect(after.map((question) => question.id), before.map((q) => q.id));
    expect(after.map((question) => question.subtopic), [
      'Gamma',
      'Gamma',
      'Beta',
      '',
    ]);
    final otherQuestions = await harness.practices.questionsForPractice(
      other.practiceId,
    );
    expect(
      otherQuestions.map((question) => question.subtopic),
      everyElement('Alpha'),
    );
    await expectHistoryCounts(attempts: 4, sessionsCount: 1, cards: 1);
  });

  test('deleteSubtopics clears names and keeps every question', () async {
    final main = await harness.seedPractice(
      topicName: 'Networking',
      count: 4,
      subtopics: const ['Alpha', 'Beta', 'Beta', ''],
    );
    await completeSession(main.practiceId, wrongAt: 1);
    final before = await harness.practices.questionsForPractice(
      main.practiceId,
    );
    await expectHistoryCounts(attempts: 4, sessionsCount: 1, cards: 1);

    await harness.practices.deleteSubtopics(main.topicId, const ['Beta']);

    final after = await harness.practices.questionsForPractice(main.practiceId);
    expect(after.map((question) => question.id), before.map((q) => q.id));
    expect(after.map((question) => question.subtopic), ['Alpha', '', '', '']);
    final rows = await harness.database
        .select(harness.database.questions)
        .get();
    for (var index = 1; index <= 2; index++) {
      final row = rows.singleWhere((row) => row.id == after[index].id);
      expect(row.subtopic, isNull);
    }
    await expectHistoryCounts(attempts: 4, sessionsCount: 1, cards: 1);
  });

  test('deleting Uncategorized changes nothing', () async {
    final main = await harness.seedPractice(
      count: 3,
      subtopics: const ['Alpha', '', 'Beta'],
    );
    final before = await harness.practices.questionsForPractice(
      main.practiceId,
    );

    await harness.practices.deleteSubtopics(main.topicId, const ['']);

    final after = await harness.practices.questionsForPractice(main.practiceId);
    expect(after.map((question) => question.id), before.map((q) => q.id));
    expect(after.map((question) => question.subtopic), ['Alpha', '', 'Beta']);
  });

  test('mergeSubtopics applies one name across selected categories', () async {
    final main = await harness.seedPractice(
      topicName: 'Networking',
      count: 4,
      subtopics: const ['Alpha', 'Beta', '', 'Alpha'],
    );
    final other = await harness.seedPractice(
      topicName: 'Other',
      count: 1,
      subtopics: const ['Alpha'],
    );
    await completeSession(main.practiceId, wrongAt: 2);
    final before = await harness.practices.questionsForPractice(
      main.practiceId,
    );
    await expectHistoryCounts(attempts: 4, sessionsCount: 1, cards: 1);

    await harness.practices.mergeSubtopics(main.topicId, const [
      'Alpha',
      'Beta',
      '',
    ], 'Combined');

    final after = await harness.practices.questionsForPractice(main.practiceId);
    expect(after.map((question) => question.id), before.map((q) => q.id));
    expect(after.map((question) => question.subtopic), [
      'Combined',
      'Combined',
      'Combined',
      'Combined',
    ]);
    final otherQuestions = await harness.practices.questionsForPractice(
      other.practiceId,
    );
    expect(otherQuestions.single.subtopic, 'Alpha');
    await expectHistoryCounts(attempts: 4, sessionsCount: 1, cards: 1);
  });
}
