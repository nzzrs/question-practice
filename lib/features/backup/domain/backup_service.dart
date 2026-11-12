import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/models.dart';

/// Raised when a backup file cannot be read or applied.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Counts and metadata read from a valid backup file.
class BackupInfo {
  const BackupInfo({
    required this.exportedAt,
    required this.topics,
    required this.practices,
    required this.questions,
    required this.sessions,
    required this.attempts,
    required this.concepts,
    required this.errorCards,
    required this.manualCards,
    this.skippedQuestions = 0,
    this.highlights = 0,
    this.archivedTopics = 0,
    this.formatVersion = 1,
    this.appVersion,
    this.buildNumber,
    this.schemaVersion,
    this.tableCounts = const <String, int>{},
  });

  final DateTime? exportedAt;
  final int topics;
  final int practices;
  final int questions;
  final int sessions;
  final int attempts;
  final int concepts;
  final int errorCards;
  final int manualCards;
  final int skippedQuestions;
  final int highlights;
  final int archivedTopics;

  /// Format of the file this information came from.
  final int formatVersion;

  /// App version and build that produced the file, when the file records them.
  final String? appVersion;
  final int? buildNumber;

  /// Database schema version that produced the file, when it is recorded.
  final int? schemaVersion;

  /// Rows per table as recorded by the backup, empty when the file has none.
  final Map<String, int> tableCounts;

  int get cards => concepts + errorCards + manualCards;

  String get description {
    final archived = archivedTopics > 0 ? ' ($archivedTopics archived)' : '';
    final buffer = StringBuffer(
      '$topics topics$archived, $practices practices, $questions questions, '
      '$sessions sessions, $attempts answers and $cards cards',
    );
    if (skippedQuestions > 0) {
      buffer.write(', $skippedQuestions skipped questions');
    }
    if (highlights > 0) {
      buffer.write(', $highlights highlights');
    }
    return buffer.toString();
  }

  /// A short label for the file producer, used by the restore preview.
  String get sourceLabel {
    final version = appVersion;
    if (version == null || version.trim().isEmpty) {
      return 'backup format v$formatVersion';
    }
    final build = buildNumber;
    final suffix = build == null ? '' : ' ($build)';
    return 'app $version$suffix, backup format v$formatVersion';
  }
}

class BackupService {
  BackupService({required AppDatabase database, required Clock clock})
    : _db = database,
      _clock = clock;

  /// Format written by this version of the app.
  static const formatVersion = 2;

  /// Oldest format this app can still read.
  static const minimumFormatVersion = 1;

  /// Release information recorded in exported files.
  ///
  /// Kept in sync with `pubspec.yaml` and the About section. The backup format
  /// must not depend on platform plugins just to read its own version.
  static const appVersion = '0.9.10';
  static const buildNumber = 11;

  static const appId = 'question_practice';
  static const maxImportBytes = 50 * 1024 * 1024;

  /// Tables that must be present in every supported backup.
  static const requiredTables = <String>{
    'topics',
    'practices',
    'questions',
    'sessions',
    'sessionQuestions',
    'attempts',
    'concepts',
    'errorCards',
    'manualCards',
    'settings',
  };

  /// Tables added after the first backup format.
  static const optionalTables = <String>{'skippedQuestions', 'highlights'};

  final AppDatabase _db;
  final Clock _clock;

