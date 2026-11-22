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
import 'topic_update_models.dart';

/// Raised when a file cannot be used to update the selected topic.
class TopicFileException implements Exception {
  const TopicFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Exports one whole topic and prepares safe practice updates from a file.
///
/// The payload uses the documented practice import format with the topic's
/// score thresholds added. Exported questions carry their database id as
/// `sourceId`; an update maps that identity back to the stored question and
/// falls back to the trimmed prompt.
class TopicEditService {
  TopicEditService({
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

  /// Builds one topic with every practice in the documented import format.
  Future<Map<String, dynamic>> buildTopicPayload(int topicId) async {
    final topic = await _practices.topicById(topicId);
    if (topic == null) {
      throw const TopicFileException('This topic no longer exists.');
    }
    final practices = await _practices.practicesForTopic(topicId);
    final practicePayloads = <Map<String, dynamic>>[];
    for (final practice in practices) {
      final questions = await _practices.questionsForPractice(practice.id);
      practicePayloads.add(<String, dynamic>{
        'name': practice.name,
        'description': practice.description,
        'questions': <Map<String, dynamic>>[
          for (final question in questions) _questionJson(question),
        ],
      });
    }
    return <String, dynamic>{
      'formatVersion': 1,
      'topics': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': topic.name,
          'description': topic.description,
          if (topic.priority != null) 'priority': topic.priority,
          'minimumScore': topic.minimumScore,
          'targetScore': topic.targetScore,
          'practices': practicePayloads,
        },
      ],
    };
  }

