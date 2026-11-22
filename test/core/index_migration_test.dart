import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

const _schemaFifteenIndexes = <String>[
  'questions_practice_position',
  'sessions_status_finished',
  'sessions_status_started',
  'concepts_created',
  'manual_cards_created',
  'notes_created',
  'error_cards_created',
  'error_cards_last_wrong',
  'skipped_questions_handled_created',
];

const _supersededIndexes = <String>[
  'questions_practice',
  'sessions_status',
  'skipped_questions_handled',
];

void main() {
  test('schema 15 adds query indexes and keeps every schema 14 row', () async {
    final sqlite = sqlite3.openInMemory();
    _createSchemaFourteen(sqlite);
    _insertSchemaFourteenRows(sqlite);
    sqlite.execute('PRAGMA user_version = 14');

    final database = AppDatabase(NativeDatabase.opened(sqlite));
    addTearDown(database.close);

    expect(database.schemaVersion, 15);

    final indexes = await _indexNames(database);
    expect(indexes, containsAll(_schemaFifteenIndexes));
    expect(
      indexes.intersection(_supersededIndexes.toSet()),
      isEmpty,
      reason: 'Composite indexes replace the single-column prefixes.',
    );

    expect(await _indexColumns(database, 'questions_practice_position'), [
      'practice_id',
      'position',
    ]);
    expect(await _indexColumns(database, 'sessions_status_finished'), [
      'status',
      'finished_at',
    ]);
    expect(await _indexColumns(database, 'sessions_status_started'), [
      'status',
      'started_at',
    ]);
    expect(await _indexColumns(database, 'concepts_created'), ['created_at']);
    expect(await _indexColumns(database, 'manual_cards_created'), [
      'created_at',
    ]);
    expect(await _indexColumns(database, 'notes_created'), ['created_at']);
    expect(await _indexColumns(database, 'error_cards_created'), [
      'created_at',
    ]);
    expect(await _indexColumns(database, 'error_cards_last_wrong'), [
      'status',
      'last_wrong_at',
    ]);
    expect(await _indexColumns(database, 'skipped_questions_handled_created'), [
      'handled_at',
      'created_at',
    ]);

    final question = await database
        .customSelect('SELECT prompt, position FROM questions')
        .getSingle();
    expect(question.read<String>('prompt'), 'Kept question?');
    expect(question.read<int>('position'), 2);

    final session = await database
        .customSelect('SELECT status, mode FROM sessions')
        .getSingle();
    expect(session.read<String>('status'), 'completed');
    expect(session.read<String>('mode'), 'practice');

    final concept = await database
        .customSelect('SELECT term FROM concepts')
        .getSingle();
    expect(concept.read<String>('term'), 'VPC');

    final errorCard = await database
        .customSelect('SELECT status, last_wrong_at FROM error_cards')
        .getSingle();
    expect(errorCard.read<String>('status'), 'active');
    expect(errorCard.read<int>('last_wrong_at'), 1700000200);

    final manualCard = await database
        .customSelect('SELECT question FROM manual_cards')
        .getSingle();
    expect(manualCard.read<String>('question'), 'Kept basic card?');

    final note = await database
        .customSelect('SELECT text FROM notes')
        .getSingle();
    expect(note.read<String>('text'), 'Kept note');

    final skipped = await database
        .customSelect('SELECT question FROM skipped_questions')
        .getSingle();
    expect(skipped.read<String>('question'), 'Kept skipped question?');
  });

  test('schema 15 upgrade is idempotent when its indexes exist', () async {
    final sqlite = sqlite3.openInMemory();
    _createSchemaFourteen(sqlite);
    _insertSchemaFourteenRows(sqlite);
    for (final statement in _schemaFifteenIndexSql) {
      sqlite.execute(statement);
    }
    sqlite.execute('PRAGMA user_version = 14');

    final database = AppDatabase(NativeDatabase.opened(sqlite));
    addTearDown(database.close);

    final indexes = await _indexNames(database);
    expect(indexes, containsAll(_schemaFifteenIndexes));

    final count = await database
        .customSelect('SELECT COUNT(*) AS amount FROM error_cards')
        .getSingle();
    expect(count.read<int>('amount'), 1);
  });

  test('a fresh database creates every schema 15 index', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final indexes = await _indexNames(database);
    expect(indexes, containsAll(_schemaFifteenIndexes));
    expect(indexes.intersection(_supersededIndexes.toSet()), isEmpty);
  });
}

