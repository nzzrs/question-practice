import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/errors/error_cards_review_page.dart';
import 'package:question_practice/features/export/cards_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<ErrorCard> createError(
    TestHarness harness, {
    required Question question,
    bool completed = false,
  }) async {
    final id = await harness.cards.createErrorCard(
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
      subtopic: 'Sub',
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    if (completed) {
      await harness.cards.completeErrorCardDetails(
        id,
        harness.clock.now().toUtc(),
      );
    }
    return (await harness.cards.errorCardById(id))!;
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

  testWidgets('cards review opens full screen with a clear exit', (
    tester,
  ) async {
    final recorder = SystemUiCallRecorder()..install();
    addTearDown(recorder.dispose);
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    await createError(harness, question: question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    await tester.tap(find.text('Review all'));
    await pumpFrames(tester);

    expect(find.byType(ErrorCardsReviewPage), findsOneWidget);
    final route = ModalRoute.of(
      tester.element(find.byType(ErrorCardsReviewPage)),
    );
    expect(route, isA<MaterialPageRoute<bool>>());
    expect((route as MaterialPageRoute<bool>).fullscreenDialog, isTrue);
    expect(find.byType(M3EAppBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('app-focus-header')), findsOneWidget);
    expect(recorder.modes, contains('SystemUiMode.immersiveSticky'));

    final pageSize = tester.getSize(find.byType(ErrorCardsReviewPage));
    expect(
      pageSize.width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );

    await tester.tap(find.byKey(const ValueKey('app-focus-exit')));
    await pumpFrames(tester);

    expect(find.byType(ErrorCardsReviewPage), findsNothing);
    expect(find.text('Cards'), findsOneWidget);
    expect(recorder.modes.last, 'SystemUiMode.edgeToEdge');
  });

  testWidgets(
    'leaving the completion screen reports success and restores bars',
    (tester) async {
      final recorder = SystemUiCallRecorder()..install();
      addTearDown(recorder.dispose);
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await harness.seedPractice(count: 1);
      final question = (await harness.practices.questionsForPractice(
        seeded.practiceId,
      )).single;
      await createError(harness, question: question, completed: true);

      await pumpTestApp(tester, home: const CardsPage(), harness: harness);
      expect(find.text('Review selected'), findsOneWidget);
      await tester.tap(find.text('Review all'));
      await pumpFrames(tester);

      await tester.tap(find.text('Skip'));
      await pumpFrames(tester);
      expect(find.text('Review complete'), findsWidgets);

      // The Android back gesture leaves the completion screen as a success too.
      await tester.binding.handlePopRoute();
      await pumpFrames(tester);

      expect(find.byType(ErrorCardsReviewPage), findsNothing);
      // A completed review clears the selection, so only Review all remains.
      expect(find.text('Review selected'), findsNothing);
      expect(recorder.modes.last, 'SystemUiMode.edgeToEdge');
    },
  );

  testWidgets('adding atomic cards completes the error and advances', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => aiResponse([
        {
          'type': 'contrast',
          'front': 'Which layer owns IP addresses?',
          'back': 'The network layer owns addressing.',
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
    final seeded = await harness.seedPractice(count: 2);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final first = await createError(harness, question: questions[0]);
    final second = await createError(harness, question: questions[1]);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [first, second]),
      harness: harness,
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

    expect(find.text('Item 2 of 2'), findsOneWidget);
    final completed = await tester.runAsync(
      () => harness.cards.errorCardById(first.id),
    );
    expect(completed!.needsDetails, isFalse);
    final untouched = await tester.runAsync(
      () => harness.cards.errorCardById(second.id),
    );
    expect(untouched!.needsDetails, isTrue);
    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
    expect(cards!.single.subtopic, 'Sub');
    expect(cards.single.cognitiveType, CognitiveType.contrast);
  });
}
