import 'dart:convert';

import '../database/app_database.dart';
import '../database/daos/stats_dao.dart';
import '../domain/models.dart';

List<String> decodeStringList(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! List) {
    throw const FormatException('Expected a JSON array');
  }
  return decoded.map((item) => item.toString()).toList(growable: false);
}

String encodeStringList(List<String> values) => jsonEncode(values);

Topic topicFromRow(TopicRow row) {
  return Topic(
    id: row.id,
    name: row.name,
    description: row.description,
    priority: row.priority,
    createdAt: row.createdAt.toUtc(),
  );
}

Practice practiceFromRow(PracticeRow row) {
  return Practice(
    id: row.id,
    topicId: row.topicId,
    name: row.name,
    description: row.description,
    contentHash: row.contentHash,
    importedAt: row.importedAt.toUtc(),
  );
}

Question questionFromRow(QuestionRow row) {
  return Question(
    id: row.id,
    practiceId: row.practiceId,
    prompt: row.prompt,
    alternatives: decodeStringList(row.alternativesJson),
    correctIndex: row.correctIndex,
    explanation: row.explanation,
    alternativeExplanations: decodeStringList(row.alternativeExplanationsJson),
    position: row.position,
  );
}

PracticeSession sessionFromRow(SessionRow row) {
  return PracticeSession(
    id: row.id,
    practiceId: row.practiceId,
    mode: SessionMode.values.byName(row.mode),
    status: SessionStatus.values.byName(row.status),
    startedAt: row.startedAt.toUtc(),
    finishedAt: row.finishedAt?.toUtc(),
    total: row.total,
    correct: row.correct,
    skipped: row.skipped,
    distracted: row.distracted,
  );
}

Attempt attemptFromRow(AttemptRow row) {
  return Attempt(
    id: row.id,
    sessionId: row.sessionId,
    questionId: row.questionId,
    selectedIndex: row.selectedIndex,
    reasoning: row.reasoning,
    distracted: row.distracted,
    isCorrect: row.isCorrect,
    answeredAt: row.answeredAt.toUtc(),
  );
}

Concept conceptFromRow(ConceptRow row) {
  return Concept(
    id: row.id,
    sessionId: row.sessionId,
    questionId: row.questionId,
    term: row.term,
    definition: row.definition,
    context: row.context,
    topicName: row.topicName,
    source: ConceptSource.values.byName(row.source),
    createdAt: row.createdAt.toUtc(),
    exportedAt: row.exportedAt?.toUtc(),
  );
}

ErrorCard errorCardFromRow(ErrorCardRow row) {
  return ErrorCard(
    id: row.id,
    questionId: row.questionId,
    sessionId: row.sessionId,
    question: row.question,
    alternatives: decodeStringList(row.alternativesJson),
    correctIndex: row.correctIndex,
    wrongIndex: row.wrongIndex,
    reasoning: row.reasoning,
    bias: row.bias,
    vaccine: row.vaccine,
    topicName: row.topicName,
    practiceName: row.practiceName,
    status: ErrorCardStatus.values.byName(row.status),
    createdAt: row.createdAt.toUtc(),
    lastWrongAt: row.lastWrongAt.toUtc(),
    dueAt: row.dueAt.toUtc(),
    detailsCompletedAt: row.detailsCompletedAt?.toUtc(),
    resolvedAt: row.resolvedAt?.toUtc(),
    exportedAt: row.exportedAt?.toUtc(),
  );
}

ManualCard manualCardFromRow(ManualCardRow row) {
  return ManualCard(
    id: row.id,
    sessionId: row.sessionId,
    question: row.question,
    answer: row.answer,
    createdAt: row.createdAt.toUtc(),
    exportedAt: row.exportedAt?.toUtc(),
  );
}

TopicSummary topicSummaryFromRow(TopicSummaryRow row) {
  return TopicSummary(
    topic: Topic(
      id: row.topicId,
      name: row.topicName,
      description: row.topicDescription,
      priority: row.topicPriority,
      createdAt: row.topicCreatedAt,
    ),
    practiceCount: row.practiceCount,
    questionCount: row.questionCount,
    answeredCount: row.answeredCount,
    correctCount: row.correctCount,
    correctQuestionCount: row.correctQuestionCount,
    activeErrorCount: row.activeErrorCount,
    dueErrorCount: row.dueErrorCount,
    sessionCount: row.sessionCount,
    lastPracticedAt: row.lastPracticedAt,
  );
}

PracticeSummary practiceSummaryFromRow(PracticeSummaryRow row) {
  return PracticeSummary(
    practice: Practice(
      id: row.practiceId,
      topicId: row.topicId,
      name: row.name,
      description: row.description,
      contentHash: row.contentHash,
      importedAt: row.importedAt.toUtc(),
    ),
    questionCount: row.questionCount,
    lastScore: row.lastScore,
  );
}

HomeStats homeStatsFromRow(HomeStatsRow row) {
  return HomeStats(
    dueErrors: row.dueErrors,
    activeErrors: row.activeErrors,
    incompleteErrorCards: row.incompleteErrorCards,
    unexportedCards: row.unexportedCards,
    inProgressSessionId: row.inProgressSessionId,
    inProgressSessionMode: row.inProgressSessionMode == null
        ? null
        : SessionMode.values.byName(row.inProgressSessionMode!),
    inProgressSessionTotal: row.inProgressSessionTotal,
  );
}
