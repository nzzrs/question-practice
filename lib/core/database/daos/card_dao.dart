import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'card_dao.g.dart';

@DriftAccessor(
  tables: [Concepts, ErrorCards, ManualCards, SkippedQuestions, Notes],
)
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

  /// Newest concept with this term (case-insensitive) that has a definition.
  Future<ConceptRow?> latestConceptForTerm(String term) {
    final cleaned = term.trim();
    if (cleaned.isEmpty) return Future.value(null);
    return (select(concepts)
          ..where(
            (c) =>
                c.term.lower().equals(cleaned.toLowerCase()) &
                c.definition.equals('').not(),
          )
          ..orderBy([
            (c) => OrderingTerm.desc(c.createdAt),
            (c) => OrderingTerm.desc(c.id),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> updateConceptDefinition(int id, String definition) {
    return (update(concepts)..where((c) => c.id.equals(id))).write(
      ConceptsCompanion(definition: Value(definition)),
    );
  }

  Future<void> updateConceptExtra(int id, String extra) {
    return (update(concepts)..where((c) => c.id.equals(id))).write(
      ConceptsCompanion(extra: Value(extra)),
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

  /// Marks the details step complete without touching the legacy notes.
  Future<void> completeErrorCardDetails(int id, DateTime completedAt) {
    return (update(errorCards)..where((e) => e.id.equals(id))).write(
      ErrorCardsCompanion(detailsCompletedAt: Value(completedAt)),
    );
  }

  Future<void> updateErrorCardContent(
    int id, {
    required String question,
    required List<String> alternatives,
    required String explanation,
    required List<String> alternativeExplanations,
  }) {
    return (update(errorCards)..where((e) => e.id.equals(id))).write(
      ErrorCardsCompanion(
        question: Value(question),
        alternativesJson: Value(jsonEncode(alternatives)),
        explanation: Value(explanation),
        alternativeExplanationsJson: Value(jsonEncode(alternativeExplanations)),
      ),
    );
  }

  Future<void> updateErrorCardReasoning(int id, String reasoning) {
    return (update(errorCards)..where((e) => e.id.equals(id))).write(
      ErrorCardsCompanion(reasoning: Value(reasoning)),
    );
  }

  Future<void> updateErrorCardMistakeKinds(int id, String mistakeKindsJson) {
    return (update(errorCards)..where((e) => e.id.equals(id))).write(
      ErrorCardsCompanion(mistakeKindsJson: Value(mistakeKindsJson)),
    );
  }

  Future<void> updateErrorCardDistracted(int id, bool distracted) {
    return (update(errorCards)..where((e) => e.id.equals(id))).write(
      ErrorCardsCompanion(distracted: Value(distracted)),
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
        distracted: const Value(false),
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

  Stream<List<SkippedQuestionRow>> watchUnhandledSkippedQuestions() {
    return (select(skippedQuestions)
          ..where((s) => s.handledAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .watch();
  }

  Future<List<SkippedQuestionRow>> skippedQuestionsForSession(int sessionId) {
    return (select(skippedQuestions)
          ..where((s) => s.sessionId.equals(sessionId))
          ..orderBy([(s) => OrderingTerm.asc(s.id)]))
        .get();
  }

  Future<SkippedQuestionRow?> skippedQuestionFor(
    int sessionId,
    int questionId,
  ) {
    return (select(skippedQuestions)
          ..where(
            (s) =>
                s.sessionId.equals(sessionId) & s.questionId.equals(questionId),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> insertSkippedQuestion(SkippedQuestionsCompanion question) {
    return into(skippedQuestions).insert(question);
  }

  Future<void> updateSkippedQuestion(
    int id, {
    required String reasoning,
    required bool unknown,
    required DateTime createdAt,
  }) {
    return (update(skippedQuestions)..where((s) => s.id.equals(id))).write(
      SkippedQuestionsCompanion(
        reasoning: Value(reasoning),
        unknown: Value(unknown),
        createdAt: Value(createdAt),
        handledAt: const Value(null),
        handledKind: const Value(null),
      ),
    );
  }

  Future<void> markSkippedQuestionHandled(
    int id,
    DateTime handledAt,
    String kind,
  ) {
    return (update(skippedQuestions)..where((s) => s.id.equals(id))).write(
      SkippedQuestionsCompanion(
        handledAt: Value(handledAt),
        handledKind: Value(kind),
      ),
    );
  }

  Future<void> deleteSkippedQuestion(int id) {
    return deleteSkippedQuestions([id]);
  }

  Future<void> deleteSkippedQuestions(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(skippedQuestions)..where((s) => s.id.isIn(ids))).go();
  }

  Future<int> insertNote(NotesCompanion note) {
    return into(notes).insert(note);
  }

  Stream<List<NoteRow>> watchNotes() {
    return (select(
      notes,
    )..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).watch();
  }

  Future<List<NoteRow>> notesForSession(int sessionId) {
    return (select(notes)
          ..where((n) => n.sessionId.equals(sessionId))
          ..orderBy([(n) => OrderingTerm.asc(n.id)]))
        .get();
  }

  /// Notes saved for a question in any session.
  ///
  /// A note belongs to the question, so it keeps showing whenever that
  /// question is practised again, not only in the session that saved it.
  Future<List<NoteRow>> notesForQuestion(int questionId) {
    return (select(notes)
          ..where((n) => n.questionId.equals(questionId))
          ..orderBy([(n) => OrderingTerm.asc(n.id)]))
        .get();
  }

  Future<void> markNoteKept(int id, DateTime keptAt) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(keptAt: Value(keptAt)),
    );
  }

  Future<void> markNoteConverted(
    int id, {
    required DateTime cardCreatedAt,
    int? manualCardId,
  }) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        cardCreatedAt: Value(cardCreatedAt),
        manualCardId: Value(manualCardId),
      ),
    );
  }

  Future<void> deleteNote(int id) {
    return deleteNotes([id]);
  }

  Future<void> deleteNotes(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(notes)..where((n) => n.id.isIn(ids))).go();
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
