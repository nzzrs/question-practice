import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import '../../../core/data/card_repository.dart';
import '../../../core/data/settings_repository.dart';
import '../../../core/domain/acronyms.dart';
import '../../../core/domain/models.dart';
import '../../../core/platform/secure_key_store.dart';
import '../../../core/platform/web_launcher.dart';
import '../../export/domain/card_templates.dart';

/// Why a lookup failed, so the creator can show a neutral fallback instead of
/// an error when no provider is configured.
enum LookupFailure { noProvider, providerError }

class LookupException implements Exception {
  const LookupException(
    this.message, {
    this.canUseWeb = false,
    this.failure = LookupFailure.providerError,
  });

  final String message;
  final bool canUseWeb;
  final LookupFailure failure;

  @override
  String toString() => message;
}

/// A resolved dictionary-style meaning, without saving a concept.
class DefinitionSuggestion {
  const DefinitionSuggestion({required this.definition, required this.extra});

  final String definition;

  /// The full form of an acronym, shown in the Anki extra field.
  final String extra;
}

class LookupResult {
  const LookupResult({
    required this.conceptId,
    required this.term,
    required this.definition,
    required this.extra,
    required this.source,
    required this.openedWeb,
  });

  final int conceptId;
  final String term;
  final String definition;

  /// The full form of an acronym, shown in the Anki extra field.
  final String extra;
  final ConceptSource source;
  final bool openedWeb;
}

class ReviewCheckResult {
  const ReviewCheckResult({
    required this.consistent,
    required this.feedback,
    this.biasSuggestion = '',
    this.vaccineSuggestion = '',
  });

  final bool consistent;
  final String feedback;

