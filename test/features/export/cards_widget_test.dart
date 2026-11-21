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
    List<MistakeKind> mistakeKinds = const [],
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
      mistakeKinds: mistakeKinds,
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

  Future<int> seedNote(
    TestHarness harness,
    Question question, {
    String text = 'managed service',
    String subtopic = '',
  }) {
    return harness.cards.createNote(
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
    'incomplete error selection switches the primary action to review',
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

      expect(find.text('Review pending'), findsOneWidget);
      expect(find.text('Review all'), findsNothing);
      expect(find.text('Review selected'), findsNothing);

      final review = tester.widget<AppPrimaryButton>(
        find.widgetWithText(AppPrimaryButton, 'Review pending'),
      );
      expect(review.onPressed, isNotNull);
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

      await tester.tap(row);
      await pumpFrames(tester);

      expect(find.text('Review pending'), findsNothing);
      expect(find.text('Export to AnkiDroid'), findsOneWidget);
      expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    },
  );

  testWidgets('complete error selection keeps export visible', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final cardId = await seedError(harness, question, complete: true);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);
    expect(find.text('Review all'), findsNothing);
    expect(find.byType(M3ECheckbox), findsNothing);

    final row = find.byKey(ValueKey('error-row-$cardId'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);

    expect(find.text('1 selected'), findsOneWidget);
    final export = tester.widget<AppPrimaryButton>(
      find.widgetWithText(AppPrimaryButton, 'Export to AnkiDroid'),
    );
    expect(export.onPressed, isNull);
  });

  testWidgets('legacy mistake kinds stay out of the error preview', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final cardId = await seedError(
      harness,
      question,
      complete: true,
      mistakeKinds: const [MistakeKind.forgottenFact, MistakeKind.confusion],
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('error-row-$cardId'));
    await tester.ensureVisible(row);
    await pumpFrames(tester);
    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.text('Error preview'), findsOneWidget);
    expect(find.text('Forgotten fact'), findsNothing);
    expect(find.text('Confusion between 2 options'), findsNothing);
    expect(find.text('Misinterpretation'), findsNothing);
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
    expect(find.byTooltip('Review skipped question'), findsNothing);

    final skippedRow = find.text('Question 1?');
    await tester.ensureVisible(skippedRow);
    await tester.tap(skippedRow);
    await pumpFrames(tester);
    expect(find.text('Skipped question preview'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await pumpFrames(tester);
    expect(find.text('Review the skipped question'), findsOneWidget);
    expect(find.text('Item 1 of 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-dock-create')));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    expect(find.byKey(const ValueKey('creator-front')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    final close = find.byKey(const ValueKey('creator-close'));
    await tester.ensureVisible(close);
    await tester.tap(close);
    await pumpFrames(tester, frames: 24);
    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
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

  testWidgets('global pending review walks error cards and skipped questions', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 2);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    await seedError(harness, questions.first, complete: false);
    await seedSkipped(harness, questions.last);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    await tester.tap(find.byKey(const ValueKey('review-all-pending')));
    await pumpFrames(tester);

    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.text('Complete the error card'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-dock-next')));
    await pumpFrames(tester);

    expect(find.text('Item 2 of 2'), findsOneWidget);
    expect(find.text('Review the skipped question'), findsOneWidget);
  });

  testWidgets('saved notes stay visible in the cards view', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.textContaining('Notes ·'), findsOneWidget);
    expect(find.text('managed service'), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-download')), findsOneWidget);
    expect(find.text('Review notes'), findsNothing);
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
                  'ideas': [
                    {
                      'template': 'contrast',
                      'variants': [
                        {
                          'front':
                              'How does a VPC differ from a public subnet?',
                          'back': 'A VPC stays private while a public subnet routes out.',
                        },
                      ],
                    },
                    {
                      'template': 'mechanism',
                      'variants': [
                        {
                          'front':
                              'Why does a private subnet need a NAT gateway?',
                          'back': 'Because it has no direct route out.',
                        },
                      ],
                    },
                    {
                      'template': 'mechanism',
                      'variants': [
                        {
                          'front': 'Is a VPC public?',
                          'back': 'No, it is private.',
                        },
                      ],
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
    final noteId = await seedNote(
      harness,
      question,
      text: 'A VPC is a private network owned by the account.',
      subtopic: 'Networking',
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('note-row-$noteId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);
    expect(find.text('Note preview'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await pumpFrames(tester);

    final create = find.byKey(const ValueKey('review-dock-create'));
    expect(create, findsOneWidget);
    await tester.ensureVisible(create);
    await tester.tap(create);
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);

    final suggest = find.byKey(const ValueKey('creator-ai-suggest'));
    await tester.ensureVisible(suggest);
    await pumpFrames(tester);
    await tester.tap(suggest);
    await pumpFrames(tester, frames: 24);

    expect(find.byKey(const ValueKey('creator-ai-section')), findsOneWidget);
    expect(find.text('AI suggestions'), findsNothing);
    expect(find.text('3 ideas · 3 variants'), findsOneWidget);
    expect(find.text('Contrast'), findsWidgets);
    expect(find.text('Cause and effect'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('creator-ai-section')),
        matching: find.text('Ready'),
      ),
      findsNWidgets(2),
    );
    expect(
      find.textContaining('Can be answered with yes or no'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('creator-ai-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-add')));
    await pumpFrames(tester);
    final close = find.byKey(const ValueKey('creator-close'));
    await tester.ensureVisible(close);
    await tester.tap(close);
    await pumpFrames(tester, frames: 24);
    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
    await pumpFrames(tester, frames: 24);

    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, hasLength(3));
    expect(
      manuals!.map((card) => card.question),
      containsAll([
        'How does a VPC differ from a public subnet?',
        'Why does a private subnet need a NAT gateway?',
        'Is a VPC public?',
      ]),
    );
    expect(
      manuals.map((card) => card.cognitiveType),
      containsAll([CognitiveType.contrast, CognitiveType.fact]),
    );
    expect(
      manuals.where((card) => card.cognitiveType == CognitiveType.heuristic),
      isEmpty,
    );
    expect(manuals.every((card) => card.subtopic == 'Networking'), isTrue);
    expect(manuals.first.context, question.prompt);
    final notes = await tester.runAsync(() => harness.cards.watchNotes().first);
    expect(notes!.single.hasCard, isTrue);
  });

  testWidgets('Cards review opens the shared note view', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final noteId = await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(find.text('Review notes'), findsNothing);
    expect(find.byTooltip('Suggest cards with AI'), findsNothing);
    expect(find.byTooltip('Make a card'), findsNothing);
    expect(find.byTooltip('Delete note'), findsNothing);

    final row = find.byKey(ValueKey('note-row-$noteId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.text('Note preview'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await pumpFrames(tester);

    expect(find.text('Item 1 of 1'), findsOneWidget);
    expect(find.text('Review the note'), findsOneWidget);
    expect(find.text('managed service'), findsOneWidget);
    expect(find.text('From the question'), findsNothing);
    expect(find.byKey(const ValueKey('note-see-context')), findsOneWidget);
    expect(find.text('Suggest with AI'), findsNothing);
    expect(find.byKey(const ValueKey('review-dock-create')), findsOneWidget);
    expect(find.text('Keep for later'), findsNothing);
    expect(find.text('Save and finish'), findsOneWidget);
    expect(find.text('Delete note'), findsNothing);
    expect(find.byKey(const ValueKey('review-dock-delete')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-dock-delete')));
    await pumpFrames(tester);
    expect(find.text('Delete note?'), findsOneWidget);
    expect(
      find.textContaining('Cards already made from it stay'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester);
    expect(find.text('Review the note'), findsOneWidget);
  });

  testWidgets('note card action offers only a concept card', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final noteId = await seedNote(harness, question, subtopic: 'Networking');

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('note-row-$noteId'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await pumpFrames(tester);

    expect(find.text('Note preview'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await pumpFrames(tester);

    await tester.tap(find.byKey(const ValueKey('review-dock-create')));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);

    expect(
      find.byKey(const ValueKey('creator-definition-cloze')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('creator-front')), findsNothing);
    expect(find.text('Basic'), findsNothing);
    expect(find.text('Concept'), findsNothing);
    expect(find.text('Definition'), findsWidgets);
    expect(
      tester
          .widget<M3ETextField>(
            find.byKey(const ValueKey('creator-definition-cloze')),
          )
          .controller!
          .text,
      contains('managed service'),
    );
    expect(
      tester
          .widget<M3EButton>(find.byKey(const ValueKey('creator-add')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('creator-definition-cloze')),
      'Definition of {{c1::managed service}}: '
      '{{c2::A service run by the provider.}}',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    final close = find.byKey(const ValueKey('creator-close'));
    await tester.ensureVisible(close);
    await tester.tap(close);
    await pumpFrames(tester, frames: 24);
    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
    await pumpFrames(tester, frames: 24);

    final concepts = await tester.runAsync(
      () => harness.cards.watchConcepts().first,
    );
    expect(concepts, hasLength(1));
    expect(concepts!.single.term, 'managed service');
    expect(concepts.single.definition, 'A service run by the provider.');
    expect(concepts.single.subtopic, 'Networking');
    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, isEmpty);
    final notes = await tester.runAsync(() => harness.cards.watchNotes().first);
    expect(notes!.single.hasCard, isTrue);
  });

  testWidgets('cards filters group concepts, basic cards, errors and notes', (
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
    final noteId = await seedNote(harness, question);

    Future<void> choose(String filter) async {
      final chip = find.byKey(ValueKey('cards-filter-$filter'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await pumpFrames(tester);
    }

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    expect(find.byKey(ValueKey('basic-row-$factId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$heuristicId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$contrastId')), findsOneWidget);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsOneWidget);
    expect(find.byKey(ValueKey('error-row-$errorId')), findsOneWidget);
    expect(find.byKey(ValueKey('skipped-row-$skippedId')), findsOneWidget);
    expect(find.byKey(ValueKey('note-row-$noteId')), findsOneWidget);

    await choose('cards');
    expect(find.byKey(ValueKey('basic-row-$factId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$heuristicId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$contrastId')), findsOneWidget);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsOneWidget);
    expect(find.byKey(ValueKey('error-row-$errorId')), findsNothing);
    expect(find.byKey(ValueKey('skipped-row-$skippedId')), findsNothing);
    expect(find.byKey(ValueKey('note-row-$noteId')), findsNothing);

    await choose('errors');
    expect(find.byKey(ValueKey('error-row-$errorId')), findsOneWidget);
    expect(find.byKey(ValueKey('skipped-row-$skippedId')), findsOneWidget);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsNothing);
    expect(find.byKey(ValueKey('basic-row-$factId')), findsNothing);
    expect(find.byKey(ValueKey('note-row-$noteId')), findsNothing);

    await choose('notes');
    expect(find.byKey(ValueKey('note-row-$noteId')), findsOneWidget);
    expect(find.byKey(ValueKey('error-row-$errorId')), findsNothing);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsNothing);

    await choose('all');
    expect(find.byKey(ValueKey('basic-row-$factId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$heuristicId')), findsOneWidget);
    expect(find.byKey(ValueKey('basic-row-$contrastId')), findsOneWidget);
    expect(find.byKey(ValueKey('concept-row-$conceptId')), findsOneWidget);
    expect(find.byKey(ValueKey('error-row-$errorId')), findsOneWidget);
    expect(find.byKey(ValueKey('skipped-row-$skippedId')), findsOneWidget);
    expect(find.byKey(ValueKey('note-row-$noteId')), findsOneWidget);
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
    expect(find.text('1 selected'), findsOneWidget);
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

  testWidgets('long-press selects a note row', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final id = await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('note-row-$id'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('clear-selection')), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(M3ECheckbox), findsNothing);
    expect(find.text('Review the note'), findsNothing);
    expect(find.text('Note preview'), findsNothing);
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
    expect(find.text('Export to AnkiDroid'), findsNothing);
    final review = tester.widget<AppPrimaryButton>(
      find.widgetWithText(AppPrimaryButton, 'Review pending'),
    );
    expect(review.onPressed, isNotNull);
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

  testWidgets('multi-selection deletes notes and keeps their cards', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final firstId = await seedNote(harness, question, text: 'first');
    final secondId = await seedNote(harness, question, text: 'second');

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    // Created after Cards initialized, so it is not part of the selection.
    final manualId = await seedBasic(harness, question);
    await harness.cards.markNoteConverted(
      firstId,
      cardCreatedAt: harness.clock.now().toUtc(),
      manualCardId: manualId,
    );
    await pumpFrames(tester);

    final first = find.byKey(ValueKey('note-row-$firstId'));
    final second = find.byKey(ValueKey('note-row-$secondId'));
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

    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await pumpFrames(tester);
    expect(find.text('Delete selected cards?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await pumpFrames(tester, frames: 24);

    final notes = await tester.runAsync(() => harness.cards.watchNotes().first);
    expect(notes, isEmpty);
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
