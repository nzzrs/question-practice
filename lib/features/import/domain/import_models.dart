import '../../../core/domain/models.dart';

class ImportIssue {
  const ImportIssue({required this.path, required this.message});

  final String path;
  final String message;

  String get displayPath => path.isEmpty ? '/ (root)' : path;

  @override
  String toString() => '$displayPath: $message';
}

class ImportException implements Exception {
  const ImportException(this.issues);

  final List<ImportIssue> issues;

  @override
  String toString() => issues.map((issue) => issue.toString()).join('\n');
}

class ImportTopic {
  const ImportTopic({
    required this.name,
    required this.description,
    required this.priority,
    required this.practices,
  });

  final String name;
  final String description;
  final int? priority;
  final List<ImportPractice> practices;
}

class ImportPractice {
  const ImportPractice({
    required this.name,
    required this.description,
    required this.contentHash,
    required this.questions,
  });

  final String name;
  final String description;
  final String contentHash;
  final List<QuestionDraft> questions;
}

class ImportPreview {
  const ImportPreview({
    required this.topics,
    required this.notes,
    required this.fileName,
  });

  final List<ImportTopic> topics;
  final List<String> notes;
  final String fileName;

  int get topicCount => topics.length;
  int get practiceCount =>
      topics.fold(0, (sum, topic) => sum + topic.practices.length);
  int get questionCount => topics.fold(
    0,
    (sum, topic) =>
        sum +
        topic.practices.fold(
          0,
          (inner, practice) => inner + practice.questions.length,
        ),
  );
}

class ImportResult {
  const ImportResult({
    required this.topicsCreated,
    required this.topicsReused,
    required this.practicesImported,
    required this.practicesSkipped,
    required this.questionsImported,
  });

  final int topicsCreated;
  final int topicsReused;
  final int practicesImported;
  final int practicesSkipped;
  final int questionsImported;
}