  /// Short one-phrase rewrites the learner can apply to each field.
  final String biasSuggestion;
  final String vaccineSuggestion;
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
    String subtopic = '',
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
        subtopic: subtopic,
      );
    }

    final definition = await resolveDefinition(
      term: cleanedTerm,
      question: question,
      topicName: topicName,
      subtopic: subtopic,
    );
    final id = await _saveConcept(
      term: cleanedTerm,
      definition: definition.definition,
      extra: definition.extra,
      question: question,
      topicName: topicName,
      subtopic: subtopic,
      sessionId: sessionId,
      questionId: questionId,
      source: ConceptSource.ai,
    );
    return LookupResult(
      conceptId: id,
      term: cleanedTerm,
      definition: definition.definition,
      extra: definition.extra,
      source: ConceptSource.ai,
      openedWeb: false,
    );
  }

  /// Resolves a meaning from AI without saving a concept.
  ///
  /// The creator calls this while the learner types a term. Web lookup mode is
  /// treated as no provider: resolving a meaning never opens a browser.
  Future<DefinitionSuggestion> resolveDefinition({
    required String term,
    required String question,
    required String topicName,
    String subtopic = '',
  }) async {
    final cleanedTerm = term.trim();
    if (cleanedTerm.isEmpty) {
      throw const LookupException('Select a word or phrase first.');
    }
    final settings = await _settings.load();
    if (settings.lookupMode == LookupMode.web) {
      throw const LookupException(
        'Turning on AI lookup in Settings fills the meaning automatically.',
        failure: LookupFailure.noProvider,
      );
    }
    final apiKey = await _keyStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const LookupException(
        'No API key saved. Add one in Settings.',
        failure: LookupFailure.noProvider,
      );
    }
    final definition = await _askAi(
      settings: settings,
      apiKey: apiKey,
      term: cleanedTerm,
      question: question,
      topicName: topicName,
    );
    return DefinitionSuggestion(
      definition: definition.definition,
      extra: definition.extra,
    );
  }

  Future<LookupResult> openWeb({
    required String term,
    required String question,
    required String topicName,
    required String practiceName,
    required int? sessionId,
    required int? questionId,
    String subtopic = '',
  }) async {
    final cleanedTerm = term.trim();
    final settings = await _settings.load();
    final uri = _webUri(settings.webEngine, cleanedTerm);
    final id = await _saveConcept(
      term: cleanedTerm,
      definition: '',
      extra: '',
      question: question,
      topicName: topicName,
      subtopic: subtopic,
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
      extra: '',
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
    return (await _askAi(
      settings: settings,
      apiKey: key,
      term: 'HTTP',
      question: 'What does HTTP mean?',
      topicName: 'Connectivity test',
    )).definition;
  }

  /// Answers a free-form question about [selection] with question context.
  Future<String> ask({
    required String selection,
    required String question,
    required String topicName,
    required String userQuestion,
  }) async {
    final passage = selection.trim();
    final ask = userQuestion.trim();
    if (passage.isEmpty) {
      throw const LookupException('Select a word or phrase first.');
    }
    if (ask.isEmpty) {
      throw const LookupException('Write a question first.');
    }
    final settings = await _settings.load();
    final apiKey = await _keyStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const LookupException(
        'Ask needs an AI provider. Add an API key in Settings.',
      );
    }
    const systemPrompt =
        "You answer a learner's question about a selected passage in a "
        'study app. Use the selected passage, the question around it and '
        'the topic. Be accurate and concise: at most 90 words, plain text, no '
        'markdown. If the passage does not contain the answer, say so and give '
        'a short, grounded explanation.';
    final userPrompt =
        'Topic: $topicName\n'
        'Question context: $question\n'
        'Selected passage: $passage\n'
        'Learner question: $ask';
    final content = await _requestAi(
      settings: settings,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      jsonMode: false,
    );
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const LookupException('The AI returned an empty answer.');
    }
    if (trimmed.startsWith('{')) {
      try {
        final payload = _decodeObject(trimmed);
        final answer = payload['answer'] ?? payload['text'];
        if (answer is String && answer.trim().isNotEmpty) {
          return answer.trim();
        }
      } on Object {
        return trimmed;
      }
    }
    return trimmed;
  }

  /// Rewrites [text] as a shorter version of the named card field.
  ///
  /// Used before saving a card, when imported wording is too long to review.
  Future<String> summarizeText({
    required String text,
    required String fieldLabel,
    String? question,
  }) async {
    final source = text.trim();
    if (source.isEmpty) {
      throw LookupException('Write the $fieldLabel first.');
    }
    final settings = await _settings.load();
    final apiKey = await _keyStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const LookupException(
        'Summarizing needs an AI provider. Add an API key in Settings.',
      );
    }
    final label = fieldLabel.trim().isEmpty ? 'text' : fieldLabel.trim();
    final systemPrompt =
        'You shorten one field of a study card for a learner. Rewrite the '
        '$label so it is shorter and easier to review while keeping every '
        'fact, name and number. Return only the rewritten $label as plain '
        'text, at most 30 words, with no markdown and no quotation marks.';
    final context = question?.trim() ?? '';
    final userPrompt = [
      if (context.isNotEmpty) 'Question context: $context',
      'Original $label: $source',
    ].join('\n');
    final content = await _requestAi(
      settings: settings,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      jsonMode: false,
    );
    final trimmed = content
        .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
        .trim();
    if (trimmed.isEmpty) {
      throw const LookupException('The AI returned an empty summary.');
    }
    return trimmed;
  }

  /// Suggests structured atomic card ideas from a saved note.
  ///
  /// Each idea returns one to three wording variants of the same fact, so the
  /// learner can keep the variants that help without re-running the request.
  Future<List<SuggestedCardIdea>> suggestArchetypeCards({
    required String note,
    required String questionContext,
    required String topicName,
    String subtopic = '',
  }) async {
    final passage = note.trim();
    if (passage.isEmpty) {
      throw const LookupException('Select a note first.');
    }
    final settings = await _settings.load();
    final apiKey = await _keyStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const LookupException(
        'Suggesting cards needs an AI provider. Add an API key in Settings.',
        failure: LookupFailure.noProvider,
      );
    }
    const systemPrompt =
        'You turn one saved note from a study app into atomic card ideas with '
        'a fixed template. Use the note, the question around it, the topic and '
        'the subtopic. Return exactly one JSON object: '
        '{"ideas":[{"template":"definition|contrast|mechanism|heuristic|'
        'procedure","variants":[{"front":"...","back":"..."}]}]}. Rules: '
        '- At most 3 ideas. Each idea has 1-3 variants. Variants of one idea '
        'test the same fact in different wording. '
        '- definition: front is the term only; back is an atomic meaning that '
        'never repeats the term. '
        '- contrast: the front names both options and the criterion; the back '
        'says what A does while B does. '
        '- mechanism: the front asks why X causes or requires Y; the back is '
        'one causal line. '
        '- heuristic: the front must be exactly "If a scenario asks X but '
        'restricts with Y, which option is always discarded?"; the back '
        'starts with "Discard Z because ...". '
        '- procedure: the front asks what must be true before the next step; '
        'the back is the condition or command. '
        '- Each variant tests exactly one idea. Front <= 30 words; back <= 20 '
        'words. '
        '- No yes/no questions, no answer clues, no option letters, no '
        'markdown. '
        '- Never put the topic or subtopic inside the front or back. Tags are '
        'applied by the app. '
        '- Only use ideas supported by the note or its context. Skip trivial '
        'or duplicate ideas.';
    final context = questionContext.trim();
    final userPrompt = [
      if (topicName.trim().isNotEmpty) 'Topic: ${topicName.trim()}',
      if (subtopic.trim().isNotEmpty) 'Subtopic: ${subtopic.trim()}',
      if (context.isNotEmpty) 'Question context: $context',
      'Selected passage: $passage',
    ].join('\n');
    return _requestJsonCardIdeas(
      settings: settings,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      errorMessage: 'The AI returned invalid card suggestions. Try again.',
      maxIdeas: 3,
      maxVariants: 3,
    );
  }

  /// Drafts one atomic card from a read-only wrong-answer bullet.
  ///
  /// The bullet is the starting point, not the final wording. Returns null
  /// when the provider answers without a usable card, so the creator can tell
  /// the learner to write the card instead.
  Future<SuggestedCard?> suggestCardFromWrongNote({
    required String note,
    required String question,
    required String wrongAnswer,
    required String correctAnswer,
    required String explanation,
    required String topicName,
    String subtopic = '',
    List<String> otherNotes = const [],
  }) async {
    final bullet = note.trim();
    if (bullet.isEmpty) {
      throw const LookupException('Write the bullet first.');
    }
    final settings = await _settings.load();
    final apiKey = await _keyStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const LookupException(
        'Drafting a card needs an AI provider. Add an API key in Settings.',
        failure: LookupFailure.noProvider,
      );
    }
    const systemPrompt =
        'You turn one learner-written wrong-answer note into one atomic study '
        'card. Return exactly one JSON object: '
        '{"cards":[{"type":"contrast|heuristic|fact","front":"...",'
        '"back":"..."}]}. Rules: '
        '- Give 1-3 candidate cards, but each card tests exactly one idea. '
        '- Use the note as the basis; fix the wording instead of copying it. '
        '- contrast when the note names a confusion; heuristic when it names '
        'a rule or condition; fact otherwise. '
        '- Front <= 30 words. Back <= 20 words. No yes/no fronts. '
        '- No answer clues, option letters, markdown or code fences. '
        '- Never put the topic or subtopic inside the front or back.';
    final other = otherNotes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && item != bullet)
        .toList();
    final userPrompt = [
      if (topicName.trim().isNotEmpty) 'Topic: ${topicName.trim()}',
      if (subtopic.trim().isNotEmpty) 'Subtopic: ${subtopic.trim()}',
      'Question: $question',
      'Chosen wrong answer: $wrongAnswer',
      'Correct answer: $correctAnswer',
      'Explanation: $explanation',
      if (other.isNotEmpty)
        'Other notes from this attempt:\n- ${other.join('\n- ')}',
      'Learner note to turn into a card: $bullet',
    ].join('\n');

    final content = await _requestAi(
      settings: settings,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    try {
      final payload = _decodeObject(content);
      final rawCards = payload['cards'];
      if (rawCards is! List) {
        throw const FormatException('Missing cards list');
      }
      for (final item in rawCards) {
        if (item is! Map<String, dynamic>) continue;
        final rawFront = item['front'];
        final rawBack = item['back'];
        final front = rawFront is String ? rawFront.trim() : '';
        final back = rawBack is String ? rawBack.trim() : '';
        if (front.isEmpty || back.isEmpty) continue;
        final rawType = item['type'];
        final template = templateFromLegacyType(
          rawType is String ? rawType : null,
        );
        if (template == null || template == CardTemplate.definition) continue;
        return SuggestedCard(front: front, back: back, template: template);
      }
      return null;
    } on LookupException {
      rethrow;
    } on Object {
      throw const LookupException(
        'The AI returned invalid card drafts. Try again.',
      );
    }
  }

  /// Breaks one error into contrast and heuristic ideas.
  ///
  /// At most two ideas are returned: a contrast between the chosen wrong
  /// option and the correct one, and a heuristic whose front follows the
  /// mandatory exam-heuristic template.
  Future<List<SuggestedCardIdea>> breakdownErrorCard({
    required String question,
    required String wrongAnswer,
    required String correctAnswer,
    required String reasoning,
    required String explanation,
    required String topicName,
    String subtopic = '',
    List<MistakeKind> mistakeKinds = const [],
    List<String> wrongNotes = const [],
  }) async {
    final settings = await _settings.load();
    final apiKey = await _keyStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const LookupException(
        'Breaking down cards needs an AI provider. Add an API key in Settings.',
        failure: LookupFailure.noProvider,
      );
    }
    const systemPrompt =
        'You split one study error into atomic card ideas. Return exactly one '
        'JSON object: {"ideas":[{"template":"contrast|heuristic",'
        '"variants":[{"front":"...","back":"..."}]}]}. Rules: '
        '- At most 2 ideas: one contrast and one heuristic. Each has 1-3 '
        'variants. '
        '- The contrast uses the chosen wrong answer and the correct answer; '
        'the front names both options and the criterion, and the back states '
        'the decisive difference. '
        '- The heuristic front must use the exact exam-heuristic template: '
        '"If a scenario asks X but restricts with Y, which option is always '
        'discarded?" The back starts with "Discard Z because ...". '
        '- No definition, mechanism, or procedure ideas. '
        '- Each variant tests exactly one idea. Front <= 30 words; back <= 20 '
        'words. '
        '- No yes/no questions, no answer clues, no option letters, no '
        'markdown. '
        '- Never put the topic or subtopic inside the front or back. Tags are '
        'applied by the app. '
        '- Only use ideas supported by the error context. Skip trivial or '
        'duplicate ideas.';
    final mistakes = mistakeKinds.map((kind) => kind.label).join(', ');
    final notes = wrongNotes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final userPrompt = [
      if (topicName.trim().isNotEmpty) 'Topic: ${topicName.trim()}',
      if (subtopic.trim().isNotEmpty) 'Subtopic: ${subtopic.trim()}',
      'Question: $question',
      'Chosen wrong answer: $wrongAnswer',
      'Correct answer: $correctAnswer',
      'Mistake classifications: ${mistakes.isEmpty ? '(none)' : mistakes}',
      if (notes.isNotEmpty)
        'What went wrong (learner\'s own notes, one per line):\n'
            '- ${notes.join('\n- ')}',
      'Learner reasoning: ${reasoning.trim().isEmpty ? '(not written)' : reasoning.trim()}',
      'Explanation: $explanation',
    ].join('\n');
    return _requestJsonCardIdeas(
      settings: settings,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      errorMessage: 'The AI returned an invalid card breakdown. Try again.',
      maxIdeas: 2,
      maxVariants: 3,
      allowedTemplates: const {CardTemplate.contrast, CardTemplate.heuristic},
    );
  }

  Future<List<SuggestedCardIdea>> _requestJsonCardIdeas({
    required AppSettings settings,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required String errorMessage,
    required int maxIdeas,
    required int maxVariants,
    Set<CardTemplate>? allowedTemplates,
  }) async {
    final content = await _requestAi(
      settings: settings,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    try {
      final payload = _decodeObject(content);
      final ideas = <SuggestedCardIdea>[];
      final seenIdeas = <String>{};
      final rawIdeas = payload['ideas'];
      if (rawIdeas is List) {
        for (final rawIdea in rawIdeas) {
          if (ideas.length >= maxIdeas) break;
          final idea = _parseIdea(
            rawIdea,
            maxVariants: maxVariants,
            allowedTemplates: allowedTemplates,
          );
          if (idea == null) continue;
          final key =
              '${idea.template.name}\u0000'
              '${idea.variants.first.front.toLowerCase()}';
          if (!seenIdeas.add(key)) continue;
          ideas.add(idea);
        }
        return List.unmodifiable(ideas);
      }

      final rawCards = payload['cards'];
      if (rawCards is! List) {
        throw const FormatException('Missing ideas list');
      }
      for (final item in rawCards) {
        if (ideas.length >= maxIdeas) break;
        if (item is! Map<String, dynamic>) continue;
        final rawFront = item['front'];
        final rawBack = item['back'];
        final front = rawFront is String ? rawFront.trim() : '';
        final back = rawBack is String ? rawBack.trim() : '';
        if (front.isEmpty || back.isEmpty) continue;
        final rawType = item['type'];
        final template = templateFromLegacyType(
          rawType is String ? rawType : null,
        );
        if (template == null) continue;
        if (allowedTemplates != null && !allowedTemplates.contains(template)) {
          continue;
        }
        final key = '${template.name}\u0000${front.toLowerCase()}';
        if (!seenIdeas.add(key)) continue;
        ideas.add(
          SuggestedCardIdea(
            template: template,
            variants: [
              SuggestedCard(front: front, back: back, template: template),
            ],
          ),
        );
      }
      return List.unmodifiable(ideas);
    } on Object {
      throw LookupException(errorMessage);
    }
  }

  SuggestedCardIdea? _parseIdea(
    Object? rawIdea, {
    required int maxVariants,
    Set<CardTemplate>? allowedTemplates,
  }) {
    if (rawIdea is! Map<String, dynamic>) return null;
    final rawTemplate = rawIdea['template'];
    final template = templateFromName(
      rawTemplate is String ? rawTemplate : null,
    );
    if (template == null) return null;
    if (allowedTemplates != null && !allowedTemplates.contains(template)) {
      return null;
    }
    final rawVariants = rawIdea['variants'];
    if (rawVariants is! List) return null;
    final variants = <SuggestedCard>[];
    final seenFronts = <String>{};
    for (final item in rawVariants) {
      if (variants.length >= maxVariants) break;
      if (item is! Map<String, dynamic>) continue;
      final rawFront = item['front'];
      final rawBack = item['back'];
      final front = rawFront is String ? rawFront.trim() : '';
      final back = rawBack is String ? rawBack.trim() : '';
      if (front.isEmpty || back.isEmpty) continue;
      if (!seenFronts.add(front.toLowerCase())) continue;
      variants.add(
        SuggestedCard(
          front: front,
          back: back,
          template: template,
          variantIndex: variants.length,
        ),
      );
    }
    if (variants.isEmpty) return null;
    return SuggestedCardIdea(template: template, variants: variants);
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
    required String extra,
    required String question,
    required String topicName,
    required int? sessionId,
    required int? questionId,
    required ConceptSource source,
    String subtopic = '',
  }) {
    return _cards.createConcept(
      sessionId: sessionId,
      questionId: questionId,
      term: term,
      definition: definition,
      extra: extra,
      context: question,
      topicName: topicName,
      subtopic: subtopic,
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

  Future<ReviewCheckResult> checkErrorNotes({
    required String question,
    required String correctAnswer,
    required String wrongAnswer,
    required String reasoning,
    required String bias,
    required String vaccine,
  }) async {
    final settings = await _settings.load();
    final apiKey = await _keyStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const LookupException('No API key saved. Add one in Settings.');
    }
    const systemPrompt =
        "You review a learner's error analysis for a study app. Focus on the "
        "learner's own reasoning and flawed assumption, not on the question's "
        'explanation: the explanation says why an answer is correct, but the '
        'learner may have failed for a different reason. Infer how that '
        'reasoning led to the wrong answer, then judge whether the flawed '
        'assumption names that error and whether the prevention note is a '
        'concrete rule or check derived from it. Answer with exactly one JSON '
        'object: {"consistent":true,"feedback":"...","bias":"...",'
        '"vaccine":"..."}. The bias and vaccine values are short one-phrase '
        "suggestions (12 words or fewer) that could replace the learner's "
        'notes. Set consistent to false when the notes are vague, merely '
        'restate the mistake, or do not match the learner reasoning. Keep '
        'feedback under 45 words and do not add markdown or extra keys.';
    final userPrompt =
        'Question: $question\n'
        'Correct answer: $correctAnswer\n'
        'Chosen wrong answer: $wrongAnswer\n'
        'Learner reasoning: ${reasoning.trim().isEmpty ? '(not written)' : reasoning}\n'
        'Flawed assumption: $bias\n'
        'Prevention note: $vaccine';
    final content = await _requestAi(
      settings: settings,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    try {
      final payload = _decodeObject(content);
      final consistent = payload['consistent'];
      final feedback = (payload['feedback'] as String? ?? '').trim();
      if (consistent is! bool || feedback.isEmpty) {
        throw const FormatException('Missing review verdict');
      }
      return ReviewCheckResult(
        consistent: consistent,
        feedback: feedback,
        biasSuggestion: (payload['bias'] as String? ?? '').trim(),
        vaccineSuggestion: (payload['vaccine'] as String? ?? '').trim(),
      );
    } on Object {
      throw const LookupException(
        'The AI returned an invalid review. Try again.',
      );
    }
  }

  Future<_AiDefinition> _askAi({
    required AppSettings settings,
    required String apiKey,
    required String term,
    required String question,
    required String topicName,
  }) async {
    final acronym = looksLikeAcronym(term);
    final systemPrompt = acronym
        ? 'You define a term for a study app. Use the question context and the '
              'given topic. The term is an acronym. Answer with exactly one '
              'JSON object: {"definition":"...","expansion":"..."}. The '
              'definition must be a dictionary-style meaning in at most 20 '
              'words. It must never spell out, repeat or expand the acronym '
              'itself. The expansion must contain only the full form of the '
              'acronym, without a trailing period. Do not add markdown or '
              'extra keys.'
        : 'You define a term for a study app. Use the question context and the '
              'given topic. Answer with exactly one JSON object: '
              '{"definition":"...","expansion":""}. The definition must be a '
              'dictionary-style meaning in at most 20 words, factual, and only '
              'define the term. Leave expansion empty. Do not add markdown or '
              'extra keys.';
    final userPrompt = 'Topic: $topicName\nQuestion: $question\nTerm: $term';
    final content = await _requestAi(
      settings: settings,
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    try {
      final payload = _decodeObject(content);
      final definition = (payload['definition'] as String? ?? '').trim();
      final expansion = acronym
          ? (payload['expansion'] as String? ?? '').trim()
          : '';
      if (definition.isEmpty || (acronym && expansion.isEmpty)) {
        throw const FormatException('Missing definition');
      }
      return _AiDefinition(definition: definition, extra: expansion);
    } on Object {
      throw LookupException(
        acronym
            ? 'The AI returned an invalid acronym definition. Try again or use '
                  'web search.'
            : 'The AI returned an invalid response. Try again or use web '
                  'search.',
        canUseWeb: true,
      );
    }
  }

  Future<String> _requestAi({
    required AppSettings settings,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = true,
  }) async {
    final model = settings.aiModel.trim();
    if (model.isEmpty) {
      throw const LookupException(
        'No AI model configured. Add a model in Settings.',
        canUseWeb: true,
        failure: LookupFailure.noProvider,
      );
    }
    final base = settings.aiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw const LookupException(
        'No AI endpoint configured. Add one in Settings.',
        canUseWeb: true,
        failure: LookupFailure.noProvider,
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
              if (jsonMode) 'responseMimeType': 'application/json',
            },
          }
        : <String, dynamic>{
            'model': model,
            'temperature': 0.2,
            if (jsonMode) 'response_format': {'type': 'json_object'},
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
      return isGemini
          ? _geminiContent(decoded)
          : decoded['choices'][0]['message']['content'] as String;
    } on Object {
      throw const LookupException(
        'The AI returned an invalid response. Try again or use web search.',
        canUseWeb: true,
      );
    }
  }

  Map<String, dynamic> _decodeObject(String content) {
    final cleaned = content
        .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
        .trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('No JSON object in response');
    }
    final payload = jsonDecode(cleaned.substring(start, end + 1));
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return payload;
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

class _AiDefinition {
  const _AiDefinition({required this.definition, required this.extra});

  final String definition;
  final String extra;
}
