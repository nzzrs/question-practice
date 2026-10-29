import 'package:flutter/services.dart';

class AnkiStatus {
  const AnkiStatus({
    required this.installed,
    required this.apiAvailable,
    required this.permissionGranted,
    required this.deckExists,
    required this.conceptModelAvailable,
    required this.errorModelAvailable,
    required this.basicModelAvailable,
  });

  const AnkiStatus.unavailable()
    : installed = false,
      apiAvailable = false,
      permissionGranted = false,
      deckExists = false,
      conceptModelAvailable = false,
      errorModelAvailable = false,
      basicModelAvailable = false;

  final bool installed;
  final bool apiAvailable;
  final bool permissionGranted;
  final bool deckExists;
  final bool conceptModelAvailable;
  final bool errorModelAvailable;
  final bool basicModelAvailable;

  bool get ready =>
      apiAvailable &&
      permissionGranted &&
      conceptModelAvailable &&
      errorModelAvailable &&
      basicModelAvailable;

  factory AnkiStatus.fromMap(Map<Object?, Object?> map) {
    bool read(String key) => map[key] == true;
    return AnkiStatus(
      installed: read('installed'),
      apiAvailable: read('apiAvailable'),
      permissionGranted: read('permissionGranted'),
      deckExists: read('deckExists'),
      conceptModelAvailable: read('conceptModelAvailable'),
      errorModelAvailable: read('errorModelAvailable'),
      basicModelAvailable: read('basicModelAvailable'),
    );
  }
}

enum AnkiModel { concept, error, basic }

class AnkiNote {
  const AnkiNote({
    required this.model,
    required this.fields,
    required this.deckName,
    this.tags = const [],
  });

  final AnkiModel model;
  final List<String> fields;
  final String deckName;
  final List<String> tags;
}

class AnkiImportResult {
  const AnkiImportResult({
    required this.added,
    required this.failed,
    required this.message,
  });

  final int added;
  final int failed;
  final String message;

  bool get success => failed == 0;
}

abstract class AnkiGateway {
  Future<AnkiStatus> status();

  Future<AnkiStatus> requestPermission();

  Future<AnkiImportResult> importNotes({required List<AnkiNote> notes});

  Future<List<String>> deckNames();

  Future<void> triggerSync();

  Future<bool> openAnkiDroid();
}

class MethodChannelAnkiGateway implements AnkiGateway {
  MethodChannelAnkiGateway([MethodChannel? channel])
    : _channel =
          channel ?? const MethodChannel('link.nzrs.questionpractice/anki');

  final MethodChannel _channel;

  @override
  Future<AnkiStatus> status() async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>('status');
      return map == null
          ? const AnkiStatus.unavailable()
          : AnkiStatus.fromMap(map);
    } on PlatformException {
      return const AnkiStatus.unavailable();
    } on MissingPluginException {
      return const AnkiStatus.unavailable();
    }
  }

  @override
  Future<AnkiStatus> requestPermission() async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>(
        'requestPermission',
      );
      return map == null
          ? const AnkiStatus.unavailable()
          : AnkiStatus.fromMap(map);
    } on PlatformException {
      return const AnkiStatus.unavailable();
    } on MissingPluginException {
      return const AnkiStatus.unavailable();
    }
  }

  @override
  Future<AnkiImportResult> importNotes({required List<AnkiNote> notes}) async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>(
        'importNotes',
        {
          'notes': [
            for (final note in notes)
              {
                'model': note.model.name,
                'fields': note.fields,
                'deckName': note.deckName,
                'tags': note.tags,
              },
          ],
        },
      );
      if (map == null) {
        return const AnkiImportResult(
          added: 0,
          failed: 0,
          message: 'AnkiDroid did not return a result.',
        );
      }
      return AnkiImportResult(
        added: (map['added'] as num?)?.toInt() ?? 0,
        failed: (map['failed'] as num?)?.toInt() ?? 0,
        message: map['message'] as String? ?? '',
      );
    } on PlatformException catch (error) {
      return AnkiImportResult(
        added: 0,
        failed: notes.length,
        message: error.message ?? 'AnkiDroid rejected the import.',
      );
    } on MissingPluginException {
      return AnkiImportResult(
        added: 0,
        failed: notes.length,
        message: 'AnkiDroid integration is not available on this build.',
      );
    }
  }

  @override
  Future<List<String>> deckNames() async {
    try {
      final names = await _channel.invokeMethod<List<Object?>>('deckNames');
      return [
        for (final name in names ?? const <Object?>[])
          if (name is String) name,
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> triggerSync() async {
    try {
      await _channel.invokeMethod<void>('triggerSync');
    } on PlatformException {
      // Sync is best effort; the notes are already saved.
    } on MissingPluginException {
      // Nothing to do on unsupported platforms.
    }
  }

  @override
  Future<bool> openAnkiDroid() async {
    try {
      return await _channel.invokeMethod<bool>('openAnkiDroid') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class FakeAnkiGateway implements AnkiGateway {
  FakeAnkiGateway({
    this.currentStatus = const AnkiStatus(
      installed: true,
      apiAvailable: true,
      permissionGranted: true,
      deckExists: false,
      conceptModelAvailable: true,
      errorModelAvailable: true,
      basicModelAvailable: true,
    ),
    this.importResult = const AnkiImportResult(
      added: 0,
      failed: 0,
      message: 'Fake import',
    ),
    this.permissionStatus,
    this.availableDecks = const ['Question Practice'],
  });

  AnkiStatus currentStatus;
  AnkiStatus? permissionStatus;
  AnkiImportResult importResult;
  List<String> availableDecks;
  final List<AnkiNote> importedNotes = [];
  int syncCount = 0;
  int permissionRequests = 0;

  @override
  Future<AnkiStatus> status() async => currentStatus;

  @override
  Future<AnkiStatus> requestPermission() async {
    permissionRequests++;
    currentStatus = permissionStatus ?? currentStatus;
    return currentStatus;
  }

  @override
  Future<AnkiImportResult> importNotes({required List<AnkiNote> notes}) async {
    importedNotes.addAll(notes);
    final added = importResult.added == 0 && importResult.failed == 0
        ? notes.length
        : importResult.added;
    return AnkiImportResult(
      added: added,
      failed: importResult.failed,
      message: importResult.message,
    );
  }

  @override
  Future<List<String>> deckNames() async => availableDecks;

  @override
  Future<void> triggerSync() async {
    syncCount++;
  }

  @override
  Future<bool> openAnkiDroid() async => true;
}
