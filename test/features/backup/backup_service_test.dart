import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/backup/domain/backup_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  test('a backup round trip restores every local table', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 2,
      ankiDeck: 'Cloud deck',
      subtopics: const ['Containers', 'Storage'],
    );
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
    await harness.settings.save(
      const AppSettings(ankiDeck: 'Saved deck', soundsEnabled: false),
    );
    await harness.settings.saveApiKey('super-secret-key');

    final service = BackupService(
      database: harness.database,
      clock: harness.clock,
    );
    final encoded = await service.encode();
    expect(encoded, isNot(contains('super-secret-key')));
    final payload = jsonDecode(encoded) as Map<String, dynamic>;
    expect(payload['formatVersion'], BackupService.formatVersion);
    expect(payload['checksum'], isA<String>());

    await harness.database.clearAll();
    expect(await harness.practices.allTopics(), isEmpty);
    expect(await harness.practices.allQuestions(), isEmpty);

    final info = await service.restoreText(encoded);
    expect(info.topics, 1);
    expect(info.practices, 1);
    expect(info.questions, 2);
    expect(info.sessions, 1);
    expect(info.attempts, 1);
    expect(info.concepts, 1);
    expect(info.errorCards, 1);
    expect(info.manualCards, 1);

    final topics = await harness.practices.allTopics();
    expect(topics.single.name, 'Cloud');
    expect(topics.single.ankiDeck, 'Cloud deck');
    final practices = await harness.practices.allPractices();
    expect(practices.single.name, 'Core');
    final restoredQuestions = await harness.practices.questionsForPractice(
      practices.single.id,
    );
    expect(
      restoredQuestions.map((question) => question.prompt),
      unorderedEquals(questions.map((question) => question.prompt)),
    );
    expect(
      restoredQuestions.map((question) => question.subtopic),
      unorderedEquals(['Containers', 'Storage']),
    );
    final attempts = await harness.sessions.attemptsForSession(session.id);
    expect(attempts.single.reasoning, 'I misread the prompt.');
    final concepts = await harness.cards.conceptsForSession(session.id);
    expect(concepts.single.definition, 'A container for objects.');
    final errors = await harness.database
        .select(harness.database.errorCards)
        .get();
    expect(errors.single.question, questions.first.prompt);
    final manuals = await harness.database
        .select(harness.database.manualCards)
        .get();
    expect(manuals.single.answer, 'A container for objects.');
    final settings = await harness.settings.load();
    expect(settings.ankiDeck, 'Saved deck');
    expect(settings.soundsEnabled, isFalse);
  });

  test('an older backup without subtopics restores as uncategorized', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 2,
      subtopics: const ['Containers', 'Storage'],
    );
    final service = BackupService(
      database: harness.database,
      clock: harness.clock,
    );
    final payload = jsonDecode(await service.encode()) as Map<String, dynamic>;
    final tables = payload['tables'] as Map<String, dynamic>;
    for (final item in tables['questions'] as List<dynamic>) {
      (item as Map<String, dynamic>).remove('subtopic');
    }
    payload['checksum'] = _checksum(tables);

    await service.restoreText(jsonEncode(payload));

    final practice = (await harness.practices.allPractices()).single;
    final questions = await harness.practices.questionsForPractice(practice.id);
    expect(questions.map((question) => question.subtopic), ['', '']);
  });

  test('a damaged backup is rejected without touching local data', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud', practiceName: 'Core');

    final service = BackupService(
      database: harness.database,
      clock: harness.clock,
    );
    final encoded = await service.encode();
    final payload = jsonDecode(encoded) as Map<String, dynamic>;
    final tables = payload['tables'] as Map<String, dynamic>;
    final topics = tables['topics'] as List<dynamic>;
    (topics.single as Map<String, dynamic>)['name'] = 'Tampered';
    payload.remove('checksum');

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(isA<BackupException>()),
    );
    final topicsAfter = await harness.practices.allTopics();
    expect(topicsAfter.single.name, 'Cloud');
  });

  test('a backup without a checksum is rejected', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final service = BackupService(
      database: harness.database,
      clock: harness.clock,
    );
    final payload = jsonDecode(await service.encode()) as Map<String, dynamic>;
    payload.remove('checksum');

    await expectLater(
      service.restoreText(jsonEncode(payload)),
      throwsA(isA<BackupException>()),
    );
  });
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
