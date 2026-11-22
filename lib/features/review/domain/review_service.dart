import 'package:clock/clock.dart';

import '../../../core/data/card_repository.dart';
import '../../../core/data/practice_repository.dart';
import '../../../core/data/session_repository.dart';
import '../../../core/domain/models.dart';

sealed class ReviewStep {
  const ReviewStep();
}

class ErrorReviewStep extends ReviewStep {
  const ErrorReviewStep(this.card);

  final ErrorCard card;
}

class SkippedReviewStep extends ReviewStep {
  const SkippedReviewStep({
    required this.question,
    required this.topicName,
    required this.practiceName,
    required this.reasoning,
    this.unknown = false,
    this.skippedQuestionId,
  });

  final Question question;
  final String topicName;
  final String practiceName;
  final String reasoning;

  /// The learner marked the answer as "I didn't know this".
  final bool unknown;

  /// Persistent queue record, when the answer was stored for later.
  final int? skippedQuestionId;
}

class ConceptDefinitionStep extends ReviewStep {
  const ConceptDefinitionStep(this.concept);

  final Concept concept;
}

class NoteReviewStep extends ReviewStep {
  const NoteReviewStep(this.note);

  final Note note;
}

class ReviewData {
  const ReviewData({
    required this.session,
    required this.steps,
    required this.conceptCount,
  });

  final PracticeSession session;
  final List<ReviewStep> steps;
  final int conceptCount;
}

class ReviewService {
  ReviewService({
    required PracticeRepository practices,
    required SessionRepository sessions,
    required CardRepository cards,
    required Clock clock,
  }) : _practices = practices,
       _sessions = sessions,
       _cards = cards,
       _clock = clock;

  final PracticeRepository _practices;
  final SessionRepository _sessions;
  final CardRepository _cards;
  final Clock _clock;

  Future<ReviewData?> load(int sessionId) async {
    final session = await _sessions.sessionById(sessionId);
    if (session == null) return null;
    final questions = await _sessions.questionsForSession(sessionId);
    final attempts = await _sessions.attemptsForSession(sessionId);
    final concepts = await _cards.conceptsForSession(sessionId);
    final notes = await _cards.notesForSession(sessionId);
    final skippedRecords = await _cards.skippedQuestionsForSession(sessionId);
    final skippedByQuestion = {
      for (final record in skippedRecords) record.questionId: record,
    };
    final questionsById = {
      for (final question in questions) question.id: question,
    };
    final practices = await _practices.allPractices();
    final topics = await _practices.allTopics();
    final practiceById = {
      for (final practice in practices) practice.id: practice,
    };
    final topicNames = {for (final topic in topics) topic.id: topic.name};

    final wrongQuestionIds = [
      for (final attempt in attempts)
        if (!attempt.isSkipped && !attempt.isCorrect && !attempt.distracted)
          attempt.questionId,
    ];
    final activeCards = await _cards.activeErrorsForQuestions(wrongQuestionIds);

    final steps = <ReviewStep>[];
    final addedErrorCardIds = <int>{};
    for (final attempt in attempts) {
      if (attempt.isSkipped) {
        final question = questionsById[attempt.questionId];
        if (question == null) continue;
        final record = skippedByQuestion[attempt.questionId];
        if (record != null && record.isHandled) continue;
        final practice = practiceById[question.practiceId];
        steps.add(
          SkippedReviewStep(
            question: question,
            topicName: practice == null
                ? ''
                : topicNames[practice.topicId] ?? '',
            practiceName: practice?.name ?? '',
            reasoning: record?.reasoning ?? attempt.reasoning,
            unknown: record?.unknown ?? attempt.unknown,
            skippedQuestionId: record?.id,
          ),
        );
      } else if (!attempt.isCorrect && !attempt.distracted) {
        final card = activeCards[attempt.questionId];
        if (card != null &&
            card.needsReview &&
            addedErrorCardIds.add(card.id)) {
          steps.add(ErrorReviewStep(card));
        }
      }
    }

    for (final concept in concepts.where((item) => item.needsDefinition)) {
      steps.add(ConceptDefinitionStep(concept));
    }

    for (final note in notes.where((item) => item.needsReview)) {
      steps.add(NoteReviewStep(note));
    }

    return ReviewData(
      session: session,
      steps: steps,
      conceptCount: concepts.length,
    );
  }

