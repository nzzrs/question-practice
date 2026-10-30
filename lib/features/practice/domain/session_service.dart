import 'dart:math';

import 'package:clock/clock.dart';

import '../../../core/data/card_repository.dart';
import '../../../core/data/practice_repository.dart';
import '../../../core/data/session_repository.dart';
import '../../../core/domain/models.dart';

const errorReviewDelay = Duration(hours: 48);

class SessionException implements Exception {
  const SessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionQuestionItem {
  const SessionQuestionItem({
    required this.question,
    required this.topicName,
    required this.practiceName,
    required this.alternativeOrder,
  });

  final Question question;
  final String topicName;
  final String practiceName;

  /// Original alternative indexes in display order.
  final List<int> alternativeOrder;

  /// Falls back to the source order for items built without a shuffle.
  List<int> get displayOrder => alternativeOrder.isEmpty
      ? List<int>.generate(question.alternatives.length, (index) => index)
      : alternativeOrder;
}

class SessionStart {
  const SessionStart({
    required this.session,
    required this.items,
    required this.attempts,
    required this.errorCards,
  });

  final PracticeSession session;
  final List<SessionQuestionItem> items;
  final Map<int, Attempt> attempts;
  final Map<int, ErrorCard> errorCards;

  int get answeredCount => attempts.length;

  SessionQuestionItem? get currentItem {
    for (final item in items) {
      if (!attempts.containsKey(item.question.id)) return item;
    }
    return null;
  }

  int get currentIndex {
    for (var index = 0; index < items.length; index++) {
      if (!attempts.containsKey(items[index].question.id)) return index;
    }
    return items.length;
  }
}

class AnswerOutcome {
  const AnswerOutcome({required this.attempt, required this.summary});

  final Attempt attempt;
  final SessionSummary? summary;

  bool get completed => summary != null;
}

class SessionService {
  SessionService({
    required PracticeRepository practices,
    required SessionRepository sessions,
    required CardRepository cards,
    required Clock clock,
    Random? random,
  }) : _practices = practices,
       _sessions = sessions,
       _cards = cards,
       _clock = clock,
       _random = random ?? Random();

  final PracticeRepository _practices;
  final SessionRepository _sessions;
  final CardRepository _cards;
  final Clock _clock;
  final Random _random;

  SessionQuestionItem _itemFor(
    Question question, {
    required String topicName,
    required String practiceName,
  }) {
    final order = List<int>.generate(
      question.alternatives.length,
      (index) => index,
    )..shuffle(_random);
    return SessionQuestionItem(
      question: question,
      topicName: topicName,
      practiceName: practiceName,
      alternativeOrder: List<int>.unmodifiable(order),
    );
  }

  Future<SessionStart> startPractice(int practiceId) async {
    final practice = await _practices.practiceById(practiceId);
    if (practice == null) {
      throw const SessionException('This practice no longer exists.');
    }
    final topic = await _practices.topicById(practice.topicId);
    final questions = await _practices.questionsForPractice(practiceId);
    if (questions.isEmpty) {
      throw const SessionException('This practice has no questions.');
    }
    final session = await _sessions.startSession(
      practiceId: practiceId,
      mode: SessionMode.practice,
      questions: questions,
      startedAt: _clock.now().toUtc(),
    );
    return SessionStart(
      session: session,
      items: [
        for (final question in questions)
          _itemFor(
            question,
            topicName: topic?.name ?? '',
            practiceName: practice.name,
          ),
      ],
      attempts: <int, Attempt>{},
      errorCards: const {},
    );
  }

  Future<SessionStart> startMixed() async {
    final questions = await _practices.allQuestions();
    if (questions.isEmpty) {
      throw const SessionException('Import a practice before starting.');
    }
    final topics = await _practices.allTopics();
    final practices = await _practices.allPractices();
    final topicNames = {for (final topic in topics) topic.id: topic.name};
    final practiceById = {
      for (final practice in practices) practice.id: practice,
    };
    final shuffled = List<Question>.of(questions)..shuffle(_random);
    final session = await _sessions.startSession(
      practiceId: null,
      mode: SessionMode.mixed,
      questions: shuffled,
      startedAt: _clock.now().toUtc(),
    );
    return SessionStart(
      session: session,
      items: [
        for (final question in shuffled)
          _itemFor(
            question,
            topicName:
                topicNames[practiceById[question.practiceId]?.topicId] ?? '',
            practiceName: practiceById[question.practiceId]?.name ?? '',
          ),
      ],
      attempts: <int, Attempt>{},
      errorCards: const {},
    );
  }

