// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic_dao.dart';

// ignore_for_file: type=lint
mixin _$TopicDaoMixin on DatabaseAccessor<AppDatabase> {
  $TopicsTable get topics => attachedDatabase.topics;
  $PracticesTable get practices => attachedDatabase.practices;
  $QuestionsTable get questions => attachedDatabase.questions;
  TopicDaoManager get managers => TopicDaoManager(this);
}

class TopicDaoManager {
  final _$TopicDaoMixin _db;
  TopicDaoManager(this._db);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db.attachedDatabase, _db.topics);
  $$PracticesTableTableManager get practices =>
      $$PracticesTableTableManager(_db.attachedDatabase, _db.practices);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db.attachedDatabase, _db.questions);
}
