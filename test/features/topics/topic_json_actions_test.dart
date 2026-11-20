import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/features/import/domain/import_service.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/topics/domain/topic_edit_service.dart';

import '../../helpers/test_harness.dart';

class _RecordingTopicEditService extends TopicEditService {
  _RecordingTopicEditService({
    required super.practices,
    required super.importService,
    required super.clock,
  });

  int? sharedTopicId;

  @override
  Future<File> shareTopicJson(int topicId) async {
    sharedTopicId = topicId;
    return File('${Directory.systemTemp.path}/fake-topic.json');
  }
}

void main() {
  testWidgets('topic options offer topic JSON download and update', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 1,
    );
    final service = _RecordingTopicEditService(
      practices: harness.practices,
      importService: ImportService(
        repository: harness.practices,
        clock: harness.clock,
      ),
      clock: harness.clock,
    );

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      overrides: [topicEditServiceProvider.overrideWithValue(service)],
    );

    await tester.longPress(find.text('Cloud'));
    await pumpFrames(tester);

    expect(find.text('Download topic JSON'), findsOneWidget);
    expect(find.text('Every practice in this topic'), findsOneWidget);
    expect(find.text('Update topic JSON'), findsOneWidget);
    expect(
      find.text('Add or modify practices and questions from a file'),
      findsOneWidget,
    );

    await tester.tap(find.text('Download topic JSON'));
    await pumpFrames(tester);

    expect(service.sharedTopicId, seeded.topicId);
    expect(tester.takeException(), isNull);
  });
}