  Future<SessionStart> startPastErrors() async {
    final due = await _cards.dueErrors();
    if (due.isEmpty) {
      throw const SessionException('No errors are due for review yet.');
    }
    final questions = <SessionQuestionItem>[];
    final cards = <int, ErrorCard>{};
    for (final card in due) {
      final question = await _practices.questionById(card.questionId);
      if (question == null) continue;
      questions.add(
        _itemFor(
          question,
          topicName: card.topicName,
          practiceName: card.practiceName,
        ),
      );
      cards[question.id] = card;
    }
    if (questions.isEmpty) {
      throw const SessionException('No errors are due for review yet.');
    }
    final session = await _sessions.startSession(
      practiceId: null,
      mode: SessionMode.pastErrors,
      questions: questions.map((item) => item.question).toList(),
      startedAt: _clock.now().toUtc(),
    );
    return SessionStart(
      session: session,
      items: questions,
      attempts: <int, Attempt>{},
      errorCards: cards,
    );
  }

  Future<SessionStart> resume(int sessionId) async {
    final session = await _sessions.sessionById(sessionId);
    if (session == null) {
      throw const SessionException('This session no longer exists.');
    }
    if (session.status != SessionStatus.inProgress) {
      throw const SessionException('This session is already finished.');
    }
    final questions = await _sessions.questionsForSession(sessionId);
    final attempts = await _sessions.attemptsForSession(sessionId);
    final topics = await _practices.allTopics();
    final practices = await _practices.allPractices();
    final topicNames = {for (final topic in topics) topic.id: topic.name};
    final practiceById = {
      for (final practice in practices) practice.id: practice,
    };
    final cards = <int, ErrorCard>{};
    if (session.mode == SessionMode.pastErrors) {
      for (final question in questions) {
        final card = await _cards.activeErrorForQuestion(question.id);
        if (card != null) cards[question.id] = card;
      }
    }
    return SessionStart(
      session: session,
      items: [
        for (final question in questions)
          _itemFor(
            question,
            topicName:
                topicNames[practiceById[question.practiceId]?.topicId] ?? '',
            practiceName: practiceById[question.practiceId]?.name ?? '',
          ),
      ],
      attempts: {for (final attempt in attempts) attempt.questionId: attempt},
      errorCards: cards,
    );
  }

  Future<AnswerOutcome> submitAnswer({
    required SessionStart start,
    required SessionQuestionItem item,
    required List<int> selectedIndexes,
    required String reasoning,
    required bool distracted,
  }) async {
    final session = start.session;
    if (start.attempts.containsKey(item.question.id)) {
      throw const SessionException('This question was already answered.');
    }
    final selected = selectedIndexes.toSet().toList()..sort();
    for (final index in selected) {
      if (index < 0 || index >= item.question.alternatives.length) {
        throw const SessionException('That alternative does not exist.');
      }
    }
    final now = _clock.now().toUtc();
    final isCorrect = item.question.isCorrectSelection(selected);
    final wasDistracted = distracted && !isCorrect && selected.isNotEmpty;

    final attempt = await _sessions.recordAttempt(
      sessionId: session.id,
      questionId: item.question.id,
      selectedIndexes: selected,
      reasoning: reasoning.trim(),
      distracted: wasDistracted,
      isCorrect: isCorrect,
      answeredAt: now,
    );

    if (session.mode == SessionMode.pastErrors) {
      final card =
          start.errorCards[item.question.id] ??
          await _cards.activeErrorForQuestion(item.question.id);
      if (card != null) {
        if (isCorrect) {
          await _cards.resolveError(card.id, now);
        } else if (!wasDistracted && selected.isNotEmpty) {
          await _cards.touchWrongError(
            id: card.id,
            wrongIndexes: selected,
            reasoning: reasoning.trim(),
            wrongAt: now,
            dueAfter: errorReviewDelay,
          );
        }
      }
    } else if (!isCorrect && !wasDistracted && selected.isNotEmpty) {
      final active = await _cards.activeErrorForQuestion(item.question.id);
      if (active == null) {
        await _cards.createErrorCard(
          questionId: item.question.id,
          sessionId: session.id,
          question: item.question.prompt,
          alternatives: item.question.alternatives,
          correctIndexes: item.question.correctIndexes,
          wrongIndexes: selected,
          reasoning: reasoning.trim(),
          explanation: item.question.explanation,
          alternativeExplanations: item.question.alternativeExplanations,
          topicName: item.topicName,
          practiceName: item.practiceName,
          lastWrongAt: now,
          dueAfter: errorReviewDelay,
        );
      } else {
        await _cards.touchWrongError(
          id: active.id,
          wrongIndexes: selected,
          reasoning: reasoning.trim(),
          wrongAt: now,
          dueAfter: errorReviewDelay,
        );
      }
    }

    start.attempts[item.question.id] = attempt;
    final summary = await completeIfReady(session.id);
    return AnswerOutcome(attempt: attempt, summary: summary);
  }