  Future<void> saveErrorDetails({
    required int cardId,
    required String bias,
    required String vaccine,
  }) {
    return _cards.updateErrorCardDetails(
      id: cardId,
      bias: bias.trim(),
      vaccine: vaccine.trim(),
      completedAt: _clock.now().toUtc(),
    );
  }

  /// Marks the card's details step complete, leaving the old bias and vaccine
  /// notes untouched for cards created before atomic breakdowns.
  Future<void> completeErrorDetails(int cardId) {
    return _cards.completeErrorCardDetails(cardId, _clock.now().toUtc());
  }

  /// Creates the selected atomic cards for [card] and completes its details.
  ///
  /// Each [SuggestedCard] becomes one Basic card carrying the error's topic,
  /// subtopic and cognitive type. Returns the number of cards created.
  Future<int> createErrorBreakdownCards({
    required ErrorCard card,
    required Iterable<SuggestedCard> cards,
  }) async {
    var added = 0;
    for (final suggestion in cards) {
      await createBasicCard(
        sessionId: card.sessionId,
        questionId: card.questionId,
        question: suggestion.front,
        answer: suggestion.back,
        topicName: card.topicName,
        subtopic: card.subtopic,
        cognitiveType: suggestion.cognitiveType,
      );
      added++;
    }
    await completeErrorDetails(card.id);
    return added;
  }

  Future<void> saveConceptDefinition(int conceptId, String definition) {
    return _cards.updateConceptDefinition(conceptId, definition.trim());
  }

  Future<void> keepNote(int noteId) {
    return _cards.keepNote(noteId, _clock.now().toUtc());
  }

  Future<void> markNoteConverted(int noteId, {int? manualCardId}) {
    return _cards.markNoteConverted(
      noteId,
      cardCreatedAt: _clock.now().toUtc(),
      manualCardId: manualCardId,
    );
  }

  Future<int> createConcept({
    required int? sessionId,
    required int? questionId,
    required String term,
    required String definition,
    String extra = '',
    required String context,
    required String topicName,
    required ConceptSource source,
    int? skippedQuestionId,
    String subtopic = '',
  }) async {
    final id = await _cards.createConcept(
      sessionId: sessionId,
      questionId: questionId,
      term: term.trim(),
      definition: definition.trim(),
      extra: extra.trim(),
      context: context,
      topicName: topicName,
      subtopic: subtopic,
      source: source,
      createdAt: _clock.now().toUtc(),
    );
    if (skippedQuestionId != null) {
      await _cards.markSkippedHandled(
        skippedQuestionId,
        'concept',
        _clock.now().toUtc(),
      );
    }
    return id;
  }

  Future<int> createBasicCard({
    required int? sessionId,
    required String question,
    required String answer,
    required String topicName,
    int? questionId,
    String context = '',
    int? skippedQuestionId,
    String subtopic = '',
    CognitiveType cognitiveType = CognitiveType.fact,
  }) async {
    final id = await _cards.createManualCard(
      sessionId: sessionId,
      questionId: questionId,
      question: question.trim(),
      answer: answer.trim(),
      context: context.trim(),
      topicName: topicName,
      subtopic: subtopic,
      cognitiveType: cognitiveType,
      createdAt: _clock.now().toUtc(),
    );
    if (skippedQuestionId != null) {
      await _cards.markSkippedHandled(
        skippedQuestionId,
        'basic',
        _clock.now().toUtc(),
      );
    }
    return id;
  }
}
