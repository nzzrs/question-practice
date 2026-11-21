import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<void> openCreator(WidgetTester tester) async {
    await tester.tap(find.text('Open creator'));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await pumpFrames(tester);
  }

  http.Response aiResponse(List<Map<String, String>> cards) {
    return http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode({'cards': cards}),
            },
          },
        ],
      }),
      200,
    );
  }

  testWidgets('manual creation saves several basic cards one by one', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    int? created;

    await pumpTestApp(
      tester,
      harness: harness,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: M3EButton.filled(
              onPressed: () async {
                created = await showCardCreator(
                  context,
                  request: const CardCreatorRequest(
                    title: 'Create cards',
                    topicName: 'Topic',
                    subtopic: 'Sub',
                  ),
                );
              },
              label: const Text('Open creator'),
            ),
          ),
        ),
      ),
    );
    await openCreator(tester);

    expect(find.byKey(const ValueKey('creator-ai-unavailable')), findsNothing);
    expect(find.text('Save 0 cards'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'Which layer owns IP addresses?',
    );
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'The network layer.',
    );
    await reveal(tester, find.byKey(const ValueKey('creator-type-fact')));
    await tester.tap(find.byKey(const ValueKey('creator-type-fact')));
    await pumpFrames(tester);
    await reveal(tester, find.byKey(const ValueKey('creator-add')));
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);

    expect(find.text('Save 1 card'), findsOneWidget);
    expect(
      tester
          .widget<M3ETextField>(find.byKey(const ValueKey('creator-front')))
          .controller!
          .text,
      isEmpty,
    );

    await reveal(tester, find.byKey(const ValueKey('creator-front')));
    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'Which layer owns MAC addresses?',
    );
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'The data link layer.',
    );
    await pumpFrames(tester);
    await reveal(tester, find.byKey(const ValueKey('creator-add')));
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);

    expect(find.text('Save 2 cards'), findsOneWidget);

    await reveal(tester, find.byKey(const ValueKey('creator-draft-0')));
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await pumpFrames(tester);
    expect(find.text('Save 1 card'), findsOneWidget);

    await reveal(tester, find.text('Save 1 card'));
    await tester.tap(find.text('Save 1 card'));
    await pumpFrames(tester, frames: 24);

    expect(created, 1);
    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
    expect(cards!.single.question, 'Which layer owns MAC addresses?');
    expect(cards.single.answer, 'The data link layer.');
    expect(cards.single.subtopic, 'Sub');
    expect(cards.single.cognitiveType, CognitiveType.fact);
  });

  testWidgets('concept creation saves a concept card', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    int? created;

    await pumpTestApp(
      tester,
      harness: harness,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: M3EButton.filled(
              onPressed: () async {
                created = await showCardCreator(
                  context,
                  request: const CardCreatorRequest(
                    title: 'Create cards',
                    topicName: 'Topic',
                    subtopic: 'Networking',
                  ),
                );
              },
              label: const Text('Open creator'),
            ),
          ),
        ),
      ),
    );
    await openCreator(tester);

    await reveal(tester, find.text('Concept'));
    await tester.tap(find.text('Concept'));
    await pumpFrames(tester);
    await tester.enterText(find.byKey(const ValueKey('creator-term')), 'VPC');
    await tester.enterText(
      find.byKey(const ValueKey('creator-definition')),
      'A private network.',
    );
    await pumpFrames(tester);
    await reveal(tester, find.byKey(const ValueKey('creator-add')));
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await reveal(tester, find.text('Save 1 card'));
    await tester.tap(find.text('Save 1 card'));
    await pumpFrames(tester, frames: 24);

    expect(created, 1);
    final concepts = await tester.runAsync(
      () => harness.cards.watchConcepts().first,
    );
    expect(concepts, hasLength(1));
    expect(concepts!.single.term, 'VPC');
    expect(concepts.single.definition, 'A private network.');
    expect(concepts.single.subtopic, 'Networking');
    expect(concepts.single.source, ConceptSource.manual);
    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, isEmpty);
  });

  testWidgets('litmus warns about binary and heuristic fronts', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(
      tester,
      harness: harness,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: M3EButton.filled(
              onPressed: () => showCardCreator(
                context,
                request: const CardCreatorRequest(
                  title: 'Create cards',
                  topicName: 'Topic',
                ),
              ),
              label: const Text('Open creator'),
            ),
          ),
        ),
      ),
    );
    await openCreator(tester);

    await reveal(tester, find.byKey(const ValueKey('creator-type-heuristic')));
    await tester.tap(find.byKey(const ValueKey('creator-type-heuristic')));
    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'Is a VPC public because it is private?',
    );
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'No, it is private.',
    );
    await pumpFrames(tester);

    expect(find.text('Check quality'), findsOneWidget);
    final detail = tester.widget<Text>(
      find.byKey(const ValueKey('creator-litmus-detail-current')),
    );
    expect(detail.data, contains('Can be answered with yes or no'));
    expect(detail.data, contains('The question hints at the answer'));
    expect(
      detail.data,
      contains('Heuristic front does not use the rule template'),
    );
    expect(
      find.byKey(const ValueKey('creator-heuristic-template')),
      findsOneWidget,
    );
  });

  testWidgets('AI suggestions can be edited, added and saved', (tester) async {
    final client = MockClient(
      (request) async => aiResponse([
        {
          'type': 'heuristic',
          'front': 'Given a VPC with a private subnet, what rule applies?',
          'back': 'Traffic stays inside the VPC.',
        },
        {
          'type': 'fact',
          'front': 'What is a VPC?',
          'back': 'A private network.',
        },
      ]),
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
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    final noteId = await harness.cards.createNote(
      sessionId: null,
      questionId: question.id,
      text: 'A VPC is a private network.',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      subtopic: 'Networking',
      createdAt: harness.clock.now().toUtc(),
    );
    final note = (await tester.runAsync(
      () => harness.cards.watchNotes().first,
    ))!.singleWhere((item) => item.id == noteId);

    int? created;
    await pumpTestApp(
      tester,
      harness: harness,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: M3EButton.filled(
              onPressed: () async {
                created = await showCardCreator(
                  context,
                  request: CardCreatorRequest(
                    title: 'Create cards',
                    questionId: question.id,
                    questionContext: question.prompt,
                    topicName: 'Topic',
                    subtopic: 'Networking',
                    initialKind: CardCreatorKind.concept,
                    initialTerm: note.text,
                    note: note,
                  ),
                );
              },
              label: const Text('Open creator'),
            ),
          ),
        ),
      ),
    );
    await openCreator(tester);

    await reveal(tester, find.byKey(const ValueKey('creator-ai-suggest')));
    await tester.tap(find.byKey(const ValueKey('creator-ai-suggest')));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Heuristic'), findsOneWidget);
    expect(find.text('Fact'), findsOneWidget);
    expect(find.text('Ready'), findsNWidgets(3));

    await tester.enterText(
      find.byKey(const ValueKey('creator-ai-front-1')),
      'What exactly is a VPC?',
    );
    await pumpFrames(tester);

    await reveal(tester, find.byKey(const ValueKey('creator-ai-select-0')));
    await tester.tap(find.byKey(const ValueKey('creator-ai-select-0')));
    await pumpFrames(tester);
    await reveal(tester, find.byKey(const ValueKey('creator-ai-add')));
    await tester.tap(find.byKey(const ValueKey('creator-ai-add')));
    await pumpFrames(tester);

    expect(find.text('Save 1 card'), findsOneWidget);
    await reveal(tester, find.text('Save 1 card'));
    await tester.tap(find.text('Save 1 card'));
    await pumpFrames(tester, frames: 24);

    expect(created, 1);
    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
    expect(cards!.single.question, 'What exactly is a VPC?');
    expect(cards.single.cognitiveType, CognitiveType.fact);
    expect(cards.single.subtopic, 'Networking');
    final savedNote = await tester.runAsync(
      () => harness.cards.watchNotes().first,
    );
    expect(savedNote!.single.hasCard, isTrue);
  });
}
