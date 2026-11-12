import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/list_sort.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/backup/domain/backup_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  test('a v2 backup records metadata and every table', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await _seedAllData(harness);

    final service = _service(harness);
    final payload = _payload(await service.encode());
    final tables = payload['tables'] as Map<String, dynamic>;
    final metadata = payload['metadata'] as Map<String, dynamic>;

    expect(payload['formatVersion'], BackupService.formatVersion);
    expect(BackupService.formatVersion, 2);
    expect(metadata['formatVersion'], 2);
    expect(metadata['appVersion'], BackupService.appVersion);
    expect(metadata['buildNumber'], BackupService.buildNumber);
    expect(metadata['schemaVersion'], harness.database.schemaVersion);
    expect(DateTime.tryParse(metadata['exportedAt'] as String), isNotNull);
    expect(payload['checksum'], _checksum(tables));

    final counts = metadata['tableCounts'] as Map<String, dynamic>;
    expect(counts.keys, containsAll(BackupService.requiredTables));
    expect(counts.keys, containsAll(BackupService.optionalTables));
    for (final entry in counts.entries) {
      expect(
        entry.value,
        (tables[entry.key] as List<dynamic>).length,
        reason: entry.key,
      );
    }
  });

  test('a v2 round trip restores every table and every deck', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedAllData(harness);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).first;
    final inProgress = await harness.sessions.startSession(
      practiceId: seeded.practiceId,
      mode: SessionMode.mixed,
      questions: [question],
      startedAt: harness.clock.now().toUtc(),
    );

    final service = _service(harness);
    final encoded = await service.encode();
    expect(encoded, isNot(contains('super-secret-key')));

    await harness.database.clearAll();
    expect(await harness.practices.allTopics(), isEmpty);
    expect(await harness.practices.allQuestions(), isEmpty);

    final info = await service.restoreText(encoded);
    expect(info.formatVersion, 2);
    expect(info.topics, 2);
    expect(info.practices, 2);
    expect(info.questions, 5);
    expect(info.sessions, 2);
    expect(info.attempts, 1);
    expect(info.concepts, 1);
    expect(info.errorCards, 1);
    expect(info.manualCards, 1);
    expect(info.skippedQuestions, 1);
    expect(info.highlights, 1);
    expect(info.archivedTopics, 1);

    final topics = await harness.practices.allTopics();
    final cloud = topics.firstWhere((topic) => topic.name == 'Cloud');
    final archived = topics.firstWhere((topic) => topic.name == 'Archived');
    expect(cloud.ankiDeck, 'Cloud deck');
    expect(archived.ankiDeck, 'Archived deck');
    expect(archived.archived, isTrue);

    final practice = (await harness.practices.allPractices()).firstWhere(
      (row) => row.name == 'Core',
    );
    final questions = await harness.practices.questionsForPractice(practice.id);
    expect(
      questions.map((row) => row.subtopic),
      unorderedEquals(['Containers', 'Storage', 'Containers', 'Storage']),
    );

    final completed = await harness.sessions.sessionById(inProgress.id);
    expect(completed!.status, SessionStatus.inProgress);
    expect(
      await harness.sessions.questionsForSession(inProgress.id),
      hasLength(1),
    );
    final attempts = await harness.database
        .select(harness.database.attempts)
        .get();
    expect(attempts.single.reasoning, 'I misread the prompt.');

    final concepts = await harness.database
        .select(harness.database.concepts)
        .get();
    expect(concepts.single.definition, 'A container for objects.');
    final errors = await harness.database
        .select(harness.database.errorCards)
        .get();
    expect(errors.single.question, question.prompt);
    final manuals = await harness.database
        .select(harness.database.manualCards)
        .get();
    expect(manuals.single.answer, 'A container for objects.');
    final skipped = await harness.database
        .select(harness.database.skippedQuestions)
        .get();
    expect(skipped.single.reasoning, 'Skipped this one.');
    final highlights = await harness.database
        .select(harness.database.highlights)
        .get();
    expect(highlights.single.phrase, 'object storage');
    expect(highlights.single.context, 'Cloud storage');

    final settings = await harness.settings.load();
    expect(settings.ankiDeck, 'Saved deck');
    expect(settings.soundsEnabled, isFalse);
    expect(settings.soundVolume, closeTo(0.35, 0.0001));
    expect(settings.lookupMode, LookupMode.ai);
    // The AI key lives in secure storage, outside the database and the backup.
    expect(await harness.settings.hasApiKey(), isTrue);
  });

  test('a v1 backup still restores its topic deck', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 2,
      ankiDeck: 'Cloud deck',
      subtopics: const ['Containers', 'Storage'],
    );

    final service = _service(harness);
    final payload = _asV1(_payload(await service.encode()));
    final topics = payload['tables'] as Map<String, dynamic>;
    for (final item in topics['topics'] as List<dynamic>) {
      final topic = item as Map<String, dynamic>;
      topic.remove('archived');
      topic.remove('subtopic');
    }
    for (final item in topics['questions'] as List<dynamic>) {
      (item as Map<String, dynamic>).remove('subtopic');
    }
    _resign(payload);

    await harness.database.clearAll();
    final info = await service.restoreText(jsonEncode(payload));

    expect(info.formatVersion, 1);
    expect(info.appVersion, isNull);
    final topic = (await harness.practices.allTopics()).single;
    expect(topic.ankiDeck, 'Cloud deck');
    expect(topic.archived, isFalse);
    final practice = (await harness.practices.allPractices()).single;
    final questions = await harness.practices.questionsForPractice(practice.id);
    expect(questions.map((row) => row.subtopic), ['', '']);
  });

  test('an older v1 backup with SQL column names restores the deck', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud', ankiDeck: 'Legacy deck');

    final service = _service(harness);
    final payload = _asV1(_payload(await service.encode()));
    final tables = payload['tables'] as Map<String, dynamic>;
    final topic =
        (tables['topics'] as List<dynamic>).single as Map<String, dynamic>;
    final deck = topic.remove('ankiDeck');
    topic['anki_deck'] = deck;
    _resign(payload);

    await harness.database.clearAll();
    await service.restoreText(jsonEncode(payload));

    expect(
      (await harness.practices.allTopics()).single.ankiDeck,
      'Legacy deck',
    );
  });

  test('unknown future tables are ignored', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud', ankiDeck: 'Cloud deck');

    final service = _service(harness);
    final payload = _payload(await service.encode());
    final tables = payload['tables'] as Map<String, dynamic>;
    tables['futureNotes'] = [
      {'id': 1, 'text': 'from a newer app'},
    ];
    _resign(payload);

    await harness.database.clearAll();
    await service.restoreText(jsonEncode(payload));
    expect((await harness.practices.allTopics()).single.ankiDeck, 'Cloud deck');
  });

  test('missing optional tables still restore', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud');

    final service = _service(harness);
    final payload = _payload(await service.encode());
    final tables = payload['tables'] as Map<String, dynamic>;
    tables.remove('skippedQuestions');
    tables.remove('highlights');
    _resign(payload);

    await service.restoreText(jsonEncode(payload));
    expect(await harness.practices.allTopics(), hasLength(1));
  });

  test('a corrupt checksum is rejected without touching local data', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud');

    final service = _service(harness);
    final payload = _payload(await service.encode());
    final tables = payload['tables'] as Map<String, dynamic>;
    ((tables['topics'] as List<dynamic>).single
            as Map<String, dynamic>)['name'] =
        'Tampered';

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('damaged'),
        ),
      ),
    );
    expect((await harness.practices.allTopics()).single.name, 'Cloud');
  });

  test('a backup without a checksum is rejected', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final service = _service(harness);
    final payload = _payload(await service.encode());
    payload.remove('checksum');

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('checksum'),
        ),
      ),
    );
  });

  test('invalid JSON, empty text and invalid UTF-8 are rejected', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final service = _service(harness);

    await expectLater(
      service.restoreText('{"app": '),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('not valid JSON'),
        ),
      ),
    );
    await expectLater(
      service.restoreText('   '),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('empty'),
        ),
      ),
    );
    await expectLater(
      service.restoreBytes(Uint8List.fromList([0xff, 0xfe, 0xfd])),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('UTF-8'),
        ),
      ),
    );
  });

  test('unsupported format versions are rejected by name', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final service = _service(harness);
    final payload = _payload(await service.encode());

    final future = Map<String, dynamic>.from(payload)
      ..['formatVersion'] = 99
      ..['metadata'] = <String, dynamic>{'formatVersion': 99};
    await expectLater(
      service.restoreText(jsonEncode(future)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          allOf(contains('format version 99'), contains('supports up to 2')),
        ),
      ),
    );

    payload['formatVersion'] = 0;
    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('unsupported format version 0'),
        ),
      ),
    );

    payload.remove('formatVersion');
    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('no format version'),
        ),
      ),
    );
  });

  test('a newer database schema is rejected', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final service = _service(harness);
    final payload = _payload(await service.encode());
    final metadata = payload['metadata'] as Map<String, dynamic>;
    metadata['schemaVersion'] = harness.database.schemaVersion + 1;

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('Update the app'),
        ),
      ),
    );
  });

  test('a missing required table is named in the error', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final service = _service(harness);
    final payload = _payload(await service.encode());
    final tables = payload['tables'] as Map<String, dynamic>;
    final removed = Map<String, dynamic>.from(tables)..remove('practices');
    payload['tables'] = removed;
    _resign(payload);

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('"practices"'),
        ),
      ),
    );
  });

  test('malformed rows are reported with their table and position', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud');
    final service = _service(harness);
    final payload = _payload(await service.encode());
    final tables = payload['tables'] as Map<String, dynamic>;
    ((tables['topics'] as List<dynamic>).single
            as Map<String, dynamic>)['name'] =
        42;
    _resign(payload);

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          allOf(contains('"topics"'), contains('entry 1'), contains('"name"')),
        ),
      ),
    );
  });

  test('duplicate primary keys are rejected', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud');
    final service = _service(harness);
    final payload = _payload(await service.encode());
    final tables = payload['tables'] as Map<String, dynamic>;
    final topics = tables['topics'] as List<dynamic>;
    topics.add(Map<String, dynamic>.from(topics.single as Map));
    _resign(payload);

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          allOf(contains('"topics"'), contains('duplicate id 1')),
        ),
      ),
    );
  });

  test('orphan references are rejected before any write', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud');
    final service = _service(harness);
    final payload = _payload(await service.encode());
    final tables = payload['tables'] as Map<String, dynamic>;
    ((tables['practices'] as List<dynamic>).single
            as Map<String, dynamic>)['topicId'] =
        999;
    _resign(payload);

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          allOf(contains('practices row 1'), contains('missing topic 999')),
        ),
      ),
    );
    expect((await harness.practices.allTopics()).single.name, 'Cloud');
  });

  test('duplicate active error cards are rejected', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await _seedAllData(harness);
    final service = _service(harness);
    final payload = _payload(await service.encode());
    final tables = payload['tables'] as Map<String, dynamic>;
    final cards = tables['errorCards'] as List<dynamic>;
    final duplicate = Map<String, dynamic>.from(cards.last as Map)..['id'] = 99;
    cards.add(duplicate);
    final metadata = payload['metadata'] as Map<String, dynamic>;
    final counts = metadata['tableCounts'] as Map<String, dynamic>;
    counts['errorCards'] = cards.length;
    _resign(payload);

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('two active error cards'),
        ),
      ),
    );
  });

  test('metadata row counts are verified', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud');
    final service = _service(harness);
    final payload = _payload(await service.encode());
    final metadata = payload['metadata'] as Map<String, dynamic>;
    (metadata['tableCounts'] as Map<String, dynamic>)['topics'] = 5;

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('metadata says "topics" has 5 rows'),
        ),
      ),
    );
  });

  test('a failure inside the transaction rolls everything back', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Original', practiceName: 'Keep me');
    await harness.settings.save(const AppSettings(ankiDeck: 'Original deck'));

    final service = _service(harness);
    final source = await harness.seedPractice(
      topicName: 'Explode',
      practiceName: 'Explode',
    );
    final encoded = await service.encode();
    await harness.practices.deleteTopic(source.topicId);

    await harness.database.customStatement('''
      CREATE TRIGGER fail_practice_insert
      BEFORE INSERT ON practices
      WHEN NEW.name = 'Explode'
      BEGIN
        SELECT RAISE(ABORT, 'forced failure');
      END;
    ''');

    await expectLater(
      service.restoreText(encoded),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('could not be applied'),
        ),
      ),
    );

    final topics = await harness.practices.allTopics();
    expect(topics.map((topic) => topic.name), ['Original']);
    expect((await harness.practices.allPractices()).single.name, 'Keep me');
    expect((await harness.settings.load()).ankiDeck, 'Original deck');
  });
}

