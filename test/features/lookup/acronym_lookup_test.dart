import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/lookup/domain/lookup_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() {
    harness = TestHarness();
  });

  tearDown(() async {
    await harness.close();
  });

  LookupService serviceWith(http.Client client) {
    return LookupService(
      client: client,
      settings: harness.settings,
      keyStore: harness.keyStore,
      webLauncher: harness.webLauncher,
      cards: harness.cards,
      clock: harness.clock,
    );
  }

  Future<void> useAi() async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiModel: 'test-model',
        aiBaseUrl: 'https://example.test/v1',
      ),
    );
    await harness.keyStore.writeApiKey('secret-key');
  }

  test('acronym lookup keeps the meaning and the full form apart', () async {
    await useAi();
    String? systemPrompt;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      systemPrompt =
          (messages.first as Map<String, dynamic>)['content'] as String;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'definition':
                      'Discipline that uses software engineering principles '
                      'to automate operations and improve reliability.',
                  'expansion': 'Site Reliability Engineering',
                }),
              },
            },
          ],
        }),
        200,
      );
    });

    final result = await serviceWith(client).define(
      term: 'SRE',
      question: 'What does SRE automate?',
      topicName: 'Operations',
      practiceName: 'Reliability',
      sessionId: null,
      questionId: null,
    );

    expect(
      result.definition,
      'Discipline that uses software engineering principles '
      'to automate operations and improve reliability.',
    );
    expect(result.extra, 'Site Reliability Engineering');
    expect(result.definition, isNot(contains('Site Reliability')));

    final concepts = await harness.cards.watchConcepts().first;
    expect(concepts.single.definition, result.definition);
    expect(concepts.single.extra, 'Site Reliability Engineering');

    final prompt = systemPrompt!.toLowerCase();
    expect(prompt, contains('acronym'));
    expect(prompt, contains('dictionary'));
    expect(prompt, contains('never spell out'));
  });

  test('ordinary terms do not keep an expansion in the extra field', () async {
    await useAi();
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'definition': 'A managed container runtime.',
                  'expansion': 'Should be ignored',
                }),
              },
            },
          ],
        }),
        200,
      ),
    );

    final result = await serviceWith(client).define(
      term: 'Cloud Run',
      question: 'Which service?',
      topicName: 'Cloud',
      practiceName: 'Core',
      sessionId: null,
      questionId: null,
    );

    expect(result.definition, 'A managed container runtime.');
    expect(result.extra, isEmpty);
    final concepts = await harness.cards.watchConcepts().first;
    expect(concepts.single.extra, isEmpty);
  });
}
