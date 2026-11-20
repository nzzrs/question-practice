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

  test('concept cloze prefixes the topic and subtopic', () {
    expect(
      builder.conceptCloze(
        'TCP',
        'A reliable transport protocol.',
        topicName: 'Networking',
        subtopic: 'Layer 4',
      ),
      '[Networking / Layer 4] '
      'Definition of {{c1::TCP}}: {{c2::A reliable transport protocol.}}',
    );
    expect(
      builder.conceptCloze('TCP', 'Definition', topicName: 'Networking'),
      '[Networking] Definition of {{c1::TCP}}: {{c2::Definition}}',
    );
  });

  test('cloze content cannot break the cloze syntax', () {
    final text = builder.conceptCloze('A::B', 'x}} y');
    expect(text, 'Definition of {{c1::A: :B}}: {{c2::x} } y}}');
  });

  test('newlines become HTML breaks and tabs become spaces', () {
    expect(builder.html('a\nb\tc'), 'a<br>b c');
  });

  test('concept notes place the acronym expansion in the extra field', () {
    final notes = builder.notes(ExportSelection(concepts: [_concept()]));
    expect(notes.single.model, AnkiModel.concept);
    expect(notes.single.fields, [
      '[Networking basics] '
          'Definition of {{c1::TCP}}: {{c2::A reliable transport protocol.}}',
      'Transmission Control Protocol',
    ]);
  });

  test('concept files keep the expansion as the second column', () {
    final files = builder.files(ExportSelection(concepts: [_concept()]));
    expect(files.concepts, contains('\tTransmission Control Protocol'));
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
    expect(files.basic, 'What is a subnet?\tA range of IP addresses.');
    expect(files.basic, isNot(contains('IPv4 addresses are split')));

    final note = builder.notes(ExportSelection(manualCards: [basic])).single;
    expect(note.model, AnkiModel.basic);
    expect(note.fields.first, 'What is a subnet?');
    expect(note.fields.last, 'A range of IP addresses.');
  });

  test('tags are hierarchical and derive from topic and subtopic', () {
    final note = builder
        .notes(
          ExportSelection(
            manualCards: [
              _manualCard(topicName: 'Networking basics', subtopic: 'Layer 4'),
            ],
          ),
        )
        .single;
    expect(note.tags, [
      'question-practice',
      'topic::networking-basics',
      'subtopic::layer-4',
    ]);
  });

  test('files contain the selected cards only', () {
    final concept = _concept();
    final basic = _manualCard();
    final files = builder.files(
      ExportSelection(concepts: [concept], manualCards: [basic]),
    );
    expect(files.concepts, contains('Definition of {{c1::TCP}}'));
    expect(files.basic, contains('What is a subnet?'));
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
