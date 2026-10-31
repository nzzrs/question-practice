import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('reasoning can be written after answering a question', (
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

    await tester.tap(find.text('Correct 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);

    await tester.scrollUntilVisible(
      find.text('Your reasoning (optional)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);
    expect(find.text('Your reasoning (optional)'), findsOneWidget);

    await tester.tap(find.text('Your reasoning (optional)'));
    await pumpFrames(tester);

    await tester.enterText(
      find.byType(EditableText).last,
      'Because the first option matched the definition.',
    );
    await pumpFrames(tester, frames: 20);

    final attempt = await harness.sessions.attemptForQuestion(
      start.session.id,
      start.items.first.question.id,
    );
    expect(
      attempt?.reasoning,
      'Because the first option matched the definition.',
    );

    await tester.tap(find.text('Next question'));
    await pumpFrames(tester);
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await pumpFrames(tester);

    await tester.scrollUntilVisible(
      find.text('Because the first option matched the definition.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Because the first option matched the definition.'),
      findsOneWidget,
    );
  });

  test('updating reasoning also refreshes the linked error card', () async {
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
    await service.updateReasoning(
      start: start,
      item: item,
      reasoning: 'I rushed the second line.',
    );

    final attempt = await harness.sessions.attemptForQuestion(
      start.session.id,
      item.question.id,
    );
    expect(attempt?.reasoning, 'I rushed the second line.');
    final card = await harness.cards.activeErrorForQuestion(item.question.id);
    expect(card?.reasoning, 'I rushed the second line.');
  });
}
