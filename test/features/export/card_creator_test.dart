import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/domain/reading_time.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/export/card_creator_controller.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';
import 'package:question_practice/features/review/domain/review_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<void> openCreator(
    WidgetTester tester,
    TestHarness harness,
    CardCreatorRequest request, {
    ValueChanged<int>? onSaved,
    List<Override> overrides = const [],
  }) async {
    await pumpTestApp(
      tester,
      harness: harness,
      overrides: overrides,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: M3EButton.filled(
              onPressed: () async {
                final created = await showCardCreator(
                  context,
                  request: request,
                );
                onSaved?.call(created);
              },
              label: const Text('Open creator'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open creator'));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await pumpFrames(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await reveal(tester, finder);
    await tester.tap(finder);
    await pumpFrames(tester);
  }

  Future<void> tapTemplate(WidgetTester tester, CardTemplate template) async {
    final picker = find.byKey(const ValueKey('creator-template-picker'));
    await reveal(tester, picker);
    await tester.tap(picker);
    await pumpFrames(tester, frames: 24);
    await tester.tap(find.text(template.chipLabel).last);
    await pumpFrames(tester, frames: 24);
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey(key));
    await reveal(tester, finder);
    await tester.enterText(finder, text);
    await pumpFrames(tester, frames: 4);
  }

  String fieldText(WidgetTester tester, String key) {
    return tester
        .widget<M3ETextField>(find.byKey(ValueKey(key)))
        .controller!
        .text;
  }

  Future<void> saveAll(WidgetTester tester) async {
    final save = find.byKey(const ValueKey('creator-save'));
    await reveal(tester, save);
    await tester.tap(save);
    await pumpFrames(tester, frames: 24);
  }

  Future<void> addBuilderCard(WidgetTester tester) async {
    final add = find.byKey(const ValueKey('creator-add'));
    await reveal(tester, add);
    await tester.tap(add);
    await pumpFrames(tester);
  }

  Future<NoteFixture> seedNote(
    TestHarness harness, {
    String text = 'A VPC is a private network.',
    String subtopic = 'Sub',
  }) async {
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    final createdAt = harness.clock.now().toUtc();
    final noteId = await harness.cards.createNote(
      sessionId: null,
      questionId: question.id,
      text: text,
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      subtopic: subtopic,
      createdAt: createdAt,
    );
    final note = Note(
      id: noteId,
      sessionId: null,
      questionId: question.id,
      text: text,
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      subtopic: subtopic,
      createdAt: createdAt,
      keptAt: null,
      cardCreatedAt: null,
      manualCardId: null,
    );
    return NoteFixture(note: note, question: question);
  }

  Future<CardCreatorErrorSource> seedError(
    TestHarness harness, {
    List<MistakeKind> mistakeKinds = const [],
  }) async {
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    final id = await harness.cards.createErrorCard(
      questionId: question.id,
      sessionId: null,
      question: question.prompt,
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      wrongIndexes: const [1],
      reasoning: 'Reasoning',
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      topicName: 'Topic',
      practiceName: 'Practice',
      subtopic: 'Sub',
      mistakeKinds: mistakeKinds,
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    final card = (await harness.cards.errorCardById(id))!;
    return CardCreatorErrorSource(
      card: card,
      question: question.prompt,
      wrongAnswer: question.alternatives[1],
      correctAnswer: question.alternatives[0],
      reasoning: 'Reasoning',
      explanation: question.explanation,
    );
  }

  Future<void> enableAi(TestHarness harness) async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiModel: 'test-model',
        aiBaseUrl: 'https://example.test/v1',
      ),
    );
    await harness.keyStore.writeApiKey('secret-key');
  }

  http.Response choicesResponse(Object content) {
    return http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {
              'content': content is String ? content : jsonEncode(content),
            },
          },
        ],
      }),
      200,
    );
  }

  http.Response ideasResponse(List<Map<String, dynamic>> ideas) {
    return choicesResponse({'ideas': ideas});
  }

  Map<String, dynamic> ideaJson(String template, String front, String back) {
    return {
      'template': template,
      'variants': [
        {'front': front, 'back': back},
      ],
    };
  }

  testWidgets('manual creation saves several cards without an AI provider', (
    tester,
  ) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{}', 500);
    });
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    int? created;

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
      ),
      onSaved: (count) => created = count,
    );

    expect(find.text('Save'), findsOneWidget);
    expect(
      tester
          .widget<AppPrimaryButton>(find.byKey(const ValueKey('creator-save')))
          .onPressed,
      isNull,
    );
    expect(find.text('Waiting for text'), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-ai-section')), findsNothing);
    expect(find.byKey(const ValueKey('creator-tags')), findsOneWidget);
    expect(find.text('question-practice'), findsOneWidget);
    expect(find.text('topic::topic'), findsOneWidget);
    expect(find.text('subtopic::sub'), findsOneWidget);
    expect(
      find.text(
        'Topic and subtopic are saved as tags, never inside the card text.',
      ),
      findsOneWidget,
    );

    await enter(tester, 'creator-front', 'Which layer owns IP addresses?');
    await enter(tester, 'creator-back', 'The network layer.');
    await addBuilderCard(tester);
    expect(find.text('Cards to save · 1'), findsOneWidget);

    await enter(tester, 'creator-front', 'Which layer owns MAC addresses?');
    await enter(tester, 'creator-back', 'The data link layer.');
    await addBuilderCard(tester);
    expect(find.text('Cards to save · 2'), findsOneWidget);
    expect(
      tester
          .widget<AppPrimaryButton>(find.byKey(const ValueKey('creator-save')))
          .onPressed,
      isNotNull,
    );

    await saveAll(tester);

    expect(created, 2);
    expect(requests, 0);
    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(2));
    expect(cards!.map((card) => card.question), [
      'Which layer owns IP addresses?',
      'Which layer owns MAC addresses?',
    ]);
    expect(cards.every((card) => card.subtopic == 'Sub'), isTrue);
    expect(
      cards.every((card) => card.cognitiveType == CognitiveType.contrast),
      isTrue,
    );
  });

  testWidgets('template picker fills the exact scaffolds', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(title: 'Create cards', topicName: 'Topic'),
    );

    expect(
      find.byKey(const ValueKey('creator-template-picker')),
      findsOneWidget,
    );
    expect(find.byType(M3EChip), findsNothing);

    await tapTemplate(tester, CardTemplate.contrast);
    expect(
      fieldText(tester, 'creator-front'),
      'What is the key difference between [option A] and [option B] on '
      '[criterion]?',
    );
    expect(
      fieldText(tester, 'creator-back'),
      '[Option A] does [behavior A], while [Option B] does [behavior B].',
    );

    await tapTemplate(tester, CardTemplate.mechanism);
    expect(
      fieldText(tester, 'creator-front'),
      'Why does [technology or concept] cause or require [effect]?',
    );
    expect(fieldText(tester, 'creator-back'), '[One-line cause and effect].');

    await tapTemplate(tester, CardTemplate.heuristic);
    expect(
      fieldText(tester, 'creator-front'),
      'If a scenario asks [X] but restricts with [Y], which option is always '
      'discarded?',
    );
    expect(fieldText(tester, 'creator-back'), 'Discard [Z] because [rule].');

    await tapTemplate(tester, CardTemplate.procedure);
    expect(
      fieldText(tester, 'creator-front'),
      'In [process X], what must be true before [next step Y]?',
    );
    expect(fieldText(tester, 'creator-back'), '[Condition or command].');

    await tapTemplate(tester, CardTemplate.definition);
    expect(find.byKey(const ValueKey('creator-front')), findsNothing);
    expect(
      find.byKey(const ValueKey('creator-definition-cloze')),
      findsOneWidget,
    );
    expect(
      fieldText(tester, 'creator-definition-cloze'),
      'Definition of {{c1::term}}: {{c2::…}}',
    );
    expect(
      find.byKey(const ValueKey('creator-definition-preview')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('creator-template-fill')), findsNothing);
  });

  testWidgets('a template change fills only empty or generated fields', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(title: 'Create cards', topicName: 'Topic'),
    );

    await tapTemplate(tester, CardTemplate.contrast);
    await enter(tester, 'creator-front', 'My own front?');
    await enter(tester, 'creator-back', 'My own back.');

    await tapTemplate(tester, CardTemplate.mechanism);
    expect(fieldText(tester, 'creator-front'), 'My own front?');
    expect(fieldText(tester, 'creator-back'), 'My own back.');
    expect(find.byKey(const ValueKey('creator-template-fill')), findsNothing);

    await enter(tester, 'creator-back', '');
    await tapTemplate(tester, CardTemplate.heuristic);
    expect(fieldText(tester, 'creator-front'), 'My own front?');
    expect(fieldText(tester, 'creator-back'), 'Discard [Z] because [rule].');

    await enter(tester, 'creator-front', '');
    await tapTemplate(tester, CardTemplate.procedure);
    expect(
      fieldText(tester, 'creator-front'),
      'In [process X], what must be true before [next step Y]?',
    );
    expect(fieldText(tester, 'creator-back'), '[Condition or command].');
  });

  testWidgets('a template change replaces its own generated text', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(title: 'Create cards', topicName: 'Topic'),
    );

    await tapTemplate(tester, CardTemplate.contrast);
    await tapTemplate(tester, CardTemplate.mechanism);
    expect(
      fieldText(tester, 'creator-front'),
      'Why does [technology or concept] cause or require [effect]?',
    );
    expect(fieldText(tester, 'creator-back'), '[One-line cause and effect].');
  });

  testWidgets('switching to Definition and back keeps custom text', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(title: 'Create cards', topicName: 'Topic'),
    );

    await tapTemplate(tester, CardTemplate.contrast);
    await enter(tester, 'creator-front', 'My own front?');
    await enter(tester, 'creator-back', 'My own back.');

    await tapTemplate(tester, CardTemplate.definition);
    await enter(
      tester,
      'creator-definition-cloze',
      '{{c1::Subnet}} is {{c2::a smaller network}}',
    );

    await tapTemplate(tester, CardTemplate.contrast);
    expect(fieldText(tester, 'creator-front'), 'My own front?');
    expect(fieldText(tester, 'creator-back'), 'My own back.');

    await tapTemplate(tester, CardTemplate.definition);
    expect(
      fieldText(tester, 'creator-definition-cloze'),
      '{{c1::Subnet}} is {{c2::a smaller network}}',
    );
  });

  testWidgets('error contrast scaffold inserts the wrong and correct answers', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final error = await seedError(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        error: error,
      ),
    );

    await tapTemplate(tester, CardTemplate.contrast);
    final front = fieldText(tester, 'creator-front');
    final back = fieldText(tester, 'creator-back');
    expect(front, contains('Wrong 1'));
    expect(front, contains('Correct 1'));
    expect(front, contains('[criterion]'));
    expect(back, contains('Wrong 1'));
    expect(back, contains('Correct 1'));
    expect(back, contains('[behavior A]'));
  });

  testWidgets('legacy mistake kinds stay out of the creator recap', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final error = await seedError(
      harness,
      mistakeKinds: const [MistakeKind.forgottenFact, MistakeKind.confusion],
    );

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        error: error,
      ),
    );

    expect(find.byKey(const ValueKey('creator-context')), findsOneWidget);
    expect(find.text('Wrong answer chosen'), findsOneWidget);
    expect(find.text('Forgotten fact'), findsNothing);
    expect(find.text('Confusion between 2 options'), findsNothing);
    expect(find.text('Misinterpretation'), findsNothing);
  });

  testWidgets('custom prefilled skipped or ask text is preserved', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    int? created;

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        initialFront: 'A custom question?',
        initialBack: 'A custom answer.',
      ),
      onSaved: (count) => created = count,
    );

    expect(fieldText(tester, 'creator-front'), 'A custom question?');
    expect(fieldText(tester, 'creator-back'), 'A custom answer.');
    expect(find.text('Custom card'), findsNothing);
    expect(
      find.byKey(const ValueKey('creator-template-picker')),
      findsOneWidget,
    );

    await addBuilderCard(tester);
    await saveAll(tester);
    expect(created, 1);
    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
    expect(cards!.single.cognitiveType, CognitiveType.fact);
  });

  testWidgets('quality shows Waiting for text, Ready and Check quality', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(title: 'Create cards', topicName: 'Topic'),
    );

    expect(find.text('Waiting for text'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('creator-litmus-detail-current')),
      findsNothing,
    );

    await tapTemplate(tester, CardTemplate.contrast);
    expect(find.text('Ready'), findsOneWidget);

    await enter(tester, 'creator-front', 'Is a VPC public?');
    await enter(tester, 'creator-back', 'No, it is private.');
    expect(find.text('Check quality'), findsOneWidget);
    final detail = tester.widget<Text>(
      find.byKey(const ValueKey('creator-litmus-detail-current')),
    );
    expect(detail.data, contains('Can be answered with yes or no'));

    final readingTime = find.byKey(
      const ValueKey('creator-litmus-reading-time'),
    );
    expect(readingTime, findsOneWidget);
    expect(
      find.descendant(
        of: readingTime,
        matching: find.text(readingTimeLabel('Is a VPC public?')),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Estimated time to read the front'), findsOneWidget);

    await enter(
      tester,
      'creator-front',
      'Which addresses does the network layer own?',
    );
    expect(find.text('Ready'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('creator-litmus-detail-current')),
      findsNothing,
    );
  });

  testWidgets('definition seeds a raw cloze and saves a concept without HTTP', (
    tester,
  ) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{}', 500);
    });
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    int? created;

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        initialTemplate: CardTemplate.definition,
        initialTerm: 'VPC',
        initialDefinition: 'A private network.',
      ),
      onSaved: (count) => created = count,
    );
    await pumpFrames(tester, frames: 8);

    expect(
      fieldText(tester, 'creator-definition-cloze'),
      'Definition of {{c1::VPC}}: {{c2::A private network.}}',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('creator-definition-preview')),
        matching: find.text(
          'Definition of {{c1::VPC}}: {{c2::A private network.}}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('From your cards'), findsNothing);
    expect(requests, 0);

    await addBuilderCard(tester);
    expect(find.text('Definition pending'), findsNothing);
    expect(find.text('Cards to save · 1'), findsOneWidget);
    await saveAll(tester);

    expect(created, 1);
    final concepts = await tester.runAsync(
      () => harness.cards.watchConcepts().first,
    );
    expect(concepts, hasLength(1));
    expect(concepts!.single.term, 'VPC');
    expect(concepts.single.definition, 'A private network.');
    expect(concepts.single.extra, isEmpty);
    expect(concepts.single.source, ConceptSource.manual);
  });

  testWidgets('definition edits, previews and saves the parsed raw cloze', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    int? created;

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(title: 'Create cards', topicName: 'Topic'),
      onSaved: (count) => created = count,
    );

    await tapTemplate(tester, CardTemplate.definition);
    await enter(
      tester,
      'creator-definition-cloze',
      '{{c1::VPC}} is {{c2::a private network}}',
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('creator-definition-preview')),
        matching: find.text(
          'Definition of {{c1::VPC}}: {{c2::a private network}}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Ready'), findsOneWidget);

    await addBuilderCard(tester);
    await saveAll(tester);

    expect(created, 1);
    final concepts = await tester.runAsync(
      () => harness.cards.watchConcepts().first,
    );
    expect(concepts, hasLength(1));
    expect(concepts!.single.term, 'VPC');
    expect(concepts.single.definition, 'a private network');
  });

  testWidgets('definition is never added or saved without a definition', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        initialTemplate: CardTemplate.definition,
        initialTerm: 'VPC',
      ),
    );
    await pumpFrames(tester, frames: 8);

    expect(
      fieldText(tester, 'creator-definition-cloze'),
      'Definition of {{c1::VPC}}: {{c2::…}}',
    );
    expect(find.text('Check quality'), findsOneWidget);
    expect(find.textContaining('No definition yet'), findsOneWidget);
    expect(
      tester
          .widget<M3EButton>(find.byKey(const ValueKey('creator-add')))
          .onPressed,
      isNull,
    );
    expect(find.text('Save'), findsOneWidget);
    expect(
      tester
          .widget<AppPrimaryButton>(find.byKey(const ValueKey('creator-save')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('definition preview follows raw cloze edits', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        initialTemplate: CardTemplate.definition,
      ),
    );
    await pumpFrames(tester, frames: 8);

    expect(find.text('Waiting for text'), findsOneWidget);

    await enter(
      tester,
      'creator-definition-cloze',
      'Definition of {{c1::Subnet}}: {{c2::A smaller network.}}',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('creator-definition-preview')),
        matching: find.text(
          'Definition of {{c1::Subnet}}: {{c2::A smaller network.}}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Ready'), findsOneWidget);

    await enter(tester, 'creator-definition-cloze', '{{c1::Subnet}}');
    expect(find.textContaining('No definition yet'), findsOneWidget);
  });

  testWidgets('AI suggestions stay hidden until the sparkle action is used', (
    tester,
  ) async {
    final client = MockClient(
      (_) async =>
          ideasResponse([ideaJson('contrast', 'Why A?', 'Because one.')]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
    );

    expect(find.byKey(const ValueKey('creator-ai-section')), findsNothing);
    expect(find.text('AI suggestions'), findsNothing);
    expect(find.byKey(const ValueKey('creator-ai-suggest')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is M3ETooltip && widget.message == 'Suggest cards with AI',
      ),
      findsOneWidget,
    );

    await tapKey(tester, 'creator-ai-suggest');
    await pumpFrames(tester, frames: 24);

    expect(find.byKey(const ValueKey('creator-ai-section')), findsOneWidget);
    expect(find.text('AI suggestions'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is M3ETooltip && widget.message == 'Hide AI suggestions',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('creator-ai-idea-0')), findsOneWidget);
    expect(find.text('Contrast'), findsWidgets);
  });

  testWidgets('AI suggestions skip drafts and existing card fronts', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => ideasResponse([
        ideaJson(
          'contrast',
          'Which layer owns IP addresses?',
          'The network layer.',
        ),
        ideaJson(
          'mechanism',
          'Which layer owns MAC addresses',
          'The data link layer.',
        ),
        ideaJson(
          'definition',
          'Why does a private subnet need NAT?',
          'To reach the internet.',
        ),
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
        existingFronts: const ['Which layer owns IP addresses?'],
      ),
    );

    await enter(tester, 'creator-front', 'Which layer owns MAC addresses?');
    await enter(tester, 'creator-back', 'The data link layer.');
    await addBuilderCard(tester);

    await tapKey(tester, 'creator-ai-suggest');
    await pumpFrames(tester, frames: 24);

    expect(find.text('1 idea · 1 variant'), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-ai-idea-1')), findsNothing);
    expect(find.text('Which layer owns IP addresses?'), findsNothing);
    expect(
      fieldText(tester, 'creator-ai-front-0-0'),
      'Why does a private subnet need NAT?',
    );
    expect(find.byKey(const ValueKey('creator-ai-front-0-1')), findsNothing);
  });

  testWidgets('AI note seeds drop ideas that repeat existing cards', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => ideasResponse([
        ideaJson(
          'contrast',
          'Which layer owns IP addresses?',
          'The network layer.',
        ),
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);
    final creator = CardCreatorController();
    addTearDown(creator.dispose);

    await pumpTestApp(
      tester,
      harness: harness,
      home: Scaffold(
        body: CardCreatorPane(
          request: CardCreatorRequest(
            title: 'Create cards',
            topicName: 'Topic',
            note: fixture.note,
            existingFronts: const ['Which layer owns IP addresses?'],
          ),
          controller: creator,
        ),
      ),
    );
    await pumpFrames(tester);

    creator.seedFromNote(fixture.note);
    await pumpFrames(tester, frames: 24);

    expect(find.byKey(const ValueKey('creator-seed-error')), findsOneWidget);
    expect(
      find.textContaining('only repeated cards you already have'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('creator-ai-idea-0')), findsNothing);
  });

  testWidgets('a missing AI key only shows guidance after the sparkle tap', (
    tester,
  ) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{}', 500);
    });
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
    );

    expect(find.byKey(const ValueKey('creator-ai-unavailable')), findsNothing);
    await tapKey(tester, 'creator-ai-suggest');
    await pumpFrames(tester, frames: 8);

    expect(
      find.byKey(const ValueKey('creator-ai-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Add an AI provider in Settings.'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets(
    'AI suggestions show three variants with only the first selected',
    (tester) async {
      final client = MockClient(
        (_) async => ideasResponse([
          {
            'template': 'mechanism',
            'variants': [
              {'front': 'Why A?', 'back': 'Because one.'},
              {'front': 'How does A work?', 'back': 'Because two.'},
              {'front': 'What makes A happen?', 'back': 'Because three.'},
            ],
          },
        ]),
      );
      final harness = TestHarness(httpClient: client);
      addTearDown(harness.close);
      await enableAi(harness);
      final fixture = await seedNote(harness);

      await openCreator(
        tester,
        harness,
        CardCreatorRequest(
          title: 'Create cards',
          topicName: 'Topic',
          subtopic: 'Sub',
          questionId: fixture.question.id,
          questionContext: fixture.question.prompt,
          note: fixture.note,
        ),
      );

      await tapKey(tester, 'creator-ai-suggest');
      await pumpFrames(tester, frames: 24);

      expect(find.text('1 idea · 3 variants'), findsOneWidget);
      expect(find.byKey(const ValueKey('creator-ai-idea-0')), findsOneWidget);
      for (var index = 0; index < 3; index++) {
        expect(
          find.byKey(ValueKey('creator-ai-variant-0-$index')),
          findsOneWidget,
        );
      }
      expect(
        tester
            .widget<M3ECheckbox>(
              find.byKey(const ValueKey('creator-ai-select-0-0')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<M3ECheckbox>(
              find.byKey(const ValueKey('creator-ai-select-0-1')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<M3ECheckbox>(
              find.byKey(const ValueKey('creator-ai-select-0-2')),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets('AI suggestions cap at three ideas and three variants', (
    tester,
  ) async {
    const ideaWords = ['alpha', 'beta', 'gamma', 'delta', 'epsilon'];
    const variantWords = ['one', 'two', 'three', 'four', 'five'];
    final client = MockClient(
      (_) async => ideasResponse([
        for (var idea = 0; idea < 5; idea++)
          {
            'template': 'mechanism',
            'variants': [
              for (var variant = 0; variant < 5; variant++)
                {
                  'front':
                      '${ideaWords[idea]} question ${variantWords[variant]}',
                  'back': 'Answer ${ideaWords[idea]} ${variantWords[variant]}',
                },
            ],
          },
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
    );
    await tapKey(tester, 'creator-ai-suggest');
    await pumpFrames(tester, frames: 24);

    expect(find.text('3 ideas · 9 variants'), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-ai-idea-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-ai-idea-3')), findsNothing);
    expect(
      find.byKey(const ValueKey('creator-ai-variant-2-2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('creator-ai-variant-2-3')), findsNothing);
  });

  testWidgets('AI retry replaces proposals and keeps drafts', (tester) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return ideasResponse([
        {
          'template': 'mechanism',
          'variants': [
            {
              'front': requests == 1 ? 'First proposal?' : 'Second proposal?',
              'back': 'An answer.',
            },
          ],
        },
      ]);
    });
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
    );
    await tapKey(tester, 'creator-ai-suggest');
    await pumpFrames(tester, frames: 24);
    expect(fieldText(tester, 'creator-ai-front-0-0'), 'First proposal?');

    await tapKey(tester, 'creator-ai-add');
    expect(find.text('Cards to save · 1'), findsOneWidget);

    await tapKey(tester, 'creator-ai-retry');
    await pumpFrames(tester, frames: 24);

    expect(requests, 2);
    expect(find.text('Cards to save · 1'), findsOneWidget);
    expect(fieldText(tester, 'creator-ai-front-0-0'), 'Second proposal?');
    expect(find.text('Clear suggestions'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is M3ETooltip && widget.message == 'Suggest again',
      ),
      findsOneWidget,
    );
  });

  testWidgets('AI error leaves manual drafts intact', (tester) async {
    final client = MockClient((_) async => http.Response('nope', 401));
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
    );

    await enter(tester, 'creator-front', 'Which layer owns IP?');
    await enter(tester, 'creator-back', 'The network layer.');
    await addBuilderCard(tester);
    expect(find.text('Cards to save · 1'), findsOneWidget);

    await tapKey(tester, 'creator-ai-suggest');
    await pumpFrames(tester, frames: 24);

    expect(find.byKey(const ValueKey('creator-ai-error')), findsOneWidget);
    expect(find.text('Cards to save · 1'), findsOneWidget);
    expect(
      tester
          .widget<M3ETextField>(find.byKey(const ValueKey('creator-front')))
          .enabled,
      isTrue,
    );
  });

  testWidgets('Add selected to list adds only complete selected variants', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => ideasResponse([
        {
          'template': 'contrast',
          'variants': [
            {'front': 'Complete front?', 'back': 'Complete back.'},
            {'front': 'Second front?', 'back': 'Second back.'},
          ],
        },
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
    );
    await tapKey(tester, 'creator-ai-suggest');
    await pumpFrames(tester, frames: 24);

    await tapKey(tester, 'creator-ai-select-0-1');
    await enter(tester, 'creator-ai-front-0-1', '');
    expect(
      tester
          .widget<M3ECheckbox>(
            find.byKey(const ValueKey('creator-ai-select-0-1')),
          )
          .value,
      isTrue,
    );

    await tapKey(tester, 'creator-ai-add');
    expect(find.text('Cards to save · 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('creator-ai-variant-0-0')),
      findsOneWidget,
    );
  });

  testWidgets('AI definition variant becomes a concept draft', (tester) async {
    final client = MockClient(
      (_) async => ideasResponse([
        {
          'template': 'definition',
          'variants': [
            {'front': 'VPC', 'back': 'A private network.'},
          ],
        },
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);
    int? created;

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
      onSaved: (count) => created = count,
    );
    await tapKey(tester, 'creator-ai-suggest');
    await pumpFrames(tester, frames: 24);
    await tapKey(tester, 'creator-ai-add');
    await saveAll(tester);

    expect(created, 1);
    final concepts = await tester.runAsync(
      () => harness.cards.watchConcepts().first,
    );
    expect(concepts, hasLength(1));
    expect(concepts!.single.term, 'VPC');
    expect(concepts.single.definition, 'A private network.');
    expect(concepts.single.source, ConceptSource.ai);
    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, isEmpty);
  });

  testWidgets('draft save marks the note converted with the first basic id', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionId: fixture.question.id,
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
    );
    await enter(tester, 'creator-front', 'What is a VPC?');
    await enter(tester, 'creator-back', 'A private network.');
    await addBuilderCard(tester);
    await saveAll(tester);

    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    final notes = await tester.runAsync(() => harness.cards.watchNotes().first);
    expect(cards, hasLength(1));
    expect(notes!.single.hasCard, isTrue);
    expect(notes.single.manualCardId, cards!.single.id);
  });

  testWidgets('draft save completes error details', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final error = await seedError(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: error.question,
        error: error,
      ),
    );
    await enter(tester, 'creator-front', 'Which layer owns IP?');
    await enter(tester, 'creator-back', 'The network layer.');
    await addBuilderCard(tester);
    await saveAll(tester);

    final saved = await tester.runAsync(
      () => harness.cards.errorCardById(error.card.id),
    );
    expect(saved!.needsDetails, isFalse);
  });

  testWidgets('save stays enabled while AI is loading', (tester) async {
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
    );
    await enter(tester, 'creator-front', 'Which layer owns IP?');
    await enter(tester, 'creator-back', 'The network layer.');
    await addBuilderCard(tester);

    await tapKey(tester, 'creator-ai-suggest');
    expect(find.byKey(const ValueKey('creator-ai-loading')), findsOneWidget);
    expect(
      tester
          .widget<AppPrimaryButton>(find.byKey(const ValueKey('creator-save')))
          .onPressed,
      isNotNull,
    );

    response.complete(
      ideasResponse([
        ideaJson('contrast', 'Which layer owns IP?', 'The network layer.'),
      ]),
    );
    await pumpFrames(tester, frames: 24);
    expect(find.byKey(const ValueKey('creator-ai-loading')), findsNothing);
  });

  testWidgets('embedded pane hides the sheet chrome and reports saved cards', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final creator = CardCreatorController();
    addTearDown(creator.dispose);
    int? saved;

    await pumpTestApp(
      tester,
      harness: harness,
      home: Scaffold(
        body: CardCreatorPane(
          request: const CardCreatorRequest(
            title: 'Create cards',
            topicName: 'Topic',
          ),
          controller: creator,
          onSaved: (count) => saved = count,
        ),
      ),
    );
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('creator-close')), findsNothing);
    expect(find.byKey(const ValueKey('creator-context')), findsNothing);
    expect(find.byKey(const ValueKey('creator-tags')), findsNothing);

    await enter(tester, 'creator-front', 'What is a VPC?');
    await enter(tester, 'creator-back', 'A private network.');
    await addBuilderCard(tester);
    await saveAll(tester);

    expect(saved, 1);
  });

  testWidgets('a host can save drafts without a second save button', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final creator = CardCreatorController();
    addTearDown(creator.dispose);
    final handle = CardCreatorSaveHandle();
    int? saved;

    await pumpTestApp(
      tester,
      harness: harness,
      home: Scaffold(
        body: CardCreatorPane(
          request: const CardCreatorRequest(
            title: 'Create cards',
            topicName: 'Topic',
          ),
          controller: creator,
          saveHandle: handle,
          showSaveButton: false,
          onSaved: (count) => saved = count,
        ),
      ),
    );
    await pumpFrames(tester);

    expect(find.byKey(const ValueKey('creator-save')), findsNothing);
    expect(handle.isAttached, isTrue);

    await enter(tester, 'creator-front', 'What is a VPC?');
    await enter(tester, 'creator-back', 'A private network.');
    await addBuilderCard(tester);

    final created = await tester.runAsync(() => handle.save());
    await pumpFrames(tester);

    expect(created, 1);
    expect(saved, 1);
    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
  });

  testWidgets('the compact template picker has an accessible name', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        initialFront: 'A custom question?',
        initialBack: 'A custom answer.',
      ),
    );

    final picker = find.bySemanticsLabel(RegExp('Card template'));
    expect(picker, findsOneWidget);
    final node = tester.getSemantics(picker);
    expect(node.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('completeErrorOnSave false leaves the error details open', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final error = await seedError(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        questionContext: error.question,
        error: error,
        completeErrorOnSave: false,
      ),
    );
    await enter(tester, 'creator-front', 'Which layer owns IP?');
    await enter(tester, 'creator-back', 'The network layer.');
    await addBuilderCard(tester);
    await saveAll(tester);

    final saved = await tester.runAsync(
      () => harness.cards.errorCardById(error.card.id),
    );
    expect(saved!.needsDetails, isTrue);
  });

  testWidgets('draft save handles a skipped question', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    final skippedId = await harness.cards.saveSkippedQuestion(
      sessionId: null,
      questionId: question.id,
      question: question.prompt,
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      reasoning: '',
      topicName: 'Topic',
      practiceName: 'Practice',
      unknown: false,
      createdAt: harness.clock.now().toUtc(),
    );

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        questionId: question.id,
        questionContext: question.prompt,
        initialFront: question.prompt,
        initialBack: question.correctAnswer,
        skippedQuestionId: skippedId,
      ),
    );
    await addBuilderCard(tester);
    await saveAll(tester);

    final skipped = await tester.runAsync(
      () => harness.cards.watchUnhandledSkippedQuestions().first,
    );
    expect(skipped, isEmpty);
  });

  testWidgets(
    'partial save failure keeps the remaining draft and shows snack',
    (tester) async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final service = _ControlledReviewService(harness)..failOnCall = 2;

      await openCreator(
        tester,
        harness,
        const CardCreatorRequest(title: 'Create cards', topicName: 'Topic'),
        overrides: [reviewServiceProvider.overrideWithValue(service)],
      );

      await enter(tester, 'creator-front', 'First saved?');
      await enter(tester, 'creator-back', 'First answer.');
      await addBuilderCard(tester);
      await enter(tester, 'creator-front', 'Second stays?');
      await enter(tester, 'creator-back', 'Second answer.');
      await addBuilderCard(tester);

      await saveAll(tester);
      await pumpFrames(tester, frames: 4);

      expect(
        find.textContaining('1 card saved, but the rest could not be saved'),
        findsOneWidget,
      );
      expect(find.text('Cards to save · 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('creator-draft-0')), findsOneWidget);
      final cards = await tester.runAsync(
        () => harness.cards.watchManualCards().first,
      );
      expect(cards, hasLength(1));
      expect(cards!.single.question, 'First saved?');
    },
  );

  testWidgets('saving disables close, fields and save until it finishes', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final gate = Completer<void>();
    final service = _ControlledReviewService(harness)..gate = gate;
    int? saved;

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(title: 'Create cards', topicName: 'Topic'),
      onSaved: (count) => saved = count,
      overrides: [reviewServiceProvider.overrideWithValue(service)],
    );

    await enter(tester, 'creator-front', 'A slow save?');
    await enter(tester, 'creator-back', 'A slow answer.');
    await addBuilderCard(tester);
    await tapKey(tester, 'creator-save');

    expect(find.text('Saving…'), findsOneWidget);
    expect(
      tester
          .widget<AppPrimaryButton>(find.byKey(const ValueKey('creator-save')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<M3EIconButton>(find.byKey(const ValueKey('creator-close')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<M3ETextField>(find.byKey(const ValueKey('creator-front')))
          .enabled,
      isFalse,
    );

    gate.complete();
    await pumpFrames(tester, frames: 24);
    expect(saved, 1);
  });

  testWidgets('creator fits a 320x640 screen and keep save reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(
        title: 'Create cards',
        topicName: 'A very long topic name that wraps',
        subtopic: 'A long subtopic name',
      ),
    );
    await enter(tester, 'creator-front', 'A narrow question?');
    await enter(tester, 'creator-back', 'A narrow answer.');
    await addBuilderCard(tester);
    await reveal(tester, find.byKey(const ValueKey('creator-save')));

    expect(tester.takeException(), isNull);
    expect(find.text('Cards to save · 1'), findsOneWidget);
  });

  testWidgets('creator fits 360dp at text scale 2.0', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
      ),
    );
    await reveal(tester, find.byKey(const ValueKey('creator-template-picker')));
    expect(tester.takeException(), isNull);
    await reveal(tester, find.byKey(const ValueKey('creator-save')));

    expect(tester.takeException(), isNull);
  });

  testWidgets('creator fits 320dp at text scale 2.0 with the AI action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = TestHarness();
    addTearDown(harness.close);
    final error = await seedError(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'A very long topic name that wraps',
        subtopic: 'A long subtopic name',
        error: error,
      ),
    );

    expect(find.byKey(const ValueKey('creator-ai-suggest')), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('creator-template-picker')));
    expect(tester.takeException(), isNull);
    await reveal(tester, find.byKey(const ValueKey('creator-front')));
    expect(tester.takeException(), isNull);
    await reveal(tester, find.byKey(const ValueKey('creator-save')));
    expect(tester.takeException(), isNull);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('compact picker opens and selects at 320dp text scale 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = TestHarness();
    addTearDown(harness.close);

    await openCreator(
      tester,
      harness,
      const CardCreatorRequest(title: 'Create cards', topicName: 'Topic'),
    );
    final picker = find.byKey(const ValueKey('creator-template-picker'));
    await reveal(tester, picker);
    await tester.tap(picker);
    await pumpFrames(tester, frames: 24);
    expect(find.text('Cause and effect'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cause and effect').last);
    await pumpFrames(tester, frames: 24);
    expect(fieldText(tester, 'creator-front'), contains('[effect]'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry and quality controls expose tooltips and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final client = MockClient(
      (_) async => ideasResponse([
        {
          'template': 'mechanism',
          'variants': [
            {'front': 'Why A?', 'back': 'Because one.'},
          ],
        },
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await enableAi(harness);
    final fixture = await seedNote(harness);

    await openCreator(
      tester,
      harness,
      CardCreatorRequest(
        title: 'Create cards',
        topicName: 'Topic',
        subtopic: 'Sub',
        questionContext: fixture.question.prompt,
        note: fixture.note,
      ),
    );

    expect(
      find.bySemanticsLabel('Card quality: waiting for text'),
      findsOneWidget,
    );
    await tapKey(tester, 'creator-ai-suggest');
    await pumpFrames(tester, frames: 24);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is M3ETooltip && widget.message == 'Suggest again',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Card quality: Ready'), findsWidgets);

    await tapKey(tester, 'creator-ai-add');
    expect(
      find.byWidgetPredicate(
        (widget) => widget is M3ETooltip && widget.message == 'Remove card',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

class NoteFixture {
  const NoteFixture({required this.note, required this.question});

  final Note note;
  final Question question;
}

/// Wraps the real review service so a test can fail or hold one card save.
class _ControlledReviewService extends ReviewService {
  _ControlledReviewService(TestHarness harness)
    : super(
        practices: harness.practices,
        sessions: harness.sessions,
        cards: harness.cards,
        clock: harness.clock,
      );

  int calls = 0;
  int failOnCall = 0;
  Completer<void>? gate;

  @override
  Future<int> createBasicCard({
    required int? sessionId,
    required String question,
    required String answer,
    required String topicName,
    int? questionId,
    String context = '',
    int? skippedQuestionId,
    String subtopic = '',
    CognitiveType cognitiveType = CognitiveType.fact,
  }) async {
    calls++;
    if (calls == failOnCall) {
      throw StateError('database offline');
    }
    final held = gate;
    if (held != null) await held.future;
    return super.createBasicCard(
      sessionId: sessionId,
      question: question,
      answer: answer,
      topicName: topicName,
      questionId: questionId,
      context: context,
      skippedQuestionId: skippedQuestionId,
      subtopic: subtopic,
      cognitiveType: cognitiveType,
    );
  }
}