  /// Serializes every local table into a versioned JSON document.
  ///
  /// The AI API key lives in Android secure storage and is deliberately not
  /// part of the database, so it never appears in a backup.
  Future<String> encode() async {
    // One read transaction gives a consistent snapshot even if the UI writes
    // while the backup is being prepared.
    final tables = await _db.transaction(_readAllTables);
    final exportedAt = _clock.now().toUtc();
    final counts = <String, int>{
      for (final entry in tables.entries)
        entry.key: (entry.value as List).length,
    };
    final payload = <String, dynamic>{
      'app': appId,
      'formatVersion': formatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'metadata': <String, dynamic>{
        'formatVersion': formatVersion,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'schemaVersion': _db.schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'tableCounts': counts,
      },
      'checksum': _checksum(tables),
      'tables': tables,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Validates a backup without writing anything.
  Future<BackupInfo> inspectBytes(Uint8List bytes) async {
    return inspectText(_decodeBytes(bytes));
  }

  /// Validates a backup without writing anything.
  BackupInfo inspectText(String text) {
    return _parse(text).info;
  }

  /// Replaces every local table with the contents of [text].
  ///
  /// Parsing and validation happen before the transaction, and the write
  /// itself is atomic, so an invalid backup leaves the current data untouched.
  Future<BackupInfo> restoreText(String text) async {
    final backup = _parse(text);
    try {
      await _db.transaction(() async {
        await _db.clearAll();
        await _db.batch((batch) {
          batch.insertAll(_db.topics, [
            for (final row in backup.topics) row.toCompanion(false),
          ]);
          batch.insertAll(_db.practices, [
            for (final row in backup.practices) row.toCompanion(false),
          ]);
          batch.insertAll(_db.questions, [
            for (final row in backup.questions) row.toCompanion(false),
          ]);
          batch.insertAll(_db.sessions, [
            for (final row in backup.sessions) row.toCompanion(false),
          ]);
          batch.insertAll(_db.sessionQuestions, [
            for (final row in backup.sessionQuestions) row.toCompanion(false),
          ]);
          batch.insertAll(_db.attempts, [
            for (final row in backup.attempts) row.toCompanion(false),
          ]);
          batch.insertAll(_db.concepts, [
            for (final row in backup.concepts) row.toCompanion(false),
          ]);
          batch.insertAll(_db.errorCards, [
            for (final row in backup.errorCards) row.toCompanion(false),
          ]);
          batch.insertAll(_db.manualCards, [
            for (final row in backup.manualCards) row.toCompanion(false),
          ]);
          batch.insertAll(_db.skippedQuestions, [
            for (final row in backup.skippedQuestions) row.toCompanion(false),
          ]);
          batch.insertAll(_db.highlights, [
            for (final row in backup.highlights) row.toCompanion(false),
          ]);
          batch.insertAll(_db.settings, [
            for (final row in backup.settings) row.toCompanion(false),
          ]);
        });
      });
    } on BackupException {
      rethrow;
    } on Object catch (error) {
      throw BackupException('The backup could not be applied: $error');
    }
    return backup.info;
  }

  /// Replaces every local table with the contents of [bytes].
  Future<BackupInfo> restoreBytes(Uint8List bytes) async {
    return restoreText(_decodeBytes(bytes));
  }

  /// Writes a timestamped backup to the temporary directory.
  Future<File> writeBackupFile() async {
    final directory = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(_clock.now());
    final file = File(
      p.join(directory.path, 'question-practice-backup-$stamp.json'),
    );
    await file.writeAsString(await encode());
    return file;
  }

  /// Writes a backup and opens the system share sheet.
  Future<File> shareBackup() async {
    final file = await writeBackupFile();
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Question Practice backup',
        text: 'Complete local backup from Question Practice.',
        files: [XFile(file.path)],
      ),
    );
    return file;
  }

  Future<Map<String, dynamic>> _readAllTables() async {
    final topics = await _db.select(_db.topics).get();
    final practices = await _db.select(_db.practices).get();
    final questions = await _db.select(_db.questions).get();
    final sessions = await _db.select(_db.sessions).get();
    final sessionQuestions = await _db.select(_db.sessionQuestions).get();
    final attempts = await _db.select(_db.attempts).get();
    final concepts = await _db.select(_db.concepts).get();
    final errorCards = await _db.select(_db.errorCards).get();
    final manualCards = await _db.select(_db.manualCards).get();
    final skippedQuestions = await _db.select(_db.skippedQuestions).get();
    final highlights = await _db.select(_db.highlights).get();
    final settings = await _db.select(_db.settings).get();

    return <String, dynamic>{
      'topics': [for (final row in topics) row.toJson()],
      'practices': [for (final row in practices) row.toJson()],
      'questions': [for (final row in questions) row.toJson()],
      'sessions': [for (final row in sessions) row.toJson()],
      'sessionQuestions': [for (final row in sessionQuestions) row.toJson()],
      'attempts': [for (final row in attempts) row.toJson()],
      'concepts': [for (final row in concepts) row.toJson()],
      'errorCards': [for (final row in errorCards) row.toJson()],
      'manualCards': [for (final row in manualCards) row.toJson()],
      'skippedQuestions': [for (final row in skippedQuestions) row.toJson()],
      'highlights': [for (final row in highlights) row.toJson()],
      'settings': [for (final row in settings) row.toJson()],
    };
  }

