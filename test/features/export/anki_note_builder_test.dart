import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/anki_gateway.dart';
import 'package:question_practice/features/export/domain/anki_note_builder.dart';

void main() {
  const builder = AnkiNoteBuilder();

  test('concept cloze uses the requested format', () {
    expect(
      builder.conceptCloze('GCP', 'Google Cloud Platform'),
      'Definition of {{c1::GCP}}: {{c2::Google Cloud Platform}}',
    );
  });

  test('concept cloze has no topic/subtopic prefix', () {
    expect(
      builder.conceptCloze('TCP', 'A reliable transport protocol.'),
      'Definition of {{c1::TCP}}: {{c2::A reliable transport protocol.}}',
    );
    expect(builder.conceptCloze('TCP', 'Definition'), isNot(contains('[')));
  });

  test('cloze content cannot break the cloze syntax', () {
    final text = builder.conceptCloze('A::B', 'x}} y');
    expect(text, 'Definition of {{c1::A: :B}}: {{c2::x} } y}}');
  });

  test('newlines become HTML breaks and tabs become spaces', () {
    expect(builder.html('a\nb\tc'), 'a<br>b c');
  });

  test('concept notes place the expansion in the extra field', () {
    final notes = builder.notes(ExportSelection(concepts: [_concept()]));
    expect(notes.single.model, AnkiModel.concept);
    expect(notes.single.fields, [
      'Definition of {{c1::TCP}}: {{c2::A reliable transport protocol.}}',
      'Transmission Control Protocol',
    ]);
  });

  test('file headers name the columns and the tags column', () {
    final files = builder.files(
      ExportSelection(concepts: [_concept()], manualCards: [_manualCard()]),
    );

    expect(files.concepts, contains('#separator:Tab'));
    expect(files.concepts, contains('#html:true'));
    expect(files.concepts, contains('#notetype:Cloze'));
    expect(files.concepts, contains('#columns:Front\tExtra\tTags'));
    expect(files.concepts, contains('#tags column:3'));

    expect(files.basic, contains('#notetype:Basic'));
    expect(files.basic, contains('#columns:Front\tBack\tTags'));
    expect(files.basic, contains('#tags column:3'));
  });

  test('concept file has three fields and the tag list', () {
    final files = builder.files(ExportSelection(concepts: [_concept()]));
    final row = files.concepts.split('\n').last;
    final fields = row.split('\t');

    expect(fields, hasLength(3));
    expect(fields[0], contains('Definition of {{c1::TCP}}'));
    expect(fields[1], 'Transmission Control Protocol');
    expect(fields[2], 'question-practice topic::networking-basics');
  });

  test('basic file has three fields and the tag list', () {
    final files = builder.files(ExportSelection(manualCards: [_manualCard()]));
    final row = files.basic.split('\n').last;
    final fields = row.split('\t');

    expect(fields, hasLength(3));
    expect(fields[0], 'What is a subnet?');
    expect(fields[1], 'A range of IP addresses.');
    expect(fields[2], 'question-practice topic::networking-basics');
  });

  test('notes follow per-topic deck overrides', () {
    final notes = builder.notes(
      ExportSelection(
        concepts: [_concept()],
        manualCards: [_manualCard(topicName: 'Cloud')],
      ),
      defaultDeck: 'Default deck',
      deckByTopic: const {
        'Networking basics': 'Networking deck',
        'Cloud': 'Cloud deck',
      },
    );
    expect(notes.map((note) => note.deckName), [
      'Networking deck',
      'Cloud deck',
    ]);
  });

  test('basic cards contain only the question and the answer', () {
    final basic = _manualCard();
    final files = builder.files(ExportSelection(manualCards: [basic]));
    final row = files.basic.split('\n').last;
    expect(
      row.split('\t').take(2).join('\t'),
      'What is a subnet?\tA range of IP addresses.',
    );
    expect(files.basic, isNot(contains('IPv4 addresses are split')));

    final note = builder.notes(ExportSelection(manualCards: [basic])).single;
    expect(note.model, AnkiModel.basic);
    expect(note.fields.first, 'What is a subnet?');
    expect(note.fields.last, 'A range of IP addresses.');
  });

  test('direct notes still carry hierarchical tags', () {
    final notes = builder.notes(
      ExportSelection(
        concepts: [_concept()],
        manualCards: [
          _manualCard(topicName: 'Networking basics', subtopic: 'Layer 4'),
        ],
      ),
    );

    expect(notes.first.tags, ['question-practice', 'topic::networking-basics']);
    expect(notes.last.tags, [
      'question-practice',
      'topic::networking-basics',
      'subtopic::layer-4',
    ]);
  });

  test('no exported front or back contains a bracketed topic prefix', () {
    final files = builder.files(
      ExportSelection(concepts: [_concept()], manualCards: [_manualCard()]),
    );
    for (final file in [files.concepts, files.basic]) {
      for (final line in file.split('\n')) {
        if (line.startsWith('#')) continue;
        final fields = line.split('\t');
        expect(fields.first, isNot(contains('[')));
        expect(fields[1], isNot(contains('[')));
      }
    }
  });

  test('files are empty when their selection is empty', () {
    final files = builder.files(const ExportSelection());
    expect(files.concepts, isEmpty);
    expect(files.basic, isEmpty);
  });

  test('tagsFor omits missing parts and keeps prefixes', () {
    expect(AnkiNoteBuilder.tagsFor('', ''), ['question-practice']);
    expect(AnkiNoteBuilder.tagsFor('Networking basics', ''), [
      'question-practice',
      'topic::networking-basics',
    ]);
    expect(AnkiNoteBuilder.tagsFor('', 'Layer 4'), [
      'question-practice',
      'subtopic::layer-4',
    ]);
    expect(AnkiNoteBuilder.tagsFor('Layer 4', 'Layer 4'), [
      'question-practice',
      'topic::layer-4',
      'subtopic::layer-4',
    ]);
  });

  test('cloze escaping and newline handling remain intact', () {
    final text = builder.conceptCloze('A\nB', 'C\nD');
    expect(text, contains('A<br>B'));
    expect(text, contains('C<br>D'));
  });
}

Concept _concept() {
  return Concept(
    id: 1,
    sessionId: 1,
    questionId: 1,
    term: 'TCP',
    definition: 'A reliable transport protocol.',
    extra: 'Transmission Control Protocol',
    context: 'Context',
    topicName: 'Networking basics',
    source: ConceptSource.ai,
    createdAt: DateTime.utc(2026),
    exportedAt: null,
  );
}

ManualCard _manualCard({
  String topicName = 'Networking basics',
  String subtopic = '',
}) {
  return ManualCard(
    id: 3,
    sessionId: 1,
    questionId: 7,
    question: 'What is a subnet?',
    answer: 'A range of IP addresses.',
    context: 'IPv4 addresses are split into networks.',
    topicName: topicName,
    subtopic: subtopic,
    createdAt: DateTime.utc(2026),
    exportedAt: null,
  );
}
