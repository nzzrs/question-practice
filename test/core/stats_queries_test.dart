import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/database/app_database.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';

import '../helpers/test_harness.dart';

Future<int> _completeSession(
  SessionService sessions,
  int practiceId, {
  bool Function(int index)? correct,
}) async {
  final start = await sessions.startPractice(practiceId);
  for (var index = 0; index < start.items.length; index++) {
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

/// Waits for the stream's first value, applies a write and waits for an
/// emission that matches. A missing dependency leaves the stream stale, so the
/// helper fails with [description] after the timeout.
Future<void> _expectRefresh(
  Stream<List<TopicSummary>> stream,
  String description, {
  required Future<void> Function() mutate,
  required bool Function(List<TopicSummary> rows) matches,
}) async {
  final initial = Completer<void>();
  final refreshed = Completer<void>();
  var emitted = false;
  final subscription = stream.listen(
    (rows) {
      if (!emitted) {
        emitted = true;
        if (!initial.isCompleted) initial.complete();
        return;
      }
      if (!refreshed.isCompleted && matches(rows)) refreshed.complete();
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!initial.isCompleted) initial.completeError(error, stackTrace);
      if (!refreshed.isCompleted) refreshed.completeError(error, stackTrace);
    },
  );
  try {
    await initial.future.timeout(const Duration(seconds: 10));
    await mutate();
    await refreshed.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw StateError('Stream stayed stale: $description'),
    );
  } finally {
    await subscription.cancel();
  }
}

