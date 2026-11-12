import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

  test('done, solved and skipped derive from answer history', () async {
    final practice = await harness.seedPractice(count: 3);
    final start = await service.startPractice(practice.practiceId);
    final ids = [for (final item in start.items) item.question.id];

    await service.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await service.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );
    await service.submitAnswer(
      start: start,
      item: start.items[2],
      selectedIndexes: const [],
      reasoning: '',
      distracted: false,
    );

    final progress = await harness.sessions.questionProgress();
    expect(progress.isDone(ids[0]), isTrue);
    expect(progress.isDone(ids[1]), isTrue);
    expect(progress.isDone(ids[2]), isFalse);

    expect(progress.isSolved(ids[0]), isTrue);
    expect(progress.isSolved(ids[1]), isFalse);
    expect(progress.isSolved(ids[2]), isFalse);

    expect(progress.isSkipped(ids[2]), isTrue);
    expect(progress.isSkipped(ids[1]), isFalse);
  });

  test(
    'shuffled practice keeps only unsolved, non-skipped questions',
    () async {
      final practice = await harness.seedPractice(count: 3);
      final start = await service.startPractice(practice.practiceId);
      final solvedId = start.items[0].question.id;
      final wrongId = start.items[1].question.id;
      final skippedId = start.items[2].question.id;

      await service.submitAnswer(
        start: start,
        item: start.items[0],
        selectedIndexes: const [0],
        reasoning: '',
        distracted: false,
      );
      await service.submitAnswer(
        start: start,
        item: start.items[1],
        selectedIndexes: const [1],
        reasoning: '',
        distracted: false,
      );
      await service.submitAnswer(
        start: start,
        item: start.items[2],
        selectedIndexes: const [],
        reasoning: '',
        distracted: false,
      );

      final mixed = await service.startMixed();
      final ids = [for (final item in mixed.items) item.question.id];
      expect(ids, [wrongId]);
      expect(ids, isNot(contains(solvedId)));
      expect(ids, isNot(contains(skippedId)));
    },
  );

  test('questions left unanswered by an early finish are excluded', () async {
    final practice = await harness.seedPractice(count: 2);
    final start = await service.startPractice(practice.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.first,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await service.finishEarly(start: start, markSkipped: false);

    final progress = await harness.sessions.questionProgress();
    expect(progress.isSkipped(start.items.last.question.id), isTrue);
    expect(
      progress.countsForShuffledPractice(start.items.last.question.id),
      isFalse,
    );

    await expectLater(service.startMixed(), throwsA(isA<SessionException>()));
  });

  test('shuffled practice reports when nothing is left to practise', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await service.startPractice(practice.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );

    await expectLater(
      service.startMixed(),
      throwsA(
        isA<SessionException>().having(
          (error) => error.message,
          'message',
          contains('No unsolved'),
        ),
      ),
    );
  });

  test(
    'redo marks earlier answers as done and leaves no unanswered items',
    () async {
      final practice = await harness.seedPractice(count: 2);
      final first = await service.startPractice(practice.practiceId);
      for (final item in first.items) {
        await service.submitAnswer(
          start: first,
          item: item,
          selectedIndexes: const [0],
          reasoning: '',
          distracted: false,
        );
      }

      final redo = await service.startPractice(practice.practiceId);
      expect(redo.pendingUnanswered, isEmpty);
      expect(redo.items.every(redo.isDone), isTrue);

      final summary = await service.finishEarly(
        start: redo,
        markSkipped: false,
      );
      expect(summary.session.total, 0);
    },
  );

  test(
    'finishing a redo early only marks never-answered questions skipped',
    () async {
      final practice = await harness.seedPractice(count: 2);
      final first = await service.startPractice(practice.practiceId);
      for (final item in first.items) {
        await service.submitAnswer(
          start: first,
          item: item,
          selectedIndexes: const [0],
          reasoning: '',
          distracted: false,
        );
      }
      await harness.practices.createQuestions(practice.practiceId, const [
        QuestionDraft(
          prompt: 'Never answered',
          alternatives: ['Correct', 'Wrong'],
          correctIndexes: [0],
          explanation: 'Correct.',
          alternativeExplanations: ['Correct', 'Wrong'],
        ),
      ]);

      final redo = await service.startPractice(practice.practiceId);
      final pending = redo.pendingUnanswered.single;
      final summary = await service.finishEarly(start: redo, markSkipped: true);

      expect(summary.session.total, 1);
      expect(summary.session.skipped, 1);
      final attempts = await harness.sessions.attemptsForSession(
        redo.session.id,
      );
      expect(attempts, hasLength(1));
      expect(attempts.single.questionId, pending.question.id);
    },
  );

  test('a never answered question stays pending on a redo', () async {
    final practice = await harness.seedPractice(count: 3);
    final first = await service.startPractice(practice.practiceId);
    for (final item in first.items.take(2)) {
      await service.submitAnswer(
        start: first,
        item: item,
        selectedIndexes: const [0],
        reasoning: '',
        distracted: false,
      );
    }
    await service.finishEarly(start: first, markSkipped: false);
    final neverAnswered = first.items.last.question.id;

    final redo = await service.startPractice(practice.practiceId);
    expect(redo.pendingUnanswered.map((item) => item.question.id), [
      neverAnswered,
    ]);
  });

  testWidgets('a done question shows a Done tag in the session', (
    tester,
  ) async {
    final practice = await harness.seedPractice(count: 2);
    final start = await service.startPractice(practice.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    expect(find.text('Done'), findsNothing);

    await tester.tap(find.text('Correct 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);

    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.format_list_numbered));
    await pumpFrames(tester);
    expect(find.text('Question 2?'), findsOneWidget);
    expect(find.text('Done'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('redo hides the unanswered prompt when every question is done', (
    tester,
  ) async {
    final practice = await harness.seedPractice(count: 2);
    final first = await service.startPractice(practice.practiceId);
    for (final item in first.items) {
      await service.submitAnswer(
        start: first,
        item: item,
        selectedIndexes: const [0],
        reasoning: '',
        distracted: false,
      );
    }
    await harness.practices.createQuestions(practice.practiceId, const [
      QuestionDraft(
        prompt: 'Question 3?',
        alternatives: ['Correct 3', 'Wrong 3'],
        correctIndexes: [0],
        explanation: 'Because 3 is correct.',
        alternativeExplanations: ['Correct', 'Wrong'],
      ),
    ]);

    final redo = await service.startPractice(practice.practiceId);
    final newItem = redo.items.firstWhere(
      (item) => item.question.prompt == 'Question 3?',
    );
    await service.submitAnswer(
      start: redo,
      item: newItem,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await pumpTestApp(
      tester,
      home: SessionPage(start: redo),
      harness: harness,
    );

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await pumpFrames(tester);

    expect(find.text('Finish practice?'), findsNothing);
    expect(find.text('Results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redo asks about a question that was never answered', (
    tester,
  ) async {
    final practice = await harness.seedPractice(count: 2);
    final first = await service.startPractice(practice.practiceId);
    for (final item in first.items) {
      await service.submitAnswer(
        start: first,
        item: item,
        selectedIndexes: const [0],
        reasoning: '',
        distracted: false,
      );
    }
    await harness.practices.createQuestions(practice.practiceId, const [
      QuestionDraft(
        prompt: 'Question 3?',
        alternatives: ['Correct 3', 'Wrong 3'],
        correctIndexes: [0],
        explanation: 'Because 3 is correct.',
        alternativeExplanations: ['Correct', 'Wrong'],
      ),
    ]);

    final redo = await service.startPractice(practice.practiceId);
    final doneItem = redo.items.firstWhere(
      (item) => item.question.prompt == 'Question 1?',
    );
    await service.submitAnswer(
      start: redo,
      item: doneItem,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await pumpTestApp(
      tester,
      home: SessionPage(start: redo),
      harness: harness,
    );

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await pumpFrames(tester);

    expect(find.text('Finish practice?'), findsOneWidget);
    expect(find.textContaining('1 question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
