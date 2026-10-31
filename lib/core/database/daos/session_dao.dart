import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'session_dao.g.dart';

@DriftAccessor(
  tables: [
    Sessions,
    SessionQuestions,
    Attempts,
    Questions,
    Practices,
    Topics,
    Concepts,
  ],
)
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.db);

  Future<int> createSession({
    required int? practiceId,
    required String mode,
    required String status,
    required DateTime startedAt,
    required int total,
  }) {
    return into(sessions).insert(
      SessionsCompanion.insert(
        practiceId: Value(practiceId),
        mode: mode,
        status: status,
        startedAt: startedAt,
        total: total,
      ),
    );
  }

  Future<void> addSessionQuestions(int sessionId, List<int> questionIds) async {
    await batch((batch) {
      batch.insertAll(sessionQuestions, [
        for (var i = 0; i < questionIds.length; i++)
          SessionQuestionsCompanion.insert(
            sessionId: sessionId,
            questionId: questionIds[i],
            position: i,
          ),
      ]);
    });
  }

  Future<SessionRow?> sessionById(int id) {
    return (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<SessionRow?> latestInProgressSession() {
    return (select(sessions)
          ..where((s) => s.status.equals('inProgress'))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<SessionRow?> watchLatestInProgressSession() {
    return (select(sessions)
          ..where((s) => s.status.equals('inProgress'))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<List<InProgressSessionRow>> watchInProgressSessions() {
    final query = customSelect(
      '''
      SELECT
        s.id AS session_id,
        s.practice_id AS session_practice_id,
        s.mode AS session_mode,
        s.status AS session_status,
        s.started_at AS session_started_at,
        s.finished_at AS session_finished_at,
        s.total AS session_total,
        s.correct AS session_correct,
        s.skipped AS session_skipped,
        s.distracted AS session_distracted,
        COALESCE(p.name, '') AS practice_name,
        COALESCE(t.name, '') AS topic_name,
        (SELECT COUNT(*) FROM attempts a WHERE a.session_id = s.id) AS answered_count
      FROM sessions s
      LEFT JOIN practices p ON p.id = s.practice_id
      LEFT JOIN topics t ON t.id = p.topic_id
      WHERE s.status = 'inProgress'
      ORDER BY s.started_at DESC, s.id DESC
      ''',
      readsFrom: {sessions, practices, topics, attempts},
    );
    return query.watch().map(
      (rows) => rows.map(InProgressSessionRow.fromRow).toList(),
    );
  }

  Future<List<QuestionRow>> questionsForSession(int sessionId) {
    final query =
        select(questions).join([
            innerJoin(
              sessionQuestions,
              sessionQuestions.questionId.equalsExp(questions.id),
            ),
          ])
          ..where(sessionQuestions.sessionId.equals(sessionId))
          ..orderBy([OrderingTerm.asc(sessionQuestions.position)]);
    return query.get().then(
      (rows) => rows.map((row) => row.readTable(questions)).toList(),
    );
  }

  Future<List<AttemptRow>> attemptsForSession(int sessionId) {
    return (select(attempts)
          ..where((a) => a.sessionId.equals(sessionId))
          ..orderBy([(a) => OrderingTerm.asc(a.id)]))
        .get();
  }

  Future<AttemptRow?> attemptForQuestion(int sessionId, int questionId) {
    return (select(attempts)..where(
          (a) =>
              a.sessionId.equals(sessionId) & a.questionId.equals(questionId),
        ))
        .getSingleOrNull();
  }

  Future<int> insertAttempt(AttemptsCompanion attempt) {
    return into(attempts).insert(attempt);
  }

  Future<void> updateAttemptDistracted(int id, bool distracted) {
    return (update(attempts)..where((a) => a.id.equals(id))).write(
      AttemptsCompanion(distracted: Value(distracted)),
    );
  }

  Future<void> completeSession({
    required int id,
    required int total,
    required int correct,
    required int skipped,
    required int distracted,
    required DateTime finishedAt,
  }) {
    return (update(sessions)..where((s) => s.id.equals(id))).write(
      SessionsCompanion(
        status: const Value('completed'),
        total: Value(total),
        correct: Value(correct),
        skipped: Value(skipped),
        distracted: Value(distracted),
        finishedAt: Value(finishedAt),
      ),
    );
  }

  Future<void> abandonSession(int id) {
    return (update(sessions)..where((s) => s.id.equals(id))).write(
      const SessionsCompanion(status: Value('abandoned')),
    );
  }

  Future<void> deleteSession(int id) {
    return (delete(sessions)..where((s) => s.id.equals(id))).go();
  }

  Stream<List<SessionRow>> watchCompletedSessions() {
    return (select(sessions)
          ..where((s) => s.status.equals('completed'))
          ..orderBy([(s) => OrderingTerm.desc(s.finishedAt)]))
        .watch();
  }

  Future<List<PracticeRow>> practicesWithSessions() {
    return (select(practices)..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
  }

  Future<int> lookupCountForSession(int sessionId) async {
    final query = customSelect(
      'SELECT COUNT(DISTINCT term) AS amount FROM concepts WHERE session_id = ?',
      variables: [Variable.withInt(sessionId)],
      readsFrom: {concepts},
    );
    final row = await query.getSingle();
    return row.read<int>('amount');
  }

  Future<int> conceptCountForSession(int sessionId) async {
    final query = customSelect(
      'SELECT COUNT(*) AS amount FROM concepts WHERE session_id = ?',
      variables: [Variable.withInt(sessionId)],
      readsFrom: {concepts},
    );
    final row = await query.getSingle();
    return row.read<int>('amount');
  }
}

class InProgressSessionRow {
  const InProgressSessionRow({
    required this.session,
    required this.topicName,
    required this.practiceName,
    required this.answeredCount,
  });

  factory InProgressSessionRow.fromRow(QueryRow row) {
    return InProgressSessionRow(
      session: SessionRow(
        id: row.read<int>('session_id'),
        practiceId: row.read<int?>('session_practice_id'),
        mode: row.read<String>('session_mode'),
        status: row.read<String>('session_status'),
        startedAt: row.read<DateTime>('session_started_at').toUtc(),
        finishedAt: row.read<DateTime?>('session_finished_at')?.toUtc(),
        total: row.read<int>('session_total'),
        correct: row.read<int>('session_correct'),
        skipped: row.read<int>('session_skipped'),
        distracted: row.read<int>('session_distracted'),
      ),
      topicName: row.read<String>('topic_name'),
      practiceName: row.read<String>('practice_name'),
      answeredCount: row.read<int>('answered_count'),
    );
  }

  final SessionRow session;
  final String topicName;
  final String practiceName;
  final int answeredCount;
}
