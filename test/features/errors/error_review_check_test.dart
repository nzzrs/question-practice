import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/app_sections.dart';
import 'package:question_practice/features/errors/error_card_review_view.dart';
import 'package:question_practice/features/export/card_creator_controller.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';

import '../../helpers/test_harness.dart';

const _aiSettings = AppSettings(
  lookupMode: LookupMode.ai,
  aiModel: 'test-model',
  aiBaseUrl: 'https://example.test/v1',
);

http.Response _aiResponse(List<Map<String, dynamic>> ideas) {
  return http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({'ideas': ideas}),
          },
        },
      ],
    }),
    200,
  );
}

Map<String, dynamic> _idea(String template, String front, String back) {
  return {
    'template': template,
    'variants': [
      {'front': front, 'back': back},
    ],
  };
}

Future<ErrorCard> _createError(
  TestHarness harness, {
  String subtopic = 'Network layer',
  List<MistakeKind> mistakeKinds = const [MistakeKind.confusion],
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
    reasoning: 'I assumed both alternatives did the same job.',
    explanation: question.explanation,
    alternativeExplanations: question.alternativeExplanations,
    topicName: 'Topic',
    practiceName: 'Practice',
    subtopic: subtopic,
    mistakeKinds: mistakeKinds,
    lastWrongAt: harness.clock.now().toUtc(),
    dueAfter: const Duration(hours: 48),
  );
  return (await harness.cards.errorCardById(id))!;
}

Future<void> _pumpView(
  WidgetTester tester,
  TestHarness harness,
  ErrorCard card, {
  ValueChanged<int>? onCardsAdded,
}) async {
  final creator = CardCreatorController();
  addTearDown(creator.dispose);
  await pumpTestApp(
    tester,
    home: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ErrorCardReviewView(
                card: card,
                creator: creator,
                onSeedRequested: () {},
              ),
            ),
          ),
          SizedBox(
            height: 360,
            child: CardCreatorPane(
              request: CardCreatorRequest(
                title: 'Create cards',
                sessionId: card.sessionId,
                questionId: card.questionId,
                questionContext: card.question,
                topicName: card.topicName,
                subtopic: card.subtopic,
                error: CardCreatorErrorSource(
                  card: card,
                  question: card.question,
                  wrongAnswer: card.wrongAnswer,
                  correctAnswer: card.correctAnswer,
                  reasoning: card.reasoning,
                  explanation: card.explanation,
                ),
              ),
              controller: creator,
              onSaved: onCardsAdded,
            ),
          ),
        ],
      ),
    ),
    harness: harness,
  );
}

