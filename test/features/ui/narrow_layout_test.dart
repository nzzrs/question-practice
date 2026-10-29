import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/theme.dart';
import 'package:question_practice/features/errors/past_errors_page.dart';
import 'package:question_practice/features/export/cards_page.dart';
import 'package:question_practice/features/help/help_page.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/import/import_page.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';
import 'package:question_practice/features/practice/summary_page.dart';
import 'package:question_practice/features/review/review_page.dart';
import 'package:question_practice/features/settings/settings_page.dart';
import 'package:question_practice/features/topics/topic_page.dart';

import '../../helpers/test_harness.dart';

const _narrow = Size(320, 640);

Future<void> _loadTestFont() async {
  final bytes = await File('test/fixtures/Roboto-Regular.ttf').readAsBytes();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _pumpNarrow(
  WidgetTester tester, {
  required Widget home,
  required TestHarness harness,
}) async {
  tester.view.physicalSize = _narrow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = harness.container();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: M3EMaterialApp(
        title: 'Question Practice',
        data: appThemeData(),
        fontFamily: 'Roboto',
        autoTheming: false,
        dynamicColoring: false,
        debugShowCheckedModeBanner: false,
        home: home,
      ),
    ),
  );
  await pumpFrames(tester);
  expect(tester.takeException(), isNull);
}

Future<void> _seedErrorCard(
  TestHarness harness,
  SeededPractice seeded, {
  bool complete = false,
  bool due = false,
}) async {
  final question = (await harness.practices.questionsForPractice(
    seeded.practiceId,
  )).single;
  final id = await harness.cards.createErrorCard(
    questionId: question.id,
    sessionId: null,
    question: question.prompt,
    alternatives: question.alternatives,
    correctIndexes: question.correctIndexes,
    wrongIndexes: const [1],
    reasoning: 'Reasoning',
    explanation: question.explanation,
    alternativeExplanations: question.alternativeExplanations,
    topicName: 'Topic',
    practiceName: 'Practice',
    lastWrongAt: due
        ? harness.clock.now().subtract(const Duration(hours: 72)).toUtc()
        : harness.clock.now().toUtc(),
    dueAfter: const Duration(hours: 48),
  );
  if (complete) {
    await harness.cards.updateErrorCardDetails(
      id: id,
      bias: 'Bias',
      vaccine: 'Vaccine',
      completedAt: harness.clock.now().toUtc(),
    );
  }
}

void main() {
  setUpAll(_loadTestFont);

  testWidgets('home and empty library fit 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await _pumpNarrow(tester, home: const HomePage(), harness: harness);
    expect(find.text('No practices yet'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
  });

  testWidgets('home with long topics fits 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(
      topicName: 'Google Professional Cloud Architect',
      practiceName: 'Exam',
      count: 3,
    );
    await _pumpNarrow(tester, home: const HomePage(), harness: harness);
    expect(find.text('Google Professional Cloud Architect'), findsOneWidget);
  });

  testWidgets('home shows pending error cards beside the export count', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    await _seedErrorCard(harness, seeded);
    await _pumpNarrow(tester, home: const HomePage(), harness: harness);
    expect(find.text('1 pending'), findsOneWidget);
  });

  testWidgets('topic page fits 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Networking basics',
      practiceName: 'A very long practice name for narrow phones',
      count: 2,
      ankiDeck: 'A deck with a fairly long name',
    );
    await _pumpNarrow(
      tester,
      home: TopicPage(topicId: seeded.topicId),
      harness: harness,
    );
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Practices'), findsOneWidget);
  });

  testWidgets('review page with long prompts fits 320', (tester) async {
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
    await service.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [1],
      reasoning: 'A long reasoning line that should wrap cleanly.',
      distracted: false,
    );
    await service.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [],
      reasoning: '',
      distracted: false,
    );
    await _pumpNarrow(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text('What was the flawed assumption in your reasoning?'),
      findsOneWidget,
    );
    expect(
      find.text('What do you need to know to prevent that error?'),
      findsOneWidget,
    );
  });

  testWidgets('session page fits 320', (tester) async {
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
    await _pumpNarrow(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Select text to define a term.'), findsOneWidget);
  });

  testWidgets('cards page fits 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    await _seedErrorCard(harness, seeded, complete: true);
    await _pumpNarrow(tester, home: const CardsPage(), harness: harness);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);
    expect(find.text('Review all'), findsOneWidget);
  });

  testWidgets('cards page with long tags fits 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'A very long topic name that keeps going for a while',
      practiceName: 'Practice',
      count: 1,
      ankiDeck: 'A parent deck with a very long name::A child deck with another long name',
    );
    await _seedErrorCard(harness, seeded, complete: true);
    await _pumpNarrow(tester, home: const CardsPage(), harness: harness);
    expect(tester.takeException(), isNull);
    expect(find.text('Export to AnkiDroid'), findsOneWidget);
  });

  testWidgets('import page and preview fit 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await _pumpNarrow(tester, home: const ImportPage(), harness: harness);
    expect(find.text('Choose file'), findsOneWidget);
    expect(find.text('Load sample'), findsOneWidget);

    await tester.tap(find.text('Load sample'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ready to import'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
  });

  testWidgets('settings page fits 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await _pumpNarrow(tester, home: const SettingsPage(), harness: harness);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Practice sounds'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await pumpFrames(tester);
    expect(find.text('AnkiDroid'), findsOneWidget);
  });

  testWidgets('help page fits 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await _pumpNarrow(tester, home: const HelpPage(), harness: harness);
    expect(find.text('A quiet loop for practice'), findsOneWidget);
  });

  testWidgets('past errors page fits 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    await _seedErrorCard(harness, seeded, due: true);
    await _pumpNarrow(tester, home: const PastErrorsPage(), harness: harness);
    expect(find.text('Review 1 error'), findsOneWidget);
  });

  testWidgets('summary page fits 320', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final practice = await harness.seedPractice(count: 3);
    final service = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await service.startPractice(practice.practiceId);
    await service.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await service.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [1],
      reasoning: '',
      distracted: false,
    );
    final outcome = await service.submitAnswer(
      start: start,
      item: start.items[2],
      selectedIndexes: const [],
      reasoning: '',
      distracted: false,
    );
    await _pumpNarrow(
      tester,
      home: SummaryPage(summary: outcome.summary!),
      harness: harness,
    );
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
