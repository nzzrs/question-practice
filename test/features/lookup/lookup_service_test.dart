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
    expect(userPrompt, contains('Selected passage: load balancer'));
    expect(
      userPrompt,
      contains('Learner question: What does this do in practice?'),
    );
    expect(
      userPrompt,
      contains('Question context: Which component spreads requests?'),
    );
    expect(systemPrompt, contains('selected passage'));
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

  test('AI summarize rewrites a card field without JSON mode', () async {
    await useAi();
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      final system =
          (messages.first as Map<String, dynamic>)['content'] as String;
      final user = (messages.last as Map<String, dynamic>)['content'] as String;
      expect(system, contains('shorten'));
      expect(
        user,
        contains('Original question: A very long imported question?'),
      );
      expect(user, contains('Question context: Which one?'));
      expect(body.containsKey('response_format'), isFalse);
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': '  A shorter question?  '},
            },
          ],
        }),
        200,
      );
    });

    final summary = await serviceWith(client).summarizeText(
      text: 'A very long imported question?',
      fieldLabel: 'question',
      question: 'Which one?',
    );

    expect(summary, 'A shorter question?');
  });

  test('AI summarize needs a saved API key', () async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiModel: 'test-model',
        aiBaseUrl: 'https://example.test/v1',
      ),
    );

    await expectLater(
      serviceWith(MockClient((_) async => http.Response('{}', 200)))
          .summarizeText(text: 'Long text', fieldLabel: 'answer'),
      throwsA(
        isA<LookupException>().having(
          (error) => error.message,
          'message',
          contains('Add an API key'),
        ),
      ),
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

  test('AI card suggestions send the note context and parse ideas', () async {
    await useAi();
    String? userPrompt;
    String? systemPrompt;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      systemPrompt =
          (messages.first as Map<String, dynamic>)['content'] as String;
      userPrompt = (messages.last as Map<String, dynamic>)['content'] as String;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'ideas': [
                    {
                      'template': 'mechanism',
                      'variants': [
                        {
                          'front': '  What is a VPC?  ',
                          'back': ' A private network ',
                        },
                        {
                          'front': 'How is a VPC described?',
                          'back': 'A private network.',
                        },
                      ],
                    },
                    {
                      'template': 'contrast',
                      'variants': [
                        {'front': 'Who owns it?', 'back': 'The account owner'},
                      ],
                    },
                  ],
                }),
              },
            },
          ],
        }),
        200,
      );
    });

    final ideas = await serviceWith(client).suggestArchetypeCards(
      note: 'A VPC is a private network owned by the account.',
      questionContext: 'Which network isolates resources?',
      topicName: 'Cloud',
    );

    expect(ideas, hasLength(2));
    expect(ideas.first.template, CardTemplate.mechanism);
    expect(ideas.first.variants, hasLength(2));
    expect(ideas.first.variants.first.front, 'What is a VPC?');
    expect(ideas.first.variants.first.back, 'A private network');
    expect(ideas.first.variants.last.variantIndex, 1);
    expect(
      userPrompt,
      contains(
        'Selected passage: A VPC is a private network owned by the account.',
      ),
    );
    expect(
      userPrompt,
      contains('Question context: Which network isolates resources?'),
    );
    expect(userPrompt, contains('Topic: Cloud'));
    expect(systemPrompt, contains('atomic'));
    expect(systemPrompt, contains('Front <= 30 words'));
    expect(systemPrompt, contains('Never put the topic or subtopic inside'));
  });

  test('AI card suggestions tolerate fenced JSON', () async {
    await useAi();
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content':
                    '```json\n{"ideas":[{"template":"mechanism",'
                    '"variants":[{"front":"Term","back":"Meaning"}]}]}\n```',
              },
            },
          ],
        }),
        200,
      ),
    );

    final ideas = await serviceWith(client).suggestArchetypeCards(
      note: 'Term means meaning.',
      questionContext: '',
      topicName: '',
    );

    expect(ideas, hasLength(1));
    expect(ideas.single.variants.single.front, 'Term');
    expect(ideas.single.variants.single.back, 'Meaning');
  });

  test('AI card suggestions cap at three ideas and three variants', () async {
    await useAi();
    final ideasJson = [
      for (var idea = 0; idea < 5; idea++)
        {
          'template': 'mechanism',
          'variants': [
            for (var variant = 0; variant < 5; variant++)
              {
                'front': 'Idea $idea variant $variant',
                'back': 'Answer $idea $variant',
              },
          ],
        },
    ];
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({'ideas': ideasJson}),
              },
            },
          ],
        }),
        200,
      ),
    );

    final ideas = await serviceWith(client).suggestArchetypeCards(
      note: 'Note',
      questionContext: 'Question',
      topicName: 'Topic',
    );

    expect(ideas, hasLength(3));
    expect(ideas.every((idea) => idea.variants.length == 3), isTrue);
    expect(ideas.last.variants.last.front, 'Idea 2 variant 2');
  });

  test(
    'AI card suggestions deduplicate variants and skip empty variants',
    () async {
      await useAi();
      final payload = {
        'ideas': [
          {
            'template': 'contrast',
            'variants': [
              {'front': 'A', 'back': 'One'},
              {'front': 'a', 'back': 'One again'},
              {'front': ' ', 'back': 'Empty front'},
              {'front': 'B', 'back': '  '},
              {'front': 'C', 'back': 'Three'},
            ],
          },
        ],
      };
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': jsonEncode(payload)},
              },
            ],
          }),
          200,
        ),
      );

      final ideas = await serviceWith(client).suggestArchetypeCards(
        note: 'Note',
        questionContext: 'Question',
        topicName: 'Topic',
      );

      expect(ideas, hasLength(1));
      expect(ideas.single.variants.map((variant) => variant.front), ['A', 'C']);
      expect(ideas.single.variants.map((variant) => variant.variantIndex), [
        0,
        1,
      ]);
    },
  );

  test(
    'AI card suggestions accept legacy flat cards as one-variant ideas',
    () async {
      await useAi();
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'cards': [
                      {'type': 'fact', 'front': 'A', 'back': 'One'},
                      {'type': 'heuristic', 'front': 'B', 'back': 'Two'},
                      {'type': 'unknown', 'front': 'C', 'back': 'Three'},
                    ],
                  }),
                },
              },
            ],
          }),
          200,
        ),
      );

      final ideas = await serviceWith(client).suggestArchetypeCards(
        note: 'Note',
        questionContext: 'Question',
        topicName: 'Topic',
      );

      expect(ideas, hasLength(2));
      expect(ideas.first.template, CardTemplate.mechanism);
      expect(ideas.first.variants.single.front, 'A');
      expect(ideas.last.template, CardTemplate.heuristic);
    },
  );

  test(
    'breakdown error card keeps only contrast and heuristic ideas',
    () async {
      await useAi();
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'ideas': [
                      {
                        'template': 'definition',
                        'variants': [
                          {'front': 'VPC', 'back': 'A private network.'},
                        ],
                      },
                      {
                        'template': 'mechanism',
                        'variants': [
                          {'front': 'Why?', 'back': 'Because.'},
                        ],
                      },
                      {
                        'template': 'contrast',
                        'variants': [
                          {'front': 'A or B?', 'back': 'A, because of size.'},
                        ],
                      },
                      {
                        'template': 'heuristic',
                        'variants': [
                          {
                            'front':
                                'If a scenario asks X but restricts with Y, '
                                'which option is always discarded?',
                            'back': 'Discard Z because rule.',
                          },
                        ],
                      },
                    ],
                  }),
                },
              },
            ],
          }),
          200,
        ),
      );

      final ideas = await serviceWith(client).breakdownErrorCard(
        question: 'Question',
        wrongAnswer: 'Wrong',
        correctAnswer: 'Correct',
        reasoning: 'Reason',
        explanation: 'Explanation',
        topicName: 'Topic',
      );

      expect(ideas, hasLength(2));
      expect(ideas.map((idea) => idea.template), [
        CardTemplate.contrast,
        CardTemplate.heuristic,
      ]);
    },
  );

  test('breakdown error card caps at two ideas and three variants', () async {
    await useAi();
    final payload = {
      'ideas': [
        for (var idea = 0; idea < 4; idea++)
          {
            'template': idea.isEven ? 'contrast' : 'heuristic',
            'variants': [
              for (var variant = 0; variant < 4; variant++)
                {
                  'front': 'Idea $idea variant $variant',
                  'back': 'Answer $idea $variant',
                },
            ],
          },
      ],
    };
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': jsonEncode(payload)},
            },
          ],
        }),
        200,
      ),
    );

    final ideas = await serviceWith(client).breakdownErrorCard(
      question: 'Question',
      wrongAnswer: 'Wrong',
      correctAnswer: 'Correct',
      reasoning: 'Reason',
      explanation: 'Explanation',
      topicName: 'Topic',
    );

    expect(ideas, hasLength(2));
    expect(ideas.every((idea) => idea.variants.length == 3), isTrue);
  });

  test('invalid AI JSON throws the existing error message', () async {
    await useAi();
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'not json'},
            },
          ],
        }),
        200,
      ),
    );

    await expectLater(
      serviceWith(client).suggestArchetypeCards(
        note: 'Note',
        questionContext: 'Question',
        topicName: 'Topic',
      ),
      throwsA(
        isA<LookupException>().having(
          (error) => error.message,
          'message',
          'The AI returned invalid card suggestions. Try again.',
        ),
      ),
    );
  });

  test(
    'resolveDefinition returns a definition without saving a concept',
    () async {
      await useAi();
      String? termPrompt;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List<dynamic>;
        termPrompt =
            (messages.last as Map<String, dynamic>)['content'] as String;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'definition': 'A private network.',
                    'expansion': 'Virtual Private Cloud',
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final suggestion = await serviceWith(client).resolveDefinition(
        term: 'VPC',
        question: 'Which network?',
        topicName: 'Cloud',
      );

      expect(suggestion.definition, 'A private network.');
      expect(suggestion.extra, 'Virtual Private Cloud');
      expect(termPrompt, contains('Term: VPC'));
      expect(await harness.cards.watchConcepts().first, isEmpty);
    },
  );

  test(
    'resolveDefinition reports no provider without a key or in web mode',
    () async {
      await harness.settings.save(
        const AppSettings(lookupMode: LookupMode.ai, aiModel: 'test-model'),
      );
      final noKey = serviceWith(
        MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        noKey.resolveDefinition(
          term: 'VPC',
          question: 'Question',
          topicName: 'Topic',
        ),
        throwsA(
          isA<LookupException>().having(
            (error) => error.failure,
            'failure',
            LookupFailure.noProvider,
          ),
        ),
      );

      await harness.settings.save(
        const AppSettings(lookupMode: LookupMode.web),
      );
      await harness.keyStore.writeApiKey('secret-key');
      await expectLater(
        serviceWith(MockClient((_) async => http.Response('{}', 200)))
            .resolveDefinition(
              term: 'VPC',
              question: 'Question',
              topicName: 'Topic',
            ),
        throwsA(
          isA<LookupException>().having(
            (error) => error.failure,
            'failure',
            LookupFailure.noProvider,
          ),
        ),
      );
    },
  );

  test(
    'latestConceptForTerm prefers the newest non-empty definition',
    () async {
      final older = await harness.cards.createConcept(
        sessionId: null,
        questionId: null,
        term: 'VPC',
        definition: 'Older meaning.',
        context: 'Context',
        topicName: 'Cloud',
        source: ConceptSource.manual,
        createdAt: harness.clock.now().toUtc().subtract(
          const Duration(days: 1),
        ),
      );
      harness.clock.advance(const Duration(days: 1));
      final newer = await harness.cards.createConcept(
        sessionId: null,
        questionId: null,
        term: 'vpc',
        definition: 'Newer meaning.',
        context: 'Context',
        topicName: 'Cloud',
        source: ConceptSource.manual,
        createdAt: harness.clock.now().toUtc(),
      );
      harness.clock.advance(const Duration(days: 1));
      await harness.cards.createConcept(
        sessionId: null,
        questionId: null,
        term: 'VPC',
        definition: '',
        context: 'Context',
        topicName: 'Cloud',
        source: ConceptSource.manual,
        createdAt: harness.clock.now().toUtc(),
      );

      final found = await harness.cards.latestConceptForTerm('  vpc  ');

      expect(found, isNotNull);
      expect(found!.id, isNot(older));
      expect(found.id, newer);
      expect(found.definition, 'Newer meaning.');
    },
  );

  test('AI card suggestions need a saved API key', () async {
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiModel: 'test-model',
        aiBaseUrl: 'https://example.test/v1',
      ),
    );
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });

    await expectLater(
      serviceWith(client).suggestArchetypeCards(
        note: 'Note',
        questionContext: 'Question',
        topicName: 'Topic',
      ),
      throwsA(
        isA<LookupException>().having(
          (error) => error.message,
          'message',
          contains('API key'),
        ),
      ),
    );
    expect(called, isFalse);
  });
}
