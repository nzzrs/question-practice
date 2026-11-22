import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';

import '../helpers/test_harness.dart';

class _SelectCounter extends QueryInterceptor {
  final List<String> statements = [];
  final List<List<Object?>> arguments = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement);
    arguments.add(args);
    return executor.runSelect(statement, args);
  }
}

bool _readsTable(String statement, String table) {
  return RegExp('FROM\\s+"?${RegExp.escape(table)}"?').hasMatch(statement);
}

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

void main() {
  test('home reads one filtered summary query per list', () async {
    final counter = _SelectCounter();
    final counted = TestHarness(
      executor: NativeDatabase.memory().interceptWith(counter),
    );
    addTearDown(counted.close);
    final active = await counted.seedPractice(topicName: 'Active', count: 1);
    final archived = await counted.seedPractice(
      topicName: 'Archived',
      count: 1,
    );
    await counted.practices.setTopicArchived(archived.topicId, true);
    counter.statements.clear();

    final container = counted.container();
    addTearDown(container.dispose);
    final activeSub = container.listen(topicSummariesProvider, (_, _) {});
    final archivedSub = container.listen(
      archivedTopicSummariesProvider,
      (_, _) {},
    );
    addTearDown(activeSub.close);
    addTearDown(archivedSub.close);

    final activeRows = await container.read(topicSummariesProvider.future);
    final archivedRows = await container.read(
      archivedTopicSummariesProvider.future,
    );
    expect(activeRows.map((row) => row.topic.id), [active.topicId]);
    expect(archivedRows.map((row) => row.topic.id), [archived.topicId]);

    final summaryQueries = counter.statements
        .where((statement) => _readsTable(statement, 'topics'))
        .toList();
    expect(summaryQueries, hasLength(2));
    expect(
      summaryQueries.where((statement) => statement.contains('archived = 0')),
      hasLength(1),
    );
    expect(
      summaryQueries.where((statement) => statement.contains('archived = 1')),
      hasLength(1),
    );
  });

  test('filtered queries carry one filter and combined last session', () async {
    final counter = _SelectCounter();
    final counted = TestHarness(
      executor: NativeDatabase.memory().interceptWith(counter),
    );
    addTearDown(counted.close);
    final practice = await counted.seedPractice(topicName: 'Cloud', count: 2);
    final countedSessions = SessionService(
      practices: counted.practices,
      sessions: counted.sessions,
      cards: counted.cards,
      clock: counted.clock,
    );
    await _completeSession(countedSessions, practice.practiceId);
    counted.clock.advance(const Duration(hours: 1));
    await _completeSession(
      countedSessions,
      practice.practiceId,
      correct: (_) => false,
    );

    counter.statements.clear();
    final active = await counted.practices.watchTopicSummaries().first;
    expect(active, hasLength(1));
    expect(counter.statements, hasLength(1));
    expect(counter.statements.single, contains('archived = 0'));
    expect(counter.statements.single, isNot(contains('archived = 1')));

    counter.statements.clear();
    counter.arguments.clear();
    final archived = await counted.practices
        .watchArchivedTopicSummaries()
        .first;
    expect(archived, isEmpty);
    expect(counter.statements, hasLength(1));
    expect(counter.statements.single, contains('archived = 1'));
    expect(counter.statements.single, isNot(contains('archived = 0')));

    counter.statements.clear();
    counter.arguments.clear();
    final summary = await counted.practices
        .watchTopicSummary(practice.topicId)
        .first;
    expect(summary, isNotNull);
    expect(counter.statements, hasLength(1));
    expect(counter.statements.single, contains('t.id = ?'));
    expect(counter.arguments.single, contains(practice.topicId));

    counter.statements.clear();
    final practices = await counted.practices
        .watchPracticeSummaries(practice.topicId)
        .first;
    expect(practices.single.lastScore, 0);
    expect(practices.single.questionCount, 2);
    final statement = counter.statements.single;
    expect(statement, contains('LEFT JOIN sessions last_session'));
    expect(statement, isNot(contains('SELECT s.correct')));
    expect(statement, isNot(contains('SELECT s.total')));
    expect(RegExp('FROM sessions s').allMatches(statement), hasLength(2));
  });
}
