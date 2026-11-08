import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/lookup/ask_sheet.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('asking about a selection shows the answer and a card action', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': 'It spreads traffic across several servers.',
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

    await pumpTestApp(
      tester,
      home: Scaffold(
        body: AskSheet(
          selection: 'load balancer',
          question: 'Which component spreads requests?',
          topicName: 'Cloud',
          practiceName: 'Core',
          sessionId: null,
          questionId: null,
        ),
      ),
      harness: harness,
    );

    await tester.enterText(
      find.byType(EditableText),
      'What does this do in practice?',
    );
    await tester.tap(find.text('Ask'));
    await pumpFrames(tester, frames: 24);

    expect(
      find.text('It spreads traffic across several servers.'),
      findsOneWidget,
    );
    expect(find.text('Turn into a card'), findsOneWidget);
    expect(find.text('Ask another'), findsOneWidget);
  });
}