  String _decodeBytes(Uint8List bytes) {
    if (bytes.lengthInBytes > maxImportBytes) {
      throw const BackupException('The backup file is larger than 50 MB.');
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const BackupException('The backup file is not valid UTF-8 text.');
    }
  }

  _BackupTables _parse(String text) {
    if (text.trim().isEmpty) {
      throw const BackupException('The backup file is empty.');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw BackupException('The backup is not valid JSON: ${error.message}');
    }
    if (decoded is! Map) {
      throw const BackupException('The backup is not a JSON object.');
    }
    final payload = decoded.cast<String, dynamic>();
    if (payload['app'] != appId) {
      throw const BackupException(
        'This file is not a Question Practice backup.',
      );
    }
    final version = _formatVersion(payload['formatVersion']);
    final metadata = _metadata(payload['metadata'], version);
    _checkSchemaVersion(metadata);

    final rawTables = payload['tables'];
    if (rawTables is! Map) {
      throw const BackupException('The backup has no data tables.');
    }
    final tables = rawTables.cast<String, dynamic>();
    final checksum = payload['checksum'];
    if (checksum is! String) {
      throw const BackupException('The backup has no integrity checksum.');
    }
    if (checksum != _checksum(tables)) {
      throw const BackupException(
        'The backup is damaged or was changed after export.',
      );
    }

    final content = _readContent(tables);
    _checkTableCounts(tables, metadata);
    _validateReferences(content);

    final info = BackupInfo(
      exportedAt: _date(payload['exportedAt']) ?? _date(metadata['exportedAt']),
      topics: content.topics.length,
      practices: content.practices.length,
      questions: content.questions.length,
      sessions: content.sessions.length,
      attempts: content.attempts.length,
      concepts: content.concepts.length,
      errorCards: content.errorCards.length,
      manualCards: content.manualCards.length,
      skippedQuestions: content.skippedQuestions.length,
      highlights: content.highlights.length,
      archivedTopics: content.topics.where((row) => row.archived).length,
      formatVersion: version,
      appVersion: _stringOrNull(metadata['appVersion']),
      buildNumber: metadata['buildNumber'] is int
          ? metadata['buildNumber'] as int
          : null,
      schemaVersion: metadata['schemaVersion'] is int
          ? metadata['schemaVersion'] as int
          : null,
      tableCounts: _readCounts(metadata['tableCounts']) ?? const {},
    );
    return _BackupTables(info: info, content: content);
  }

  int _formatVersion(Object? value) {
    if (value is! int) {
      throw const BackupException('The backup has no format version.');
    }
    if (value > formatVersion) {
      throw BackupException(
        'This backup uses format version $value, but this app supports up to '
        '$formatVersion. Update the app and try again.',
      );
    }
    if (value < minimumFormatVersion) {
      throw BackupException(
        'The backup uses unsupported format version $value.',
      );
    }
    return value;
  }

  Map<String, dynamic> _metadata(Object? value, int version) {
    if (value == null) {
      if (version > 1) {
        throw const BackupException('The backup has no metadata block.');
      }
      return const <String, dynamic>{};
    }
    if (value is! Map) {
      throw const BackupException('The backup metadata is not an object.');
    }
    final metadata = value.cast<String, dynamic>();
    final recorded = metadata['formatVersion'];
    if (recorded != null && recorded != version) {
      throw const BackupException(
        'The backup metadata does not match its format version.',
      );
    }
    return metadata;
  }

  void _checkSchemaVersion(Map<String, dynamic> metadata) {
    final schema = metadata['schemaVersion'];
    if (schema is! int) return;
    if (schema > _db.schemaVersion) {
      throw BackupException(
        'This backup was made with database schema $schema, but this app uses '
        'schema ${_db.schemaVersion}. Update the app and try again.',
      );
    }
  }

