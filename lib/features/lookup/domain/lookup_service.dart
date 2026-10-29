import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import '../../../core/data/card_repository.dart';
import '../../../core/data/settings_repository.dart';
import '../../../core/domain/models.dart';
import '../../../core/platform/secure_key_store.dart';
import '../../../core/platform/web_launcher.dart';

class LookupException implements Exception {
  const LookupException(this.message, {this.canUseWeb = false});

  final String message;
  final bool canUseWeb;

  @override
  String toString() => message;
}

class LookupResult {
  const LookupResult({
    required this.conceptId,
    required this.term,
    required this.definition,
    required this.source,
    required this.openedWeb,
  });

  final int conceptId;
  final String term;
  final String definition;
  final ConceptSource source;
  final bool openedWeb;
}

class LookupService {
  LookupService({
    required http.Client client,
    required SettingsRepository settings,
    required SecureKeyStore keyStore,
    required WebLauncher webLauncher,
    required CardRepository cards,
    required Clock clock,
  }) : _client = client,
       _settings = settings,
       _keyStore = keyStore,
       _webLauncher = webLauncher,
       _cards = cards,
       _clock = clock;

  final http.Client _client;
  final SettingsRepository _settings;
  final SecureKeyStore _keyStore;
  final WebLauncher _webLauncher;
  final CardRepository _cards;
  final Clock _clock;

