import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/review/highlight_review_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<List<StudyHighlight>> seedHighlights(
    WidgetTester tester,
    TestHarness harness,
  ) async {
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    await harness.cards.createHighlight(
      sessionId: null,
      questionId: question.id,
      text: 'first highlight',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    harness.clock.advance(const Duration(minutes: 1));
    await harness.cards.createHighlight(
      sessionId: null,
      questionId: question.id,
      text: 'second highlight',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    return (await tester.runAsync(
      () => harness.cards.watchHighlights().first,
    ))!;
  }

  testWidgets('skips through highlights and reports the completion', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final highlights = await seedHighlights(tester, harness);

    await pumpTestApp(
      tester,
      home: HighlightReviewPage(highlights: highlights),
      harness: harness,
    );

    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.text('second highlight'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await pumpFrames(tester);

    expect(find.text('Item 2 of 2'), findsOneWidget);
    expect(find.text('first highlight'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await pumpFrames(tester);

    expect(find.text('Note review complete'), findsOneWidget);
    expect(find.text('No notes were changed.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('keeping a highlight records it and finishes the review', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final highlights = await seedHighlights(tester, harness);

    await pumpTestApp(
      tester,
      home: HighlightReviewPage(highlights: highlights),
      harness: harness,
    );

    await tester.tap(find.text('Skip'));
    await pumpFrames(tester);
    expect(find.text('Item 2 of 2'), findsOneWidget);

    await tester.tap(find.text('Keep & done'));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Note review complete'), findsOneWidget);
    expect(find.text('1 note kept'), findsOneWidget);
    final saved = await tester.runAsync(
      () => harness.cards.watchHighlights().first,
    );
    expect(
      saved!.singleWhere((item) => item.text == 'first highlight').isKept,
      isTrue,
    );
  });

  testWidgets('opens at the requested highlight', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final highlights = await seedHighlights(tester, harness);
    final target = highlights.singleWhere(
      (highlight) => highlight.text == 'first highlight',
    );

    await pumpTestApp(
      tester,
      home: HighlightReviewPage(
        highlights: highlights,
        initialHighlightId: target.id,
      ),
      harness: harness,
    );

    expect(find.text('Item 2 of 2'), findsOneWidget);
    expect(find.text('first highlight'), findsOneWidget);
  });

  testWidgets('deleting the current highlight advances safely', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final highlights = await seedHighlights(tester, harness);

    await pumpTestApp(
      tester,
      home: HighlightReviewPage(highlights: highlights),
      harness: harness,
    );

    expect(find.text('second highlight'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('highlight-delete')));
    await pumpFrames(tester);
    expect(find.text('Delete note?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Item 1 of 1'), findsOneWidget);
    expect(find.text('first highlight'), findsOneWidget);
    final saved = await tester.runAsync(
      () => harness.cards.watchHighlights().first,
    );
    expect(saved, hasLength(1));
    expect(saved!.single.text, 'first highlight');
  });
}
