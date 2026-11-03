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

/// Raised when a backup file cannot be read or applied.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Counts and export time read from a valid backup file.
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

  String get description =>
      '$topics topics, $practices practices, $questions questions, '
      '${sessions + attempts} session records and '
      '${concepts + errorCards + manualCards} cards';
}

class BackupService {
  BackupService({required AppDatabase database, required Clock clock})
    : _db = database,
      _clock = clock;

  static const formatVersion = 1;
  static const appId = 'question_practice';
  static const maxImportBytes = 50 * 1024 * 1024;

  final AppDatabase _db;
  final Clock _clock;

  /// Serializes every local table into a versioned JSON document.
  ///
  /// The AI API key lives in Android secure storage and is deliberately not
  /// part of the database, so it never appears in a backup.
  Future<String> encode() async {
    final topics = await _db.select(_db.topics).get();
    final practices = await _db.select(_db.practices).get();
    final questions = await _db.select(_db.questions).get();
    final sessions = await _db.select(_db.sessions).get();
    final sessionQuestions = await _db.select(_db.sessionQuestions).get();
    final attempts = await _db.select(_db.attempts).get();
    final concepts = await _db.select(_db.concepts).get();
    final errorCards = await _db.select(_db.errorCards).get();
    final manualCards = await _db.select(_db.manualCards).get();
    final settings = await _db.select(_db.settings).get();

    final tables = <String, dynamic>{
      'topics': [for (final row in topics) row.toJson()],
      'practices': [for (final row in practices) row.toJson()],
      'questions': [for (final row in questions) row.toJson()],
      'sessions': [for (final row in sessions) row.toJson()],
      'sessionQuestions': [for (final row in sessionQuestions) row.toJson()],
      'attempts': [for (final row in attempts) row.toJson()],
      'concepts': [for (final row in concepts) row.toJson()],
      'errorCards': [for (final row in errorCards) row.toJson()],
      'manualCards': [for (final row in manualCards) row.toJson()],
      'settings': [for (final row in settings) row.toJson()],
    };
    final payload = <String, dynamic>{
      'app': appId,
      'formatVersion': formatVersion,
      'exportedAt': _clock.now().toUtc().toIso8601String(),
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
  /// Parsing happens before the transaction, and the write itself is atomic,
  /// so an invalid backup leaves the current data untouched.
  Future<BackupInfo> restoreText(String text) async {
    final backup = _parse(text);
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
        batch.insertAll(_db.settings, [
          for (final row in backup.settings) row.toCompanion(false),
        ]);
      });
    });
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
    if (payload['formatVersion'] != formatVersion) {
      throw const BackupException(
        'This backup was made by an unsupported app version.',
      );
    }
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

    final info = BackupInfo(
      exportedAt: _date(payload['exportedAt']),
      topics: _length(tables, 'topics'),
      practices: _length(tables, 'practices'),
      questions: _length(tables, 'questions'),
      sessions: _length(tables, 'sessions'),
      attempts: _length(tables, 'attempts'),
      concepts: _length(tables, 'concepts'),
      errorCards: _length(tables, 'errorCards'),
      manualCards: _length(tables, 'manualCards'),
    );
    return _BackupTables(
      info: info,
      topics: _rows(tables, 'topics', (json) => TopicRow.fromJson(json)),
      practices: _rows(
        tables,
        'practices',
        (json) => PracticeRow.fromJson(json),
      ),
      questions: _rows(
        tables,
        'questions',
        (json) => QuestionRow.fromJson(json),
      ),
      sessions: _rows(tables, 'sessions', (json) => SessionRow.fromJson(json)),
      sessionQuestions: _rows(
        tables,
        'sessionQuestions',
        (json) => SessionQuestionRow.fromJson(json),
      ),
      attempts: _rows(tables, 'attempts', (json) => AttemptRow.fromJson(json)),
      concepts: _rows(tables, 'concepts', (json) => ConceptRow.fromJson(json)),
      errorCards: _rows(
        tables,
        'errorCards',
        (json) => ErrorCardRow.fromJson(json),
      ),
      manualCards: _rows(
        tables,
        'manualCards',
        (json) => ManualCardRow.fromJson(json),
      ),
      settings: _rows(tables, 'settings', (json) => SettingRow.fromJson(json)),
    );
  }

  List<T> _rows<T>(
    Map<String, dynamic> tables,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) {
    final raw = tables[key];
    if (raw is! List) {
      throw BackupException('The backup is missing the "$key" table.');
    }
    final rows = <T>[];
    for (final item in raw) {
      if (item is! Map) {
        throw BackupException('The "$key" table has an invalid entry.');
      }
      try {
        rows.add(parse(item.cast<String, dynamic>()));
      } on Object {
        throw BackupException('The "$key" table has an unreadable entry.');
      }
    }
    return rows;
  }

  int _length(Map<String, dynamic> tables, String key) {
    final raw = tables[key];
    return raw is List ? raw.length : 0;
  }

  DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
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

class _BackupTables {
  const _BackupTables({
    required this.info,
    required this.topics,
    required this.practices,
    required this.questions,
    required this.sessions,
    required this.sessionQuestions,
    required this.attempts,
    required this.concepts,
    required this.errorCards,
    required this.manualCards,
    required this.settings,
  });

  final BackupInfo info;
  final List<TopicRow> topics;
  final List<PracticeRow> practices;
  final List<QuestionRow> questions;
  final List<SessionRow> sessions;
  final List<SessionQuestionRow> sessionQuestions;
  final List<AttemptRow> attempts;
  final List<ConceptRow> concepts;
  final List<ErrorCardRow> errorCards;
  final List<ManualCardRow> manualCards;
  final List<SettingRow> settings;
}
