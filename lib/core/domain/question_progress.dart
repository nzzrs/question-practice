import 'package:meta/meta.dart';

/// Per-question history derived from existing attempts.
///
/// A question is **done** after the learner answered it at least once: an
/// attempt with a non-empty selection that is not marked "I didn't know this".
/// The answer may be correct, wrong or distracted; all of them mean the
/// question was seen and tried.
///
/// A question is **solved** when it was answered correctly at least once.
///
/// A question is **skipped** when it has an attempt with no selected
/// alternative or with the "I didn't know this" mark, or when a completed
/// session left it out through **Leave unanswered**.
///
/// Shuffled practice includes only questions that are neither solved nor
/// skipped, so questions already solved and questions the learner left
/// unanswered stay out of the random queue.
@immutable
class QuestionProgress {
  const QuestionProgress({
    required this.doneQuestionIds,
    required this.solvedQuestionIds,
    required this.skippedQuestionIds,
  });

  const QuestionProgress.empty()
    : doneQuestionIds = const {},
      solvedQuestionIds = const {},
      skippedQuestionIds = const {};

  final Set<int> doneQuestionIds;
  final Set<int> solvedQuestionIds;
  final Set<int> skippedQuestionIds;

  bool isDone(int questionId) => doneQuestionIds.contains(questionId);

  bool isSolved(int questionId) => solvedQuestionIds.contains(questionId);

  bool isSkipped(int questionId) => skippedQuestionIds.contains(questionId);

  bool countsForShuffledPractice(int questionId) =>
      !isSolved(questionId) && !isSkipped(questionId);
}
