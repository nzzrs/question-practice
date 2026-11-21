import '../../../core/domain/models.dart';

/// A generated front/back pair for one of the basic card templates.
class CardScaffold {
  const CardScaffold({required this.front, required this.back});

  final String front;
  final String back;
}

/// A term and definition parsed from the raw Definition cloze.
class ParsedDefinitionCloze {
  const ParsedDefinitionCloze({required this.term, required this.definition});

  final String term;
  final String definition;

  bool get isComplete => term.isNotEmpty && definition.isNotEmpty;
}

const _contrastFront =
    'What is the key difference between [option A] and [option B] on '
    '[criterion]?';
const _contrastBack =
    '[Option A] does [behavior A], while [Option B] does [behavior B].';
const _mechanismFront =
    'Why does [technology or concept] cause or require [effect]?';
const _mechanismBack = '[One-line cause and effect].';
const _heuristicFront =
    'If a scenario asks [X] but restricts with [Y], which option is always '
    'discarded?';
const _heuristicBack = 'Discard [Z] because [rule].';
const _procedureFront =
    'In [process X], what must be true before [next step Y]?';
const _procedureBack = '[Condition or command].';

/// Returns the exact scaffold for a basic template.
///
/// [CardTemplate.definition] has no basic scaffold: it is written as a raw
/// cloze sentence, so this returns null for it.
///
/// When [wrongAnswer] and [correctAnswer] are supplied (the error context),
/// the contrast scaffold names the chosen wrong option as A and the correct
/// option as B. Other placeholders stay untouched for the learner.
CardScaffold? fillScaffold(
  CardTemplate template, {
  String wrongAnswer = '',
  String correctAnswer = '',
}) {
  switch (template) {
    case CardTemplate.definition:
      return null;
    case CardTemplate.contrast:
      return CardScaffold(
        front: _contrastFront
            .replaceAll('[option A]', _option(wrongAnswer, '[option A]'))
            .replaceAll('[option B]', _option(correctAnswer, '[option B]')),
        back: _contrastBack
            .replaceAll('[Option A]', _option(wrongAnswer, '[Option A]'))
            .replaceAll('[Option B]', _option(correctAnswer, '[Option B]')),
      );
    case CardTemplate.mechanism:
      return const CardScaffold(front: _mechanismFront, back: _mechanismBack);
    case CardTemplate.heuristic:
      return const CardScaffold(front: _heuristicFront, back: _heuristicBack);
    case CardTemplate.procedure:
      return const CardScaffold(front: _procedureFront, back: _procedureBack);
  }
}

