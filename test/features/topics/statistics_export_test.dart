import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/topics/domain/statistics_export_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late SessionService sessions;
  late Directory directory;

  setUp(() async {
    harness = TestHarness();
    sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    directory = await Directory.systemTemp.createTemp('statistics-export-');
  });

  tearDown(() async {
    await harness.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  Future<void> completeSession(int practiceId, {required bool correct}) async {
    final start = await sessions.startPractice(practiceId);
    for (final item in start.items) {
      await sessions.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: correct ? const [0] : const [1],
        reasoning: '',
        distracted: false,
      );
    }
  }

  test(
    'topic payload carries summary, progress, subtopics and trend',
    () async {
      final practice = await harness.seedPractice(
        topicName: 'Cloud',
        practiceName: 'Core',
        count: 2,
        subtopics: const ['Compute', 'Storage'],
      );
      await completeSession(practice.practiceId, correct: true);
      harness.clock.advance(const Duration(days: 7));
      await completeSession(practice.practiceId, correct: false);

      final service = StatisticsExportService(
        practices: harness.practices,
        clock: harness.clock,
        temporaryDirectory: () async => directory,
      );
      final payload = await service.buildTopicPayload(practice.topicId);

      expect(payload['app'], 'question_practice');
      expect(payload['kind'], 'statistics');
      expect(payload['formatVersion'], 1);
      final scope = payload['scope'] as Map<String, dynamic>;
      expect(scope['kind'], 'topic');
      expect(scope['topicId'], practice.topicId);
      expect(scope['topicName'], 'Cloud');

      final summary = payload['summary'] as Map<String, dynamic>;
      expect(summary['practiceCount'], 1);
      expect(summary['questionCount'], 2);
      expect(summary['answeredCount'], 4);
      expect(summary['correctCount'], 2);
      expect(summary['accuracy'], 0.5);
      expect(summary['progress'], 1);
      expect(summary['sessionCount'], 2);

      final progress = payload['progress'] as List<dynamic>;
      expect(progress, hasLength(2));
      expect((progress.first as Map<String, dynamic>)['score'], 1);
      expect((progress.last as Map<String, dynamic>)['score'], 0);

      final subtopics = payload['subtopics'] as List<dynamic>;
      expect(subtopics, hasLength(2));
      final compute = subtopics.cast<Map<String, dynamic>>().firstWhere(
        (stat) => stat['subtopic'] == 'Compute',
      );
      expect(compute['questionCount'], 1);
      expect(compute['answeredCount'], 2);
      expect(compute['correctCount'], 1);
      expect(compute['accuracy'], 0.5);
      expect(compute['progress'], 1);

      final trend = payload['trend'] as Map<String, dynamic>;
      expect(trend['sessionCount'], 2);
      final regression = trend['regression'] as Map<String, dynamic>;
      expect(regression['slope'], closeTo(-1, 1e-9));
      expect(regression['intercept'], closeTo(1, 1e-9));
      expect(trend['learningRatePercentagePointsPerWeek'], closeTo(-100, 1e-9));
    },
  );

  test('payload omits subtopics when no question has one', () async {
    final practice = await harness.seedPractice(count: 1);

    final service = StatisticsExportService(
      practices: harness.practices,
      clock: harness.clock,
      temporaryDirectory: () async => directory,
    );
    final payload = await service.buildTopicPayload(practice.topicId);

    expect(payload['subtopics'], isEmpty);
    expect((payload['trend'] as Map<String, dynamic>)['regression'], isNull);
  });

  test(
    'shareTopicStats writes JSON and passes the file to the sharer',
    () async {
      final practice = await harness.seedPractice(
        topicName: 'Cloud',
        count: 1,
        subtopics: const ['Compute'],
      );
      File? shared;
      final service = StatisticsExportService(
        practices: harness.practices,
        clock: harness.clock,
        temporaryDirectory: () async => directory,
        shareFile: (file) async => shared = file,
      );

      final file = await service.shareTopicStats(practice.topicId);

      expect(shared, isNotNull);
      expect(shared!.path, file.path);
      expect(await file.exists(), isTrue);
      final payload =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(payload['kind'], 'statistics');
      expect(
        (payload['scope'] as Map<String, dynamic>)['topicId'],
        practice.topicId,
      );
    },
  );
}
