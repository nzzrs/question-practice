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
              'message': {
                'content': jsonEncode({
                  'definition': 'A managed cloud computing platform.',
                  'expansion': 'Google Cloud Platform',
                }),
              },
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

    expect(result.definition, 'A managed cloud computing platform.');
    expect(result.extra, 'Google Cloud Platform');
    expect(result.source, ConceptSource.ai);
    final concepts = await harness.cards.watchConcepts().first;
    expect(concepts.single.term, 'GCP');
    expect(concepts.single.definition, 'A managed cloud computing platform.');
    expect(concepts.single.extra, 'Google Cloud Platform');
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

  test('Gemini lookup uses generateContent and parses candidates', () async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiProvider: AiProvider.gemini,
        aiBaseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        aiModel: 'gemini-test',
      ),
    );
    await harness.keyStore.writeApiKey('gemini-key');
    final client = MockClient((request) async {
      expect(request.url.path, '/v1beta/models/gemini-test:generateContent');
      expect(request.url.queryParameters['key'], 'gemini-key');
      expect(request.headers['Authorization'], isNull);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['generationConfig'], isA<Map<String, dynamic>>());
      expect(body['contents'], isA<List<dynamic>>());
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '{"definition":"Managed container platform"}'},
                ],
              },
            },
          ],
        }),
        200,
      );
    });

    final result = await serviceWith(client).define(
      term: 'Cloud Run',
      question: 'Which service?',
      topicName: 'Cloud',
      practiceName: 'Core',
      sessionId: null,
      questionId: null,
    );

    expect(result.definition, 'Managed container platform');
    expect(result.source, ConceptSource.ai);
  });

  test('lists Gemini models that support generateContent', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1beta/models');
      expect(request.url.queryParameters['key'], 'gemini-key');
      return http.Response(
        jsonEncode({
          'models': [
            {
              'name': 'models/gemini-z',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/text-embedding',
              'supportedGenerationMethods': ['embedContent'],
            },
            {
              'name': 'models/gemini-a',
              'supportedGenerationMethods': ['generateContent', 'countTokens'],
            },
          ],
        }),
        200,
      );
    });

    final models = await serviceWith(client).listModels(
      provider: AiProvider.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      apiKey: 'gemini-key',
    );

    expect(models, ['gemini-a', 'gemini-z']);
  });

  test('lists OpenAI-compatible models from data ids', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/models');
      expect(request.headers['Authorization'], 'Bearer secret-key');
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 'b-model'},
            {'id': 'a-model'},
          ],
        }),
        200,
      );
    });

    final models = await serviceWith(client).listModels(
      provider: AiProvider.openai,
      baseUrl: 'https://example.test/v1',
      apiKey: 'secret-key',
    );

    expect(models, ['a-model', 'b-model']);
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

  test(
    'AI review check sends the error notes and parses the verdict',
    () async {
      await useAi();
      String? userPrompt;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        userPrompt =
            (messages.last as Map<String, dynamic>)['content'] as String;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'consistent': false,
                    'feedback': 'The prevention note restates the bias instead of naming a check.',
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final result = await serviceWith(client).checkErrorNotes(
        question: 'Which storage class?',
        correctAnswer: 'Coldline',
        wrongAnswer: 'Standard',
        reasoning: 'All storage classes looked the same to me.',
        bias: 'I assumed all storage classes cost the same.',
        vaccine: 'Remember that storage classes differ in price.',
      );

      expect(result.consistent, isFalse);
      expect(result.feedback, contains('restates the bias'));
      expect(
        userPrompt,
        contains('I assumed all storage classes cost the same.'),
      );
      expect(
        userPrompt,
        contains('Remember that storage classes differ in price.'),
      );
      expect(userPrompt, contains('Coldline'));
    },
  );

  test(
    'AI review check sends the learner reasoning and returns short suggestions',
    () async {
      await useAi();
      String? userPrompt;
      String? systemPrompt;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        systemPrompt =
            (messages.first as Map<String, dynamic>)['content'] as String;
        userPrompt =
            (messages.last as Map<String, dynamic>)['content'] as String;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'consistent': false,
                    'feedback': 'The note does not address the mix-up.',
                    'bias': 'Confused the cold tier with the standard tier.',
                    'vaccine': 'Check the tier before comparing prices.',
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final result = await serviceWith(client).checkErrorNotes(
        question: 'Which storage class?',
        correctAnswer: 'Coldline',
        wrongAnswer: 'Standard',
        reasoning: 'I thought the cheapest class was the cold one.',
        bias: 'I read the price table backwards.',
        vaccine: 'Read the table again.',
      );

      expect(result.consistent, isFalse);
      expect(result.biasSuggestion, contains('cold tier'));
      expect(result.vaccineSuggestion, contains('tier'));
      expect(userPrompt, contains('Chosen wrong answer: Standard'));
      expect(userPrompt, contains('Learner reasoning: I thought the cheapest'));
      expect(systemPrompt, contains('learner'));
      expect(systemPrompt, contains('one-phrase'));
    },
  );

  test('ask sends the passage and the learner message as plain text', () async {
    await useAi();
    String? userPrompt;
    String? systemPrompt;
    Map<String, dynamic>? requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      final messages = requestBody!['messages'] as List<dynamic>;
      systemPrompt =
          (messages.first as Map<String, dynamic>)['content'] as String;
      userPrompt = (messages.last as Map<String, dynamic>)['content'] as String;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': 'It distributes traffic across several backends.',
              },
            },
          ],
        }),
        200,
      );
    });

    final answer = await serviceWith(client).ask(
      selection: 'load balancer',
      question: 'Which component spreads requests?',
      topicName: 'Cloud',
      userQuestion: 'What does this do in practice?',
    );

    expect(answer, 'It distributes traffic across several backends.');
    expect(userPrompt, contains('Highlighted passage: load balancer'));
    expect(
      userPrompt,
      contains('Learner question: What does this do in practice?'),
    );
    expect(
      userPrompt,
      contains('Question context: Which component spreads requests?'),
    );
    expect(systemPrompt, contains('highlighted passage'));
    expect(requestBody!.containsKey('response_format'), isFalse);
  });

  test('ask needs a saved API key', () async {
    await harness.settings.save(
      const AppSettings(lookupMode: LookupMode.ai, aiModel: 'test-model'),
    );

    await expectLater(
      serviceWith(MockClient((_) async => http.Response('{}', 200))).ask(
        selection: 'term',
        question: 'Question',
        topicName: 'Topic',
        userQuestion: 'Why?',
      ),
      throwsA(isA<LookupException>()),
    );
  });

  test('AI review check needs a saved API key', () async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiModel: 'test-model',
        aiBaseUrl: 'https://example.test/v1',
      ),
    );

    await expectLater(
      serviceWith(MockClient((_) async => http.Response('{}', 200)))
          .checkErrorNotes(
            question: 'Question',
            correctAnswer: 'Answer',
            wrongAnswer: 'Wrong',
            reasoning: 'Reason',
            bias: 'Bias',
            vaccine: 'Vaccine',
          ),
      throwsA(isA<LookupException>()),
    );
  });
}
