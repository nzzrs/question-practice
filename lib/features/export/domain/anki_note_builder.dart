import 'dart:convert';

import '../../../core/domain/models.dart';
import '../../../core/platform/anki_gateway.dart';

/// Cards chosen for one export. Error cards are no longer exported directly:
/// the review screen turns them into atomic basic cards first.
class ExportSelection {
  const ExportSelection({
    this.concepts = const [],
    this.manualCards = const [],
  });

  final List<Concept> concepts;
  final List<ManualCard> manualCards;

  int get total => concepts.length + manualCards.length;
  bool get isEmpty => total == 0;

  Iterable<int> get conceptIds => concepts.map((concept) => concept.id);
  Iterable<int> get manualCardIds => manualCards.map((card) => card.id);
}

class ExportFiles {
  const ExportFiles({required this.concepts, required this.basic});

  final String concepts;
  final String basic;

  bool get hasConcepts => concepts.isNotEmpty;
  bool get hasBasic => basic.isNotEmpty;
}

class AnkiNoteBuilder {
  const AnkiNoteBuilder();

  static const _html = HtmlEscape(HtmlEscapeMode.element);

  /// Builds a cloze card. Topic and subtopic travel in tags only, never in the
  /// card text.
  String conceptCloze(String term, String definition) {
    final safeTerm = _escapeCloze(term);
    final safeDefinition = _escapeCloze(definition);
    return 'Definition of {{c1::$safeTerm}}: {{c2::$safeDefinition}}';
  }

  List<String> conceptFields(Concept concept) {
    return [
      conceptCloze(concept.term, concept.definition),
      html(concept.extra),
    ];
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
          fields: conceptFields(concept),
          tags: tagsFor(concept.topicName, concept.subtopic),
        ),
      for (final card in selection.manualCards)
        AnkiNote(
          model: AnkiModel.basic,
          deckName: deckFor(card.topicName),
          fields: [html(card.question), html(card.answer)],
          tags: tagsFor(card.topicName, card.subtopic),
        ),
    ];
  }

  ExportFiles files(ExportSelection selection) {
    return ExportFiles(
      concepts: _conceptFile(selection.concepts),
      basic: _basicFile(selection.manualCards),
    );
  }

  String _conceptFile(List<Concept> concepts) {
    if (concepts.isEmpty) return '';
    return [
      '#separator:Tab',
      '#html:true',
      '#notetype:Cloze',
      '#columns:Front\tExtra\tTags',
      '#tags column:3',
      for (final concept in concepts)
        [
          ...conceptFields(concept),
          tagsFor(concept.topicName, concept.subtopic).join(' '),
        ].join('\t'),
    ].join('\n');
  }

  String _basicFile(List<ManualCard> cards) {
    if (cards.isEmpty) return '';
    return [
      '#separator:Tab',
      '#html:true',
      '#notetype:Basic',
      '#columns:Front\tBack\tTags',
      '#tags column:3',
      for (final card in cards)
        [
          html(card.question),
          html(card.answer),
          tagsFor(card.topicName, card.subtopic).join(' '),
        ].join('\t'),
    ].join('\n');
  }

  String _escapeCloze(String value) {
    return html(value)
        .replaceAll('{{', '{ {')
        .replaceAll('}}', '} }')
        .replaceAll('::', ': :');
  }

  /// Hierarchical Anki tags derived from the simulator structure.
  static List<String> tagsFor(String topicName, String subtopic) {
    return [
      'question-practice',
      if (slug(topicName).isNotEmpty) 'topic::${slug(topicName)}',
      if (slug(subtopic).isNotEmpty) 'subtopic::${slug(subtopic)}',
    ];
  }

  /// Stable slug used inside Anki tags.
  static String slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
