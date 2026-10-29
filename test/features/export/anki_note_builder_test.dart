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

  test('cloze content cannot break the cloze syntax', () {
    final text = builder.conceptCloze('A::B', 'x}} y');
    expect(text, 'Definition of {{c1::A: :B}}: {{c2::x} } y}}');
  });

  test('error cards keep the five-field order', () {
    final card = _errorCard();
    final notes = builder.notes(ExportSelection(errorCards: [card]));
    expect(notes, hasLength(1));
    expect(notes.single.model, AnkiModel.error);
    expect(notes.single.deckName, 'Question Practice');
    expect(notes.single.fields, [
      'Question &lt;one&gt;?',
      'Wrong &amp; answer',
      'Correct answer',
      'Bias line',
      'Vaccine line',
    ]);
  });

  test('newlines become HTML breaks and tabs become spaces', () {
    expect(builder.html('a\nb\tc'), 'a<br>b c');
  });

  test('notes follow per-topic deck overrides', () {
    final notes = builder.notes(
      ExportSelection(
        concepts: [_concept()],
        errorCards: [_errorCard()],
        manualCards: [
          ManualCard(
            id: 2,
            sessionId: 1,
            question: 'Front',
            answer: 'Back',
            topicName: 'Cloud',
            createdAt: DateTime.utc(2026),
            exportedAt: null,
          ),
        ],
      ),
      defaultDeck: 'Default deck',
      deckByTopic: const {
        'Networking basics': 'Networking deck',
        'Cloud': 'Cloud deck',
      },
    );
    expect(notes.map((note) => note.deckName), [
      'Networking deck',
      'Networking deck',
      'Cloud deck',
    ]);
  });

  test('files contain the selected cards only', () {
    final concept = _concept();
    final basic = ManualCard(
      id: 2,
      sessionId: 1,
      question: 'Front',
      answer: 'Back',
      topicName: 'Networking basics',
      createdAt: DateTime.utc(2026),
      exportedAt: null,
    );
    final files = builder.files(
      ExportSelection(concepts: [concept], manualCards: [basic]),
    );
    expect(files.concepts, contains('Definition of {{c1::TCP}}'));
    expect(files.basic, 'Front\tBack');
    expect(files.errors, isEmpty);
  });
}

Concept _concept() {
  return Concept(
    id: 1,
    sessionId: 1,
    questionId: 1,
    term: 'TCP',
    definition: 'Transmission Control Protocol',
    context: 'Context',
    topicName: 'Networking basics',
    source: ConceptSource.ai,
    createdAt: DateTime.utc(2026),
    exportedAt: null,
  );
}

ErrorCard _errorCard() {
  return ErrorCard(
    id: 1,
    questionId: 1,
    sessionId: 1,
    question: 'Question <one>?',
    alternatives: ['Wrong & answer', 'Correct answer'],
    correctIndex: 1,
    wrongIndex: 0,
    reasoning: 'Reason',
    bias: 'Bias line',
    vaccine: 'Vaccine line',
    topicName: 'Networking basics',
    practiceName: 'Practice',
    status: ErrorCardStatus.active,
    createdAt: DateTime.utc(2026),
    lastWrongAt: DateTime.utc(2026),
    dueAt: DateTime.utc(2026, 1, 3),
    detailsCompletedAt: DateTime.utc(2026),
    resolvedAt: null,
    exportedAt: null,
  );
}
