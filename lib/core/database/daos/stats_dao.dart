import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'stats_dao.g.dart';

@DriftAccessor(
  tables: [
    Topics,
    Practices,
    Questions,
    Sessions,
    Attempts,
    ErrorCards,
    Concepts,
    ManualCards,
  ],
)
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  StatsDao(super.db);

  Stream<HomeStatsRow> watchHomeStats(DateTime now) {
    final query = customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM error_cards WHERE status = 'active') AS active_errors,
        (SELECT COUNT(*) FROM error_cards WHERE status = 'active' AND due_at <= ?) AS due_errors,
        (SELECT COUNT(*) FROM error_cards WHERE status = 'active' AND details_completed_at IS NULL) AS incomplete_error_cards,
        (
          (SELECT COUNT(*) FROM concepts WHERE exported_at IS NULL AND definition <> '')
          + (SELECT COUNT(*) FROM error_cards WHERE exported_at IS NULL AND details_completed_at IS NOT NULL)
          + (SELECT COUNT(*) FROM manual_cards WHERE exported_at IS NULL)
        ) AS unexported_cards,
        (SELECT id FROM sessions WHERE status = 'inProgress' ORDER BY started_at DESC LIMIT 1) AS in_progress_session_id,
        (SELECT mode FROM sessions WHERE status = 'inProgress' ORDER BY started_at DESC LIMIT 1) AS in_progress_session_mode,
        (SELECT total FROM sessions WHERE status = 'inProgress' ORDER BY started_at DESC LIMIT 1) AS in_progress_session_total
      ''',
      variables: [Variable.withDateTime(now)],
      readsFrom: {errorCards, concepts, manualCards, sessions},
    );
    return query.watchSingle().map(
      (row) => HomeStatsRow(
        activeErrors: row.read<int>('active_errors'),
        dueErrors: row.read<int>('due_errors'),
        incompleteErrorCards: row.read<int>('incomplete_error_cards'),
        unexportedCards: row.read<int>('unexported_cards'),
        inProgressSessionId: row.read<int?>('in_progress_session_id'),
        inProgressSessionMode: row.read<String?>('in_progress_session_mode'),
        inProgressSessionTotal: row.read<int?>('in_progress_session_total'),
      ),
    );
  }

  Stream<List<TopicSummaryRow>> watchTopicSummaries(DateTime now) {
    final query = customSelect(
      '''
      SELECT
        t.id AS topic_id,
        t.name AS topic_name,
        t.description AS topic_description,
        t.priority AS topic_priority,
        t.anki_deck AS topic_anki_deck,
        t.created_at AS topic_created_at,
        (SELECT COUNT(*) FROM practices p WHERE p.topic_id = t.id) AS practice_count,
        (
          SELECT COUNT(*) FROM questions q
          INNER JOIN practices p ON p.id = q.practice_id
          WHERE p.topic_id = t.id
        ) AS question_count,
        (
          SELECT COUNT(*) FROM attempts a
          INNER JOIN sessions s ON s.id = a.session_id
          INNER JOIN questions q ON q.id = a.question_id
          INNER JOIN practices p ON p.id = q.practice_id
          WHERE p.topic_id = t.id AND s.status = 'completed' AND a.selected_index IS NOT NULL
        ) AS answered_count,
        (
          SELECT COUNT(*) FROM attempts a
          INNER JOIN sessions s ON s.id = a.session_id
          INNER JOIN questions q ON q.id = a.question_id
          INNER JOIN practices p ON p.id = q.practice_id
          WHERE p.topic_id = t.id AND s.status = 'completed' AND a.is_correct = 1
        ) AS correct_count,
        (
          SELECT COUNT(DISTINCT a.question_id) FROM attempts a
          INNER JOIN sessions s ON s.id = a.session_id
          INNER JOIN questions q ON q.id = a.question_id
          INNER JOIN practices p ON p.id = q.practice_id
          WHERE p.topic_id = t.id AND s.status = 'completed' AND a.is_correct = 1
        ) AS correct_question_count,
        (
          SELECT COUNT(*) FROM error_cards e
          INNER JOIN questions q ON q.id = e.question_id
          INNER JOIN practices p ON p.id = q.practice_id
          WHERE p.topic_id = t.id AND e.status = 'active'
        ) AS active_error_count,
        (
          SELECT COUNT(*) FROM error_cards e
          INNER JOIN questions q ON q.id = e.question_id
          INNER JOIN practices p ON p.id = q.practice_id
          WHERE p.topic_id = t.id AND e.status = 'active' AND e.due_at <= ?
        ) AS due_error_count,
        (
          SELECT COUNT(DISTINCT a.session_id) FROM attempts a
          INNER JOIN sessions s ON s.id = a.session_id
          INNER JOIN questions q ON q.id = a.question_id
          INNER JOIN practices p ON p.id = q.practice_id
          WHERE p.topic_id = t.id AND s.status = 'completed'
        ) AS session_count,
        (
          SELECT MAX(s.finished_at) FROM sessions s
          INNER JOIN attempts a ON a.session_id = s.id
          INNER JOIN questions q ON q.id = a.question_id
          INNER JOIN practices p ON p.id = q.practice_id
          WHERE p.topic_id = t.id AND s.status = 'completed'
        ) AS last_practiced_at
      FROM topics t
      ORDER BY (t.priority IS NULL) ASC, t.priority ASC, t.name COLLATE NOCASE ASC
      ''',
      variables: [Variable.withDateTime(now)],
      readsFrom: {topics, practices, questions, sessions, attempts, errorCards},
    );
    return query.watch().map(
      (rows) => rows.map(TopicSummaryRow.fromRow).toList(),
    );
  }

  Stream<List<PracticeSummaryRow>> watchPracticeSummaries(
    int topicId,
    DateTime now,
  ) {
    final query = customSelect(
      '''
      SELECT
        p.id AS practice_id,
        p.topic_id AS practice_topic_id,
        p.name AS practice_name,
        p.description AS practice_description,
        p.content_hash AS practice_content_hash,
        p.imported_at AS practice_imported_at,
        COUNT(q.id) AS question_count,
        (
          SELECT s.correct FROM sessions s
          WHERE s.practice_id = p.id AND s.status = 'completed'
          ORDER BY s.finished_at DESC LIMIT 1
        ) AS last_correct,
        (
          SELECT s.total FROM sessions s
          WHERE s.practice_id = p.id AND s.status = 'completed'
          ORDER BY s.finished_at DESC LIMIT 1
        ) AS last_total
      FROM practices p
      LEFT JOIN questions q ON q.practice_id = p.id
      WHERE p.topic_id = ?
      GROUP BY p.id
      ORDER BY p.id ASC
      ''',
      variables: [Variable.withInt(topicId)],
      readsFrom: {practices, questions, sessions},
    );
    return query.watch().map(
      (rows) => rows.map(PracticeSummaryRow.fromRow).toList(),
    );
  }
}

class HomeStatsRow {
  const HomeStatsRow({
    required this.activeErrors,
    required this.dueErrors,
    required this.incompleteErrorCards,
    required this.unexportedCards,
    required this.inProgressSessionId,
    required this.inProgressSessionMode,
    required this.inProgressSessionTotal,
  });

  final int activeErrors;
  final int dueErrors;
  final int incompleteErrorCards;
  final int unexportedCards;
  final int? inProgressSessionId;
  final String? inProgressSessionMode;
  final int? inProgressSessionTotal;
}

class TopicSummaryRow {
  const TopicSummaryRow({
    required this.topicId,
    required this.topicName,
    required this.topicDescription,
    required this.topicPriority,
    required this.topicAnkiDeck,
    required this.topicCreatedAt,
    required this.practiceCount,
    required this.questionCount,
    required this.answeredCount,
    required this.correctCount,
    required this.correctQuestionCount,
    required this.activeErrorCount,
    required this.dueErrorCount,
    required this.sessionCount,
    required this.lastPracticedAt,
  });

  factory TopicSummaryRow.fromRow(QueryRow row) {
    return TopicSummaryRow(
      topicId: row.read<int>('topic_id'),
      topicName: row.read<String>('topic_name'),
      topicDescription: row.read<String>('topic_description'),
      topicPriority: row.read<int?>('topic_priority'),
      topicAnkiDeck: row.read<String?>('topic_anki_deck'),
      topicCreatedAt: row.read<DateTime>('topic_created_at').toUtc(),
      practiceCount: row.read<int>('practice_count'),
      questionCount: row.read<int>('question_count'),
      answeredCount: row.read<int>('answered_count'),
      correctCount: row.read<int>('correct_count'),
      correctQuestionCount: row.read<int>('correct_question_count'),
      activeErrorCount: row.read<int>('active_error_count'),
      dueErrorCount: row.read<int>('due_error_count'),
      sessionCount: row.read<int>('session_count'),
      lastPracticedAt: row.read<DateTime?>('last_practiced_at')?.toUtc(),
    );
  }

  final int topicId;
  final String topicName;
  final String topicDescription;
  final int? topicPriority;
  final String? topicAnkiDeck;
  final DateTime topicCreatedAt;
  final int practiceCount;
  final int questionCount;
  final int answeredCount;
  final int correctCount;
  final int correctQuestionCount;
  final int activeErrorCount;
  final int dueErrorCount;
  final int sessionCount;
  final DateTime? lastPracticedAt;
}

class PracticeSummaryRow {
  const PracticeSummaryRow({
    required this.practiceId,
    required this.topicId,
    required this.name,
    required this.description,
    required this.contentHash,
    required this.importedAt,
    required this.questionCount,
    required this.lastCorrect,
    required this.lastTotal,
  });

  factory PracticeSummaryRow.fromRow(QueryRow row) {
    return PracticeSummaryRow(
      practiceId: row.read<int>('practice_id'),
      topicId: row.read<int>('practice_topic_id'),
      name: row.read<String>('practice_name'),
      description: row.read<String>('practice_description'),
      contentHash: row.read<String>('practice_content_hash'),
      importedAt: row.read<DateTime>('practice_imported_at').toUtc(),
      questionCount: row.read<int>('question_count'),
      lastCorrect: row.read<int?>('last_correct'),
      lastTotal: row.read<int?>('last_total'),
    );
  }

  final int practiceId;
  final int topicId;
  final String name;
  final String description;
  final String contentHash;
  final DateTime importedAt;
  final int questionCount;
  final int? lastCorrect;
  final int? lastTotal;

  double? get lastScore {
    final correct = lastCorrect;
    final total = lastTotal;
    if (correct == null || total == null || total == 0) return null;
    return correct / total;
  }
}
