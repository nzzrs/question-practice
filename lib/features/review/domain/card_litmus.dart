import '../../../core/domain/models.dart';

/// A quality problem found in a proposed atomic card.
enum LitmusIssue {
  binary('Can be answered with yes or no'),
  longFront('Front is longer than 30 words'),
  syntacticClue('The question hints at the answer'),
  missingTemplate('Heuristic front does not use the rule template');

  const LitmusIssue(this.label);

  final String label;
}

/// Result of checking one proposed card before it is saved.
class LitmusReport {
  const LitmusReport(this.issues);

  final List<LitmusIssue> issues;

  bool get isClean => issues.isEmpty;
  String get label => isClean ? 'Ready' : issues.first.label;

  /// A short list suitable for a badge tooltip.
  String get detail => issues.map((issue) => issue.label).join(' · ');
}

final _binaryStart = RegExp(
  r'^(is|are|was|were|do|does|did|can|could|will|would|should|shall|has|have|had|am)\b',
  caseSensitive: false,
);
final _syntacticClue = RegExp(
  r'\b(the answer is|because|all of the above|none of the above|which of the following|except|always|never|only|best describes|according to|as mentioned|remember that)\b',
  caseSensitive: false,
);
final _ruleTemplate = RegExp(
  r'^given\b.*\bwith\b.*\bwhat rule applies\?',
  caseSensitive: false,
);

/// Checks a proposed front/back pair against the card quality rules.
LitmusReport checkCardLitmus({
  required String front,
  required String back,
  required CognitiveType cognitiveType,
}) {
  final issues = <LitmusIssue>[];
  final trimmedFront = front.trim();
  final words = trimmedFront
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;

  final binary =
      RegExp(r'^(yes|no)\b', caseSensitive: false).hasMatch(trimmedFront) ||
      trimmedFront.toLowerCase().contains('yes or no') ||
      trimmedFront.toLowerCase().contains('true or false') ||
      (trimmedFront.endsWith('?') && _binaryStart.hasMatch(trimmedFront));
  if (binary) issues.add(LitmusIssue.binary);
  if (words > 30) issues.add(LitmusIssue.longFront);
  if (_syntacticClue.hasMatch(trimmedFront)) {
    issues.add(LitmusIssue.syntacticClue);
  }
  if (cognitiveType == CognitiveType.heuristic &&
      trimmedFront.isNotEmpty &&
      !_ruleTemplate.hasMatch(trimmedFront) &&
      !trimmedFront.toLowerCase().startsWith('given ')) {
    issues.add(LitmusIssue.missingTemplate);
  }
  return LitmusReport(issues);
}
