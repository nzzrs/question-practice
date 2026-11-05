import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/lookup/lookup_sheet.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('the AI definition bubble also shows the acronym expansion', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'definition':
                      'Discipline that uses software engineering principles '
                      'to automate operations and improve system reliability.',
                  'expansion': 'Site Reliability Engineering',
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

    await pumpTestApp(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: M3EButton.filled(
              onPressed: () => showAiDefinitionBubble(
                context,
                term: 'SRE',
                question: 'What does SRE automate?',
                topicName: 'Operations',
                practiceName: 'Reliability',
                sessionId: null,
                questionId: null,
              ),
              child: const Text('Define'),
            ),
          ),
        ),
      ),
      harness: harness,
    );

    await tester.tap(find.text('Define'));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Site Reliability Engineering'), findsOneWidget);
    expect(
      find.text(
        'Discipline that uses software engineering principles '
        'to automate operations and improve system reliability.',
      ),
      findsOneWidget,
    );
    expect(find.text('Stands for'), findsOneWidget);
  });
}