void _expectSameSummary(TopicSummary actual, TopicSummary expected) {
  expect(actual.topic.id, expected.topic.id);
  expect(actual.topic.name, expected.topic.name);
  expect(actual.topic.description, expected.topic.description);
  expect(actual.topic.priority, expected.topic.priority);
  expect(actual.topic.ankiDeck, expected.topic.ankiDeck);
  expect(actual.topic.createdAt, expected.topic.createdAt);
  expect(actual.topic.minimumScore, expected.topic.minimumScore);
  expect(actual.topic.targetScore, expected.topic.targetScore);
  expect(actual.topic.archived, expected.topic.archived);
  expect(actual.practiceCount, expected.practiceCount);
  expect(actual.questionCount, expected.questionCount);
  expect(actual.attemptedQuestionCount, expected.attemptedQuestionCount);
  expect(actual.unansweredQuestionCount, expected.unansweredQuestionCount);
  expect(actual.answeredCount, expected.answeredCount);
  expect(actual.correctCount, expected.correctCount);
  expect(actual.correctQuestionCount, expected.correctQuestionCount);
  expect(actual.activeErrorCount, expected.activeErrorCount);
  expect(actual.dueErrorCount, expected.dueErrorCount);
  expect(actual.sessionCount, expected.sessionCount);
  expect(actual.lastPracticedAt, expected.lastPracticedAt);
  expect(actual.accuracy, expected.accuracy);
  expect(actual.progress, expected.progress);
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

  test('filtered topic summaries match the full library', () async {
    final gamma = await harness.seedPractice(
      topicName: 'Gamma',
      practiceName: 'Core',
      count: 3,
      priority: 1,
    );
    final beta = await harness.seedPractice(
      topicName: 'Beta',
      practiceName: 'Core',
      count: 2,
      priority: 2,
    );
    final alpha = await harness.seedPractice(
      topicName: 'alpha',
      practiceName: 'Core',
      count: 1,
      priority: null,
    );
    final zeta = await harness.seedPractice(
      topicName: 'Zeta',
      practiceName: 'Legacy',
      count: 2,
      priority: 1,
    );
    final old = await harness.seedPractice(
      topicName: 'Archived',
      practiceName: 'Legacy',
      count: 1,
      priority: null,
    );
    await harness.practices.setTopicArchived(zeta.topicId, true);
    await harness.practices.setTopicArchived(old.topicId, true);

    await _completeSession(
      sessions,
      gamma.practiceId,
      correct: (index) => index == 0,
    );
    await _completeSession(sessions, zeta.practiceId);
    harness.clock.advance(errorReviewDelay);

    final all = await harness.practices
        .watchTopicSummaries(includeArchived: true)
        .first;
    final active = await harness.practices.watchTopicSummaries().first;
    final archived = await harness.practices
        .watchArchivedTopicSummaries()
        .first;

    expect(all.map((summary) => summary.topic.name), [
      'Gamma',
      'Zeta',
      'Beta',
      'alpha',
      'Archived',
    ]);
    expect(
      active.map((summary) => summary.topic.id),
      all.where((summary) => !summary.topic.archived).map((s) => s.topic.id),
    );
    expect(
      archived.map((summary) => summary.topic.id),
      all.where((summary) => summary.topic.archived).map((s) => s.topic.id),
    );
    expect(active.map((summary) => summary.topic.id), [
      gamma.topicId,
      beta.topicId,
      alpha.topicId,
    ]);
    expect(archived.map((summary) => summary.topic.id), [
      zeta.topicId,
      old.topicId,
    ]);

    for (final expected in all) {
      final actual = await harness.practices
          .watchTopicSummary(expected.topic.id)
          .first;
      expect(actual, isNotNull);
      _expectSameSummary(actual!, expected);
    }

    final gammaSummary = active.first;
    expect(gammaSummary.answeredCount, 3);
    expect(gammaSummary.correctCount, 1);
    expect(gammaSummary.activeErrorCount, 2);
    expect(gammaSummary.dueErrorCount, 2);
    final zetaSummary = archived.first;
    expect(zetaSummary.sessionCount, 1);
    expect(zetaSummary.correctCount, 2);
    expect(zetaSummary.dueErrorCount, 0);
  });

  test('topic summary query returns null when the topic is gone', () async {
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    await harness.practices.deleteTopic(seeded.topicId);
    expect(
      await harness.practices.watchTopicSummary(seeded.topicId).first,
      isNull,
    );
  });

  test('active list follows archive changes', () async {
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    final stream = harness.practices.watchTopicSummaries();
    await _expectRefresh(
      stream,
      'archive hides the topic',
      mutate: () => harness.practices.setTopicArchived(seeded.topicId, true),
      matches: (rows) => rows.isEmpty,
    );
    await _expectRefresh(
      stream,
      'restore shows the topic',
      mutate: () => harness.practices.setTopicArchived(seeded.topicId, false),
      matches: (rows) => rows.single.topic.id == seeded.topicId,
    );
  });

  test(
    'archived stream refreshes for every stats table',
    () => _verifyRefreshForEveryTable(harness, archived: true),
  );

  test(
    'single-topic stream refreshes for every stats table',
    () => _verifyRefreshForEveryTable(harness, archived: false),
  );
}

