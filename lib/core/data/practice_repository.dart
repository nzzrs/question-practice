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

/// The practices produced by splitting one practice.
class SplitPracticeResult {
  const SplitPracticeResult({required this.parts});

  /// New practices in slice order: A, B, C, and so on.
  final List<Practice> parts;

  /// First practice of a two-part split.
  Practice get sliceA => parts[0];

  /// Second practice of a two-part split.
  Practice get sliceB => parts[1];
}

/// Sizes of the parts for a split, in slice order.
///
/// Each part gets the same number of questions; when the count is not
/// divisible, the first parts get one extra question, so sizes differ by at
/// most one. For example, 10 questions in 3 parts gives `[4, 3, 3]`.
List<int> splitPartSizes(int questionCount, int parts) {
  if (questionCount < 2) {
    throw const PracticeSplitException('A split needs at least two questions.');
  }
  if (parts < 2) {
    throw const PracticeSplitException('A split needs at least two parts.');
  }
  if (parts > questionCount) {
    throw PracticeSplitException(
      'A split cannot have more parts than questions. '
      'This practice has $questionCount.',
    );
  }
  final base = questionCount ~/ parts;
  final extra = questionCount % parts;
  return List<int>.unmodifiable([
    for (var index = 0; index < parts; index++) base + (index < extra ? 1 : 0),
  ]);
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

  /// Readiness over the topic's latest answered questions.
  Stream<TopicReadiness> watchTopicReadiness(int topicId) {
    return _db.statsDao.watchTopicReadiness(topicId).map(topicReadinessFromRow);
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

  Future<List<Practice>> practicesForTopic(int topicId) async {
    final rows = await _db.topicDao.practicesForTopic(topicId);
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
    int minimumScore = 70,
    int targetScore = 80,
    required DateTime createdAt,
  }) {
    return _db.topicDao.insertTopic(
      name: name,
      description: description,
      priority: priority,
      ankiDeck: ankiDeck,
      minimumScore: minimumScore,
      targetScore: targetScore,
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

  /// Gives every question in one topic's subtopic a new name.
  ///
  /// An empty [from] renames Uncategorized questions, which assigns them a
  /// name. Questions, attempts, sessions and cards keep their rows.
  Future<void> renameSubtopic(int topicId, String from, String to) {
    final name = to.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(to, 'to', 'A category name is required.');
    }
    return _db.topicDao.setSubtopicForTopic(
      topicId: topicId,
      subtopics: {from},
      name: name,
      includeUncategorized: from.trim().isEmpty,
    );
  }

  /// Removes named categories while keeping every question.
  ///
  /// Their subtopic becomes null, so they appear as Uncategorized. Deleting
  /// Uncategorized is a no-op.
  Future<void> deleteSubtopics(int topicId, Iterable<String> subtopics) {
    final names = {
      for (final subtopic in subtopics)
        if (subtopic.trim().isNotEmpty) subtopic.trim(),
    };
    if (names.isEmpty) return Future<void>.value();
    return _db.topicDao.setSubtopicForTopic(
      topicId: topicId,
      subtopics: names,
      name: null,
      includeUncategorized: false,
    );
  }

  /// Applies one name to every question in the selected categories.
  ///
  /// Uncategorized questions join the merged category when an empty value is
  /// selected. Other topics and all history rows stay untouched.
  Future<void> mergeSubtopics(
    int topicId,
    Iterable<String> subtopics,
    String to,
  ) {
    final name = to.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(to, 'to', 'A category name is required.');
    }
    final selection = subtopics.toSet();
    return _db.topicDao.setSubtopicForTopic(
      topicId: topicId,
      subtopics: selection,
      name: name,
      includeUncategorized: selection.any(
        (subtopic) => subtopic.trim().isEmpty,
      ),
    );
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
    return _db.transaction(
      () => _applyPracticeUpdate(
        practiceId: practiceId,
        questions: questions,
        deletedQuestionIds: deletedQuestionIds,
        contentHash: contentHash,
        importedAt: importedAt,
        description: null,
      ),
    );
  }

  Future<void> _applyPracticeUpdate({
    required int practiceId,
    required List<PracticeQuestionUpdate> questions,
    required List<int> deletedQuestionIds,
    required String contentHash,
    required DateTime importedAt,
    String? description,
  }) async {
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
    if (description != null && description != practice.description) {
      await _db.topicDao.updatePracticeDescription(practiceId, description);
    }
    await _db.topicDao.updatePracticeContent(
      id: practiceId,
      contentHash: contentHash,
      importedAt: importedAt,
    );
  }

  /// Applies a whole topic update in one transaction.
  ///
  /// Practices absent from the file are never touched. Existing practices keep
  /// the ids of matched questions; new practices and questions are inserted.
  Future<void> applyTopicUpdate({
    required int topicId,
    required String? description,
    required bool updatePriority,
    required int? priority,
    required int? minimumScore,
    required int? targetScore,
    required List<TopicPracticeUpdate> practices,
    required DateTime importedAt,
  }) {
    return _db.transaction(() async {
      final topic = await _db.topicDao.topicById(topicId);
      if (topic == null) {
        throw StateError('This topic no longer exists.');
      }
      await _db.topicDao.updateTopicDetails(
        id: topicId,
        description: description == null
            ? const Value.absent()
            : Value(description),
        priority: updatePriority ? Value(priority) : const Value.absent(),
        minimumScore: minimumScore == null
            ? const Value.absent()
            : Value(minimumScore),
        targetScore: targetScore == null
            ? const Value.absent()
            : Value(targetScore),
      );
      for (final update in practices) {
        final existingId = update.existingPracticeId;
        if (existingId == null) {
          final practiceId = await _db.topicDao.insertPractice(
            topicId: topicId,
            name: update.name,
            description: update.description,
            contentHash: update.contentHash,
            importedAt: importedAt,
          );
          await _db.topicDao.insertQuestions([
            for (var index = 0; index < update.questions.length; index++)
              QuestionsCompanion.insert(
                practiceId: practiceId,
                prompt: update.questions[index].question.prompt,
                alternativesJson: encodeStringList(
                  update.questions[index].question.alternatives,
                ),
                correctIndexesJson: Value(
                  encodeIntList(
                    update.questions[index].question.correctIndexes,
                  ),
                ),
                explanation: update.questions[index].question.explanation,
                alternativeExplanationsJson: encodeStringList(
                  update.questions[index].question.alternativeExplanations,
                ),
                position: update.questions[index].position,
                subtopic: Value(
                  _normalizeSubtopic(update.questions[index].question.subtopic),
                ),
              ),
          ]);
          continue;
        }
        if (!update.changed) continue;
        await _applyPracticeUpdate(
          practiceId: existingId,
          questions: update.questions,
          deletedQuestionIds: update.deletedQuestionIds,
          contentHash: update.contentHash,
          importedAt: importedAt,
          description: update.description,
        );
      }
    });
  }

  Future<void> setPracticeDone(int id, bool isDone) {
    return _db.topicDao.setPracticeDone(id, isDone);
  }

  Future<void> deletePractice(int id) {
    return _db.topicDao.deletePractice(id);
  }

  /// Splits one practice into [parts] new practices in one transaction.
  ///
  /// Questions are shuffled before they are dealt, so every part gets a
  /// random mix. Sizes differ by at most one. The original practice is deleted
  /// together with its sessions, answers and error cards.
  Future<SplitPracticeResult> splitPractice(
    int id, {
    int parts = 2,
    Random? random,
  }) {
    return _db.transaction(() async {
      final practice = await _db.topicDao.practiceById(id);
      if (practice == null) {
        throw const PracticeSplitException('This practice no longer exists.');
      }
      final questions = await _db.topicDao.questionsForPractice(id);
      final sizes = splitPartSizes(questions.length, parts);

      final shuffled = List<QuestionRow>.of(questions)
        ..shuffle(random ?? Random());
      final now = _clock.now().toUtc();
      final created = <Practice>[];
      var offset = 0;
      for (var index = 0; index < sizes.length; index++) {
        final partQuestions = shuffled.sublist(offset, offset + sizes[index]);
        offset += sizes[index];
        final label = _sliceLabel(index);
        final name = await _uniqueSplitName(
          practice.topicId,
          practice.name,
          label,
        );
        final partId = await _db.topicDao.insertPractice(
          topicId: practice.topicId,
          name: name,
          description: practice.description,
          contentHash: _splitHash(
            practice.contentHash,
            label.toLowerCase(),
            partQuestions,
          ),
          importedAt: now,
        );
        await _copyQuestions(partId, partQuestions);
        final row = await _db.topicDao.practiceById(partId);
        created.add(practiceFromRow(row!));
      }
      await _db.topicDao.deletePractice(id);

      return SplitPracticeResult(parts: List<Practice>.unmodifiable(created));
    });
  }

  /// Slice labels run A–Z, then fall back to the 1-based part number.
  String _sliceLabel(int index) {
    if (index < 26) return String.fromCharCode(65 + index);
    return '${index + 1}';
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
    int minimumScore = 70,
    int targetScore = 80,
  }) {
    return _db.topicDao.updateTopic(
      id: id,
      name: name,
      description: description,
      priority: priority,
      ankiDeck: ankiDeck,
      minimumScore: minimumScore,
      targetScore: targetScore,
    );
  }

  Future<T> transaction<T>(Future<T> Function() action) {
    return _db.transaction(action);
  }
}
