import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/app_sections.dart';
import 'package:question_practice/features/errors/error_card_review_view.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';

import '../../helpers/test_harness.dart';

const _aiSettings = AppSettings(
  lookupMode: LookupMode.ai,
  aiModel: 'test-model',
  aiBaseUrl: 'https://example.test/v1',
);

http.Response _aiResponse(List<Map<String, String>> cards) {
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
  await pumpTestApp(
    tester,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ErrorCardReviewView(card: card, onCardsAdded: onCardsAdded),
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

    expect(find.text('Wrong answer chosen'), findsOneWidget);
    expect(find.text('Right answer discarded'), findsOneWidget);
    expect(find.text('Your reasoning'), findsOneWidget);
    expect(find.text('Network layer'), findsOneWidget);
    expect(find.text('Why this answer'), findsOneWidget);
    expect(find.text('Check with AI'), findsNothing);
    expect(find.text('Flawed assumption (bias)'), findsNothing);
    expect(find.text('Vaccine (rule / protocol)'), findsNothing);
    expect(find.byKey(const ValueKey('error-card-reading-time')), findsNothing);
    expect(find.byKey(const ValueKey('error-create-cards')), findsOneWidget);
    expect(find.text('Create cards'), findsOneWidget);
  });

  testWidgets('manual error cards work without an AI provider', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);
    await tester.ensureVisible(
      find.byKey(const ValueKey('error-create-cards')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('error-create-cards')));
    await pumpFrames(tester);

    expect(find.byType(CardCreatorSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('error-create-cards')), findsOneWidget);
    final context = find.byKey(const ValueKey('creator-context'));
    expect(
      find.descendant(of: context, matching: find.text('Wrong answer chosen')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: context, matching: find.text('Wrong 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: context, matching: find.text('Correct answer')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: context, matching: find.text('Correct 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: context,
        matching: find.text('Confusion between 2 options'),
      ),
      findsOneWidget,
    );
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
    await tester.ensureVisible(find.byKey(const ValueKey('creator-save')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-save')));
    await pumpFrames(tester, frames: 24);

    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
    expect(cards!.single.cognitiveType, CognitiveType.fact);
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
        {
          'type': 'contrast',
          'front': 'Which layer owns IP addresses?',
          'back': 'The network layer owns addressing.',
        },
        {
          'type': 'heuristic',
          'front': 'Given requirement X with restriction Y, what rule applies?',
          'back': 'Match the layer to its addressing job.',
        },
      ]);
    });
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);
    await tester.ensureVisible(
      find.byKey(const ValueKey('error-create-cards')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('error-create-cards')));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
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
        of: find.byKey(const ValueKey('creator-ai-litmus-0')),
        matching: find.byType(Pill),
      ),
    );
    expect(ready.label, 'Ready');
    expect(ready.tone, PillTone.success);
    expect(
      tester
          .widget<Pill>(find.byKey(const ValueKey('creator-ai-type-1')))
          .label,
      'Heuristic',
    );
    expect(
      find.textContaining(
        'Given requirement X with restriction Y, what rule applies?',
      ),
      findsWidgets,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('creator-ai-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-add')));
    await pumpFrames(tester);
    expect(find.text('Save 2 cards'), findsOneWidget);
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
        {
          'type': 'heuristic',
          'front': 'Is a managed service the right choice here?',
          'back': 'A managed service removes host maintenance.',
        },
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);
    await tester.ensureVisible(
      find.byKey(const ValueKey('error-create-cards')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('error-create-cards')));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-ai-suggest')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-ai-suggest')));
    await pumpFrames(tester, frames: 24);

    expect(find.byKey(const ValueKey('creator-ai-0')), findsOneWidget);
    final badge = tester.widget<Pill>(
      find.descendant(
        of: find.byKey(const ValueKey('creator-ai-litmus-0')),
        matching: find.byType(Pill),
      ),
    );
    expect(badge.label, 'Check quality');
    expect(badge.tone, PillTone.error);
    final detail = tester.widget<Text>(
      find.byKey(const ValueKey('creator-ai-litmus-detail-0')),
    );
    expect(detail.data, contains('Can be answered with yes or no'));
    expect(
      detail.data,
      contains('Heuristic front does not use the rule template'),
    );
  });

  testWidgets('adding selected cards saves them and completes the error', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => _aiResponse([
        {
          'type': 'contrast',
          'front': 'Which layer owns IP addresses?',
          'back': 'The network layer owns addressing.',
        },
        {
          'type': 'heuristic',
          'front': 'Given requirement X with restriction Y, what rule applies?',
          'back': 'Match the layer to its addressing job.',
        },
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
      find.byKey(const ValueKey('error-create-cards')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('error-create-cards')));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('error-create-cards')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('error-create-cards')));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);

    expect(find.byKey(const ValueKey('creator-ai-suggest')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-ai-unavailable')),
    );
    await pumpFrames(tester);
    expect(find.textContaining('Add an API key in Settings'), findsOneWidget);
  });

  testWidgets('Try again retries after an AI error', (tester) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('down', 500);
      return _aiResponse([
        {
          'type': 'contrast',
          'front': 'Which layer owns IP addresses?',
          'back': 'The network layer owns addressing.',
        },
      ]);
    });
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final card = await _createError(harness);

    await _pumpView(tester, harness, card);
    await tester.ensureVisible(
      find.byKey(const ValueKey('error-create-cards')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('error-create-cards')));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
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
    expect(find.byKey(const ValueKey('creator-ai-0')), findsOneWidget);
  });
}
