import '../../../core/domain/models.dart';

/// A quality problem found in a proposed atomic card.
///
/// The declaration order is the order issues are reported in.
enum LitmusIssue {
  binary('Can be answered with yes or no'),
  longFront('Front is longer than 30 words'),
  longCard('Card needs more than 15 seconds to read'),
  syntacticClue('The question hints at the answer'),
  heuristicTemplate(
    'Exam heuristic front does not use the required prompt structure',
  ),
  procedureTemplate('Procedure front does not ask what must be true first'),
  missingFront('No front yet'),
  missingBack('No back yet'),
  missingDefinition('No definition yet'),
  repeatsTerm('Definition repeats the term');

  const LitmusIssue(this.label);

  final String label;
}

/// Result of checking one proposed card before it is saved.
class LitmusReport {
  const LitmusReport(this.issues);

  final List<LitmusIssue> issues;

  bool get isClean => issues.isEmpty;
  String get label => isClean ? 'Ready' : issues.first.label;

  /// A short list suitable for a badge tooltip or detail line.
  String get detail => issues.map((issue) => issue.label).join(' · ');
}

final _binaryStart = RegExp(
  r'^(is|are|was|were|do|does|did|can|could|will|would|should|shall|has|have|had|am)\b',
  caseSensitive: false,
);
final _binaryPrefix = RegExp(r'^(yes|no)\b', caseSensitive: false);
final _syntacticClue = RegExp(
  r'(the answer is|because|all of the above|none of the above|'
  r'which of the following|\bexcept\b|\bbest describes\b|'
  r'\baccording to\b|\bas mentioned\b|\bremember that\b|hint:)',
  caseSensitive: false,
);
final _heuristicTemplate = RegExp(
  r'^if\b.*\basks\b.*\brestricts with\b.*\bwhich option is always discarded\?$',
  caseSensitive: false,
);
const _definitionStopWords = {'the', 'and', 'of', 'for', 'in', 'on'};

/// Checks a proposed front/back pair against the card quality rules.
///
/// Quality is advisory: the report never blocks adding or saving a card.
LitmusReport checkCardLitmus({
  required String front,
  required String back,
  required CardTemplate template,
}) {
  final issues = <LitmusIssue>{};
  final trimmedFront = front.trim();
  final trimmedBack = back.trim();
  final frontWords = _wordCount(trimmedFront);

  final lowerFront = trimmedFront.toLowerCase();
  final binary =
      _binaryPrefix.hasMatch(trimmedFront) ||
      lowerFront.contains('yes or no') ||
      lowerFront.contains('true or false') ||
      (trimmedFront.endsWith('?') && _binaryStart.hasMatch(trimmedFront));
  if (binary) issues.add(LitmusIssue.binary);
  if (frontWords > 30) issues.add(LitmusIssue.longFront);
  if (frontWords + _wordCount(trimmedBack) > 50) {
    issues.add(LitmusIssue.longCard);
  }
  if (_syntacticClue.hasMatch(trimmedFront)) {
    issues.add(LitmusIssue.syntacticClue);
  }
  if (template == CardTemplate.heuristic &&
      trimmedFront.isNotEmpty &&
      !_heuristicTemplate.hasMatch(trimmedFront)) {
    issues.add(LitmusIssue.heuristicTemplate);
  }
  if (template == CardTemplate.procedure &&
      (!lowerFront.contains('before') || !trimmedFront.endsWith('?'))) {
    issues.add(LitmusIssue.procedureTemplate);
  }
  if (trimmedFront.isEmpty && trimmedBack.isNotEmpty) {
    issues.add(LitmusIssue.missingFront);
  }
  if (template != CardTemplate.definition &&
      trimmedBack.isEmpty &&
      trimmedFront.isNotEmpty) {
    issues.add(LitmusIssue.missingBack);
  }
  if (template == CardTemplate.definition && trimmedBack.isEmpty) {
    issues.add(LitmusIssue.missingDefinition);
  }
  if (template == CardTemplate.definition &&
      trimmedBack.isNotEmpty &&
      _repeatsTerm(trimmedFront, trimmedBack)) {
    issues.add(LitmusIssue.repeatsTerm);
  }

  return LitmusReport([
    for (final issue in LitmusIssue.values)
      if (issues.contains(issue)) issue,
  ]);
}

int _wordCount(String value) {
  return value.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
}

bool _repeatsTerm(String term, String meaning) {
  final tokens = RegExp(r'[A-Za-z0-9]+')
      .allMatches(term)
      .map((match) => match.group(0)!.toLowerCase());
  final seen = <String>{};
  for (final token in tokens) {
    if (token.length < 2 || _definitionStopWords.contains(token)) continue;
    if (!seen.add(token)) continue;
    final word = RegExp('\\b${RegExp.escape(token)}\\b', caseSensitive: false);
    if (word.hasMatch(meaning)) return true;
  }
  return false;
}
