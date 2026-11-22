import 'package:drift/drift.dart';

@DataClassName('TopicRow')
class Topics extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get priority => integer().nullable()();
  TextColumn get ankiDeck => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Percentage below which a score counts as failing this topic.
  IntColumn get minimumScore => integer().withDefault(const Constant(70))();

  /// Percentage at which a score counts as meeting the topic goal.
  IntColumn get targetScore => integer().withDefault(const Constant(80))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
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
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
}

@DataClassName('QuestionRow')
@TableIndex(
  name: 'questions_practice_position',
  columns: {#practiceId, #position},
)
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

  /// Optional grouping inside a practice. Null or empty means uncategorized.
  TextColumn get subtopic => text().nullable()();
}

@DataClassName('SessionRow')
@TableIndex(name: 'sessions_status_finished', columns: {#status, #finishedAt})
@TableIndex(name: 'sessions_status_started', columns: {#status, #startedAt})
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
  BoolColumn get unknown => boolean().withDefault(const Constant(false))();

  /// Quick classifications chosen after a wrong answer.
  TextColumn get mistakeKindsJson => text().withDefault(const Constant('[]'))();
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
@TableIndex(name: 'concepts_created', columns: {#createdAt})
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
  TextColumn get extra => text().withDefault(const Constant(''))();
  TextColumn get context => text().withDefault(const Constant(''))();
  TextColumn get topicName => text().withDefault(const Constant(''))();

  /// Optional grouping inside the topic, copied from the source question.
  TextColumn get subtopic => text().withDefault(const Constant(''))();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get exportedAt => dateTime().nullable()();
}

@DataClassName('ErrorCardRow')
@TableIndex(name: 'error_cards_due', columns: {#status, #dueAt})
@TableIndex(name: 'error_cards_question', columns: {#questionId})
@TableIndex(name: 'error_cards_session', columns: {#sessionId})
@TableIndex(name: 'error_cards_created', columns: {#createdAt})
@TableIndex(name: 'error_cards_last_wrong', columns: {#status, #lastWrongAt})
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

  /// Cognitive shape of the card generated from this error.
  TextColumn get cognitiveType =>
      text().withDefault(const Constant('contrast'))();

  /// Optional grouping inside the topic, copied from the source question.
  TextColumn get subtopic => text().withDefault(const Constant(''))();

  /// Quick classifications chosen after the wrong answer.
  ///
  /// Legacy data only: practice no longer collects mistake kinds.
  TextColumn get mistakeKindsJson => text().withDefault(const Constant('[]'))();

  /// A distracted re-test kept the card due instead of counting a new error.
  BoolColumn get distracted => boolean().withDefault(const Constant(false))();
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
@TableIndex(name: 'manual_cards_created', columns: {#createdAt})
class ManualCards extends Table {
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
  TextColumn get question => text()();
  TextColumn get answer => text()();

  /// Optional source passage shown above the question on the card front.
  TextColumn get context => text().withDefault(const Constant(''))();
  TextColumn get topicName => text().withDefault(const Constant(''))();

  /// Cognitive shape of the card: fact, heuristic, contrast or concept.
  TextColumn get cognitiveType => text().withDefault(const Constant('fact'))();

  /// Optional grouping inside the topic, copied from the source question.
  TextColumn get subtopic => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get exportedAt => dateTime().nullable()();
}

@DataClassName('SkippedQuestionRow')
@TableIndex(
  name: 'skipped_questions_handled_created',
  columns: {#handledAt, #createdAt},
)
@TableIndex(name: 'skipped_questions_session', columns: {#sessionId})
class SkippedQuestions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().nullable().references(
    Sessions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get questionId =>
      integer().references(Questions, #id, onDelete: KeyAction.cascade)();
  TextColumn get question => text()();
  TextColumn get alternativesJson => text()();
  TextColumn get correctIndexesJson =>
      text().withDefault(const Constant('[0]'))();
  TextColumn get explanation => text().withDefault(const Constant(''))();
  TextColumn get alternativeExplanationsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get reasoning => text().withDefault(const Constant(''))();
  TextColumn get topicName => text().withDefault(const Constant(''))();
  TextColumn get practiceName => text().withDefault(const Constant(''))();
  BoolColumn get unknown => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get handledAt => dateTime().nullable()();
  TextColumn get handledKind => text().nullable()();
}

/// A passage the learner saved to revisit, tied to the question it came from.
@DataClassName('NoteRow')
@TableIndex(name: 'notes_session', columns: {#sessionId})
@TableIndex(name: 'notes_question', columns: {#questionId})
@TableIndex(name: 'notes_created', columns: {#createdAt})
class Notes extends Table {
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

  /// The passage itself. Stored and exported as `text`.
  @JsonKey('text')
  TextColumn get noteText => text().named('text')();
  TextColumn get context => text().withDefault(const Constant(''))();
  TextColumn get topicName => text().withDefault(const Constant(''))();
  TextColumn get subtopic => text().withDefault(const Constant(''))();
  TextColumn get practiceName => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get keptAt => dateTime().nullable()();
  DateTimeColumn get cardCreatedAt => dateTime().nullable()();
  IntColumn get manualCardId => integer().nullable().references(
    ManualCards,
    #id,
    onDelete: KeyAction.setNull,
  )();
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
