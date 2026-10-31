import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';
import 'package:question_practice/features/topics/topic_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('empty home explains the first step and opens help', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);

    expect(find.text('Questions'), findsOneWidget);
    expect(find.text('No practices yet'), findsOneWidget);
    expect(find.text('Review past errors'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info_outline));
    await pumpFrames(tester);
    expect(find.text('How to use it'), findsOneWidget);
    expect(find.text('A quiet loop for practice'), findsOneWidget);
  });

  testWidgets('home shows imported topics and opens a topic', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 3,
    );
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(seeded.practiceId);
    for (final item in start.items) {
      await service.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: const [0],
        reasoning: '',
        distracted: false,
      );
    }

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    expect(find.text('Cloud'), findsOneWidget);
    expect(find.text('1 practices · 3 questions'), findsOneWidget);

    await tester.tap(find.text('Cloud'));
    await pumpFrames(tester);
    expect(find.text('Core'), findsOneWidget);
    expect(find.text('3 questions'), findsOneWidget);
  });

  testWidgets('long pressing a topic deletes it', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud', count: 2);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    await tester.longPress(find.text('Cloud'));
    await pumpFrames(tester);

    expect(find.text('Delete topic?'), findsOneWidget);
    expect(find.textContaining('every practice, question'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Cloud'), findsNothing);
    expect(find.text('No practices yet'), findsOneWidget);
    expect(await harness.practices.allTopics(), isEmpty);
  });

  testWidgets('unanswered questions stay out of topic totals', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 3,
    );
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(seeded.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.first,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await service.finishEarly(start: start, markSkipped: false);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    expect(find.text('1 practices · 1 questions'), findsOneWidget);
  });

  testWidgets('session gives in-place feedback, explanation and score', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(count: 1);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(practice.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    expect(find.text('Question 1?'), findsOneWidget);
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(find.text('Select text to define a term.'), findsOneWidget);
    expect(find.text('I was distracted or read too fast'), findsNothing);

    await tester.tap(find.text('Wrong 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);

    expect(
      find.text('Not quite. The error card will ask what went wrong.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await pumpFrames(tester);
    expect(find.text('I was distracted or read too fast'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await pumpFrames(tester);
    expect(find.text('Why this answer'), findsOneWidget);
    expect(find.text('Because 1 is correct.'), findsOneWidget);
    expect(find.textContaining('Wrong: 1 is a distractor.'), findsOneWidget);
  });

  testWidgets('session arrows move between questions without answering', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(count: 2);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(practice.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    expect(find.text('Question 1 of 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await pumpFrames(tester);
    expect(find.text('Question 2 of 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await pumpFrames(tester);
    expect(find.text('Question 1 of 2'), findsOneWidget);
  });

  testWidgets('home lists every paused session', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(count: 1);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    await service.startPractice(practice.practiceId);
    await service.startPractice(practice.practiceId);

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    expect(find.text('Session in progress'), findsNWidgets(2));
    expect(find.text('Resume'), findsNWidgets(2));
    expect(find.text('Practice'), findsNWidgets(2));
    expect(find.text('Topic · 0/1 answered'), findsNWidgets(2));
  });

  testWidgets('five-minute reminder is a floating toast, not a countdown', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(count: 2);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(practice.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.text('5 minutes on this question. Still with us? Take a breath.'),
      findsOneWidget,
    );
    expect(find.textContaining('countdown'), findsNothing);
  });

  testWidgets('the reminder counts time per question and resets on change', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(count: 2);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(practice.practiceId);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(find.textContaining('minutes on this question'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await pumpFrames(tester);
    await tester.pump(const Duration(minutes: 1));
    expect(find.textContaining('minutes on this question'), findsNothing);

    await tester.pump(const Duration(minutes: 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.text('5 minutes on this question. Still with us? Take a breath.'),
      findsOneWidget,
    );
  });

  testWidgets('topic page shows progress stats and priority', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
      ankiDeck: 'Cloud deck',
    );
    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    expect(find.text('Networking'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('Anki deck: Cloud deck'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Correct answers'), findsOneWidget);
    expect(find.text('0/2 answered'), findsOneWidget);
    expect(find.text('TCP/IP'), findsOneWidget);
    final tiles = tester.widgetList<MetricTile>(find.byType(MetricTile));
    expect(tiles.last.tone, MetricTone.success);
  });

  testWidgets('topic metrics use red for active errors and green for correct', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking',
      practiceName: 'TCP/IP',
      count: 2,
    );
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(seeded.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items.first,
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );
    await service.submitAnswer(
      start: start,
      item: start.items.last,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    final tiles = tester.widgetList<MetricTile>(find.byType(MetricTile));
    expect(tiles.first.tone, MetricTone.error);
    expect(tiles.last.tone, MetricTone.success);
  });
}
