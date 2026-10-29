// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TopicsTable extends Topics with TableInfo<$TopicsTable, TopicRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ankiDeckMeta = const VerificationMeta(
    'ankiDeck',
  );
  @override
  late final GeneratedColumn<String> ankiDeck = GeneratedColumn<String>(
    'anki_deck',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    priority,
    ankiDeck,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<TopicRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('anki_deck')) {
      context.handle(
        _ankiDeckMeta,
        ankiDeck.isAcceptableOrUnknown(data['anki_deck']!, _ankiDeckMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TopicRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TopicRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      ),
      ankiDeck: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anki_deck'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TopicsTable createAlias(String alias) {
    return $TopicsTable(attachedDatabase, alias);
  }
}

class TopicRow extends DataClass implements Insertable<TopicRow> {
  final int id;
  final String name;
  final String description;
  final int? priority;
  final String? ankiDeck;
  final DateTime createdAt;
  const TopicRow({
    required this.id,
    required this.name,
    required this.description,
    this.priority,
    this.ankiDeck,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || priority != null) {
      map['priority'] = Variable<int>(priority);
    }
    if (!nullToAbsent || ankiDeck != null) {
      map['anki_deck'] = Variable<String>(ankiDeck);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TopicsCompanion toCompanion(bool nullToAbsent) {
    return TopicsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      priority: priority == null && nullToAbsent
          ? const Value.absent()
          : Value(priority),
      ankiDeck: ankiDeck == null && nullToAbsent
          ? const Value.absent()
          : Value(ankiDeck),
      createdAt: Value(createdAt),
    );
  }

  factory TopicRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TopicRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      priority: serializer.fromJson<int?>(json['priority']),
      ankiDeck: serializer.fromJson<String?>(json['ankiDeck']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'priority': serializer.toJson<int?>(priority),
      'ankiDeck': serializer.toJson<String?>(ankiDeck),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TopicRow copyWith({
    int? id,
    String? name,
    String? description,
    Value<int?> priority = const Value.absent(),
    Value<String?> ankiDeck = const Value.absent(),
    DateTime? createdAt,
  }) => TopicRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    priority: priority.present ? priority.value : this.priority,
    ankiDeck: ankiDeck.present ? ankiDeck.value : this.ankiDeck,
    createdAt: createdAt ?? this.createdAt,
  );
  TopicRow copyWithCompanion(TopicsCompanion data) {
    return TopicRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      priority: data.priority.present ? data.priority.value : this.priority,
      ankiDeck: data.ankiDeck.present ? data.ankiDeck.value : this.ankiDeck,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TopicRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('ankiDeck: $ankiDeck, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, priority, ankiDeck, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TopicRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.priority == this.priority &&
          other.ankiDeck == this.ankiDeck &&
          other.createdAt == this.createdAt);
}

class TopicsCompanion extends UpdateCompanion<TopicRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> description;
  final Value<int?> priority;
  final Value<String?> ankiDeck;
  final Value<DateTime> createdAt;
  const TopicsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.ankiDeck = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TopicsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.ankiDeck = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<TopicRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? priority,
    Expression<String>? ankiDeck,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority,
      if (ankiDeck != null) 'anki_deck': ankiDeck,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TopicsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? description,
    Value<int?>? priority,
    Value<String?>? ankiDeck,
    Value<DateTime>? createdAt,
  }) {
    return TopicsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      ankiDeck: ankiDeck ?? this.ankiDeck,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (ankiDeck.present) {
      map['anki_deck'] = Variable<String>(ankiDeck.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TopicsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('ankiDeck: $ankiDeck, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PracticesTable extends Practices
    with TableInfo<$PracticesTable, PracticeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<int> topicId = GeneratedColumn<int>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES topics (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    topicId,
    name,
    description,
    contentHash,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practices';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}topic_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $PracticesTable createAlias(String alias) {
    return $PracticesTable(attachedDatabase, alias);
  }
}

class PracticeRow extends DataClass implements Insertable<PracticeRow> {
  final int id;
  final int topicId;
  final String name;
  final String description;
  final String contentHash;
  final DateTime importedAt;
  const PracticeRow({
    required this.id,
    required this.topicId,
    required this.name,
    required this.description,
    required this.contentHash,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['topic_id'] = Variable<int>(topicId);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['content_hash'] = Variable<String>(contentHash);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  PracticesCompanion toCompanion(bool nullToAbsent) {
    return PracticesCompanion(
      id: Value(id),
      topicId: Value(topicId),
      name: Value(name),
      description: Value(description),
      contentHash: Value(contentHash),
      importedAt: Value(importedAt),
    );
  }

  factory PracticeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeRow(
      id: serializer.fromJson<int>(json['id']),
      topicId: serializer.fromJson<int>(json['topicId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'topicId': serializer.toJson<int>(topicId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'contentHash': serializer.toJson<String>(contentHash),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  PracticeRow copyWith({
    int? id,
    int? topicId,
    String? name,
    String? description,
    String? contentHash,
    DateTime? importedAt,
  }) => PracticeRow(
    id: id ?? this.id,
    topicId: topicId ?? this.topicId,
    name: name ?? this.name,
    description: description ?? this.description,
    contentHash: contentHash ?? this.contentHash,
    importedAt: importedAt ?? this.importedAt,
  );
  PracticeRow copyWithCompanion(PracticesCompanion data) {
    return PracticeRow(
      id: data.id.present ? data.id.value : this.id,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeRow(')
          ..write('id: $id, ')
          ..write('topicId: $topicId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('contentHash: $contentHash, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, topicId, name, description, contentHash, importedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeRow &&
          other.id == this.id &&
          other.topicId == this.topicId &&
          other.name == this.name &&
          other.description == this.description &&
          other.contentHash == this.contentHash &&
          other.importedAt == this.importedAt);
}

class PracticesCompanion extends UpdateCompanion<PracticeRow> {
  final Value<int> id;
  final Value<int> topicId;
  final Value<String> name;
  final Value<String> description;
  final Value<String> contentHash;
  final Value<DateTime> importedAt;
  const PracticesCompanion({
    this.id = const Value.absent(),
    this.topicId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.importedAt = const Value.absent(),
  });
  PracticesCompanion.insert({
    this.id = const Value.absent(),
    required int topicId,
    required String name,
    this.description = const Value.absent(),
    required String contentHash,
    required DateTime importedAt,
  }) : topicId = Value(topicId),
       name = Value(name),
       contentHash = Value(contentHash),
       importedAt = Value(importedAt);
  static Insertable<PracticeRow> custom({
    Expression<int>? id,
    Expression<int>? topicId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? contentHash,
    Expression<DateTime>? importedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (topicId != null) 'topic_id': topicId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (contentHash != null) 'content_hash': contentHash,
      if (importedAt != null) 'imported_at': importedAt,
    });
  }

  PracticesCompanion copyWith({
    Value<int>? id,
    Value<int>? topicId,
    Value<String>? name,
    Value<String>? description,
    Value<String>? contentHash,
    Value<DateTime>? importedAt,
  }) {
    return PracticesCompanion(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      name: name ?? this.name,
      description: description ?? this.description,
      contentHash: contentHash ?? this.contentHash,
      importedAt: importedAt ?? this.importedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<int>(topicId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticesCompanion(')
          ..write('id: $id, ')
          ..write('topicId: $topicId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('contentHash: $contentHash, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }
}

class $QuestionsTable extends Questions
    with TableInfo<$QuestionsTable, QuestionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _practiceIdMeta = const VerificationMeta(
    'practiceId',
  );
  @override
  late final GeneratedColumn<int> practiceId = GeneratedColumn<int>(
    'practice_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practices (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alternativesJsonMeta = const VerificationMeta(
    'alternativesJson',
  );
  @override
  late final GeneratedColumn<String> alternativesJson = GeneratedColumn<String>(
    'alternatives_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctIndexMeta = const VerificationMeta(
    'correctIndex',
  );
  @override
  late final GeneratedColumn<int> correctIndex = GeneratedColumn<int>(
    'correct_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alternativeExplanationsJsonMeta =
      const VerificationMeta('alternativeExplanationsJson');
  @override
  late final GeneratedColumn<String> alternativeExplanationsJson =
      GeneratedColumn<String>(
        'alternative_explanations_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    practiceId,
    prompt,
    alternativesJson,
    correctIndex,
    explanation,
    alternativeExplanationsJson,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuestionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('practice_id')) {
      context.handle(
        _practiceIdMeta,
        practiceId.isAcceptableOrUnknown(data['practice_id']!, _practiceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_practiceIdMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('alternatives_json')) {
      context.handle(
        _alternativesJsonMeta,
        alternativesJson.isAcceptableOrUnknown(
          data['alternatives_json']!,
          _alternativesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_alternativesJsonMeta);
    }
    if (data.containsKey('correct_index')) {
      context.handle(
        _correctIndexMeta,
        correctIndex.isAcceptableOrUnknown(
          data['correct_index']!,
          _correctIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctIndexMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_explanationMeta);
    }
    if (data.containsKey('alternative_explanations_json')) {
      context.handle(
        _alternativeExplanationsJsonMeta,
        alternativeExplanationsJson.isAcceptableOrUnknown(
          data['alternative_explanations_json']!,
          _alternativeExplanationsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_alternativeExplanationsJsonMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuestionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuestionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      practiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}practice_id'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      alternativesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternatives_json'],
      )!,
      correctIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_index'],
      )!,
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      )!,
      alternativeExplanationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternative_explanations_json'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $QuestionsTable createAlias(String alias) {
    return $QuestionsTable(attachedDatabase, alias);
  }
}

class QuestionRow extends DataClass implements Insertable<QuestionRow> {
  final int id;
  final int practiceId;
  final String prompt;
  final String alternativesJson;
  final int correctIndex;
  final String explanation;
  final String alternativeExplanationsJson;
  final int position;
  const QuestionRow({
    required this.id,
    required this.practiceId,
    required this.prompt,
    required this.alternativesJson,
    required this.correctIndex,
    required this.explanation,
    required this.alternativeExplanationsJson,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['practice_id'] = Variable<int>(practiceId);
    map['prompt'] = Variable<String>(prompt);
    map['alternatives_json'] = Variable<String>(alternativesJson);
    map['correct_index'] = Variable<int>(correctIndex);
    map['explanation'] = Variable<String>(explanation);
    map['alternative_explanations_json'] = Variable<String>(
      alternativeExplanationsJson,
    );
    map['position'] = Variable<int>(position);
    return map;
  }

  QuestionsCompanion toCompanion(bool nullToAbsent) {
    return QuestionsCompanion(
      id: Value(id),
      practiceId: Value(practiceId),
      prompt: Value(prompt),
      alternativesJson: Value(alternativesJson),
      correctIndex: Value(correctIndex),
      explanation: Value(explanation),
      alternativeExplanationsJson: Value(alternativeExplanationsJson),
      position: Value(position),
    );
  }

  factory QuestionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuestionRow(
      id: serializer.fromJson<int>(json['id']),
      practiceId: serializer.fromJson<int>(json['practiceId']),
      prompt: serializer.fromJson<String>(json['prompt']),
      alternativesJson: serializer.fromJson<String>(json['alternativesJson']),
      correctIndex: serializer.fromJson<int>(json['correctIndex']),
      explanation: serializer.fromJson<String>(json['explanation']),
      alternativeExplanationsJson: serializer.fromJson<String>(
        json['alternativeExplanationsJson'],
      ),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'practiceId': serializer.toJson<int>(practiceId),
      'prompt': serializer.toJson<String>(prompt),
      'alternativesJson': serializer.toJson<String>(alternativesJson),
      'correctIndex': serializer.toJson<int>(correctIndex),
      'explanation': serializer.toJson<String>(explanation),
      'alternativeExplanationsJson': serializer.toJson<String>(
        alternativeExplanationsJson,
      ),
      'position': serializer.toJson<int>(position),
    };
  }

  QuestionRow copyWith({
    int? id,
    int? practiceId,
    String? prompt,
    String? alternativesJson,
    int? correctIndex,
    String? explanation,
    String? alternativeExplanationsJson,
    int? position,
  }) => QuestionRow(
    id: id ?? this.id,
    practiceId: practiceId ?? this.practiceId,
    prompt: prompt ?? this.prompt,
    alternativesJson: alternativesJson ?? this.alternativesJson,
    correctIndex: correctIndex ?? this.correctIndex,
    explanation: explanation ?? this.explanation,
    alternativeExplanationsJson:
        alternativeExplanationsJson ?? this.alternativeExplanationsJson,
    position: position ?? this.position,
  );
  QuestionRow copyWithCompanion(QuestionsCompanion data) {
    return QuestionRow(
      id: data.id.present ? data.id.value : this.id,
      practiceId: data.practiceId.present
          ? data.practiceId.value
          : this.practiceId,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      alternativesJson: data.alternativesJson.present
          ? data.alternativesJson.value
          : this.alternativesJson,
      correctIndex: data.correctIndex.present
          ? data.correctIndex.value
          : this.correctIndex,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      alternativeExplanationsJson: data.alternativeExplanationsJson.present
          ? data.alternativeExplanationsJson.value
          : this.alternativeExplanationsJson,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuestionRow(')
          ..write('id: $id, ')
          ..write('practiceId: $practiceId, ')
          ..write('prompt: $prompt, ')
          ..write('alternativesJson: $alternativesJson, ')
          ..write('correctIndex: $correctIndex, ')
          ..write('explanation: $explanation, ')
          ..write('alternativeExplanationsJson: $alternativeExplanationsJson, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    practiceId,
    prompt,
    alternativesJson,
    correctIndex,
    explanation,
    alternativeExplanationsJson,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionRow &&
          other.id == this.id &&
          other.practiceId == this.practiceId &&
          other.prompt == this.prompt &&
          other.alternativesJson == this.alternativesJson &&
          other.correctIndex == this.correctIndex &&
          other.explanation == this.explanation &&
          other.alternativeExplanationsJson ==
              this.alternativeExplanationsJson &&
          other.position == this.position);
}

class QuestionsCompanion extends UpdateCompanion<QuestionRow> {
  final Value<int> id;
  final Value<int> practiceId;
  final Value<String> prompt;
  final Value<String> alternativesJson;
  final Value<int> correctIndex;
  final Value<String> explanation;
  final Value<String> alternativeExplanationsJson;
  final Value<int> position;
  const QuestionsCompanion({
    this.id = const Value.absent(),
    this.practiceId = const Value.absent(),
    this.prompt = const Value.absent(),
    this.alternativesJson = const Value.absent(),
    this.correctIndex = const Value.absent(),
    this.explanation = const Value.absent(),
    this.alternativeExplanationsJson = const Value.absent(),
    this.position = const Value.absent(),
  });
  QuestionsCompanion.insert({
    this.id = const Value.absent(),
    required int practiceId,
    required String prompt,
    required String alternativesJson,
    required int correctIndex,
    required String explanation,
    required String alternativeExplanationsJson,
    required int position,
  }) : practiceId = Value(practiceId),
       prompt = Value(prompt),
       alternativesJson = Value(alternativesJson),
       correctIndex = Value(correctIndex),
       explanation = Value(explanation),
       alternativeExplanationsJson = Value(alternativeExplanationsJson),
       position = Value(position);
  static Insertable<QuestionRow> custom({
    Expression<int>? id,
    Expression<int>? practiceId,
    Expression<String>? prompt,
    Expression<String>? alternativesJson,
    Expression<int>? correctIndex,
    Expression<String>? explanation,
    Expression<String>? alternativeExplanationsJson,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (practiceId != null) 'practice_id': practiceId,
      if (prompt != null) 'prompt': prompt,
      if (alternativesJson != null) 'alternatives_json': alternativesJson,
      if (correctIndex != null) 'correct_index': correctIndex,
      if (explanation != null) 'explanation': explanation,
      if (alternativeExplanationsJson != null)
        'alternative_explanations_json': alternativeExplanationsJson,
      if (position != null) 'position': position,
    });
  }

  QuestionsCompanion copyWith({
    Value<int>? id,
    Value<int>? practiceId,
    Value<String>? prompt,
    Value<String>? alternativesJson,
    Value<int>? correctIndex,
    Value<String>? explanation,
    Value<String>? alternativeExplanationsJson,
    Value<int>? position,
  }) {
    return QuestionsCompanion(
      id: id ?? this.id,
      practiceId: practiceId ?? this.practiceId,
      prompt: prompt ?? this.prompt,
      alternativesJson: alternativesJson ?? this.alternativesJson,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
      alternativeExplanationsJson:
          alternativeExplanationsJson ?? this.alternativeExplanationsJson,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (practiceId.present) {
      map['practice_id'] = Variable<int>(practiceId.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (alternativesJson.present) {
      map['alternatives_json'] = Variable<String>(alternativesJson.value);
    }
    if (correctIndex.present) {
      map['correct_index'] = Variable<int>(correctIndex.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (alternativeExplanationsJson.present) {
      map['alternative_explanations_json'] = Variable<String>(
        alternativeExplanationsJson.value,
      );
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestionsCompanion(')
          ..write('id: $id, ')
          ..write('practiceId: $practiceId, ')
          ..write('prompt: $prompt, ')
          ..write('alternativesJson: $alternativesJson, ')
          ..write('correctIndex: $correctIndex, ')
          ..write('explanation: $explanation, ')
          ..write('alternativeExplanationsJson: $alternativeExplanationsJson, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _practiceIdMeta = const VerificationMeta(
    'practiceId',
  );
  @override
  late final GeneratedColumn<int> practiceId = GeneratedColumn<int>(
    'practice_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practices (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skippedMeta = const VerificationMeta(
    'skipped',
  );
  @override
  late final GeneratedColumn<int> skipped = GeneratedColumn<int>(
    'skipped',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _distractedMeta = const VerificationMeta(
    'distracted',
  );
  @override
  late final GeneratedColumn<int> distracted = GeneratedColumn<int>(
    'distracted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    practiceId,
    mode,
    status,
    startedAt,
    finishedAt,
    total,
    correct,
    skipped,
    distracted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('practice_id')) {
      context.handle(
        _practiceIdMeta,
        practiceId.isAcceptableOrUnknown(data['practice_id']!, _practiceIdMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    }
    if (data.containsKey('skipped')) {
      context.handle(
        _skippedMeta,
        skipped.isAcceptableOrUnknown(data['skipped']!, _skippedMeta),
      );
    }
    if (data.containsKey('distracted')) {
      context.handle(
        _distractedMeta,
        distracted.isAcceptableOrUnknown(data['distracted']!, _distractedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      practiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}practice_id'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      )!,
      skipped: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skipped'],
      )!,
      distracted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distracted'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final int id;
  final int? practiceId;
  final String mode;
  final String status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int total;
  final int correct;
  final int skipped;
  final int distracted;
  const SessionRow({
    required this.id,
    this.practiceId,
    required this.mode,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    required this.total,
    required this.correct,
    required this.skipped,
    required this.distracted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || practiceId != null) {
      map['practice_id'] = Variable<int>(practiceId);
    }
    map['mode'] = Variable<String>(mode);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    map['total'] = Variable<int>(total);
    map['correct'] = Variable<int>(correct);
    map['skipped'] = Variable<int>(skipped);
    map['distracted'] = Variable<int>(distracted);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      practiceId: practiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(practiceId),
      mode: Value(mode),
      status: Value(status),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      total: Value(total),
      correct: Value(correct),
      skipped: Value(skipped),
      distracted: Value(distracted),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<int>(json['id']),
      practiceId: serializer.fromJson<int?>(json['practiceId']),
      mode: serializer.fromJson<String>(json['mode']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      total: serializer.fromJson<int>(json['total']),
      correct: serializer.fromJson<int>(json['correct']),
      skipped: serializer.fromJson<int>(json['skipped']),
      distracted: serializer.fromJson<int>(json['distracted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'practiceId': serializer.toJson<int?>(practiceId),
      'mode': serializer.toJson<String>(mode),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'total': serializer.toJson<int>(total),
      'correct': serializer.toJson<int>(correct),
      'skipped': serializer.toJson<int>(skipped),
      'distracted': serializer.toJson<int>(distracted),
    };
  }

  SessionRow copyWith({
    int? id,
    Value<int?> practiceId = const Value.absent(),
    String? mode,
    String? status,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    int? total,
    int? correct,
    int? skipped,
    int? distracted,
  }) => SessionRow(
    id: id ?? this.id,
    practiceId: practiceId.present ? practiceId.value : this.practiceId,
    mode: mode ?? this.mode,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    total: total ?? this.total,
    correct: correct ?? this.correct,
    skipped: skipped ?? this.skipped,
    distracted: distracted ?? this.distracted,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      practiceId: data.practiceId.present
          ? data.practiceId.value
          : this.practiceId,
      mode: data.mode.present ? data.mode.value : this.mode,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      total: data.total.present ? data.total.value : this.total,
      correct: data.correct.present ? data.correct.value : this.correct,
      skipped: data.skipped.present ? data.skipped.value : this.skipped,
      distracted: data.distracted.present
          ? data.distracted.value
          : this.distracted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('practiceId: $practiceId, ')
          ..write('mode: $mode, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('total: $total, ')
          ..write('correct: $correct, ')
          ..write('skipped: $skipped, ')
          ..write('distracted: $distracted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    practiceId,
    mode,
    status,
    startedAt,
    finishedAt,
    total,
    correct,
    skipped,
    distracted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.practiceId == this.practiceId &&
          other.mode == this.mode &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.total == this.total &&
          other.correct == this.correct &&
          other.skipped == this.skipped &&
          other.distracted == this.distracted);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<int> id;
  final Value<int?> practiceId;
  final Value<String> mode;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<int> total;
  final Value<int> correct;
  final Value<int> skipped;
  final Value<int> distracted;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.practiceId = const Value.absent(),
    this.mode = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.total = const Value.absent(),
    this.correct = const Value.absent(),
    this.skipped = const Value.absent(),
    this.distracted = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    this.practiceId = const Value.absent(),
    required String mode,
    required String status,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    required int total,
    this.correct = const Value.absent(),
    this.skipped = const Value.absent(),
    this.distracted = const Value.absent(),
  }) : mode = Value(mode),
       status = Value(status),
       startedAt = Value(startedAt),
       total = Value(total);
  static Insertable<SessionRow> custom({
    Expression<int>? id,
    Expression<int>? practiceId,
    Expression<String>? mode,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? total,
    Expression<int>? correct,
    Expression<int>? skipped,
    Expression<int>? distracted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (practiceId != null) 'practice_id': practiceId,
      if (mode != null) 'mode': mode,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (total != null) 'total': total,
      if (correct != null) 'correct': correct,
      if (skipped != null) 'skipped': skipped,
      if (distracted != null) 'distracted': distracted,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<int?>? practiceId,
    Value<String>? mode,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<int>? total,
    Value<int>? correct,
    Value<int>? skipped,
    Value<int>? distracted,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      practiceId: practiceId ?? this.practiceId,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      total: total ?? this.total,
      correct: correct ?? this.correct,
      skipped: skipped ?? this.skipped,
      distracted: distracted ?? this.distracted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (practiceId.present) {
      map['practice_id'] = Variable<int>(practiceId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (skipped.present) {
      map['skipped'] = Variable<int>(skipped.value);
    }
    if (distracted.present) {
      map['distracted'] = Variable<int>(distracted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('practiceId: $practiceId, ')
          ..write('mode: $mode, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('total: $total, ')
          ..write('correct: $correct, ')
          ..write('skipped: $skipped, ')
          ..write('distracted: $distracted')
          ..write(')'))
        .toString();
  }
}

class $SessionQuestionsTable extends SessionQuestions
    with TableInfo<$SessionQuestionsTable, SessionQuestionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionQuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<int> questionId = GeneratedColumn<int>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sessionId, questionId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionQuestionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, questionId};
  @override
  SessionQuestionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionQuestionRow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}question_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $SessionQuestionsTable createAlias(String alias) {
    return $SessionQuestionsTable(attachedDatabase, alias);
  }
}

class SessionQuestionRow extends DataClass
    implements Insertable<SessionQuestionRow> {
  final int sessionId;
  final int questionId;
  final int position;
  const SessionQuestionRow({
    required this.sessionId,
    required this.questionId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<int>(sessionId);
    map['question_id'] = Variable<int>(questionId);
    map['position'] = Variable<int>(position);
    return map;
  }

  SessionQuestionsCompanion toCompanion(bool nullToAbsent) {
    return SessionQuestionsCompanion(
      sessionId: Value(sessionId),
      questionId: Value(questionId),
      position: Value(position),
    );
  }

  factory SessionQuestionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionQuestionRow(
      sessionId: serializer.fromJson<int>(json['sessionId']),
      questionId: serializer.fromJson<int>(json['questionId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<int>(sessionId),
      'questionId': serializer.toJson<int>(questionId),
      'position': serializer.toJson<int>(position),
    };
  }

  SessionQuestionRow copyWith({
    int? sessionId,
    int? questionId,
    int? position,
  }) => SessionQuestionRow(
    sessionId: sessionId ?? this.sessionId,
    questionId: questionId ?? this.questionId,
    position: position ?? this.position,
  );
  SessionQuestionRow copyWithCompanion(SessionQuestionsCompanion data) {
    return SessionQuestionRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionQuestionRow(')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, questionId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionQuestionRow &&
          other.sessionId == this.sessionId &&
          other.questionId == this.questionId &&
          other.position == this.position);
}

class SessionQuestionsCompanion extends UpdateCompanion<SessionQuestionRow> {
  final Value<int> sessionId;
  final Value<int> questionId;
  final Value<int> position;
  final Value<int> rowid;
  const SessionQuestionsCompanion({
    this.sessionId = const Value.absent(),
    this.questionId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionQuestionsCompanion.insert({
    required int sessionId,
    required int questionId,
    required int position,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       questionId = Value(questionId),
       position = Value(position);
  static Insertable<SessionQuestionRow> custom({
    Expression<int>? sessionId,
    Expression<int>? questionId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (questionId != null) 'question_id': questionId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionQuestionsCompanion copyWith({
    Value<int>? sessionId,
    Value<int>? questionId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return SessionQuestionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      questionId: questionId ?? this.questionId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<int>(questionId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionQuestionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts
    with TableInfo<$AttemptsTable, AttemptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<int> questionId = GeneratedColumn<int>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _selectedIndexMeta = const VerificationMeta(
    'selectedIndex',
  );
  @override
  late final GeneratedColumn<int> selectedIndex = GeneratedColumn<int>(
    'selected_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasoningMeta = const VerificationMeta(
    'reasoning',
  );
  @override
  late final GeneratedColumn<String> reasoning = GeneratedColumn<String>(
    'reasoning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _distractedMeta = const VerificationMeta(
    'distracted',
  );
  @override
  late final GeneratedColumn<bool> distracted = GeneratedColumn<bool>(
    'distracted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("distracted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isCorrectMeta = const VerificationMeta(
    'isCorrect',
  );
  @override
  late final GeneratedColumn<bool> isCorrect = GeneratedColumn<bool>(
    'is_correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _answeredAtMeta = const VerificationMeta(
    'answeredAt',
  );
  @override
  late final GeneratedColumn<DateTime> answeredAt = GeneratedColumn<DateTime>(
    'answered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    questionId,
    selectedIndex,
    reasoning,
    distracted,
    isCorrect,
    answeredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttemptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('selected_index')) {
      context.handle(
        _selectedIndexMeta,
        selectedIndex.isAcceptableOrUnknown(
          data['selected_index']!,
          _selectedIndexMeta,
        ),
      );
    }
    if (data.containsKey('reasoning')) {
      context.handle(
        _reasoningMeta,
        reasoning.isAcceptableOrUnknown(data['reasoning']!, _reasoningMeta),
      );
    }
    if (data.containsKey('distracted')) {
      context.handle(
        _distractedMeta,
        distracted.isAcceptableOrUnknown(data['distracted']!, _distractedMeta),
      );
    }
    if (data.containsKey('is_correct')) {
      context.handle(
        _isCorrectMeta,
        isCorrect.isAcceptableOrUnknown(data['is_correct']!, _isCorrectMeta),
      );
    } else if (isInserting) {
      context.missing(_isCorrectMeta);
    }
    if (data.containsKey('answered_at')) {
      context.handle(
        _answeredAtMeta,
        answeredAt.isAcceptableOrUnknown(data['answered_at']!, _answeredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_answeredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId, questionId},
  ];
  @override
  AttemptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttemptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}question_id'],
      )!,
      selectedIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}selected_index'],
      ),
      reasoning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning'],
      )!,
      distracted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}distracted'],
      )!,
      isCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_correct'],
      )!,
      answeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}answered_at'],
      )!,
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }
}

class AttemptRow extends DataClass implements Insertable<AttemptRow> {
  final int id;
  final int sessionId;
  final int questionId;
  final int? selectedIndex;
  final String reasoning;
  final bool distracted;
  final bool isCorrect;
  final DateTime answeredAt;
  const AttemptRow({
    required this.id,
    required this.sessionId,
    required this.questionId,
    this.selectedIndex,
    required this.reasoning,
    required this.distracted,
    required this.isCorrect,
    required this.answeredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['question_id'] = Variable<int>(questionId);
    if (!nullToAbsent || selectedIndex != null) {
      map['selected_index'] = Variable<int>(selectedIndex);
    }
    map['reasoning'] = Variable<String>(reasoning);
    map['distracted'] = Variable<bool>(distracted);
    map['is_correct'] = Variable<bool>(isCorrect);
    map['answered_at'] = Variable<DateTime>(answeredAt);
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      questionId: Value(questionId),
      selectedIndex: selectedIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(selectedIndex),
      reasoning: Value(reasoning),
      distracted: Value(distracted),
      isCorrect: Value(isCorrect),
      answeredAt: Value(answeredAt),
    );
  }

  factory AttemptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttemptRow(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      questionId: serializer.fromJson<int>(json['questionId']),
      selectedIndex: serializer.fromJson<int?>(json['selectedIndex']),
      reasoning: serializer.fromJson<String>(json['reasoning']),
      distracted: serializer.fromJson<bool>(json['distracted']),
      isCorrect: serializer.fromJson<bool>(json['isCorrect']),
      answeredAt: serializer.fromJson<DateTime>(json['answeredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'questionId': serializer.toJson<int>(questionId),
      'selectedIndex': serializer.toJson<int?>(selectedIndex),
      'reasoning': serializer.toJson<String>(reasoning),
      'distracted': serializer.toJson<bool>(distracted),
      'isCorrect': serializer.toJson<bool>(isCorrect),
      'answeredAt': serializer.toJson<DateTime>(answeredAt),
    };
  }

  AttemptRow copyWith({
    int? id,
    int? sessionId,
    int? questionId,
    Value<int?> selectedIndex = const Value.absent(),
    String? reasoning,
    bool? distracted,
    bool? isCorrect,
    DateTime? answeredAt,
  }) => AttemptRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    questionId: questionId ?? this.questionId,
    selectedIndex: selectedIndex.present
        ? selectedIndex.value
        : this.selectedIndex,
    reasoning: reasoning ?? this.reasoning,
    distracted: distracted ?? this.distracted,
    isCorrect: isCorrect ?? this.isCorrect,
    answeredAt: answeredAt ?? this.answeredAt,
  );
  AttemptRow copyWithCompanion(AttemptsCompanion data) {
    return AttemptRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      selectedIndex: data.selectedIndex.present
          ? data.selectedIndex.value
          : this.selectedIndex,
      reasoning: data.reasoning.present ? data.reasoning.value : this.reasoning,
      distracted: data.distracted.present
          ? data.distracted.value
          : this.distracted,
      isCorrect: data.isCorrect.present ? data.isCorrect.value : this.isCorrect,
      answeredAt: data.answeredAt.present
          ? data.answeredAt.value
          : this.answeredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttemptRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('selectedIndex: $selectedIndex, ')
          ..write('reasoning: $reasoning, ')
          ..write('distracted: $distracted, ')
          ..write('isCorrect: $isCorrect, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    questionId,
    selectedIndex,
    reasoning,
    distracted,
    isCorrect,
    answeredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttemptRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.questionId == this.questionId &&
          other.selectedIndex == this.selectedIndex &&
          other.reasoning == this.reasoning &&
          other.distracted == this.distracted &&
          other.isCorrect == this.isCorrect &&
          other.answeredAt == this.answeredAt);
}

class AttemptsCompanion extends UpdateCompanion<AttemptRow> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> questionId;
  final Value<int?> selectedIndex;
  final Value<String> reasoning;
  final Value<bool> distracted;
  final Value<bool> isCorrect;
  final Value<DateTime> answeredAt;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.questionId = const Value.absent(),
    this.selectedIndex = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.distracted = const Value.absent(),
    this.isCorrect = const Value.absent(),
    this.answeredAt = const Value.absent(),
  });
  AttemptsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int questionId,
    this.selectedIndex = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.distracted = const Value.absent(),
    required bool isCorrect,
    required DateTime answeredAt,
  }) : sessionId = Value(sessionId),
       questionId = Value(questionId),
       isCorrect = Value(isCorrect),
       answeredAt = Value(answeredAt);
  static Insertable<AttemptRow> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? questionId,
    Expression<int>? selectedIndex,
    Expression<String>? reasoning,
    Expression<bool>? distracted,
    Expression<bool>? isCorrect,
    Expression<DateTime>? answeredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (questionId != null) 'question_id': questionId,
      if (selectedIndex != null) 'selected_index': selectedIndex,
      if (reasoning != null) 'reasoning': reasoning,
      if (distracted != null) 'distracted': distracted,
      if (isCorrect != null) 'is_correct': isCorrect,
      if (answeredAt != null) 'answered_at': answeredAt,
    });
  }

  AttemptsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? questionId,
    Value<int?>? selectedIndex,
    Value<String>? reasoning,
    Value<bool>? distracted,
    Value<bool>? isCorrect,
    Value<DateTime>? answeredAt,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      questionId: questionId ?? this.questionId,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      reasoning: reasoning ?? this.reasoning,
      distracted: distracted ?? this.distracted,
      isCorrect: isCorrect ?? this.isCorrect,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<int>(questionId.value);
    }
    if (selectedIndex.present) {
      map['selected_index'] = Variable<int>(selectedIndex.value);
    }
    if (reasoning.present) {
      map['reasoning'] = Variable<String>(reasoning.value);
    }
    if (distracted.present) {
      map['distracted'] = Variable<bool>(distracted.value);
    }
    if (isCorrect.present) {
      map['is_correct'] = Variable<bool>(isCorrect.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<DateTime>(answeredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('selectedIndex: $selectedIndex, ')
          ..write('reasoning: $reasoning, ')
          ..write('distracted: $distracted, ')
          ..write('isCorrect: $isCorrect, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }
}

class $ConceptsTable extends Concepts
    with TableInfo<$ConceptsTable, ConceptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConceptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<int> questionId = GeneratedColumn<int>(
    'question_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES questions (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _termMeta = const VerificationMeta('term');
  @override
  late final GeneratedColumn<String> term = GeneratedColumn<String>(
    'term',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionMeta = const VerificationMeta(
    'definition',
  );
  @override
  late final GeneratedColumn<String> definition = GeneratedColumn<String>(
    'definition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _topicNameMeta = const VerificationMeta(
    'topicName',
  );
  @override
  late final GeneratedColumn<String> topicName = GeneratedColumn<String>(
    'topic_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exportedAtMeta = const VerificationMeta(
    'exportedAt',
  );
  @override
  late final GeneratedColumn<DateTime> exportedAt = GeneratedColumn<DateTime>(
    'exported_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    questionId,
    term,
    definition,
    context,
    topicName,
    source,
    createdAt,
    exportedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'concepts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConceptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    }
    if (data.containsKey('term')) {
      context.handle(
        _termMeta,
        term.isAcceptableOrUnknown(data['term']!, _termMeta),
      );
    } else if (isInserting) {
      context.missing(_termMeta);
    }
    if (data.containsKey('definition')) {
      context.handle(
        _definitionMeta,
        definition.isAcceptableOrUnknown(data['definition']!, _definitionMeta),
      );
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    if (data.containsKey('topic_name')) {
      context.handle(
        _topicNameMeta,
        topicName.isAcceptableOrUnknown(data['topic_name']!, _topicNameMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('exported_at')) {
      context.handle(
        _exportedAtMeta,
        exportedAt.isAcceptableOrUnknown(data['exported_at']!, _exportedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConceptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConceptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}question_id'],
      ),
      term: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}term'],
      )!,
      definition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      )!,
      topicName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_name'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      exportedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}exported_at'],
      ),
    );
  }

  @override
  $ConceptsTable createAlias(String alias) {
    return $ConceptsTable(attachedDatabase, alias);
  }
}

class ConceptRow extends DataClass implements Insertable<ConceptRow> {
  final int id;
  final int? sessionId;
  final int? questionId;
  final String term;
  final String definition;
  final String context;
  final String topicName;
  final String source;
  final DateTime createdAt;
  final DateTime? exportedAt;
  const ConceptRow({
    required this.id,
    this.sessionId,
    this.questionId,
    required this.term,
    required this.definition,
    required this.context,
    required this.topicName,
    required this.source,
    required this.createdAt,
    this.exportedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    if (!nullToAbsent || questionId != null) {
      map['question_id'] = Variable<int>(questionId);
    }
    map['term'] = Variable<String>(term);
    map['definition'] = Variable<String>(definition);
    map['context'] = Variable<String>(context);
    map['topic_name'] = Variable<String>(topicName);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || exportedAt != null) {
      map['exported_at'] = Variable<DateTime>(exportedAt);
    }
    return map;
  }

  ConceptsCompanion toCompanion(bool nullToAbsent) {
    return ConceptsCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      questionId: questionId == null && nullToAbsent
          ? const Value.absent()
          : Value(questionId),
      term: Value(term),
      definition: Value(definition),
      context: Value(context),
      topicName: Value(topicName),
      source: Value(source),
      createdAt: Value(createdAt),
      exportedAt: exportedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(exportedAt),
    );
  }

  factory ConceptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConceptRow(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      questionId: serializer.fromJson<int?>(json['questionId']),
      term: serializer.fromJson<String>(json['term']),
      definition: serializer.fromJson<String>(json['definition']),
      context: serializer.fromJson<String>(json['context']),
      topicName: serializer.fromJson<String>(json['topicName']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      exportedAt: serializer.fromJson<DateTime?>(json['exportedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int?>(sessionId),
      'questionId': serializer.toJson<int?>(questionId),
      'term': serializer.toJson<String>(term),
      'definition': serializer.toJson<String>(definition),
      'context': serializer.toJson<String>(context),
      'topicName': serializer.toJson<String>(topicName),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'exportedAt': serializer.toJson<DateTime?>(exportedAt),
    };
  }

  ConceptRow copyWith({
    int? id,
    Value<int?> sessionId = const Value.absent(),
    Value<int?> questionId = const Value.absent(),
    String? term,
    String? definition,
    String? context,
    String? topicName,
    String? source,
    DateTime? createdAt,
    Value<DateTime?> exportedAt = const Value.absent(),
  }) => ConceptRow(
    id: id ?? this.id,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    questionId: questionId.present ? questionId.value : this.questionId,
    term: term ?? this.term,
    definition: definition ?? this.definition,
    context: context ?? this.context,
    topicName: topicName ?? this.topicName,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    exportedAt: exportedAt.present ? exportedAt.value : this.exportedAt,
  );
  ConceptRow copyWithCompanion(ConceptsCompanion data) {
    return ConceptRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      term: data.term.present ? data.term.value : this.term,
      definition: data.definition.present
          ? data.definition.value
          : this.definition,
      context: data.context.present ? data.context.value : this.context,
      topicName: data.topicName.present ? data.topicName.value : this.topicName,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      exportedAt: data.exportedAt.present
          ? data.exportedAt.value
          : this.exportedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConceptRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('term: $term, ')
          ..write('definition: $definition, ')
          ..write('context: $context, ')
          ..write('topicName: $topicName, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('exportedAt: $exportedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    questionId,
    term,
    definition,
    context,
    topicName,
    source,
    createdAt,
    exportedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConceptRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.questionId == this.questionId &&
          other.term == this.term &&
          other.definition == this.definition &&
          other.context == this.context &&
          other.topicName == this.topicName &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.exportedAt == this.exportedAt);
}

class ConceptsCompanion extends UpdateCompanion<ConceptRow> {
  final Value<int> id;
  final Value<int?> sessionId;
  final Value<int?> questionId;
  final Value<String> term;
  final Value<String> definition;
  final Value<String> context;
  final Value<String> topicName;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<DateTime?> exportedAt;
  const ConceptsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.questionId = const Value.absent(),
    this.term = const Value.absent(),
    this.definition = const Value.absent(),
    this.context = const Value.absent(),
    this.topicName = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.exportedAt = const Value.absent(),
  });
  ConceptsCompanion.insert({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.questionId = const Value.absent(),
    required String term,
    this.definition = const Value.absent(),
    this.context = const Value.absent(),
    this.topicName = const Value.absent(),
    required String source,
    required DateTime createdAt,
    this.exportedAt = const Value.absent(),
  }) : term = Value(term),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<ConceptRow> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? questionId,
    Expression<String>? term,
    Expression<String>? definition,
    Expression<String>? context,
    Expression<String>? topicName,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? exportedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (questionId != null) 'question_id': questionId,
      if (term != null) 'term': term,
      if (definition != null) 'definition': definition,
      if (context != null) 'context': context,
      if (topicName != null) 'topic_name': topicName,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (exportedAt != null) 'exported_at': exportedAt,
    });
  }

  ConceptsCompanion copyWith({
    Value<int>? id,
    Value<int?>? sessionId,
    Value<int?>? questionId,
    Value<String>? term,
    Value<String>? definition,
    Value<String>? context,
    Value<String>? topicName,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<DateTime?>? exportedAt,
  }) {
    return ConceptsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      questionId: questionId ?? this.questionId,
      term: term ?? this.term,
      definition: definition ?? this.definition,
      context: context ?? this.context,
      topicName: topicName ?? this.topicName,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      exportedAt: exportedAt ?? this.exportedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<int>(questionId.value);
    }
    if (term.present) {
      map['term'] = Variable<String>(term.value);
    }
    if (definition.present) {
      map['definition'] = Variable<String>(definition.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (topicName.present) {
      map['topic_name'] = Variable<String>(topicName.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (exportedAt.present) {
      map['exported_at'] = Variable<DateTime>(exportedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConceptsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('questionId: $questionId, ')
          ..write('term: $term, ')
          ..write('definition: $definition, ')
          ..write('context: $context, ')
          ..write('topicName: $topicName, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('exportedAt: $exportedAt')
          ..write(')'))
        .toString();
  }
}

class $ErrorCardsTable extends ErrorCards
    with TableInfo<$ErrorCardsTable, ErrorCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ErrorCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<int> questionId = GeneratedColumn<int>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alternativesJsonMeta = const VerificationMeta(
    'alternativesJson',
  );
  @override
  late final GeneratedColumn<String> alternativesJson = GeneratedColumn<String>(
    'alternatives_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctIndexMeta = const VerificationMeta(
    'correctIndex',
  );
  @override
  late final GeneratedColumn<int> correctIndex = GeneratedColumn<int>(
    'correct_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrongIndexMeta = const VerificationMeta(
    'wrongIndex',
  );
  @override
  late final GeneratedColumn<int> wrongIndex = GeneratedColumn<int>(
    'wrong_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasoningMeta = const VerificationMeta(
    'reasoning',
  );
  @override
  late final GeneratedColumn<String> reasoning = GeneratedColumn<String>(
    'reasoning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _biasMeta = const VerificationMeta('bias');
  @override
  late final GeneratedColumn<String> bias = GeneratedColumn<String>(
    'bias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _vaccineMeta = const VerificationMeta(
    'vaccine',
  );
  @override
  late final GeneratedColumn<String> vaccine = GeneratedColumn<String>(
    'vaccine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _topicNameMeta = const VerificationMeta(
    'topicName',
  );
  @override
  late final GeneratedColumn<String> topicName = GeneratedColumn<String>(
    'topic_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _practiceNameMeta = const VerificationMeta(
    'practiceName',
  );
  @override
  late final GeneratedColumn<String> practiceName = GeneratedColumn<String>(
    'practice_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastWrongAtMeta = const VerificationMeta(
    'lastWrongAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastWrongAt = GeneratedColumn<DateTime>(
    'last_wrong_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsCompletedAtMeta =
      const VerificationMeta('detailsCompletedAt');
  @override
  late final GeneratedColumn<DateTime> detailsCompletedAt =
      GeneratedColumn<DateTime>(
        'details_completed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exportedAtMeta = const VerificationMeta(
    'exportedAt',
  );
  @override
  late final GeneratedColumn<DateTime> exportedAt = GeneratedColumn<DateTime>(
    'exported_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    questionId,
    sessionId,
    question,
    alternativesJson,
    correctIndex,
    wrongIndex,
    reasoning,
    bias,
    vaccine,
    topicName,
    practiceName,
    status,
    createdAt,
    lastWrongAt,
    dueAt,
    detailsCompletedAt,
    resolvedAt,
    exportedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'error_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<ErrorCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('alternatives_json')) {
      context.handle(
        _alternativesJsonMeta,
        alternativesJson.isAcceptableOrUnknown(
          data['alternatives_json']!,
          _alternativesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_alternativesJsonMeta);
    }
    if (data.containsKey('correct_index')) {
      context.handle(
        _correctIndexMeta,
        correctIndex.isAcceptableOrUnknown(
          data['correct_index']!,
          _correctIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctIndexMeta);
    }
    if (data.containsKey('wrong_index')) {
      context.handle(
        _wrongIndexMeta,
        wrongIndex.isAcceptableOrUnknown(data['wrong_index']!, _wrongIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_wrongIndexMeta);
    }
    if (data.containsKey('reasoning')) {
      context.handle(
        _reasoningMeta,
        reasoning.isAcceptableOrUnknown(data['reasoning']!, _reasoningMeta),
      );
    }
    if (data.containsKey('bias')) {
      context.handle(
        _biasMeta,
        bias.isAcceptableOrUnknown(data['bias']!, _biasMeta),
      );
    }
    if (data.containsKey('vaccine')) {
      context.handle(
        _vaccineMeta,
        vaccine.isAcceptableOrUnknown(data['vaccine']!, _vaccineMeta),
      );
    }
    if (data.containsKey('topic_name')) {
      context.handle(
        _topicNameMeta,
        topicName.isAcceptableOrUnknown(data['topic_name']!, _topicNameMeta),
      );
    }
    if (data.containsKey('practice_name')) {
      context.handle(
        _practiceNameMeta,
        practiceName.isAcceptableOrUnknown(
          data['practice_name']!,
          _practiceNameMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_wrong_at')) {
      context.handle(
        _lastWrongAtMeta,
        lastWrongAt.isAcceptableOrUnknown(
          data['last_wrong_at']!,
          _lastWrongAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWrongAtMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('details_completed_at')) {
      context.handle(
        _detailsCompletedAtMeta,
        detailsCompletedAt.isAcceptableOrUnknown(
          data['details_completed_at']!,
          _detailsCompletedAtMeta,
        ),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('exported_at')) {
      context.handle(
        _exportedAtMeta,
        exportedAt.isAcceptableOrUnknown(data['exported_at']!, _exportedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ErrorCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ErrorCardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}question_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      alternativesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternatives_json'],
      )!,
      correctIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_index'],
      )!,
      wrongIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong_index'],
      )!,
      reasoning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning'],
      )!,
      bias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bias'],
      )!,
      vaccine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vaccine'],
      )!,
      topicName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_name'],
      )!,
      practiceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}practice_name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastWrongAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_wrong_at'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      detailsCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}details_completed_at'],
      ),
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      exportedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}exported_at'],
      ),
    );
  }

  @override
  $ErrorCardsTable createAlias(String alias) {
    return $ErrorCardsTable(attachedDatabase, alias);
  }
}

class ErrorCardRow extends DataClass implements Insertable<ErrorCardRow> {
  final int id;
  final int questionId;
  final int? sessionId;
  final String question;
  final String alternativesJson;
  final int correctIndex;
  final int wrongIndex;
  final String reasoning;
  final String bias;
  final String vaccine;
  final String topicName;
  final String practiceName;
  final String status;
  final DateTime createdAt;
  final DateTime lastWrongAt;
  final DateTime dueAt;
  final DateTime? detailsCompletedAt;
  final DateTime? resolvedAt;
  final DateTime? exportedAt;
  const ErrorCardRow({
    required this.id,
    required this.questionId,
    this.sessionId,
    required this.question,
    required this.alternativesJson,
    required this.correctIndex,
    required this.wrongIndex,
    required this.reasoning,
    required this.bias,
    required this.vaccine,
    required this.topicName,
    required this.practiceName,
    required this.status,
    required this.createdAt,
    required this.lastWrongAt,
    required this.dueAt,
    this.detailsCompletedAt,
    this.resolvedAt,
    this.exportedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['question_id'] = Variable<int>(questionId);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    map['question'] = Variable<String>(question);
    map['alternatives_json'] = Variable<String>(alternativesJson);
    map['correct_index'] = Variable<int>(correctIndex);
    map['wrong_index'] = Variable<int>(wrongIndex);
    map['reasoning'] = Variable<String>(reasoning);
    map['bias'] = Variable<String>(bias);
    map['vaccine'] = Variable<String>(vaccine);
    map['topic_name'] = Variable<String>(topicName);
    map['practice_name'] = Variable<String>(practiceName);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_wrong_at'] = Variable<DateTime>(lastWrongAt);
    map['due_at'] = Variable<DateTime>(dueAt);
    if (!nullToAbsent || detailsCompletedAt != null) {
      map['details_completed_at'] = Variable<DateTime>(detailsCompletedAt);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    if (!nullToAbsent || exportedAt != null) {
      map['exported_at'] = Variable<DateTime>(exportedAt);
    }
    return map;
  }

  ErrorCardsCompanion toCompanion(bool nullToAbsent) {
    return ErrorCardsCompanion(
      id: Value(id),
      questionId: Value(questionId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      question: Value(question),
      alternativesJson: Value(alternativesJson),
      correctIndex: Value(correctIndex),
      wrongIndex: Value(wrongIndex),
      reasoning: Value(reasoning),
      bias: Value(bias),
      vaccine: Value(vaccine),
      topicName: Value(topicName),
      practiceName: Value(practiceName),
      status: Value(status),
      createdAt: Value(createdAt),
      lastWrongAt: Value(lastWrongAt),
      dueAt: Value(dueAt),
      detailsCompletedAt: detailsCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsCompletedAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      exportedAt: exportedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(exportedAt),
    );
  }

  factory ErrorCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ErrorCardRow(
      id: serializer.fromJson<int>(json['id']),
      questionId: serializer.fromJson<int>(json['questionId']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      question: serializer.fromJson<String>(json['question']),
      alternativesJson: serializer.fromJson<String>(json['alternativesJson']),
      correctIndex: serializer.fromJson<int>(json['correctIndex']),
      wrongIndex: serializer.fromJson<int>(json['wrongIndex']),
      reasoning: serializer.fromJson<String>(json['reasoning']),
      bias: serializer.fromJson<String>(json['bias']),
      vaccine: serializer.fromJson<String>(json['vaccine']),
      topicName: serializer.fromJson<String>(json['topicName']),
      practiceName: serializer.fromJson<String>(json['practiceName']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastWrongAt: serializer.fromJson<DateTime>(json['lastWrongAt']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      detailsCompletedAt: serializer.fromJson<DateTime?>(
        json['detailsCompletedAt'],
      ),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      exportedAt: serializer.fromJson<DateTime?>(json['exportedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'questionId': serializer.toJson<int>(questionId),
      'sessionId': serializer.toJson<int?>(sessionId),
      'question': serializer.toJson<String>(question),
      'alternativesJson': serializer.toJson<String>(alternativesJson),
      'correctIndex': serializer.toJson<int>(correctIndex),
      'wrongIndex': serializer.toJson<int>(wrongIndex),
      'reasoning': serializer.toJson<String>(reasoning),
      'bias': serializer.toJson<String>(bias),
      'vaccine': serializer.toJson<String>(vaccine),
      'topicName': serializer.toJson<String>(topicName),
      'practiceName': serializer.toJson<String>(practiceName),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastWrongAt': serializer.toJson<DateTime>(lastWrongAt),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'detailsCompletedAt': serializer.toJson<DateTime?>(detailsCompletedAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'exportedAt': serializer.toJson<DateTime?>(exportedAt),
    };
  }

  ErrorCardRow copyWith({
    int? id,
    int? questionId,
    Value<int?> sessionId = const Value.absent(),
    String? question,
    String? alternativesJson,
    int? correctIndex,
    int? wrongIndex,
    String? reasoning,
    String? bias,
    String? vaccine,
    String? topicName,
    String? practiceName,
    String? status,
    DateTime? createdAt,
    DateTime? lastWrongAt,
    DateTime? dueAt,
    Value<DateTime?> detailsCompletedAt = const Value.absent(),
    Value<DateTime?> resolvedAt = const Value.absent(),
    Value<DateTime?> exportedAt = const Value.absent(),
  }) => ErrorCardRow(
    id: id ?? this.id,
    questionId: questionId ?? this.questionId,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    question: question ?? this.question,
    alternativesJson: alternativesJson ?? this.alternativesJson,
    correctIndex: correctIndex ?? this.correctIndex,
    wrongIndex: wrongIndex ?? this.wrongIndex,
    reasoning: reasoning ?? this.reasoning,
    bias: bias ?? this.bias,
    vaccine: vaccine ?? this.vaccine,
    topicName: topicName ?? this.topicName,
    practiceName: practiceName ?? this.practiceName,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    lastWrongAt: lastWrongAt ?? this.lastWrongAt,
    dueAt: dueAt ?? this.dueAt,
    detailsCompletedAt: detailsCompletedAt.present
        ? detailsCompletedAt.value
        : this.detailsCompletedAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    exportedAt: exportedAt.present ? exportedAt.value : this.exportedAt,
  );
  ErrorCardRow copyWithCompanion(ErrorCardsCompanion data) {
    return ErrorCardRow(
      id: data.id.present ? data.id.value : this.id,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      question: data.question.present ? data.question.value : this.question,
      alternativesJson: data.alternativesJson.present
          ? data.alternativesJson.value
          : this.alternativesJson,
      correctIndex: data.correctIndex.present
          ? data.correctIndex.value
          : this.correctIndex,
      wrongIndex: data.wrongIndex.present
          ? data.wrongIndex.value
          : this.wrongIndex,
      reasoning: data.reasoning.present ? data.reasoning.value : this.reasoning,
      bias: data.bias.present ? data.bias.value : this.bias,
      vaccine: data.vaccine.present ? data.vaccine.value : this.vaccine,
      topicName: data.topicName.present ? data.topicName.value : this.topicName,
      practiceName: data.practiceName.present
          ? data.practiceName.value
          : this.practiceName,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastWrongAt: data.lastWrongAt.present
          ? data.lastWrongAt.value
          : this.lastWrongAt,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      detailsCompletedAt: data.detailsCompletedAt.present
          ? data.detailsCompletedAt.value
          : this.detailsCompletedAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      exportedAt: data.exportedAt.present
          ? data.exportedAt.value
          : this.exportedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ErrorCardRow(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('sessionId: $sessionId, ')
          ..write('question: $question, ')
          ..write('alternativesJson: $alternativesJson, ')
          ..write('correctIndex: $correctIndex, ')
          ..write('wrongIndex: $wrongIndex, ')
          ..write('reasoning: $reasoning, ')
          ..write('bias: $bias, ')
          ..write('vaccine: $vaccine, ')
          ..write('topicName: $topicName, ')
          ..write('practiceName: $practiceName, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastWrongAt: $lastWrongAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('detailsCompletedAt: $detailsCompletedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('exportedAt: $exportedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    questionId,
    sessionId,
    question,
    alternativesJson,
    correctIndex,
    wrongIndex,
    reasoning,
    bias,
    vaccine,
    topicName,
    practiceName,
    status,
    createdAt,
    lastWrongAt,
    dueAt,
    detailsCompletedAt,
    resolvedAt,
    exportedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ErrorCardRow &&
          other.id == this.id &&
          other.questionId == this.questionId &&
          other.sessionId == this.sessionId &&
          other.question == this.question &&
          other.alternativesJson == this.alternativesJson &&
          other.correctIndex == this.correctIndex &&
          other.wrongIndex == this.wrongIndex &&
          other.reasoning == this.reasoning &&
          other.bias == this.bias &&
          other.vaccine == this.vaccine &&
          other.topicName == this.topicName &&
          other.practiceName == this.practiceName &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.lastWrongAt == this.lastWrongAt &&
          other.dueAt == this.dueAt &&
          other.detailsCompletedAt == this.detailsCompletedAt &&
          other.resolvedAt == this.resolvedAt &&
          other.exportedAt == this.exportedAt);
}

class ErrorCardsCompanion extends UpdateCompanion<ErrorCardRow> {
  final Value<int> id;
  final Value<int> questionId;
  final Value<int?> sessionId;
  final Value<String> question;
  final Value<String> alternativesJson;
  final Value<int> correctIndex;
  final Value<int> wrongIndex;
  final Value<String> reasoning;
  final Value<String> bias;
  final Value<String> vaccine;
  final Value<String> topicName;
  final Value<String> practiceName;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastWrongAt;
  final Value<DateTime> dueAt;
  final Value<DateTime?> detailsCompletedAt;
  final Value<DateTime?> resolvedAt;
  final Value<DateTime?> exportedAt;
  const ErrorCardsCompanion({
    this.id = const Value.absent(),
    this.questionId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.question = const Value.absent(),
    this.alternativesJson = const Value.absent(),
    this.correctIndex = const Value.absent(),
    this.wrongIndex = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.bias = const Value.absent(),
    this.vaccine = const Value.absent(),
    this.topicName = const Value.absent(),
    this.practiceName = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastWrongAt = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.detailsCompletedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.exportedAt = const Value.absent(),
  });
  ErrorCardsCompanion.insert({
    this.id = const Value.absent(),
    required int questionId,
    this.sessionId = const Value.absent(),
    required String question,
    required String alternativesJson,
    required int correctIndex,
    required int wrongIndex,
    this.reasoning = const Value.absent(),
    this.bias = const Value.absent(),
    this.vaccine = const Value.absent(),
    this.topicName = const Value.absent(),
    this.practiceName = const Value.absent(),
    required String status,
    required DateTime createdAt,
    required DateTime lastWrongAt,
    required DateTime dueAt,
    this.detailsCompletedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.exportedAt = const Value.absent(),
  }) : questionId = Value(questionId),
       question = Value(question),
       alternativesJson = Value(alternativesJson),
       correctIndex = Value(correctIndex),
       wrongIndex = Value(wrongIndex),
       status = Value(status),
       createdAt = Value(createdAt),
       lastWrongAt = Value(lastWrongAt),
       dueAt = Value(dueAt);
  static Insertable<ErrorCardRow> custom({
    Expression<int>? id,
    Expression<int>? questionId,
    Expression<int>? sessionId,
    Expression<String>? question,
    Expression<String>? alternativesJson,
    Expression<int>? correctIndex,
    Expression<int>? wrongIndex,
    Expression<String>? reasoning,
    Expression<String>? bias,
    Expression<String>? vaccine,
    Expression<String>? topicName,
    Expression<String>? practiceName,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastWrongAt,
    Expression<DateTime>? dueAt,
    Expression<DateTime>? detailsCompletedAt,
    Expression<DateTime>? resolvedAt,
    Expression<DateTime>? exportedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      if (sessionId != null) 'session_id': sessionId,
      if (question != null) 'question': question,
      if (alternativesJson != null) 'alternatives_json': alternativesJson,
      if (correctIndex != null) 'correct_index': correctIndex,
      if (wrongIndex != null) 'wrong_index': wrongIndex,
      if (reasoning != null) 'reasoning': reasoning,
      if (bias != null) 'bias': bias,
      if (vaccine != null) 'vaccine': vaccine,
      if (topicName != null) 'topic_name': topicName,
      if (practiceName != null) 'practice_name': practiceName,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (lastWrongAt != null) 'last_wrong_at': lastWrongAt,
      if (dueAt != null) 'due_at': dueAt,
      if (detailsCompletedAt != null)
        'details_completed_at': detailsCompletedAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (exportedAt != null) 'exported_at': exportedAt,
    });
  }

  ErrorCardsCompanion copyWith({
    Value<int>? id,
    Value<int>? questionId,
    Value<int?>? sessionId,
    Value<String>? question,
    Value<String>? alternativesJson,
    Value<int>? correctIndex,
    Value<int>? wrongIndex,
    Value<String>? reasoning,
    Value<String>? bias,
    Value<String>? vaccine,
    Value<String>? topicName,
    Value<String>? practiceName,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastWrongAt,
    Value<DateTime>? dueAt,
    Value<DateTime?>? detailsCompletedAt,
    Value<DateTime?>? resolvedAt,
    Value<DateTime?>? exportedAt,
  }) {
    return ErrorCardsCompanion(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      sessionId: sessionId ?? this.sessionId,
      question: question ?? this.question,
      alternativesJson: alternativesJson ?? this.alternativesJson,
      correctIndex: correctIndex ?? this.correctIndex,
      wrongIndex: wrongIndex ?? this.wrongIndex,
      reasoning: reasoning ?? this.reasoning,
      bias: bias ?? this.bias,
      vaccine: vaccine ?? this.vaccine,
      topicName: topicName ?? this.topicName,
      practiceName: practiceName ?? this.practiceName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastWrongAt: lastWrongAt ?? this.lastWrongAt,
      dueAt: dueAt ?? this.dueAt,
      detailsCompletedAt: detailsCompletedAt ?? this.detailsCompletedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      exportedAt: exportedAt ?? this.exportedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<int>(questionId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (alternativesJson.present) {
      map['alternatives_json'] = Variable<String>(alternativesJson.value);
    }
    if (correctIndex.present) {
      map['correct_index'] = Variable<int>(correctIndex.value);
    }
    if (wrongIndex.present) {
      map['wrong_index'] = Variable<int>(wrongIndex.value);
    }
    if (reasoning.present) {
      map['reasoning'] = Variable<String>(reasoning.value);
    }
    if (bias.present) {
      map['bias'] = Variable<String>(bias.value);
    }
    if (vaccine.present) {
      map['vaccine'] = Variable<String>(vaccine.value);
    }
    if (topicName.present) {
      map['topic_name'] = Variable<String>(topicName.value);
    }
    if (practiceName.present) {
      map['practice_name'] = Variable<String>(practiceName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastWrongAt.present) {
      map['last_wrong_at'] = Variable<DateTime>(lastWrongAt.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (detailsCompletedAt.present) {
      map['details_completed_at'] = Variable<DateTime>(
        detailsCompletedAt.value,
      );
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (exportedAt.present) {
      map['exported_at'] = Variable<DateTime>(exportedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ErrorCardsCompanion(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('sessionId: $sessionId, ')
          ..write('question: $question, ')
          ..write('alternativesJson: $alternativesJson, ')
          ..write('correctIndex: $correctIndex, ')
          ..write('wrongIndex: $wrongIndex, ')
          ..write('reasoning: $reasoning, ')
          ..write('bias: $bias, ')
          ..write('vaccine: $vaccine, ')
          ..write('topicName: $topicName, ')
          ..write('practiceName: $practiceName, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastWrongAt: $lastWrongAt, ')
          ..write('dueAt: $dueAt, ')
          ..write('detailsCompletedAt: $detailsCompletedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('exportedAt: $exportedAt')
          ..write(')'))
        .toString();
  }
}

class $ManualCardsTable extends ManualCards
    with TableInfo<$ManualCardsTable, ManualCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ManualCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicNameMeta = const VerificationMeta(
    'topicName',
  );
  @override
  late final GeneratedColumn<String> topicName = GeneratedColumn<String>(
    'topic_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exportedAtMeta = const VerificationMeta(
    'exportedAt',
  );
  @override
  late final GeneratedColumn<DateTime> exportedAt = GeneratedColumn<DateTime>(
    'exported_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    question,
    answer,
    topicName,
    createdAt,
    exportedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manual_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<ManualCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('topic_name')) {
      context.handle(
        _topicNameMeta,
        topicName.isAcceptableOrUnknown(data['topic_name']!, _topicNameMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('exported_at')) {
      context.handle(
        _exportedAtMeta,
        exportedAt.isAcceptableOrUnknown(data['exported_at']!, _exportedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ManualCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ManualCardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      topicName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      exportedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}exported_at'],
      ),
    );
  }

  @override
  $ManualCardsTable createAlias(String alias) {
    return $ManualCardsTable(attachedDatabase, alias);
  }
}

class ManualCardRow extends DataClass implements Insertable<ManualCardRow> {
  final int id;
  final int? sessionId;
  final String question;
  final String answer;
  final String topicName;
  final DateTime createdAt;
  final DateTime? exportedAt;
  const ManualCardRow({
    required this.id,
    this.sessionId,
    required this.question,
    required this.answer,
    required this.topicName,
    required this.createdAt,
    this.exportedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    map['question'] = Variable<String>(question);
    map['answer'] = Variable<String>(answer);
    map['topic_name'] = Variable<String>(topicName);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || exportedAt != null) {
      map['exported_at'] = Variable<DateTime>(exportedAt);
    }
    return map;
  }

  ManualCardsCompanion toCompanion(bool nullToAbsent) {
    return ManualCardsCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      question: Value(question),
      answer: Value(answer),
      topicName: Value(topicName),
      createdAt: Value(createdAt),
      exportedAt: exportedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(exportedAt),
    );
  }

  factory ManualCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ManualCardRow(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      question: serializer.fromJson<String>(json['question']),
      answer: serializer.fromJson<String>(json['answer']),
      topicName: serializer.fromJson<String>(json['topicName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      exportedAt: serializer.fromJson<DateTime?>(json['exportedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int?>(sessionId),
      'question': serializer.toJson<String>(question),
      'answer': serializer.toJson<String>(answer),
      'topicName': serializer.toJson<String>(topicName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'exportedAt': serializer.toJson<DateTime?>(exportedAt),
    };
  }

  ManualCardRow copyWith({
    int? id,
    Value<int?> sessionId = const Value.absent(),
    String? question,
    String? answer,
    String? topicName,
    DateTime? createdAt,
    Value<DateTime?> exportedAt = const Value.absent(),
  }) => ManualCardRow(
    id: id ?? this.id,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    question: question ?? this.question,
    answer: answer ?? this.answer,
    topicName: topicName ?? this.topicName,
    createdAt: createdAt ?? this.createdAt,
    exportedAt: exportedAt.present ? exportedAt.value : this.exportedAt,
  );
  ManualCardRow copyWithCompanion(ManualCardsCompanion data) {
    return ManualCardRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      question: data.question.present ? data.question.value : this.question,
      answer: data.answer.present ? data.answer.value : this.answer,
      topicName: data.topicName.present ? data.topicName.value : this.topicName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      exportedAt: data.exportedAt.present
          ? data.exportedAt.value
          : this.exportedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ManualCardRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('topicName: $topicName, ')
          ..write('createdAt: $createdAt, ')
          ..write('exportedAt: $exportedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    question,
    answer,
    topicName,
    createdAt,
    exportedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ManualCardRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.question == this.question &&
          other.answer == this.answer &&
          other.topicName == this.topicName &&
          other.createdAt == this.createdAt &&
          other.exportedAt == this.exportedAt);
}

class ManualCardsCompanion extends UpdateCompanion<ManualCardRow> {
  final Value<int> id;
  final Value<int?> sessionId;
  final Value<String> question;
  final Value<String> answer;
  final Value<String> topicName;
  final Value<DateTime> createdAt;
  final Value<DateTime?> exportedAt;
  const ManualCardsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.topicName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.exportedAt = const Value.absent(),
  });
  ManualCardsCompanion.insert({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    required String question,
    required String answer,
    this.topicName = const Value.absent(),
    required DateTime createdAt,
    this.exportedAt = const Value.absent(),
  }) : question = Value(question),
       answer = Value(answer),
       createdAt = Value(createdAt);
  static Insertable<ManualCardRow> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? question,
    Expression<String>? answer,
    Expression<String>? topicName,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? exportedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (question != null) 'question': question,
      if (answer != null) 'answer': answer,
      if (topicName != null) 'topic_name': topicName,
      if (createdAt != null) 'created_at': createdAt,
      if (exportedAt != null) 'exported_at': exportedAt,
    });
  }

  ManualCardsCompanion copyWith({
    Value<int>? id,
    Value<int?>? sessionId,
    Value<String>? question,
    Value<String>? answer,
    Value<String>? topicName,
    Value<DateTime>? createdAt,
    Value<DateTime?>? exportedAt,
  }) {
    return ManualCardsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      topicName: topicName ?? this.topicName,
      createdAt: createdAt ?? this.createdAt,
      exportedAt: exportedAt ?? this.exportedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (topicName.present) {
      map['topic_name'] = Variable<String>(topicName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (exportedAt.present) {
      map['exported_at'] = Variable<DateTime>(exportedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ManualCardsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('topicName: $topicName, ')
          ..write('createdAt: $createdAt, ')
          ..write('exportedAt: $exportedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TopicsTable topics = $TopicsTable(this);
  late final $PracticesTable practices = $PracticesTable(this);
  late final $QuestionsTable questions = $QuestionsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionQuestionsTable sessionQuestions = $SessionQuestionsTable(
    this,
  );
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $ConceptsTable concepts = $ConceptsTable(this);
  late final $ErrorCardsTable errorCards = $ErrorCardsTable(this);
  late final $ManualCardsTable manualCards = $ManualCardsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index practicesTopic = Index(
    'practices_topic',
    'CREATE INDEX practices_topic ON practices (topic_id)',
  );
  late final Index questionsPractice = Index(
    'questions_practice',
    'CREATE INDEX questions_practice ON questions (practice_id)',
  );
  late final Index sessionsStatus = Index(
    'sessions_status',
    'CREATE INDEX sessions_status ON sessions (status)',
  );
  late final Index sessionQuestionsQuestion = Index(
    'session_questions_question',
    'CREATE INDEX session_questions_question ON session_questions (question_id)',
  );
  late final Index attemptsSession = Index(
    'attempts_session',
    'CREATE INDEX attempts_session ON attempts (session_id)',
  );
  late final Index attemptsQuestion = Index(
    'attempts_question',
    'CREATE INDEX attempts_question ON attempts (question_id)',
  );
  late final Index conceptsSession = Index(
    'concepts_session',
    'CREATE INDEX concepts_session ON concepts (session_id)',
  );
  late final Index conceptsExported = Index(
    'concepts_exported',
    'CREATE INDEX concepts_exported ON concepts (exported_at)',
  );
  late final Index errorCardsDue = Index(
    'error_cards_due',
    'CREATE INDEX error_cards_due ON error_cards (status, due_at)',
  );
  late final Index errorCardsQuestion = Index(
    'error_cards_question',
    'CREATE INDEX error_cards_question ON error_cards (question_id)',
  );
  late final Index errorCardsSession = Index(
    'error_cards_session',
    'CREATE INDEX error_cards_session ON error_cards (session_id)',
  );
  late final Index manualCardsExported = Index(
    'manual_cards_exported',
    'CREATE INDEX manual_cards_exported ON manual_cards (exported_at)',
  );
  late final TopicDao topicDao = TopicDao(this as AppDatabase);
  late final SessionDao sessionDao = SessionDao(this as AppDatabase);
  late final CardDao cardDao = CardDao(this as AppDatabase);
  late final StatsDao statsDao = StatsDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    topics,
    practices,
    questions,
    sessions,
    sessionQuestions,
    attempts,
    concepts,
    errorCards,
    manualCards,
    settings,
    practicesTopic,
    questionsPractice,
    sessionsStatus,
    sessionQuestionsQuestion,
    attemptsSession,
    attemptsQuestion,
    conceptsSession,
    conceptsExported,
    errorCardsDue,
    errorCardsQuestion,
    errorCardsSession,
    manualCardsExported,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'topics',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practices', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practices',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('questions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practices',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sessions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_questions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_questions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attempts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attempts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('concepts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('concepts', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('error_cards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('error_cards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('manual_cards', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TopicsTableCreateCompanionBuilder = TopicsCompanion Function({
  Value<int> id,
  required String name,
  Value<String> description,
  Value<int?> priority,
  Value<String?> ankiDeck,
  required DateTime createdAt,
});
typedef $$TopicsTableUpdateCompanionBuilder = TopicsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> description,
  Value<int?> priority,
  Value<String?> ankiDeck,
  Value<DateTime> createdAt,
});

final class $$TopicsTableReferences
    extends BaseReferences<_$AppDatabase, $TopicsTable, TopicRow> {
  $$TopicsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PracticesTable, List<PracticeRow>>
  _practicesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.practices,
    aliasName: 'topics__id__practices__topic_id',
  );

  $$PracticesTableProcessedTableManager get practicesRefs {
    final manager = $$PracticesTableTableManager(
      $_db,
      $_db.practices,
    ).filter((f) => f.topicId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_practicesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TopicsTableFilterComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ankiDeck => $composableBuilder(
    column: $table.ankiDeck,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> practicesRefs(
    Expression<bool> Function($$PracticesTableFilterComposer f) f,
  ) {
    final $$PracticesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practices,
      getReferencedColumn: (t) => t.topicId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticesTableFilterComposer(
            $db: $db,
            $table: $db.practices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TopicsTableOrderingComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ankiDeck => $composableBuilder(
    column: $table.ankiDeck,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TopicsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get ankiDeck =>
      $composableBuilder(column: $table.ankiDeck, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> practicesRefs<T extends Object>(
    Expression<T> Function($$PracticesTableAnnotationComposer a) f,
  ) {
    final $$PracticesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practices,
      getReferencedColumn: (t) => t.topicId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticesTableAnnotationComposer(
            $db: $db,
            $table: $db.practices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TopicsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TopicsTable,
          TopicRow,
          $$TopicsTableFilterComposer,
          $$TopicsTableOrderingComposer,
          $$TopicsTableAnnotationComposer,
          $$TopicsTableCreateCompanionBuilder,
          $$TopicsTableUpdateCompanionBuilder,
          (TopicRow, $$TopicsTableReferences),
          TopicRow,
          PrefetchHooks Function({bool practicesRefs})
        > {
  $$TopicsTableTableManager(_$AppDatabase db, $TopicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int?> priority = const Value.absent(),
                Value<String?> ankiDeck = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TopicsCompanion(
                id: id,
                name: name,
                description: description,
                priority: priority,
                ankiDeck: ankiDeck,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> description = const Value.absent(),
                Value<int?> priority = const Value.absent(),
                Value<String?> ankiDeck = const Value.absent(),
                required DateTime createdAt,
              }) => TopicsCompanion.insert(
                id: id,
                name: name,
                description: description,
                priority: priority,
                ankiDeck: ankiDeck,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TopicsTable, TopicRow>(table),
                  $$TopicsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({practicesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (practicesRefs) db.practices],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (practicesRefs)
                    await $_getPrefetchedDataByColumns<
                      TopicRow,
                      $TopicsTable,
                      PracticeRow,
                      $PracticesTable
                    >(
                      currentTable: table,
                      referencedTable: $$TopicsTableReferences
                          ._practicesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TopicsTableReferences(db, table, p0).practicesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'topic_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TopicsTable,
      TopicRow,
      $$TopicsTableFilterComposer,
      $$TopicsTableOrderingComposer,
      $$TopicsTableAnnotationComposer,
      $$TopicsTableCreateCompanionBuilder,
      $$TopicsTableUpdateCompanionBuilder,
      (TopicRow, $$TopicsTableReferences),
      TopicRow,
      PrefetchHooks Function({bool practicesRefs})
    >;
typedef $$PracticesTableCreateCompanionBuilder = PracticesCompanion Function({
  Value<int> id,
  required int topicId,
  required String name,
  Value<String> description,
  required String contentHash,
  required DateTime importedAt,
});
typedef $$PracticesTableUpdateCompanionBuilder = PracticesCompanion Function({
  Value<int> id,
  Value<int> topicId,
  Value<String> name,
  Value<String> description,
  Value<String> contentHash,
  Value<DateTime> importedAt,
});

final class $$PracticesTableReferences
    extends BaseReferences<_$AppDatabase, $PracticesTable, PracticeRow> {
  $$PracticesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TopicsTable _topicIdTable(_$AppDatabase db) =>
      db.topics.createAlias('practices__topic_id__topics__id');

  $$TopicsTableProcessedTableManager get topicId {
    final $_column = $_itemColumn<int>('topic_id')!;

    final manager = $$TopicsTableTableManager(
      $_db,
      $_db.topics,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_topicIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$QuestionsTable, List<QuestionRow>>
  _questionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.questions,
    aliasName: 'practices__id__questions__practice_id',
  );

  $$QuestionsTableProcessedTableManager get questionsRefs {
    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.practiceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_questionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SessionsTable, List<SessionRow>>
  _sessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessions,
    aliasName: 'practices__id__sessions__practice_id',
  );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.practiceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PracticesTableFilterComposer
    extends Composer<_$AppDatabase, $PracticesTable> {
  $$PracticesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TopicsTableFilterComposer get topicId {
    final $$TopicsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.topicId,
      referencedTable: $db.topics,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopicsTableFilterComposer(
            $db: $db,
            $table: $db.topics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> questionsRefs(
    Expression<bool> Function($$QuestionsTableFilterComposer f) f,
  ) {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.practiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sessionsRefs(
    Expression<bool> Function($$SessionsTableFilterComposer f) f,
  ) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.practiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticesTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticesTable> {
  $$PracticesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TopicsTableOrderingComposer get topicId {
    final $$TopicsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.topicId,
      referencedTable: $db.topics,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopicsTableOrderingComposer(
            $db: $db,
            $table: $db.topics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PracticesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticesTable> {
  $$PracticesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  $$TopicsTableAnnotationComposer get topicId {
    final $$TopicsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.topicId,
      referencedTable: $db.topics,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopicsTableAnnotationComposer(
            $db: $db,
            $table: $db.topics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> questionsRefs<T extends Object>(
    Expression<T> Function($$QuestionsTableAnnotationComposer a) f,
  ) {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.practiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.practiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticesTable,
          PracticeRow,
          $$PracticesTableFilterComposer,
          $$PracticesTableOrderingComposer,
          $$PracticesTableAnnotationComposer,
          $$PracticesTableCreateCompanionBuilder,
          $$PracticesTableUpdateCompanionBuilder,
          (PracticeRow, $$PracticesTableReferences),
          PracticeRow,
          PrefetchHooks Function({
            bool topicId,
            bool questionsRefs,
            bool sessionsRefs,
          })
        > {
  $$PracticesTableTableManager(_$AppDatabase db, $PracticesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> topicId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
              }) => PracticesCompanion(
                id: id,
                topicId: topicId,
                name: name,
                description: description,
                contentHash: contentHash,
                importedAt: importedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int topicId,
                required String name,
                Value<String> description = const Value.absent(),
                required String contentHash,
                required DateTime importedAt,
              }) => PracticesCompanion.insert(
                id: id,
                topicId: topicId,
                name: name,
                description: description,
                contentHash: contentHash,
                importedAt: importedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PracticesTable, PracticeRow>(table),
                  $$PracticesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({topicId = false, questionsRefs = false, sessionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (questionsRefs) db.questions,
                    if (sessionsRefs) db.sessions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (topicId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.topicId,
                            referencedTable: $$PracticesTableReferences
                                ._topicIdTable(db),
                            referencedColumn: $$PracticesTableReferences
                                ._topicIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (questionsRefs)
                        await $_getPrefetchedDataByColumns<
                          PracticeRow,
                          $PracticesTable,
                          QuestionRow,
                          $QuestionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PracticesTableReferences
                              ._questionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PracticesTableReferences(
                                db,
                                table,
                                p0,
                              ).questionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'practice_id',
                          typedResults: items,
                        ),
                      if (sessionsRefs)
                        await $_getPrefetchedDataByColumns<
                          PracticeRow,
                          $PracticesTable,
                          SessionRow,
                          $SessionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PracticesTableReferences
                              ._sessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PracticesTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'practice_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PracticesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticesTable,
      PracticeRow,
      $$PracticesTableFilterComposer,
      $$PracticesTableOrderingComposer,
      $$PracticesTableAnnotationComposer,
      $$PracticesTableCreateCompanionBuilder,
      $$PracticesTableUpdateCompanionBuilder,
      (PracticeRow, $$PracticesTableReferences),
      PracticeRow,
      PrefetchHooks Function({
        bool topicId,
        bool questionsRefs,
        bool sessionsRefs,
      })
    >;
typedef $$QuestionsTableCreateCompanionBuilder = QuestionsCompanion Function({
  Value<int> id,
  required int practiceId,
  required String prompt,
  required String alternativesJson,
  required int correctIndex,
  required String explanation,
  required String alternativeExplanationsJson,
  required int position,
});
typedef $$QuestionsTableUpdateCompanionBuilder = QuestionsCompanion Function({
  Value<int> id,
  Value<int> practiceId,
  Value<String> prompt,
  Value<String> alternativesJson,
  Value<int> correctIndex,
  Value<String> explanation,
  Value<String> alternativeExplanationsJson,
  Value<int> position,
});

final class $$QuestionsTableReferences
    extends BaseReferences<_$AppDatabase, $QuestionsTable, QuestionRow> {
  $$QuestionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PracticesTable _practiceIdTable(_$AppDatabase db) =>
      db.practices.createAlias('questions__practice_id__practices__id');

  $$PracticesTableProcessedTableManager get practiceId {
    final $_column = $_itemColumn<int>('practice_id')!;

    final manager = $$PracticesTableTableManager(
      $_db,
      $_db.practices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_practiceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SessionQuestionsTable, List<SessionQuestionRow>>
  _sessionQuestionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionQuestions,
    aliasName: 'questions__id__session_questions__question_id',
  );

  $$SessionQuestionsTableProcessedTableManager get sessionQuestionsRefs {
    final manager = $$SessionQuestionsTableTableManager(
      $_db,
      $_db.sessionQuestions,
    ).filter((f) => f.questionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _sessionQuestionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttemptsTable, List<AttemptRow>>
  _attemptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attempts,
    aliasName: 'questions__id__attempts__question_id',
  );

  $$AttemptsTableProcessedTableManager get attemptsRefs {
    final manager = $$AttemptsTableTableManager(
      $_db,
      $_db.attempts,
    ).filter((f) => f.questionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ConceptsTable, List<ConceptRow>>
  _conceptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.concepts,
    aliasName: 'questions__id__concepts__question_id',
  );

  $$ConceptsTableProcessedTableManager get conceptsRefs {
    final manager = $$ConceptsTableTableManager(
      $_db,
      $_db.concepts,
    ).filter((f) => f.questionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_conceptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ErrorCardsTable, List<ErrorCardRow>>
  _errorCardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.errorCards,
    aliasName: 'questions__id__error_cards__question_id',
  );

  $$ErrorCardsTableProcessedTableManager get errorCardsRefs {
    final manager = $$ErrorCardsTableTableManager(
      $_db,
      $_db.errorCards,
    ).filter((f) => f.questionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_errorCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$QuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternativesJson => $composableBuilder(
    column: $table.alternativesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctIndex => $composableBuilder(
    column: $table.correctIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternativeExplanationsJson => $composableBuilder(
    column: $table.alternativeExplanationsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PracticesTableFilterComposer get practiceId {
    final $$PracticesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.practiceId,
      referencedTable: $db.practices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticesTableFilterComposer(
            $db: $db,
            $table: $db.practices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sessionQuestionsRefs(
    Expression<bool> Function($$SessionQuestionsTableFilterComposer f) f,
  ) {
    final $$SessionQuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionQuestions,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionQuestionsTableFilterComposer(
            $db: $db,
            $table: $db.sessionQuestions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attemptsRefs(
    Expression<bool> Function($$AttemptsTableFilterComposer f) f,
  ) {
    final $$AttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableFilterComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> conceptsRefs(
    Expression<bool> Function($$ConceptsTableFilterComposer f) f,
  ) {
    final $$ConceptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.concepts,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConceptsTableFilterComposer(
            $db: $db,
            $table: $db.concepts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> errorCardsRefs(
    Expression<bool> Function($$ErrorCardsTableFilterComposer f) f,
  ) {
    final $$ErrorCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.errorCards,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ErrorCardsTableFilterComposer(
            $db: $db,
            $table: $db.errorCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternativesJson => $composableBuilder(
    column: $table.alternativesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctIndex => $composableBuilder(
    column: $table.correctIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternativeExplanationsJson => $composableBuilder(
    column: $table.alternativeExplanationsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PracticesTableOrderingComposer get practiceId {
    final $$PracticesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.practiceId,
      referencedTable: $db.practices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticesTableOrderingComposer(
            $db: $db,
            $table: $db.practices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestionsTable> {
  $$QuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<String> get alternativesJson => $composableBuilder(
    column: $table.alternativesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctIndex => $composableBuilder(
    column: $table.correctIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alternativeExplanationsJson => $composableBuilder(
    column: $table.alternativeExplanationsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PracticesTableAnnotationComposer get practiceId {
    final $$PracticesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.practiceId,
      referencedTable: $db.practices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticesTableAnnotationComposer(
            $db: $db,
            $table: $db.practices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sessionQuestionsRefs<T extends Object>(
    Expression<T> Function($$SessionQuestionsTableAnnotationComposer a) f,
  ) {
    final $$SessionQuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionQuestions,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionQuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionQuestions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attemptsRefs<T extends Object>(
    Expression<T> Function($$AttemptsTableAnnotationComposer a) f,
  ) {
    final $$AttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> conceptsRefs<T extends Object>(
    Expression<T> Function($$ConceptsTableAnnotationComposer a) f,
  ) {
    final $$ConceptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.concepts,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConceptsTableAnnotationComposer(
            $db: $db,
            $table: $db.concepts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> errorCardsRefs<T extends Object>(
    Expression<T> Function($$ErrorCardsTableAnnotationComposer a) f,
  ) {
    final $$ErrorCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.errorCards,
      getReferencedColumn: (t) => t.questionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ErrorCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.errorCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$QuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestionsTable,
          QuestionRow,
          $$QuestionsTableFilterComposer,
          $$QuestionsTableOrderingComposer,
          $$QuestionsTableAnnotationComposer,
          $$QuestionsTableCreateCompanionBuilder,
          $$QuestionsTableUpdateCompanionBuilder,
          (QuestionRow, $$QuestionsTableReferences),
          QuestionRow,
          PrefetchHooks Function({
            bool practiceId,
            bool sessionQuestionsRefs,
            bool attemptsRefs,
            bool conceptsRefs,
            bool errorCardsRefs,
          })
        > {
  $$QuestionsTableTableManager(_$AppDatabase db, $QuestionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> practiceId = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<String> alternativesJson = const Value.absent(),
                Value<int> correctIndex = const Value.absent(),
                Value<String> explanation = const Value.absent(),
                Value<String> alternativeExplanationsJson =
                    const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => QuestionsCompanion(
                id: id,
                practiceId: practiceId,
                prompt: prompt,
                alternativesJson: alternativesJson,
                correctIndex: correctIndex,
                explanation: explanation,
                alternativeExplanationsJson: alternativeExplanationsJson,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int practiceId,
                required String prompt,
                required String alternativesJson,
                required int correctIndex,
                required String explanation,
                required String alternativeExplanationsJson,
                required int position,
              }) => QuestionsCompanion.insert(
                id: id,
                practiceId: practiceId,
                prompt: prompt,
                alternativesJson: alternativesJson,
                correctIndex: correctIndex,
                explanation: explanation,
                alternativeExplanationsJson: alternativeExplanationsJson,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuestionsTable, QuestionRow>(table),
                  $$QuestionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                practiceId = false,
                sessionQuestionsRefs = false,
                attemptsRefs = false,
                conceptsRefs = false,
                errorCardsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sessionQuestionsRefs) db.sessionQuestions,
                    if (attemptsRefs) db.attempts,
                    if (conceptsRefs) db.concepts,
                    if (errorCardsRefs) db.errorCards,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (practiceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.practiceId,
                            referencedTable: $$QuestionsTableReferences
                                ._practiceIdTable(db),
                            referencedColumn: $$QuestionsTableReferences
                                ._practiceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sessionQuestionsRefs)
                        await $_getPrefetchedDataByColumns<
                          QuestionRow,
                          $QuestionsTable,
                          SessionQuestionRow,
                          $SessionQuestionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$QuestionsTableReferences
                              ._sessionQuestionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$QuestionsTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionQuestionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'question_id',
                          typedResults: items,
                        ),
                      if (attemptsRefs)
                        await $_getPrefetchedDataByColumns<
                          QuestionRow,
                          $QuestionsTable,
                          AttemptRow,
                          $AttemptsTable
                        >(
                          currentTable: table,
                          referencedTable: $$QuestionsTableReferences
                              ._attemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$QuestionsTableReferences(
                                db,
                                table,
                                p0,
                              ).attemptsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'question_id',
                          typedResults: items,
                        ),
                      if (conceptsRefs)
                        await $_getPrefetchedDataByColumns<
                          QuestionRow,
                          $QuestionsTable,
                          ConceptRow,
                          $ConceptsTable
                        >(
                          currentTable: table,
                          referencedTable: $$QuestionsTableReferences
                              ._conceptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$QuestionsTableReferences(
                                db,
                                table,
                                p0,
                              ).conceptsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'question_id',
                          typedResults: items,
                        ),
                      if (errorCardsRefs)
                        await $_getPrefetchedDataByColumns<
                          QuestionRow,
                          $QuestionsTable,
                          ErrorCardRow,
                          $ErrorCardsTable
                        >(
                          currentTable: table,
                          referencedTable: $$QuestionsTableReferences
                              ._errorCardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$QuestionsTableReferences(
                                db,
                                table,
                                p0,
                              ).errorCardsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'question_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$QuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestionsTable,
      QuestionRow,
      $$QuestionsTableFilterComposer,
      $$QuestionsTableOrderingComposer,
      $$QuestionsTableAnnotationComposer,
      $$QuestionsTableCreateCompanionBuilder,
      $$QuestionsTableUpdateCompanionBuilder,
      (QuestionRow, $$QuestionsTableReferences),
      QuestionRow,
      PrefetchHooks Function({
        bool practiceId,
        bool sessionQuestionsRefs,
        bool attemptsRefs,
        bool conceptsRefs,
        bool errorCardsRefs,
      })
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<int?> practiceId,
  required String mode,
  required String status,
  required DateTime startedAt,
  Value<DateTime?> finishedAt,
  required int total,
  Value<int> correct,
  Value<int> skipped,
  Value<int> distracted,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<int?> practiceId,
  Value<String> mode,
  Value<String> status,
  Value<DateTime> startedAt,
  Value<DateTime?> finishedAt,
  Value<int> total,
  Value<int> correct,
  Value<int> skipped,
  Value<int> distracted,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, SessionRow> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PracticesTable _practiceIdTable(_$AppDatabase db) =>
      db.practices.createAlias('sessions__practice_id__practices__id');

  $$PracticesTableProcessedTableManager? get practiceId {
    final $_column = $_itemColumn<int>('practice_id');
    if ($_column == null) return null;
    final manager = $$PracticesTableTableManager(
      $_db,
      $_db.practices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_practiceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SessionQuestionsTable, List<SessionQuestionRow>>
  _sessionQuestionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionQuestions,
    aliasName: 'sessions__id__session_questions__session_id',
  );

  $$SessionQuestionsTableProcessedTableManager get sessionQuestionsRefs {
    final manager = $$SessionQuestionsTableTableManager(
      $_db,
      $_db.sessionQuestions,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _sessionQuestionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttemptsTable, List<AttemptRow>>
  _attemptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attempts,
    aliasName: 'sessions__id__attempts__session_id',
  );

  $$AttemptsTableProcessedTableManager get attemptsRefs {
    final manager = $$AttemptsTableTableManager(
      $_db,
      $_db.attempts,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ConceptsTable, List<ConceptRow>>
  _conceptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.concepts,
    aliasName: 'sessions__id__concepts__session_id',
  );

  $$ConceptsTableProcessedTableManager get conceptsRefs {
    final manager = $$ConceptsTableTableManager(
      $_db,
      $_db.concepts,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_conceptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ErrorCardsTable, List<ErrorCardRow>>
  _errorCardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.errorCards,
    aliasName: 'sessions__id__error_cards__session_id',
  );

  $$ErrorCardsTableProcessedTableManager get errorCardsRefs {
    final manager = $$ErrorCardsTableTableManager(
      $_db,
      $_db.errorCards,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_errorCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ManualCardsTable, List<ManualCardRow>>
  _manualCardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.manualCards,
    aliasName: 'sessions__id__manual_cards__session_id',
  );

  $$ManualCardsTableProcessedTableManager get manualCardsRefs {
    final manager = $$ManualCardsTableTableManager(
      $_db,
      $_db.manualCards,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_manualCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distracted => $composableBuilder(
    column: $table.distracted,
    builder: (column) => ColumnFilters(column),
  );

  $$PracticesTableFilterComposer get practiceId {
    final $$PracticesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.practiceId,
      referencedTable: $db.practices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticesTableFilterComposer(
            $db: $db,
            $table: $db.practices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sessionQuestionsRefs(
    Expression<bool> Function($$SessionQuestionsTableFilterComposer f) f,
  ) {
    final $$SessionQuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionQuestions,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionQuestionsTableFilterComposer(
            $db: $db,
            $table: $db.sessionQuestions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attemptsRefs(
    Expression<bool> Function($$AttemptsTableFilterComposer f) f,
  ) {
    final $$AttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableFilterComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> conceptsRefs(
    Expression<bool> Function($$ConceptsTableFilterComposer f) f,
  ) {
    final $$ConceptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.concepts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConceptsTableFilterComposer(
            $db: $db,
            $table: $db.concepts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> errorCardsRefs(
    Expression<bool> Function($$ErrorCardsTableFilterComposer f) f,
  ) {
    final $$ErrorCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.errorCards,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ErrorCardsTableFilterComposer(
            $db: $db,
            $table: $db.errorCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> manualCardsRefs(
    Expression<bool> Function($$ManualCardsTableFilterComposer f) f,
  ) {
    final $$ManualCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.manualCards,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManualCardsTableFilterComposer(
            $db: $db,
            $table: $db.manualCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distracted => $composableBuilder(
    column: $table.distracted,
    builder: (column) => ColumnOrderings(column),
  );

  $$PracticesTableOrderingComposer get practiceId {
    final $$PracticesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.practiceId,
      referencedTable: $db.practices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticesTableOrderingComposer(
            $db: $db,
            $table: $db.practices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get skipped =>
      $composableBuilder(column: $table.skipped, builder: (column) => column);

  GeneratedColumn<int> get distracted => $composableBuilder(
    column: $table.distracted,
    builder: (column) => column,
  );

  $$PracticesTableAnnotationComposer get practiceId {
    final $$PracticesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.practiceId,
      referencedTable: $db.practices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticesTableAnnotationComposer(
            $db: $db,
            $table: $db.practices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sessionQuestionsRefs<T extends Object>(
    Expression<T> Function($$SessionQuestionsTableAnnotationComposer a) f,
  ) {
    final $$SessionQuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionQuestions,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionQuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionQuestions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attemptsRefs<T extends Object>(
    Expression<T> Function($$AttemptsTableAnnotationComposer a) f,
  ) {
    final $$AttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> conceptsRefs<T extends Object>(
    Expression<T> Function($$ConceptsTableAnnotationComposer a) f,
  ) {
    final $$ConceptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.concepts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConceptsTableAnnotationComposer(
            $db: $db,
            $table: $db.concepts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> errorCardsRefs<T extends Object>(
    Expression<T> Function($$ErrorCardsTableAnnotationComposer a) f,
  ) {
    final $$ErrorCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.errorCards,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ErrorCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.errorCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> manualCardsRefs<T extends Object>(
    Expression<T> Function($$ManualCardsTableAnnotationComposer a) f,
  ) {
    final $$ManualCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.manualCards,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ManualCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.manualCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (SessionRow, $$SessionsTableReferences),
          SessionRow,
          PrefetchHooks Function({
            bool practiceId,
            bool sessionQuestionsRefs,
            bool attemptsRefs,
            bool conceptsRefs,
            bool errorCardsRefs,
            bool manualCardsRefs,
          })
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> practiceId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<int> skipped = const Value.absent(),
                Value<int> distracted = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                practiceId: practiceId,
                mode: mode,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                total: total,
                correct: correct,
                skipped: skipped,
                distracted: distracted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> practiceId = const Value.absent(),
                required String mode,
                required String status,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                required int total,
                Value<int> correct = const Value.absent(),
                Value<int> skipped = const Value.absent(),
                Value<int> distracted = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                practiceId: practiceId,
                mode: mode,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                total: total,
                correct: correct,
                skipped: skipped,
                distracted: distracted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                practiceId = false,
                sessionQuestionsRefs = false,
                attemptsRefs = false,
                conceptsRefs = false,
                errorCardsRefs = false,
                manualCardsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sessionQuestionsRefs) db.sessionQuestions,
                    if (attemptsRefs) db.attempts,
                    if (conceptsRefs) db.concepts,
                    if (errorCardsRefs) db.errorCards,
                    if (manualCardsRefs) db.manualCards,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (practiceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.practiceId,
                            referencedTable: $$SessionsTableReferences
                                ._practiceIdTable(db),
                            referencedColumn: $$SessionsTableReferences
                                ._practiceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sessionQuestionsRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionRow,
                          $SessionsTable,
                          SessionQuestionRow,
                          $SessionQuestionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._sessionQuestionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionQuestionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                      if (attemptsRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionRow,
                          $SessionsTable,
                          AttemptRow,
                          $AttemptsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._attemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).attemptsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                      if (conceptsRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionRow,
                          $SessionsTable,
                          ConceptRow,
                          $ConceptsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._conceptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).conceptsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                      if (errorCardsRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionRow,
                          $SessionsTable,
                          ErrorCardRow,
                          $ErrorCardsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._errorCardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).errorCardsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                      if (manualCardsRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionRow,
                          $SessionsTable,
                          ManualCardRow,
                          $ManualCardsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._manualCardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).manualCardsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, $$SessionsTableReferences),
      SessionRow,
      PrefetchHooks Function({
        bool practiceId,
        bool sessionQuestionsRefs,
        bool attemptsRefs,
        bool conceptsRefs,
        bool errorCardsRefs,
        bool manualCardsRefs,
      })
    >;
typedef $$SessionQuestionsTableCreateCompanionBuilder =
    SessionQuestionsCompanion Function({
      required int sessionId,
      required int questionId,
      required int position,
      Value<int> rowid,
    });
typedef $$SessionQuestionsTableUpdateCompanionBuilder =
    SessionQuestionsCompanion Function({
      Value<int> sessionId,
      Value<int> questionId,
      Value<int> position,
      Value<int> rowid,
    });

final class $$SessionQuestionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SessionQuestionsTable,
          SessionQuestionRow
        > {
  $$SessionQuestionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('session_questions__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $QuestionsTable _questionIdTable(_$AppDatabase db) =>
      db.questions.createAlias('session_questions__question_id__questions__id');

  $$QuestionsTableProcessedTableManager get questionId {
    final $_column = $_itemColumn<int>('question_id')!;

    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_questionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionQuestionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionQuestionsTable> {
  $$SessionQuestionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableFilterComposer get questionId {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionQuestionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionQuestionsTable> {
  $$SessionQuestionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableOrderingComposer get questionId {
    final $$QuestionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableOrderingComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionQuestionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionQuestionsTable> {
  $$SessionQuestionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableAnnotationComposer get questionId {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionQuestionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionQuestionsTable,
          SessionQuestionRow,
          $$SessionQuestionsTableFilterComposer,
          $$SessionQuestionsTableOrderingComposer,
          $$SessionQuestionsTableAnnotationComposer,
          $$SessionQuestionsTableCreateCompanionBuilder,
          $$SessionQuestionsTableUpdateCompanionBuilder,
          (SessionQuestionRow, $$SessionQuestionsTableReferences),
          SessionQuestionRow,
          PrefetchHooks Function({bool sessionId, bool questionId})
        > {
  $$SessionQuestionsTableTableManager(
    _$AppDatabase db,
    $SessionQuestionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionQuestionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionQuestionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionQuestionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sessionId = const Value.absent(),
                Value<int> questionId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionQuestionsCompanion(
                sessionId: sessionId,
                questionId: questionId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sessionId,
                required int questionId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => SessionQuestionsCompanion.insert(
                sessionId: sessionId,
                questionId: questionId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionQuestionsTable, SessionQuestionRow>(
                    table,
                  ),
                  $$SessionQuestionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, questionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$SessionQuestionsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$SessionQuestionsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (questionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.questionId,
                        referencedTable: $$SessionQuestionsTableReferences
                            ._questionIdTable(db),
                        referencedColumn: $$SessionQuestionsTableReferences
                            ._questionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SessionQuestionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionQuestionsTable,
      SessionQuestionRow,
      $$SessionQuestionsTableFilterComposer,
      $$SessionQuestionsTableOrderingComposer,
      $$SessionQuestionsTableAnnotationComposer,
      $$SessionQuestionsTableCreateCompanionBuilder,
      $$SessionQuestionsTableUpdateCompanionBuilder,
      (SessionQuestionRow, $$SessionQuestionsTableReferences),
      SessionQuestionRow,
      PrefetchHooks Function({bool sessionId, bool questionId})
    >;
typedef $$AttemptsTableCreateCompanionBuilder = AttemptsCompanion Function({
  Value<int> id,
  required int sessionId,
  required int questionId,
  Value<int?> selectedIndex,
  Value<String> reasoning,
  Value<bool> distracted,
  required bool isCorrect,
  required DateTime answeredAt,
});
typedef $$AttemptsTableUpdateCompanionBuilder = AttemptsCompanion Function({
  Value<int> id,
  Value<int> sessionId,
  Value<int> questionId,
  Value<int?> selectedIndex,
  Value<String> reasoning,
  Value<bool> distracted,
  Value<bool> isCorrect,
  Value<DateTime> answeredAt,
});

final class $$AttemptsTableReferences
    extends BaseReferences<_$AppDatabase, $AttemptsTable, AttemptRow> {
  $$AttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('attempts__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $QuestionsTable _questionIdTable(_$AppDatabase db) =>
      db.questions.createAlias('attempts__question_id__questions__id');

  $$QuestionsTableProcessedTableManager get questionId {
    final $_column = $_itemColumn<int>('question_id')!;

    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_questionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get selectedIndex => $composableBuilder(
    column: $table.selectedIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get distracted => $composableBuilder(
    column: $table.distracted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCorrect => $composableBuilder(
    column: $table.isCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableFilterComposer get questionId {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get selectedIndex => $composableBuilder(
    column: $table.selectedIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get distracted => $composableBuilder(
    column: $table.distracted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCorrect => $composableBuilder(
    column: $table.isCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableOrderingComposer get questionId {
    final $$QuestionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableOrderingComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get selectedIndex => $composableBuilder(
    column: $table.selectedIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reasoning =>
      $composableBuilder(column: $table.reasoning, builder: (column) => column);

  GeneratedColumn<bool> get distracted => $composableBuilder(
    column: $table.distracted,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCorrect =>
      $composableBuilder(column: $table.isCorrect, builder: (column) => column);

  GeneratedColumn<DateTime> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => column,
  );

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableAnnotationComposer get questionId {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttemptsTable,
          AttemptRow,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (AttemptRow, $$AttemptsTableReferences),
          AttemptRow,
          PrefetchHooks Function({bool sessionId, bool questionId})
        > {
  $$AttemptsTableTableManager(_$AppDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> questionId = const Value.absent(),
                Value<int?> selectedIndex = const Value.absent(),
                Value<String> reasoning = const Value.absent(),
                Value<bool> distracted = const Value.absent(),
                Value<bool> isCorrect = const Value.absent(),
                Value<DateTime> answeredAt = const Value.absent(),
              }) => AttemptsCompanion(
                id: id,
                sessionId: sessionId,
                questionId: questionId,
                selectedIndex: selectedIndex,
                reasoning: reasoning,
                distracted: distracted,
                isCorrect: isCorrect,
                answeredAt: answeredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int questionId,
                Value<int?> selectedIndex = const Value.absent(),
                Value<String> reasoning = const Value.absent(),
                Value<bool> distracted = const Value.absent(),
                required bool isCorrect,
                required DateTime answeredAt,
              }) => AttemptsCompanion.insert(
                id: id,
                sessionId: sessionId,
                questionId: questionId,
                selectedIndex: selectedIndex,
                reasoning: reasoning,
                distracted: distracted,
                isCorrect: isCorrect,
                answeredAt: answeredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttemptsTable, AttemptRow>(table),
                  $$AttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, questionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$AttemptsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$AttemptsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (questionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.questionId,
                        referencedTable: $$AttemptsTableReferences
                            ._questionIdTable(db),
                        referencedColumn: $$AttemptsTableReferences
                            ._questionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttemptsTable,
      AttemptRow,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (AttemptRow, $$AttemptsTableReferences),
      AttemptRow,
      PrefetchHooks Function({bool sessionId, bool questionId})
    >;
typedef $$ConceptsTableCreateCompanionBuilder = ConceptsCompanion Function({
  Value<int> id,
  Value<int?> sessionId,
  Value<int?> questionId,
  required String term,
  Value<String> definition,
  Value<String> context,
  Value<String> topicName,
  required String source,
  required DateTime createdAt,
  Value<DateTime?> exportedAt,
});
typedef $$ConceptsTableUpdateCompanionBuilder = ConceptsCompanion Function({
  Value<int> id,
  Value<int?> sessionId,
  Value<int?> questionId,
  Value<String> term,
  Value<String> definition,
  Value<String> context,
  Value<String> topicName,
  Value<String> source,
  Value<DateTime> createdAt,
  Value<DateTime?> exportedAt,
});

final class $$ConceptsTableReferences
    extends BaseReferences<_$AppDatabase, $ConceptsTable, ConceptRow> {
  $$ConceptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('concepts__session_id__sessions__id');

  $$SessionsTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<int>('session_id');
    if ($_column == null) return null;
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $QuestionsTable _questionIdTable(_$AppDatabase db) =>
      db.questions.createAlias('concepts__question_id__questions__id');

  $$QuestionsTableProcessedTableManager? get questionId {
    final $_column = $_itemColumn<int>('question_id');
    if ($_column == null) return null;
    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_questionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ConceptsTableFilterComposer
    extends Composer<_$AppDatabase, $ConceptsTable> {
  $$ConceptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicName => $composableBuilder(
    column: $table.topicName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableFilterComposer get questionId {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConceptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConceptsTable> {
  $$ConceptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicName => $composableBuilder(
    column: $table.topicName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableOrderingComposer get questionId {
    final $$QuestionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableOrderingComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConceptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConceptsTable> {
  $$ConceptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get term =>
      $composableBuilder(column: $table.term, builder: (column) => column);

  GeneratedColumn<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get topicName =>
      $composableBuilder(column: $table.topicName, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => column,
  );

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$QuestionsTableAnnotationComposer get questionId {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConceptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConceptsTable,
          ConceptRow,
          $$ConceptsTableFilterComposer,
          $$ConceptsTableOrderingComposer,
          $$ConceptsTableAnnotationComposer,
          $$ConceptsTableCreateCompanionBuilder,
          $$ConceptsTableUpdateCompanionBuilder,
          (ConceptRow, $$ConceptsTableReferences),
          ConceptRow,
          PrefetchHooks Function({bool sessionId, bool questionId})
        > {
  $$ConceptsTableTableManager(_$AppDatabase db, $ConceptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConceptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConceptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConceptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<int?> questionId = const Value.absent(),
                Value<String> term = const Value.absent(),
                Value<String> definition = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<String> topicName = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> exportedAt = const Value.absent(),
              }) => ConceptsCompanion(
                id: id,
                sessionId: sessionId,
                questionId: questionId,
                term: term,
                definition: definition,
                context: context,
                topicName: topicName,
                source: source,
                createdAt: createdAt,
                exportedAt: exportedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<int?> questionId = const Value.absent(),
                required String term,
                Value<String> definition = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<String> topicName = const Value.absent(),
                required String source,
                required DateTime createdAt,
                Value<DateTime?> exportedAt = const Value.absent(),
              }) => ConceptsCompanion.insert(
                id: id,
                sessionId: sessionId,
                questionId: questionId,
                term: term,
                definition: definition,
                context: context,
                topicName: topicName,
                source: source,
                createdAt: createdAt,
                exportedAt: exportedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConceptsTable, ConceptRow>(table),
                  $$ConceptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, questionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$ConceptsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$ConceptsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (questionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.questionId,
                        referencedTable: $$ConceptsTableReferences
                            ._questionIdTable(db),
                        referencedColumn: $$ConceptsTableReferences
                            ._questionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ConceptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConceptsTable,
      ConceptRow,
      $$ConceptsTableFilterComposer,
      $$ConceptsTableOrderingComposer,
      $$ConceptsTableAnnotationComposer,
      $$ConceptsTableCreateCompanionBuilder,
      $$ConceptsTableUpdateCompanionBuilder,
      (ConceptRow, $$ConceptsTableReferences),
      ConceptRow,
      PrefetchHooks Function({bool sessionId, bool questionId})
    >;
typedef $$ErrorCardsTableCreateCompanionBuilder = ErrorCardsCompanion Function({
  Value<int> id,
  required int questionId,
  Value<int?> sessionId,
  required String question,
  required String alternativesJson,
  required int correctIndex,
  required int wrongIndex,
  Value<String> reasoning,
  Value<String> bias,
  Value<String> vaccine,
  Value<String> topicName,
  Value<String> practiceName,
  required String status,
  required DateTime createdAt,
  required DateTime lastWrongAt,
  required DateTime dueAt,
  Value<DateTime?> detailsCompletedAt,
  Value<DateTime?> resolvedAt,
  Value<DateTime?> exportedAt,
});
typedef $$ErrorCardsTableUpdateCompanionBuilder = ErrorCardsCompanion Function({
  Value<int> id,
  Value<int> questionId,
  Value<int?> sessionId,
  Value<String> question,
  Value<String> alternativesJson,
  Value<int> correctIndex,
  Value<int> wrongIndex,
  Value<String> reasoning,
  Value<String> bias,
  Value<String> vaccine,
  Value<String> topicName,
  Value<String> practiceName,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> lastWrongAt,
  Value<DateTime> dueAt,
  Value<DateTime?> detailsCompletedAt,
  Value<DateTime?> resolvedAt,
  Value<DateTime?> exportedAt,
});

final class $$ErrorCardsTableReferences
    extends BaseReferences<_$AppDatabase, $ErrorCardsTable, ErrorCardRow> {
  $$ErrorCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $QuestionsTable _questionIdTable(_$AppDatabase db) =>
      db.questions.createAlias('error_cards__question_id__questions__id');

  $$QuestionsTableProcessedTableManager get questionId {
    final $_column = $_itemColumn<int>('question_id')!;

    final manager = $$QuestionsTableTableManager(
      $_db,
      $_db.questions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_questionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('error_cards__session_id__sessions__id');

  $$SessionsTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<int>('session_id');
    if ($_column == null) return null;
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ErrorCardsTableFilterComposer
    extends Composer<_$AppDatabase, $ErrorCardsTable> {
  $$ErrorCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternativesJson => $composableBuilder(
    column: $table.alternativesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctIndex => $composableBuilder(
    column: $table.correctIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrongIndex => $composableBuilder(
    column: $table.wrongIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bias => $composableBuilder(
    column: $table.bias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaccine => $composableBuilder(
    column: $table.vaccine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicName => $composableBuilder(
    column: $table.topicName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get practiceName => $composableBuilder(
    column: $table.practiceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastWrongAt => $composableBuilder(
    column: $table.lastWrongAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get detailsCompletedAt => $composableBuilder(
    column: $table.detailsCompletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$QuestionsTableFilterComposer get questionId {
    final $$QuestionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableFilterComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ErrorCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $ErrorCardsTable> {
  $$ErrorCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternativesJson => $composableBuilder(
    column: $table.alternativesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctIndex => $composableBuilder(
    column: $table.correctIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrongIndex => $composableBuilder(
    column: $table.wrongIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bias => $composableBuilder(
    column: $table.bias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaccine => $composableBuilder(
    column: $table.vaccine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicName => $composableBuilder(
    column: $table.topicName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get practiceName => $composableBuilder(
    column: $table.practiceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastWrongAt => $composableBuilder(
    column: $table.lastWrongAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get detailsCompletedAt => $composableBuilder(
    column: $table.detailsCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$QuestionsTableOrderingComposer get questionId {
    final $$QuestionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableOrderingComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ErrorCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ErrorCardsTable> {
  $$ErrorCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get alternativesJson => $composableBuilder(
    column: $table.alternativesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctIndex => $composableBuilder(
    column: $table.correctIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wrongIndex => $composableBuilder(
    column: $table.wrongIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reasoning =>
      $composableBuilder(column: $table.reasoning, builder: (column) => column);

  GeneratedColumn<String> get bias =>
      $composableBuilder(column: $table.bias, builder: (column) => column);

  GeneratedColumn<String> get vaccine =>
      $composableBuilder(column: $table.vaccine, builder: (column) => column);

  GeneratedColumn<String> get topicName =>
      $composableBuilder(column: $table.topicName, builder: (column) => column);

  GeneratedColumn<String> get practiceName => $composableBuilder(
    column: $table.practiceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastWrongAt => $composableBuilder(
    column: $table.lastWrongAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<DateTime> get detailsCompletedAt => $composableBuilder(
    column: $table.detailsCompletedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => column,
  );

  $$QuestionsTableAnnotationComposer get questionId {
    final $$QuestionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.questionId,
      referencedTable: $db.questions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuestionsTableAnnotationComposer(
            $db: $db,
            $table: $db.questions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ErrorCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ErrorCardsTable,
          ErrorCardRow,
          $$ErrorCardsTableFilterComposer,
          $$ErrorCardsTableOrderingComposer,
          $$ErrorCardsTableAnnotationComposer,
          $$ErrorCardsTableCreateCompanionBuilder,
          $$ErrorCardsTableUpdateCompanionBuilder,
          (ErrorCardRow, $$ErrorCardsTableReferences),
          ErrorCardRow,
          PrefetchHooks Function({bool questionId, bool sessionId})
        > {
  $$ErrorCardsTableTableManager(_$AppDatabase db, $ErrorCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ErrorCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ErrorCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ErrorCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> questionId = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> alternativesJson = const Value.absent(),
                Value<int> correctIndex = const Value.absent(),
                Value<int> wrongIndex = const Value.absent(),
                Value<String> reasoning = const Value.absent(),
                Value<String> bias = const Value.absent(),
                Value<String> vaccine = const Value.absent(),
                Value<String> topicName = const Value.absent(),
                Value<String> practiceName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastWrongAt = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<DateTime?> detailsCompletedAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime?> exportedAt = const Value.absent(),
              }) => ErrorCardsCompanion(
                id: id,
                questionId: questionId,
                sessionId: sessionId,
                question: question,
                alternativesJson: alternativesJson,
                correctIndex: correctIndex,
                wrongIndex: wrongIndex,
                reasoning: reasoning,
                bias: bias,
                vaccine: vaccine,
                topicName: topicName,
                practiceName: practiceName,
                status: status,
                createdAt: createdAt,
                lastWrongAt: lastWrongAt,
                dueAt: dueAt,
                detailsCompletedAt: detailsCompletedAt,
                resolvedAt: resolvedAt,
                exportedAt: exportedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int questionId,
                Value<int?> sessionId = const Value.absent(),
                required String question,
                required String alternativesJson,
                required int correctIndex,
                required int wrongIndex,
                Value<String> reasoning = const Value.absent(),
                Value<String> bias = const Value.absent(),
                Value<String> vaccine = const Value.absent(),
                Value<String> topicName = const Value.absent(),
                Value<String> practiceName = const Value.absent(),
                required String status,
                required DateTime createdAt,
                required DateTime lastWrongAt,
                required DateTime dueAt,
                Value<DateTime?> detailsCompletedAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime?> exportedAt = const Value.absent(),
              }) => ErrorCardsCompanion.insert(
                id: id,
                questionId: questionId,
                sessionId: sessionId,
                question: question,
                alternativesJson: alternativesJson,
                correctIndex: correctIndex,
                wrongIndex: wrongIndex,
                reasoning: reasoning,
                bias: bias,
                vaccine: vaccine,
                topicName: topicName,
                practiceName: practiceName,
                status: status,
                createdAt: createdAt,
                lastWrongAt: lastWrongAt,
                dueAt: dueAt,
                detailsCompletedAt: detailsCompletedAt,
                resolvedAt: resolvedAt,
                exportedAt: exportedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ErrorCardsTable, ErrorCardRow>(table),
                  $$ErrorCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({questionId = false, sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (questionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.questionId,
                        referencedTable: $$ErrorCardsTableReferences
                            ._questionIdTable(db),
                        referencedColumn: $$ErrorCardsTableReferences
                            ._questionIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$ErrorCardsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$ErrorCardsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ErrorCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ErrorCardsTable,
      ErrorCardRow,
      $$ErrorCardsTableFilterComposer,
      $$ErrorCardsTableOrderingComposer,
      $$ErrorCardsTableAnnotationComposer,
      $$ErrorCardsTableCreateCompanionBuilder,
      $$ErrorCardsTableUpdateCompanionBuilder,
      (ErrorCardRow, $$ErrorCardsTableReferences),
      ErrorCardRow,
      PrefetchHooks Function({bool questionId, bool sessionId})
    >;
typedef $$ManualCardsTableCreateCompanionBuilder =
    ManualCardsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      required String question,
      required String answer,
      Value<String> topicName,
      required DateTime createdAt,
      Value<DateTime?> exportedAt,
    });
typedef $$ManualCardsTableUpdateCompanionBuilder =
    ManualCardsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      Value<String> question,
      Value<String> answer,
      Value<String> topicName,
      Value<DateTime> createdAt,
      Value<DateTime?> exportedAt,
    });

final class $$ManualCardsTableReferences
    extends BaseReferences<_$AppDatabase, $ManualCardsTable, ManualCardRow> {
  $$ManualCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('manual_cards__session_id__sessions__id');

  $$SessionsTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<int>('session_id');
    if ($_column == null) return null;
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ManualCardsTableFilterComposer
    extends Composer<_$AppDatabase, $ManualCardsTable> {
  $$ManualCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicName => $composableBuilder(
    column: $table.topicName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ManualCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $ManualCardsTable> {
  $$ManualCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicName => $composableBuilder(
    column: $table.topicName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ManualCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ManualCardsTable> {
  $$ManualCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get topicName =>
      $composableBuilder(column: $table.topicName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get exportedAt => $composableBuilder(
    column: $table.exportedAt,
    builder: (column) => column,
  );

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ManualCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ManualCardsTable,
          ManualCardRow,
          $$ManualCardsTableFilterComposer,
          $$ManualCardsTableOrderingComposer,
          $$ManualCardsTableAnnotationComposer,
          $$ManualCardsTableCreateCompanionBuilder,
          $$ManualCardsTableUpdateCompanionBuilder,
          (ManualCardRow, $$ManualCardsTableReferences),
          ManualCardRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$ManualCardsTableTableManager(_$AppDatabase db, $ManualCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ManualCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ManualCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ManualCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> topicName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> exportedAt = const Value.absent(),
              }) => ManualCardsCompanion(
                id: id,
                sessionId: sessionId,
                question: question,
                answer: answer,
                topicName: topicName,
                createdAt: createdAt,
                exportedAt: exportedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                required String question,
                required String answer,
                Value<String> topicName = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> exportedAt = const Value.absent(),
              }) => ManualCardsCompanion.insert(
                id: id,
                sessionId: sessionId,
                question: question,
                answer: answer,
                topicName: topicName,
                createdAt: createdAt,
                exportedAt: exportedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ManualCardsTable, ManualCardRow>(table),
                  $$ManualCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$ManualCardsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$ManualCardsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ManualCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ManualCardsTable,
      ManualCardRow,
      $$ManualCardsTableFilterComposer,
      $$ManualCardsTableOrderingComposer,
      $$ManualCardsTableAnnotationComposer,
      $$ManualCardsTableCreateCompanionBuilder,
      $$ManualCardsTableUpdateCompanionBuilder,
      (ManualCardRow, $$ManualCardsTableReferences),
      ManualCardRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db, _db.topics);
  $$PracticesTableTableManager get practices =>
      $$PracticesTableTableManager(_db, _db.practices);
  $$QuestionsTableTableManager get questions =>
      $$QuestionsTableTableManager(_db, _db.questions);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionQuestionsTableTableManager get sessionQuestions =>
      $$SessionQuestionsTableTableManager(_db, _db.sessionQuestions);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db, _db.attempts);
  $$ConceptsTableTableManager get concepts =>
      $$ConceptsTableTableManager(_db, _db.concepts);
  $$ErrorCardsTableTableManager get errorCards =>
      $$ErrorCardsTableTableManager(_db, _db.errorCards);
  $$ManualCardsTableTableManager get manualCards =>
      $$ManualCardsTableTableManager(_db, _db.manualCards);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
