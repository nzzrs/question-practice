import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/export/domain/card_templates.dart';

void main() {
  test('template names and storage mapping are stable', () {
    expect(CardTemplate.values.map((template) => template.chipLabel), [
      'Definition',
      'Contrast',
      'Cause and effect',
      'Exam tip',
      'Steps',
    ]);
    expect(CardTemplate.values.map((template) => template.label), [
      'Definition',
      'Contrast',
      'Cause and effect',
      'Exam tip',
      'Steps',
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

  test('cause and effect, exam tip and steps scaffolds are exact', () {
    expect(fillScaffold(CardTemplate.mechanism)!.front, contains('[effect]'));
    expect(
      fillScaffold(CardTemplate.mechanism)!.back,
      '[One-line cause and effect].',
    );
    expect(
      fillScaffold(CardTemplate.heuristic)!.front,
      'If a scenario asks [X] but restricts with [Y], which option is always '
      'discarded?',
    );
    expect(
      fillScaffold(CardTemplate.heuristic)!.back,
      'Discard [Z] because [rule].',
    );
    expect(
      fillScaffold(CardTemplate.procedure)!.front,
      'In [process X], what must be true before [next step Y]?',
    );
    expect(
      fillScaffold(CardTemplate.procedure)!.back,
      '[Condition or command].',
    );
  });

  test('definition seeds a raw cloze sentence', () {
    expect(fillScaffold(CardTemplate.definition), isNull);
    expect(seedDefinitionCloze(), 'Definition of {{c1::term}}: {{c2::…}}');
    expect(
      seedDefinitionCloze(term: 'VPC', definition: 'A private network.'),
      'Definition of {{c1::VPC}}: {{c2::A private network.}}',
    );
    expect(
      seedDefinitionCloze(term: 'VPC'),
      'Definition of {{c1::VPC}}: {{c2::…}}',
    );
    expect(
      seedDefinitionCloze(source: 'A VPC is a private network.'),
      '{{c1::VPC}} is {{c2::a private network.}}',
    );
  });

  test('definition parses the term and definition from raw cloze', () {
    final seeded = parseDefinitionCloze(
      'Definition of {{c1::VPC}}: {{c2::A private network.}}',
    );
    expect(seeded.term, 'VPC');
    expect(seeded.definition, 'A private network.');
    expect(seeded.isComplete, isTrue);

    final sentence = parseDefinitionCloze(
      '{{c1::VPC}} is {{c2::a private network}}',
    );
    expect(sentence.term, 'VPC');
    expect(sentence.definition, 'a private network');

    final plainTail = parseDefinitionCloze(
      'Definition of {{c1::VPC}} is a private network.',
    );
    expect(plainTail.term, 'VPC');
    expect(plainTail.definition, 'a private network.');

    final placeholder = parseDefinitionCloze(
      'Definition of {{c1::term}}: {{c2::…}}',
    );
    expect(placeholder.term, isEmpty);
    expect(placeholder.definition, isEmpty);
    expect(placeholder.isComplete, isFalse);

    final termOnly = parseDefinitionCloze('Definition of {{c1::VPC}}:');
    expect(termOnly.term, 'VPC');
    expect(termOnly.definition, isEmpty);
    expect(termOnly.isComplete, isFalse);

    expect(parseDefinitionCloze('No cloze here').isComplete, isFalse);
  });

  test('definition previews the exported Anki front field', () {
    expect(
      definitionPreview('VPC', ''),
      'Definition of {{c1::VPC}}: {{c2::…}}',
    );
    expect(
      definitionPreview('VPC', 'A private network.'),
      'Definition of {{c1::VPC}}: {{c2::A private network.}}',
    );
    expect(
      stripCloze('Definition of {{c1::VPC}}: {{c2::A network.}}'),
      'Definition of VPC: A network.',
    );
  });

  test('legacy and current AI templates map with a fallback', () {
    expect(templateFromLegacyType('contrast'), CardTemplate.contrast);
    expect(templateFromLegacyType('heuristic'), CardTemplate.heuristic);
    expect(templateFromLegacyType('rule'), CardTemplate.heuristic);
    expect(templateFromLegacyType('procedure'), CardTemplate.procedure);
    expect(templateFromLegacyType('fact'), CardTemplate.mechanism);
    expect(templateFromLegacyType(null), CardTemplate.mechanism);
    expect(templateFromLegacyType('unknown'), isNull);
    expect(templateFromName('definition'), CardTemplate.definition);
    expect(templateFromName('Cause and effect'), CardTemplate.mechanism);
    expect(templateFromName('exam tip'), CardTemplate.heuristic);
    expect(templateFromName(null), CardTemplate.mechanism);
    expect(templateFromName('unknown'), CardTemplate.mechanism);
  });

  test('duplicate detection ignores case, punctuation and cloze markup', () {
    expect(
      isDuplicateCardText('Which layer owns IP?', 'which layer owns IP'),
      isTrue,
    );
    expect(
      isDuplicateCardText(
        '{{c1::VPC}} is a private network',
        'VPC is a private network',
      ),
      isTrue,
    );
    expect(
      isDuplicateCardText(
        'Which layer owns IP addresses?',
        'Which layer owns MAC addresses?',
      ),
      isFalse,
    );
  });

  test('duplicate ideas and variants are filtered against existing cards', () {
    final ideas = [
      const SuggestedCardIdea(
        template: CardTemplate.contrast,
        variants: [
          SuggestedCard(
            front: 'Which layer owns IP addresses?',
            back: 'The network layer.',
            template: CardTemplate.contrast,
          ),
          SuggestedCard(
            front: 'Which layer owns MAC addresses?',
            back: 'The data link layer.',
            template: CardTemplate.contrast,
            variantIndex: 1,
          ),
        ],
      ),
      const SuggestedCardIdea(
        template: CardTemplate.mechanism,
        variants: [
          SuggestedCard(
            front: 'Which layer owns IP addresses',
            back: 'The network layer.',
            template: CardTemplate.mechanism,
          ),
        ],
      ),
      const SuggestedCardIdea(
        template: CardTemplate.procedure,
        variants: [
          SuggestedCard(
            front: 'Why does a private subnet need NAT?',
            back: 'To reach the internet.',
            template: CardTemplate.procedure,
          ),
        ],
      ),
    ];

    final filtered = filterDuplicateIdeas(
      ideas,
      existingTexts: const ['which layer owns ip addresses'],
    );

    expect(filtered, hasLength(2));
    expect(filtered.first.variants, hasLength(1));
    expect(
      filtered.first.variants.single.front,
      'Which layer owns MAC addresses?',
    );
    expect(filtered.last.variants.single.front, contains('NAT'));
  });
}
