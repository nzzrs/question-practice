import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('topic counts use singular and plural copy', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 1,
    );

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    expect(find.text('1 practice · 1 question'), findsOneWidget);

    await harness.practices.createPractice(
      topicId: seeded.topicId,
      name: 'Extra',
      description: 'Extra practice',
      contentHash: 'extra',
      importedAt: harness.clock.now().toUtc(),
    );
    final second = await harness.practices.findPracticeByName(
      seeded.topicId,
      'Extra',
    );
    await harness.practices.createQuestions(second!.id, [
      const QuestionDraft(
        prompt: 'Another question?',
        alternatives: ['Right', 'Wrong'],
        correctIndexes: [0],
        explanation: 'Because.',
        alternativeExplanations: ['Right.', 'Wrong.'],
      ),
    ]);
    await pumpFrames(tester);

    expect(find.text('2 practices · 2 questions'), findsOneWidget);
  });

  testWidgets('home card and session counts are singular', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    await service.startPractice(seeded.practiceId);

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      overrides: [
        homeStatsProvider.overrideWith(
          (ref) => Stream.value(
            const HomeStats(
              dueErrors: 0,
              activeErrors: 0,
              incompleteErrorCards: 0,
              unexportedCards: 1,
              inProgressSessionId: null,
              inProgressSessionMode: null,
              inProgressSessionTotal: null,
            ),
          ),
        ),
      ],
    );

    expect(find.text('1 session paused'), findsOneWidget);
    expect(find.text('1 card ready to export'), findsOneWidget);
  });
}
