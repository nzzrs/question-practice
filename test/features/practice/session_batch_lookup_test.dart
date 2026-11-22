import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/database/id_batches.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';

import '../../helpers/test_harness.dart';

class _SelectCounter extends QueryInterceptor {
  final List<String> statements = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement);
    return executor.runSelect(statement, args);
  }
}

bool _readsTable(String statement, String table) {
  return RegExp('FROM\\s+"?${RegExp.escape(table)}"?').hasMatch(statement);
}

void main() {
  late TestHarness harness;
  late SessionService service;
  late _SelectCounter counter;

  setUp(() {
    counter = _SelectCounter();
    harness = TestHarness(
      executor: NativeDatabase.memory().interceptWith(counter),
    );
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

  Future<void> answerAllWrong(int practiceId) async {
    final start = await service.startPractice(practiceId);
    for (final item in start.items) {
      await service.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: const [1],
        reasoning: '',
        distracted: false,
      );
    }
  }

  test('startPastErrors loads due questions with one batch query', () async {
    final practice = await harness.seedPractice(count: 3);
    await answerAllWrong(practice.practiceId);
    harness.clock.advance(errorReviewDelay);

    counter.statements.clear();
    final past = await service.startPastErrors();

    expect(past.items, hasLength(3));
    expect(
      past.items.map((item) => item.question.id),
      (await harness.cards.dueErrors()).map((card) => card.questionId),
    );
    expect(past.errorCards.keys.toSet(), {
      for (final item in past.items) item.question.id,
    });
    expect(
      counter.statements.where(
        (statement) => _readsTable(statement, 'questions'),
      ),
      hasLength(1),
    );
  });

  test('resume loads active past-error cards with one batch query', () async {
    final practice = await harness.seedPractice(count: 3);
    await answerAllWrong(practice.practiceId);
    harness.clock.advance(errorReviewDelay);
    final past = await service.startPastErrors();

    counter.statements.clear();
    final resumed = await service.resume(past.session.id);

    expect(resumed.errorCards, hasLength(3));
    expect(
      resumed.items.map((item) => item.question.id),
      past.items.map((item) => item.question.id),
    );
    for (final item in resumed.items) {
      expect(
        resumed.errorCards[item.question.id]?.questionId,
        item.question.id,
      );
    }
    expect(
      counter.statements.where(
        (statement) => _readsTable(statement, 'error_cards'),
      ),
      hasLength(1),
    );
  });

  test('batched lookups skip empty sets and chunk large id sets', () async {
    final practice = await harness.seedPractice(count: 3);
    final questions = await harness.practices.questionsForPractice(
      practice.practiceId,
    );
    final seededIds = {for (final question in questions) question.id};

    counter.statements.clear();
    expect(await harness.sessions.questionsByIds(const []), isEmpty);
    expect(await harness.cards.activeErrorsForQuestions(const []), isEmpty);
    expect(counter.statements, isEmpty);

    counter.statements.clear();
    final found = await harness.sessions.questionsByIds([
      ...seededIds,
      for (var id = 1; id <= 1200; id++) id,
    ]);

    expect(found.map((question) => question.id).toSet(), seededIds);
    final lookups = [
      for (final statement in counter.statements)
        if (_readsTable(statement, 'questions')) statement,
    ];
    expect(lookups, hasLength(2));
    for (final statement in lookups) {
      final bound = RegExp(r'\?').allMatches(statement).length;
      expect(bound, lessThanOrEqualTo(maxIdsPerQuery));
    }
  });
}
