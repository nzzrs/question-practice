import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('practice pages no longer show a reasoning field', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 2);
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

    expect(find.text('Add reasoning (optional)'), findsNothing);
    expect(find.byType(EditableText), findsNothing);

    await tester.tap(find.text('Correct 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);

    expect(find.text('Your reasoning (optional)'), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  test(
    'updating wrong-answer bullets also refreshes the linked error card',
    () async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await harness.seedPractice(count: 1);
      final service = SessionService(
        practices: harness.practices,
        sessions: harness.sessions,
        cards: harness.cards,
        clock: harness.clock,
      );
      final start = await service.startPractice(seeded.practiceId);
      final item = start.items.single;

      await service.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: const [1],
        reasoning: '',
        distracted: false,
      );
      await service.setWrongAnswerBullets(
        start: start,
        item: item,
        bullets: const ['I rushed the second line.'],
      );

      final attempt = await harness.sessions.attemptForQuestion(
        start.session.id,
        item.question.id,
      );
      expect(attempt?.reasoning, 'I rushed the second line.');
      final card = await harness.cards.activeErrorForQuestion(item.question.id);
      expect(card?.reasoning, 'I rushed the second line.');
    },
  );
}
