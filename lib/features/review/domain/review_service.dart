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
  });

  final Question question;
  final String topicName;
  final String practiceName;
  final String reasoning;
}

class ConceptDefinitionStep extends ReviewStep {
  const ConceptDefinitionStep(this.concept);

  final Concept concept;
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
    final questionsById = {
      for (final question in questions) question.id: question,
    };
    final practices = await _practices.allPractices();
    final topics = await _practices.allTopics();
    final practiceById = {
      for (final practice in practices) practice.id: practice,
    };
    final topicNames = {for (final topic in topics) topic.id: topic.name};

    final steps = <ReviewStep>[];
    for (final attempt in attempts) {
      if (attempt.isSkipped) {
        final question = questionsById[attempt.questionId];
        if (question == null) continue;
        final practice = practiceById[question.practiceId];
        steps.add(
          SkippedReviewStep(
            question: question,
            topicName: practice == null
                ? ''
                : topicNames[practice.topicId] ?? '',
            practiceName: practice?.name ?? '',
            reasoning: attempt.reasoning,
          ),
        );
      } else if (!attempt.isCorrect && !attempt.distracted) {
        final card = await _cards.activeErrorForQuestion(attempt.questionId);
        if (card != null && card.needsDetails && card.exportedAt == null) {
          steps.add(ErrorReviewStep(card));
        }
      }
    }

    for (final concept in concepts.where((item) => item.needsDefinition)) {
      steps.add(ConceptDefinitionStep(concept));
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

  Future<void> saveConceptDefinition(int conceptId, String definition) {
    return _cards.updateConceptDefinition(conceptId, definition.trim());
  }

  Future<int> createConcept({
    required int? sessionId,
    required int? questionId,
    required String term,
    required String definition,
    required String context,
    required String topicName,
    required ConceptSource source,
  }) {
    return _cards.createConcept(
      sessionId: sessionId,
      questionId: questionId,
      term: term.trim(),
      definition: definition.trim(),
      context: context,
      topicName: topicName,
      source: source,
      createdAt: _clock.now().toUtc(),
    );
  }

  Future<int> createBasicCard({
    required int? sessionId,
    required String question,
    required String answer,
    required String topicName,
  }) {
    return _cards.createManualCard(
      sessionId: sessionId,
      question: question.trim(),
      answer: answer.trim(),
      topicName: topicName,
      createdAt: _clock.now().toUtc(),
    );
  }
}
