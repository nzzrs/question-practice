import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/summary_page.dart';
import 'package:question_practice/features/review/review_page.dart';

import '../../helpers/test_harness.dart';

http.Response _aiResponse(List<Map<String, String>> cards) {
  return http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({'cards': cards}),
          },
        },
      ],
    }),
    200,
  );
}

void main() {
  testWidgets('skipped review shows the correct answer and reasoning', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [],
      reasoning: 'I mixed up the storage classes.',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('Correct 1'), findsOneWidget);
    expect(find.text('Your reasoning'), findsOneWidget);
    expect(find.text('I mixed up the storage classes.'), findsOneWidget);
    expect(find.text('Why'), findsOneWidget);

    await tester.ensureVisible(find.text('See other alternatives'));
    await tester.tap(find.text('See other alternatives'));
    await pumpFrames(tester);
    expect(find.text('Hide other alternatives'), findsOneWidget);
    expect(find.text('Wrong 1'), findsOneWidget);
    expect(find.text('Wrong: 1 is a distractor.'), findsOneWidget);
  });

  testWidgets('unknown review is labelled and keeps the reasoning', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: 'I guessed between the two names.',
      distracted: false,
    );
    await sessions.setUnknown(
      start: start,
      item: start.items.single,
      unknown: true,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.text("I didn't know this"), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('I guessed between the two names.'), findsOneWidget);
  });

  testWidgets('end-of-session review opens full screen and restores bars', (
    tester,
  ) async {
    final recorder = SystemUiCallRecorder()..install();
    addTearDown(recorder.dispose);
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: 'I guessed.',
      distracted: false,
    );
    final summary = await sessions.finishEarly(
      start: start,
      markSkipped: false,
    );

    await pumpTestApp(
      tester,
      home: SummaryPage(summary: summary),
      harness: harness,
    );
    await tester.ensureVisible(find.textContaining('Start error review'));
    await pumpFrames(tester);
    await tester.tap(find.textContaining('Start error review'));
    await pumpFrames(tester);

    expect(find.byType(ReviewPage), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.byType(ReviewPage)));
    expect(route, isA<MaterialPageRoute<void>>());
    expect((route as MaterialPageRoute<void>).fullscreenDialog, isTrue);
    expect(find.byType(M3EAppBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('app-focus-header')), findsOneWidget);
    expect(recorder.modes, contains('SystemUiMode.immersiveSticky'));

    await tester.tap(find.byKey(const ValueKey('app-focus-exit')));
    await pumpFrames(tester);

    expect(find.byType(ReviewPage), findsNothing);
    expect(find.byType(SummaryPage), findsOneWidget);
    expect(recorder.modes.last, 'SystemUiMode.edgeToEdge');
  });

  testWidgets('the end-of-session highlight step uses the shared view', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    final item = start.items.single;
    await sessions.submitAnswer(
      start: start,
      item: item,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await harness.cards.createHighlight(
      sessionId: start.session.id,
      questionId: item.question.id,
      text: 'managed service',
      context: item.question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.text('Keep this note?'), findsOneWidget);
    expect(find.text('managed service'), findsOneWidget);
    expect(find.text('From the question'), findsOneWidget);
    expect(find.text('Create cards'), findsOneWidget);
    expect(find.text('Suggest with AI'), findsOneWidget);
    expect(find.text('Keep & save'), findsOneWidget);
  });

  testWidgets('error review continues without bias or vaccine notes', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: 'I guessed.',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    expect(find.text('Analyse the error'), findsOneWidget);
    expect(find.byKey(const ValueKey('error-breakdown-ai')), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Check with AI'), findsNothing);
    expect(find.text('Flawed assumption (bias)'), findsNothing);
    expect(find.text('Vaccine (rule / protocol)'), findsNothing);

    await tester.tap(find.text('Continue'));
    await pumpFrames(tester);

    expect(find.text('Review complete'), findsWidgets);
  });

  testWidgets('adding atomic cards from the error step advances the review', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => _aiResponse([
        {
          'type': 'contrast',
          'front': 'Which layer owns IP addresses?',
          'back': 'The network layer owns addressing.',
        },
        {
          'type': 'heuristic',
          'front': 'Given requirement X with restriction Y, what rule applies?',
          'back': 'Match the layer to its addressing job.',
        },
      ]),
    );
    final harness = TestHarness(httpClient: client);
    addTearDown(harness.close);
    await harness.settings.save(
      const AppSettings(
        lookupMode: LookupMode.ai,
        aiModel: 'test-model',
        aiBaseUrl: 'https://example.test/v1',
      ),
    );
    await harness.keyStore.writeApiKey('secret-key');
    final seeded = await harness.seedPractice(count: 1);
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [1],
      reasoning: 'I guessed.',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('error-breakdown-ai')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('error-breakdown-ai')));
    await pumpFrames(tester, frames: 24);
    await tester.ensureVisible(find.byKey(const ValueKey('error-add-cards')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('error-add-cards')));
    await pumpFrames(tester, frames: 24);

    expect(find.textContaining('2 cards completed or created'), findsOneWidget);
    final error = await tester.runAsync(
      () =>
          harness.cards.activeErrorForQuestion(start.items.single.question.id),
    );
    expect(error!.needsDetails, isFalse);
    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(2));
  });
}
