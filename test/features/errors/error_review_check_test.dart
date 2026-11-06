import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/errors/error_card_review_view.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('error review can ask the AI to check the written notes', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'consistent': true,
                  'feedback':
                      'The assumption and the prevention rule match the error.',
                  'bias': 'Confused the two similar terms.',
                  'vaccine': 'Check the definition before choosing.',
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
      reasoning: '',
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      topicName: 'Topic',
      practiceName: 'Practice',
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    final card = (await harness.cards.errorCardById(id))!;
    final bias = TextEditingController(
      text: 'I assumed both alternatives meant the same thing.',
    );
    final vaccine = TextEditingController(
      text: 'Read what the question asks before comparing alternatives.',
    );
    addTearDown(bias.dispose);
    addTearDown(vaccine.dispose);

    await pumpTestApp(
      tester,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ErrorCardReviewView(card: card, bias: bias, vaccine: vaccine),
        ),
      ),
      harness: harness,
    );

    await tester.ensureVisible(find.text('Check with AI'));
    await tester.tap(find.text('Check with AI'));
    await pumpFrames(tester, frames: 24);

    expect(
      find.textContaining('The assumption and the prevention rule match'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('error-review-suggestions')),
      findsOneWidget,
    );
    expect(find.text('Confused the two similar terms.'), findsOneWidget);
    expect(find.text('Check the definition before choosing.'), findsOneWidget);

    await tester.ensureVisible(find.text('Use').first);
    await tester.tap(find.text('Use').first);
    await tester.pump();
    expect(bias.text, 'Confused the two similar terms.');
  });
}