Future<Set<String>> _indexNames(AppDatabase database) async {
  final rows = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return {for (final row in rows) row.read<String>('name')};
}

Future<List<String>> _indexColumns(AppDatabase database, String index) async {
  final rows = await database.customSelect('PRAGMA index_info($index)').get();
  final columns = [
    for (final row in rows) (row.read<int>('seqno'), row.read<String>('name')),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final column in columns) column.$2];
}

void _createSchemaFourteen(Database sqlite) {
  sqlite.execute('''
    CREATE TABLE questions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      practice_id INTEGER NOT NULL,
      prompt TEXT NOT NULL,
      alternatives_json TEXT NOT NULL,
      correct_indexes_json TEXT NOT NULL DEFAULT '[0]',
      explanation TEXT NOT NULL,
      alternative_explanations_json TEXT NOT NULL,
      position INTEGER NOT NULL,
      subtopic TEXT NULL
    )
  ''');
  sqlite.execute('''
    CREATE TABLE sessions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      practice_id INTEGER NULL,
      mode TEXT NOT NULL,
      status TEXT NOT NULL,
      started_at INTEGER NOT NULL,
      finished_at INTEGER NULL,
      total INTEGER NOT NULL,
      correct INTEGER NOT NULL DEFAULT 0,
      skipped INTEGER NOT NULL DEFAULT 0,
      distracted INTEGER NOT NULL DEFAULT 0
    )
  ''');
  sqlite.execute('''
    CREATE TABLE concepts (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NULL,
      question_id INTEGER NULL,
      term TEXT NOT NULL,
      definition TEXT NOT NULL DEFAULT '',
      extra TEXT NOT NULL DEFAULT '',
      context TEXT NOT NULL DEFAULT '',
      topic_name TEXT NOT NULL DEFAULT '',
      subtopic TEXT NOT NULL DEFAULT '',
      source TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      exported_at INTEGER NULL
    )
  ''');
  sqlite.execute('''
    CREATE TABLE error_cards (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      question_id INTEGER NOT NULL,
      session_id INTEGER NULL,
      question TEXT NOT NULL,
      alternatives_json TEXT NOT NULL,
      correct_indexes_json TEXT NOT NULL DEFAULT '[0]',
      wrong_indexes_json TEXT NOT NULL DEFAULT '[0]',
      reasoning TEXT NOT NULL DEFAULT '',
      explanation TEXT NOT NULL DEFAULT '',
      alternative_explanations_json TEXT NOT NULL DEFAULT '[]',
      bias TEXT NOT NULL DEFAULT '',
      vaccine TEXT NOT NULL DEFAULT '',
      topic_name TEXT NOT NULL DEFAULT '',
      cognitive_type TEXT NOT NULL DEFAULT 'contrast',
      subtopic TEXT NOT NULL DEFAULT '',
      mistake_kinds_json TEXT NOT NULL DEFAULT '[]',
      distracted INTEGER NOT NULL DEFAULT 0,
      practice_name TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      last_wrong_at INTEGER NOT NULL,
      due_at INTEGER NOT NULL,
      details_completed_at INTEGER NULL,
      resolved_at INTEGER NULL,
      exported_at INTEGER NULL
    )
  ''');
  sqlite.execute('''
    CREATE TABLE manual_cards (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NULL,
      question_id INTEGER NULL,
      question TEXT NOT NULL,
      answer TEXT NOT NULL,
      context TEXT NOT NULL DEFAULT '',
      topic_name TEXT NOT NULL DEFAULT '',
      cognitive_type TEXT NOT NULL DEFAULT 'fact',
      subtopic TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      exported_at INTEGER NULL
    )
  ''');
  sqlite.execute('''
    CREATE TABLE skipped_questions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NULL,
      question_id INTEGER NOT NULL,
      question TEXT NOT NULL,
      alternatives_json TEXT NOT NULL,
      correct_indexes_json TEXT NOT NULL DEFAULT '[0]',
      explanation TEXT NOT NULL DEFAULT '',
      alternative_explanations_json TEXT NOT NULL DEFAULT '[]',
      reasoning TEXT NOT NULL DEFAULT '',
      topic_name TEXT NOT NULL DEFAULT '',
      practice_name TEXT NOT NULL DEFAULT '',
      unknown INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      handled_at INTEGER NULL,
      handled_kind TEXT NULL
    )
  ''');
  sqlite.execute('''
    CREATE TABLE notes (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NULL,
      question_id INTEGER NULL,
      text TEXT NOT NULL,
      context TEXT NOT NULL DEFAULT '',
      topic_name TEXT NOT NULL DEFAULT '',
      subtopic TEXT NOT NULL DEFAULT '',
      practice_name TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      kept_at INTEGER NULL,
      card_created_at INTEGER NULL,
      manual_card_id INTEGER NULL
    )
  ''');

  // Schema 14 indexes that version 15 replaces.
  sqlite.execute('CREATE INDEX questions_practice ON questions (practice_id)');
  sqlite.execute('CREATE INDEX sessions_status ON sessions (status)');
  sqlite.execute(
    'CREATE INDEX skipped_questions_handled '
    'ON skipped_questions (handled_at)',
  );
}

