import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/errors/past_errors_page.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<int> createError(TestHarness harness) async {
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    return harness.cards.createErrorCard(
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
  }

  testWidgets('due errors start collapsed and expand from the top button', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await createError(harness);
    harness.clock.advance(const Duration(hours: 48));

    await pumpTestApp(tester, home: const PastErrorsPage(), harness: harness);

    expect(find.text('Review 1 error'), findsOneWidget);
    expect(find.text('Question 1?'), findsNothing);

    await tester.tap(find.text('Show').first);
    await pumpFrames(tester);

    expect(find.text('Question 1?'), findsOneWidget);
  });

  testWidgets('resolved history is collapsed until shown', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final id = await createError(harness);
    await harness.cards.resolveError(id, harness.clock.now().toUtc());

    await pumpTestApp(tester, home: const PastErrorsPage(), harness: harness);

    expect(find.text('1 resolved error.'), findsOneWidget);
    expect(find.text('Question 1?'), findsNothing);

    await tester.tap(find.text('Show').first);
    await pumpFrames(tester);

    expect(find.text('Question 1?'), findsOneWidget);
  });

  testWidgets('review errors opens the immersive session without app chrome', (
    tester,
  ) async {
    final recorder = SystemUiCallRecorder()..install();
    addTearDown(recorder.dispose);
    final harness = TestHarness();
    addTearDown(harness.close);
    await createError(harness);
    harness.clock.advance(const Duration(hours: 48));

    await pumpTestApp(tester, home: const PastErrorsPage(), harness: harness);
    await tester.tap(find.text('Review 1 error'));
    await pumpFrames(tester, frames: 24);

    expect(find.byType(SessionPage), findsOneWidget);
    expect(recorder.modes, contains('SystemUiMode.immersiveSticky'));
  });
}
