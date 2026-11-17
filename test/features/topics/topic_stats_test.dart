import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
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

Future<void> _completeSession(
  TestHarness harness,
  int practiceId, {
  int selected = 0,
}) async {
  final sessions = SessionService(
    practices: harness.practices,
    sessions: harness.sessions,
    cards: harness.cards,
    clock: harness.clock,
  );
  final start = await sessions.startPractice(practiceId);
  for (final item in start.items) {
    await sessions.submitAnswer(
      start: start,
      item: item,
      selectedIndexes: [selected],
      reasoning: '',
      distracted: false,
    );
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
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
    expect(find.text('weighted by questions'), findsOneWidget);
    expect(find.textContaining('weighted average'), findsOneWidget);
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

  testWidgets('learning rate and weighted trend appear after two sessions', (
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
    expect(find.text('-10000 pp/100 questions'), findsOneWidget);
    expect(find.text('-700 pp/week'), findsOneWidget);
    expect(find.text('Trend (questions)'), findsOneWidget);
  });

  testWidgets('long-press selects a category and reveals selection actions', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(
      topicName: 'Networking',
      count: 4,
      subtopics: const ['TCP', 'DNS', 'UDP', ''],
    );
    await _completeSession(harness, practice.practiceId);

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: practice.topicId),
      harness: harness,
    );

    await _reveal(tester, find.text('TCP'));
    await tester.longPress(find.text('TCP'));
    await pumpFrames(tester);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.merge_type), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await _reveal(tester, find.text('DNS'));
    await tester.tap(find.text('DNS'));
    await pumpFrames(tester);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.merge_type), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);
    expect(find.byIcon(Icons.merge_type), findsNothing);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets('renaming a selected category updates the list', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(
      topicName: 'Networking',
      count: 3,
      subtopics: const ['TCP', 'DNS', 'UDP'],
    );
    await _completeSession(harness, practice.practiceId);

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: practice.topicId),
      harness: harness,
    );

    await _reveal(tester, find.text('TCP'));
    await tester.longPress(find.text('TCP'));
    await pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await pumpFrames(tester);

    expect(find.text('Rename category'), findsOneWidget);
    await tester.enterText(find.byType(M3ETextField), 'Transport');
    await tester.tap(find.text('Save'));
    await pumpFrames(tester);

    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('TCP'), findsNothing);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets('merging selected categories combines their questions', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(
      topicName: 'Networking',
      count: 4,
      subtopics: const ['TCP', 'DNS', 'UDP', ''],
    );
    await _completeSession(harness, practice.practiceId);

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: practice.topicId),
      harness: harness,
    );

    await _reveal(tester, find.text('TCP'));
    await tester.longPress(find.text('TCP'));
    await pumpFrames(tester);
    await _reveal(tester, find.text('DNS'));
    await tester.tap(find.text('DNS'));
    await pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.merge_type));
    await pumpFrames(tester);

    expect(find.text('Merge categories'), findsOneWidget);
    expect(find.text('New name'), findsWidgets);
    await tester.tap(find.text('Merge'));
    await pumpFrames(tester);

    expect(find.text('TCP'), findsOneWidget);
    expect(find.text('DNS'), findsNothing);
    expect(find.textContaining('2/2 questions'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets('deleting a category keeps its questions as Uncategorized', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(
      topicName: 'Networking',
      count: 4,
      subtopics: const ['TCP', 'DNS', 'UDP', ''],
    );
    await _completeSession(harness, practice.practiceId);

    await pumpTestApp(
      tester,
      home: TopicStatsPage(topicId: practice.topicId),
      harness: harness,
    );

    await _reveal(tester, find.text('UDP'));
    await tester.longPress(find.text('UDP'));
    await pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await pumpFrames(tester);
    expect(find.text('Delete category?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await pumpFrames(tester);

    expect(find.text('UDP'), findsNothing);
    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.textContaining('2/2 questions'), findsOneWidget);
  });

  testWidgets('topic hero shows rolling accuracy over the last five sessions', (
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

    // Wrong, then four of the next five correct: 4/5 recent, 4/6 lifetime.
    for (final correct in [false, true, true, false, true, true]) {
      final start = await sessions.startPractice(practice.practiceId);
      await sessions.submitAnswer(
        start: start,
        item: start.items.single,
        selectedIndexes: [correct ? 0 : 1],
        reasoning: '',
        distracted: false,
      );
    }

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: practice.topicId),
      harness: harness,
    );

    expect(find.text('80%'), findsOneWidget);
    expect(find.text('Rolling accuracy · last 5 sessions'), findsOneWidget);
  });

  testWidgets('topic hero keeps a dash when no session exists', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: practice.topicId),
      harness: harness,
    );

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Rolling accuracy'), findsOneWidget);
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
