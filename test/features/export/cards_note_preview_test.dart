import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/export/cards_page.dart';
import 'package:question_practice/features/review/note_review_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<Question> onlyQuestion(
    TestHarness harness,
    SeededPractice seeded,
  ) async {
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    return questions.single;
  }

  Future<int> seedNote(
    TestHarness harness,
    Question question, {
    required String text,
  }) {
    return harness.cards.createNote(
      sessionId: null,
      questionId: question.id,
      text: text,
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
  }

  testWidgets('tapping a note opens a read-only preview', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final noteId = await seedNote(harness, question, text: 'managed service');

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('note-row-$noteId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.text('Note preview'), findsOneWidget);
    expect(find.byType(NoteReviewPage), findsNothing);
    expect(find.text('Review the note'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('FROM THE QUESTION'), findsOneWidget);

    final highlighted = tester.widget<SelectableText>(
      find.byKey(const ValueKey('note-preview-text')),
    );
    expect(highlighted.data, 'managed service');
    expect(tester.takeException(), isNull);
  });

  testWidgets('close dismisses the preview without opening review', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final noteId = await seedNote(harness, question, text: 'managed service');

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('note-row-$noteId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    await tester.tap(find.text('Close'));
    await pumpFrames(tester);

    expect(find.text('Note preview'), findsNothing);
    expect(find.byType(NoteReviewPage), findsNothing);
    expect(row, findsOneWidget);
  });

  testWidgets('review opens the tapped note inside the note review', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final firstId = await seedNote(harness, question, text: 'first note');
    harness.clock.advance(const Duration(minutes: 1));
    await seedNote(harness, question, text: 'second note');
    final notes = (await tester.runAsync(
      () => harness.cards.watchNotes().first,
    ))!;
    final target = notes.singleWhere((note) => note.id == firstId);
    final targetPosition = notes.indexWhere((note) => note.id == firstId) + 1;

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('note-row-$firstId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    await tester.tap(find.text('Review'));
    await pumpFrames(tester);

    expect(find.byType(NoteReviewPage), findsOneWidget);
    expect(find.text('Review the note'), findsOneWidget);
    expect(find.text(target.text), findsOneWidget);
    expect(find.text('Item $targetPosition of 2'), findsOneWidget);
  });

  testWidgets('note preview fits 320dp with 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final noteId = await seedNote(
      harness,
      question,
      text: 'A managed service removes host maintenance from the team.',
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('note-row-$noteId'));
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);
    await tester.tapAt(tester.getTopLeft(row) + const Offset(24, 12));
    await pumpFrames(tester);

    expect(find.text('Note preview'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('note preview fits a landscape window', (tester) async {
    tester.view.physicalSize = const Size(720, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final noteId = await seedNote(
      harness,
      question,
      text: 'A managed service removes host maintenance from the team.',
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('note-row-$noteId'));
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);
    await tester.tapAt(tester.getTopLeft(row) + const Offset(24, 12));
    await pumpFrames(tester);

    expect(find.text('Note preview'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
