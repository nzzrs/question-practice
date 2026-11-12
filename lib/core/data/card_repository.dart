import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../domain/models.dart';
import 'mappers.dart';

class CardRepository {
  CardRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<List<Concept>> watchConcepts({bool includeExported = false}) {
    return _db.cardDao
        .watchConcepts(includeExported: includeExported)
        .map((rows) => rows.map(conceptFromRow).toList());
  }

  Stream<List<ErrorCard>> watchErrorCards({bool includeExported = false}) {
    return _db.cardDao
        .watchErrorCards(includeExported: includeExported)
        .map((rows) => rows.map(errorCardFromRow).toList());
  }

  Stream<List<ManualCard>> watchManualCards({bool includeExported = false}) {
    return _db.cardDao
        .watchManualCards(includeExported: includeExported)
        .map((rows) => rows.map(manualCardFromRow).toList());
  }

  Stream<List<ErrorCard>> watchDueErrors() {
    return _db.cardDao
        .watchDueErrors(_clock.now().toUtc())
        .map((rows) => rows.map(errorCardFromRow).toList());
  }

  Stream<List<ErrorCard>> watchResolvedErrors() {
    return _db.cardDao.watchResolvedErrors().map(
      (rows) => rows.map(errorCardFromRow).toList(),
    );
  }

  Stream<List<ErrorCard>> watchErrorsNeedingDetails() {
    return _db.cardDao.watchErrorCardsNeedingDetails().map(
      (rows) => rows.map(errorCardFromRow).toList(),
    );
  }

  Future<List<ErrorCard>> dueErrors() async {
    final rows = await _db.cardDao.dueErrors(_clock.now().toUtc());
    return rows.map(errorCardFromRow).toList();
  }

  Future<List<Concept>> conceptsForSession(int sessionId) async {
    final rows = await _db.cardDao.conceptsForSession(sessionId);
    return rows.map(conceptFromRow).toList();
  }

  Future<List<Concept>> conceptsMissingDefinition(int sessionId) async {
    final rows = await _db.cardDao.conceptsMissingDefinition(sessionId);
    return rows.map(conceptFromRow).toList();
  }

  Future<ErrorCard?> activeErrorForQuestion(int questionId) async {
    final row = await _db.cardDao.activeErrorCardForQuestion(questionId);
    return row == null ? null : errorCardFromRow(row);
  }

  Future<ErrorCard?> errorCardById(int id) async {
    final row = await _db.cardDao.errorCardById(id);
    return row == null ? null : errorCardFromRow(row);
  }

