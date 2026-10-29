import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'card_dao.g.dart';

@DriftAccessor(tables: [Concepts, ErrorCards, ManualCards])
class CardDao extends DatabaseAccessor<AppDatabase> with _$CardDaoMixin {
  CardDao(super.db);

  Stream<List<ConceptRow>> watchConcepts({bool includeExported = false}) {
    final query = select(concepts);
    if (!includeExported) {
      query.where((c) => c.exportedAt.isNull());
    }
    query.orderBy([(c) => OrderingTerm.desc(c.createdAt)]);
    return query.watch();
  }

  Stream<List<ErrorCardRow>> watchErrorCards({bool includeExported = false}) {
    final query = select(errorCards);
    if (!includeExported) {
      query.where((e) => e.exportedAt.isNull());
    }
    query.orderBy([(e) => OrderingTerm.desc(e.createdAt)]);
    return query.watch();
  }

  Stream<List<ManualCardRow>> watchManualCards({bool includeExported = false}) {
    final query = select(manualCards);
    if (!includeExported) {
      query.where((m) => m.exportedAt.isNull());
    }
    query.orderBy([(m) => OrderingTerm.desc(m.createdAt)]);
    return query.watch();
  }

  Future<List<ConceptRow>> conceptsForSession(int sessionId) {
    return (select(concepts)
          ..where((c) => c.sessionId.equals(sessionId))
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .get();
  }

  Future<List<ConceptRow>> conceptsMissingDefinition(int sessionId) {
    return (select(concepts)
          ..where(
            (c) => c.sessionId.equals(sessionId) & c.definition.equals(''),
          )
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .get();
  }

  Future<int> insertConcept(ConceptsCompanion concept) {
    return into(concepts).insert(concept);
  }

  Future<void> updateConceptDefinition(int id, String definition) {
    return (update(concepts)..where((c) => c.id.equals(id))).write(
      ConceptsCompanion(definition: Value(definition)),
    );
  }

  Future<void> markConceptsExported(List<int> ids, DateTime exportedAt) async {
    if (ids.isEmpty) return;
    await (update(concepts)..where((c) => c.id.isIn(ids))).write(
      ConceptsCompanion(exportedAt: Value(exportedAt)),
    );
  }

  Future<void> deleteConcepts(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(concepts)..where((c) => c.id.isIn(ids))).go();
  }

  Future<ErrorCardRow?> activeErrorCardForQuestion(int questionId) {
    return (select(errorCards)..where(
          (e) => e.questionId.equals(questionId) & e.status.equals('active'),
        ))
        .getSingleOrNull();
  }

  Future<ErrorCardRow?> errorCardById(int id) {
    return (select(
      errorCards,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  Stream<List<ErrorCardRow>> watchDueErrors(DateTime now) {
    return (select(errorCards)
          ..where(
            (e) =>
                e.status.equals('active') & e.dueAt.isSmallerOrEqualValue(now),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.dueAt)]))
        .watch();
  }

  Future<List<ErrorCardRow>> dueErrors(DateTime now) {
    return (select(errorCards)
          ..where(
            (e) =>
                e.status.equals('active') & e.dueAt.isSmallerOrEqualValue(now),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.dueAt)]))
        .get();
  }

  Stream<List<ErrorCardRow>> watchResolvedErrors() {
    return (select(errorCards)
          ..where((e) => e.status.equals('resolved'))
          ..orderBy([(e) => OrderingTerm.desc(e.resolvedAt)]))
        .watch();
  }

  Stream<List<ErrorCardRow>> watchErrorCardsNeedingDetails() {
    return (select(errorCards)
          ..where(
            (e) => e.status.equals('active') & e.detailsCompletedAt.isNull(),
          )
          ..orderBy([(e) => OrderingTerm.desc(e.lastWrongAt)]))
        .watch();
  }

  Future<int> insertErrorCard(ErrorCardsCompanion card) {
    return into(errorCards).insert(card);
  }

  Future<int> countErrorCardsNeedingDetailsForSession(int sessionId) async {
    final query = customSelect(
      "SELECT COUNT(*) AS amount FROM error_cards WHERE session_id = ? AND status = 'active' AND details_completed_at IS NULL AND exported_at IS NULL",
      variables: [Variable.withInt(sessionId)],
      readsFrom: {errorCards},
    );
    final row = await query.getSingle();
    return row.read<int>('amount');
  }

  Future<void> updateErrorCardDetails(
    int id, {
    required String bias,
    required String vaccine,
    required DateTime completedAt,
  }) {
    return (update(errorCards)..where((e) => e.id.equals(id))).write(
      ErrorCardsCompanion(
        bias: Value(bias),
        vaccine: Value(vaccine),
        detailsCompletedAt: Value(completedAt),
      ),
    );
  }

  Future<void> touchWrongError({
    required int id,
    required List<int> wrongIndexes,
    required String reasoning,
    required DateTime wrongAt,
    required DateTime dueAt,
  }) {
    return (update(errorCards)..where((e) => e.id.equals(id))).write(
      ErrorCardsCompanion(
        wrongIndexesJson: Value(jsonEncode(wrongIndexes)),
        reasoning: Value(reasoning),
        lastWrongAt: Value(wrongAt),
        dueAt: Value(dueAt),
      ),
    );
  }

  Future<void> resolveError(int id, DateTime resolvedAt) {
    return (update(errorCards)..where((e) => e.id.equals(id))).write(
      ErrorCardsCompanion(
        status: const Value('resolved'),
        resolvedAt: Value(resolvedAt),
      ),
    );
  }

  Future<void> markErrorCardsExported(
    List<int> ids,
    DateTime exportedAt,
  ) async {
    if (ids.isEmpty) return;
    await (update(errorCards)..where((e) => e.id.isIn(ids))).write(
      ErrorCardsCompanion(exportedAt: Value(exportedAt)),
    );
  }

  Future<void> deleteErrorCards(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(errorCards)..where((e) => e.id.isIn(ids))).go();
  }

  Future<int> insertManualCard(ManualCardsCompanion card) {
    return into(manualCards).insert(card);
  }

  Future<void> markManualCardsExported(
    List<int> ids,
    DateTime exportedAt,
  ) async {
    if (ids.isEmpty) return;
    await (update(manualCards)..where((m) => m.id.isIn(ids))).write(
      ManualCardsCompanion(exportedAt: Value(exportedAt)),
    );
  }

  Future<void> deleteManualCards(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(manualCards)..where((m) => m.id.isIn(ids))).go();
  }
}
