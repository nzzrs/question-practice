import 'package:meta/meta.dart';

import '../../../core/domain/models.dart';

/// One practice from a topic update file and its question diff.
@immutable
class TopicPracticeUpdatePreview {
  const TopicPracticeUpdatePreview({
    required this.name,
    required this.description,
    required this.questions,
    required this.deletedQuestions,
    required this.contentHash,
    this.practiceId,
    this.descriptionChanged = false,
  });

  /// The stored practice this file row updates, or null for a new practice.
  final int? practiceId;
  final String name;
  final String description;
  final List<PracticeQuestionUpdate> questions;
  final List<Question> deletedQuestions;
  final String contentHash;
  final bool descriptionChanged;

  bool get isNew => practiceId == null;

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

  bool get hasChanges =>
      isNew ||
      descriptionChanged ||
      newCount > 0 ||
      modifiedCount > 0 ||
      deletedCount > 0;

  TopicPracticeUpdate toUpdate() {
    return TopicPracticeUpdate(
      existingPracticeId: practiceId,
      name: name,
      description: description,
      questions: questions,
      deletedQuestionIds: [
        for (final question in deletedQuestions) question.id,
      ],
      contentHash: contentHash,
      changed: hasChanges,
    );
  }
}

/// A validated topic file diffed against the stored topic.
@immutable
class TopicUpdatePreview {
  const TopicUpdatePreview({
    required this.topicId,
    required this.topicName,
    required this.fileName,
    required this.practices,
    this.description,
    this.updatePriority = false,
    this.priority,
    this.minimumScore,
    this.targetScore,
    this.hasMetadataChanges = false,
  });

  final int topicId;
  final String topicName;
  final String fileName;

  /// The file's description, or null when the file omits it.
  final String? description;

  /// Whether the file names a priority, including an explicit null.
  final bool updatePriority;
  final int? priority;

  /// The file's minimum score, or null when it omits it.
  final int? minimumScore;

  /// The file's target score, or null when it omits it.
  final int? targetScore;

  final List<TopicPracticeUpdatePreview> practices;

  /// Whether the topic's own fields differ from the stored topic.
  final bool hasMetadataChanges;

  List<TopicPracticeUpdatePreview> get newPractices => [
    for (final practice in practices)
      if (practice.isNew) practice,
  ];

  List<TopicPracticeUpdatePreview> get modifiedPractices => [
    for (final practice in practices)
      if (!practice.isNew && practice.hasChanges) practice,
  ];

  List<TopicPracticeUpdatePreview> get unchangedPractices => [
    for (final practice in practices)
      if (!practice.isNew && !practice.hasChanges) practice,
  ];

  int get newPracticeCount => newPractices.length;
  int get modifiedPracticeCount => modifiedPractices.length;
  int get unchangedPracticeCount => unchangedPractices.length;

  int get newQuestionCount =>
      practices.fold(0, (sum, practice) => sum + practice.newCount);
  int get modifiedQuestionCount =>
      practices.fold(0, (sum, practice) => sum + practice.modifiedCount);
  int get deletedQuestionCount =>
      practices.fold(0, (sum, practice) => sum + practice.deletedCount);

  bool get hasChanges =>
      hasMetadataChanges || practices.any((practice) => practice.hasChanges);

  List<TopicPracticeUpdate> toPracticeUpdates() => [
    for (final practice in practices) practice.toUpdate(),
  ];
}
