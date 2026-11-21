import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
      counter.statements.where(
        (statement) => _readsTable(statement, 'error_cards'),
      ),
      hasLength(1),
    );
  });
}
