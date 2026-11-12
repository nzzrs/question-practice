import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/errors/error_card_content.dart';
import 'package:question_practice/features/errors/error_card_content_editor_page.dart';
import 'package:question_practice/features/errors/error_cards_review_page.dart';

import '../../helpers/test_harness.dart';

Future<ErrorCard> _seedCard(TestHarness harness) async {
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
    reasoning: 'Reason',
    explanation: 'Original overall explanation.',
    alternativeExplanations: const [
      'Original correct explanation.',
      'Original wrong explanation.',
    ],
    topicName: 'Topic',
    practiceName: 'Practice',
    lastWrongAt: harness.clock.now().toUtc(),
    dueAfter: const Duration(hours: 48),
  );
  await harness.cards.updateErrorCardDetails(
    id: id,
    bias: 'Bias',
    vaccine: 'Rule',
    completedAt: harness.clock.now().toUtc(),
  );
  return (await harness.cards.errorCardById(id))!;
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('error-card-edit-content')));
  await pumpFrames(tester);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await pumpFrames(tester);
  await tester.tap(finder);
  await pumpFrames(tester);
}

Future<void> _enterVisible(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.ensureVisible(finder);
  await pumpFrames(tester);
  await tester.enterText(finder, text);
  await pumpFrames(tester);
}

void main() {
  testWidgets('the editor opens as a page and enables save after an edit', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final card = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [card]),
      harness: harness,
    );
    await _openEditor(tester);

    expect(find.byType(ErrorCardContentEditorPage), findsOneWidget);
    expect(find.byType(M3EDialog), findsNothing);
    expect(find.text('Edit card content'), findsOneWidget);
    final route = ModalRoute.of(
      tester.element(find.byType(ErrorCardContentEditorPage)),
    );
    expect(route, isA<MaterialPageRoute<ErrorCardContent>>());

    M3EButton saveButton() => tester.widget<M3EButton>(
      find.widgetWithText(M3EButton, 'Save changes'),
    );
    expect(saveButton().onPressed, isNull);

    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-question')),
      'Edited question?',
    );
    expect(saveButton().onPressed, isNotNull);

    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-question')),
      '',
    );
    expect(saveButton().onPressed, isNull);
    expect(find.text('Write the question.'), findsOneWidget);
  });

  testWidgets('editing the question, options and explanations persists', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final card = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [card]),
      harness: harness,
    );
    await _openEditor(tester);

    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-question')),
      'Shorter question?',
    );
    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-option-0')),
      'Short correct',
    );
    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-option-1')),
      'Short wrong',
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-error-option-0-explanation-toggle')),
    );
    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-option-0-explanation')),
      'New correct explanation.',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-error-option-1-explanation-toggle')),
    );
    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-option-1-explanation')),
      'New wrong explanation.',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-error-explanation-toggle')),
    );
    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-explanation')),
      'New overall explanation.',
    );

    await _tapVisible(tester, find.text('Save changes'));
    await pumpFrames(tester, frames: 24);

    final saved = await tester.runAsync(
      () => harness.cards.errorCardById(card.id),
    );
    expect(saved, isNotNull);
    expect(saved!.question, 'Shorter question?');
    expect(saved.alternatives, ['Short correct', 'Short wrong']);
    expect(saved.explanation, 'New overall explanation.');
    expect(saved.alternativeExplanations, [
      'New correct explanation.',
      'New wrong explanation.',
    ]);
    expect(saved.questionId, card.questionId);
    expect(saved.correctIndexes, card.correctIndexes);
    expect(saved.wrongIndexes, card.wrongIndexes);
    expect(saved.status, ErrorCardStatus.active);
    expect(saved.bias, 'Bias');
    expect(saved.vaccine, 'Rule');
  });

  testWidgets('cancel discards every editor change', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final card = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [card]),
      harness: harness,
    );
    await _openEditor(tester);

    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-question')),
      'Discard this question',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-error-explanation-toggle')),
    );
    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-explanation')),
      'Discard this explanation',
    );
    await _tapVisible(tester, find.text('Cancel'));
    expect(find.text('Discard changes?'), findsOneWidget);
    await _tapVisible(tester, find.text('Discard'));
    await pumpFrames(tester, frames: 24);

    final unchanged = await tester.runAsync(
      () => harness.cards.errorCardById(card.id),
    );
    expect(unchanged!.question, card.question);
    expect(unchanged.explanation, card.explanation);
    expect(find.byType(ErrorCardContentEditorPage), findsNothing);
    expect(find.text('Discard this question'), findsNothing);
    expect(find.text(card.question), findsOneWidget);
  });

  testWidgets('back asks before discarding unsaved edits', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final card = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [card]),
      harness: harness,
    );
    await _openEditor(tester);

    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-question')),
      'Unsaved rewrite',
    );
    await _tapVisible(tester, find.byIcon(M3EIcons.arrow_back));
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(M3EDialog),
        matching: find.text('Cancel'),
      ),
    );
    await pumpFrames(tester);
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(ErrorCardContentEditorPage), findsOneWidget);
    expect(find.text('Unsaved rewrite'), findsOneWidget);

    await _tapVisible(tester, find.byIcon(M3EIcons.arrow_back));
    await _tapVisible(tester, find.text('Discard'));
    await pumpFrames(tester, frames: 24);

    expect(find.byType(ErrorCardContentEditorPage), findsNothing);
    final unchanged = await tester.runAsync(
      () => harness.cards.errorCardById(card.id),
    );
    expect(unchanged!.question, card.question);
  });

  testWidgets('a field can be shortened with the configured AI provider', (
    tester,
  ) async {
    String? sentBody;
    final client = MockClient((request) async {
      sentBody = request.body;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'Short question?'},
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
    final card = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [card]),
      harness: harness,
    );
    await _openEditor(tester);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-error-question-summarize')),
    );
    await pumpFrames(tester, frames: 24);

    expect(tester.takeException(), isNull);
    expect(find.text('Short question?'), findsOneWidget);
    expect(sentBody, isNotNull);
    expect(sentBody, contains('question'));
  });

  testWidgets(
    'summarizing without a provider shows a message and keeps the form',
    (tester) async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final card = await _seedCard(harness);

      await pumpTestApp(
        tester,
        home: ErrorCardsReviewPage(cards: [card]),
        harness: harness,
      );
      await _openEditor(tester);

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('edit-error-question-summarize')),
      );
      await pumpFrames(tester, frames: 16);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Add an API key'), findsOneWidget);
      final field = tester.widget<M3ETextField>(
        find.byKey(const ValueKey('edit-error-question')),
      );
      expect(field.controller!.text, card.question);
    },
  );

  testWidgets('the editor fits a 360 dp wide phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    addTearDown(harness.close);
    final card = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [card]),
      harness: harness,
    );
    await _openEditor(tester);
    expect(tester.takeException(), isNull);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-error-option-0-explanation-toggle')),
    );
    expect(tester.takeException(), isNull);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('edit-error-explanation-toggle')),
    );
    await _enterVisible(
      tester,
      find.byKey(const ValueKey('edit-error-explanation')),
      'A new overall explanation on a narrow phone.',
    );
    expect(tester.takeException(), isNull);
  });
}
