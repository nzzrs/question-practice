import 'package:drift/drift.dart';

import 'daos/card_dao.dart';
import 'daos/session_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/stats_dao.dart';
import 'daos/topic_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Topics,
    Practices,
    Questions,
    Sessions,
    SessionQuestions,
    Attempts,
    Concepts,
    ErrorCards,
    ManualCards,
    SkippedQuestions,
    Notes,
    Settings,
  ],
  daos: [TopicDao, SessionDao, CardDao, StatsDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS error_cards_active_question '
        "ON error_cards(question_id) WHERE status = 'active'",
      );
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(topics, topics.ankiDeck);
        await migrator.addColumn(manualCards, manualCards.topicName);
      }
      if (from < 3) {
        await migrator.addColumn(questions, questions.correctIndexesJson);
        await migrator.addColumn(attempts, attempts.selectedIndexesJson);
        await migrator.addColumn(errorCards, errorCards.correctIndexesJson);
        await migrator.addColumn(errorCards, errorCards.wrongIndexesJson);
        await customStatement(
          "UPDATE questions SET correct_indexes_json = '[' || correct_index || ']'",
        );
        await customStatement(
          "UPDATE attempts SET selected_indexes_json = "
          "CASE WHEN selected_index IS NULL THEN '[]' "
          "ELSE '[' || selected_index || ']' END",
        );
        await customStatement(
          "UPDATE error_cards SET "
          "correct_indexes_json = '[' || correct_index || ']', "
          "wrong_indexes_json = '[' || wrong_index || ']'",
        );
      }
      if (from < 4) {
        await migrator.addColumn(errorCards, errorCards.explanation);
        await migrator.addColumn(
          errorCards,
          errorCards.alternativeExplanationsJson,
        );
      }
      if (from < 5) {
        await migrator.addColumn(practices, practices.isDone);
      }
      if (from < 6) {
        await migrator.addColumn(attempts, attempts.unknown);
        await migrator.addColumn(concepts, concepts.extra);
      }
      if (from < 7) {
        await migrator.addColumn(manualCards, manualCards.questionId);
        await migrator.addColumn(manualCards, manualCards.context);
        await migrator.createTable(skippedQuestions);
      }
      if (from < 8) {
        // Version 8 created the table as `highlights`; version 12 renames it.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS highlights (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NULL REFERENCES sessions (id) ON DELETE CASCADE,
            question_id INTEGER NULL REFERENCES questions (id) ON DELETE SET NULL,
            phrase TEXT NOT NULL,
            context TEXT NOT NULL DEFAULT '',
            topic_name TEXT NOT NULL DEFAULT '',
            practice_name TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            kept_at INTEGER NULL,
            card_created_at INTEGER NULL,
            manual_card_id INTEGER NULL REFERENCES manual_cards (id) ON DELETE SET NULL
          )
        ''');
      }
      if (from < 9) {
        await migrator.addColumn(topics, topics.archived);
      }
      if (from < 10) {
        await migrator.addColumn(questions, questions.subtopic);
      }
      if (from < 11) {
        await migrator.addColumn(topics, topics.minimumScore);
        await migrator.addColumn(topics, topics.targetScore);
        await migrator.addColumn(attempts, attempts.mistakeKindsJson);
        await migrator.addColumn(concepts, concepts.subtopic);
        await migrator.addColumn(errorCards, errorCards.cognitiveType);
        await migrator.addColumn(errorCards, errorCards.subtopic);
        await migrator.addColumn(errorCards, errorCards.mistakeKindsJson);
        await migrator.addColumn(manualCards, manualCards.cognitiveType);
        await migrator.addColumn(manualCards, manualCards.subtopic);
        await customStatement(
          'ALTER TABLE highlights ADD COLUMN subtopic TEXT NOT NULL DEFAULT \'\'',
        );
      }
      if (from < 12) {
        await customStatement('ALTER TABLE highlights RENAME TO notes');
        await customStatement('ALTER TABLE notes RENAME COLUMN phrase TO text');
        await customStatement('DROP INDEX IF EXISTS highlights_session');
        await customStatement('DROP INDEX IF EXISTS highlights_question');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS notes_session ON notes (session_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS notes_question ON notes (question_id)',
        );
      }
      if (from < 13) {
        await migrator.addColumn(errorCards, errorCards.distracted);
      }
      if (from < 14) {
        // Reopen active cards that were missed again after their details were
        // completed, or whose details are still missing. Older versions did
        // not clear the export marker, so these rows stayed hidden from the
        // Errors flow. Rows, notes and history are preserved. The guard keeps
        // partial or hand-built databases from failing the upgrade.
        final errorCardColumns = await customSelect(
          'PRAGMA table_info(error_cards)',
        ).get();
        final errorCardNames = {
          for (final row in errorCardColumns) row.read<String>('name'),
        };
        if (errorCardNames.containsAll(const [
          'exported_at',
          'status',
          'details_completed_at',
          'last_wrong_at',
        ])) {
          await customStatement('''
            UPDATE error_cards
            SET exported_at = NULL
            WHERE status = 'active'
              AND exported_at IS NOT NULL
              AND (
                details_completed_at IS NULL
                OR last_wrong_at > details_completed_at
              )
          ''');
        }
      }
      if (from < 15) {
        // Indexes for the current query patterns: ordered question lists per
        // practice, session history by status, newest card and note lists,
        // the due/needs-details review queues and the skipped-question queue.
        // Each statement is guarded so a hand-built or partial database
        // without that table or column still upgrades; IF NOT EXISTS keeps a
        // database that already has the index, or a retried upgrade, at rest.
        if (await _hasColumn('questions', 'position')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS questions_practice_position '
            'ON questions (practice_id, position)',
          );
        }
        if (await _hasColumn('sessions', 'finished_at')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS sessions_status_finished '
            'ON sessions (status, finished_at)',
          );
        }
        if (await _hasColumn('sessions', 'started_at')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS sessions_status_started '
            'ON sessions (status, started_at)',
          );
        }
        if (await _hasColumn('concepts', 'created_at')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS concepts_created '
            'ON concepts (created_at)',
          );
        }
        if (await _hasColumn('manual_cards', 'created_at')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS manual_cards_created '
            'ON manual_cards (created_at)',
          );
        }
        if (await _hasColumn('notes', 'created_at')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS notes_created ON notes (created_at)',
          );
        }
        if (await _hasColumn('error_cards', 'created_at')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS error_cards_created '
            'ON error_cards (created_at)',
          );
        }
        if (await _hasColumn('error_cards', 'last_wrong_at')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS error_cards_last_wrong '
            'ON error_cards (status, last_wrong_at)',
          );
        }
        if (await _hasColumn('skipped_questions', 'created_at')) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS skipped_questions_handled_created '
            'ON skipped_questions (handled_at, created_at)',
          );
        }
        // The single-column indexes above are prefixes of the new composite
        // indexes, so keeping both would only add write cost.
        await customStatement('DROP INDEX IF EXISTS questions_practice');
        await customStatement('DROP INDEX IF EXISTS sessions_status');
        await customStatement('DROP INDEX IF EXISTS skipped_questions_handled');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Whether [table] and [column] both exist in the connected database.
  ///
  /// Older, partial or hand-built databases used by recovery and tests may
  /// lack parts of the current schema; upgrade steps use this to skip an
  /// index instead of failing the whole migration.
  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((row) => row.read<String>('name') == column);
  }

  Future<void> clearAll() {
    return transaction(() async {
      await delete(attempts).go();
      await delete(concepts).go();
      await delete(manualCards).go();
      await delete(skippedQuestions).go();
      await delete(notes).go();
      await delete(errorCards).go();
      await delete(sessionQuestions).go();
      await delete(sessions).go();
      await delete(questions).go();
      await delete(practices).go();
      await delete(topics).go();
      await delete(settings).go();
    });
  }
}
