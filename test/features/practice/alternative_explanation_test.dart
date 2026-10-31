import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/errors/error_card_review_view.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';
import 'package:question_practice/features/practice/selectable_linkified_text.dart';

import '../../helpers/test_harness.dart';

Future<SeededPractice> _seedThreeAlternatives(TestHarness harness) async {
  final now = harness.clock.now().toUtc();
  final topicId = await harness.practices.createTopic(
    name: 'Topic',
    description: 'Topic description',
    priority: 1,
    ankiDeck: null,
    createdAt: now,
  );
  final practiceId = await harness.practices.createPractice(
    topicId: topicId,
    name: 'Practice',
    description: 'Practice description',
    contentHash: 'three-alternatives',
    importedAt: now,
  );
  await harness.practices.createQuestions(practiceId, const [
    QuestionDraft(
      prompt: 'Pick one?',
      alternatives: ['Correct 1', 'Wrong 1', 'Wrong 2'],
      correctIndexes: [0],
      explanation: 'Overall explanation.',
      alternativeExplanations: [
        'Correct explanation.',
        'Selected wrong explanation.',
        'Untouched wrong explanation.',
      ],
    ),
  ]);
  return SeededPractice(topicId: topicId, practiceId: practiceId);
}

void main() {
  testWidgets(
    'only correct and selected alternatives start with their explanation open',
    (tester) async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await _seedThreeAlternatives(harness);
      final service = SessionService(
        practices: harness.practices,
        sessions: harness.sessions,
        cards: harness.cards,
        clock: harness.clock,
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

      expect(find.text('Correct explanation.'), findsOneWidget);
      expect(find.text('Selected wrong explanation.'), findsOneWidget);
      expect(find.text('Untouched wrong explanation.'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('alternative-explanation-2-toggle')),
      );
      await pumpFrames(tester);
      expect(find.text('Untouched wrong explanation.'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('alternative-explanation-2-toggle')),
      );
      await pumpFrames(tester);
      expect(find.text('Untouched wrong explanation.'), findsNothing);
    },
  );

  testWidgets('error cards collapse untouched alternative explanations', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedThreeAlternatives(harness);
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
      reasoning: '',
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

    expect(find.text('Correct explanation.'), findsOneWidget);
    expect(find.text('Selected wrong explanation.'), findsOneWidget);
    expect(find.text('Untouched wrong explanation.'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('error-alternative-explanation-2-toggle')),
    );
    await pumpFrames(tester);
    expect(find.text('Untouched wrong explanation.'), findsOneWidget);
  });

  testWidgets('alternative text is selectable while answering', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedThreeAlternatives(harness);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(seeded.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    for (final index in [0, 1, 2]) {
      final text = tester.widget<SelectableLinkifiedText>(
        find.byKey(ValueKey('alternative-$index-text')),
      );
      expect(text.selectable, isTrue);
    }
  });
}
