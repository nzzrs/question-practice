import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/app_scaffold.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/note_review_page.dart';
import 'package:question_practice/features/review/note_review_view.dart';
import 'package:question_practice/features/review/review_action_dock.dart';
import 'package:question_practice/features/review/review_page.dart';
import 'package:question_practice/features/review/review_shell.dart';
import 'package:question_practice/features/review/skipped_question_view.dart';

import '../../helpers/test_harness.dart';

void main() {
  SessionService sessionsFor(TestHarness harness) {
    return SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
  }

  Future<SessionStart> startSession(TestHarness harness) async {
    final seeded = await harness.seedPractice(count: 1);
    return sessionsFor(harness).startPractice(seeded.practiceId);
  }

  Future<List<Note>> seedTwoNotes(
    WidgetTester tester,
    TestHarness harness,
  ) async {
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

  bool isEnabled(WidgetTester tester, Key key) {
    return tester
            .widget<M3EIconButton>(
              find.descendant(
                of: find.byKey(key),
                matching: find.byType(M3EIconButton),
              ),
            )
            .onPressed !=
        null;
  }

  testWidgets('skipped review is selectable and uses one shared dock', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await startSession(harness);
    await sessionsFor(harness).submitAnswer(
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

    expect(find.byType(ReviewShell), findsOneWidget);
    expect(find.byType(ReviewActionDock), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SkippedQuestionView),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('review-dock-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-next')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ReviewActionDock),
        matching: find.byKey(const ValueKey('review-create-fab')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ReviewActionDock),
        matching: find.byKey(const ValueKey('review-dock-delete')),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('review-create-fab')), findsOneWidget);
    final fabWidget = tester.widget<M3EFab>(
      find.byKey(const ValueKey('review-create-fab')),
    );
    expect(fabWidget.tooltip, 'Create cards');
    expect(fabWidget.icon, isA<Icon>());
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Keep for later'), findsNothing);
    expect(find.text('Save and finish'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    expect(isEnabled(tester, ReviewActionDock.backKey), isFalse);
    expect(isEnabled(tester, ReviewActionDock.nextKey), isFalse);
  });

  testWidgets('concept review saves its definition and finishes on the last '
      'item', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await startSession(harness);
    final sessions = sessionsFor(harness);
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
    expect(find.text('Save and finish'), findsOneWidget);

    await tester.tap(find.text('Save and finish'));
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
    await tester.tap(find.text('Save and finish'));
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
    final sessions = sessionsFor(harness);
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

    expect(find.byType(ReviewShell), findsOneWidget);
    expect(find.text('From the question'), findsNothing);
    expect(find.text('Keep for later'), findsNothing);
    expect(find.text('Delete note'), findsNothing);
    expect(find.byKey(const ValueKey('review-dock-delete')), findsNothing);
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

  testWidgets('the dock keeps back, primary, forward order at every width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedTwoNotes(tester, harness);

    tester.view.physicalSize = const Size(720, 900);
    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    for (final width in <double>[720, 360, 320]) {
      tester.view.physicalSize = Size(width, 900);
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('review-dock-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-dock-save')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-dock-next')), findsOneWidget);
      final back = tester.getCenter(
        find.byKey(const ValueKey('review-dock-back')),
      );
      final save = tester.getCenter(
        find.byKey(const ValueKey('review-dock-save')),
      );
      final next = tester.getCenter(
        find.byKey(const ValueKey('review-dock-next')),
      );
      expect(back.dx, lessThan(save.dx));
      expect(save.dx, lessThan(next.dx));
      expect(back.dy, closeTo(save.dy, 1));
      expect(save.dy, closeTo(next.dy, 1));
    }
  });

  testWidgets('Save on an earlier note saves and advances', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedTwoNotes(tester, harness);

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.text('second note'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Save and finish'), findsNothing);

    await tester.tap(find.byKey(ReviewActionDock.saveKey));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Item 2 of 2'), findsOneWidget);
    expect(find.text('first note'), findsOneWidget);
    final saved = await tester.runAsync(() => harness.cards.watchNotes().first);
    expect(
      saved!.singleWhere((note) => note.text == 'second note').isKept,
      isTrue,
    );
  });

  testWidgets('the create FAB is a real floating action, not a bottom-bar '
      'child', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedTwoNotes(tester, harness);

    tester.view.physicalSize = const Size(360, 720);
    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    final fab = find.byKey(ReviewCreateFab.fabKey);
    final slot = find.byKey(ReviewCreateFab.slotKey);
    final dock = find.byType(ReviewActionDock);
    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('app-focus-page')),
    );

    expect(find.byType(ReviewCreateFab), findsOneWidget);
    expect(scaffold.floatingActionButton, isA<ReviewCreateFab>());
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-dock-visible')),
        matching: fab,
      ),
      findsNothing,
    );
    expect(
      find.ancestor(of: fab, matching: find.byType(AppActionDock)),
      findsNothing,
    );
    expect(
      find.ancestor(of: fab, matching: find.byType(ReviewActionDock)),
      findsNothing,
    );
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getSize(fab).width, lessThan(100));
    expect(tester.getSize(slot).width, lessThan(100));
    expect(tester.getSize(slot).width, lessThan(screen.width / 2));
    expect(tester.getRect(fab).overlaps(tester.getRect(dock)), isFalse);
  });

  testWidgets('the create FAB fits every review layout without overlapping', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedTwoNotes(tester, harness);

    tester.view.physicalSize = const Size(360, 720);
    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    final dock = find.byType(ReviewActionDock);
    final fab = find.byKey(const ValueKey('review-create-fab'));

    void expectFits() {
      expect(tester.takeException(), isNull);
      expect(fab, findsOneWidget);
      final fabRect = tester.getRect(fab);
      final dockRect = tester.getRect(dock);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(fabRect.left, greaterThanOrEqualTo(0));
      expect(fabRect.right, lessThanOrEqualTo(screen.width));
      expect(fabRect.bottom, lessThanOrEqualTo(screen.height));
      expect(fabRect.overlaps(dockRect), isFalse);
    }

    for (final size in const <Size>[
      Size(320, 640),
      Size(360, 720),
      Size(720, 900),
      Size(640, 320),
    ]) {
      tester.view.physicalSize = size;
      await pumpFrames(tester);
      expectFits();
    }

    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await pumpFrames(tester);
    expectFits();

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(fab, findsNothing);
    expect(dock, findsNothing);
  });

  testWidgets('the create FAB rises above a validation snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => M3ESnackbar.defaultController.dismiss(immediate: true));
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await startSession(harness);
    final sessions = sessionsFor(harness);
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

    final fab = find.byKey(ReviewCreateFab.fabKey);
    final slot = find.byKey(ReviewCreateFab.slotKey);
    final dock = find.byType(ReviewActionDock);
    final fabBefore = tester.getRect(fab);
    final slotBefore = tester.getSize(slot);
    final dockBefore = tester.getRect(dock);

    await tester.tap(find.byKey(ReviewActionDock.saveKey));
    await pumpFrames(tester);
    expect(find.text('Write a definition before saving.'), findsOneWidget);

    final snack = find.byType(M3ESnackbar);
    expect(snack, findsOneWidget);
    final fabRect = tester.getRect(fab);
    final snackRect = tester.getRect(snack);
    expect(fabRect.overlaps(snackRect), isFalse);
    expect(fabRect.top, lessThan(fabBefore.top));
    expect(tester.getSize(slot).width, slotBefore.width);
    expect(tester.getSize(slot).width, lessThan(100));
    expect(tester.getRect(dock), dockBefore);
    expect(
      find.ancestor(of: fab, matching: find.byType(AppActionDock)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long snackbar never covers the create FAB or expands its '
      'surface', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => M3ESnackbar.defaultController.dismiss(immediate: true));
    final harness = TestHarness();
    addTearDown(harness.close);
    final notes = await seedTwoNotes(tester, harness);

    await pumpTestApp(
      tester,
      home: NoteReviewPage(notes: notes),
      harness: harness,
    );

    final fab = find.byKey(ReviewCreateFab.fabKey);
    final slot = find.byKey(ReviewCreateFab.slotKey);
    final dock = find.byType(ReviewActionDock);
    final fabBefore = tester.getRect(fab);
    final slotBefore = tester.getSize(slot);
    final dockBefore = tester.getRect(dock);

    M3ESnackbar.show(
      tester.element(fab),
      message:
          'This deliberately long validation message wraps over several lines '
          'at the smallest supported width and must never cover the create '
          'cards action or grow a surface behind it.',
    );
    await pumpFrames(tester);

    final snack = find.byType(M3ESnackbar);
    expect(snack, findsOneWidget);
    final fabAfter = tester.getRect(fab);
    expect(fabAfter.overlaps(tester.getRect(snack)), isFalse);
    expect(fabAfter.top, lessThan(fabBefore.top));
    expect(tester.getSize(slot).width, slotBefore.width);
    expect(tester.getSize(slot).width, lessThan(100));
    expect(tester.getRect(dock), dockBefore);
    expect(tester.takeException(), isNull);
  });
}