  Future<int> countErrorCardsNeedingDetailsForSession(int sessionId) {
    return _db.cardDao.countErrorCardsNeedingDetailsForSession(sessionId);
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
    required DateTime createdAt,
  }) {
    return _db.cardDao.insertConcept(
      ConceptsCompanion.insert(
        sessionId: Value(sessionId),
        questionId: Value(questionId),
        term: term,
        definition: Value(definition),
        extra: Value(extra),
        context: Value(context),
        topicName: Value(topicName),
        source: source.name,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> updateConceptDefinition(int id, String definition) {
    return _db.cardDao.updateConceptDefinition(id, definition);
  }

  Future<void> updateConceptExtra(int id, String extra) {
    return _db.cardDao.updateConceptExtra(id, extra);
  }

  Future<int> createErrorCard({
    required int questionId,
    required int? sessionId,
    required String question,
    required List<String> alternatives,
    required List<int> correctIndexes,
    required List<int> wrongIndexes,
    required String reasoning,
    required String explanation,
    required List<String> alternativeExplanations,
    required String topicName,
    required String practiceName,
    required DateTime lastWrongAt,
    required Duration dueAfter,
  }) {
    return _db.cardDao.insertErrorCard(
      ErrorCardsCompanion.insert(
        questionId: questionId,
        sessionId: Value(sessionId),
        question: question,
        alternativesJson: encodeStringList(alternatives),
        correctIndexesJson: Value(encodeIntList(correctIndexes)),
        wrongIndexesJson: Value(encodeIntList(wrongIndexes)),
        reasoning: Value(reasoning),
        explanation: Value(explanation),
        alternativeExplanationsJson: Value(
          encodeStringList(alternativeExplanations),
        ),
        topicName: Value(topicName),
        practiceName: Value(practiceName),
        status: ErrorCardStatus.active.name,
        createdAt: lastWrongAt,
        lastWrongAt: lastWrongAt,
        dueAt: lastWrongAt.add(dueAfter),
      ),
    );
  }

  Future<void> updateErrorCardDetails({
    required int id,
    required String bias,
    required String vaccine,
    required DateTime completedAt,
  }) {
    return _db.cardDao.updateErrorCardDetails(
      id,
      bias: bias,
      vaccine: vaccine,
      completedAt: completedAt,
    );
  }

  Future<void> updateErrorCardContent({
    required int id,
    required String question,
    required List<String> alternatives,
  }) {
    return _db.cardDao.updateErrorCardContent(
      id,
      question: question,
      alternatives: alternatives,
    );
  }

  Future<void> updateErrorCardReasoning(int id, String reasoning) {
    return _db.cardDao.updateErrorCardReasoning(id, reasoning);
  }

  Future<void> touchWrongError({
    required int id,
    required List<int> wrongIndexes,
    required String reasoning,
    required DateTime wrongAt,
    required Duration dueAfter,
  }) {
    return _db.cardDao.touchWrongError(
      id: id,
      wrongIndexes: wrongIndexes,
      reasoning: reasoning,
      wrongAt: wrongAt,
      dueAt: wrongAt.add(dueAfter),
    );
  }

  Future<void> deleteErrorCard(int id) {
    return _db.cardDao.deleteErrorCards([id]);
  }

  Future<void> resolveError(int id, DateTime resolvedAt) {
    return _db.cardDao.resolveError(id, resolvedAt);
  }

  Future<int> createManualCard({
    required int? sessionId,
    required String question,
    required String answer,
    required String topicName,
    required DateTime createdAt,
    int? questionId,
    String context = '',
  }) {
    return _db.cardDao.insertManualCard(
      ManualCardsCompanion.insert(
        sessionId: Value(sessionId),
        questionId: Value(questionId),
        question: question,
        answer: answer,
        context: Value(context),
        topicName: Value(topicName),
        createdAt: createdAt,
      ),
    );
  }

  Stream<List<SkippedQuestion>> watchUnhandledSkippedQuestions() {
    return _db.cardDao.watchUnhandledSkippedQuestions().map(
      (rows) => rows.map(skippedQuestionFromRow).toList(),
    );
  }

  Future<List<SkippedQuestion>> skippedQuestionsForSession(
    int sessionId,
  ) async {
    final rows = await _db.cardDao.skippedQuestionsForSession(sessionId);
    return rows.map(skippedQuestionFromRow).toList();
  }

  /// Stores a skipped or "I didn't know this" answer for later card making.
  ///
  /// Re-skipping the same question in the same session reopens the existing
  /// record, so toggling "I didn't know this" never leaves duplicates.
  Future<int> saveSkippedQuestion({
    required int? sessionId,
    required int questionId,
    required String question,
    required List<String> alternatives,
    required List<int> correctIndexes,
    required String explanation,
    required List<String> alternativeExplanations,
    required String reasoning,
    required String topicName,
    required String practiceName,
    required bool unknown,
    required DateTime createdAt,
  }) async {
    if (sessionId != null) {
      final existing = await _db.cardDao.skippedQuestionFor(
        sessionId,
        questionId,
      );
      if (existing != null) {
        await _db.cardDao.updateSkippedQuestion(
          existing.id,
          reasoning: reasoning,
          unknown: unknown,
          createdAt: createdAt,
        );
        return existing.id;
      }
    }
    return _db.cardDao.insertSkippedQuestion(
      SkippedQuestionsCompanion.insert(
        sessionId: Value(sessionId),
        questionId: questionId,
        question: question,
        alternativesJson: encodeStringList(alternatives),
        correctIndexesJson: Value(encodeIntList(correctIndexes)),
        explanation: Value(explanation),
        alternativeExplanationsJson: Value(
          encodeStringList(alternativeExplanations),
        ),
        reasoning: Value(reasoning),
        topicName: Value(topicName),
        practiceName: Value(practiceName),
        unknown: Value(unknown),
        createdAt: createdAt,
      ),
    );
  }

  Future<void> updateSkippedReasoning(
    int sessionId,
    int questionId,
    String reasoning,
  ) async {
    final existing = await _db.cardDao.skippedQuestionFor(
      sessionId,
      questionId,
    );
    if (existing == null) return;
    await _db.cardDao.updateSkippedQuestion(
      existing.id,
      reasoning: reasoning,
      unknown: existing.unknown,
      createdAt: existing.createdAt,
    );
  }

  Future<void> markSkippedHandled(int id, String kind, DateTime handledAt) {
    return _db.cardDao.markSkippedQuestionHandled(id, handledAt, kind);
  }

  Future<void> clearSkippedQuestion(int sessionId, int questionId) async {
    final existing = await _db.cardDao.skippedQuestionFor(
      sessionId,
      questionId,
    );
    if (existing == null) return;
    await _db.cardDao.deleteSkippedQuestion(existing.id);
  }

  Future<int> createHighlight({
    required int? sessionId,
    required int? questionId,
    required String text,
    required String context,
    required String topicName,
    required String practiceName,
    required DateTime createdAt,
  }) {
    return _db.cardDao.insertHighlight(
      HighlightsCompanion.insert(
        sessionId: Value(sessionId),
        questionId: Value(questionId),
        phrase: text,
        context: Value(context),
        topicName: Value(topicName),
        practiceName: Value(practiceName),
        createdAt: createdAt,
      ),
    );
  }

  Stream<List<StudyHighlight>> watchHighlights() {
    return _db.cardDao.watchHighlights().map(
      (rows) => rows.map(highlightFromRow).toList(),
    );
  }

  Future<List<StudyHighlight>> highlightsForSession(int sessionId) async {
    final rows = await _db.cardDao.highlightsForSession(sessionId);
    return rows.map(highlightFromRow).toList();
  }

  Future<void> keepHighlight(int id, DateTime keptAt) {
    return _db.cardDao.markHighlightKept(id, keptAt);
  }

  Future<void> markHighlightConverted(
    int id, {
    required DateTime cardCreatedAt,
    int? manualCardId,
  }) {
    return _db.cardDao.markHighlightConverted(
      id,
      cardCreatedAt: cardCreatedAt,
      manualCardId: manualCardId,
    );
  }

  Future<void> deleteHighlight(int id) {
    return _db.cardDao.deleteHighlight(id);
  }

  Future<void> markExported({
    required List<int> conceptIds,
    required List<int> errorCardIds,
    required List<int> manualCardIds,
    required DateTime exportedAt,
  }) {
    return _db.transaction(() async {
      await _db.cardDao.markConceptsExported(conceptIds, exportedAt);
      await _db.cardDao.markErrorCardsExported(errorCardIds, exportedAt);
      await _db.cardDao.markManualCardsExported(manualCardIds, exportedAt);
    });
  }

  Future<void> deleteCards({
    required List<int> conceptIds,
    required List<int> errorCardIds,
    required List<int> manualCardIds,
  }) {
    return _db.transaction(() async {
      await _db.cardDao.deleteConcepts(conceptIds);
      await _db.cardDao.deleteErrorCards(errorCardIds);
      await _db.cardDao.deleteManualCards(manualCardIds);
    });
  }
}
