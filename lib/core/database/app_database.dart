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
  int get schemaVersion => 5;

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
