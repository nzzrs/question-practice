import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'schema 16 renames manual cards and keeps every schema 15 row',
    () async {
      final sqlite = sqlite3.openInMemory();
      _createSchemaFifteen(sqlite);
      _insertSchemaFifteenRows(sqlite);
      sqlite.execute('PRAGMA user_version = 15');

      final database = AppDatabase(NativeDatabase.opened(sqlite));
      addTearDown(database.close);

      expect(database.schemaVersion, 16);

      final schemaNames = await _schemaNames(database);
      expect(schemaNames, contains('basic_cards'));
      expect(schemaNames, isNot(contains('manual_cards')));

      final cardColumns = await _columnNames(database, 'basic_cards');
      expect(cardColumns, containsAll(['id', 'question', 'answer']));

      final noteColumns = await _columnNames(database, 'notes');
      expect(noteColumns, contains('basic_card_id'));
      expect(noteColumns, isNot(contains('manual_card_id')));

      final indexes = await _indexNames(database);
      expect(indexes, contains('basic_cards_exported'));
      expect(indexes, contains('basic_cards_created'));
      expect(indexes, isNot(contains('manual_cards_exported')));
      expect(indexes, isNot(contains('manual_cards_created')));
      expect(await _indexColumns(database, 'basic_cards_exported'), [
        'exported_at',
      ]);
      expect(await _indexColumns(database, 'basic_cards_created'), [
        'created_at',
      ]);

      final foreignKeys = await _foreignKeys(database, 'notes');
      expect(foreignKeys['basic_cards'], 'SET NULL');
      expect(foreignKeys['questions'], 'SET NULL');
      expect(foreignKeys['sessions'], 'CASCADE');

      final card = await database.select(database.basicCards).getSingle();
      expect(card.question, 'Kept basic card?');
      expect(card.answer, 'Answer');
      expect(card.topicName, 'Cloud');
      expect(card.exportedAt, isNull);

      final note = await database.select(database.notes).getSingle();
      expect(note.noteText, 'Kept note');
      expect(note.basicCardId, 1);

      // ON DELETE SET NULL still links notes to the renamed table.
      await database.customStatement('DELETE FROM basic_cards WHERE id = 1');
      final afterDelete = await database.select(database.notes).getSingle();
      expect(afterDelete.basicCardId, isNull);
    },
  );

  test('schema 16 upgrade is idempotent when it already ran', () async {
    final sqlite = sqlite3.openInMemory();
    _createSchemaFifteen(sqlite);
    _insertSchemaFifteenRows(sqlite);
    sqlite.execute('ALTER TABLE manual_cards RENAME TO basic_cards');
    sqlite.execute(
      'ALTER TABLE notes RENAME COLUMN manual_card_id TO basic_card_id',
    );
    sqlite.execute('DROP INDEX manual_cards_exported');
    sqlite.execute('DROP INDEX manual_cards_created');
    sqlite.execute(
      'CREATE INDEX basic_cards_exported ON basic_cards (exported_at)',
    );
    sqlite.execute(
      'CREATE INDEX basic_cards_created ON basic_cards (created_at)',
    );
    sqlite.execute('PRAGMA user_version = 15');

    final database = AppDatabase(NativeDatabase.opened(sqlite));
    addTearDown(database.close);

    final cards = await database.select(database.basicCards).get();
    expect(cards.single.question, 'Kept basic card?');
    final note = await database.select(database.notes).getSingle();
    expect(note.basicCardId, 1);

    final indexes = await _indexNames(database);
    expect(indexes, contains('basic_cards_exported'));
    expect(indexes, contains('basic_cards_created'));
  });

  test(
    'a partial schema 15 database upgrades without the card table',
    () async {
      final sqlite = sqlite3.openInMemory();
      sqlite.execute('''
      CREATE TABLE notes (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        manual_card_id INTEGER NULL
      )
    ''');
      sqlite.execute('''
      INSERT INTO notes (id, text, created_at, manual_card_id)
      VALUES (1, 'Partial note', 1700000000, 9)
    ''');
      sqlite.execute('PRAGMA user_version = 15');

      final database = AppDatabase(NativeDatabase.opened(sqlite));
      addTearDown(database.close);

      final columns = await _columnNames(database, 'notes');
      expect(columns, contains('basic_card_id'));
      expect(columns, isNot(contains('manual_card_id')));

      final note = await database
          .customSelect('SELECT text, basic_card_id FROM notes')
          .getSingle();
      expect(note.read<String>('text'), 'Partial note');
      expect(note.read<int?>('basic_card_id'), 9);
    },
  );

  test('a hand-built notes foreign key is repointed to basic cards', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite.execute('''
        CREATE TABLE basic_cards (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          question TEXT NOT NULL,
          answer TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          exported_at INTEGER NULL
        )
      ''');
    sqlite.execute('''
        CREATE TABLE notes (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          text TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          manual_card_id INTEGER NULL
            REFERENCES manual_cards (id) ON DELETE SET NULL
        )
      ''');
    sqlite.execute('''
        INSERT INTO basic_cards (id, question, answer, created_at)
        VALUES (1, 'Front?', 'Back', 1700000000)
      ''');
    sqlite.execute('''
        INSERT INTO notes (id, text, created_at, manual_card_id)
        VALUES (1, 'Linked note', 1700000000, 1)
      ''');
    sqlite.execute('PRAGMA user_version = 15');

    final database = AppDatabase(NativeDatabase.opened(sqlite));
    addTearDown(database.close);

    final columns = await _columnNames(database, 'notes');
    expect(columns, contains('basic_card_id'));
    expect(columns, isNot(contains('manual_card_id')));

    final foreignKeys = await _foreignKeys(database, 'notes');
    expect(foreignKeys['basic_cards'], 'SET NULL');

    final note = await database
        .customSelect('SELECT text, basic_card_id FROM notes')
        .getSingle();
    expect(note.read<String>('text'), 'Linked note');
    expect(note.read<int?>('basic_card_id'), 1);

    await database.customStatement('DELETE FROM basic_cards WHERE id = 1');
    final afterDelete = await database
        .customSelect('SELECT basic_card_id FROM notes')
        .getSingle();
    expect(afterDelete.read<int?>('basic_card_id'), isNull);
  });

  test('a quoted legacy notes foreign key is repointed', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite.execute('''
        CREATE TABLE basic_cards (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          question TEXT NOT NULL,
          answer TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          exported_at INTEGER NULL
        )
      ''');
    // Lower-case DDL with a quoted target, as a hand-built database may keep.
    sqlite.execute('''
        create table notes (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          text TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          manual_card_id INTEGER NULL
            REFERENCES "manual_cards" (id) ON DELETE SET NULL
        )
      ''');
    sqlite.execute('''
        INSERT INTO basic_cards (id, question, answer, created_at)
        VALUES (1, 'Front?', 'Back', 1700000000)
      ''');
    sqlite.execute('''
        INSERT INTO notes (id, text, created_at, manual_card_id)
        VALUES (1, 'Quoted link', 1700000000, 1)
      ''');
    sqlite.execute('PRAGMA user_version = 15');

    final database = AppDatabase(NativeDatabase.opened(sqlite));
    addTearDown(database.close);

    expect(await _columnNames(database, 'notes'), contains('basic_card_id'));
    final foreignKeys = await _foreignKeys(database, 'notes');
    expect(foreignKeys, isNot(contains('manual_cards')));
    expect(foreignKeys['basic_cards'], 'SET NULL');

    await database.customStatement('DELETE FROM basic_cards WHERE id = 1');
    final afterDelete = await database
        .customSelect('SELECT basic_card_id FROM notes')
        .getSingle();
    expect(afterDelete.read<int?>('basic_card_id'), isNull);
  });

  test('a fresh database uses basic card names and indexes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final schemaNames = await _schemaNames(database);
    expect(schemaNames, contains('basic_cards'));
    expect(schemaNames, isNot(contains('manual_cards')));

    final noteColumns = await _columnNames(database, 'notes');
    expect(noteColumns, contains('basic_card_id'));
    expect(noteColumns, isNot(contains('manual_card_id')));

    final indexes = await _indexNames(database);
    expect(indexes, contains('basic_cards_exported'));
    expect(indexes, contains('basic_cards_created'));

    final cardId = await database
        .into(database.basicCards)
        .insert(
          BasicCardsCompanion.insert(
            question: 'Fresh front?',
            answer: 'Fresh back',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
    final noteId = await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            noteText: 'Fresh note',
            createdAt: DateTime.utc(2026, 1, 1),
            basicCardId: Value(cardId),
          ),
        );

    final saved = await (database.select(
      database.notes,
    )..where((row) => row.id.equals(noteId))).getSingle();
    expect(saved.basicCardId, cardId);
  });
}

