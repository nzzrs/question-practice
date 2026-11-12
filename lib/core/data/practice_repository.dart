import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import '../domain/models.dart';
import 'mappers.dart';

/// Raised when a practice cannot be split.
class PracticeSplitException implements Exception {
  const PracticeSplitException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The two practices produced by splitting one practice.
class SplitPracticeResult {
  const SplitPracticeResult({required this.sliceA, required this.sliceB});

  final Practice sliceA;
  final Practice sliceB;
}

class PracticeRepository {
  PracticeRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<HomeStats> watchHomeStats() {
    return _db.statsDao
        .watchHomeStats(_clock.now().toUtc())
        .map(homeStatsFromRow);
  }

  Stream<List<TopicSummary>> watchTopicSummaries({
    bool includeArchived = false,
  }) {
    return _db.statsDao
        .watchTopicSummaries(
          _clock.now().toUtc(),
          includeArchived: includeArchived,
        )
        .map((rows) => rows.map(topicSummaryFromRow).toList());
  }

  Stream<List<TopicSummary>> watchArchivedTopicSummaries() {
    return watchTopicSummaries(includeArchived: true)
        .map((rows) => rows.where((row) => row.topic.archived).toList());
  }

  Stream<TopicSummary?> watchTopicSummary(int topicId) {
    return watchTopicSummaries(
      includeArchived: true,
    ).map((rows) => rows.where((row) => row.topic.id == topicId).firstOrNull);
  }

  Stream<List<PracticeSummary>> watchPracticeSummaries(int topicId) {
    return _db.statsDao
        .watchPracticeSummaries(topicId, _clock.now().toUtc())
        .map((rows) => rows.map(practiceSummaryFromRow).toList());
  }

  Stream<List<TopicProgressPoint>> watchTopicProgress(int topicId) {
    return _db.statsDao
        .watchTopicProgress(topicId)
        .map(
          (rows) => [
            for (final row in rows)
              TopicProgressPoint(
                sessionId: row.sessionId,
                finishedAt: row.finishedAt,
                practiceName: row.practiceName,
                correct: row.correct,
                total: row.total,
              ),
          ],
        );
  }

