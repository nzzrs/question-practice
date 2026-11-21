import '../../../core/domain/models.dart';

/// A generated front/back pair for one of the basic card templates.
class CardScaffold {
  const CardScaffold({required this.front, required this.back});

  final String front;
  final String back;
}

const _contrastFront =
    'What is the key difference between [option A] and [option B] on '
    '[criterion]?';
const _contrastBack =
    '[Option A] does [behavior A], while [Option B] does [behavior B].';
const _mechanismFront =
    'Why does [technology or concept] cause or require [effect]?';
const _mechanismBack = '[One-line causal mechanism].';
const _heuristicFront =
    'If a scenario asks [X] but restricts with [Y], which option is always '
    'discarded?';
const _heuristicBack = 'Discard [Z] because [rule].';
const _procedureFront =
    'In [process X], what must be true before [next step Y]?';
const _procedureBack = '[Condition or command].';

/// Returns the exact scaffold for a basic template.
///
/// [CardTemplate.definition] has no basic scaffold: its front is generated
/// from the term and the resolved meaning, so this returns null for it.
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

/// Builds the read-only Anki Cloze field preview for a Definition card.
///
/// The meaning is shown as an ellipsis while it is pending, so the learner can
/// see where the answer will go without an editable definition field.
String definitionPreview(String term, String meaning) {
  final safeTerm = term.trim();
  final safeMeaning = meaning.trim();
  return 'Definition of {{c1::$safeTerm}}: '
      '{{c2::${safeMeaning.isEmpty ? '…' : safeMeaning}}}';
}

/// Maps a legacy AI `type` value to the template that now represents it.
///
/// Missing values fall back to Mechanism, the generic factual Basic template.
/// Unknown values return null so callers skip the proposal instead of guessing.
CardTemplate? templateFromLegacyType(String? value) {
  final type = value?.trim().toLowerCase() ?? '';
  return switch (type) {
    'definition' => CardTemplate.definition,
    'contrast' => CardTemplate.contrast,
    'heuristic' || 'rule' => CardTemplate.heuristic,
    'procedure' => CardTemplate.procedure,
    'fact' || 'mechanism' || '' => CardTemplate.mechanism,
    _ => null,
  };
}

/// Reads a current AI `template` value, skipping unknown values.
CardTemplate? templateFromName(String? value) {
  final name = value?.trim().toLowerCase() ?? '';
  for (final template in CardTemplate.values) {
    if (template.name == name) return template;
  }
  return null;
}

/// Removes Cloze markup, for human-readable previews and accessibility labels.
String stripCloze(String value) {
  return value.replaceAll(RegExp(r'\{\{c\d+::(.*?)\}\}'), r'$1');
}