  _BackupContent _readContent(Map<String, dynamic> tables) {
    for (final key in requiredTables) {
      if (!tables.containsKey(key)) {
        throw BackupException('The backup is missing the "$key" table.');
      }
    }
    return _BackupContent(
      topics: _readRows<TopicRow>(
        tables,
        'topics',
        parse: _topic,
        identities: (row) => ['id ${row.id}'],
      ),
      practices: _readRows<PracticeRow>(
        tables,
        'practices',
        parse: _practice,
        identities: (row) => ['id ${row.id}'],
      ),
      questions: _readRows<QuestionRow>(
        tables,
        'questions',
        parse: _question,
        identities: (row) => ['id ${row.id}'],
      ),
      sessions: _readRows<SessionRow>(
        tables,
        'sessions',
        parse: _session,
        identities: (row) => ['id ${row.id}'],
      ),
      sessionQuestions: _readRows<SessionQuestionRow>(
        tables,
        'sessionQuestions',
        parse: _sessionQuestion,
        identities: (row) => [
          'session ${row.sessionId} / question ${row.questionId}',
        ],
      ),
      attempts: _readRows<AttemptRow>(
        tables,
        'attempts',
        parse: _attempt,
        identities: (row) => [
          'id ${row.id}',
          'session ${row.sessionId} / question ${row.questionId}',
        ],
      ),
      concepts: _readRows<ConceptRow>(
        tables,
        'concepts',
        parse: _concept,
        identities: (row) => ['id ${row.id}'],
      ),
      errorCards: _readRows<ErrorCardRow>(
        tables,
        'errorCards',
        parse: _errorCard,
        identities: (row) => ['id ${row.id}'],
      ),
      manualCards: _readRows<ManualCardRow>(
        tables,
        'manualCards',
        parse: _manualCard,
        identities: (row) => ['id ${row.id}'],
      ),
      skippedQuestions: _readRows<SkippedQuestionRow>(
        tables,
        'skippedQuestions',
        optional: true,
        parse: _skippedQuestion,
        identities: (row) => ['id ${row.id}'],
      ),
      highlights: _readRows<HighlightRow>(
        tables,
        'highlights',
        optional: true,
        parse: _highlight,
        identities: (row) => ['id ${row.id}'],
      ),
      settings: _readRows<SettingRow>(
        tables,
        'settings',
        parse: _setting,
        identities: (row) => ['key "${row.key}"'],
      ),
    );
  }

  /// Reads one table, rejecting malformed rows and duplicate identities.
  List<T> _readRows<T>(
    Map<String, dynamic> tables,
    String key, {
    required T Function(_Row row) parse,
    required List<String> Function(T row) identities,
    bool optional = false,
  }) {
    final raw = tables[key];
    if (raw == null) {
      if (optional) return <T>[];
      throw BackupException('The backup is missing the "$key" table.');
    }
    if (raw is! List) {
      throw BackupException('The "$key" table is not a list of rows.');
    }
    final rows = <T>[];
    final seen = <String>{};
    for (var index = 0; index < raw.length; index++) {
      final item = raw[index];
      if (item is! Map) {
        throw BackupException(
          'The "$key" table entry ${index + 1} is not an object.',
        );
      }
      final row = _Row(
        item.cast<String, dynamic>(),
        'The "$key" table entry ${index + 1}',
      );
      final T parsed;
      try {
        parsed = parse(row);
      } on _BadRow catch (error) {
        throw BackupException('${row.path}: ${error.message}');
      }
      for (final identity in identities(parsed)) {
        if (!seen.add(identity)) {
          throw BackupException('The "$key" table has a duplicate $identity.');
        }
      }
      rows.add(parsed);
    }
    return rows;
  }

  void _checkTableCounts(
    Map<String, dynamic> tables,
    Map<String, dynamic> metadata,
  ) {
    final recorded = _readCounts(metadata['tableCounts']);
    if (recorded == null) return;
    for (final entry in recorded.entries) {
      final known =
          requiredTables.contains(entry.key) ||
          optionalTables.contains(entry.key);
      if (!known) continue;
      final raw = tables[entry.key];
      final actual = raw is List ? raw.length : 0;
      if (actual != entry.value) {
        throw BackupException(
          'The backup metadata says "${entry.key}" has ${entry.value} rows, '
          'but the table has $actual.',
        );
      }
    }
  }