Future<Set<String>> _schemaNames(AppDatabase database) async {
  final rows = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return {for (final row in rows) row.read<String>('name')};
}

Future<Set<String>> _columnNames(AppDatabase database, String table) async {
  final rows = await database.customSelect('PRAGMA table_info($table)').get();
  return {for (final row in rows) row.read<String>('name')};
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

Future<Map<String, String>> _foreignKeys(
  AppDatabase database,
  String table,
) async {
  final rows = await database
      .customSelect('PRAGMA foreign_key_list($table)')
      .get();
  return {
    for (final row in rows)
      row.read<String>('table'): row.read<String>('on_delete'),
  };
}

void _createSchemaFifteen(Database sqlite) {
  sqlite.execute('''
    CREATE TABLE sessions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    )
  ''');
  sqlite.execute('''
    CREATE TABLE questions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      prompt TEXT NOT NULL
    )
  ''');
  sqlite.execute('''
    CREATE TABLE manual_cards (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NULL REFERENCES sessions (id) ON DELETE CASCADE,
      question_id INTEGER NULL REFERENCES questions (id) ON DELETE SET NULL,
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
    CREATE TABLE notes (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NULL REFERENCES sessions (id) ON DELETE CASCADE,
      question_id INTEGER NULL REFERENCES questions (id) ON DELETE SET NULL,
      text TEXT NOT NULL,
      context TEXT NOT NULL DEFAULT '',
      topic_name TEXT NOT NULL DEFAULT '',
      subtopic TEXT NOT NULL DEFAULT '',
      practice_name TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      kept_at INTEGER NULL,
      card_created_at INTEGER NULL,
      manual_card_id INTEGER NULL
        REFERENCES manual_cards (id) ON DELETE SET NULL
    )
  ''');
  sqlite.execute(
    'CREATE INDEX manual_cards_exported ON manual_cards (exported_at)',
  );
  sqlite.execute(
    'CREATE INDEX manual_cards_created ON manual_cards (created_at)',
  );
}

void _insertSchemaFifteenRows(Database sqlite) {
  sqlite.execute('INSERT INTO sessions (id) VALUES (1)');
  sqlite.execute(
    "INSERT INTO questions (id, prompt) VALUES (1, 'Kept question?')",
  );
  sqlite.execute('''
    INSERT INTO manual_cards (
      id, session_id, question_id, question, answer, topic_name, created_at
    ) VALUES (
      1, 1, 1, 'Kept basic card?', 'Answer', 'Cloud', 1700000000
    )
  ''');
  sqlite.execute('''
    INSERT INTO notes (
      id, session_id, question_id, text, created_at, manual_card_id
    ) VALUES (1, 1, 1, 'Kept note', 1700000100, 1)
  ''');
}
