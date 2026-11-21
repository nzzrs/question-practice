import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema 12 renames highlights to notes and keeps every row', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite.execute('PRAGMA foreign_keys = ON');
    sqlite.execute('''
      CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT)
    ''');
    sqlite.execute('''
      CREATE TABLE questions (id INTEGER PRIMARY KEY AUTOINCREMENT)
    ''');
    sqlite.execute('''
      CREATE TABLE manual_cards (id INTEGER PRIMARY KEY AUTOINCREMENT)
    ''');
    sqlite.execute('''
      CREATE TABLE highlights (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NULL REFERENCES sessions (id) ON DELETE CASCADE,
        question_id INTEGER NULL REFERENCES questions (id) ON DELETE SET NULL,
        phrase TEXT NOT NULL,
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
      'CREATE INDEX highlights_session ON highlights (session_id)',
    );
    sqlite.execute(
      'CREATE INDEX highlights_question ON highlights (question_id)',
    );
    sqlite.execute('INSERT INTO sessions (id) VALUES (1)');
    sqlite.execute('INSERT INTO questions (id) VALUES (7)');
    sqlite.execute('INSERT INTO manual_cards (id) VALUES (3)');
    sqlite.execute('''
      INSERT INTO highlights (
        id, session_id, question_id, phrase, context, topic_name, subtopic,
        practice_name, created_at, kept_at, card_created_at, manual_card_id
      ) VALUES (
        1, 1, 7, 'object storage', 'Cloud storage', 'Cloud', 'Storage',
        'Core', 1700000000, NULL, NULL, NULL
      )
    ''');
    sqlite.execute('''
      INSERT INTO highlights (
        id, session_id, question_id, phrase, context, topic_name, subtopic,
        practice_name, created_at, kept_at, card_created_at, manual_card_id
      ) VALUES (
        2, NULL, NULL, 'kept note', '', '', '', '', 1700000001,
        1700000002, 1700000003, 3
      )
    ''');
    sqlite.execute('PRAGMA user_version = 11');

    final database = AppDatabase(NativeDatabase.opened(sqlite));
    addTearDown(database.close);

    final notes = await database.select(database.notes).get();
    expect(notes, hasLength(2));
    expect(notes.first.noteText, 'object storage');
    expect(notes.first.sessionId, 1);
    expect(notes.first.questionId, 7);
    expect(notes.first.subtopic, 'Storage');
    expect(notes.last.noteText, 'kept note');
    expect(notes.last.sessionId, isNull);
    expect(notes.last.manualCardId, 3);
    expect(
      notes.last.keptAt,
      DateTime.fromMillisecondsSinceEpoch(1700000002000),
    );
    expect(
      notes.last.cardCreatedAt,
      DateTime.fromMillisecondsSinceEpoch(1700000003000),
    );

    final schemaObjects = await database
        .customSelect("SELECT name FROM sqlite_master")
        .get();
    final names = {for (final row in schemaObjects) row.read<String>('name')};
    expect(names, contains('notes'));
    expect(names, isNot(contains('highlights')));
    expect(names, contains('notes_session'));
    expect(names, contains('notes_question'));
    expect(names, isNot(contains('highlights_session')));
    expect(names, isNot(contains('highlights_question')));
    expect(database.schemaVersion, 12);

    // Renaming keeps the foreign keys attached to the new table.
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_key_list(notes)')
        .get();
    final targets = {
      for (final row in foreignKeys)
        row.read<String>('table'): row.read<String>('on_delete'),
    };
    expect(targets, {
      'sessions': 'CASCADE',
      'questions': 'SET NULL',
      'manual_cards': 'SET NULL',
    });

    // AUTOINCREMENT keeps counting after the rename instead of reusing ids.
    final nextId = await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            noteText: 'after upgrade',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000004000),
          ),
        );
    expect(nextId, 3);

    // ON DELETE SET NULL for the question, then for the manual card.
    await database.customStatement('DELETE FROM questions WHERE id = 7');
    final afterQuestion = await database
        .customSelect('SELECT id, question_id FROM notes ORDER BY id')
        .get();
    expect(afterQuestion.first.read<int?>('question_id'), isNull);

    await database.customStatement('DELETE FROM manual_cards WHERE id = 3');
    final afterCard = await database
        .customSelect('SELECT id, manual_card_id FROM notes ORDER BY id')
        .get();
    expect(afterCard[1].read<int?>('manual_card_id'), isNull);

    // ON DELETE CASCADE for the session.
    await database.customStatement('DELETE FROM sessions WHERE id = 1');
    final remaining = await database
        .customSelect('SELECT id FROM notes ORDER BY id')
        .get();
    expect([for (final row in remaining) row.read<int>('id')], [2, 3]);
  });

  test(
    'upgrading from schema 7 builds notes through versions 8 to 12',
    () async {
      final sqlite = sqlite3.openInMemory();
      for (final table in [
        'topics',
        'questions',
        'sessions',
        'attempts',
        'concepts',
        'error_cards',
        'manual_cards',
      ]) {
        sqlite.execute(
          'CREATE TABLE $table (id INTEGER PRIMARY KEY AUTOINCREMENT)',
        );
      }
      sqlite.execute('PRAGMA user_version = 7');

      final database = AppDatabase(NativeDatabase.opened(sqlite));
      addTearDown(database.close);

      final columns = await database
          .customSelect('PRAGMA table_info(notes)')
          .get();
      final names = {for (final row in columns) row.read<String>('name')};
      expect(names, containsAll(['id', 'text', 'context', 'subtopic']));
      expect(names, isNot(contains('phrase')));

      final id = await database
          .into(database.notes)
          .insert(
            NotesCompanion.insert(
              noteText: 'upgraded note',
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          );
      final saved = await (database.select(
        database.notes,
      )..where((row) => row.id.equals(id))).getSingle();
      expect(saved.noteText, 'upgraded note');
    },
  );

  test('a fresh database creates notes with the new indexes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final id = await database
        .into(database.notes)
        .insert(
          NotesCompanion.insert(
            noteText: 'fresh note',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );

    final saved = await (database.select(
      database.notes,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(saved.noteText, 'fresh note');

    final schemaObjects = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final indexes = {for (final row in schemaObjects) row.read<String>('name')};
    expect(indexes, contains('notes_session'));
    expect(indexes, contains('notes_question'));
  });
}
