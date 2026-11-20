import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/export/card_creator_page.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/review_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('skipped review creates cards from the correct answer', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [],
      reasoning: '',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );
    await pumpFrames(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('skipped-review-missing')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);
    expect(find.text('What was missing?'), findsWidgets);

    await tester.tap(find.text('Create cards'));
    await pumpFrames(tester);

    expect(find.byType(CardCreatorPage), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-front')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('creator-add')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    expect(find.text('Save 1 card'), findsOneWidget);

    await tester.tap(find.text('Save 1 card'));
    await pumpFrames(tester, frames: 24);

    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
    expect(cards!.single.question, 'Question 1?');
    expect(cards.single.answer, 'Correct 1');
    expect(cards.single.context, 'Question 1?');
    final queued = await tester.runAsync(
      () => harness.cards.watchUnhandledSkippedQuestions().first,
    );
    expect(queued, isEmpty);
  });
}
