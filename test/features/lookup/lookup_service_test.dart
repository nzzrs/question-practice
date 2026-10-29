import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/web_launcher.dart';
import 'package:question_practice/features/lookup/domain/lookup_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late RecordingWebLauncher launcher;

  setUp(() {
    launcher = RecordingWebLauncher();
    harness = TestHarness(webLauncher: launcher);
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

  Future<void> useAi({String model = 'test-model'}) async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiModel: 'test-model',
        aiBaseUrl: 'https://example.test/v1',
      ),
    );
    await harness.keyStore.writeApiKey('secret-key');
  }

  test('AI lookup parses a JSON definition and saves a concept', () async {
    await useAi();
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer secret-key');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'test-model');
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': '{"definition":"Google Cloud Platform"}'},
            },
          ],
        }),
        200,
      );
    });

    final result = await serviceWith(client).define(
      term: 'GCP',
      question: 'Which platform?',
      topicName: 'Cloud',
      practiceName: 'Core',
      sessionId: null,
      questionId: null,
    );

    expect(result.definition, 'Google Cloud Platform');
    expect(result.source, ConceptSource.ai);
    final concepts = await harness.cards.watchConcepts().first;
    expect(concepts.single.term, 'GCP');
    expect(concepts.single.definition, 'Google Cloud Platform');
  });

  test('AI lookup tolerates fenced JSON', () async {
    await useAi();
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': '```json\n{"definition":"A short answer"}\n```',
              },
            },
          ],
        }),
        200,
      ),
    );

    final result = await serviceWith(client).define(
      term: 'X',
      question: 'Question',
      topicName: 'Topic',
      practiceName: 'Practice',
      sessionId: null,
      questionId: null,
    );
    expect(result.definition, 'A short answer');
  });

  test('rejected API key offers web fallback', () async {
    await useAi();
    final client = MockClient((request) async => http.Response('no', 401));

    await expectLater(
      serviceWith(client).define(
        term: 'X',
        question: 'Question',
        topicName: 'Topic',
        practiceName: 'Practice',
        sessionId: null,
        questionId: null,
      ),
      throwsA(
        isA<LookupException>().having(
          (error) => error.canUseWeb,
          'canUseWeb',
          isTrue,
        ),
      ),
    );
    expect(await harness.cards.watchConcepts().first, isEmpty);
  });

  test('missing API key fails before any network call', () async {
    await harness.settings.save(
      const AppSettings(lookupMode: LookupMode.ai, aiModel: 'test-model'),
    );
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });

    await expectLater(
      serviceWith(client).define(
        term: 'X',
        question: 'Question',
        topicName: 'Topic',
        practiceName: 'Practice',
        sessionId: null,
        questionId: null,
      ),
      throwsA(isA<LookupException>()),
    );
    expect(called, isFalse);
  });

  test('web lookup opens the chosen engine and saves a concept', () async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.web,
        webEngine: WebEngine.wikipedia,
      ),
    );

    final result =
        await serviceWith(MockClient((_) async => http.Response('', 500)))
            .define(
              term: 'TCP/IP',
              question: 'Question',
              topicName: 'Networking',
              practiceName: 'Basics',
              sessionId: null,
              questionId: null,
            );

    expect(result.openedWeb, isTrue);
    expect(launcher.opened.single.host, 'en.wikipedia.org');
    expect(launcher.opened.single.queryParameters['search'], 'TCP/IP');
    final concepts = await harness.cards.watchConcepts().first;
    expect(concepts.single.source, ConceptSource.web);
    expect(concepts.single.needsDefinition, isTrue);
  });

  test('missing AI model is reported clearly', () async {
    await harness.settings.save(
      const AppSettings(lookupMode: LookupMode.ai, aiModel: ''),
    );
    await harness.keyStore.writeApiKey('key');

    await expectLater(
      serviceWith(MockClient((_) async => http.Response('{}', 200))).define(
        term: 'X',
        question: 'Question',
        topicName: 'Topic',
        practiceName: 'Practice',
        sessionId: null,
        questionId: null,
      ),
      throwsA(
        isA<LookupException>().having(
          (error) => error.message,
          'message',
          contains('model'),
        ),
      ),
    );
  });
}