void _insertSchemaFourteenRows(Database sqlite) {
  sqlite.execute('''
    INSERT INTO questions (
      id, practice_id, prompt, alternatives_json, explanation,
      alternative_explanations_json, position
    ) VALUES (
      1, 3, 'Kept question?', '["A","B"]', 'Because A.', '["",""]', 2
    )
  ''');
  sqlite.execute('''
    INSERT INTO sessions (
      id, practice_id, mode, status, started_at, finished_at, total
    ) VALUES (1, 3, 'practice', 'completed', 1700000000, 1700000100, 1)
  ''');
  sqlite.execute('''
    INSERT INTO concepts (
      id, session_id, question_id, term, source, created_at
    ) VALUES (1, 1, 1, 'VPC', 'manual', 1700000300)
  ''');
  sqlite.execute('''
    INSERT INTO error_cards (
      id, question_id, session_id, question, alternatives_json, status,
      created_at, last_wrong_at, due_at, reasoning
    ) VALUES (
      1, 1, 1, 'Kept question?', '["A","B"]', 'active',
      1700000000, 1700000200, 1700000400, 'Read too fast.'
    )
  ''');
  sqlite.execute('''
    INSERT INTO manual_cards (
      id, session_id, question_id, question, answer, created_at
    ) VALUES (1, 1, 1, 'Kept basic card?', 'Answer', 1700000500)
  ''');
  sqlite.execute('''
    INSERT INTO skipped_questions (
      id, session_id, question_id, question, alternatives_json, created_at
    ) VALUES (
      1, 1, 1, 'Kept skipped question?', '["A","B"]', 1700000600
    )
  ''');
  sqlite.execute('''
    INSERT INTO notes (
      id, session_id, question_id, text, created_at
    ) VALUES (1, 1, 1, 'Kept note', 1700000700)
  ''');
}

const _schemaFifteenIndexSql = <String>[
  'CREATE INDEX questions_practice_position '
      'ON questions (practice_id, position)',
  'CREATE INDEX sessions_status_finished ON sessions (status, finished_at)',
  'CREATE INDEX sessions_status_started ON sessions (status, started_at)',
  'CREATE INDEX concepts_created ON concepts (created_at)',
  'CREATE INDEX manual_cards_created ON manual_cards (created_at)',
  'CREATE INDEX notes_created ON notes (created_at)',
  'CREATE INDEX error_cards_created ON error_cards (created_at)',
  'CREATE INDEX error_cards_last_wrong ON error_cards (status, last_wrong_at)',
  'CREATE INDEX skipped_questions_handled_created '
      'ON skipped_questions (handled_at, created_at)',
];
