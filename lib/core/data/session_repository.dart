import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../domain/models.dart';
import 'mappers.dart';

class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  Future<PracticeSession> startSession({
    required int? practiceId,
    required SessionMode mode,
    required List<Question> questions,
    required DateTime startedAt,
  }) {
    return _db.transaction(() async {
      final id = await _db.sessionDao.createSession(
        practiceId: practiceId,
        mode: mode.name,
        status: SessionStatus.inProgress.name,
        startedAt: startedAt,
        total: questions.length,
      );
      await _db.sessionDao.addSessionQuestions(
        id,
        questions.map((question) => question.id).toList(),
      );
      final row = await _db.sessionDao.sessionById(id);
      return sessionFromRow(row!);
    });
  }

  Future<PracticeSession?> sessionById(int id) async {
    final row = await _db.sessionDao.sessionById(id);
    return row == null ? null : sessionFromRow(row);
  }

  Future<PracticeSession?> latestInProgress() async {
    final row = await _db.sessionDao.latestInProgressSession();
    return row == null ? null : sessionFromRow(row);
  }

  Stream<PracticeSession?> watchLatestInProgress() {
    return _db.sessionDao.watchLatestInProgressSession().map(
      (row) => row == null ? null : sessionFromRow(row),
    );
  }

  Stream<List<PracticeSession>> watchInProgress() {
    return _db.sessionDao.watchInProgressSessions().map(
      (rows) => rows.map(sessionFromInProgressRow).toList(),
    );
  }

  Future<List<Question>> questionsForSession(int sessionId) async {
    final rows = await _db.sessionDao.questionsForSession(sessionId);
    return rows.map(questionFromRow).toList();
  }

  Future<List<Attempt>> attemptsForSession(int sessionId) async {
    final rows = await _db.sessionDao.attemptsForSession(sessionId);
    return rows.map(attemptFromRow).toList();
  }

  Future<Attempt?> attemptForQuestion(int sessionId, int questionId) async {
    final row = await _db.sessionDao.attemptForQuestion(sessionId, questionId);
    return row == null ? null : attemptFromRow(row);
  }

  Future<Attempt> recordAttempt({
    required int sessionId,
    required int questionId,
    required List<int> selectedIndexes,
    required String reasoning,
    required bool distracted,
    required bool isCorrect,
    required DateTime answeredAt,
  }) async {
    await _db.sessionDao.insertAttempt(
      AttemptsCompanion.insert(
        sessionId: sessionId,
        questionId: questionId,
        selectedIndexesJson: Value(encodeIntList(selectedIndexes)),
        reasoning: Value(reasoning),
        distracted: Value(distracted),
        isCorrect: isCorrect,
        answeredAt: answeredAt,
      ),
    );
    final row = await _db.sessionDao.attemptForQuestion(sessionId, questionId);
    return attemptFromRow(row!);
  }

  Future<void> updateAttemptDistracted(int id, bool distracted) {
    return _db.sessionDao.updateAttemptDistracted(id, distracted);
  }

  Future<void> completeSession({
    required int id,
    required int total,
    required int correct,
    required int skipped,
    required int distracted,
    required DateTime finishedAt,
  }) {
    return _db.sessionDao.completeSession(
      id: id,
      total: total,
      correct: correct,
      skipped: skipped,
      distracted: distracted,
      finishedAt: finishedAt,
    );
  }

  Future<void> abandonSession(int id) => _db.sessionDao.abandonSession(id);

  Future<void> discardSession(int id) => _db.sessionDao.deleteSession(id);

  Future<int> lookupCountForSession(int sessionId) {
    return _db.sessionDao.lookupCountForSession(sessionId);
  }

  Future<int> conceptCountForSession(int sessionId) {
    return _db.sessionDao.conceptCountForSession(sessionId);
  }
}
