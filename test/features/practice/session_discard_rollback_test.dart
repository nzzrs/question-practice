import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/data/error_card_undo.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';

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

  test(
    'discard restores an existing card changed by one wrong answer',
    () async {
      final seeded = await _seedThreeOptionPractice(harness, count: 2);
      final question = (await harness.practices.questionsForPractice(
        seeded.practiceId,
      )).first;
      final baseline = await _seedExistingCard(harness, question);
      harness.clock.advance(const Duration(hours: 3));

      final start = await service.startPractice(seeded.practiceId);
      await service.submitAnswer(
        start: start,
        item: start.items.first,
        selectedIndexes: const [2],
        reasoning: 'New mistake reasoning',
        distracted: false,
      );

      final changed = await harness.cards.errorCardById(baseline.id);
      expect(changed!.wrongIndexes, [2]);
      expect(changed.reasoning, 'New mistake reasoning');
      expect(changed.lastWrongAt, isNot(baseline.lastWrongAt));
      expect(changed.dueAt, isNot(baseline.dueAt));
      expect(changed.exportedAt, isNull);

      await service.discard(start.session.id);

      final restored = await harness.cards.errorCardById(baseline.id);
      _expectSameUndoState(restored!, baseline);
      expect(await harness.sessions.sessionById(start.session.id), isNull);
      expect(
        await harness.sessions.attemptsForSession(start.session.id),
        isEmpty,
      );
      expect(
        await harness.database.settingsDao.getValue(
          errorCardUndoKey(start.session.id),
        ),
        isNull,
      );
    },
  );

  test(
    'repeated writes restore the original, not an intermediate answer',
    () async {
      final seeded = await _seedThreeOptionPractice(harness, count: 3);
      final question = (await harness.practices.questionsForPractice(
        seeded.practiceId,
      )).first;
      final baseline = await _seedExistingCard(harness, question);

      final start = await service.startPractice(seeded.practiceId);
      final item = start.items.first;
      await service.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: const [2],
        reasoning: 'First intermediate reasoning',
        distracted: false,
      );
      await service.setWrongAnswerBullets(
        start: start,
        item: item,
        bullets: const ['Second intermediate reasoning.'],
      );
      await service.setDistracted(start: start, item: item, distracted: true);
      await service.setDistracted(start: start, item: item, distracted: false);
      harness.clock.advance(const Duration(minutes: 5));
      await service.submitAnswer(
        start: start,
        item: start.items[1],
        selectedIndexes: const [2],
        reasoning: 'Second card',
        distracted: false,
      );

      expect(
        (await harness.cards.errorCardById(baseline.id))!.reasoning,
        'Second intermediate reasoning.',
      );

      await service.discard(start.session.id);

      final restored = await harness.cards.errorCardById(baseline.id);
      _expectSameUndoState(restored!, baseline);
    },
  );

  test('discard restores every existing card the session changed', () async {
    final seeded = await _seedThreeOptionPractice(harness, count: 3);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final first = await _seedExistingCard(
      harness,
      questions[0],
      reasoning: 'First original',
      wrongIndexes: const [1],
    );
    final second = await _seedExistingCard(
      harness,
      questions[1],
      reasoning: 'Second original',
      wrongIndexes: const [2],
    );

    final start = await service.startPractice(seeded.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [2],
      reasoning: 'First changed',
      distracted: false,
    );
    await service.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [1],
      reasoning: 'Second changed',
      distracted: false,
    );

    await service.discard(start.session.id);

    _expectSameUndoState((await harness.cards.errorCardById(first.id))!, first);
    _expectSameUndoState(
      (await harness.cards.errorCardById(second.id))!,
      second,
    );
  });

  test('discard removes a card the session created', () async {
    final seeded = await _seedThreeOptionPractice(harness, count: 3);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final existing = await _seedExistingCard(harness, questions[0]);

    final start = await service.startPractice(seeded.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [2],
      reasoning: 'Changed existing card',
      distracted: false,
    );
    await service.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [2],
      reasoning: 'Created a new card',
      distracted: false,
    );

    final created = await harness.cards.activeErrorForQuestion(questions[1].id);
    expect(created, isNotNull);

    await service.discard(start.session.id);

    expect(await harness.cards.errorCardById(created!.id), isNull);
    _expectSameUndoState(
      (await harness.cards.errorCardById(existing.id))!,
      existing,
    );
  });

  test('finish keeps the updates and clears the undo journal', () async {
    final seeded = await _seedThreeOptionPractice(harness, count: 3);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).first;
    final baseline = await _seedExistingCard(harness, question);

    final start = await service.startPractice(seeded.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.first,
      selectedIndexes: const [2],
      reasoning: 'Kept after finish',
      distracted: false,
    );
    final changed = await harness.cards.errorCardById(baseline.id);

    await service.finishEarly(start: start, markSkipped: false);

    expect(
      await harness.database.settingsDao.getValue(
        errorCardUndoKey(start.session.id),
      ),
      isNull,
    );
    _expectSameUndoState(
      (await harness.cards.errorCardById(baseline.id))!,
      changed!,
    );

    await service.discard(start.session.id);

    _expectSameUndoState(
      (await harness.cards.errorCardById(baseline.id))!,
      changed,
    );
  });

  test(
    'resume and discard still restore the state from before a restart',
    () async {
      final seeded = await _seedThreeOptionPractice(harness, count: 2);
      final question = (await harness.practices.questionsForPractice(
        seeded.practiceId,
      )).first;
      final baseline = await _seedExistingCard(harness, question);

      final start = await service.startPractice(seeded.practiceId);
      await service.submitAnswer(
        start: start,
        item: start.items.first,
        selectedIndexes: const [2],
        reasoning: 'Changed before restart',
        distracted: false,
      );

      final restarted = SessionService(
        practices: harness.practices,
        sessions: harness.sessions,
        cards: harness.cards,
        clock: harness.clock,
      );
      final resumed = await restarted.resume(start.session.id);
      await restarted.discard(resumed.session.id);

      _expectSameUndoState(
        (await harness.cards.errorCardById(baseline.id))!,
        baseline,
      );
    },
  );

  test('discard restores a card that the session resolved', () async {
    final seeded = await _seedThreeOptionPractice(harness, count: 2);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final first = await _seedExistingCard(harness, questions[0]);
    final second = await _seedExistingCard(harness, questions[1]);
    harness.clock.advance(const Duration(hours: 48));

    final start = await service.startPastErrors();
    final firstItem = start.items.firstWhere(
      (item) => item.question.id == questions[0].id,
    );
    await service.submitAnswer(
      start: start,
      item: firstItem,
      selectedIndexes: const [0],
      reasoning: 'Now correct',
      distracted: false,
    );

    final resolved = await harness.cards.errorCardById(first.id);
    expect(resolved!.status, ErrorCardStatus.resolved);
    expect(resolved.resolvedAt, isNotNull);

    await service.discard(start.session.id);

    final restored = await harness.cards.errorCardById(first.id);
    _expectSameUndoState(restored!, first);
    expect(restored.status, ErrorCardStatus.active);
    expect(restored.resolvedAt, isNull);
    _expectSameUndoState(
      (await harness.cards.errorCardById(second.id))!,
      second,
    );
  });

  test('discard does not crash when the card was deleted meanwhile', () async {
    final seeded = await _seedThreeOptionPractice(harness, count: 2);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).first;
    final baseline = await _seedExistingCard(harness, question);

    final start = await service.startPractice(seeded.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.first,
      selectedIndexes: const [2],
      reasoning: 'Temporary mistake',
      distracted: false,
    );
    await harness.cards.deleteErrorCard(baseline.id);

    await service.discard(start.session.id);

    expect(await harness.sessions.sessionById(start.session.id), isNull);
    expect(
      await harness.database.settingsDao.getValue(
        errorCardUndoKey(start.session.id),
      ),
      isNull,
    );
  });

  test('discarding an unknown session is a no-op', () async {
    await service.discard(999999);

    expect(await harness.sessions.sessionById(999999), isNull);
  });

  test(
    'a failed restore surfaces and leaves the session and journal intact',
    () async {
      final seeded = await _seedThreeOptionPractice(harness, count: 2);
      final question = (await harness.practices.questionsForPractice(
        seeded.practiceId,
      )).first;
      final baseline = await _seedExistingCard(harness, question);

      final start = await service.startPractice(seeded.practiceId);
      await service.submitAnswer(
        start: start,
        item: start.items.first,
        selectedIndexes: const [2],
        reasoning: 'Recorded before the conflict',
        distracted: false,
      );

      // Resolving the card and creating a new active card for the same question
      // makes the snapshot impossible to restore without violating the active
      // card uniqueness rule.
      await harness.cards.resolveError(
        baseline.id,
        harness.clock.now().toUtc(),
      );
      final conflicting = await _seedExistingCard(
        harness,
        question,
        reasoning: 'Newer active card',
      );

      await expectLater(
        service.discard(start.session.id),
        throwsA(isA<SessionException>()),
      );

      expect(await harness.sessions.sessionById(start.session.id), isNotNull);
      expect(
        await harness.database.settingsDao.getValue(
          errorCardUndoKey(start.session.id),
        ),
        isNotNull,
      );
      expect(
        (await harness.cards.errorCardById(baseline.id))!.status,
        ErrorCardStatus.resolved,
      );
      expect(await harness.cards.errorCardById(conflicting.id), isNotNull);
    },
  );

  testWidgets('the exit dialog still discards the session and its attempts', (
    tester,
  ) async {
    final seeded = await harness.seedPractice(count: 2);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).first;
    final baseline = await _seedExistingCard(
      harness,
      question,
      exportedAt: DateTime.utc(2026, 1, 1, 9),
    );
    final start = await service.startPractice(seeded.practiceId);
    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    await tester.tap(find.text('Wrong 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);
    expect(
      (await harness.cards.errorCardById(baseline.id))!.exportedAt,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('session-leave')));
    await pumpFrames(tester);
    expect(find.text('Leave this practice?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await pumpFrames(tester);

    _expectSameUndoState(
      (await harness.cards.errorCardById(baseline.id))!,
      baseline,
    );
    expect(await harness.sessions.sessionById(start.session.id), isNull);
    expect(
      await harness.sessions.attemptsForSession(start.session.id),
      isEmpty,
    );
  });
}

Future<SeededPractice> _seedThreeOptionPractice(
  TestHarness harness, {
  required int count,
}) async {
  final topicId = await harness.practices.createTopic(
    name: 'Rollback topic',
    description: '',
    priority: null,
    createdAt: harness.clock.now().toUtc(),
  );
  final practiceId = await harness.practices.createPractice(
    topicId: topicId,
    name: 'Rollback practice',
    description: '',
    contentHash: 'rollback-$count',
    importedAt: harness.clock.now().toUtc(),
  );
  await harness.practices.createQuestions(practiceId, [
    for (var index = 0; index < count; index++)
      QuestionDraft(
        prompt: 'Question ${index + 1}?',
        alternatives: ['A${index + 1}', 'B${index + 1}', 'C${index + 1}'],
        correctIndexes: const [0],
        explanation: 'A${index + 1} is correct.',
        alternativeExplanations: const ['', '', ''],
      ),
  ]);
  return SeededPractice(topicId: topicId, practiceId: practiceId);
}

Future<ErrorCard> _seedExistingCard(
  TestHarness harness,
  Question question, {
  String reasoning = 'Original reasoning',
  List<int> wrongIndexes = const [1],
  DateTime? exportedAt,
}) async {
  final id = await harness.cards.createErrorCard(
    questionId: question.id,
    sessionId: null,
    question: question.prompt,
    alternatives: question.alternatives,
    correctIndexes: question.correctIndexes,
    wrongIndexes: wrongIndexes,
    reasoning: reasoning,
    explanation: question.explanation,
    alternativeExplanations: question.alternativeExplanations,
    topicName: 'Rollback topic',
    practiceName: 'Rollback practice',
    lastWrongAt: DateTime.utc(2025, 12, 1, 8),
    dueAfter: const Duration(hours: 48),
  );
  if (exportedAt != null) {
    await harness.database.cardDao.markErrorCardsExported([id], exportedAt);
  }
  return (await harness.cards.errorCardById(id))!;
}

void _expectSameUndoState(ErrorCard actual, ErrorCard expected) {
  expect(actual.wrongIndexes, expected.wrongIndexes);
  expect(actual.reasoning, expected.reasoning);
  expect(actual.lastWrongAt, expected.lastWrongAt);
  expect(actual.dueAt, expected.dueAt);
  expect(actual.distracted, expected.distracted);
  expect(actual.exportedAt, expected.exportedAt);
  expect(actual.status, expected.status);
  expect(actual.resolvedAt, expected.resolvedAt);
}
