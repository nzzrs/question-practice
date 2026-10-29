import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
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
