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
  }) {
    return _db.cardDao.insertManualCard(
      ManualCardsCompanion.insert(
        sessionId: Value(sessionId),
        question: question,
        answer: answer,
        topicName: Value(topicName),
        createdAt: createdAt,
      ),
    );
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
