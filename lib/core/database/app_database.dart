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
    Settings,
  ],
  daos: [TopicDao, SessionDao, CardDao, StatsDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS error_cards_active_question '
        "ON error_cards(question_id) WHERE status = 'active'",
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> clearAll() {
    return transaction(() async {
      await delete(attempts).go();
      await delete(concepts).go();
      await delete(manualCards).go();
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
