/// Learner-edited question, options and explanations for an error card.
class ErrorCardContent {
  const ErrorCardContent({
    required this.question,
    required this.alternatives,
    this.explanation = '',
    this.alternativeExplanations = const [],
  });

  final String question;
  final List<String> alternatives;
  final String explanation;
  final List<String> alternativeExplanations;

  String alternativeExplanation(int index) {
    if (index < 0 || index >= alternativeExplanations.length) return '';
    return alternativeExplanations[index];
  }
}