/// Runs one observable write per table a summary reads from.
///
/// [archived] selects the archived list; otherwise the single-topic stream is
/// used. Both must invalidate on topics, practices, questions, sessions,
/// session questions, attempts and error cards.
Future<void> _verifyRefreshForEveryTable(
  TestHarness harness, {
  required bool archived,
}) async {
  final sessions = SessionService(
    practices: harness.practices,
    sessions: harness.sessions,
    cards: harness.cards,
    clock: harness.clock,
  );
  final seeded = await harness.seedPractice(
    topicName: 'Armed',
    practiceName: 'Kept',
    count: 1,
  );
  if (archived) {
    await harness.practices.setTopicArchived(seeded.topicId, true);
  }
  final stream = archived
      ? harness.practices.watchArchivedTopicSummaries()
      : harness.practices
            .watchTopicSummary(seeded.topicId)
            .map((row) => row == null ? <TopicSummary>[] : [row]);
  final label = archived ? 'archived' : 'single topic';

  // topics
  await _expectRefresh(
    stream,
    '$label: topic rename',
    mutate: () => harness.practices.updateTopic(
      id: seeded.topicId,
      name: 'Renamed',
      description: 'Topic description',
      priority: 1,
      minimumScore: 70,
      targetScore: 80,
    ),
    matches: (rows) => rows.single.topic.name == 'Renamed',
  );

  // practices
  late int extraPracticeId;
  await _expectRefresh(
    stream,
    '$label: practice insert',
    mutate: () async {
      extraPracticeId = await harness.practices.createPractice(
        topicId: seeded.topicId,
        name: 'Extra',
        description: '',
        contentHash: 'extra',
        importedAt: harness.clock.now().toUtc(),
      );
    },
    matches: (rows) => rows.single.practiceCount == 2,
  );

  // questions
  await _expectRefresh(
    stream,
    '$label: question insert',
    mutate: () => harness.practices.createQuestions(extraPracticeId, const [
      QuestionDraft(
        prompt: 'One?',
        alternatives: ['Right', 'Wrong'],
        correctIndexes: [0],
        explanation: 'Because.',
        alternativeExplanations: ['Right.', 'Wrong.'],
      ),
      QuestionDraft(
        prompt: 'Two?',
        alternatives: ['Right', 'Wrong'],
        correctIndexes: [0],
        explanation: 'Because.',
        alternativeExplanations: ['Right.', 'Wrong.'],
      ),
    ]),
    matches: (rows) => rows.single.questionCount == 3,
  );

  // sessions, session questions and attempts
  final sessionId = await _completeSessionThroughStream(
    sessions,
    stream,
    extraPracticeId,
    label,
  );

  final attempts = await harness.database
      .select(harness.database.attempts)
      .get();
  final target = attempts.firstWhere((row) => row.sessionId == sessionId);

  // sessions (finishedAt changes the last practiced date)
  final later = harness.clock.now().toUtc().add(const Duration(minutes: 5));
  await _expectRefresh(
    stream,
    '$label: session update',
    mutate: () =>
        (harness.database.update(harness.database.sessions)
              ..where((row) => row.id.equals(sessionId)))
            .write(SessionsCompanion(finishedAt: Value(later))),
    matches: (rows) => rows.single.lastPracticedAt == later,
  );

  // attempts
  await _expectRefresh(
    stream,
    '$label: attempt update',
    mutate: () =>
        (harness.database.update(harness.database.attempts)
              ..where((row) => row.id.equals(target.id)))
            .write(const AttemptsCompanion(selectedIndexesJson: Value('[]'))),
    matches: (rows) => rows.single.unansweredQuestionCount == 1,
  );

  // session questions
  await _expectRefresh(
    stream,
    '$label: session question delete',
    mutate: () => (harness.database.delete(
      harness.database.sessionQuestions,
    )..where((row) => row.sessionId.equals(sessionId))).go(),
    matches: (rows) => rows.single.unansweredQuestionCount == 0,
  );

  // error cards
  final errors = await harness.database
      .select(harness.database.errorCards)
      .get();
  expect(errors, hasLength(2));
  await _expectRefresh(
    stream,
    '$label: error card resolve',
    mutate: () => harness.cards.resolveError(
      errors.first.id,
      harness.clock.now().toUtc(),
    ),
    matches: (rows) => rows.single.activeErrorCount == 1,
  );
}

Future<int> _completeSessionThroughStream(
  SessionService sessions,
  Stream<List<TopicSummary>> stream,
  int practiceId,
  String label,
) async {
  final start = await sessions.startPractice(practiceId);
  await _expectRefresh(
    stream,
    '$label: session completion',
    mutate: () async {
      for (final item in start.items) {
        await sessions.submitAnswer(
          start: start,
          item: item,
          selectedIndexes: const [1],
          reasoning: '',
          distracted: false,
        );
      }
      await sessions.finishEarly(start: start, markSkipped: false);
    },
    matches: (rows) =>
        rows.single.sessionCount == 1 &&
        rows.single.answeredCount == 2 &&
        rows.single.activeErrorCount == 2,
  );
  return start.session.id;
}
