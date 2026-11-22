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
    BasicCards,
    SkippedQuestions,
    Notes,
    Settings,
  ],
  daos: [TopicDao, SessionDao, CardDao, StatsDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 16;

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
        // Older schemas still name the table `manual_cards`; version 16
        // renames it. Guard the column so a partial database upgrades.
        if (await _hasTable('manual_cards') &&
            !await _hasColumns('manual_cards', const ['topic_name'])) {
          await customStatement(
            'ALTER TABLE manual_cards ADD COLUMN topic_name TEXT NOT NULL '
            "DEFAULT ''",
          );
        }
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
        if (await _hasTable('manual_cards') &&
            !await _hasColumns('manual_cards', const ['question_id'])) {
          await customStatement(
            'ALTER TABLE manual_cards ADD COLUMN question_id INTEGER NULL '
            'REFERENCES questions (id) ON DELETE SET NULL',
          );
        }
        if (await _hasTable('manual_cards') &&
            !await _hasColumns('manual_cards', const ['context'])) {
          await customStatement(
            'ALTER TABLE manual_cards ADD COLUMN context TEXT NOT NULL '
            "DEFAULT ''",
          );
        }
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
        if (await _hasTable('manual_cards') &&
            !await _hasColumns('manual_cards', const ['cognitive_type'])) {
          await customStatement(
            'ALTER TABLE manual_cards ADD COLUMN cognitive_type TEXT NOT NULL '
            "DEFAULT 'fact'",
          );
        }
        if (await _hasTable('manual_cards') &&
            !await _hasColumns('manual_cards', const ['subtopic'])) {
          await customStatement(
            'ALTER TABLE manual_cards ADD COLUMN subtopic TEXT NOT NULL '
            "DEFAULT ''",
          );
        }
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
        // Each statement is guarded on every indexed column so a hand-built
        // or partial database, lacking that table or any one column, still
        // upgrades; IF NOT EXISTS keeps a database that already has the
        // index, or a retried upgrade, at rest.
        if (await _hasColumns('questions', const ['practice_id', 'position'])) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS questions_practice_position '
            'ON questions (practice_id, position)',
          );
          // The single-column index is a prefix of the composite above, so
          // keeping both would only add write cost. It is dropped only once
          // its replacement exists.
          await customStatement('DROP INDEX IF EXISTS questions_practice');
        }
        final sessionsHaveFinishedAt = await _hasColumns('sessions', const [
          'status',
          'finished_at',
        ]);
        final sessionsHaveStartedAt = await _hasColumns('sessions', const [
          'status',
          'started_at',
        ]);
        if (sessionsHaveFinishedAt) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS sessions_status_finished '
            'ON sessions (status, finished_at)',
          );
        }
        if (sessionsHaveStartedAt) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS sessions_status_started '
            'ON sessions (status, started_at)',
          );
        }
        if (sessionsHaveFinishedAt || sessionsHaveStartedAt) {
          await customStatement('DROP INDEX IF EXISTS sessions_status');
        }
        if (await _hasColumns('concepts', const ['created_at'])) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS concepts_created '
            'ON concepts (created_at)',
          );
        }
        if (await _hasColumns('manual_cards', const ['created_at'])) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS manual_cards_created '
            'ON manual_cards (created_at)',
          );
        }
        if (await _hasColumns('notes', const ['created_at'])) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS notes_created ON notes (created_at)',
          );
        }
        if (await _hasColumns('error_cards', const ['created_at'])) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS error_cards_created '
            'ON error_cards (created_at)',
          );
        }
        if (await _hasColumns('error_cards', const [
          'status',
          'last_wrong_at',
        ])) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS error_cards_last_wrong '
            'ON error_cards (status, last_wrong_at)',
          );
        }
        if (await _hasColumns('skipped_questions', const [
          'handled_at',
          'created_at',
        ])) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS skipped_questions_handled_created '
            'ON skipped_questions (handled_at, created_at)',
          );
          await customStatement(
            'DROP INDEX IF EXISTS skipped_questions_handled',
          );
        }
      }
      if (from < 16) {
        // Version 16 names the table after the product term. Older schemas,
        // code paths and backups still call these rows manual cards. Every
        // statement is guarded so a partial or hand-built database upgrades
        // and a retried upgrade stays at rest.
        if (await _hasTable('manual_cards') &&
            !await _hasTable('basic_cards')) {
          await customStatement(
            'ALTER TABLE manual_cards RENAME TO basic_cards',
          );
        }
        if (await _hasTable('notes') &&
            await _hasColumns('notes', const ['manual_card_id']) &&
            !await _hasColumns('notes', const ['basic_card_id'])) {
          await customStatement(
            'ALTER TABLE notes RENAME COLUMN manual_card_id TO basic_card_id',
          );
        }
        await customStatement('DROP INDEX IF EXISTS manual_cards_exported');
        await customStatement('DROP INDEX IF EXISTS manual_cards_created');
        if (await _hasColumns('basic_cards', const ['exported_at'])) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS basic_cards_exported '
            'ON basic_cards (exported_at)',
          );
        }
        if (await _hasColumns('basic_cards', const ['created_at'])) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS basic_cards_created '
            'ON basic_cards (created_at)',
          );
        }
        await _repairNotesBasicCardReference();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Whether [table] exists and holds every column in [columns].
  ///
  /// Older, partial or hand-built databases used by recovery and tests may
  /// lack parts of the current schema; upgrade steps use this to skip an
  /// index instead of failing the whole migration.
  Future<bool> _hasColumns(String table, List<String> columns) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    final names = {for (final row in rows) row.read<String>('name')};
    return columns.every(names.contains);
  }

  /// Whether [table] exists in this database.
  Future<bool> _hasTable(String table) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = '$table'",
    ).get();
    return rows.isNotEmpty;
  }

  /// Repoints a leftover `notes` foreign key from `manual_cards` to the
  /// renamed `basic_cards` table.
  ///
  /// SQLite rewrites foreign keys on a table rename, but a hand-built database
  /// can keep the old target name once the old table is gone. Only then is
  /// `notes` rebuilt, keeping its rows and indexes.
  Future<void> _repairNotesBasicCardReference() async {
    if (!await _hasTable('notes') || !await _hasTable('basic_cards')) return;
    final foreignKeys = await customSelect('PRAGMA foreign_key_list(notes)')
        .get();
    final dangling = foreignKeys.any(
      (row) => row.read<String>('table') == 'manual_cards',
    );
    if (!dangling) return;

    final definitionRow = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'notes'",
    ).getSingle();
    final definition = definitionRow.read<String?>('sql');
    if (definition == null) return;
    final repaired = definition.replaceAllMapped(
      RegExp(r'REFERENCES\s+manual_cards\b', caseSensitive: false),
      (match) => 'REFERENCES basic_cards',
    );
    if (repaired == definition) return;

    final indexRows = await customSelect(
      "SELECT sql FROM sqlite_master "
      "WHERE type = 'index' AND tbl_name = 'notes' AND sql IS NOT NULL",
    ).get();
    final indexSql = [for (final row in indexRows) row.read<String>('sql')];

    await customStatement(
      'ALTER TABLE notes RENAME TO notes_basic_card_rebuild',
    );
    await customStatement(
      repaired.replaceFirst(
        RegExp(r'CREATE\s+TABLE\s+(?:"notes"|notes)'),
        'CREATE TABLE notes_rebuilt',
      ),
    );
    await customStatement(
      'INSERT INTO notes_rebuilt SELECT * FROM notes_basic_card_rebuild',
    );
    await customStatement('DROP TABLE notes_basic_card_rebuild');
    await customStatement('ALTER TABLE notes_rebuilt RENAME TO notes');
    for (final sql in indexSql) {
      await customStatement(sql);
    }
  }

  Future<void> clearAll() {
    return transaction(() async {
      await delete(attempts).go();
      await delete(concepts).go();
      await delete(basicCards).go();
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