BackupService _service(TestHarness harness) {
  return BackupService(database: harness.database, clock: harness.clock);
}

Map<String, dynamic> _payload(String encoded) {
  return jsonDecode(encoded) as Map<String, dynamic>;
}

Map<String, dynamic> _asV1(Map<String, dynamic> payload) {
  final copy = Map<String, dynamic>.from(payload)
    ..['formatVersion'] = 1
    ..remove('metadata');
  return copy;
}

void _resign(Map<String, dynamic> payload) {
  payload['checksum'] = _checksum(payload['tables'] as Map<String, dynamic>);
}

/// Seeds two topics, one practice with four questions, a completed session, all
/// card kinds and the app settings.
Future<SeededPractice> _seedAllData(TestHarness harness) async {
  final seeded = await harness.seedPractice(
    topicName: 'Cloud',
    practiceName: 'Core',
    count: 4,
    ankiDeck: 'Cloud deck',
    subtopics: const ['Containers', 'Storage', 'Containers', 'Storage'],
  );
  final archived = await harness.seedPractice(
    topicName: 'Archived',
    practiceName: 'Old',
    count: 1,
    ankiDeck: 'Archived deck',
  );
  await harness.practices.setTopicArchived(archived.topicId, true);

  final questions = await harness.practices.questionsForPractice(
    seeded.practiceId,
  );
  final session = await harness.sessions.startSession(
    practiceId: seeded.practiceId,
    mode: SessionMode.practice,
    questions: questions,
    startedAt: harness.clock.now().toUtc(),
  );
  await harness.sessions.recordAttempt(
    sessionId: session.id,
    questionId: questions.first.id,
    selectedIndexes: const [1],
    reasoning: 'I misread the prompt.',
    distracted: false,
    isCorrect: false,
    answeredAt: harness.clock.now().toUtc(),
  );
  await harness.sessions.completeSession(
    id: session.id,
    total: questions.length,
    correct: 0,
    skipped: 0,
    distracted: 0,
    finishedAt: harness.clock.now().toUtc(),
  );
  await harness.cards.createConcept(
    sessionId: session.id,
    questionId: questions.first.id,
    term: 'Bucket',
    definition: 'A container for objects.',
    context: 'Cloud storage',
    topicName: 'Cloud',
    source: ConceptSource.ai,
    createdAt: harness.clock.now().toUtc(),
  );
  await harness.cards.createErrorCard(
    questionId: questions.first.id,
    sessionId: session.id,
    question: questions.first.prompt,
    alternatives: questions.first.alternatives,
    correctIndexes: questions.first.correctIndexes,
    wrongIndexes: const [1],
    reasoning: 'I misread the prompt.',
    explanation: questions.first.explanation,
    alternativeExplanations: questions.first.alternativeExplanations,
    topicName: 'Cloud',
    practiceName: 'Core',
    lastWrongAt: harness.clock.now().toUtc(),
    dueAfter: const Duration(hours: 48),
  );
  await harness.cards.createManualCard(
    sessionId: session.id,
    question: 'What is a bucket?',
    answer: 'A container for objects.',
    topicName: 'Cloud',
    createdAt: harness.clock.now().toUtc(),
  );
  await harness.cards.saveSkippedQuestion(
    sessionId: session.id,
    questionId: questions.last.id,
    question: questions.last.prompt,
    alternatives: questions.last.alternatives,
    correctIndexes: questions.last.correctIndexes,
    explanation: questions.last.explanation,
    alternativeExplanations: questions.last.alternativeExplanations,
    reasoning: 'Skipped this one.',
    topicName: 'Cloud',
    practiceName: 'Core',
    unknown: false,
    createdAt: harness.clock.now().toUtc(),
  );
  await harness.cards.createHighlight(
    sessionId: session.id,
    questionId: questions.first.id,
    text: 'object storage',
    context: 'Cloud storage',
    topicName: 'Cloud',
    practiceName: 'Core',
    createdAt: harness.clock.now().toUtc(),
  );
  await harness.settings.save(
    const AppSettings(
      ankiDeck: 'Saved deck',
      soundsEnabled: false,
      soundVolume: 0.35,
      lookupMode: LookupMode.ai,
    ),
  );
  await harness.settings.saveApiKey('super-secret-key');
  await harness.settings.saveHomeTopicSort(ListSort.defaultByName);
  await harness.settings.saveTopicPracticeSort(
    seeded.topicId,
    ListSort.defaultByName,
  );
  return seeded;
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