  Map<String, int>? _readCounts(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const BackupException('The backup table counts are not an object.');
    }
    final counts = <String, int>{};
    for (final entry in value.entries) {
      final count = entry.value;
      if (count is! int || count < 0) {
        throw BackupException(
          'The backup row count for "${entry.key}" is not a valid number.',
        );
      }
      counts[entry.key.toString()] = count;
    }
    return counts;
  }

  void _validateReferences(_BackupContent content) {
    final topicIds = {for (final row in content.topics) row.id};
    final practiceIds = {for (final row in content.practices) row.id};
    final questionIds = {for (final row in content.questions) row.id};
    final sessionIds = {for (final row in content.sessions) row.id};
    final manualCardIds = {for (final row in content.manualCards) row.id};

    for (final row in content.practices) {
      _requireReference('practices', row.id, 'topic', row.topicId, topicIds);
    }
    for (final row in content.questions) {
      _requireReference(
        'questions',
        row.id,
        'practice',
        row.practiceId,
        practiceIds,
      );
    }
    for (final row in content.sessions) {
      final practiceId = row.practiceId;
      if (practiceId != null) {
        _requireReference(
          'sessions',
          row.id,
          'practice',
          practiceId,
          practiceIds,
        );
      }
    }
    for (final row in content.sessionQuestions) {
      _requireReference(
        'sessionQuestions',
        'session ${row.sessionId} / question ${row.questionId}',
        'session',
        row.sessionId,
        sessionIds,
      );
      _requireReference(
        'sessionQuestions',
        'session ${row.sessionId} / question ${row.questionId}',
        'question',
        row.questionId,
        questionIds,
      );
    }
    for (final row in content.attempts) {
      _requireReference(
        'attempts',
        row.id,
        'session',
        row.sessionId,
        sessionIds,
      );
      _requireReference(
        'attempts',
        row.id,
        'question',
        row.questionId,
        questionIds,
      );
    }
    for (final row in content.concepts) {
      final sessionId = row.sessionId;
      final questionId = row.questionId;
      if (sessionId != null) {
        _requireReference('concepts', row.id, 'session', sessionId, sessionIds);
      }
      if (questionId != null) {
        _requireReference(
          'concepts',
          row.id,
          'question',
          questionId,
          questionIds,
        );
      }
    }
    for (final row in content.errorCards) {
      _requireReference(
        'errorCards',
        row.id,
        'question',
        row.questionId,
        questionIds,
      );
      final sessionId = row.sessionId;
      if (sessionId != null) {
        _requireReference(
          'errorCards',
          row.id,
          'session',
          sessionId,
          sessionIds,
        );
      }
    }
    for (final row in content.manualCards) {
      final sessionId = row.sessionId;
      final questionId = row.questionId;
      if (sessionId != null) {
        _requireReference(
          'manualCards',
          row.id,
          'session',
          sessionId,
          sessionIds,
        );
      }
      if (questionId != null) {
        _requireReference(
          'manualCards',
          row.id,
          'question',
          questionId,
          questionIds,
        );
      }
    }
    for (final row in content.skippedQuestions) {
      _requireReference(
        'skippedQuestions',
        row.id,
        'question',
        row.questionId,
        questionIds,
      );
      final sessionId = row.sessionId;
      if (sessionId != null) {
        _requireReference(
          'skippedQuestions',
          row.id,
          'session',
          sessionId,
          sessionIds,
        );
      }
    }
    for (final row in content.highlights) {
      final sessionId = row.sessionId;
      final questionId = row.questionId;
      final manualCardId = row.manualCardId;
      if (sessionId != null) {
        _requireReference(
          'highlights',
          row.id,
          'session',
          sessionId,
          sessionIds,
        );
      }
      if (questionId != null) {
        _requireReference(
          'highlights',
          row.id,
          'question',
          questionId,
          questionIds,
        );
      }
      if (manualCardId != null) {
        _requireReference(
          'highlights',
          row.id,
          'manual card',
          manualCardId,
          manualCardIds,
        );
      }
    }

    final activeCardQuestions = <int>{};
    for (final row in content.errorCards) {
      if (row.status != ErrorCardStatus.active.name) continue;
      if (!activeCardQuestions.add(row.questionId)) {
        throw BackupException(
          'The backup has two active error cards for question '
          '${row.questionId}.',
        );
      }
    }
  }

  void _requireReference(
    String table,
    Object rowId,
    String field,
    int value,
    Set<int> known,
  ) {
    if (!known.contains(value)) {
      throw BackupException(
        'The backup is inconsistent: $table row $rowId refers to missing '
        '$field $value.',
      );
    }
  }

  TopicRow _topic(_Row row) {
    return TopicRow(
      id: row.requireInt('id'),
      name: row.requireString('name'),
      description: row.stringOr('description', ''),
      priority: row.optionalInt('priority'),
      // Older exports used the SQL column spelling, so accept both.
      ankiDeck: row.optionalStringAny(const ['ankiDeck', 'anki_deck', 'deck']),
      createdAt: row.requireDate('createdAt'),
      archived: row.boolOr('archived', false),
    );
  }

  PracticeRow _practice(_Row row) {
    return PracticeRow(
      id: row.requireInt('id'),
      topicId: row.requireInt('topicId'),
      name: row.requireString('name'),
      description: row.stringOr('description', ''),
      contentHash: row.requireString('contentHash'),
      importedAt: row.requireDate('importedAt'),
      isDone: row.boolOr('isDone', false),
    );
  }

  QuestionRow _question(_Row row) {
    return QuestionRow(
      id: row.requireInt('id'),
      practiceId: row.requireInt('practiceId'),
      prompt: row.requireString('prompt'),
      alternativesJson: row.requireJsonList('alternativesJson'),
      correctIndexesJson: row.jsonListOr('correctIndexesJson', '[0]'),
      explanation: row.requireString('explanation'),
      alternativeExplanationsJson: row.jsonListOr(
        'alternativeExplanationsJson',
        '[]',
      ),
      position: row.requireInt('position'),
      subtopic: row.optionalString('subtopic'),
    );
  }

  SessionRow _session(_Row row) {
    return SessionRow(
      id: row.requireInt('id'),
      practiceId: row.optionalInt('practiceId'),
      mode: row.requireEnum('mode', SessionMode.values),
      status: row.requireEnum('status', SessionStatus.values),
      startedAt: row.requireDate('startedAt'),
      finishedAt: row.optionalDate('finishedAt'),
      total: row.requireInt('total'),
      correct: row.intOr('correct', 0),
      skipped: row.intOr('skipped', 0),
      distracted: row.intOr('distracted', 0),
    );
  }

  SessionQuestionRow _sessionQuestion(_Row row) {
    return SessionQuestionRow(
      sessionId: row.requireInt('sessionId'),
      questionId: row.requireInt('questionId'),
      position: row.requireInt('position'),
    );
  }

  AttemptRow _attempt(_Row row) {
    return AttemptRow(
      id: row.requireInt('id'),
      sessionId: row.requireInt('sessionId'),
      questionId: row.requireInt('questionId'),
      selectedIndexesJson: row.jsonListOr('selectedIndexesJson', '[]'),
      reasoning: row.stringOr('reasoning', ''),
      distracted: row.boolOr('distracted', false),
      unknown: row.boolOr('unknown', false),
      isCorrect: row.requireBool('isCorrect'),
      answeredAt: row.requireDate('answeredAt'),
    );
  }

  ConceptRow _concept(_Row row) {
    return ConceptRow(
      id: row.requireInt('id'),
      sessionId: row.optionalInt('sessionId'),
      questionId: row.optionalInt('questionId'),
      term: row.requireString('term'),
      definition: row.stringOr('definition', ''),
      extra: row.stringOr('extra', ''),
      context: row.stringOr('context', ''),
      topicName: row.stringOr('topicName', ''),
      source: row.requireEnum('source', ConceptSource.values),
      createdAt: row.requireDate('createdAt'),
      exportedAt: row.optionalDate('exportedAt'),
    );
  }

  ErrorCardRow _errorCard(_Row row) {
    return ErrorCardRow(
      id: row.requireInt('id'),
      questionId: row.requireInt('questionId'),
      sessionId: row.optionalInt('sessionId'),
      question: row.requireString('question'),
      alternativesJson: row.requireJsonList('alternativesJson'),
      correctIndexesJson: row.jsonListOr('correctIndexesJson', '[0]'),
      wrongIndexesJson: row.jsonListOr('wrongIndexesJson', '[0]'),
      reasoning: row.stringOr('reasoning', ''),
      explanation: row.stringOr('explanation', ''),
      alternativeExplanationsJson: row.jsonListOr(
        'alternativeExplanationsJson',
        '[]',
      ),
      bias: row.stringOr('bias', ''),
      vaccine: row.stringOr('vaccine', ''),
      topicName: row.stringOr('topicName', ''),
      practiceName: row.stringOr('practiceName', ''),
      status: row.requireEnum('status', ErrorCardStatus.values),
      createdAt: row.requireDate('createdAt'),
      lastWrongAt: row.requireDate('lastWrongAt'),
      dueAt: row.requireDate('dueAt'),
      detailsCompletedAt: row.optionalDate('detailsCompletedAt'),
      resolvedAt: row.optionalDate('resolvedAt'),
      exportedAt: row.optionalDate('exportedAt'),
    );
  }

  ManualCardRow _manualCard(_Row row) {
    return ManualCardRow(
      id: row.requireInt('id'),
      sessionId: row.optionalInt('sessionId'),
      questionId: row.optionalInt('questionId'),
      question: row.requireString('question'),
      answer: row.requireString('answer'),
      context: row.stringOr('context', ''),
      topicName: row.stringOr('topicName', ''),
      createdAt: row.requireDate('createdAt'),
      exportedAt: row.optionalDate('exportedAt'),
    );
  }

  SkippedQuestionRow _skippedQuestion(_Row row) {
    return SkippedQuestionRow(
      id: row.requireInt('id'),
      sessionId: row.optionalInt('sessionId'),
      questionId: row.requireInt('questionId'),
      question: row.requireString('question'),
      alternativesJson: row.requireJsonList('alternativesJson'),
      correctIndexesJson: row.jsonListOr('correctIndexesJson', '[0]'),
      explanation: row.stringOr('explanation', ''),
      alternativeExplanationsJson: row.jsonListOr(
        'alternativeExplanationsJson',
        '[]',
      ),
      reasoning: row.stringOr('reasoning', ''),
      topicName: row.stringOr('topicName', ''),
      practiceName: row.stringOr('practiceName', ''),
      unknown: row.boolOr('unknown', false),
      createdAt: row.requireDate('createdAt'),
      handledAt: row.optionalDate('handledAt'),
      handledKind: row.optionalString('handledKind'),
    );
  }

  HighlightRow _highlight(_Row row) {
    return HighlightRow(
      id: row.requireInt('id'),
      sessionId: row.optionalInt('sessionId'),
      questionId: row.optionalInt('questionId'),
      phrase: row.requireString('phrase'),
      context: row.stringOr('context', ''),
      topicName: row.stringOr('topicName', ''),
      practiceName: row.stringOr('practiceName', ''),
      createdAt: row.requireDate('createdAt'),
      keptAt: row.optionalDate('keptAt'),
      cardCreatedAt: row.optionalDate('cardCreatedAt'),
      manualCardId: row.optionalInt('manualCardId'),
    );
  }

  SettingRow _setting(_Row row) {
    return SettingRow(
      key: row.requireString('key'),
      value: row.requireString('value'),
    );
  }

  DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  String? _stringOrNull(Object? value) {
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  String _checksum(Map<String, dynamic> tables) {
    return sha256.convert(utf8.encode(_canonicalJson(tables))).toString();
  }

  String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    return jsonEncode(value);
  }
}

