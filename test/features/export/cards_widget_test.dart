import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/export/cards_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<TestHarness> harnessWithErrorCard({required bool complete}) async {
    final harness = TestHarness();
    final practice = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      practice.practiceId,
    )).single;
    final cardId = await harness.cards.createErrorCard(
      questionId: question.id,
      sessionId: null,
      question: question.prompt,
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      wrongIndexes: const [1],
      reasoning: 'Reason',
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      topicName: 'Topic',
      practiceName: 'Practice',
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    if (complete) {
      await harness.cards.updateErrorCardDetails(
        id: cardId,
        bias: 'Bias',
        vaccine: 'Vaccine',
        completedAt: harness.clock.now().toUtc(),
      );
    }
    return harness;
  }

  testWidgets(
    'incomplete selection disables export but keeps review selected',
    (tester) async {
      final harness = await harnessWithErrorCard(complete: false);
      addTearDown(harness.close);

      await pumpTestApp(tester, home: const CardsPage(), harness: harness);
      expect(find.text('Export to AnkiDroid'), findsOneWidget);

      await tester.tap(find.byType(M3ECheckbox).first);
      await pumpFrames(tester);

      expect(find.text('Review all'), findsOneWidget);
      expect(find.text('Review selected'), findsOneWidget);
      expect(find.text('Export to AnkiDroid'), findsOneWidget);

      final export = tester.widget<AppPrimaryButton>(
        find.widgetWithText(AppPrimaryButton, 'Export to AnkiDroid'),
      );
      expect(export.onPressed, isNull);
      final share = tester.widget<AppDockIconButton>(
        find.ancestor(
          of: find.byIcon(Icons.ios_share),
          matching: find.byType(AppDockIconButton),
        ),
      );
      expect(share.onPressed, isNull);

      await tester.tap(find.byType(M3ECheckbox).first);
      await pumpFrames(tester);

      expect(find.text('Review selected'), findsNothing);
      expect(find.text('Export to AnkiDroid'), findsOneWidget);
    },
  );

  testWidgets('complete error selection keeps export visible', (tester) async {
    final harness = await harnessWithErrorCard(complete: true);
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);
    expect(find.text('Review all'), findsOneWidget);
  });

  testWidgets('skipped questions stay in cards and can become a card', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    await harness.cards.saveSkippedQuestion(
      sessionId: null,
      questionId: question.id,
      question: question.prompt,
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      reasoning: 'I guessed.',
      topicName: 'Topic',
      practiceName: 'Practice',
      unknown: false,
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.textContaining('Error and skipped'), findsOneWidget);
    expect(find.text('Question 1?'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await pumpFrames(tester);
    expect(find.text('Review the skipped question'), findsOneWidget);
    expect(find.text('Item 1 of 1'), findsOneWidget);

    await tester.tap(find.text('Make a card'));
    await pumpFrames(tester);
    expect(find.text('Turn this skipped question into a card'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await pumpFrames(tester, frames: 24);

    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, hasLength(1));
    expect(manuals!.single.context, 'Question 1?');
    final queued = await tester.runAsync(
      () => harness.cards.watchUnhandledSkippedQuestions().first,
    );
    expect(queued, isEmpty);

    await tester.tap(find.text('Done'));
    await pumpFrames(tester);
    expect(find.textContaining('Basic cards ·'), findsOneWidget);
  });

  testWidgets('review all walks error cards and skipped questions', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    final errorId = await harness.cards.createErrorCard(
      questionId: question.id,
      sessionId: null,
      question: question.prompt,
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      wrongIndexes: const [1],
      reasoning: 'Reason',
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      topicName: 'Topic',
      practiceName: 'Practice',
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    await harness.cards.updateErrorCardDetails(
      id: errorId,
      bias: 'Bias',
      vaccine: 'Vaccine',
      completedAt: harness.clock.now().toUtc(),
    );
    await harness.cards.saveSkippedQuestion(
      sessionId: null,
      questionId: question.id,
      question: 'Skipped prompt?',
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      reasoning: '',
      topicName: 'Topic',
      practiceName: 'Practice',
      unknown: false,
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    await tester.tap(find.text('Review all'));
    await pumpFrames(tester);

    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.text('Check the error card'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await pumpFrames(tester);

    expect(find.text('Item 2 of 2'), findsOneWidget);
    expect(find.text('Review the skipped question'), findsOneWidget);
  });

  testWidgets('saved highlights stay visible in the cards view', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    await harness.cards.createHighlight(
      sessionId: null,
      questionId: question.id,
      text: 'managed service',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.textContaining('Highlights ·'), findsOneWidget);
    expect(find.text('managed service'), findsOneWidget);
    expect(find.text('Download all'), findsOneWidget);
  });
}
