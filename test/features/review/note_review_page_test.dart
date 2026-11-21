import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/review/note_review_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<List<Note>> seedNotes(WidgetTester tester, TestHarness harness) async {
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    await harness.cards.createNote(
      sessionId: null,
      questionId: question.id,
      text: 'first note',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    harness.clock.advance(const Duration(minutes: 1));
    await harness.cards.createNote(
      sessionId: null,
      questionId: question.id,
      text: 'second note',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    return (await tester.runAsync(() => harness.cards.watchNotes().first))!;
  }

  testWidgets('moves through notes with the forward arrow and reports the '
      'completion', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedNotes(tester, harness);

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.text('second note'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Save and finish'), findsNothing);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('review-dock-next')));
    await pumpFrames(tester);

    expect(find.text('Item 2 of 2'), findsOneWidget);
    expect(find.text('first note'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-dock-next')));
    await pumpFrames(tester);

    expect(find.text('Note review complete'), findsOneWidget);
    expect(find.text('No notes were changed.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('keeping a note records it and finishes the review', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedNotes(tester, harness);

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    await tester.tap(find.byKey(const ValueKey('review-dock-next')));
    await pumpFrames(tester);
    expect(find.text('Item 2 of 2'), findsOneWidget);

    await tester.tap(find.text('Save and finish'));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Note review complete'), findsOneWidget);
    expect(find.text('1 note kept'), findsOneWidget);
    final saved = await tester.runAsync(() => harness.cards.watchNotes().first);
    expect(
      saved!.singleWhere((item) => item.text == 'first note').isKept,
      isTrue,
    );
  });

  testWidgets('opens at the requested note', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedNotes(tester, harness);
    final target = notes.singleWhere((note) => note.text == 'first note');

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes, initialNoteId: target.id),
      harness: harness,
    );

    expect(find.text('Item 2 of 2'), findsOneWidget);
    expect(find.text('first note'), findsOneWidget);
  });

  testWidgets('the note dock fits 320 dp at 2.0 text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedNotes(tester, harness);

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('review-dock-delete')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-save')), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('deleting the current note advances safely', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedNotes(tester, harness);

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    expect(find.text('second note'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('review-dock-delete')));
    await pumpFrames(tester);
    expect(find.text('Delete note?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Item 1 of 1'), findsOneWidget);
    expect(find.text('first note'), findsOneWidget);
    final saved = await tester.runAsync(() => harness.cards.watchNotes().first);
    expect(saved, hasLength(1));
    expect(saved!.single.text, 'first note');
  });
}
