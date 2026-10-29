import 'package:clock/clock.dart';
import 'package:collection/collection.dart';

import '../database/app_database.dart';
import '../domain/models.dart';
import 'mappers.dart';

class PracticeRepository {
  PracticeRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<HomeStats> watchHomeStats() {
    return _db.statsDao
        .watchHomeStats(_clock.now().toUtc())
        .map(homeStatsFromRow);
  }

  Stream<List<TopicSummary>> watchTopicSummaries() {
    return _db.statsDao
        .watchTopicSummaries(_clock.now().toUtc())
        .map((rows) => rows.map(topicSummaryFromRow).toList());
  }

  Stream<TopicSummary?> watchTopicSummary(int topicId) {
    return watchTopicSummaries().map(
      (rows) => rows.where((row) => row.topic.id == topicId).firstOrNull,
    );
  }

  Stream<List<PracticeSummary>> watchPracticeSummaries(int topicId) {
    return _db.statsDao
        .watchPracticeSummaries(topicId, _clock.now().toUtc())
        .map((rows) => rows.map(practiceSummaryFromRow).toList());
  }

  Future<List<Question>> questionsForPractice(int practiceId) async {
    final rows = await _db.topicDao.questionsForPractice(practiceId);
    return rows.map(questionFromRow).toList();
  }

  Future<List<Question>> allQuestions() async {
    final rows = await _db.topicDao.allQuestions();
    return rows.map(questionFromRow).toList();
  }

  Future<List<Topic>> allTopics() async {
    final rows = await _db.topicDao.allTopics();
    return rows.map(topicFromRow).toList();
  }

  Future<List<Practice>> allPractices() async {
    final rows = await _db.topicDao.allPractices();
    return rows.map(practiceFromRow).toList();
  }

  Future<Question?> questionById(int id) async {
    final row = await _db.topicDao.questionById(id);
    return row == null ? null : questionFromRow(row);
  }

  Future<Practice?> practiceById(int id) async {
    final row = await _db.topicDao.practiceById(id);
    return row == null ? null : practiceFromRow(row);
  }

  Future<Topic?> topicById(int id) async {
    final row = await _db.topicDao.topicById(id);
    return row == null ? null : topicFromRow(row);
  }

  Future<Topic?> findTopicByName(String name) async {
    final row = await _db.topicDao.findTopicByName(name);
    return row == null ? null : topicFromRow(row);
  }

  Future<Practice?> findPracticeByHash(int topicId, String hash) async {
    final row = await _db.topicDao.findPracticeByHash(topicId, hash);
    return row == null ? null : practiceFromRow(row);
  }

  Future<Practice?> findPracticeByName(int topicId, String name) async {
    final row = await _db.topicDao.findPracticeByName(topicId, name);
    return row == null ? null : practiceFromRow(row);
  }

  Future<int> createTopic({
    required String name,
    required String description,
    required int? priority,
    required DateTime createdAt,
  }) {
    return _db.topicDao.insertTopic(
      name: name,
      description: description,
      priority: priority,
      createdAt: createdAt,
    );
  }

  Future<int> createPractice({
    required int topicId,
    required String name,
    required String description,
    required String contentHash,
    required DateTime importedAt,
  }) {
    return _db.topicDao.insertPractice(
      topicId: topicId,
      name: name,
      description: description,
      contentHash: contentHash,
      importedAt: importedAt,
    );
  }

  Future<void> createQuestions(int practiceId, List<QuestionDraft> questions) {
    return _db.topicDao.insertQuestions([
      for (var i = 0; i < questions.length; i++)
        QuestionsCompanion.insert(
          practiceId: practiceId,
          prompt: questions[i].prompt,
          alternativesJson: encodeStringList(questions[i].alternatives),
          correctIndex: questions[i].correctIndex,
          explanation: questions[i].explanation,
          alternativeExplanationsJson: encodeStringList(
            questions[i].alternativeExplanations,
          ),
          position: i,
        ),
    ]);
  }

  Future<void> updateTopic({
    required int id,
    required String name,
    required String description,
    required int? priority,
  }) {
    return _db.topicDao.updateTopic(
      id: id,
      name: name,
      description: description,
      priority: priority,
    );
  }

  Future<T> transaction<T>(Future<T> Function() action) {
    return _db.transaction(action);
  }
}