/// A typed row reader that reports field problems with a table and row index.
class _Row {
  const _Row(this._json, this.path);

  final Map<String, dynamic> _json;
  final String path;

  String requireString(String field) {
    final value = _json[field];
    if (value is! String) _fail(field, 'a string');
    return value;
  }

  String stringOr(String field, String fallback) {
    if (!_json.containsKey(field)) return fallback;
    final value = _json[field];
    if (value == null) return fallback;
    if (value is! String) _fail(field, 'a string');
    return value;
  }

  String? optionalString(String field) {
    final value = _json[field];
    if (value == null) return null;
    if (value is! String) _fail(field, 'a string or null');
    return value;
  }

  String? optionalStringAny(List<String> fields) {
    for (final field in fields) {
      if (!_json.containsKey(field)) continue;
      final value = _json[field];
      if (value == null) return null;
      if (value is! String) _fail(field, 'a string or null');
      return value;
    }
    return null;
  }

  int requireInt(String field) {
    final value = _json[field];
    if (value is! int) _fail(field, 'a whole number');
    return value;
  }

  int intOr(String field, int fallback) {
    if (!_json.containsKey(field) || _json[field] == null) return fallback;
    return requireInt(field);
  }

  bool requireBool(String field) {
    final value = _json[field];
    if (value is! bool) _fail(field, 'true or false');
    return value;
  }

