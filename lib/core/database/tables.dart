import 'package:drift/drift.dart';

@DataClassName('TopicRow')
class Topics extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get priority => integer().nullable()();
  TextColumn get ankiDeck => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('PracticeRow')
@TableIndex(name: 'practices_topic', columns: {#topicId})
class Practices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get topicId =>
      integer().references(Topics, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get contentHash => text()();
  DateTimeColumn get importedAt => dateTime()();
}

@DataClassName('QuestionRow')
@TableIndex(name: 'questions_practice', columns: {#practiceId})
class Questions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get practiceId =>
      integer().references(Practices, #id, onDelete: KeyAction.cascade)();
  TextColumn get prompt => text()();
  TextColumn get alternativesJson => text()();
  TextColumn get correctIndexesJson =>
      text().withDefault(const Constant('[0]'))();
  TextColumn get explanation => text()();
  TextColumn get alternativeExplanationsJson => text()();
  IntColumn get position => integer()();
}

@DataClassName('SessionRow')
@TableIndex(name: 'sessions_status', columns: {#status})
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get practiceId => integer().nullable().references(
    Practices,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get mode => text()();
  TextColumn get status => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get total => integer()();
  IntColumn get correct => integer().withDefault(const Constant(0))();
  IntColumn get skipped => integer().withDefault(const Constant(0))();
  IntColumn get distracted => integer().withDefault(const Constant(0))();
}

@DataClassName('SessionQuestionRow')
@TableIndex(name: 'session_questions_question', columns: {#questionId})
class SessionQuestions extends Table {
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get questionId =>
      integer().references(Questions, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {sessionId, questionId};
}

@DataClassName('AttemptRow')
@TableIndex(name: 'attempts_session', columns: {#sessionId})
@TableIndex(name: 'attempts_question', columns: {#questionId})
class Attempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get questionId =>
      integer().references(Questions, #id, onDelete: KeyAction.cascade)();
  TextColumn get selectedIndexesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get reasoning => text().withDefault(const Constant(''))();
  BoolColumn get distracted => boolean().withDefault(const Constant(false))();
  BoolColumn get isCorrect => boolean()();
  DateTimeColumn get answeredAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, questionId},
  ];
}

@DataClassName('ConceptRow')
@TableIndex(name: 'concepts_session', columns: {#sessionId})
@TableIndex(name: 'concepts_exported', columns: {#exportedAt})
class Concepts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().nullable().references(
    Sessions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get questionId => integer().nullable().references(
    Questions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get term => text()();
  TextColumn get definition => text().withDefault(const Constant(''))();
  TextColumn get context => text().withDefault(const Constant(''))();
  TextColumn get topicName => text().withDefault(const Constant(''))();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get exportedAt => dateTime().nullable()();
}

@DataClassName('ErrorCardRow')
@TableIndex(name: 'error_cards_due', columns: {#status, #dueAt})
@TableIndex(name: 'error_cards_question', columns: {#questionId})
@TableIndex(name: 'error_cards_session', columns: {#sessionId})
class ErrorCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId =>
      integer().references(Questions, #id, onDelete: KeyAction.cascade)();
  IntColumn get sessionId => integer().nullable().references(
    Sessions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get question => text()();
  TextColumn get alternativesJson => text()();
  TextColumn get correctIndexesJson =>
      text().withDefault(const Constant('[0]'))();
  TextColumn get wrongIndexesJson =>
      text().withDefault(const Constant('[0]'))();
  TextColumn get reasoning => text().withDefault(const Constant(''))();
  TextColumn get explanation => text().withDefault(const Constant(''))();
  TextColumn get alternativeExplanationsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get bias => text().withDefault(const Constant(''))();
  TextColumn get vaccine => text().withDefault(const Constant(''))();
  TextColumn get topicName => text().withDefault(const Constant(''))();
  TextColumn get practiceName => text().withDefault(const Constant(''))();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastWrongAt => dateTime()();
  DateTimeColumn get dueAt => dateTime()();
  DateTimeColumn get detailsCompletedAt => dateTime().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  DateTimeColumn get exportedAt => dateTime().nullable()();
}

@DataClassName('ManualCardRow')
@TableIndex(name: 'manual_cards_exported', columns: {#exportedAt})
class ManualCards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().nullable().references(
    Sessions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get question => text()();
  TextColumn get answer => text()();
  TextColumn get topicName => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get exportedAt => dateTime().nullable()();
}

@DataClassName('SettingRow')
class Settings extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
