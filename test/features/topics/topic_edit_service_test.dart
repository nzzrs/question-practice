import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/import/domain/import_service.dart';
import 'package:question_practice/features/topics/domain/topic_edit_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestHarness harness;
  late ImportService importService;
  late TopicEditService service;
  late Directory directory;

  setUp(() async {
    harness = TestHarness();
    importService = ImportService(
      repository: harness.practices,
      clock: harness.clock,
      bundle: rootBundle,
    );
    directory = await Directory.systemTemp.createTemp('topic-edit-');
    service = TopicEditService(
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

  Map<String, dynamic> topicOf(Map<String, dynamic> payload) {
    return (payload['topics'] as List<dynamic>).first as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> practicesOf(Map<String, dynamic> payload) {
    return (topicOf(payload)['practices'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> questionsOf(Map<String, dynamic> practice) {
    return (practice['questions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> newQuestion({String prompt = 'A new question?'}) {
    return <String, dynamic>{
      'sourceId': '999999',
      'prompt': prompt,
      'alternatives': const ['Right', 'Wrong'],
      'correctIndex': 0,
      'explanation': 'Right is correct.',
      'alternativeExplanations': const ['Correct.', 'Wrong.'],
    };
  }

  Future<Practice> addPractice(
    int topicId, {
    required String name,
    int count = 1,
    String description = 'Extra description',
  }) async {
    final practiceId = await harness.practices.createPractice(
      topicId: topicId,
      name: name,
      description: description,
      contentHash: 'hash-$name-$count',
      importedAt: harness.clock.now().toUtc(),
    );
    await harness.practices.createQuestions(practiceId, [
      for (var index = 0; index < count; index++)
        QuestionDraft(
          prompt: '$name question ${index + 1}?',
          alternatives: const ['Right', 'Wrong'],
          correctIndexes: const [0],
          explanation: 'Right is correct.',
          alternativeExplanations: const ['Correct.', 'Wrong.'],
        ),
    ]);
    return (await harness.practices.practiceById(practiceId))!;
  }

  test('payload contains the topic scores and every practice', () async {
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 2,
      subtopics: const ['Compute', 'Storage'],
    );
    await harness.practices.updateTopic(
      id: seeded.topicId,
      name: 'Cloud',
      description: 'Core services',
      priority: 2,
      minimumScore: 55,
      targetScore: 85,
    );
    await addPractice(seeded.topicId, name: 'Extra', description: 'More');

    final payload = await service.buildTopicPayload(seeded.topicId);
    final topic = topicOf(payload);
    expect(payload['formatVersion'], 1);
    expect(topic['name'], 'Cloud');
    expect(topic['description'], 'Core services');
    expect(topic['priority'], 2);
    expect(topic['minimumScore'], 55);
    expect(topic['targetScore'], 85);

    final practices = practicesOf(payload);
    expect(practices.map((practice) => practice['name']), ['Core', 'Extra']);
    expect(practices[0]['description'], 'Practice description');
    final coreQuestions = questionsOf(practices[0]);
    final stored = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    expect(coreQuestions, hasLength(2));
    expect(coreQuestions[0]['sourceId'], stored[0].id.toString());
    expect(coreQuestions[0]['subtopic'], 'Compute');
    expect(coreQuestions[0]['correctIndex'], 0);

    final roundTrip = await importService.previewText(
      service.encodePayload(payload),
      fileName: 'topic.json',
    );
    expect(roundTrip.topicCount, 1);
    expect(roundTrip.practiceCount, 2);
    expect(roundTrip.questionCount, 3);
    expect(roundTrip.topics.single.minimumScore, 55);
    expect(roundTrip.topics.single.targetScore, 85);
  });

  test('shareTopicJson writes a file and opens the share action', () async {
    final seeded = await harness.seedPractice(count: 1);
    File? shared;
    final sharing = TopicEditService(
      practices: harness.practices,
      importService: importService,
      clock: harness.clock,
      temporaryDirectory: () async => directory,
      shareFile: (file) async => shared = file,
    );

    final file = await sharing.shareTopicJson(seeded.topicId);

    expect(shared, isNotNull);
    expect(shared!.path, file.path);
    expect(await file.exists(), isTrue);
    expect(file.path, contains('question-practice-topic-'));
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(topicOf(payload)['name'], 'Topic');
  });

  test(
    'preview adds, modifies and deletes questions and creates practices',
    () async {
      final seeded = await harness.seedPractice(
        topicName: 'Cloud',
        practiceName: 'Core',
        count: 4,
      );
      await addPractice(seeded.topicId, name: 'Extra');
      final kept = await addPractice(seeded.topicId, name: 'Kept');
      final stored = await harness.practices.questionsForPractice(
        seeded.practiceId,
      );

      final payload = await service.buildTopicPayload(seeded.topicId);
      final practices = practicesOf(payload);
      // Kept stays in the database but is omitted from the file on purpose.
      practices.removeWhere((practice) => practice['name'] == 'Kept');
      final core = practices.first;
      final questions = questionsOf(core);
      questions[0]['explanation'] = 'A better explanation.';
      questions.removeAt(1);
      questions.add(newQuestion());
      practices.add(<String, dynamic>{
        'name': 'Brand new',
        'description': 'Created from the file',
        'questions': [newQuestion(prompt: 'New practice question?')],
      });

      final preview = await service.previewUpdateText(
        jsonEncode(payload),
        fileName: 'edited.json',
        topicId: seeded.topicId,
      );

      expect(preview.newPracticeCount, 1);
      expect(preview.modifiedPracticeCount, 1);
      expect(preview.unchangedPracticeCount, 1);
      expect(preview.newQuestionCount, 2);
      expect(preview.modifiedQuestionCount, 1);
      expect(preview.deletedQuestionCount, 1);
      expect(preview.hasChanges, isTrue);
      expect(preview.hasMetadataChanges, isFalse);

      final corePreview = preview.practices.first;
      expect(corePreview.practiceId, seeded.practiceId);
      expect(
        corePreview.modifiedQuestions.single.existingQuestionId,
        stored[0].id,
      );
      expect(corePreview.deletedQuestions.single.id, stored[1].id);

      harness.clock.advance(const Duration(minutes: 5));
      await service.apply(preview);

      final updated = await harness.practices.questionsForPractice(
        seeded.practiceId,
      );
      expect(updated, hasLength(4));
      expect(updated[0].id, stored[0].id);
      expect(updated[0].explanation, 'A better explanation.');
      expect(
        updated.any((question) => question.prompt == 'A new question?'),
        isTrue,
      );
      expect(updated.any((question) => question.id == stored[1].id), isFalse);

      final updatedPractices = await harness.practices.practicesForTopic(
        seeded.topicId,
      );
      expect(
        updatedPractices.map((practice) => practice.name),
        containsAll(<String>['Core', 'Extra', 'Kept', 'Brand new']),
      );
      expect(
        updatedPractices.any((practice) => practice.name == 'Brand new'),
        isTrue,
      );
      final keptQuestions = await harness.practices.questionsForPractice(
        kept.id,
      );
      expect(keptQuestions, hasLength(1));
      expect(keptQuestions.single.prompt, 'Kept question 1?');
    },
  );

  test('updates topic metadata when the file names it', () async {
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    final payload = await service.buildTopicPayload(seeded.topicId);
    final topic = topicOf(payload);
    topic['description'] = 'Updated description';
    topic['priority'] = 4;
    topic['minimumScore'] = 60;
    topic['targetScore'] = 95;

    final preview = await service.previewUpdateText(
      jsonEncode(payload),
      fileName: 'metadata.json',
      topicId: seeded.topicId,
    );

    expect(preview.hasMetadataChanges, isTrue);
    expect(preview.description, 'Updated description');
    expect(preview.priority, 4);
    expect(preview.minimumScore, 60);
    expect(preview.targetScore, 95);

    await service.apply(preview);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Updated description');
    expect(stored.priority, 4);
    expect(stored.minimumScore, 60);
    expect(stored.targetScore, 95);
  });

  test('omitted metadata keeps the stored topic values', () async {
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    await harness.practices.updateTopic(
      id: seeded.topicId,
      name: 'Cloud',
      description: 'Stored description',
      priority: 3,
      minimumScore: 50,
      targetScore: 90,
    );
    final payload = await service.buildTopicPayload(seeded.topicId);
    final topic = topicOf(payload);
    topic.remove('description');
    topic.remove('priority');
    topic.remove('minimumScore');
    topic.remove('targetScore');

    final preview = await service.previewUpdateText(
      jsonEncode(payload),
      fileName: 'bare.json',
      topicId: seeded.topicId,
    );
    expect(preview.hasMetadataChanges, isFalse);
    expect(preview.description, isNull);
    expect(preview.updatePriority, isFalse);
    expect(preview.minimumScore, isNull);
    expect(preview.targetScore, isNull);

    await service.apply(preview);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Stored description');
    expect(stored.priority, 3);
    expect(stored.minimumScore, 50);
    expect(stored.targetScore, 90);
  });

  test('rejects a file without the topic name', () async {
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    final payload = await service.buildTopicPayload(seeded.topicId);
    topicOf(payload)['name'] = 'Something else';

    await expectLater(
      service.previewUpdateText(
        jsonEncode(payload),
        fileName: 'wrong.json',
        topicId: seeded.topicId,
      ),
      throwsA(
        isA<TopicFileException>().having(
          (error) => error.message,
          'message',
          contains('does not contain'),
        ),
      ),
    );
  });

  test('an invalid file is rejected before any diff is built', () async {
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    await expectLater(
      service.previewUpdateText(
        '{"formatVersion": 1, "topics": []}',
        fileName: 'bad.json',
        topicId: seeded.topicId,
      ),
      throwsA(isA<Object>()),
    );
  });
}
