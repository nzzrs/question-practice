import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/anki_gateway.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/errors/error_cards_review_page.dart';
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

  Future<int> seedError(
    TestHarness harness,
    Question question, {
    bool complete = false,
  }) async {
    final cardId = await harness.cards.createErrorCard(
      questionId: question.id,
      sessionId: null,
      question: question.prompt,
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      wrongIndexes: const [1],
      reasoning: 'Reason',
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      topicName: 'Topic',
      practiceName: 'Practice',
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    if (complete) {
      await harness.cards.updateErrorCardDetails(
        id: cardId,
        bias: 'Bias',
        vaccine: 'Vaccine',
        completedAt: harness.clock.now().toUtc(),
      );
    }
    return cardId;
  }

  Future<int> seedSkipped(TestHarness harness, Question question) {
    return harness.cards.saveSkippedQuestion(
      sessionId: null,
      questionId: question.id,
      question: question.prompt,
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      reasoning: 'I guessed.',
      topicName: 'Topic',
      practiceName: 'Practice',
      unknown: false,
      createdAt: harness.clock.now().toUtc(),
    );
  }

  Future<int> seedNote(TestHarness harness, Question question) {
    return harness.cards.createNote(
      sessionId: null,
      questionId: question.id,
      text: 'managed service',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
  }

  Future<int> seedConcept(TestHarness harness, Question question) {
    return harness.cards.createConcept(
      sessionId: null,
      questionId: question.id,
      term: 'VPC',
      definition: 'A private network.',
      context: question.prompt,
      topicName: 'Topic',
      source: ConceptSource.manual,
      createdAt: harness.clock.now().toUtc(),
    );
  }

  Future<int> seedBasic(TestHarness harness, Question question) {
    return harness.cards.createManualCard(
      sessionId: null,
      questionId: question.id,
      question: 'What is a VPC?',
      answer: 'A private network.',
      context: question.prompt,
      topicName: 'Topic',
      cognitiveType: CognitiveType.fact,
      createdAt: harness.clock.now().toUtc(),
    );
  }

  testWidgets('filters stay compact and sections drop verbose actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedConcept(harness, question);
    await seedBasic(harness, question);
    await seedError(harness, question);
    await seedSkipped(harness, question);
    await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(tester.takeException(), isNull);

    expect(find.byKey(const ValueKey('cards-filter-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-filter-cards')), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-filter-errors')), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-filter-notes')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cards-filter-show-exported')),
      findsOneWidget,
    );
    expect(find.text('Facts'), findsNothing);
    expect(find.text('Heuristics'), findsNothing);
    expect(find.text('Contrasts'), findsNothing);

    expect(find.textContaining('Anki Cloze'), findsNothing);
    expect(find.textContaining('Create cards turns'), findsNothing);
    expect(find.textContaining('Anki Basic'), findsNothing);
    expect(find.textContaining('Plain text only'), findsNothing);
    expect(find.text('Review all'), findsNothing);
    expect(find.text('Review selected'), findsNothing);
    expect(find.text('Review notes'), findsNothing);
    expect(find.text('Download all'), findsNothing);
    expect(find.byTooltip('Complete'), findsNothing);
    expect(find.byTooltip('Create cards'), findsNothing);
    expect(find.byTooltip('Review skipped question'), findsNothing);

    final globalSelectAll = tester.widget<M3EButton>(
      find.byKey(const ValueKey('select-all')),
    );
    expect(globalSelectAll.onPressed, isNotNull);
    expect(globalSelectAll.semanticLabel, 'Select all visible items');
    expect(find.byKey(const ValueKey('cards-action-row')), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-all-pending')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notes-download')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);

    final notesDownload = tester.widget<M3EIconButton>(
      find.byKey(const ValueKey('notes-download')),
    );
    expect(notesDownload.tooltip, 'Download all notes');

    final notesSelectAll = find.descendant(
      of: find.byKey(const ValueKey('notes-select-all')),
      matching: find.byType(M3EIconButton),
    );
    expect(notesSelectAll, findsOneWidget);
    expect(
      tester.getCenter(notesSelectAll).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('notes-download'))).dx,
      ),
    );

    // Selection has no separate clear control. The action row must still fit
    // at 320dp with 2x text.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('select-all')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('select-all')));
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    expect(find.byKey(const ValueKey('select-all')), findsOneWidget);
    expect(find.text('Deselect all'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards page fits a 320dp window at normal text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedConcept(harness, question);
    await seedBasic(harness, question);
    await seedError(harness, question);
    await seedSkipped(harness, question);
    await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('cards-status')), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-filter-bar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('review-all-pending')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('select-all')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cards-info')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards page fits a 720dp landscape window', (tester) async {
    tester.view.physicalSize = const Size(720, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedConcept(harness, question);
    await seedBasic(harness, question);
    await seedError(harness, question);
    await seedSkipped(harness, question);
    await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(tester.takeException(), isNull);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-filter-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-action-row')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('select-all')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('review-all-pending')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cards-info')), findsOneWidget);
  });

  testWidgets('cards page fits a 720dp landscape window at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedConcept(harness, question);
    await seedBasic(harness, question);
    await seedError(harness, question);
    await seedSkipped(harness, question);
    await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    await pumpFrames(tester);

    final actionRect = tester.getRect(
      find.byKey(const ValueKey('cards-action-row')),
    );
    final reviewRect = tester.getRect(
      find.byKey(const ValueKey('review-all-pending')),
    );
    final selectRect = tester.getRect(find.byKey(const ValueKey('select-all')));

    final reason = 'row $actionRect review $reviewRect select $selectRect';
    for (final rect in [reviewRect, selectRect]) {
      expect(rect.left, greaterThanOrEqualTo(actionRect.left), reason: reason);
      expect(rect.right, lessThanOrEqualTo(actionRect.right), reason: reason);
      expect(rect.top, greaterThanOrEqualTo(actionRect.top), reason: reason);
      expect(rect.bottom, lessThanOrEqualTo(actionRect.bottom), reason: reason);
    }
    expect(
      find.byKey(const ValueKey('cards-info')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('actions sit under the filters, right aligned and in order', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedConcept(harness, question);
    await seedError(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    final filterRect = tester.getRect(
      find.byKey(const ValueKey('cards-filter-bar')),
    );
    final actionRect = tester.getRect(
      find.byKey(const ValueKey('cards-action-row')),
    );
    final review = find.byKey(const ValueKey('review-all-pending'));
    final selectAll = find.byKey(const ValueKey('select-all'));

    expect(actionRect.top, greaterThanOrEqualTo(filterRect.bottom));
    expect(find.text('Review all pending'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
    expect(
      tester.getCenter(review).dx,
      lessThan(tester.getCenter(selectAll).dx),
    );
    expect(tester.getTopRight(selectAll).dx, closeTo(actionRect.right, 1));
    expect(
      tester.getSize(selectAll).width,
      lessThanOrEqualTo(actionRect.width),
    );
    expect(review.hitTestable(), findsOneWidget);
    expect(selectAll.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 360]) {
    testWidgets(
      'both actions stay on screen at ${width.toInt()}dp with 2x text',
      (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final harness = TestHarness();
        addTearDown(harness.close);
        final seeded = await harness.seedPractice(count: 1);
        final question = await onlyQuestion(harness, seeded);
        await seedConcept(harness, question);
        await seedError(harness, question);

        await pumpTestApp(tester, home: const CardsPage(), harness: harness);
        await pumpFrames(tester);

        final actionRect = tester.getRect(
          find.byKey(const ValueKey('cards-action-row')),
        );
        final review = find.byKey(const ValueKey('review-all-pending'));
        final selectAll = find.byKey(const ValueKey('select-all'));
        final reviewRect = tester.getRect(review);
        final selectRect = tester.getRect(selectAll);

        // Both actions are fully inside the row, stacked in reading order and
        // flush with its right edge. Nothing hides behind a horizontal scroll.
        final reason = 'row $actionRect review $reviewRect select $selectRect';
        for (final rect in [reviewRect, selectRect]) {
          expect(
            rect.left,
            greaterThanOrEqualTo(actionRect.left),
            reason: reason,
          );
          expect(
            rect.right,
            lessThanOrEqualTo(actionRect.right),
            reason: reason,
          );
          expect(
            rect.top,
            greaterThanOrEqualTo(actionRect.top),
            reason: reason,
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(actionRect.bottom),
            reason: reason,
          );
        }
        expect(
          reviewRect.bottom,
          lessThanOrEqualTo(selectRect.top),
          reason: reason,
        );
        expect(reviewRect.right, closeTo(actionRect.right, 1), reason: reason);
        expect(selectRect.right, closeTo(actionRect.right, 1), reason: reason);
        expect(review.hitTestable(), findsOneWidget);
        expect(selectAll.hitTestable(), findsOneWidget);

        // Large text wraps the longest label instead of clipping it.
        final reviewLabel = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: review,
            matching: find.text('Review all pending'),
          ),
        );
        expect(reviewLabel.didExceedMaxLines, isFalse);

        await tester.tap(selectAll);
        await pumpFrames(tester);
        expect(find.text('Deselect all'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('help icon opens a short structured export guide', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(count: 1);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsNothing);
    final info = tester.widget<M3EIconButton>(
      find.byKey(const ValueKey('cards-info')),
    );
    expect(info.tooltip, 'What exports to Anki');
    expect(info.semanticLabel, 'What exports to Anki');

    await tester.tap(find.byKey(const ValueKey('cards-info')));
    await pumpFrames(tester);

    expect(find.text('What goes to Anki'), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-info-cloze')), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-info-basic')), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-info-tags')), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-info-decks')), findsOneWidget);
    expect(find.byKey(const ValueKey('cards-info-stays')), findsOneWidget);
    expect(find.text('Cloze cards'), findsOneWidget);
    expect(find.text('Basic cards'), findsOneWidget);
    expect(
      find.text(
        'Basic cards come from the Contrast, Cause and effect, '
        'Scenario and rule, and Steps templates. Each has a front and a back.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Decks'), findsOneWidget);
    expect(find.text('Stays in Question Practice'), findsOneWidget);

    // The guide uses the current card vocabulary and stays short: no old
    // paragraph plumbing or retired taxonomy leaks into the dialog.
    expect(find.textContaining('heuristics'), findsNothing);
    expect(find.textContaining('topic::'), findsNothing);
    expect(find.textContaining('subtopic::'), findsNothing);
    expect(find.textContaining('question-practice'), findsNothing);
    expect(find.textContaining('AI suggestions'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help dialog fits 320dp with 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(count: 1);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    await tester.tap(find.byKey(const ValueKey('cards-info')));
    await pumpFrames(tester);

    expect(find.text('What goes to Anki'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('concept preview hides raw source names and type pills', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final conceptId = await seedConcept(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('concept-row-$conceptId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.text('Concept preview'), findsOneWidget);
    expect(find.text('manual'), findsNothing);
    expect(find.text('ai'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(M3EDialog),
        matching: find.text('Concept'),
      ),
      findsNothing,
    );
    expect(find.text('Cloze card'), findsOneWidget);
  });

  testWidgets('select all ignores visible rows that cannot be selected', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final basicId = await seedBasic(harness, question);
    await harness.cards.markExported(
      conceptIds: const [],
      manualCardIds: [basicId],
      exportedAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    await tester.tap(find.byKey(const ValueKey('cards-filter-show-exported')));
    await pumpFrames(tester);
    expect(find.byKey(ValueKey('basic-row-$basicId')), findsOneWidget);

    final globalSelectAll = tester.widget<M3EButton>(
      find.byKey(const ValueKey('select-all')),
    );
    expect(globalSelectAll.onPressed, isNull);
    final sectionSelectAll = tester.widget<M3EIconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('basic-select-all')),
        matching: find.byType(M3EIconButton),
      ),
    );
    expect(sectionSelectAll.onPressed, isNull);
  });

  testWidgets('a concept without a definition can be completed from preview', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final conceptId = await seedConcept(harness, question);
    await harness.cards.updateConceptDefinition(conceptId, '');

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('concept-row-$conceptId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);
    expect(find.text('Concept preview'), findsOneWidget);
    expect(find.text('Needs a definition before export.'), findsWidgets);

    await tester.tap(find.text('Complete'));
    await pumpFrames(tester);
    expect(find.text('Definition of VPC'), findsWidgets);
    expect(find.text('Save'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'A private network.');
    await tester.tap(find.text('Save'));
    await pumpFrames(tester, frames: 24);

    final concepts = await tester.runAsync(
      () => harness.cards.watchConcepts().first,
    );
    expect(concepts!.single.isExportable, isTrue);
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('global select all selects every visible row and toggles off', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedConcept(harness, question);
    await seedBasic(harness, question);
    await seedError(harness, question);
    await seedSkipped(harness, question);
    await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.text('Ready for AnkiDroid'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('select-all')));
    await pumpFrames(tester);

    expect(find.text('5 selected · review to export'), findsOneWidget);
    expect(find.text('Review pending'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    expect(find.text('Deselect all'), findsOneWidget);
    final selectAll = tester.widget<M3EButton>(
      find.byKey(const ValueKey('select-all')),
    );
    expect(selectAll.onPressed, isNotNull);

    await tester.ensureVisible(find.byKey(const ValueKey('select-all')));
    await tester.tap(find.byKey(const ValueKey('select-all')));
    await pumpFrames(tester);

    expect(find.text('Ready for AnkiDroid'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
  });

  testWidgets('primary action reviews pending selection before exporting', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final conceptId = await seedConcept(harness, question);
    final errorId = await seedError(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    final conceptRow = find.byKey(ValueKey('concept-row-$conceptId'));
    await tester.ensureVisible(conceptRow);
    await tester.longPress(conceptRow);
    await pumpFrames(tester);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);
    final export = tester.widget<AppPrimaryButton>(
      find.widgetWithText(AppPrimaryButton, 'Export to AnkiDroid'),
    );
    expect(export.onPressed, isNotNull);

    final errorRow = find.byKey(ValueKey('error-row-$errorId'));
    await tester.ensureVisible(errorRow);
    await tester.tap(errorRow);
    await pumpFrames(tester);
    expect(find.text('2 selected · review to export'), findsOneWidget);
    expect(find.text('Review pending'), findsOneWidget);
    expect(
      tester
          .widget<AppPrimaryButton>(
            find.widgetWithText(AppPrimaryButton, 'Review pending'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(errorRow);
    await pumpFrames(tester);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);
  });

  testWidgets('exporting ready selection clears and persists no selection', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedConcept(harness, question);
    await seedBasic(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    await tester.tap(find.byKey(const ValueKey('select-all')));
    await pumpFrames(tester);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(AppPrimaryButton, 'Export to AnkiDroid'),
    );
    await pumpFrames(tester, frames: 24);

    expect((harness.anki as FakeAnkiGateway).importedNotes, hasLength(2));
    expect(find.text('Ready for AnkiDroid'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);

    final stored = await tester.runAsync(
      () => harness.settings.loadCardsSelection(),
    );
    expect(stored, isNull);
  });

  testWidgets('error and skipped previews review the chosen item', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 2);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final errorId = await seedError(harness, questions.first);
    final skippedId = await seedSkipped(harness, questions.last);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    final errorRow = find.byKey(ValueKey('error-row-$errorId'));
    await tester.ensureVisible(errorRow);
    await tester.tap(errorRow);
    await pumpFrames(tester);
    expect(find.text('Error preview'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await pumpFrames(tester);
    expect(find.byType(ErrorCardsReviewPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-focus-exit')));
    await pumpFrames(tester);

    final skippedRow = find.byKey(ValueKey('skipped-row-$skippedId'));
    await tester.ensureVisible(skippedRow);
    await tester.tap(skippedRow);
    await pumpFrames(tester);
    expect(find.text('Skipped question preview'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await pumpFrames(tester);
    expect(find.byType(ErrorCardsReviewPage), findsOneWidget);
  });

  testWidgets('tapping a note previews it, then opens the shared note review', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final noteId = await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('note-row-$noteId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.text('Note preview'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(M3EDialog), matching: find.text('Note')),
      findsNothing,
    );
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.byType(NoteReviewPage), findsNothing);

    await tester.tap(find.text('Review'));
    await pumpFrames(tester);

    expect(find.byType(NoteReviewPage), findsOneWidget);
    expect(find.text('Review the note'), findsOneWidget);
  });
}