void main() {
  testWidgets('error review keeps compact context and no bias notes', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);

    expect(find.text('Correct 1'), findsOneWidget);
    expect(find.text('Wrong 1'), findsOneWidget);
    expect(find.text('What went wrong?'), findsOneWidget);
    expect(
      find.text('I assumed both alternatives did the same job.'),
      findsOneWidget,
    );
    expect(find.text('Not quite.'), findsOneWidget);
    expect(find.text('Network layer'), findsOneWidget);
    expect(find.text('Why this answer'), findsOneWidget);
    expect(find.byKey(const ValueKey('error-card-edit-content')), findsNothing);
    expect(find.text('Check with AI'), findsNothing);
    expect(find.text('Flawed assumption (bias)'), findsNothing);
    expect(find.text('Vaccine (rule / protocol)'), findsNothing);
    expect(find.byKey(const ValueKey('error-card-reading-time')), findsNothing);
    expect(find.byType(CardCreatorPane), findsOneWidget);
    expect(find.text('Create cards'), findsOneWidget);
  });

  testWidgets('manual error cards work without an AI provider', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);

    expect(find.byType(CardCreatorPane), findsOneWidget);
    expect(find.byType(CardCreatorSheet), findsNothing);

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
    await tester.ensureVisible(find.byKey(const ValueKey('creator-save')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-save')));
    await pumpFrames(tester, frames: 24);

    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
    expect(cards!.single.cognitiveType, CognitiveType.contrast);
    final saved = await tester.runAsync(
      () => harness.cards.errorCardById(card.id),
    );
    expect(saved!.needsDetails, isFalse);
  });

  testWidgets('breakdown shows cognitive types and litmus badges', (
    tester,
  ) async {
    String? sentBody;
    final client = MockClient((request) async {
      sentBody = request.body;
      return _aiResponse([
        _idea(
          'contrast',
          'Which layer owns IP addresses?',
          'The network layer owns addressing.',
        ),
        _idea(
          'heuristic',
          'If a scenario asks for addressing but restricts with layer, which '
              'option is always discarded?',
          'Discard the physical layer because it has no addressing.',
        ),
      ]);
    });
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-ai-suggest')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-suggest')));
    await pumpFrames(tester, frames: 24);

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<Pill>(find.byKey(const ValueKey('creator-ai-type-0')))
          .label,
      'Contrast',
    );
    final ready = tester.widget<Pill>(
      find.descendant(
        of: find.byKey(const ValueKey('creator-ai-litmus-0-0')),
        matching: find.byType(Pill),
      ),
    );
    expect(ready.label, 'Ready');
    expect(ready.tone, PillTone.success);
    expect(
      tester
          .widget<Pill>(find.byKey(const ValueKey('creator-ai-type-1')))
          .label,
      'Scenario and rule',
    );
    expect(
      find.textContaining(
        'If a scenario asks for addressing but restricts with layer',
      ),
      findsWidgets,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('creator-ai-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-add')));
    await pumpFrames(tester);
    expect(find.text('Cards to save · 2'), findsOneWidget);
    expect(sentBody, isNotNull);
    expect(sentBody, contains('Chosen wrong answer: Wrong 1'));
    expect(sentBody, contains('Correct answer: Correct 1'));
    expect(sentBody, contains('Confusion between 2 options'));
    expect(sentBody, contains('Subtopic: Network layer'));
  });

  testWidgets('cards with litmus issues stay visible with a warning', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => _aiResponse([
        _idea(
          'heuristic',
          'Is a managed service the right choice here?',
          'A managed service removes host maintenance.',
        ),
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-ai-suggest')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-suggest')));
    await pumpFrames(tester, frames: 24);

    expect(find.byKey(const ValueKey('creator-ai-idea-0')), findsOneWidget);
    final badge = tester.widget<Pill>(
      find.descendant(
        of: find.byKey(const ValueKey('creator-ai-litmus-0-0')),
        matching: find.byType(Pill),
      ),
    );
    expect(badge.label, 'Check quality');
    expect(badge.tone, PillTone.error);
    final detail = tester.widget<Text>(
      find.byKey(const ValueKey('creator-ai-litmus-detail-0-0')),
    );
    expect(detail.data, contains('Can be answered with yes or no'));
    expect(
      detail.data,
      contains(
        'Scenario and rule front does not use the required prompt structure',
      ),
    );
  });

  testWidgets('adding selected cards saves them and completes the error', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => _aiResponse([
        _idea(
          'contrast',
          'Which layer owns IP addresses?',
          'The network layer owns addressing.',
        ),
        _idea(
          'heuristic',
          'If a scenario asks for addressing but restricts with layer, which '
              'option is always discarded?',
          'Discard the physical layer because it has no addressing.',
        ),
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final card = await _createError(harness);
    var reported = 0;

    await _pumpView(
      tester,
      harness,
      card,
      onCardsAdded: (count) => reported = count,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-ai-suggest')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-suggest')));
    await pumpFrames(tester, frames: 24);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-ai-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-add')));
    await pumpFrames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-save')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-save')));
    await pumpFrames(tester, frames: 24);

    expect(reported, 2);
    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(2));
    final byType = {for (final item in cards!) item.cognitiveType: item};
    expect(byType.keys, containsAll([CognitiveType.contrast]));
    expect(byType.keys, contains(CognitiveType.heuristic));
    expect(byType[CognitiveType.contrast]!.subtopic, 'Network layer');
    expect(byType[CognitiveType.contrast]!.topicName, 'Topic');
    expect(byType[CognitiveType.contrast]!.questionId, card.questionId);
    expect(byType[CognitiveType.contrast]!.sessionId, card.sessionId);

    final saved = await tester.runAsync(
      () => harness.cards.errorCardById(card.id),
    );
    expect(saved!.needsDetails, isFalse);
    expect(saved.detailsCompletedAt, isNotNull);
    expect(saved.bias, card.bias);
    expect(saved.vaccine, card.vaccine);
  });

  testWidgets('a missing AI key shows a Settings hint without blocking cards', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);

    expect(find.byKey(const ValueKey('creator-ai-suggest')), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-ai-unavailable')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-ai-suggest')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-suggest')));
    await pumpFrames(tester, frames: 8);
    expect(
      find.byKey(const ValueKey('creator-ai-unavailable')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Add an AI provider in Settings'),
      findsOneWidget,
    );
  });

  testWidgets('Suggest again retries after an AI error', (tester) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('down', 500);
      return _aiResponse([
        _idea(
          'contrast',
          'Which layer owns IP addresses?',
          'The network layer owns addressing.',
        ),
      ]);
    });
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-ai-suggest')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-suggest')));
    await pumpFrames(tester, frames: 24);

    expect(find.byKey(const ValueKey('creator-ai-error')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-ai-retry')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-retry')));
    await pumpFrames(tester, frames: 24);

    expect(calls, 2);
    expect(find.byKey(const ValueKey('creator-ai-idea-0')), findsOneWidget);
  });
}
