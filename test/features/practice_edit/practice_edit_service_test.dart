import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/database/app_database.dart';
import 'package:question_practice/features/import/domain/import_service.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice_edit/domain/practice_edit_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestHarness harness;
  late ImportService importService;
  late PracticeEditService service;
  late Directory directory;

  setUp(() async {
    harness = TestHarness();
    importService = ImportService(
      repository: harness.practices,
      clock: harness.clock,
      bundle: rootBundle,
    );
    directory = await Directory.systemTemp.createTemp('practice-edit-');
    service = PracticeEditService(
      practices: harness.practices,
      importService: importService,
      clock: harness.clock,
      temporaryDirectory: () async => directory,
    );
  });

  tearDown(() async {
    await harness.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  Map<String, dynamic> firstPractice(Map<String, dynamic> payload) {
    final topics = payload['topics'] as List<dynamic>;
    final topic = topics.first as Map<String, dynamic>;
    final practices = topic['practices'] as List<dynamic>;
    return practices.first as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> questionsOf(Map<String, dynamic> payload) {
    return (firstPractice(payload)['questions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> newQuestion({
    String prompt = 'A brand new question?',
    String sourceId = '999999',
  }) {
    return <String, dynamic>{
      'sourceId': sourceId,
      'prompt': prompt,
      'alternatives': const ['Right', 'Wrong'],
      'correctIndex': 0,
      'explanation': 'Right is correct.',
      'alternativeExplanations': const ['Correct.', 'Wrong.'],
    };
  }

  test(
    'export payload contains the topic, practice and stable question ids',
    () async {
      final seeded = await harness.seedPractice(
        topicName: 'Cloud',
        practiceName: 'Core',
        count: 2,
        subtopics: const ['Compute', 'Storage'],
      );
      await harness.database.topicDao.insertQuestions([
        QuestionsCompanion.insert(
          practiceId: seeded.practiceId,
          prompt: 'Pick two services?',
          alternativesJson: jsonEncode(const ['A', 'B', 'C']),
          correctIndexesJson: const drift.Value('[0, 2]'),
          explanation: 'A and C are right.',
          alternativeExplanationsJson: jsonEncode(const [
            'Correct A.',
            'Wrong B.',
            'Correct C.',
          ]),
          position: 2,
          subtopic: const drift.Value('Cloud'),
        ),
      ]);
      final stored = await harness.practices.questionsForPractice(
        seeded.practiceId,
      );

      final payload = await service.buildPracticePayload(seeded.practiceId);
      final topic =
          (payload['topics'] as List<dynamic>).first as Map<String, dynamic>;
      expect(payload['formatVersion'], 1);
      expect(topic['name'], 'Cloud');
      expect(topic['description'], 'Topic description');
      expect(topic['priority'], 1);
      final practice = firstPractice(payload);
      expect(practice['name'], 'Core');
      expect(practice['description'], 'Practice description');
      final questions = questionsOf(payload);
      expect(questions, hasLength(3));
      expect(questions[0]['sourceId'], stored[0].id.toString());
      expect(questions[0]['prompt'], 'Question 1?');
      expect(questions[0]['subtopic'], 'Compute');
      expect(questions[0]['correctIndex'], 0);
      expect(questions[1]['subtopic'], 'Storage');
      expect(questions[2]['correctIndexes'], const [0, 2]);
      expect(questions[2]['sourceId'], stored[2].id.toString());

      final roundTrip = await importService.previewText(
        service.encodePayload(payload),
        fileName: 'exported.json',
      );
      expect(roundTrip.topicCount, 1);
      expect(roundTrip.practiceCount, 1);
      expect(roundTrip.questionCount, 3);
    },
  );

  test('sharePracticeJson writes a file and opens the share action', () async {
    final seeded = await harness.seedPractice(count: 1);
    File? shared;
    final sharing = PracticeEditService(
      practices: harness.practices,
      importService: importService,
      clock: harness.clock,
      temporaryDirectory: () async => directory,
      shareFile: (file) async => shared = file,
    );

    final file = await sharing.sharePracticeJson(seeded.practiceId);

    expect(shared, isNotNull);
    expect(shared!.path, file.path);
    expect(await file.exists(), isTrue);
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(firstPractice(payload)['name'], 'Practice');
  });

  test(
    'diff classifies unchanged, modified, new and deleted questions',
    () async {
      final seeded = await harness.seedPractice(count: 4);
      final stored = await harness.practices.questionsForPractice(
        seeded.practiceId,
      );
      final payload = await service.buildPracticePayload(seeded.practiceId);
      final questions = questionsOf(payload);
      questions[0]['explanation'] = 'A better explanation.';
      questions.removeAt(1);
      questions.add(newQuestion());

      final preview = await service.previewUpdateText(
        jsonEncode(payload),
        fileName: 'edited.json',
        practiceId: seeded.practiceId,
      );

      expect(preview.newCount, 1);
      expect(preview.modifiedCount, 1);
      expect(preview.deletedCount, 1);
      expect(preview.unchangedCount, 2);
      expect(preview.hasChanges, isTrue);
      expect(preview.modifiedQuestions.single.existingQuestionId, stored[0].id);
      expect(preview.deletedQuestions.single.id, stored[1].id);
      expect(
        preview.newQuestions.single.question.prompt,
        'A brand new question?',
      );
      expect(preview.questions.map((item) => item.position), [0, 1, 2, 3]);
    },
  );

  test('files without sourceId fall back to the exact prompt', () async {
    final seeded = await harness.seedPractice(count: 3);
    final stored = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final payload = await service.buildPracticePayload(seeded.practiceId);
    final questions = questionsOf(payload);
    for (final question in questions) {
      question.remove('sourceId');
    }
    questions[0]['explanation'] = 'Changed but the prompt is the same.';

    final preview = await service.previewUpdateText(
      jsonEncode(payload),
      fileName: 'legacy.json',
      practiceId: seeded.practiceId,
    );

    expect(preview.newCount, 0);
    expect(preview.deletedCount, 0);
    expect(preview.modifiedCount, 1);
    expect(preview.unchangedCount, 2);
    expect(preview.modifiedQuestions.single.existingQuestionId, stored[0].id);
  });

  test('sourceId still maps a question when its prompt is reworded', () async {
    final seeded = await harness.seedPractice(count: 1);
    final stored = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final payload = await service.buildPracticePayload(seeded.practiceId);
    questionsOf(payload)[0]['prompt'] = 'Reworded question?';

    final preview = await service.previewUpdateText(
      jsonEncode(payload),
      fileName: 'reworded.json',
      practiceId: seeded.practiceId,
    );

    expect(preview.modifiedCount, 1);
    expect(
      preview.modifiedQuestions.single.existingQuestionId,
      stored.single.id,
    );
  });

  test(
    'a file for another practice is rejected with a clear message',
    () async {
      final seeded = await harness.seedPractice(practiceName: 'Core', count: 1);
      final payload = await service.buildPracticePayload(seeded.practiceId);
      firstPractice(payload)['name'] = 'Something else';

      await expectLater(
        service.previewUpdateText(
          jsonEncode(payload),
          fileName: 'wrong.json',
          practiceId: seeded.practiceId,
        ),
        throwsA(
          isA<PracticeFileException>().having(
            (error) => error.message,
            'message',
            contains('does not contain'),
          ),
        ),
      );
    },
  );

  test('applying an update keeps answers and error cards linked', () async {
    final seeded = await harness.seedPractice(count: 2);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    for (final item in start.items) {
      await sessions.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: item.question.prompt == 'Question 2?'
            ? const [1]
            : const [0],
        reasoning: 'Because.',
        distracted: false,
      );
    }
    final stored = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final beforeAttempts = await harness.database
        .select(harness.database.attempts)
        .get();
    final beforeCards = await harness.database
        .select(harness.database.errorCards)
        .get();
    expect(beforeAttempts, hasLength(2));
    expect(beforeCards, hasLength(1));

    final payload = await service.buildPracticePayload(seeded.practiceId);
    final questions = questionsOf(payload);
    questions[1]['explanation'] = 'The updated explanation.';
    final preview = await service.previewUpdateText(
      jsonEncode(payload),
      fileName: 'updated.json',
      practiceId: seeded.practiceId,
    );
    harness.clock.advance(const Duration(minutes: 5));

    await service.apply(preview);

    final updated = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    expect(updated.map((item) => item.id), stored.map((item) => item.id));
    expect(updated[1].explanation, 'The updated explanation.');
    final afterAttempts = await harness.database
        .select(harness.database.attempts)
        .get();
    final afterCards = await harness.database
        .select(harness.database.errorCards)
        .get();
    expect(
      afterAttempts.map((row) => row.id),
      beforeAttempts.map((row) => row.id),
    );
    expect(afterCards.single.questionId, stored[1].id);
    final practice = await harness.practices.practiceById(seeded.practiceId);
    expect(practice!.importedAt, harness.clock.now().toUtc());
    expect(practice.contentHash, preview.contentHash);
  });

  test('a deleted question and its linked records cascade away', () async {
    final seeded = await harness.seedPractice(count: 2);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    for (final item in start.items) {
      await sessions.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: const [1],
        reasoning: '',
        distracted: false,
      );
    }
    final stored = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final deletedId = stored[1].id;
    final payload = await service.buildPracticePayload(seeded.practiceId);
    questionsOf(payload).removeAt(1);
    final preview = await service.previewUpdateText(
      jsonEncode(payload),
      fileName: 'deleted.json',
      practiceId: seeded.practiceId,
    );

    await service.apply(preview);

    final remaining = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    expect(remaining.single.id, stored[0].id);
    final attempts = await harness.database
        .select(harness.database.attempts)
        .get();
    final cards = await harness.database
        .select(harness.database.errorCards)
        .get();
    expect(attempts.map((row) => row.questionId), [stored[0].id]);
    expect(cards.map((row) => row.questionId), [stored[0].id]);
    expect(attempts.any((row) => row.questionId == deletedId), isFalse);
    expect(cards.any((row) => row.questionId == deletedId), isFalse);
    final sessionQuestions = await harness.database
        .select(harness.database.sessionQuestions)
        .get();
    expect(sessionQuestions.any((row) => row.questionId == deletedId), isFalse);
  });
}
