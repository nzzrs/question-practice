import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/topics/domain/statistics_export_service.dart';
import 'package:question_practice/features/topics/topic_page.dart';
import 'package:question_practice/features/topics/topic_stats_page.dart';

import '../../helpers/test_harness.dart';

Future<void> _loadTestFont() async {
  final bytes = await File('test/fixtures/Roboto-Regular.ttf').readAsBytes();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadTestFont);

  testWidgets('topic statistics shows session progress at 320', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(practice.practiceId);
    for (final item in start.items) {
      await sessions.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: const [0],
        reasoning: '',
        distracted: false,
      );
    }

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: practice.topicId),
      harness: harness,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Progress over time'), findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);
  });

  testWidgets('topic statistics shows per-subtopic accuracy and progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(
      topicName: 'Networking',
      count: 2,
      subtopics: const ['TCP', 'DNS'],
    );
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(practice.practiceId);
    for (final item in start.items) {
      await sessions.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: const [0],
        reasoning: '',
        distracted: false,
      );
    }

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: practice.topicId),
      harness: harness,
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('By subtopic'), findsOneWidget);
    expect(find.text('TCP'), findsOneWidget);
    expect(find.text('DNS'), findsOneWidget);
    expect(find.textContaining('100% accuracy'), findsNWidgets(2));
    expect(find.textContaining('1/1 questions'), findsNWidgets(2));
  });

  testWidgets('topic statistics hides subtopics when none are assigned', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(
      topicName: 'Networking',
      count: 2,
    );
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(practice.practiceId);
    for (final item in start.items) {
      await sessions.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: const [0],
        reasoning: '',
        distracted: false,
      );
    }

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: practice.topicId),
      harness: harness,
    );

    expect(find.textContaining('Progress over time'), findsOneWidget);
    expect(find.textContaining('By subtopic'), findsNothing);
    expect(find.text('Uncategorized'), findsNothing);
    expect(find.text('Learning rate'), findsNothing);
    expect(find.text('Trend'), findsNothing);
  });

  testWidgets('learning rate and trend appear after one week of history', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(topicName: 'Cloud', count: 1);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );

    Future<void> answer(int selected) async {
      final start = await sessions.startPractice(practice.practiceId);
      await sessions.submitAnswer(
        start: start,
        item: start.items.single,
        selectedIndexes: [selected],
        reasoning: '',
        distracted: false,
      );
    }

    await answer(0);
    harness.clock.advance(const Duration(days: 7));
    await answer(1);

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: practice.topicId),
      harness: harness,
    );

    expect(find.text('Learning rate'), findsOneWidget);
    expect(find.text('-100 pp/week'), findsOneWidget);
    expect(find.text('Trend'), findsOneWidget);
  });

  testWidgets('export statistics button shares the topic statistics', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(
      topicName: 'Cloud',
      count: 2,
      subtopics: const ['Compute'],
    );
    final service = _RecordingStatisticsExportService(
      practices: harness.practices,
      clock: harness.clock,
    );

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: practice.topicId),
      harness: harness,
      overrides: [statisticsExportServiceProvider.overrideWithValue(service)],
    );
    await tester.tap(find.byIcon(Icons.ios_share));
    await pumpFrames(tester);

    expect(service.exportedTopicId, practice.topicId);
  });

  testWidgets('topic page opens statistics from its app bar', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud');

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await pumpFrames(tester);
    expect(find.text('Statistics'), findsOneWidget);
  });
}

class _RecordingStatisticsExportService extends StatisticsExportService {
  _RecordingStatisticsExportService({
    required super.practices,
    required super.clock,
  });

  int? exportedTopicId;

  @override
  Future<File> shareTopicStats(int topicId) async {
    exportedTopicId = topicId;
    return File('${Directory.systemTemp.path}/fake-statistics.json');
  }
}