  Future<Attempt> setDistracted({
    required SessionStart start,
    required SessionQuestionItem item,
    required bool distracted,
  }) async {
    final session = start.session;
    final attempt = await _sessions.attemptForQuestion(
      session.id,
      item.question.id,
    );
    if (attempt == null) {
      throw const SessionException('This question has no answer to update.');
    }
    final effective = distracted && !attempt.isCorrect && !attempt.isSkipped;
    if (effective == attempt.distracted) return attempt;

    await _sessions.updateAttemptDistracted(attempt.id, effective);
    final card = await _cards.activeErrorForQuestion(item.question.id);
    if (effective) {
      if (card != null && card.sessionId == session.id) {
        await _cards.deleteErrorCard(card.id);
      }
    } else if (!attempt.isCorrect && !attempt.isSkipped) {
      final now = _clock.now().toUtc();
      if (card == null) {
        await _cards.createErrorCard(
          questionId: item.question.id,
          sessionId: session.id,
          question: item.question.prompt,
          alternatives: item.question.alternatives,
          correctIndexes: item.question.correctIndexes,
          wrongIndexes: attempt.selectedIndexes,
          reasoning: attempt.reasoning,
          explanation: item.question.explanation,
          alternativeExplanations: item.question.alternativeExplanations,
          topicName: item.topicName,
          practiceName: item.practiceName,
          lastWrongAt: now,
          dueAfter: errorReviewDelay,
        );
      } else {
        await _cards.touchWrongError(
          id: card.id,
          wrongIndexes: attempt.selectedIndexes,
          reasoning: attempt.reasoning,
          wrongAt: now,
          dueAfter: errorReviewDelay,
        );
      }
    }
    await _refreshCompletedCounts(session.id);
    final updated = await _sessions.attemptForQuestion(
      session.id,
      item.question.id,
    );
    return updated ?? attempt;
  }

  Future<void> _refreshCompletedCounts(int sessionId) async {
    final session = await _sessions.sessionById(sessionId);
    if (session == null || session.status != SessionStatus.completed) return;
    final attempts = await _sessions.attemptsForSession(sessionId);
    await _sessions.completeSession(
      id: sessionId,
      total: attempts.length,
      correct: attempts.where((attempt) => attempt.isCorrect).length,
      skipped: attempts.where((attempt) => attempt.isSkipped).length,
      distracted: attempts.where((attempt) => attempt.distracted).length,
      finishedAt: session.finishedAt ?? _clock.now().toUtc(),
    );
  }

  Future<SessionSummary?> completeIfReady(int sessionId) async {
    final session = await _sessions.sessionById(sessionId);
    if (session == null || session.status != SessionStatus.inProgress) {
      return null;
    }
    final attempts = await _sessions.attemptsForSession(sessionId);
    if (attempts.length < session.total) return null;

    final now = _clock.now().toUtc();
    final correct = attempts.where((attempt) => attempt.isCorrect).length;
    final skipped = attempts.where((attempt) => attempt.isSkipped).length;
    final distracted = attempts.where((attempt) => attempt.distracted).length;
    await _sessions.completeSession(
      id: sessionId,
      total: attempts.length,
      correct: correct,
      skipped: skipped,
      distracted: distracted,
      finishedAt: now,
    );
    return summaryFor(sessionId);
  }

  /// Completes a session before every question was answered.
  ///
  /// Unanswered questions are left out of the session when [markSkipped] is
  /// false, so they do not affect the score or the statistics. When it is true,
  /// each unanswered question is recorded as a skipped attempt.
  Future<SessionSummary> finishEarly({
    required SessionStart start,
    required bool markSkipped,
  }) async {
    final session = start.session;
    if (session.status != SessionStatus.inProgress) {
      return summaryFor(session.id);
    }
    final unanswered = [
      for (final item in start.items)
        if (!start.attempts.containsKey(item.question.id)) item,
    ];
    final now = _clock.now().toUtc();
    if (markSkipped) {
      for (final item in unanswered) {
        final attempt = await _sessions.recordAttempt(
          sessionId: session.id,
          questionId: item.question.id,
          selectedIndexes: const [],
          reasoning: '',
          distracted: false,
          isCorrect: false,
          answeredAt: now,
        );
        start.attempts[item.question.id] = attempt;
      }
    }
    final attempts = await _sessions.attemptsForSession(session.id);
    await _sessions.completeSession(
      id: session.id,
      total: attempts.length,
      correct: attempts.where((attempt) => attempt.isCorrect).length,
      skipped: attempts.where((attempt) => attempt.isSkipped).length,
      distracted: attempts.where((attempt) => attempt.distracted).length,
      finishedAt: now,
    );
    return summaryFor(session.id);
  }

  Future<SessionSummary> summaryFor(int sessionId) async {
    final session = await _sessions.sessionById(sessionId);
    if (session == null) {
      throw const SessionException('This session no longer exists.');
    }
    final lookupCount = await _sessions.lookupCountForSession(sessionId);
    final conceptCount = await _sessions.conceptCountForSession(sessionId);
    final needingNotes = await _cards.countErrorCardsNeedingDetailsForSession(
      sessionId,
    );
    return SessionSummary(
      session: session,
      lookupCount: lookupCount,
      conceptCount: conceptCount,
      errorCardsNeedingNotes: needingNotes,
    );
  }

  Future<void> discard(int sessionId) => _sessions.discardSession(sessionId);
}
