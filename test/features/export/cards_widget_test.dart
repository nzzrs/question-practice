import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
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

  testWidgets('incomplete error selection replaces export with review', (
    tester,
  ) async {
    final harness = await harnessWithErrorCard(complete: false);
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);

    await tester.tap(find.byType(M3ECheckbox).first);
    await pumpFrames(tester);

    expect(find.text('Review selected'), findsOneWidget);
    expect(find.text('Export to AnkiDroid'), findsNothing);
  });

  testWidgets('complete error selection keeps export visible', (tester) async {
    final harness = await harnessWithErrorCard(complete: true);
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);
    expect(find.text('Review all'), findsOneWidget);
  });
}
