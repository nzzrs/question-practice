import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('mistake chips appear only after a wrong answer', (tester) async {
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

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    expect(find.text('Forgotten fact'), findsNothing);
    expect(
      find.text('What went wrong? Optional, feeds the card generator.'),
      findsNothing,
    );

    await tester.tap(find.text('Wrong 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);

    await tester.scrollUntilVisible(
      find.text('Forgotten fact'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);

    expect(
      find.text('What went wrong? Optional, feeds the card generator.'),
      findsOneWidget,
    );
    expect(find.text('Forgotten fact'), findsOneWidget);
    expect(find.text('Confusion between 2 options'), findsOneWidget);
    expect(find.text('Misinterpretation'), findsOneWidget);
    expect(find.text('Distraction'), findsOneWidget);
  });

  testWidgets('toggling a mistake chip persists it to the attempt and card', (
    tester,
  ) async {
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

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    await tester.tap(find.text('Wrong 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);
    await tester.scrollUntilVisible(
      find.text('Forgotten fact'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);

    await tester.tap(find.text('Forgotten fact'));
    await pumpFrames(tester);

    final attempt = await harness.sessions.attemptForQuestion(
      start.session.id,
      item.question.id,
    );
    expect(attempt!.mistakeKinds, const [MistakeKind.forgottenFact]);
    final card = await harness.cards.activeErrorForQuestion(item.question.id);
    expect(card!.mistakeKinds, const [MistakeKind.forgottenFact]);

    await tester.tap(find.text('Forgotten fact'));
    await pumpFrames(tester);

    final cleared = await harness.sessions.attemptForQuestion(
      start.session.id,
      item.question.id,
    );
    expect(cleared!.mistakeKinds, isEmpty);
  });

  testWidgets('mistake chips do not appear for a correct answer', (
    tester,
  ) async {
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

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    await tester.tap(find.text('Correct 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);

    expect(find.text('Forgotten fact'), findsNothing);
    expect(
      find.text('What went wrong? Optional, feeds the card generator.'),
      findsNothing,
    );
  });
}
