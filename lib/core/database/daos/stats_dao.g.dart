// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_dao.dart';

// ignore_for_file: type=lint
mixin _$StatsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TopicsTable get topics => attachedDatabase.topics;
  $PracticesTable get practices => attachedDatabase.practices;
  $QuestionsTable get questions => attachedDatabase.questions;
  $SessionsTable get sessions => attachedDatabase.sessions;
  $SessionQuestionsTable get sessionQuestions =>
      attachedDatabase.sessionQuestions;
  $AttemptsTable get attempts => attachedDatabase.attempts;
  $ErrorCardsTable get errorCards => attachedDatabase.errorCards;
  $ConceptsTable get concepts => attachedDatabase.concepts;
  $ManualCardsTable get manualCards => attachedDatabase.manualCards;
  StatsDaoManager get managers => StatsDaoManager(this);
}

class StatsDaoManager {
  final _$StatsDaoMixin _db;
  StatsDaoManager(this._db);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db.attachedDatabase, _db.topics);
  $$PracticesTableTableManager get practices =>
      $$PracticesTableTableManager(_db.attachedDatabase, _db.practices);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db.attachedDatabase, _db.questions);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
  $$SessionQuestionsTableTableManager get sessionQuestions =>
      $$SessionQuestionsTableTableManager(
        _db.attachedDatabase,
        _db.sessionQuestions,
      );
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db.attachedDatabase, _db.attempts);
  $$ErrorCardsTableTableManager get errorCards =>
      $$ErrorCardsTableTableManager(_db.attachedDatabase, _db.errorCards);
  $$ConceptsTableTableManager get concepts =>
      $$ConceptsTableTableManager(_db.attachedDatabase, _db.concepts);
  $$ManualCardsTableTableManager get manualCards =>
      $$ManualCardsTableTableManager(_db.attachedDatabase, _db.manualCards);
}
