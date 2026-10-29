// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_dao.dart';

// ignore_for_file: type=lint
mixin _$SessionDaoMixin on DatabaseAccessor<AppDatabase> {
  $TopicsTable get topics => attachedDatabase.topics;
  $PracticesTable get practices => attachedDatabase.practices;
  $SessionsTable get sessions => attachedDatabase.sessions;
  $QuestionsTable get questions => attachedDatabase.questions;
  $SessionQuestionsTable get sessionQuestions =>
      attachedDatabase.sessionQuestions;
  $AttemptsTable get attempts => attachedDatabase.attempts;
  $ConceptsTable get concepts => attachedDatabase.concepts;
  SessionDaoManager get managers => SessionDaoManager(this);
}

class SessionDaoManager {
  final _$SessionDaoMixin _db;
  SessionDaoManager(this._db);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db.attachedDatabase, _db.topics);
  $$PracticesTableTableManager get practices =>
      $$PracticesTableTableManager(_db.attachedDatabase, _db.practices);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db.attachedDatabase, _db.questions);
  $$SessionQuestionsTableTableManager get sessionQuestions =>
      $$SessionQuestionsTableTableManager(
        _db.attachedDatabase,
        _db.sessionQuestions,
      );
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db.attachedDatabase, _db.attempts);
  $$ConceptsTableTableManager get concepts =>
      $$ConceptsTableTableManager(_db.attachedDatabase, _db.concepts);
}
