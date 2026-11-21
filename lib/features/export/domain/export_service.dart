import 'dart:io';

import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/card_repository.dart';
import '../../../core/data/practice_repository.dart';
import '../../../core/domain/models.dart';
import '../../../core/platform/anki_gateway.dart';
import 'anki_note_builder.dart';

class ExportOutcome {
  const ExportOutcome({
    required this.success,
    required this.added,
    required this.failed,
    required this.message,
  });

  final bool success;
  final int added;
  final int failed;
  final String message;
}

class ExportService {
  ExportService({
    required AnkiGateway gateway,
    required CardRepository cards,
    required PracticeRepository practices,
    required Clock clock,
    AnkiNoteBuilder builder = const AnkiNoteBuilder(),
  }) : _gateway = gateway,
       _cards = cards,
       _practices = practices,
       _clock = clock,
       _builder = builder;

  final AnkiGateway _gateway;
  final CardRepository _cards;
  final PracticeRepository _practices;
  final Clock _clock;
  final AnkiNoteBuilder _builder;

  AnkiNoteBuilder get builder => _builder;

  Future<ExportOutcome> exportToAnki({
    required String deckName,
    required ExportSelection selection,
  }) async {
    if (selection.isEmpty) {
      return const ExportOutcome(
        success: false,
        added: 0,
        failed: 0,
        message: 'Select at least one card.',
      );
    }
    final status = await _gateway.status();
    if (!status.installed) {
      return const ExportOutcome(
        success: false,
        added: 0,
        failed: 0,
        message: 'AnkiDroid is not installed.',
      );
    }
    if (!status.apiAvailable) {
      return const ExportOutcome(
        success: false,
        added: 0,
        failed: 0,
        message: 'Enable the AnkiDroid API in AnkiDroid settings, then retry.',
      );
    }
    if (!status.permissionGranted) {
      return const ExportOutcome(
        success: false,
        added: 0,
        failed: 0,
        message: 'Grant AnkiDroid database permission, then retry.',
      );
    }
    if (selection.concepts.isNotEmpty && !status.conceptModelAvailable) {
      return const ExportOutcome(
        success: false,
        added: 0,
        failed: 0,
        message: 'AnkiDroid needs a Cloze note type for concept cards. Create one there, then retry.',
      );
    }

    final defaultDeck = deckName.trim().isEmpty
        ? 'Question Practice'
        : deckName.trim();
    final topics = await _practices.allTopics();
    final deckByTopic = <String, String>{
      for (final topic in topics)
        if (topic.ankiDeck != null && topic.ankiDeck!.trim().isNotEmpty)
          topic.name: topic.ankiDeck!.trim(),
    };
    final notes = _builder.notes(
      selection,
      defaultDeck: defaultDeck,
      deckByTopic: deckByTopic,
    );
    final result = await _gateway.importNotes(notes: notes);
    final success = result.failed == 0 && result.added == notes.length;
    if (success) {
      await _cards.markExported(
        conceptIds: selection.conceptIds.toList(),
        manualCardIds: selection.manualCardIds.toList(),
        exportedAt: _clock.now().toUtc(),
      );
      await _gateway.triggerSync();
    }
    return ExportOutcome(
      success: success,
      added: result.added,
      failed: result.failed,
      message: result.message.isEmpty
          ? success
                ? '${result.added} cards sent to AnkiDroid.'
                : 'AnkiDroid rejected some cards.'
          : result.message,
    );
  }

  Future<List<File>> writeFiles(ExportSelection selection) async {
    final directory = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(_clock.now());
    final files = _builder.files(selection);
    final result = <File>[];
    if (files.hasConcepts) {
      final file = File(
        p.join(directory.path, 'question-practice-concepts-$stamp.txt'),
      );
      await file.writeAsString(files.concepts);
      result.add(file);
    }
    if (files.hasBasic) {
      final file = File(
        p.join(directory.path, 'question-practice-basic-$stamp.tsv'),
      );
      await file.writeAsString(files.basic);
      result.add(file);
    }
    return result;
  }

  Future<void> shareFiles(ExportSelection selection) async {
    final files = await writeFiles(selection);
    if (files.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Question Practice cards',
        text: 'Anki-compatible cards from Question Practice.',
        files: [for (final file in files) XFile(file.path)],
      ),
    );
  }

  /// Serializes saved notes as human-readable plain text.
  String notesText(List<Note> notes) {
    final buffer = StringBuffer('Question Practice notes\n');
    buffer.writeln('${notes.length} note${notes.length == 1 ? '' : 's'}');
    for (final note in notes) {
      buffer.writeln();
      buffer.writeln('---');
      final topic = note.topicName.trim();
      if (topic.isNotEmpty) buffer.writeln('# $topic');
      buffer.writeln(note.text.trim());
      if (note.context.trim().isNotEmpty) {
        buffer.writeln('Context: ${note.context.trim()}');
      }
      final status = note.hasCard
          ? 'Card made'
          : note.isKept
          ? 'Kept'
          : 'In review';
      buffer.writeln('Status: $status');
    }
    return buffer.toString();
  }

  /// Writes all notes to a text file and opens the share sheet.
  Future<void> shareNotes(List<Note> notes) async {
    if (notes.isEmpty) return;
    final directory = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(_clock.now());
    final file = File(
      p.join(directory.path, 'question-practice-notes-$stamp.txt'),
    );
    await file.writeAsString(notesText(notes));
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Question Practice notes',
        text: 'Saved notes from Question Practice.',
        files: [XFile(file.path)],
      ),
    );
  }
}