  Future<LookupResult> define({
    required String term,
    required String question,
    required String topicName,
    required String practiceName,
    required int? sessionId,
    required int? questionId,
  }) async {
    final cleanedTerm = term.trim();
    if (cleanedTerm.isEmpty) {
      throw const LookupException('Select a word or phrase first.');
    }
    final settings = await _settings.load();
    if (settings.lookupMode == LookupMode.web) {
      return openWeb(
        term: cleanedTerm,
        question: question,
        topicName: topicName,
        practiceName: practiceName,
        sessionId: sessionId,
        questionId: questionId,
      );
    }

    final apiKey = await _keyStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const LookupException(
        'No API key saved. Add one in Settings or use web search.',
        canUseWeb: true,
      );
    }
    final definition = await _askAi(
      settings: settings,
      apiKey: apiKey,
      term: cleanedTerm,
      question: question,
      topicName: topicName,
    );
    final id = await _saveConcept(
      term: cleanedTerm,
      definition: definition,
      question: question,
      topicName: topicName,
      sessionId: sessionId,
      questionId: questionId,
      source: ConceptSource.ai,
    );
    return LookupResult(
      conceptId: id,
      term: cleanedTerm,
      definition: definition,
      source: ConceptSource.ai,
      openedWeb: false,
    );
  }

  Future<LookupResult> openWeb({
    required String term,
    required String question,
    required String topicName,
    required String practiceName,
    required int? sessionId,
    required int? questionId,
  }) async {
    final cleanedTerm = term.trim();
    final settings = await _settings.load();
    final uri = _webUri(settings.webEngine, cleanedTerm);
    final id = await _saveConcept(
      term: cleanedTerm,
      definition: '',
      question: question,
      topicName: topicName,
      sessionId: sessionId,
      questionId: questionId,
      source: ConceptSource.web,
    );
    var opened = false;
    try {
      await _webLauncher.open(uri);
      opened = true;
    } on WebLaunchException {
      opened = false;
    }
    return LookupResult(
      conceptId: id,
      term: cleanedTerm,
      definition: '',
      source: ConceptSource.web,
      openedWeb: opened,
    );
  }

  Future<String> testConnection() async {
    final settings = await _settings.load();
    final key = await _keyStore.readApiKey();
    if (key == null || key.trim().isEmpty) {
      throw const LookupException('Add an API key first.');
    }
    return _askAi(
      settings: settings,
      apiKey: key,
      term: 'HTTP',
      question: 'What does HTTP mean?',
      topicName: 'Connectivity test',
    );
  }

  Future<List<String>> listModels({
    required AiProvider provider,
    required String baseUrl,
    required String apiKey,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const LookupException('Add an API key first.');
    }
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw const LookupException('Add a base URL first.');
    }
    try {
      if (provider == AiProvider.gemini) {
        final uri = Uri.parse('$base/models')
            .replace(queryParameters: {'key': key});
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 20));
        _ensureModelResponse(response);
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final models = decoded['models'] as List<dynamic>? ?? const [];
        return [
          for (final item in models)
            if (item is Map<String, dynamic>)
              if (!_geminiModelExcluded(item))
                (item['name'] as String? ?? '').replaceFirst('models/', ''),
        ].where((name) => name.isNotEmpty).toList()..sort();
      }

      final response = await _client
          .get(
            Uri.parse('$base/models'),
            headers: {'Authorization': 'Bearer $key'},
          )
          .timeout(const Duration(seconds: 20));
      _ensureModelResponse(response);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final models = decoded['data'] as List<dynamic>? ?? const [];
      return [
        for (final item in models)
          if (item is Map<String, dynamic>) item['id'] as String? ?? '',
      ].where((name) => name.isNotEmpty).toList()..sort();
    } on TimeoutException {
      throw const LookupException('The provider took too long to list models.');
    } on LookupException {
      rethrow;
    } on Object {
      throw const LookupException('Could not read the provider model list.');
    }
  }

  void _ensureModelResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const LookupException('The API key was rejected.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LookupException(
        'The provider returned HTTP ${response.statusCode} when listing models.',
      );
    }
  }

  bool _geminiModelExcluded(Map<String, dynamic> model) {
    final methods = model['supportedGenerationMethods'];
    if (methods is! List) return false;
    return !methods.contains('generateContent');
  }

  Future<int> _saveConcept({
    required String term,
    required String definition,
    required String question,
    required String topicName,
    required int? sessionId,
    required int? questionId,
    required ConceptSource source,
  }) {
    return _cards.createConcept(
      sessionId: sessionId,
      questionId: questionId,
      term: term,
      definition: definition,
      context: question,
      topicName: topicName,
      source: source,
      createdAt: _clock.now().toUtc(),
    );
  }

  Uri _webUri(WebEngine engine, String term) {
    return switch (engine) {
      WebEngine.duckDuckGo => Uri.https('duckduckgo.com', '/', {'q': term}),
      WebEngine.wikipedia => Uri.https('en.wikipedia.org', '/w/index.php', {
        'search': term,
      }),
    };
  }

  Future<String> _askAi({
    required AppSettings settings,
    required String apiKey,
    required String term,
    required String question,
    required String topicName,
  }) async {
    final model = settings.aiModel.trim();
    if (model.isEmpty) {
      throw const LookupException(
        'No AI model configured. Add a model in Settings.',
        canUseWeb: true,
      );
    }
    final base = settings.aiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw const LookupException(
        'No AI endpoint configured. Add one in Settings.',
        canUseWeb: true,
      );
    }
    final isGemini = settings.aiProvider == AiProvider.gemini;
    final geminiModel = model.replaceFirst(RegExp(r'^models/'), '');
    final uri = isGemini
        ? Uri.tryParse('$base/models/$geminiModel:generateContent')
              ?.replace(queryParameters: {'key': apiKey})
        : Uri.tryParse('$base/chat/completions');
    if (uri == null || !uri.isAbsolute) {
      throw const LookupException(
        'The AI endpoint is not a valid URL.',
        canUseWeb: true,
      );
    }

    const systemPrompt =
        'You define a term for a study app. Use the question context and the given topic. '
        'Answer with exactly one JSON object: {"definition":"..."}. '
        'The definition must be at most 20 words, factual, and only define the term. '
        'Do not add markdown or extra keys.';
    final userPrompt = 'Topic: $topicName\nQuestion: $question\nTerm: $term';
    final body = isGemini
        ? <String, dynamic>{
            'systemInstruction': {
              'parts': [
                {'text': systemPrompt},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': userPrompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.2,
              'responseMimeType': 'application/json',
            },
          }
        : <String, dynamic>{
            'model': model,
            'temperature': 0.2,
            'response_format': {'type': 'json_object'},
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
          };

    Future<http.Response> send(Map<String, dynamic> requestBody) {
      return _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (!isGemini) 'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));
    }

    http.Response response;
    try {
      response = await send(body);
      if (response.statusCode == 400) {
        final fallback = Map<String, dynamic>.of(body);
        if (isGemini) {
          final config = Map<String, dynamic>.of(
            fallback['generationConfig'] as Map<String, dynamic>,
          )..remove('responseMimeType');
          fallback['generationConfig'] = config;
        } else {
          fallback.remove('response_format');
        }
        response = await send(fallback);
      }
    } on TimeoutException {
      throw const LookupException(
        'The AI provider took too long to answer.',
        canUseWeb: true,
      );
    } on http.ClientException {
      throw const LookupException(
        'Could not reach the AI provider. Check the connection.',
        canUseWeb: true,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const LookupException('The API key was rejected.', canUseWeb: true);
    }
    if (response.statusCode == 429) {
      throw const LookupException(
        'The AI provider is rate limiting requests. Try again or use web search.',
        canUseWeb: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LookupException(
        'The AI provider returned HTTP ${response.statusCode}.',
        canUseWeb: true,
      );
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = isGemini
          ? _geminiContent(decoded)
          : decoded['choices'][0]['message']['content'] as String;
      final cleaned = content
          .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
          .trim();
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start < 0 || end <= start) {
        throw const FormatException('No JSON object in response');
      }
      final payload = jsonDecode(cleaned.substring(start, end + 1));
      final definition = (payload['definition'] as String? ?? '').trim();
      if (definition.isEmpty) {
        throw const FormatException('Empty definition');
      }
      return definition;
    } on Object {
      throw const LookupException(
        'The AI returned an invalid response. Try again or use web search.',
        canUseWeb: true,
      );
    }
  }

  String _geminiContent(Map<String, dynamic> decoded) {
    final candidates = decoded['candidates'] as List<dynamic>;
    final content = candidates.first as Map<String, dynamic>;
    final parts = content['content']['parts'] as List<dynamic>;
    return [
      for (final part in parts)
        if (part is Map<String, dynamic>) part['text'] as String? ?? '',
    ].join();
  }
}
