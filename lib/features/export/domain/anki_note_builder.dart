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

  /// Builds a cloze card whose front names the topic and subtopic.
  String conceptCloze(
    String term,
    String definition, {
    String topicName = '',
    String subtopic = '',
  }) {
    final safeTerm = _escapeCloze(term);
    final safeDefinition = _escapeCloze(definition);
    final context = _contextPrefix(topicName, subtopic);
    return '${context}Definition of {{c1::$safeTerm}}: {{c2::$safeDefinition}}';
  }

  List<String> conceptFields(Concept concept) {
    return [
      conceptCloze(
        concept.term,
        concept.definition,
        topicName: concept.topicName,
        subtopic: concept.subtopic,
      ),
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
          tags: _tags(concept.topicName, concept.subtopic),
        ),
      for (final card in selection.manualCards)
        AnkiNote(
          model: AnkiModel.basic,
          deckName: deckFor(card.topicName),
          fields: [html(card.question), html(card.answer)],
          tags: _tags(card.topicName, card.subtopic),
        ),
    ];
  }

  ExportFiles files(ExportSelection selection) {
    return ExportFiles(
      concepts: [
        for (final concept in selection.concepts)
          conceptFields(concept).join('\t'),
      ].join('\n'),
      basic: [
        for (final card in selection.manualCards)
          [html(card.question), html(card.answer)].join('\t'),
      ].join('\n'),
    );
  }

  String _contextPrefix(String topicName, String subtopic) {
    final topic = topicName.trim();
    final sub = subtopic.trim();
    if (topic.isEmpty && sub.isEmpty) return '';
    if (topic.isNotEmpty && sub.isNotEmpty) return '[$topic / $sub] ';
    return '[${topic.isEmpty ? sub : topic}] ';
  }

  String _escapeCloze(String value) {
    return html(value)
        .replaceAll('{{', '{ {')
        .replaceAll('}}', '} }')
        .replaceAll('::', ': :');
  }

  /// Hierarchical Anki tags derived from the simulator structure.
  List<String> _tags(String topicName, String subtopic) {
    return [
      'question-practice',
      if (_slug(topicName).isNotEmpty) 'topic::${_slug(topicName)}',
      if (_slug(subtopic).isNotEmpty) 'subtopic::${_slug(subtopic)}',
    ];
  }

  String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
