import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/ui/adaptive_split_view.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/summary_page.dart';
import 'package:question_practice/features/review/review_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('skipped review shows the correct answer and reasoning', (
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
      reasoning: 'I mixed up the storage classes.',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('Correct 1'), findsOneWidget);
    expect(find.text('Your reasoning'), findsOneWidget);
    expect(find.text('I mixed up the storage classes.'), findsOneWidget);
    expect(find.text('Why'), findsOneWidget);

    await tester.ensureVisible(find.text('See other alternatives'));
    await tester.tap(find.text('See other alternatives'));
    await pumpFrames(tester);
    expect(find.text('Hide other alternatives'), findsOneWidget);
    expect(find.text('Wrong 1'), findsOneWidget);
    expect(find.text('Wrong: 1 is a distractor.'), findsOneWidget);
  });

  testWidgets('unknown review is labelled and keeps the reasoning', (
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
      selectedIndexes: const [1],
      reasoning: 'I guessed between the two names.',
      distracted: false,
    );
    await sessions.setUnknown(
      start: start,
      item: start.items.single,
      unknown: true,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.text("I didn't know this"), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('I guessed between the two names.'), findsOneWidget);
  });

  testWidgets('end-of-session review opens full screen and restores bars', (
    tester,
  ) async {
    final recorder = SystemUiCallRecorder()..install();
    addTearDown(recorder.dispose);
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
      selectedIndexes: const [1],
      reasoning: 'I guessed.',
      distracted: false,
    );
    final summary = await sessions.finishEarly(
      start: start,
      markSkipped: false,
    );

    await pumpTestApp(
      tester,
      home: SummaryPage(summary: summary),
      harness: harness,
    );
    await tester.ensureVisible(find.textContaining('Start error review'));
    await pumpFrames(tester);
    await tester.tap(find.textContaining('Start error review'));
    await pumpFrames(tester);

    expect(find.byType(ReviewPage), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.byType(ReviewPage)));
    expect(route, isA<MaterialPageRoute<void>>());
    expect((route as MaterialPageRoute<void>).fullscreenDialog, isTrue);
    expect(find.byType(M3EAppBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('app-focus-header')), findsOneWidget);
    expect(recorder.modes, contains('SystemUiMode.immersiveSticky'));

    await tester.tap(find.byKey(const ValueKey('app-focus-exit')));
    await pumpFrames(tester);

    expect(find.byType(ReviewPage), findsNothing);
    expect(find.byType(SummaryPage), findsOneWidget);
    expect(recorder.modes.last, 'SystemUiMode.edgeToEdge');
  });

  testWidgets('the end-of-session note step uses the shared view', (
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
    final item = start.items.single;
    await sessions.submitAnswer(
      start: start,
      item: item,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await harness.cards.createNote(
      sessionId: start.session.id,
      questionId: item.question.id,
      text: 'managed service',
      context: item.question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.text('Review the note'), findsOneWidget);
    expect(find.text('managed service'), findsOneWidget);
    expect(find.text('From the question'), findsNothing);
    expect(find.byKey(const ValueKey('review-create-fab')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-see-context')), findsOneWidget);
    expect(find.text('Suggest cards with AI'), findsNothing);
    expect(find.text('Save and finish'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    expect(find.text('Keep & save'), findsNothing);
    expect(find.byKey(const ValueKey('review-dock-delete')), findsNothing);
    expect(find.text('Delete note'), findsNothing);
  });

  testWidgets('note deletion is not offered inside the review', (tester) async {
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
    final item = start.items.single;
    await sessions.submitAnswer(
      start: start,
      item: item,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await harness.cards.createNote(
      sessionId: start.session.id,
      questionId: item.question.id,
      text: 'delete this note',
      context: item.question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.byKey(const ValueKey('review-dock-delete')), findsNothing);
    expect(find.text('Delete note'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    final notes = await tester.runAsync(
      () => harness.cards.notesForSession(start.session.id),
    );
    expect(notes, hasLength(1));
  });

  testWidgets('error review continues without bias or vaccine notes', (
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
      selectedIndexes: const [1],
      reasoning: 'I guessed.',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.text('Analyse the error'), findsOneWidget);
    expect(find.byType(AdaptiveSplitView), findsNothing);
    expect(find.byType(CardCreatorSheet), findsNothing);
    expect(find.byKey(const ValueKey('review-create-fab')), findsOneWidget);
    expect(find.text('Save and finish'), findsOneWidget);
    expect(find.text('Check with AI'), findsNothing);
    expect(find.text('Flawed assumption (bias)'), findsNothing);
    expect(find.text('Vaccine (rule / protocol)'), findsNothing);

    await tester.tap(find.text('Save and finish'));
    await pumpFrames(tester);

    expect(find.text('Review complete'), findsWidgets);
  });

  testWidgets('adding atomic cards from the error step advances the review', (
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
      selectedIndexes: const [1],
      reasoning: 'I guessed.',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    await tester.tap(find.byKey(const ValueKey('review-create-fab')));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'Which layer owns IP addresses?',
    );
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'The network layer owns addressing.',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-close')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
    await pumpFrames(tester, frames: 24);

    expect(find.textContaining('1 card completed or created'), findsOneWidget);
    final error = await tester.runAsync(
      () =>
          harness.cards.activeErrorForQuestion(start.items.single.question.id),
    );
    expect(error!.needsDetails, isFalse);
    final cards = await tester.runAsync(
      () => harness.cards.watchBasicCards().first,
    );
    expect(cards, hasLength(1));
  });
}
