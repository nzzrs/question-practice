import 'package:meta/meta.dart';

import '../../../core/domain/models.dart';

/// A practice file validated against the stored practice it updates.
@immutable
class PracticeUpdatePreview {
  const PracticeUpdatePreview({
    required this.practiceId,
    required this.topicName,
    required this.practiceName,
    required this.fileName,
    required this.questions,
    required this.deletedQuestions,
    required this.contentHash,
  });

  final int practiceId;
  final String topicName;
  final String practiceName;
  final String fileName;

  /// Every question in the file, in its new order and with its mapping.
  final List<PracticeQuestionUpdate> questions;

  /// Stored questions that the file no longer contains.
  final List<Question> deletedQuestions;

  /// Hash of the file's practice content without file identities.
  final String contentHash;

  List<PracticeQuestionUpdate> get newQuestions => [
    for (final update in questions)
      if (update.isNew) update,
  ];

  List<PracticeQuestionUpdate> get modifiedQuestions => [
    for (final update in questions)
      if (!update.isNew && update.changed) update,
  ];

  int get newCount => newQuestions.length;
  int get modifiedCount => modifiedQuestions.length;
  int get unchangedCount => questions.length - newCount - modifiedCount;
  int get deletedCount => deletedQuestions.length;

  bool get hasChanges => newCount > 0 || modifiedCount > 0 || deletedCount > 0;

  List<int> get deletedQuestionIds => [
    for (final question in deletedQuestions) question.id,
  ];
}
