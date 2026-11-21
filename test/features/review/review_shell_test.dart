import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/note_review_page.dart';
import 'package:question_practice/features/review/note_review_view.dart';
import 'package:question_practice/features/review/review_page.dart';
import 'package:question_practice/features/review/skipped_question_view.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<SessionStart> startSession(TestHarness harness) async {
    final seeded = await harness.seedPractice(count: 1);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    return sessions.startPractice(seeded.practiceId);
  }

  testWidgets('skipped review content is selectable and uses one dock', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await startSession(harness);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [],
      reasoning: 'I mixed up the storage classes.',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(
      find.descendant(
        of: find.byType(SkippedQuestionView),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('review-dock-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-create')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-next')), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Keep for later'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('concept review is selectable and saves its definition', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await startSession(harness);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await harness.cards.createConcept(
      sessionId: start.session.id,
      questionId: start.items.single.question.id,
      term: 'VPC',
      definition: '',
      context: start.items.single.question.prompt,
      topicName: 'Topic',
      source: ConceptSource.manual,
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.text('Complete the concept'), findsOneWidget);
    expect(find.byType(SelectionArea), findsWidgets);
    expect(find.text('VPC'), findsOneWidget);

    await tester.tap(find.text('Finish'));
    await pumpFrames(tester);
    expect(find.text('Write a definition before saving.'), findsOneWidget);
    expect(find.text('Complete the concept'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await pumpFrames(tester);

    await tester.enterText(
      find.byType(M3ETextField),
      'A private network inside a cloud provider.',
    );
    await pumpFrames(tester);
    await tester.tap(find.text('Finish'));
    await pumpFrames(tester, frames: 24);
    expect(find.text('Review complete'), findsWidgets);
    final concepts = await tester.runAsync(
      () => harness.cards.watchConcepts().first,
    );
    expect(
      concepts!.single.definition,
      'A private network inside a cloud provider.',
    );
  });

  testWidgets('note review is selectable and opens the original attempt', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
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
      selectedIndexes: const [1],
      reasoning: 'I mixed them up.',
      distracted: false,
    );
    await harness.cards.createNote(
      sessionId: start.session.id,
      questionId: question.id,
      text: 'managed service',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    final notes = (await tester.runAsync(
      () => harness.cards.watchNotes().first,
    ))!;

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    expect(find.text('From the question'), findsNothing);
    expect(find.text('Keep for later'), findsNothing);
    expect(find.text('Delete note'), findsNothing);
    expect(find.text('Save and finish'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NoteReviewView),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );

    final context = find.byKey(const ValueKey('note-see-context'));
    expect(context, findsOneWidget);
    await tester.tap(context);
    await pumpFrames(tester);

    expect(find.text('Original question'), findsOneWidget);
    expect(find.text(question.prompt), findsOneWidget);
    expect(find.text('Wrong 1'), findsOneWidget);
    expect(find.text('Correct 1'), findsOneWidget);
    expect(find.text('Your reasoning'), findsOneWidget);
    expect(find.text('I mixed them up.'), findsOneWidget);
    expect(find.byType(SelectionArea), findsWidgets);
  });

  testWidgets('a note without a resolvable question shows unavailable', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.cards.createNote(
      sessionId: null,
      questionId: null,
      text: 'orphan note',
      context: '',
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    final notes = (await tester.runAsync(
      () => harness.cards.watchNotes().first,
    ))!;

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    expect(find.text('orphan note'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('note-context-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('note-see-context')), findsNothing);
  });

  testWidgets('the note delete action is icon-only and confirmed', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.cards.createNote(
      sessionId: null,
      questionId: null,
      text: 'delete me',
      context: '',
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    final notes = (await tester.runAsync(
      () => harness.cards.watchNotes().first,
    ))!;

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    final delete = find.byKey(const ValueKey('review-dock-delete'));
    expect(delete, findsOneWidget);
    expect(find.text('Delete note'), findsNothing);
    await tester.tap(delete);
    await pumpFrames(tester);
    expect(find.text('Delete note?'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
