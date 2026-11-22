import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/export/cards_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('Cards shows Scenario and rule for a heuristic basic card', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final question = questions.single;
    final cardId = await harness.cards.createBasicCard(
      sessionId: null,
      questionId: question.id,
      question: 'Which rule applies to this scenario?',
      answer: 'The stricter rule.',
      context: question.prompt,
      topicName: 'Topic',
      cognitiveType: CognitiveType.heuristic,
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    final row = find.byKey(ValueKey('basic-row-$cardId'));
    await tester.ensureVisible(row);
    expect(
      find.descendant(of: row, matching: find.text('Scenario and rule')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Heuristic')),
      findsNothing,
    );
    expect(find.text('Exam tip'), findsNothing);

    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.text('Card preview'), findsOneWidget);
    expect(find.text('Scenario and rule'), findsWidgets);
    expect(find.text('Exam tip'), findsNothing);
    expect(find.text('Exam heuristic'), findsNothing);
  });

  testWidgets('Cards shows Steps for a procedure basic card', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final question = questions.single;
    final cardId = await harness.cards.createBasicCard(
      sessionId: null,
      questionId: question.id,
      question: 'In the handshake, what must be true before the client sends?',
      answer: 'The server chose a cipher.',
      context: question.prompt,
      topicName: 'Topic',
      cognitiveType: CognitiveType.procedure,
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    final row = find.byKey(ValueKey('basic-row-$cardId'));
    await tester.ensureVisible(row);
    expect(
      find.descendant(of: row, matching: find.text('Steps')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Scenario and rule')),
      findsNothing,
    );

    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.text('Card preview'), findsOneWidget);
    expect(find.text('Steps'), findsWidgets);
    expect(find.text('Scenario and rule'), findsNothing);
  });
}