  String encodePayload(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<File> writeTopicJson(int topicId) async {
    final payload = await buildTopicPayload(topicId);
    final directory = await _temporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(_clock.now());
    final file = File(
      p.join(directory.path, 'question-practice-topic-$topicId-$stamp.json'),
    );
    await file.writeAsString(encodePayload(payload));
    return file;
  }

  /// Writes the topic JSON and opens the system share sheet.
  Future<File> shareTopicJson(int topicId) async {
    final file = await writeTopicJson(topicId);
    await _shareFile(file);
    return file;
  }

  /// Validates a picked file and diffs it against the stored topic.
  Future<TopicUpdatePreview> previewUpdateBytes(
    Uint8List bytes, {
    required String fileName,
    required int topicId,
  }) async {
    final preview = await _importService.previewBytes(
      bytes,
      fileName: fileName,
    );
    return previewUpdate(preview, topicId: topicId);
  }

  /// Text variant used by tests and content already read from storage.
  Future<TopicUpdatePreview> previewUpdateText(
    String text, {
    required String fileName,
    required int topicId,
  }) async {
    final preview = await _importService.previewText(text, fileName: fileName);
    return previewUpdate(preview, topicId: topicId);
  }

  /// Diffs a validated import preview against the stored topic.
  Future<TopicUpdatePreview> previewUpdate(
    ImportPreview preview, {
    required int topicId,
  }) async {
    final topic = await _practices.topicById(topicId);
    if (topic == null) {
      throw const TopicFileException('This topic no longer exists.');
    }
    final fileTopic = _findTopic(preview, topic.name);
    if (fileTopic == null) {
      throw TopicFileException(
        'This file does not contain the topic "${topic.name}". '
        'Download the topic JSON first, edit that file, then update again.',
      );
    }

    final storedPractices = await _practices.practicesForTopic(topicId);
    final storedByName = <String, Practice>{
      for (final practice in storedPractices)
        _normalizeName(practice.name): practice,
    };
    final practices = <TopicPracticeUpdatePreview>[];
    for (final filePractice in fileTopic.practices) {
      final stored = storedByName[_normalizeName(filePractice.name)];
      if (stored == null) {
        practices.add(
          TopicPracticeUpdatePreview(
            name: filePractice.name,
            description: filePractice.description,
            contentHash: filePractice.contentHash,
            questions: [
              for (
                var index = 0;
                index < filePractice.questions.length;
                index++
              )
                PracticeQuestionUpdate(
                  question: filePractice.questions[index],
                  position: index,
                ),
            ],
            deletedQuestions: const [],
          ),
        );
        continue;
      }
      practices.add(
        await _previewPractice(existing: stored, file: filePractice),
      );
    }

    final description = fileTopic.hasDescription ? fileTopic.description : null;
    final priority = fileTopic.hasPriority ? fileTopic.priority : null;
    final minimumScore = fileTopic.hasMinimumScore
        ? fileTopic.minimumScore
        : null;
    final targetScore = fileTopic.hasTargetScore ? fileTopic.targetScore : null;
    final metadataChanged =
        (description != null && description != topic.description) ||
        (fileTopic.hasPriority && priority != topic.priority) ||
        (minimumScore != null && minimumScore != topic.minimumScore) ||
        (targetScore != null && targetScore != topic.targetScore);

    return TopicUpdatePreview(
      topicId: topicId,
      topicName: topic.name,
      fileName: preview.fileName,
      description: description,
      updatePriority: fileTopic.hasPriority,
      priority: priority,
      minimumScore: minimumScore,
      targetScore: targetScore,
      practices: practices,
      hasMetadataChanges: metadataChanged,
    );
  }

  /// Applies a preview in one transaction.
  Future<void> apply(TopicUpdatePreview preview) {
    return _practices.applyTopicUpdate(
      topicId: preview.topicId,
      description: preview.description,
      updatePriority: preview.updatePriority,
      priority: preview.priority,
      minimumScore: preview.minimumScore,
      targetScore: preview.targetScore,
      practices: preview.toPracticeUpdates(),
      importedAt: _clock.now().toUtc(),
    );
  }

  Future<TopicPracticeUpdatePreview> _previewPractice({
    required Practice existing,
    required ImportPractice file,
  }) async {
    final stored = await _practices.questionsForPractice(existing.id);
    final storedById = <int, Question>{
      for (final item in stored) item.id: item,
    };
    final used = <int>{};
    final matchedIds = List<int?>.filled(file.questions.length, null);

    for (var index = 0; index < file.questions.length; index++) {
      final sourceId = int.tryParse(file.questions[index].sourceId);
      if (sourceId == null || used.contains(sourceId)) continue;
      if (!storedById.containsKey(sourceId)) continue;
      matchedIds[index] = sourceId;
      used.add(sourceId);
    }

    for (var index = 0; index < file.questions.length; index++) {
      if (matchedIds[index] != null) continue;
      final prompt = _normalizePrompt(file.questions[index].prompt);
      for (final storedQuestion in stored) {
        if (used.contains(storedQuestion.id)) continue;
        if (_normalizePrompt(storedQuestion.prompt) != prompt) continue;
        matchedIds[index] = storedQuestion.id;
        used.add(storedQuestion.id);
        break;
      }
    }

    final questions = <PracticeQuestionUpdate>[
      for (var index = 0; index < file.questions.length; index++)
        PracticeQuestionUpdate(
          existingQuestionId: matchedIds[index],
          question: file.questions[index],
          position: index,
          changed:
              matchedIds[index] != null &&
              !_sameContent(
                storedById[matchedIds[index]]!,
                file.questions[index],
              ),
        ),
    ];
    final deleted = <Question>[
      for (final item in stored)
        if (!used.contains(item.id)) item,
    ];

    return TopicPracticeUpdatePreview(
      practiceId: existing.id,
      name: existing.name,
      description: file.description,
      descriptionChanged: file.description != existing.description,
      contentHash: file.contentHash,
      questions: questions,
      deletedQuestions: deleted,
    );
  }

  ImportTopic? _findTopic(ImportPreview preview, String topicName) {
    final normalized = _normalizeName(topicName);
    for (final topic in preview.topics) {
      if (_normalizeName(topic.name) == normalized) return topic;
    }
    return null;
  }

  String _normalizeName(String value) => value.trim().toLowerCase();

  String _normalizePrompt(String value) => value.trim();

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
        subject: 'Question Practice topic',
        text: 'Topic JSON from Question Practice.',
        files: [XFile(file.path)],
      ),
    );
  }
}
