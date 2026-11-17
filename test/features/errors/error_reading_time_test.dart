import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/reading_time.dart';
import 'package:question_practice/features/errors/error_card_review_view.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('error card review shows a front reading-time badge', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    final id = await harness.cards.createErrorCard(
      questionId: question.id,
      sessionId: null,
      question: question.prompt,
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      wrongIndexes: const [1],
      reasoning: 'A long reasoning note that is not part of the card front.',
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      topicName: 'Topic',
      practiceName: 'Practice',
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    final card = (await harness.cards.errorCardById(id))!;
    final bias = TextEditingController();
    final vaccine = TextEditingController();
    addTearDown(bias.dispose);
    addTearDown(vaccine.dispose);

    await pumpTestApp(
      tester,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ErrorCardReviewView(card: card, bias: bias, vaccine: vaccine),
        ),
      ),
      harness: harness,
    );

    final expected = readingTimeLabel('${question.prompt} Wrong 1 Correct 1');
    final badge = find.byKey(const ValueKey('error-card-reading-time'));
    expect(badge, findsOneWidget);
    expect(find.text(expected), findsOneWidget);
    expect(find.byTooltip('Estimated time to read the front'), findsOneWidget);
    // The reasoning, bias, vaccine and explanation are not part of the front.
    expect(
      find.text(
        readingTimeLabel(
          '${question.prompt} Wrong 1 Correct 1 '
          'A long reasoning note that is not part of the card front.',
        ),
      ),
      findsNothing,
    );
  });
}
