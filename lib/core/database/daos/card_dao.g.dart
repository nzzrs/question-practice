// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_dao.dart';

// ignore_for_file: type=lint
mixin _$CardDaoMixin on DatabaseAccessor<AppDatabase> {
  $TopicsTable get topics => attachedDatabase.topics;
  $PracticesTable get practices => attachedDatabase.practices;
  $SessionsTable get sessions => attachedDatabase.sessions;
  $QuestionsTable get questions => attachedDatabase.questions;
  $ConceptsTable get concepts => attachedDatabase.concepts;
  $ErrorCardsTable get errorCards => attachedDatabase.errorCards;
  $ManualCardsTable get manualCards => attachedDatabase.manualCards;
  CardDaoManager get managers => CardDaoManager(this);
}

class CardDaoManager {
  final _$CardDaoMixin _db;
  CardDaoManager(this._db);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db.attachedDatabase, _db.topics);
  $$PracticesTableTableManager get practices =>
      $$PracticesTableTableManager(_db.attachedDatabase, _db.practices);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db.attachedDatabase, _db.questions);
  $$ConceptsTableTableManager get concepts =>
      $$ConceptsTableTableManager(_db.attachedDatabase, _db.concepts);
  $$ErrorCardsTableTableManager get errorCards =>
      $$ErrorCardsTableTableManager(_db.attachedDatabase, _db.errorCards);
  $$ManualCardsTableTableManager get manualCards =>
      $$ManualCardsTableTableManager(_db.attachedDatabase, _db.manualCards);
}
