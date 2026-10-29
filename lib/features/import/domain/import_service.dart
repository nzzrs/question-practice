import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:json_schema/json_schema.dart';

import '../../../core/data/practice_repository.dart';
import '../../../core/domain/models.dart';
import 'import_models.dart';

class ImportService {
  ImportService({
    required PracticeRepository repository,
    required Clock clock,
    AssetBundle? bundle,
  }) : _repository = repository,
       _clock = clock,
       _bundle = bundle ?? rootBundle;

  static const maxFileBytes = 10 * 1024 * 1024;
  static const maxQuestions = 5000;

  final PracticeRepository _repository;
  final Clock _clock;
  final AssetBundle _bundle;
  Future<JsonSchema>? _schema;

  Future<ImportPreview> previewBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    if (bytes.lengthInBytes > maxFileBytes) {
      throw const ImportException([
        ImportIssue(path: '/', message: 'The file is larger than 10 MB.'),
      ]);
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const ImportException([
        ImportIssue(path: '/', message: 'The file is not valid UTF-8 text.'),
      ]);
    }
    return previewText(text, fileName: fileName);
  }

  Future<ImportPreview> previewText(
    String rawText, {
    required String fileName,
  }) async {
    final text = rawText.startsWith('\uFEFF') ? rawText.substring(1) : rawText;
    if (text.trim().isEmpty) {
      throw const ImportException([
        ImportIssue(path: '/', message: 'The file is empty.'),
      ]);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw ImportException(_jsonIssues(error, text));
    }

    await _validateSchema(decoded);
    final payload = decoded as Map<String, dynamic>;
    final topics = _readTopics(payload);
    final notes = await _duplicateNotes(topics);
    return ImportPreview(topics: topics, notes: notes, fileName: fileName);
  }

  Future<ImportResult> import(ImportPreview preview) {
    return _repository.transaction(() async {
      var topicsCreated = 0;
      var topicsReused = 0;
      var practicesImported = 0;
      var practicesSkipped = 0;
      var questionsImported = 0;
      final now = _clock.now().toUtc();

      for (final topic in preview.topics) {
        final existingTopic = await _repository.findTopicByName(topic.name);
        final int topicId;
        if (existingTopic == null) {
          topicId = await _repository.createTopic(
            name: topic.name,
            description: topic.description,
            priority: topic.priority,
            createdAt: now,
          );
          topicsCreated++;
        } else {
          topicId = existingTopic.id;
          topicsReused++;
        }

        for (final practice in topic.practices) {
          final duplicate = await _repository.findPracticeByHash(
            topicId,
            practice.contentHash,
          );
          if (duplicate != null) {
            practicesSkipped++;
            continue;
          }

          var name = practice.name;
          var suffix = 2;
          while (await _repository.findPracticeByName(topicId, name) != null) {
            name = '${practice.name} ($suffix)';
            suffix++;
          }

          final practiceId = await _repository.createPractice(
            topicId: topicId,
            name: name,
            description: practice.description,
            contentHash: practice.contentHash,
            importedAt: now,
          );
          await _repository.createQuestions(practiceId, practice.questions);
          practicesImported++;
          questionsImported += practice.questions.length;
        }
      }

      return ImportResult(
        topicsCreated: topicsCreated,
        topicsReused: topicsReused,
        practicesImported: practicesImported,
        practicesSkipped: practicesSkipped,
        questionsImported: questionsImported,
      );
    });
  }

  Future<void> _validateSchema(dynamic instance) async {
    final schema = await (_schema ??= _loadSchema());
    final results = schema.validate(instance);
    if (!results.isValid) {
      throw ImportException([
        for (final error in results.errors)
          ImportIssue(path: error.instancePath, message: error.message),
      ]);
    }
  }

  Future<JsonSchema> _loadSchema() async {
    final source = await _bundle.loadString(
      'assets/schema/practice_import.schema.json',
    );
    return JsonSchema.create(jsonDecode(source));
  }

  List<ImportTopic> _readTopics(Map<String, dynamic> payload) {
    final issues = <ImportIssue>[];
    final topics = <ImportTopic>[];
    final topicNames = <String>{};
    var totalQuestions = 0;

    final rawTopics = payload['topics'] as List<dynamic>;
    for (var topicIndex = 0; topicIndex < rawTopics.length; topicIndex++) {
      final rawTopic = rawTopics[topicIndex] as Map<String, dynamic>;
      final topicPath = '/topics/$topicIndex';
      final topicName = (rawTopic['name'] as String).trim();
      final normalizedTopicName = topicName.toLowerCase();
      if (!topicNames.add(normalizedTopicName)) {
        issues.add(
          ImportIssue(
            path: '$topicPath/name',
            message:
                'Topic names must be unique; "$topicName" appears more than once.',
          ),
        );
      }
      final priority = rawTopic['priority'] as int?;
      if (priority != null && (priority < 1 || priority > 5)) {
        issues.add(
          ImportIssue(
            path: '$topicPath/priority',
            message: 'Priority must be between 1 and 5.',
          ),
        );
      }

      final practices = <ImportPractice>[];
      final practiceNames = <String>{};
      final rawPractices = rawTopic['practices'] as List<dynamic>;
      for (
        var practiceIndex = 0;
        practiceIndex < rawPractices.length;
        practiceIndex++
      ) {
        final rawPractice = rawPractices[practiceIndex] as Map<String, dynamic>;
        final practicePath = '$topicPath/practices/$practiceIndex';
        final practiceName = (rawPractice['name'] as String).trim();
        final normalizedPracticeName = practiceName.toLowerCase();
        if (!practiceNames.add(normalizedPracticeName)) {
          issues.add(
            ImportIssue(
              path: '$practicePath/name',
              message:
                  'Practice names must be unique within a topic; "$practiceName" appears more than once.',
            ),
          );
        }

        final questions = <QuestionDraft>[];
        final rawQuestions = rawPractice['questions'] as List<dynamic>;
        for (
          var questionIndex = 0;
          questionIndex < rawQuestions.length;
          questionIndex++
        ) {
          final rawQuestion =
              rawQuestions[questionIndex] as Map<String, dynamic>;
          final questionPath = '$practicePath/questions/$questionIndex';
          final prompt = (rawQuestion['prompt'] as String).trim();
          final alternatives = (rawQuestion['alternatives'] as List<dynamic>)
              .map((item) => item as String)
              .toList(growable: false);
          final explanations =
              (rawQuestion['alternativeExplanations'] as List<dynamic>)
                  .map((item) => item as String)
                  .toList(growable: false);
          final correctIndexes = _readCorrectIndexes(
            rawQuestion,
            questionPath,
            issues,
          );
          final explanation = (rawQuestion['explanation'] as String).trim();

          if (prompt.isEmpty) {
            _empty(issues, '$questionPath/prompt', 'Prompt');
          }
          if (explanation.isEmpty) {
            _empty(issues, '$questionPath/explanation', 'Explanation');
          }
          for (final index in correctIndexes) {
            if (index < 0 || index >= alternatives.length) {
              issues.add(
                ImportIssue(
                  path: '$questionPath/correctIndexes',
                  message:
                      'Correct index $index is outside 0..${alternatives.length - 1}.',
                ),
              );
            }
          }
          if (explanations.length != alternatives.length) {
            issues.add(
              ImportIssue(
                path: '$questionPath/alternativeExplanations',
                message:
                    'Expected ${alternatives.length} explanations, found ${explanations.length}.',
              ),
            );
          }
          for (
            var alternativeIndex = 0;
            alternativeIndex < alternatives.length;
            alternativeIndex++
          ) {
            if (alternatives[alternativeIndex].trim().isEmpty) {
              _empty(
                issues,
                '$questionPath/alternatives/$alternativeIndex',
                'Alternative',
              );
            }
          }
          for (
            var explanationIndex = 0;
            explanationIndex < explanations.length;
            explanationIndex++
          ) {
            if (explanations[explanationIndex].trim().isEmpty) {
              _empty(
                issues,
                '$questionPath/alternativeExplanations/$explanationIndex',
                'Alternative explanation',
              );
            }
          }

          questions.add(
            QuestionDraft(
              prompt: prompt,
              alternatives: alternatives,
              correctIndexes: correctIndexes,
              explanation: explanation,
              alternativeExplanations: explanations,
            ),
          );
          totalQuestions++;
        }

        practices.add(
          ImportPractice(
            name: practiceName,
            description: (rawPractice['description'] as String? ?? '').trim(),
            contentHash: sha256
                .convert(utf8.encode(jsonEncode(rawPractice)))
                .toString(),
            questions: questions,
          ),
        );
      }

      topics.add(
        ImportTopic(
          name: topicName,
          description: (rawTopic['description'] as String? ?? '').trim(),
          priority: priority,
          practices: practices,
        ),
      );
    }

    if (totalQuestions > maxQuestions) {
      issues.add(
        ImportIssue(
          path: '/topics',
          message: 'The file contains more than $maxQuestions questions.',
        ),
      );
    }
    if (issues.isNotEmpty) {
      throw ImportException(issues);
    }
    return topics;
  }

  Future<List<String>> _duplicateNotes(List<ImportTopic> topics) async {
    final notes = <String>[];
    for (final topic in topics) {
      final existingTopic = await _repository.findTopicByName(topic.name);
      if (existingTopic == null) continue;
      notes.add(
        'Topic "${topic.name}" already exists; its description and priority will be kept.',
      );
      for (final practice in topic.practices) {
        final exact = await _repository.findPracticeByHash(
          existingTopic.id,
          practice.contentHash,
        );
        if (exact != null) {
          notes.add(
            'Practice "${practice.name}" is already imported and will be skipped.',
          );
          continue;
        }
        if (await _repository.findPracticeByName(
              existingTopic.id,
              practice.name,
            ) !=
            null) {
          notes.add(
            'Practice "${practice.name}" already exists with different content; it will be imported with a number suffix.',
          );
        }
      }
    }
    return notes;
  }

  void _empty(List<ImportIssue> issues, String path, String label) {
    issues.add(ImportIssue(path: path, message: '$label cannot be empty.'));
  }

  List<int> _readCorrectIndexes(
    Map<String, dynamic> rawQuestion,
    String questionPath,
    List<ImportIssue> issues,
  ) {
    final hasSingle = rawQuestion.containsKey('correctIndex');
    final hasMany = rawQuestion.containsKey('correctIndexes');
    if (hasSingle == hasMany) {
      issues.add(
        ImportIssue(
          path: '$questionPath/correctIndexes',
          message: 'Use either "correctIndex" for one answer or "correctIndexes" for several, not both.',
        ),
      );
      return const [];
    }
    if (hasSingle) {
      final value = rawQuestion['correctIndex'];
      return value is int ? [value] : const [];
    }
    final rawValues = rawQuestion['correctIndexes'];
    if (rawValues is! List) return const [];
    final indexes = <int>[];
    for (final value in rawValues) {
      if (value is int) indexes.add(value);
    }
    if (indexes.length != rawValues.length) return const [];
    if (indexes.isEmpty) {
      issues.add(
        ImportIssue(
          path: '$questionPath/correctIndexes',
          message: 'correctIndexes cannot be empty.',
        ),
      );
      return const [];
    }
    if (indexes.toSet().length != indexes.length) {
      issues.add(
        ImportIssue(
          path: '$questionPath/correctIndexes',
          message: 'correctIndexes cannot contain the same index twice.',
        ),
      );
      return const [];
    }
    return indexes;
  }

  List<ImportIssue> _jsonIssues(FormatException error, String text) {
    final offset = (error.offset ?? 0).clamp(0, text.length);
    final before = text.substring(0, offset);
    final line = '\n'.allMatches(before).length + 1;
    final lastNewline = before.lastIndexOf('\n');
    final column = offset - lastNewline;
    return [
      ImportIssue(path: 'line $line, column $column', message: error.message),
    ];
  }
}
