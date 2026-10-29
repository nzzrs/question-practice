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
    required DateTime createdAt,
  }) {
    return into(topics).insert(
      TopicsCompanion.insert(
        name: name,
        description: Value(description),
        priority: Value(priority),
        ankiDeck: Value(ankiDeck),
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

  Future<void> updateTopic({
    required int id,
    required String name,
    required String description,
    required int? priority,
    required String? ankiDeck,
  }) {
    return (update(topics)..where((t) => t.id.equals(id))).write(
      TopicsCompanion(
        name: Value(name),
        description: Value(description),
        priority: Value(priority),
        ankiDeck: Value(ankiDeck),
      ),
    );
  }
}