  bool boolOr(String field, bool fallback) {
    if (!_json.containsKey(field) || _json[field] == null) return fallback;
    return requireBool(field);
  }

  int? optionalInt(String field) {
    final value = _json[field];
    if (value == null) return null;
    if (value is! int) _fail(field, 'a whole number or null');
    return value;
  }

  String requireJsonList(String field) {
    final value = requireString(field);
    _checkJsonList(field, value);
    return value;
  }

  String jsonListOr(String field, String fallback) {
    if (!_json.containsKey(field) || _json[field] == null) return fallback;
    return requireJsonList(field);
  }

  String requireEnum(String field, Iterable<Enum> values) {
    final value = requireString(field);
    final names = values.map((candidate) => candidate.name).toSet();
    if (!names.contains(value)) {
      _fail(field, 'one of ${names.join(', ')}');
    }
    return value;
  }

  DateTime requireDate(String field) {
    final value = _date(field, _json[field]);
    if (value == null) _fail(field, 'a date');
    return value;
  }

  DateTime? optionalDate(String field) {
    final value = _json[field];
    if (value == null) return null;
    final parsed = _date(field, value);
    if (parsed == null) _fail(field, 'a date or null');
    return parsed;
  }

  void _checkJsonList(String field, String value) {
    dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      _fail(field, 'a JSON array');
    }
    if (decoded is! List) _fail(field, 'a JSON array');
  }

  DateTime? _date(String field, Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  Never _fail(String field, String expected) {
    throw _BadRow('field "$field" must be $expected.');
  }
}

