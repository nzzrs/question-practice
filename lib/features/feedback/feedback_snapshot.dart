import '../../core/domain/models.dart';
import '../practice/domain/session_service.dart';
import 'domain/wrong_notes.dart';

/// Where the shared feedback surface is rendered.
enum FeedbackMode { practice, review }

/// Everything the shared feedback surface needs, independent of its host.
class FeedbackSnapshot {
  const FeedbackSnapshot({
    required this.question,
    required this.alternatives,
    required this.correctIndexes,
    required this.selectedIndexes,
    required this.order,
    required this.explanation,
    required this.alternativeExplanations,
    required this.topicName,
    required this.subtopic,
    required this.wrongNotes,
    required this.mode,
    this.isCorrect = false,
    this.isSkipped = false,
    this.isUnknown = false,
    this.isDistracted = false,
    this.pastErrors = false,
    this.revealed = true,
    this.notes = const [],
  });

  final String question;
  final List<String> alternatives;
  final List<int> correctIndexes;
  final List<int> selectedIndexes;

  /// Original alternative indexes in display order.
  final List<int> order;
  final String explanation;
  final List<String> alternativeExplanations;
  final String topicName;
  final String subtopic;
  final List<String> wrongNotes;
  final FeedbackMode mode;
  final bool isCorrect;
  final bool isSkipped;
  final bool isUnknown;
  final bool isDistracted;
  final bool pastErrors;

  /// False before the learner submits, when correct and wrong states stay hidden.
  final bool revealed;
  final List<Note> notes;

  bool get allowsMultiple => correctIndexes.length > 1;
  bool get canEditWrongNotes =>
      mode == FeedbackMode.practice && revealed && !isCorrect && !isSkipped;

  factory FeedbackSnapshot.fromQuestion({
    required SessionQuestionItem item,
    required Iterable<int> selectedIndexes,
    FeedbackMode mode = FeedbackMode.practice,
    bool pastErrors = false,
    bool revealed = false,
    List<Note> notes = const [],
  }) {
    final question = item.question;
    final selected = selectedIndexes.toSet().toList()..sort();
    return FeedbackSnapshot(
      question: question.prompt,
      alternatives: question.alternatives,
      correctIndexes: question.correctIndexes,
      selectedIndexes: selected,
      order: item.displayOrder,
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      topicName: item.topicName,
      subtopic: question.subtopic,
      wrongNotes: const [],
      mode: mode,
      pastErrors: pastErrors,
      revealed: revealed,
      isCorrect: revealed && question.isCorrectSelection(selected),
      notes: notes,
    );
  }

  factory FeedbackSnapshot.fromAttempt({
    required SessionQuestionItem item,
    required Attempt attempt,
    required FeedbackMode mode,
    required bool pastErrors,
    List<Note> notes = const [],
  }) {
    return FeedbackSnapshot(
      question: item.question.prompt,
      alternatives: item.question.alternatives,
      correctIndexes: item.question.correctIndexes,
      selectedIndexes: attempt.selectedIndexes,
      order: item.displayOrder,
      explanation: item.question.explanation,
      alternativeExplanations: item.question.alternativeExplanations,
      topicName: item.topicName,
      subtopic: item.question.subtopic,
      wrongNotes: WrongNotes.parse(attempt.reasoning),
      mode: mode,
      isCorrect: attempt.isCorrect,
      isSkipped: attempt.isSkipped,
      isUnknown: attempt.unknown,
      isDistracted: attempt.distracted,
      pastErrors: pastErrors,
      notes: notes,
    );
  }

  factory FeedbackSnapshot.fromCard({
    required ErrorCard card,
    List<Note> notes = const [],
  }) {
    return FeedbackSnapshot(
      question: card.question,
      alternatives: card.alternatives,
      correctIndexes: card.correctIndexes,
      selectedIndexes: card.wrongIndexes,
      order: List<int>.generate(card.alternatives.length, (index) => index),
      explanation: card.explanation,
      alternativeExplanations: card.alternativeExplanations,
      topicName: card.topicName,
      subtopic: card.subtopic,
      wrongNotes: WrongNotes.parse(card.reasoning),
      mode: FeedbackMode.review,
      isDistracted: card.distracted,
      notes: notes,
    );
  }
}
