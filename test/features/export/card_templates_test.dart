import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/export/domain/card_templates.dart';

void main() {
  test('template names and storage mapping are stable', () {
    expect(CardTemplate.values.map((template) => template.chipLabel), [
      'Definition / term',
      'Contrast / difference',
      'Mechanism / cause-effect',
      'Exam heuristic',
      'Phase transition / procedure',
    ]);
    expect(CardTemplate.values.map((template) => template.label), [
      'Definition',
      'Contrast',
      'Mechanism',
      'Exam heuristic',
      'Procedure',
    ]);
    expect(CardTemplate.values.map((template) => template.cognitiveType), [
      CognitiveType.concept,
      CognitiveType.contrast,
      CognitiveType.fact,
      CognitiveType.heuristic,
      CognitiveType.heuristic,
    ]);
  });

  test('contrast scaffold names the error wrong and correct answers', () {
    final scaffold = fillScaffold(
      CardTemplate.contrast,
      wrongAnswer: 'Wrong',
      correctAnswer: 'Correct',
    )!;

    expect(
      scaffold.front,
      'What is the key difference between Wrong and Correct on [criterion]?',
    );
    expect(
      scaffold.back,
      'Wrong does [behavior A], while Correct does [behavior B].',
    );
  });

  test('mechanism, heuristic and procedure scaffolds are exact', () {
    expect(fillScaffold(CardTemplate.mechanism)!.front, contains('[effect]'));
    expect(
      fillScaffold(CardTemplate.heuristic)!.front,
      'If a scenario asks [X] but restricts with [Y], which option is always '
      'discarded?',
    );
    expect(
      fillScaffold(CardTemplate.procedure)!.front,
      'In [process X], what must be true before [next step Y]?',
    );
  });

  test('definition has no basic scaffold and previews the cloze field', () {
    expect(fillScaffold(CardTemplate.definition), isNull);
    expect(
      definitionPreview('VPC', ''),
      'Definition of {{c1::VPC}}: {{c2::…}}',
    );
    expect(
      definitionPreview('VPC', 'A private network.'),
      'Definition of {{c1::VPC}}: {{c2::A private network.}}',
    );
  });

  test('legacy types map to the current templates', () {
    expect(templateFromLegacyType('contrast'), CardTemplate.contrast);
    expect(templateFromLegacyType('heuristic'), CardTemplate.heuristic);
    expect(templateFromLegacyType('rule'), CardTemplate.heuristic);
    expect(templateFromLegacyType('procedure'), CardTemplate.procedure);
    expect(templateFromLegacyType('fact'), CardTemplate.mechanism);
    expect(templateFromLegacyType(null), CardTemplate.mechanism);
    expect(templateFromLegacyType('unknown'), isNull);
    expect(templateFromName('definition'), CardTemplate.definition);
    expect(templateFromName('unknown'), isNull);
  });
}
