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

    final globalSelectAll = tester.widget<M3EIconButton>(
      find.byKey(const ValueKey('select-all')),
    );
    expect(globalSelectAll.tooltip, 'Select all');
    expect(globalSelectAll.semanticLabel, 'Select all visible items');

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
    expect(find.byKey(const ValueKey('select-all')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('clear-selection')), findsOneWidget);
    final selectAll = tester.widget<M3EIconButton>(
      find.byKey(const ValueKey('select-all')),
    );
    expect(selectAll.tooltip, 'Deselect all');

    await tester.ensureVisible(find.byKey(const ValueKey('select-all')));
    await tester.tap(find.byKey(const ValueKey('select-all')));
    await pumpFrames(tester);

    expect(find.text('Ready for AnkiDroid'), findsOneWidget);
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

  testWidgets('tapping a note opens the shared note review', (tester) async {
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

    expect(find.byType(NoteReviewPage), findsOneWidget);
    expect(find.text('Review the note'), findsOneWidget);
  });
}