String _option(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

/// Seeds a raw Definition cloze.
///
/// A term and definition become the exact Anki cloze sentence. A sentence such
/// as a note is split at "is" / "are" / "means" when that reads naturally.
/// Nothing usable produces the empty scaffold, whose placeholders parse as
/// empty so Save stays disabled until the learner writes real text.
String seedDefinitionCloze({
  String term = '',
  String definition = '',
  String source = '',
}) {
  final safeTerm = term.trim();
  final safeDefinition = definition.trim();
  if (safeTerm.isNotEmpty && safeDefinition.isNotEmpty) {
    return 'Definition of {{c1::$safeTerm}}: {{c2::$safeDefinition}}';
  }

  final text = safeTerm.isNotEmpty
      ? safeTerm
      : safeDefinition.isNotEmpty
      ? safeDefinition
      : source.trim();
  if (text.isNotEmpty) {
    final split = _splitDefinitionSentence(text);
    if (split != null) {
      return '{{c1::${split.term}}} ${split.connector} '
          '{{c2::${split.definition}}}';
    }
    if (safeTerm.isNotEmpty && _wordCount(safeTerm) <= 4) {
      return 'Definition of {{c1::$safeTerm}}: {{c2::…}}';
    }
    return 'Definition of {{c1::term}}: {{c2::$text}}';
  }
  return 'Definition of {{c1::term}}: {{c2::…}}';
}

/// Parses the raw Definition cloze into the Concept model fields.
///
/// `{{c1::VPC}}` is the term; everything after it is the definition, with
/// remaining clozes resolved. Placeholder words from the seed count as empty.
ParsedDefinitionCloze parseDefinitionCloze(String raw) {
  final matches = RegExp(r'\{\{c(\d+)::(.*?)\}\}').allMatches(raw).toList();
  if (matches.isEmpty) {
    return const ParsedDefinitionCloze(term: '', definition: '');
  }

  final termMatch = matches.firstWhere(
    (match) => match.group(1) == '1',
    orElse: () => matches.first,
  );
  final term = _cleanValue(termMatch.group(2) ?? '');
  // Read the definition from everything around the term, so text before the
  // term is kept as well. The term cloze is removed before cleaning.
  final withoutTerm = raw.replaceRange(termMatch.start, termMatch.end, ' ');
  var definition = _cleanDefinition(stripCloze(withoutTerm));

  if (definition.isEmpty) {
    final others = [
      for (final match in matches)
        if (!identical(match, termMatch)) _cleanValue(match.group(2) ?? ''),
    ].where((value) => value.isNotEmpty);
    definition = others.join(' ');
  }

  return ParsedDefinitionCloze(term: term, definition: definition);
}

/// Builds the read-only Anki Cloze front field for a Definition card.
///
/// The meaning is shown as an ellipsis while it is pending, so the learner can
/// see where the answer will go.
String definitionPreview(String term, String meaning) {
  final safeTerm = term.trim();
  final safeMeaning = meaning.trim();
  return 'Definition of {{c1::$safeTerm}}: '
      '{{c2::${safeMeaning.isEmpty ? '…' : safeMeaning}}}';
}

/// Normalizes card text for duplicate detection.
///
/// Cloze markup, HTML and punctuation are removed so two wordings of the same
/// front compare closely.
String normalizeCardText(String value) {
  return stripCloze(value)
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

/// Whether [candidate] repeats or closely paraphrases [existing].
///
/// Near duplicates share at least 82% of their words, or one wording contains
/// every word of the other while both have at least four words.
bool isDuplicateCardText(String candidate, String existing) {
  final safeCandidate = normalizeCardText(candidate);
  final safeExisting = normalizeCardText(existing);
  if (safeCandidate.isEmpty || safeExisting.isEmpty) return false;
  if (safeCandidate == safeExisting) return true;

  final candidateWords = safeCandidate.split(' ').toSet();
  final existingWords = safeExisting.split(' ').toSet();
  final union = candidateWords.union(existingWords).length;
  if (union == 0) return false;
  final shared = candidateWords.intersection(existingWords).length;
  if (shared / union >= 0.82) return true;

  final smaller = candidateWords.length < existingWords.length
      ? candidateWords.length
      : existingWords.length;
  if (smaller >= 4 &&
      (candidateWords.containsAll(existingWords) ||
          existingWords.containsAll(candidateWords))) {
    return true;
  }
  return false;
}

/// Drops AI ideas and variants that repeat [existingTexts] or each other.
///
/// The first accepted wording is remembered so a later idea in the same reply
/// cannot repeat it.
List<SuggestedCardIdea> filterDuplicateIdeas(
  Iterable<SuggestedCardIdea> ideas, {
  Iterable<String> existingTexts = const [],
}) {
  final known = [
    for (final text in existingTexts)
      if (text.trim().isNotEmpty) text,
  ];
  final filtered = <SuggestedCardIdea>[];
  for (final idea in ideas) {
    final variants = <SuggestedCard>[];
    for (final variant in idea.variants) {
      final duplicate = known.any(
        (existing) => isDuplicateCardText(variant.front, existing),
      );
      if (duplicate) continue;
      variants.add(variant);
    }
    if (variants.isEmpty) continue;
    known.addAll(variants.map((variant) => variant.front));
    filtered.add(
      SuggestedCardIdea(template: idea.template, variants: variants),
    );
  }
  return filtered;
}

/// Maps a legacy AI `type` value to the template that now represents it.
///
/// Missing values fall back to Cause and effect, the generic factual template.
/// Unknown values return null so callers skip the proposal instead of guessing.
CardTemplate? templateFromLegacyType(String? value) {
  final type = value?.trim().toLowerCase() ?? '';
  return switch (type) {
    'definition' => CardTemplate.definition,
    'contrast' => CardTemplate.contrast,
    'heuristic' || 'rule' => CardTemplate.heuristic,
    'procedure' || 'steps' => CardTemplate.procedure,
    'fact' || 'mechanism' || 'cause and effect' || '' => CardTemplate.mechanism,
    _ => null,
  };
}

/// Reads a current AI `template` value.
///
/// Missing or unknown values fall back to Cause and effect so one malformed
/// suggestion never hides the whole reply.
CardTemplate templateFromName(String? value) {
  final name = value?.trim().toLowerCase() ?? '';
  for (final template in CardTemplate.values) {
    if (template.name == name) return template;
  }
  return switch (name) {
    'rule' || 'exam tip' || 'exam heuristic' => CardTemplate.heuristic,
    'steps' ||
    'procedure' ||
    'phase transition' ||
    'phase transition / procedure' => CardTemplate.procedure,
    'cause and effect' ||
    'cause-effect' ||
    'mechanism' ||
    'mechanism / cause-effect' ||
    'fact' => CardTemplate.mechanism,
    'definition' || 'definition / term' => CardTemplate.definition,
    'contrast' || 'contrast / difference' => CardTemplate.contrast,
    _ => CardTemplate.mechanism,
  };
}

/// Removes Cloze markup, for human-readable previews and accessibility labels.
String stripCloze(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'\{\{c\d+::(.*?)\}\}'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll('{{', '')
      .replaceAll('}}', '');
}

String _cleanValue(String value) {
  final trimmed = value.trim();
  const placeholders = {'term', 'meaning', '…', '...'};
  if (placeholders.contains(trimmed.toLowerCase())) return '';
  return trimmed;
}

final _definitionPrefix = RegExp(
  r'^definition(?:\s+of)?\s*[:;,\-–—=|]*\s*',
  caseSensitive: false,
);
final _leadingPunctuation = RegExp(r'^[:;,\-–—=|]+\s*');
final _leadingConnector = RegExp(
  r'^(is|are|means|refers to|describes|defines)\s+',
  caseSensitive: false,
);
final _trailingConnector = RegExp(
  r'\s+(is|are|means|refers to|describes|defines)\s*[.!?]*$',
  caseSensitive: false,
);
final _connectorOnly = RegExp(
  r'^(is|are|means|refers to|describes|defines)$',
  caseSensitive: false,
);
final _punctuationOnly = RegExp(r'^[\s\p{P}\p{S}]+$', unicode: true);

String _cleanDefinition(String value) {
  var text = value.trim();
  text = text.replaceFirst(_definitionPrefix, '');
  text = text.replaceFirst(_leadingPunctuation, '');
  text = text.replaceFirst(_leadingConnector, '');
  text = text.replaceFirst(_trailingConnector, '');
  text = text.trim();
  if (text.isEmpty || _connectorOnly.hasMatch(text)) return '';
  if (_punctuationOnly.hasMatch(text)) return '';
  return _cleanValue(text);
}

class _DefinitionSplit {
  const _DefinitionSplit({
    required this.term,
    required this.connector,
    required this.definition,
  });

  final String term;
  final String connector;
  final String definition;
}

_DefinitionSplit? _splitDefinitionSentence(String value) {
  final match = RegExp(
    r'^(.+?)\s+(is|are|means|refers to|describes|defines)\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  final term = _stripArticle(match.group(1)!.trim());
  final connector = match.group(2)!.toLowerCase();
  final definition = match.group(3)!.trim();
  if (term.isEmpty || definition.isEmpty) return null;
  return _DefinitionSplit(
    term: term,
    connector: connector,
    definition: definition,
  );
}

String _stripArticle(String value) {
  return value.replaceFirst(
    RegExp(r'^(a|an|the)\s+', caseSensitive: false),
    '',
  );
}

int _wordCount(String value) {
  return value.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
}