class _BadRow implements Exception {
  const _BadRow(this.message);

  final String message;
}

class _BackupTables {
  const _BackupTables({required this.info, required this.content});

  final BackupInfo info;
  final _BackupContent content;

  List<TopicRow> get topics => content.topics;
  List<PracticeRow> get practices => content.practices;
  List<QuestionRow> get questions => content.questions;
  List<SessionRow> get sessions => content.sessions;
  List<SessionQuestionRow> get sessionQuestions => content.sessionQuestions;
  List<AttemptRow> get attempts => content.attempts;
  List<ConceptRow> get concepts => content.concepts;
  List<ErrorCardRow> get errorCards => content.errorCards;
  List<ManualCardRow> get manualCards => content.manualCards;
  List<SkippedQuestionRow> get skippedQuestions => content.skippedQuestions;
  List<HighlightRow> get highlights => content.highlights;
  List<SettingRow> get settings => content.settings;
}

class _BackupContent {
  const _BackupContent({
    required this.topics,
    required this.practices,
    required this.questions,
    required this.sessions,
    required this.sessionQuestions,
    required this.attempts,
    required this.concepts,
    required this.errorCards,
    required this.manualCards,
    required this.skippedQuestions,
    required this.highlights,
    required this.settings,
  });

  final List<TopicRow> topics;
  final List<PracticeRow> practices;
  final List<QuestionRow> questions;
  final List<SessionRow> sessions;
  final List<SessionQuestionRow> sessionQuestions;
  final List<AttemptRow> attempts;
  final List<ConceptRow> concepts;
  final List<ErrorCardRow> errorCards;
  final List<ManualCardRow> manualCards;
  final List<SkippedQuestionRow> skippedQuestions;
  final List<HighlightRow> highlights;
  final List<SettingRow> settings;
}
