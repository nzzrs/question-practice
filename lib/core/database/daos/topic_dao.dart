import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'topic_dao.g.dart';

@DriftAccessor(tables: [Topics, Practices, Questions])
class TopicDao extends DatabaseAccessor<AppDatabase> with _$TopicDaoMixin {
  TopicDao(super.db);

  Stream<List<TopicRow>> watchTopics() {
    return (select(topics)..orderBy([
          (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
        ]))
        .watch();
  }

  Stream<List<PracticeRow>> watchPracticesForTopic(int topicId) {
    return (select(practices)
          ..where((p) => p.topicId.equals(topicId))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .watch();
  }

  Stream<List<QuestionRow>> watchQuestionsForPractice(int practiceId) {
    return (select(questions)
          ..where((q) => q.practiceId.equals(practiceId))
          ..orderBy([(q) => OrderingTerm.asc(q.position)]))
        .watch();
  }

  Future<List<PracticeRow>> practicesForTopic(int topicId) {
    return (select(practices)
          ..where((p) => p.topicId.equals(topicId))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();
  }

  Future<List<TopicRow>> allTopics() {
    return (select(topics)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  Future<List<PracticeRow>> allPractices() {
    return (select(practices)..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
  }

  Future<List<QuestionRow>> questionsForPractice(int practiceId) {
    return (select(questions)
          ..where((q) => q.practiceId.equals(practiceId))
          ..orderBy([(q) => OrderingTerm.asc(q.position)]))
        .get();
  }

  Future<List<QuestionRow>> allQuestions() {
    return (select(questions)..orderBy([
          (q) => OrderingTerm.asc(q.practiceId),
          (q) => OrderingTerm.asc(q.position),
        ]))
        .get();
  }

  Future<QuestionRow?> questionById(int id) {
    return (select(questions)..where((q) => q.id.equals(id))).getSingleOrNull();
  }

  /// Question rows for [ids] in one query. The result order is unspecified.
  Future<List<QuestionRow>> questionsByIds(Iterable<int> ids) {
    final values = ids.toSet().toList(growable: false);
    if (values.isEmpty) return Future.value(const []);
    return (select(questions)..where((q) => q.id.isIn(values))).get();
  }

  Future<TopicRow?> topicById(int id) {
    return (select(topics)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<PracticeRow?> practiceById(int id) {
    return (select(practices)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<TopicRow?> findTopicByName(String name) async {
    final normalized = name.trim().toLowerCase();
    final rows = await select(topics).get();
    for (final row in rows) {
      if (row.name.trim().toLowerCase() == normalized) {
        return row;
      }
    }
    return null;
  }

  Future<PracticeRow?> findPracticeByHash(int topicId, String hash) {
    return (select(
          practices,
        )..where((p) => p.topicId.equals(topicId) & p.contentHash.equals(hash)))
        .getSingleOrNull();
  }

  Future<PracticeRow?> findPracticeByName(int topicId, String name) async {
    final normalized = name.trim().toLowerCase();
    final rows = await (select(
      practices,
    )..where((p) => p.topicId.equals(topicId))).get();
    for (final row in rows) {
      if (row.name.trim().toLowerCase() == normalized) {
        return row;
      }
    }
    return null;
  }

  Future<int> insertTopic({
    required String name,
    required String description,
    required int? priority,
    String? ankiDeck,
    int minimumScore = 70,
    int targetScore = 80,
    required DateTime createdAt,
  }) {
    return into(topics).insert(
      TopicsCompanion.insert(
        name: name,
        description: Value(description),
        priority: Value(priority),
        ankiDeck: Value(ankiDeck),
        minimumScore: Value(minimumScore),
        targetScore: Value(targetScore),
        createdAt: createdAt,
      ),
    );
  }

  Future<int> insertPractice({
    required int topicId,
    required String name,
    required String description,
    required String contentHash,
    required DateTime importedAt,
  }) {
    return into(practices).insert(
      PracticesCompanion.insert(
        topicId: topicId,
        name: name,
        description: Value(description),
        contentHash: contentHash,
        importedAt: importedAt,
      ),
    );
  }

  Future<void> insertQuestions(List<QuestionsCompanion> rows) async {
    await batch((batch) => batch.insertAll(questions, rows));
  }

  Future<void> renamePractice(int id, String name) {
    return (update(practices)..where((p) => p.id.equals(id))).write(
      PracticesCompanion(name: Value(name)),
    );
  }

  Future<void> updatePracticeDescription(int id, String description) {
    return (update(practices)..where((p) => p.id.equals(id))).write(
      PracticesCompanion(description: Value(description)),
    );
  }

  Future<void> updatePracticeContent({
    required int id,
    required String contentHash,
    required DateTime importedAt,
  }) {
    return (update(practices)..where((p) => p.id.equals(id))).write(
      PracticesCompanion(
        contentHash: Value(contentHash),
        importedAt: Value(importedAt),
      ),
    );
  }

  Future<void> updateQuestion({
    required int id,
    required String prompt,
    required List<String> alternatives,
    required List<int> correctIndexes,
    required String explanation,
    required List<String> alternativeExplanations,
    required int position,
    required String? subtopic,
  }) {
    return (update(questions)..where((q) => q.id.equals(id))).write(
      QuestionsCompanion(
        prompt: Value(prompt),
        alternativesJson: Value(jsonEncode(alternatives)),
        correctIndexesJson: Value(jsonEncode(correctIndexes)),
        explanation: Value(explanation),
        alternativeExplanationsJson: Value(jsonEncode(alternativeExplanations)),
        position: Value(position),
        subtopic: Value(subtopic),
      ),
    );
  }

  Future<void> deleteQuestion(int id) {
    return (delete(questions)..where((q) => q.id.equals(id))).go();
  }

  Future<void> setPracticeDone(int id, bool isDone) {
    return (update(practices)..where((p) => p.id.equals(id))).write(
      PracticesCompanion(isDone: Value(isDone)),
    );
  }

  /// Sets or clears the subtopic of matching questions in one topic.
  ///
  /// [subtopics] lists the named categories to change; blank entries are
  /// ignored. When [includeUncategorized] is true, questions with a null or
  /// blank subtopic are changed too. A null [name] clears the subtopic.
  Future<void> setSubtopicForTopic({
    required int topicId,
    required Set<String> subtopics,
    required String? name,
    required bool includeUncategorized,
  }) async {
    final names = {
      for (final subtopic in subtopics)
        if (subtopic.trim().isNotEmpty) subtopic.trim(),
    };
    final conditions = <String>[];
    if (names.isNotEmpty) {
      final placeholders = List.filled(names.length, '?').join(', ');
      conditions.add('subtopic IN ($placeholders)');
    }
    if (includeUncategorized) {
      conditions.add("(subtopic IS NULL OR TRIM(subtopic) = '')");
    }
    if (conditions.isEmpty) return;

    final setClause = name == null ? 'subtopic = NULL' : 'subtopic = ?';
    final variables = <Variable>[
      if (name != null) Variable.withString(name),
      Variable.withInt(topicId),
      for (final subtopic in names) Variable.withString(subtopic),
    ];
    await customUpdate(
      '''
      UPDATE questions
      SET $setClause
      WHERE practice_id IN (
        SELECT id FROM practices WHERE topic_id = ?
      )
        AND (${conditions.join(' OR ')})
      ''',
      variables: variables,
      updates: {questions, practices},
      updateKind: UpdateKind.update,
    );
  }

  Future<void> deletePractice(int id) async {
    await (delete(practices)..where((p) => p.id.equals(id))).go();
  }

  Future<void> deleteTopic(int id) async {
    await (delete(topics)..where((t) => t.id.equals(id))).go();
  }

  /// Writes only the topic fields supplied by an update file.
  Future<void> updateTopicDetails({
    required int id,
    Value<String> description = const Value.absent(),
    Value<int?> priority = const Value.absent(),
    Value<int> minimumScore = const Value.absent(),
    Value<int> targetScore = const Value.absent(),
  }) {
    return (update(topics)..where((t) => t.id.equals(id))).write(
      TopicsCompanion(
        description: description,
        priority: priority,
        minimumScore: minimumScore,
        targetScore: targetScore,
      ),
    );
  }

  Future<void> updateTopic({
    required int id,
    required String name,
    required String description,
    required int? priority,
    required String? ankiDeck,
    required int minimumScore,
    required int targetScore,
  }) {
    return (update(topics)..where((t) => t.id.equals(id))).write(
      TopicsCompanion(
        name: Value(name),
        description: Value(description),
        priority: Value(priority),
        ankiDeck: Value(ankiDeck),
        minimumScore: Value(minimumScore),
        targetScore: Value(targetScore),
      ),
    );
  }

  Future<void> setTopicArchived(int id, bool archived) {
    return (update(topics)..where((t) => t.id.equals(id))).write(
      TopicsCompanion(archived: Value(archived)),
    );
  }
}
