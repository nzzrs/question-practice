import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';
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

    expect(find.text('What was missing?'), findsOneWidget);
    expect(find.text('Save and finish'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('review-create-fab')));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);

    expect(find.byType(CardCreatorSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-front')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    expect(find.text('Cards to save · 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('creator-close')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
    await pumpFrames(tester, frames: 24);

    final cards = await tester.runAsync(
      () => harness.cards.watchBasicCards().first,
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
