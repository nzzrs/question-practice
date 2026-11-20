import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/export/cards_page.dart';

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
    required bool complete,
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

  Future<int> seedHighlight(
    TestHarness harness,
    Question question, {
    String text = 'managed service',
    String subtopic = '',
  }) {
    return harness.cards.createHighlight(
      sessionId: null,
      questionId: question.id,
      text: text,
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      subtopic: subtopic,
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

  Future<int> seedBasic(
    TestHarness harness,
    Question question, {
    String questionText = 'What is a VPC?',
    CognitiveType cognitiveType = CognitiveType.fact,
    String subtopic = '',
  }) {
    return harness.cards.createManualCard(
      sessionId: null,
      questionId: question.id,
      question: questionText,
      answer: 'A private network.',
      context: question.prompt,
      topicName: 'Topic',
      cognitiveType: cognitiveType,
      subtopic: subtopic,
      createdAt: harness.clock.now().toUtc(),
    );
  }

  testWidgets(
    'incomplete selection disables export but keeps review selected',
    (tester) async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await harness.seedPractice(count: 1);
      final question = await onlyQuestion(harness, seeded);
      final cardId = await seedError(harness, question, complete: false);

      await pumpTestApp(tester, home: const CardsPage(), harness: harness);
      expect(find.text('Export to AnkiDroid'), findsOneWidget);
      expect(find.byType(M3ECheckbox), findsNothing);

      final row = find.byKey(ValueKey('error-row-$cardId'));
      await tester.ensureVisible(row);
      await tester.longPress(row);
      await pumpFrames(tester);

      expect(find.text('Review all'), findsOneWidget);
      expect(find.text('Review selected'), findsOneWidget);
      expect(find.text('Export to AnkiDroid'), findsOneWidget);

      final export = tester.widget<AppPrimaryButton>(
        find.widgetWithText(AppPrimaryButton, 'Export to AnkiDroid'),
      );
      expect(export.onPressed, isNull);
      final share = tester.widget<AppDockIconButton>(
        find.ancestor(
          of: find.byIcon(Icons.ios_share),
          matching: find.byType(AppDockIconButton),
        ),
      );
      expect(share.onPressed, isNull);

      await tester.tap(row);
      await pumpFrames(tester);

      expect(find.text('Review selected'), findsNothing);
      expect(find.text('Export to AnkiDroid'), findsOneWidget);
      expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    },
  );

  testWidgets('complete error selection keeps export visible', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedError(harness, question, complete: true);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);
    expect(find.text('Review all'), findsOneWidget);
    expect(find.byType(M3ECheckbox), findsNothing);
  });

  testWidgets('skipped questions stay in cards and can become a card', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedSkipped(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.textContaining('Error and skipped'), findsOneWidget);
    expect(find.text('Question 1?'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await pumpFrames(tester);
    expect(find.text('Review the skipped question'), findsOneWidget);
    expect(find.text('Item 1 of 1'), findsOneWidget);

    await tester.tap(find.text('Make a card'));
    await pumpFrames(tester);
    expect(find.text('Turn this skipped question into a card'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await pumpFrames(tester, frames: 24);

    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, hasLength(1));
    expect(manuals!.single.context, 'Question 1?');
    final queued = await tester.runAsync(
      () => harness.cards.watchUnhandledSkippedQuestions().first,
    );
    expect(queued, isEmpty);

    await tester.tap(find.text('Done'));
    await pumpFrames(tester);
    expect(find.textContaining('Basic cards ·'), findsOneWidget);
  });

  testWidgets('review all walks error cards and skipped questions', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 2);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    await seedError(harness, questions.first, complete: true);
    await seedSkipped(harness, questions.last);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    await tester.tap(find.text('Review all'));
    await pumpFrames(tester);

    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.text('Check the error card'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await pumpFrames(tester);

    expect(find.text('Item 2 of 2'), findsOneWidget);
    expect(find.text('Review the skipped question'), findsOneWidget);
  });

  testWidgets('saved highlights stay visible in the cards view', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedHighlight(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.textContaining('Highlights ·'), findsOneWidget);
    expect(find.text('managed service'), findsOneWidget);
    expect(find.text('Download all'), findsOneWidget);
    expect(find.text('Review highlights'), findsOneWidget);
  });

  testWidgets('AI suggests grouped atomic cards and saves their type', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'cards': [
                    {
                      'type': 'heuristic',
                      'front': 'Given a VPC with a private subnet, what rule applies?',
                      'back': 'Traffic stays inside the VPC.',
                    },
                    {
                      'type': 'fact',
                      'front': 'What is a VPC?',
                      'back': 'A private network',
                    },
                    {
                      'type': 'fact',
                      'front': 'Is a VPC public?',
                      'back': 'No, it is private.',
                    },
                  ],
                }),
              },
            },
          ],
        }),
        200,
      ),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiModel: 'test-model',
        aiBaseUrl: 'https://example.test/v1',
      ),
    );
    await harness.keyStore.writeApiKey('secret-key');
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final highlightId = await seedHighlight(
      harness,
      question,
      text: 'A VPC is a private network owned by the account.',
      subtopic: 'Networking',
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('highlight-row-$highlightId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    final suggest = find.byKey(const ValueKey('highlight-suggest-cards'));
    expect(suggest, findsOneWidget);
    await tester.ensureVisible(suggest);
    await tester.tap(suggest);
    await pumpFrames(tester, frames: 24);

    expect(find.text('Suggested cards with AI'), findsOneWidget);
    expect(find.text('Procedures & rules'), findsOneWidget);
    expect(find.text('Atomic facts'), findsOneWidget);
    expect(find.text('Heuristic'), findsOneWidget);
    expect(find.text('Fact'), findsNWidgets(2));
    expect(find.text('Ready'), findsNWidgets(2));
    expect(
      find.textContaining('Can be answered with yes or no'),
      findsOneWidget,
    );
    expect(find.text('Add 3 cards'), findsOneWidget);

    await tester.ensureVisible(find.text('Add 3 cards'));
    await tester.tap(find.text('Add 3 cards'));
    await pumpFrames(tester, frames: 24);

    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, hasLength(3));
    expect(
      manuals!.map((card) => card.question),
      containsAll([
        'Given a VPC with a private subnet, what rule applies?',
        'What is a VPC?',
        'Is a VPC public?',
      ]),
    );
    expect(
      manuals.map((card) => card.cognitiveType),
      containsAll([CognitiveType.heuristic, CognitiveType.fact]),
    );
    expect(
      manuals.where((card) => card.cognitiveType == CognitiveType.heuristic),
      hasLength(1),
    );
    expect(manuals.every((card) => card.subtopic == 'Networking'), isTrue);
    expect(manuals.first.context, question.prompt);
    final highlights = await tester.runAsync(
      () => harness.cards.watchHighlights().first,
    );
    expect(highlights!.single.hasCard, isTrue);
    expect(
      find.textContaining('3 cards added from the highlight'),
      findsOneWidget,
    );
  });

  testWidgets('Cards review opens the shared highlight view', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final highlightId = await seedHighlight(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.text('Review highlights'), findsOneWidget);
    expect(find.byTooltip('Suggest cards with AI'), findsNothing);
    expect(find.byTooltip('Make a card'), findsNothing);
    expect(find.byTooltip('Delete highlight'), findsNothing);

    final row = find.byKey(ValueKey('highlight-row-$highlightId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.text('Item 1 of 1'), findsOneWidget);
    expect(find.text('Review the highlight'), findsOneWidget);
    expect(find.text('managed service'), findsOneWidget);
    expect(find.text('From the question'), findsOneWidget);
    expect(find.text('Suggest cards with AI'), findsOneWidget);
    expect(find.text('Make concept card'), findsOneWidget);
    expect(find.text('Keep for later'), findsOneWidget);
    expect(find.text('Keep & done'), findsOneWidget);
    expect(find.text('Delete highlight'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('highlight-delete')));
    await pumpFrames(tester);
    expect(find.text('Delete highlight?'), findsOneWidget);
    expect(
      find.textContaining('Cards already made from it stay'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester);
    expect(find.text('Review the highlight'), findsOneWidget);
  });

  testWidgets('highlight card action offers only a concept card', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final highlightId = await seedHighlight(
      harness,
      question,
      subtopic: 'Networking',
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('highlight-row-$highlightId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    await tester.tap(find.byKey(const ValueKey('highlight-make-card')));
    await pumpFrames(tester);

    expect(find.text('Turn the highlight into a concept card'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-card-definition')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-card-question')), findsNothing);
    expect(find.text('Basic card'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('new-card-definition')),
      'A private network.',
    );
    await pumpFrames(tester);
    await tester.tap(find.text('Create'));
    await pumpFrames(tester, frames: 24);

    final concepts = await tester.runAsync(
      () => harness.cards.watchConcepts().first,
    );
    expect(concepts, hasLength(1));
    expect(concepts!.single.term, 'managed service');
    expect(concepts.single.subtopic, 'Networking');
    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, isEmpty);
    final highlights = await tester.runAsync(
      () => harness.cards.watchHighlights().first,
    );
    expect(highlights!.single.hasCard, isTrue);
  });

  testWidgets('cognitive filters show only matching card types', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final factId = await seedBasic(
      harness,
      question,
      questionText: 'Fact card',
      cognitiveType: CognitiveType.fact,
    );
    final heuristicId = await seedBasic(
      harness,
      question,
      questionText: 'Heuristic card',
      cognitiveType: CognitiveType.heuristic,
    );
    final contrastId = await seedBasic(
      harness,
      question,
      questionText: 'Contrast card',
      cognitiveType: CognitiveType.contrast,
    );
    final conceptId = await seedConcept(harness, question);
    final errorId = await seedError(harness, question, complete: true);
    final skippedId = await seedSkipped(harness, question);
    final highlightId = await seedHighlight(harness, question);

    Future<void> choose(String filter) async {
      await tester.tap(find.byKey(ValueKey('cards-filter-$filter')));
      await pumpFrames(tester);
    }

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    expect(find.byKey(ValueKey('basic-row-$factId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$heuristicId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$contrastId')), findsOneWidget);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsOneWidget);
    expect(find.byKey(ValueKey('error-row-$errorId')), findsOneWidget);
    expect(find.byKey(ValueKey('skipped-row-$skippedId')), findsOneWidget);
    expect(find.byKey(ValueKey('highlight-row-$highlightId')), findsOneWidget);

    await choose('facts');
    expect(find.byKey(ValueKey('basic-row-$factId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$heuristicId')), findsNothing);
    expect(find.byKey(ValueKey('basic-row-$contrastId')), findsNothing);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsNothing);
    expect(find.byKey(ValueKey('error-row-$errorId')), findsNothing);
    expect(find.byKey(ValueKey('skipped-row-$skippedId')), findsNothing);
    expect(find.byKey(ValueKey('highlight-row-$highlightId')), findsNothing);

    await choose('heuristics');
    expect(find.byKey(ValueKey('basic-row-$heuristicId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$factId')), findsNothing);

    await choose('contrasts');
    expect(find.byKey(ValueKey('basic-row-$contrastId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$factId')), findsNothing);

    await choose('concepts');
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$factId')), findsNothing);
    expect(find.byKey(ValueKey('basic-row-$heuristicId')), findsNothing);
    expect(find.byKey(ValueKey('basic-row-$contrastId')), findsNothing);
    expect(find.byKey(ValueKey('error-row-$errorId')), findsNothing);
    expect(find.byKey(ValueKey('skipped-row-$skippedId')), findsNothing);
    expect(find.byKey(ValueKey('highlight-row-$highlightId')), findsNothing);

    await choose('errors');
    expect(find.byKey(ValueKey('error-row-$errorId')), findsOneWidget);
    expect(find.byKey(ValueKey('skipped-row-$skippedId')), findsOneWidget);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsNothing);
    expect(find.byKey(ValueKey('basic-row-$factId')), findsNothing);

    await choose('highlights');
    expect(find.byKey(ValueKey('highlight-row-$highlightId')), findsOneWidget);
    expect(find.byKey(ValueKey('error-row-$errorId')), findsNothing);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsNothing);

    await choose('all');
    expect(find.byKey(ValueKey('basic-row-$factId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$heuristicId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$contrastId')), findsOneWidget);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsOneWidget);
    expect(find.byKey(ValueKey('error-row-$errorId')), findsOneWidget);
    expect(find.byKey(ValueKey('skipped-row-$skippedId')), findsOneWidget);
    expect(find.byKey(ValueKey('highlight-row-$highlightId')), findsOneWidget);
  });

  testWidgets('long-press selects a concept row', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final id = await seedConcept(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('concept-row-$id'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('clear-selection')), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(M3ECheckbox), findsNothing);
  });

  testWidgets('long-press selects an error row', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final id = await seedError(harness, question, complete: true);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('error-row-$id'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('clear-selection')), findsOneWidget);
    expect(find.text('1 selected · review to export'), findsOneWidget);
    expect(find.byType(M3ECheckbox), findsNothing);
  });

  testWidgets('long-press selects a basic row', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final id = await seedBasic(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('basic-row-$id'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('clear-selection')), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(M3ECheckbox), findsNothing);
  });

  testWidgets('long-press selects a skipped row', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final id = await seedSkipped(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('skipped-row-$id'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('clear-selection')), findsOneWidget);
    expect(find.text('1 selected · review to export'), findsOneWidget);
    expect(find.byType(M3ECheckbox), findsNothing);
  });

  testWidgets('long-press selects a highlight row', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final id = await seedHighlight(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('highlight-row-$id'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('clear-selection')), findsOneWidget);
    expect(find.text('1 selected · review to export'), findsOneWidget);
    expect(find.byType(M3ECheckbox), findsNothing);
    expect(find.text('Review the highlight'), findsNothing);
  });

  testWidgets('selected skipped questions enable delete without export', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final skippedId = await seedSkipped(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.byType(M3ECheckbox), findsNothing);

    final row = find.byKey(ValueKey('skipped-row-$skippedId'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);

    expect(find.text('1 selected · review to export'), findsOneWidget);
    final export = tester.widget<AppPrimaryButton>(
      find.widgetWithText(AppPrimaryButton, 'Export to AnkiDroid'),
    );
    expect(export.onPressed, isNull);
    final share = tester.widget<AppDockIconButton>(
      find.ancestor(
        of: find.byIcon(Icons.ios_share),
        matching: find.byType(AppDockIconButton),
      ),
    );
    expect(share.onPressed, isNull);
    final delete = tester.widget<AppDockIconButton>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(AppDockIconButton),
      ),
    );
    expect(delete.onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await pumpFrames(tester);
    expect(find.text('Delete selected cards?'), findsOneWidget);
    expect(
      find.textContaining('Skipped questions are removed'),
      findsOneWidget,
    );

    await tester.tap(find.text('Delete'));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Question 1?'), findsNothing);
    final queued = await tester.runAsync(
      () => harness.cards.watchUnhandledSkippedQuestions().first,
    );
    expect(queued, isEmpty);
    final questions = await tester.runAsync(
      () => harness.practices.questionsForPractice(seeded.practiceId),
    );
    expect(questions, hasLength(1));
  });

  testWidgets('multi-selection deletes highlights and keeps their cards', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final firstId = await seedHighlight(harness, question, text: 'first');
    final secondId = await seedHighlight(harness, question, text: 'second');

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    // Created after Cards initialized, so it is not part of the selection.
    final manualId = await seedBasic(harness, question);
    await harness.cards.markHighlightConverted(
      firstId,
      cardCreatedAt: harness.clock.now().toUtc(),
      manualCardId: manualId,
    );
    await pumpFrames(tester);

    final first = find.byKey(ValueKey('highlight-row-$firstId'));
    final second = find.byKey(ValueKey('highlight-row-$secondId'));
    await tester.scrollUntilVisible(
      first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.longPress(first);
    await pumpFrames(tester);
    await tester.scrollUntilVisible(
      second,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(second);
    await pumpFrames(tester);

    expect(find.text('2 selected · review to export'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await pumpFrames(tester);
    expect(find.text('Delete selected cards?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await pumpFrames(tester, frames: 24);

    final highlights = await tester.runAsync(
      () => harness.cards.watchHighlights().first,
    );
    expect(highlights, isEmpty);
    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, hasLength(1));
  });

  testWidgets('selection never moves rows on the cards list', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 2);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final firstId = await seedSkipped(harness, questions.first);
    final secondId = await seedSkipped(harness, questions.last);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final first = find.byKey(ValueKey('skipped-row-$firstId'));
    final second = find.byKey(ValueKey('skipped-row-$secondId'));
    await tester.ensureVisible(first);
    await pumpFrames(tester);
    final before = tester.getTopLeft(first).dy;

    await tester.longPress(first);
    await pumpFrames(tester);
    expect(tester.getTopLeft(first).dy, before);
    expect(find.text('1 selected · review to export'), findsOneWidget);

    await tester.tap(second);
    await pumpFrames(tester);
    expect(find.text('2 selected · review to export'), findsOneWidget);
    expect(tester.getTopLeft(first).dy, before);
    expect(tester.getTopLeft(second).dy, greaterThan(before));
  });
}
