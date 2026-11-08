import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/review_page.dart';

import '../../helpers/test_harness.dart';

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
}