  Stream<List<SubtopicStat>> watchSubtopicStats(int topicId) {
    return _db.statsDao
        .watchSubtopicStats(topicId)
        .map(
          (rows) => [
            for (final row in rows)
              SubtopicStat(
                subtopic: row.subtopic,
                questionCount: row.questionCount,
                attemptedQuestionCount: row.attemptedQuestionCount,
                answeredCount: row.answeredCount,
                correctCount: row.correctCount,
              ),
          ],
        );
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
    String? ankiDeck,
    required DateTime createdAt,
  }) {
    return _db.topicDao.insertTopic(
      name: name,
      description: description,
      priority: priority,
      ankiDeck: ankiDeck,
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
          correctIndexesJson: Value(encodeIntList(questions[i].correctIndexes)),
          explanation: questions[i].explanation,
          alternativeExplanationsJson: encodeStringList(
            questions[i].alternativeExplanations,
          ),
          position: i,
          subtopic: Value(_normalizeSubtopic(questions[i].subtopic)),
        ),
    ]);
  }

  String? _normalizeSubtopic(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> renamePractice(int id, String name) {
    return _db.topicDao.renamePractice(id, name);
  }

  Future<void> updatePracticeDescription(int id, String description) {
    return _db.topicDao.updatePracticeDescription(id, description);
  }

  /// Rewrites a practice's questions while keeping the rows of matched ones.
  ///
  /// Matched questions keep their id, so attempts, error cards, skipped
  /// questions and statistics stay linked. Removed questions are deleted and
  /// cascade through the existing schema relationships.
  Future<void> applyPracticeUpdate({
    required int practiceId,
    required List<PracticeQuestionUpdate> questions,
    required List<int> deletedQuestionIds,
    required String contentHash,
    required DateTime importedAt,
  }) {
    return _db.transaction(() async {
      final practice = await _db.topicDao.practiceById(practiceId);
      if (practice == null) {
        throw StateError('This practice no longer exists.');
      }
      for (final id in deletedQuestionIds) {
        await _db.topicDao.deleteQuestion(id);
      }
      final inserted = <QuestionsCompanion>[];
      for (final update in questions) {
        final question = update.question;
        final existingId = update.existingQuestionId;
        if (existingId == null) {
          inserted.add(
            QuestionsCompanion.insert(
              practiceId: practiceId,
              prompt: question.prompt,
              alternativesJson: encodeStringList(question.alternatives),
              correctIndexesJson: Value(encodeIntList(question.correctIndexes)),
              explanation: question.explanation,
              alternativeExplanationsJson: encodeStringList(
                question.alternativeExplanations,
              ),
              position: update.position,
              subtopic: Value(_normalizeSubtopic(question.subtopic)),
            ),
          );
          continue;
        }
        await _db.topicDao.updateQuestion(
          id: existingId,
          prompt: question.prompt,
          alternatives: question.alternatives,
          correctIndexes: question.correctIndexes,
          explanation: question.explanation,
          alternativeExplanations: question.alternativeExplanations,
          position: update.position,
          subtopic: _normalizeSubtopic(question.subtopic),
        );
      }
      if (inserted.isNotEmpty) {
        await _db.topicDao.insertQuestions(inserted);
      }
      await _db.topicDao.updatePracticeContent(
        id: practiceId,
        contentHash: contentHash,
        importedAt: importedAt,
      );
    });
  }

  Future<void> setPracticeDone(int id, bool isDone) {
    return _db.topicDao.setPracticeDone(id, isDone);
  }

  Future<void> deletePractice(int id) {
    return _db.topicDao.deletePractice(id);
  }

  Future<SplitPracticeResult> splitPractice(int id, {Random? random}) {
    return _db.transaction(() async {
      final practice = await _db.topicDao.practiceById(id);
      if (practice == null) {
        throw const PracticeSplitException('This practice no longer exists.');
      }
      final questions = await _db.topicDao.questionsForPractice(id);
      if (questions.length < 2) {
        throw const PracticeSplitException(
          'A split needs at least two questions.',
        );
      }
      if (questions.length.isOdd) {
        throw PracticeSplitException(
          'A split needs an even number of questions. '
          'This practice has ${questions.length}.',
        );
      }

      final shuffled = List<QuestionRow>.of(questions)
        ..shuffle(random ?? Random());
      final half = shuffled.length ~/ 2;
      final sliceAQuestions = shuffled.sublist(0, half);
      final sliceBQuestions = shuffled.sublist(half);
      final nameA = await _uniqueSplitName(
        practice.topicId,
        practice.name,
        'A',
      );
      final nameB = await _uniqueSplitName(
        practice.topicId,
        practice.name,
        'B',
      );
      final now = _clock.now().toUtc();

      final sliceAId = await _db.topicDao.insertPractice(
        topicId: practice.topicId,
        name: nameA,
        description: practice.description,
        contentHash: _splitHash(practice.contentHash, 'a', sliceAQuestions),
        importedAt: now,
      );
      await _copyQuestions(sliceAId, sliceAQuestions);
      final sliceBId = await _db.topicDao.insertPractice(
        topicId: practice.topicId,
        name: nameB,
        description: practice.description,
        contentHash: _splitHash(practice.contentHash, 'b', sliceBQuestions),
        importedAt: now,
      );
      await _copyQuestions(sliceBId, sliceBQuestions);
      await _db.topicDao.deletePractice(id);

      final sliceARow = await _db.topicDao.practiceById(sliceAId);
      final sliceBRow = await _db.topicDao.practiceById(sliceBId);
      return SplitPracticeResult(
        sliceA: practiceFromRow(sliceARow!),
        sliceB: practiceFromRow(sliceBRow!),
      );
    });
  }

  Future<String> _uniqueSplitName(
    int topicId,
    String baseName,
    String slice,
  ) async {
    var suffix = 'Slice $slice';
    var candidate = _withSuffix(baseName, suffix);
    var copy = 2;
    while (await _db.topicDao.findPracticeByName(topicId, candidate) != null) {
      suffix = 'Slice $slice $copy';
      candidate = _withSuffix(baseName, suffix);
      copy++;
    }
    return candidate;
  }

  String _withSuffix(String baseName, String suffix) {
    final tail = ' $suffix';
    final room = 120 - tail.length;
    final trimmed = baseName.length > room
        ? baseName.substring(0, room).trimRight()
        : baseName;
    return '$trimmed$tail';
  }

  String _splitHash(
    String originalHash,
    String slice,
    List<QuestionRow> questions,
  ) {
    final source = [
      originalHash,
      slice,
      for (final question in questions) question.id,
    ].join('|');
    return sha256.convert(utf8.encode(source)).toString();
  }

  Future<void> _copyQuestions(int practiceId, List<QuestionRow> questions) {
    return _db.topicDao.insertQuestions([
      for (var index = 0; index < questions.length; index++)
        QuestionsCompanion.insert(
          practiceId: practiceId,
          prompt: questions[index].prompt,
          alternativesJson: questions[index].alternativesJson,
          correctIndexesJson: Value(questions[index].correctIndexesJson),
          explanation: questions[index].explanation,
          alternativeExplanationsJson:
              questions[index].alternativeExplanationsJson,
          position: index,
          subtopic: Value(questions[index].subtopic),
        ),
    ]);
  }

  Future<void> deleteTopic(int id) {
    return _db.topicDao.deleteTopic(id);
  }

  Future<void> setTopicArchived(int id, bool archived) {
    return _db.topicDao.setTopicArchived(id, archived);
  }

  Future<void> updateTopic({
    required int id,
    required String name,
    required String description,
    required int? priority,
    String? ankiDeck,
  }) {
    return _db.topicDao.updateTopic(
      id: id,
      name: name,
      description: description,
      priority: priority,
      ankiDeck: ankiDeck,
    );
  }

  Future<T> transaction<T>(Future<T> Function() action) {
    return _db.transaction(action);
  }
}
