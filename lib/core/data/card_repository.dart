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

  /// Active cards for [questionIds], keyed by question, in batched queries.
  Future<Map<int, ErrorCard>> activeErrorsForQuestions(
    Iterable<int> questionIds,
  ) async {
    final rows = await _db.cardDao.activeErrorCardsForQuestions(questionIds);
    return {for (final row in rows) row.questionId: errorCardFromRow(row)};
  }

  Future<ErrorCard?> errorCardById(int id) async {
    final row = await _db.cardDao.errorCardById(id);
    return row == null ? null : errorCardFromRow(row);
  }

  /// Newest saved concept with [term], ignoring case and empty definitions.
  Future<Concept?> latestConceptForTerm(String term) async {
    final row = await _db.cardDao.latestConceptForTerm(term);
    return row == null ? null : conceptFromRow(row);
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
    String subtopic = '',
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
        subtopic: Value(subtopic),
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
    String subtopic = '',
    CognitiveType cognitiveType = CognitiveType.contrast,
    List<MistakeKind> mistakeKinds = const [],
    bool distracted = false,
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
        cognitiveType: Value(cognitiveType.name),
        subtopic: Value(subtopic),
        mistakeKindsJson: Value(mistakeKindsToJson(mistakeKinds)),
        distracted: Value(distracted),
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

  Future<void> completeErrorCardDetails(int id, DateTime completedAt) {
    return _db.cardDao.completeErrorCardDetails(id, completedAt);
  }

  Future<void> updateErrorCardContent({
    required int id,
    required String question,
    required List<String> alternatives,
    required String explanation,
    required List<String> alternativeExplanations,
  }) {
    return _db.cardDao.updateErrorCardContent(
      id,
      question: question,
      alternatives: alternatives,
      explanation: explanation,
      alternativeExplanations: alternativeExplanations,
    );
  }

  Future<void> updateErrorCardReasoning(int id, String reasoning) {
    return _db.cardDao.updateErrorCardReasoning(id, reasoning);
  }

  Future<void> updateErrorCardMistakeKinds(
    int id,
    List<MistakeKind> mistakeKinds,
  ) {
    return _db.cardDao.updateErrorCardMistakeKinds(
      id,
      mistakeKindsToJson(mistakeKinds),
    );
  }

  Future<void> setErrorCardDistracted(int id, bool distracted) {
    return _db.cardDao.updateErrorCardDistracted(id, distracted);
  }

  Future<void> touchWrongError({
    required int id,
    required List<int> wrongIndexes,
    required String reasoning,
    required DateTime wrongAt,
    required Duration dueAfter,
  }) async {
    // A mistake recorded at the exact instant the details were completed must
    // still reopen the card. Without the nudge `needsDetails` would compare
    // equal timestamps and silently keep the repeated error reviewed. A full
    // second is used because date-time columns round to whole seconds.
    var effectiveWrongAt = wrongAt;
    final existing = await _db.cardDao.errorCardById(id);
    final completedAt = existing?.detailsCompletedAt;
    if (completedAt != null && !effectiveWrongAt.isAfter(completedAt)) {
      effectiveWrongAt = completedAt.add(const Duration(seconds: 1));
    }
    return _db.cardDao.touchWrongError(
      id: id,
      wrongIndexes: wrongIndexes,
      reasoning: reasoning,
      wrongAt: effectiveWrongAt,
      dueAt: effectiveWrongAt.add(dueAfter),
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
    String subtopic = '',
    CognitiveType cognitiveType = CognitiveType.fact,
  }) {
    return _db.cardDao.insertManualCard(
      ManualCardsCompanion.insert(
        sessionId: Value(sessionId),
        questionId: Value(questionId),
        question: question,
        answer: answer,
        context: Value(context),
        topicName: Value(topicName),
        cognitiveType: Value(cognitiveType.name),
        subtopic: Value(subtopic),
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

  Future<int> createNote({
    required int? sessionId,
    required int? questionId,
    required String text,
    required String context,
    required String topicName,
    required String practiceName,
    required DateTime createdAt,
    String subtopic = '',
  }) {
    return _db.cardDao.insertNote(
      NotesCompanion.insert(
        sessionId: Value(sessionId),
        questionId: Value(questionId),
        noteText: text,
        context: Value(context),
        topicName: Value(topicName),
        subtopic: Value(subtopic),
        practiceName: Value(practiceName),
        createdAt: createdAt,
      ),
    );
  }

  Stream<List<Note>> watchNotes() {
    return _db.cardDao.watchNotes().map(
      (rows) => rows.map(noteFromRow).toList(),
    );
  }

  Future<List<Note>> notesForSession(int sessionId) async {
    final rows = await _db.cardDao.notesForSession(sessionId);
    return rows.map(noteFromRow).toList();
  }

  /// Notes saved for a question in any session.
  Future<List<Note>> notesForQuestion(int questionId) async {
    final rows = await _db.cardDao.notesForQuestion(questionId);
    return rows.map(noteFromRow).toList();
  }

  Future<void> keepNote(int id, DateTime keptAt) {
    return _db.cardDao.markNoteKept(id, keptAt);
  }

  Future<void> markNoteConverted(
    int id, {
    required DateTime cardCreatedAt,
    int? manualCardId,
  }) {
    return _db.cardDao.markNoteConverted(
      id,
      cardCreatedAt: cardCreatedAt,
      manualCardId: manualCardId,
    );
  }

  Future<void> deleteNote(int id) {
    return _db.cardDao.deleteNote(id);
  }

  Future<void> deleteNotes(List<int> ids) {
    return _db.cardDao.deleteNotes(ids);
  }

  Future<void> markExported({
    required List<int> conceptIds,
    required List<int> manualCardIds,
    required DateTime exportedAt,
  }) {
    return _db.transaction(() async {
      await _db.cardDao.markConceptsExported(conceptIds, exportedAt);
      await _db.cardDao.markManualCardsExported(manualCardIds, exportedAt);
    });
  }

  Future<void> deleteCards({
    required List<int> conceptIds,
    required List<int> errorCardIds,
    required List<int> manualCardIds,
    List<int> skippedQuestionIds = const [],
    List<int> noteIds = const [],
  }) {
    return _db.transaction(() async {
      await _db.cardDao.deleteConcepts(conceptIds);
      await _db.cardDao.deleteErrorCards(errorCardIds);
      await _db.cardDao.deleteManualCards(manualCardIds);
      await _db.cardDao.deleteSkippedQuestions(skippedQuestionIds);
      await _db.cardDao.deleteNotes(noteIds);
    });
  }
}
