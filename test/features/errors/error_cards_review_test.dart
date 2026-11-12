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
    String? bias,
    String? vaccine,
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
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    if (bias != null && vaccine != null) {
      await harness.cards.updateErrorCardDetails(
        id: id,
        bias: bias,
        vaccine: vaccine,
        completedAt: harness.clock.now().toUtc(),
      );
    }
    return (await harness.cards.errorCardById(id))!;
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
      await createError(
        harness,
        question: question,
        bias: 'Bias',
        vaccine: 'Rule',
      );

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

  testWidgets('the AI check belongs to its card, not the review page', (
    tester,
  ) async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final feedback = calls == 1
          ? 'First card verdict.'
          : 'Second card verdict.';
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'consistent': true,
                  'feedback': feedback,
                  'bias': '',
                  'vaccine': '',
                }),
              },
            },
          ],
        }),
        200,
      );
    });
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
    final first = await createError(
      harness,
      question: questions[0],
      bias: 'First bias',
      vaccine: 'First rule',
    );
    final second = await createError(
      harness,
      question: questions[1],
      bias: 'Second bias',
      vaccine: 'Second rule',
    );

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [first, second]),
      harness: harness,
    );

    await tester.ensureVisible(find.text('Check with AI'));
    await pumpFrames(tester);
    await tester.tap(find.text('Check with AI'));
    await pumpFrames(tester, frames: 24);
    expect(find.text('First card verdict.'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await pumpFrames(tester);
    expect(find.text('Item 2 of 2'), findsOneWidget);
    expect(find.text('First card verdict.'), findsNothing);

    await tester.ensureVisible(find.text('Check with AI'));
    await pumpFrames(tester);
    await tester.tap(find.text('Check with AI'));
    await pumpFrames(tester, frames: 24);
    expect(find.text('Second card verdict.'), findsOneWidget);
    expect(find.text('First card verdict.'), findsNothing);

    await tester.tap(find.text('Previous'));
    await pumpFrames(tester);
    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.text('First card verdict.'), findsOneWidget);
    expect(find.text('Second card verdict.'), findsNothing);
  });

  testWidgets('the question and options can be shortened before saving', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    final card = await createError(
      harness,
      question: question,
      bias: 'Bias',
      vaccine: 'Rule',
    );

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [card]),
      harness: harness,
    );

    await tester.tap(find.byKey(const ValueKey('error-card-edit-content')));
    await pumpFrames(tester);
    expect(find.text('Edit card content'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit-error-question')),
      'Shorter question?',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-error-option-0')),
      'Short correct',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-error-option-1')),
      'Short wrong',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await pumpFrames(tester);

    expect(find.text('Shorter question?'), findsOneWidget);
    expect(find.text('Short wrong'), findsWidgets);
    expect(find.text('Short correct'), findsWidgets);

    final saved = await tester.runAsync(
      () => harness.cards.errorCardById(card.id),
    );
    expect(saved!.question, 'Shorter question?');
    expect(saved.alternatives, ['Short correct', 'Short wrong']);
    expect(saved.questionId, card.questionId);
    expect(saved.correctIndexes, card.correctIndexes);
    expect(saved.wrongIndexes, card.wrongIndexes);
  });
}
