import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/data/mappers.dart';
import 'package:question_practice/core/database/app_database.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/domain/review_service.dart';
import 'package:sqlite3/sqlite3.dart';

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

  Future<Question> onlyQuestion(int practiceId) async {
    return (await harness.practices.questionsForPractice(practiceId)).single;
  }

  Future<AnswerOutcome> answerWrong(
    SessionStart start, {
    String reasoning = 'Wrong again',
    bool distracted = false,
  }) {
    return sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: reasoning,
      distracted: distracted,
    );
  }

  test(
    'a repeated wrong in a later session reopens the same active card',
    () async {
      final practice = await harness.seedPractice(count: 1);
      final question = await onlyQuestion(practice.practiceId);

      final first = await sessions.startPractice(practice.practiceId);
      await answerWrong(first, reasoning: 'First mistake');
      final original = await harness.cards.activeErrorForQuestion(question.id);
      expect(original, isNotNull);
      expect(original!.needsDetails, isTrue);

      await review.saveErrorDetails(
        cardId: original.id,
        bias: 'Wrong layer',
        vaccine: 'Read the layer names',
      );
      final completed = await harness.cards.errorCardById(original.id);
      expect(completed!.needsDetails, isFalse);
      expect(completed.detailsCompletedAt, isNotNull);
      await harness.database.cardDao.markErrorCardsExported([
        original.id,
      ], harness.clock.now().toUtc());
      final exported = await harness.cards.errorCardById(original.id);
      expect(exported!.exportedAt, isNotNull);

      harness.clock.advance(const Duration(hours: 2));
      final second = await sessions.startPractice(practice.practiceId);
      await answerWrong(second, reasoning: 'Same mistake again');

      final repeated = await harness.cards.activeErrorForQuestion(question.id);
      expect(repeated, isNotNull);
      expect(repeated!.id, original.id);
      expect(repeated.needsDetails, isTrue);
      expect(repeated.exportedAt, isNull);
      expect(repeated.reasoning, 'Same mistake again');
      expect(repeated.bias, 'Wrong layer');
      expect(repeated.vaccine, 'Read the layer names');
      expect(
        repeated.lastWrongAt.isAfter(completed.detailsCompletedAt!),
        isTrue,
      );

      final cards = await harness.cards.watchErrorCards().first;
      expect(
        cards.where((card) => card.questionId == question.id),
        hasLength(1),
      );
      final homeStats = await harness.database.statsDao
          .watchHomeStats(harness.clock.now().toUtc())
          .first;
      expect(homeStats.incompleteErrorCards, 1);
    },
  );

  test(
    'the later session summary counts the repeated error and offers review',
    () async {
      final practice = await harness.seedPractice(count: 1);
      final question = await onlyQuestion(practice.practiceId);

      final first = await sessions.startPractice(practice.practiceId);
      await answerWrong(first);
      final card = await harness.cards.activeErrorForQuestion(question.id);
      await review.saveErrorDetails(
        cardId: card!.id,
        bias: 'Wrong layer',
        vaccine: 'Read the layer names',
      );

      harness.clock.advance(const Duration(hours: 2));
      final second = await sessions.startPractice(practice.practiceId);
      final outcome = await answerWrong(second);

      expect(outcome.summary, isNotNull);
      expect(outcome.summary!.errorCardsNeedingNotes, 1);
      expect(outcome.summary!.hasReviewableIssues, isTrue);

      final data = await review.load(second.session.id);
      expect(data, isNotNull);
      final errorSteps = data!.steps.whereType<ErrorReviewStep>().toList();
      expect(errorSteps, hasLength(1));
      expect(errorSteps.single.card.id, card.id);

      final pending = await harness.cards.watchErrorsNeedingDetails().first;
      expect(pending.map((item) => item.id), contains(card.id));
    },
  );

  test(
    'completing details again clears the repeated-error pending state',
    () async {
      final practice = await harness.seedPractice(count: 1);
      final question = await onlyQuestion(practice.practiceId);

      final first = await sessions.startPractice(practice.practiceId);
      await answerWrong(first);
      final card = await harness.cards.activeErrorForQuestion(question.id);
      await review.saveErrorDetails(
        cardId: card!.id,
        bias: 'First bias',
        vaccine: 'First vaccine',
      );

      harness.clock.advance(const Duration(hours: 2));
      final second = await sessions.startPractice(practice.practiceId);
      await answerWrong(second);
      expect(
        (await harness.cards.errorCardById(card.id))!.needsDetails,
        isTrue,
      );

      harness.clock.advance(const Duration(minutes: 1));
      await review.saveErrorDetails(
        cardId: card.id,
        bias: 'Second bias',
        vaccine: 'Second vaccine',
      );

      final cleared = await harness.cards.errorCardById(card.id);
      expect(cleared!.needsDetails, isFalse);
      expect(cleared.bias, 'Second bias');
      expect(cleared.vaccine, 'Second vaccine');
      final pending = await harness.cards.watchErrorsNeedingDetails().first;
      expect(pending.map((item) => item.id), isNot(contains(card.id)));
    },
  );

  test('the first wrong creates exactly one active card', () async {
    final practice = await harness.seedPractice(count: 2);
    final first = await sessions.startPractice(practice.practiceId);
    final outcome = await sessions.submitAnswer(
      start: first,
      item: first.items.first,
      selectedIndexes: const [1],
      reasoning: 'First mistake',
      distracted: false,
    );

    final cards = await harness.cards
        .watchErrorCards(includeExported: true)
        .first;
    expect(cards, hasLength(1));
    expect(cards.single.status, ErrorCardStatus.active);
    expect(cards.single.needsDetails, isTrue);
    expect(outcome.summary, isNull);
  });

  test(
    'a resolved error followed by a wrong answer creates a new active card',
    () async {
      final practice = await harness.seedPractice(count: 1);
      final question = await onlyQuestion(practice.practiceId);

      final first = await sessions.startPractice(practice.practiceId);
      await answerWrong(first);
      final original = await harness.cards.activeErrorForQuestion(question.id);

      harness.clock.advance(errorReviewDelay);
      final past = await sessions.startPastErrors();
      await sessions.submitAnswer(
        start: past,
        item: past.items.single,
        selectedIndexes: const [0],
        reasoning: 'Now correct',
        distracted: false,
      );
      expect(await harness.cards.activeErrorForQuestion(question.id), isNull);

      harness.clock.advance(const Duration(hours: 1));
      final again = await sessions.startPractice(practice.practiceId);
      await answerWrong(again, reasoning: 'Forgot it again');
      final replacement = await harness.cards.activeErrorForQuestion(
        question.id,
      );

      expect(replacement, isNotNull);
      expect(replacement!.id, isNot(original!.id));
      final cards = await harness.cards
          .watchErrorCards(includeExported: true)
          .first;
      expect(
        cards.where((card) => card.status == ErrorCardStatus.active),
        hasLength(1),
      );
      final resolved = cards.where((card) => card.isResolved);
      expect(resolved, hasLength(1));
      expect(resolved.single.id, original.id);
    },
  );

  test(
    'correct, skipped and distracted answers create no wrong errors',
    () async {
      final practice = await harness.seedPractice(count: 3);
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
        selectedIndexes: const [],
        reasoning: '',
        distracted: false,
      );
      final distracted = await sessions.submitAnswer(
        start: start,
        item: start.items[2],
        selectedIndexes: const [1],
        reasoning: 'Lost focus',
        distracted: true,
      );
      expect(distracted.attempt.distracted, isTrue);

      expect(await harness.cards.watchErrorCards().first, isEmpty);
      expect(await harness.cards.watchErrorsNeedingDetails().first, isEmpty);
      expect(await harness.cards.dueErrors(), isEmpty);
      final summary = await sessions.summaryFor(start.session.id);
      expect(summary.errorCardsNeedingNotes, 0);
      final data = await review.load(start.session.id);
      expect(data!.steps.whereType<ErrorReviewStep>(), isEmpty);
    },
  );

  test('a distracted repeat does not reopen a completed error', () async {
    final practice = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(practice.practiceId);

    final first = await sessions.startPractice(practice.practiceId);
    await answerWrong(first);
    final card = await harness.cards.activeErrorForQuestion(question.id);
    await review.saveErrorDetails(
      cardId: card!.id,
      bias: 'Known bias',
      vaccine: 'Known vaccine',
    );

    harness.clock.advance(const Duration(hours: 2));
    final second = await sessions.startPractice(practice.practiceId);
    final outcome = await answerWrong(second, distracted: true);
    expect(outcome.summary, isNotNull);

    final stored = await harness.cards.errorCardById(card.id);
    expect(stored!.needsDetails, isFalse);
    expect(stored.distracted, isTrue);
    expect(await harness.cards.watchErrorsNeedingDetails().first, isEmpty);
    expect(outcome.summary!.errorCardsNeedingNotes, 0);
    final data = await review.load(second.session.id);
    expect(data!.steps.whereType<ErrorReviewStep>(), isEmpty);
  });

  test(
    'schema 14 preserves legacy error cards and reopens only pending ones',
    () async {
      final sqlite = sqlite3.openInMemory();
      sqlite.execute('''
      CREATE TABLE error_cards (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        session_id INTEGER NULL,
        question TEXT NOT NULL,
        alternatives_json TEXT NOT NULL,
        correct_indexes_json TEXT NOT NULL DEFAULT '[0]',
        wrong_indexes_json TEXT NOT NULL DEFAULT '[0]',
        reasoning TEXT NOT NULL DEFAULT '',
        explanation TEXT NOT NULL DEFAULT '',
        alternative_explanations_json TEXT NOT NULL DEFAULT '[]',
        bias TEXT NOT NULL DEFAULT '',
        vaccine TEXT NOT NULL DEFAULT '',
        topic_name TEXT NOT NULL DEFAULT '',
        cognitive_type TEXT NOT NULL DEFAULT 'contrast',
        subtopic TEXT NOT NULL DEFAULT '',
        mistake_kinds_json TEXT NOT NULL DEFAULT '[]',
        distracted INTEGER NOT NULL DEFAULT 0,
        practice_name TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_wrong_at INTEGER NOT NULL,
        due_at INTEGER NOT NULL,
        details_completed_at INTEGER NULL,
        resolved_at INTEGER NULL,
        exported_at INTEGER NULL
      )
    ''');
      sqlite.execute('''
      INSERT INTO error_cards (
        id, question_id, question, alternatives_json, status, created_at,
        last_wrong_at, due_at, details_completed_at, exported_at, reasoning
      ) VALUES
        (1, 7, 'Repeated?', '["A","B"]', 'active', 1000, 2000, 2000, 1500,
         3000, 'Missed again after details.'),
        (2, 8, 'Done?', '["A","B"]', 'active', 1000, 1000, 2000, 2000,
         3000, 'Details are current.'),
        (3, 9, 'Never detailed?', '["A","B"]', 'active', 1000, 2000, 2000,
         NULL, 3000, 'Details never completed.'),
        (4, 10, 'Resolved?', '["A","B"]', 'resolved', 1000, 2000, 2000,
         1500, 3000, 'Resolved history stays.')
    ''');
      sqlite.execute('PRAGMA user_version = 13');

      final database = AppDatabase(NativeDatabase.opened(sqlite));
      addTearDown(database.close);

      expect(database.schemaVersion, 14);
      final rows = await database.select(database.errorCards).get();
      expect(rows, hasLength(4));
      final byId = {for (final row in rows) row.id: row};

      final repeated = errorCardFromRow(byId[1]!);
      expect(repeated.needsDetails, isTrue);
      expect(repeated.exportedAt, isNull);
      expect(repeated.reasoning, 'Missed again after details.');

      final completed = errorCardFromRow(byId[2]!);
      expect(completed.needsDetails, isFalse);
      expect(completed.exportedAt, isNotNull);

      final neverDetailed = errorCardFromRow(byId[3]!);
      expect(neverDetailed.needsDetails, isTrue);
      expect(neverDetailed.exportedAt, isNull);

      final resolved = errorCardFromRow(byId[4]!);
      expect(resolved.status, ErrorCardStatus.resolved);
      expect(resolved.exportedAt, isNotNull);
      expect(resolved.reasoning, 'Resolved history stays.');
    },
  );
}
