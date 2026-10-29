import 'dart:convert';

import '../../../core/domain/models.dart';
import '../../../core/platform/anki_gateway.dart';

class ExportSelection {
  const ExportSelection({
    this.concepts = const [],
    this.errorCards = const [],
    this.manualCards = const [],
  });

  final List<Concept> concepts;
  final List<ErrorCard> errorCards;
  final List<ManualCard> manualCards;

  int get total => concepts.length + errorCards.length + manualCards.length;
  bool get isEmpty => total == 0;

  Iterable<int> get conceptIds => concepts.map((concept) => concept.id);
  Iterable<int> get errorCardIds => errorCards.map((card) => card.id);
  Iterable<int> get manualCardIds => manualCards.map((card) => card.id);
}

class ExportFiles {
  const ExportFiles({
    required this.concepts,
    required this.errors,
    required this.basic,
  });

  final String concepts;
  final String errors;
  final String basic;

  bool get hasConcepts => concepts.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
  bool get hasBasic => basic.isNotEmpty;
}

class AnkiNoteBuilder {
  const AnkiNoteBuilder();

  static const _html = HtmlEscape(HtmlEscapeMode.element);

  String conceptCloze(String term, String definition) {
    final safeTerm = _escapeCloze(term);
    final safeDefinition = _escapeCloze(definition);
    return 'Definition of {{c1::$safeTerm}}: {{c2::$safeDefinition}}';
  }

  String html(String value) {
    return _html
        .convert(value.trim())
        .replaceAll('\t', ' ')
        .replaceAll('\r\n', '<br>')
        .replaceAll('\n', '<br>');
  }

  List<AnkiNote> notes(
    ExportSelection selection, {
    String defaultDeck = 'Question Practice',
    Map<String, String> deckByTopic = const {},
  }) {
    String deckFor(String topicName) {
      final configured = deckByTopic[topicName.trim()];
      if (configured != null && configured.trim().isNotEmpty) {
        return configured.trim();
      }
      return defaultDeck;
    }

    return [
      for (final concept in selection.concepts)
        AnkiNote(
          model: AnkiModel.concept,
          deckName: deckFor(concept.topicName),
          fields: [conceptCloze(concept.term, concept.definition)],
          tags: _tags(concept.topicName),
        ),
      for (final card in selection.errorCards)
        AnkiNote(
          model: AnkiModel.error,
          deckName: deckFor(card.topicName),
          fields: [
            html(card.question),
            html(card.wrongAnswer),
            html(card.correctAnswer),
            html(card.bias),
            html(card.vaccine),
          ],
          tags: _tags(card.topicName),
        ),
      for (final card in selection.manualCards)
        AnkiNote(
          model: AnkiModel.basic,
          deckName: deckFor(card.topicName),
          fields: [html(card.question), html(card.answer)],
        ),
    ];
  }

  ExportFiles files(ExportSelection selection) {
    return ExportFiles(
      concepts: [
        for (final concept in selection.concepts)
          conceptCloze(concept.term, concept.definition),
      ].join('\n'),
      errors: [
        for (final card in selection.errorCards)
          [
            html(card.question),
            html(card.wrongAnswer),
            html(card.correctAnswer),
            html(card.bias),
            html(card.vaccine),
          ].join('\t'),
      ].join('\n'),
      basic: [
        for (final card in selection.manualCards)
          [html(card.question), html(card.answer)].join('\t'),
      ].join('\n'),
    );
  }

  String _escapeCloze(String value) {
    return html(value)
        .replaceAll('{{', '{ {')
        .replaceAll('}}', '} }')
        .replaceAll('::', ': :');
  }

  List<String> _tags(String topicName) {
    final slug = topicName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return ['question-practice', if (slug.isNotEmpty) 'topic-$slug'];
  }
}
