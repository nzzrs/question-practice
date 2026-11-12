import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/practice_repository.dart';
import '../../../core/domain/models.dart';
import '../../import/domain/import_models.dart';
import '../../import/domain/import_service.dart';
import 'practice_update_models.dart';

/// Raised when a file cannot be used to update the selected practice.
class PracticeFileException implements Exception {
  const PracticeFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Exports one practice and prepares safe question updates from a file.
///
/// Exported questions carry their database id as `sourceId`. An update maps
/// that identity back to the stored question, falling back to the trimmed
/// prompt for files written before identities existed.
class PracticeEditService {
  PracticeEditService({
    required PracticeRepository practices,
    required ImportService importService,
    required Clock clock,
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function(File file)? shareFile,
  }) : _practices = practices,
       _importService = importService,
       _clock = clock,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _shareFile = shareFile ?? _shareWithSystem;

  final PracticeRepository _practices;
  final ImportService _importService;
  final Clock _clock;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(File file) _shareFile;

  /// Builds one topic and one practice in the documented import format.
  Future<Map<String, dynamic>> buildPracticePayload(int practiceId) async {
    final practice = await _practices.practiceById(practiceId);
    if (practice == null) {
      throw const PracticeFileException('This practice no longer exists.');
    }
    final topic = await _practices.topicById(practice.topicId);
    if (topic == null) {
      throw const PracticeFileException('The topic no longer exists.');
    }
    final questions = await _practices.questionsForPractice(practiceId);
    return <String, dynamic>{
      'formatVersion': 1,
      'topics': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': topic.name,
          'description': topic.description,
          if (topic.priority != null) 'priority': topic.priority,
          'practices': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': practice.name,
              'description': practice.description,
              'questions': <Map<String, dynamic>>[
                for (final question in questions) _questionJson(question),
              ],
            },
          ],
        },
      ],
    };
  }

  String encodePayload(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<File> writePracticeJson(int practiceId) async {
    final payload = await buildPracticePayload(practiceId);
    final directory = await _temporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(_clock.now());
    final file = File(
      p.join(
        directory.path,
        'question-practice-practice-$practiceId-$stamp.json',
      ),
    );
    await file.writeAsString(encodePayload(payload));
    return file;
  }

  /// Writes the practice JSON and opens the system share sheet.
  Future<File> sharePracticeJson(int practiceId) async {
    final file = await writePracticeJson(practiceId);
    await _shareFile(file);
    return file;
  }

  /// Validates a picked file and diffs it against the stored practice.
  Future<PracticeUpdatePreview> previewUpdateBytes(
    Uint8List bytes, {
    required String fileName,
    required int practiceId,
  }) async {
    final preview = await _importService.previewBytes(
      bytes,
      fileName: fileName,
    );
    return previewUpdate(preview, practiceId: practiceId);
  }

  /// Text variant used by tests and content already read from storage.
  Future<PracticeUpdatePreview> previewUpdateText(
    String text, {
    required String fileName,
    required int practiceId,
  }) async {
    final preview = await _importService.previewText(text, fileName: fileName);
    return previewUpdate(preview, practiceId: practiceId);
  }

  /// Diffs a validated import preview against the stored practice.
  Future<PracticeUpdatePreview> previewUpdate(
    ImportPreview preview, {
    required int practiceId,
  }) async {
    final practice = await _practices.practiceById(practiceId);
    if (practice == null) {
      throw const PracticeFileException('This practice no longer exists.');
    }
    final topic = await _practices.topicById(practice.topicId);
    if (topic == null) {
      throw const PracticeFileException('The topic no longer exists.');
    }
    final filePractice = _findPractice(
      preview,
      topicName: topic.name,
      practiceName: practice.name,
    );
    if (filePractice == null) {
      throw PracticeFileException(
        'This file does not contain "${practice.name}" in "${topic.name}". '
        'Download the practice JSON first, edit that file, then update again.',
      );
    }

    final stored = await _practices.questionsForPractice(practiceId);
    final storedById = <int, Question>{
      for (final item in stored) item.id: item,
    };
    final used = <int>{};
    final matchedIds = List<int?>.filled(filePractice.questions.length, null);

    for (var index = 0; index < filePractice.questions.length; index++) {
      final sourceId = int.tryParse(filePractice.questions[index].sourceId);
      if (sourceId == null || used.contains(sourceId)) continue;
      if (!storedById.containsKey(sourceId)) continue;
      matchedIds[index] = sourceId;
      used.add(sourceId);
    }

    for (var index = 0; index < filePractice.questions.length; index++) {
      if (matchedIds[index] != null) continue;
      final prompt = _normalizePrompt(filePractice.questions[index].prompt);
      for (final storedQuestion in stored) {
        if (used.contains(storedQuestion.id)) continue;
        if (_normalizePrompt(storedQuestion.prompt) != prompt) continue;
        matchedIds[index] = storedQuestion.id;
        used.add(storedQuestion.id);
        break;
      }
    }

    final questions = <PracticeQuestionUpdate>[
      for (var index = 0; index < filePractice.questions.length; index++)
        PracticeQuestionUpdate(
          existingQuestionId: matchedIds[index],
          question: filePractice.questions[index],
          position: index,
          changed:
              matchedIds[index] != null &&
              !_sameContent(
                storedById[matchedIds[index]]!,
                filePractice.questions[index],
              ),
        ),
    ];
    final deleted = <Question>[
      for (final item in stored)
        if (!used.contains(item.id)) item,
    ];

    return PracticeUpdatePreview(
      practiceId: practiceId,
      topicName: topic.name,
      practiceName: practice.name,
      fileName: preview.fileName,
      questions: questions,
      deletedQuestions: deleted,
      contentHash: filePractice.contentHash,
    );
  }

  /// Applies a preview in one transaction.
  Future<void> apply(PracticeUpdatePreview preview) {
    return _practices.applyPracticeUpdate(
      practiceId: preview.practiceId,
      questions: preview.questions,
      deletedQuestionIds: preview.deletedQuestionIds,
      contentHash: preview.contentHash,
      importedAt: _clock.now().toUtc(),
    );
  }

  Map<String, dynamic> _questionJson(Question question) {
    return <String, dynamic>{
      'sourceId': question.id.toString(),
      'prompt': question.prompt,
      if (question.subtopic.trim().isNotEmpty)
        'subtopic': question.subtopic.trim(),
      'alternatives': question.alternatives,
      if (question.correctIndexes.length == 1)
        'correctIndex': question.correctIndexes.first
      else
        'correctIndexes': question.correctIndexes,
      'explanation': question.explanation,
      'alternativeExplanations': question.alternativeExplanations,
    };
  }

  ImportPractice? _findPractice(
    ImportPreview preview, {
    required String topicName,
    required String practiceName,
  }) {
    final normalizedTopic = topicName.trim().toLowerCase();
    final normalizedPractice = practiceName.trim().toLowerCase();
    for (final topic in preview.topics) {
      if (topic.name.trim().toLowerCase() != normalizedTopic) continue;
      for (final practice in topic.practices) {
        if (practice.name.trim().toLowerCase() == normalizedPractice) {
          return practice;
        }
      }
    }
    return null;
  }

  bool _sameContent(Question stored, QuestionDraft file) {
    return _normalizePrompt(stored.prompt) == _normalizePrompt(file.prompt) &&
        _sameList(stored.alternatives, file.alternatives) &&
        _sameIndexes(stored.correctIndexes, file.correctIndexes) &&
        stored.explanation.trim() == file.explanation.trim() &&
        _sameList(
          stored.alternativeExplanations,
          file.alternativeExplanations,
        ) &&
        stored.subtopic.trim() == file.subtopic.trim();
  }

  String _normalizePrompt(String value) => value.trim();

  bool _sameList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  bool _sameIndexes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    final rightSet = right.toSet();
    return left.every(rightSet.contains);
  }

  static Future<void> _shareWithSystem(File file) {
    return SharePlus.instance.share(
      ShareParams(
        subject: 'Question Practice practice',
        text: 'Practice JSON from Question Practice.',
        files: [XFile(file.path)],
      ),
    );
  }
}
