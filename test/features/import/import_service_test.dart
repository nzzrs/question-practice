import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/import/domain/import_models.dart';
import 'package:question_practice/features/import/domain/import_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestHarness harness;
  late ImportService service;
  late String sample;

  setUp(() async {
    harness = TestHarness();
    service = ImportService(
      repository: harness.practices,
      clock: harness.clock,
      bundle: rootBundle,
    );
    sample = await rootBundle.loadString('assets/samples/sample_practice.json');
  });

  tearDown(() async {
    await harness.close();
  });

  test('sample has the expected structure', () async {
    final preview = await service.previewText(sample, fileName: 'sample.json');

    expect(preview.topicCount, 2);
    expect(preview.practiceCount, 3);
    expect(preview.questionCount, 8);
    expect(preview.notes, isEmpty);
  });

  test('import writes topics, practices and questions once', () async {
    final preview = await service.previewText(sample, fileName: 'sample.json');
    final result = await service.import(preview);

    expect(result.topicsCreated, 2);
    expect(result.practicesImported, 3);
    expect(result.questionsImported, 8);
    expect(result.practicesSkipped, 0);

    final topics = await harness.practices.watchTopicSummaries().first;
    expect(topics, hasLength(2));
    expect(topics.first.topic.name, 'Cloud fundamentals');
    expect(topics.first.questionCount, 5);

    final second = await service.import(
      await service.previewText(sample, fileName: 'sample.json'),
    );
    expect(second.topicsCreated, 0);
    expect(second.topicsReused, 2);
    expect(second.practicesImported, 0);
    expect(second.practicesSkipped, 3);
    expect(second.questionsImported, 0);
  });

  test('same practice name with new content gets a suffix', () async {
    final first = await service.previewText(sample, fileName: 'sample.json');
    await service.import(first);

    final changed = jsonDecode(sample) as Map<String, dynamic>;
    final topics = changed['topics'] as List<dynamic>;
    final cloud = topics.first as Map<String, dynamic>;
    final practices = cloud['practices'] as List<dynamic>;
    final core = practices.first as Map<String, dynamic>;
    final questions = core['questions'] as List<dynamic>;
    (questions.first as Map<String, dynamic>)['prompt'] = 'Changed prompt?';

    final second = await service.import(
      await service.previewText(jsonEncode(changed), fileName: 'changed.json'),
    );
    expect(second.practicesImported, 1);
    final rows = await harness.database.topicDao.allPractices();
    expect(rows.any((row) => row.name == 'Compute choices (2)'), isTrue);
  });

  test('accepts a BOM and .txt contents', () async {
    final preview = await service.previewText(
      '\uFEFF$sample',
      fileName: 'practices.txt',
    );
    expect(preview.questionCount, 8);
  });

  test('rejects invalid JSON with a line and column', () async {
    expect(
      () => service.previewText('{"topics": [}', fileName: 'broken.json'),
      throwsA(
        isA<ImportException>().having(
          (error) => error.issues.first.path,
          'path',
          contains('line'),
        ),
      ),
    );
  });

  test('rejects a correctIndex outside the alternatives', () async {
    final payload = jsonDecode(sample) as Map<String, dynamic>;
    final topics = payload['topics'] as List<dynamic>;
    final question =
        ((topics.first as Map<String, dynamic>)['practices'] as List<dynamic>)
                .first
            as Map<String, dynamic>;
    (question['questions'] as List<dynamic>).first['correctIndex'] = 99;

    await expectLater(
      service.previewText(jsonEncode(payload), fileName: 'bad.json'),
      throwsA(
        isA<ImportException>().having(
          (error) => error.issues.any(
            (issue) =>
                issue.path.contains('correctIndex') ||
                issue.message.contains('correctIndex'),
          ),
          'has correctIndex error',
          isTrue,
        ),
      ),
    );
  });

  test('rejects mismatched explanation counts', () async {
    final payload = jsonDecode(sample) as Map<String, dynamic>;
    final topics = payload['topics'] as List<dynamic>;
    final practice =
        ((topics.first as Map<String, dynamic>)['practices'] as List<dynamic>)
                .first
            as Map<String, dynamic>;
    final question =
        (practice['questions'] as List<dynamic>).first as Map<String, dynamic>;
    (question['alternativeExplanations'] as List<dynamic>).removeLast();

    await expectLater(
      service.previewText(jsonEncode(payload), fileName: 'bad.json'),
      throwsA(
        isA<ImportException>().having(
          (error) =>
              error.issues.any((issue) => issue.message.contains('Expected')),
          'has count error',
          isTrue,
        ),
      ),
    );
  });

  test('rejects a file over the size limit without parsing', () async {
    await expectLater(
      service.previewBytes(
        Uint8List(ImportService.maxFileBytes + 1),
        fileName: 'huge.json',
      ),
      throwsA(isA<ImportException>()),
    );
  });
}
