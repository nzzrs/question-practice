import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

const _distractedCheck = ValueKey('distracted-answer-check');
const _unknownCheck = ValueKey('unknown-answer-check');

Future<SessionStart> _startSession(TestHarness harness) async {
  final seeded = await harness.seedPractice(count: 1);
  final service = SessionService(
    practices: harness.practices,
    sessions: harness.sessions,
    cards: harness.cards,
    clock: harness.clock,
  );
  return service.startPractice(seeded.practiceId);
}

Future<void> _checkAnswer(WidgetTester tester, String answer) async {
  await tester.tap(find.text(answer));
  await tester.pump();
  await tester.tap(find.text('Check'));
  await pumpFrames(tester);
}

void main() {
  testWidgets('a wrong answer offers only the distraction checkbox', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startSession(harness);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    await _checkAnswer(tester, 'Wrong 1');

    expect(find.text('I was distracted or read too fast'), findsOneWidget);
    expect(
      find.text('No error card; it does not count as skipped.'),
      findsOneWidget,
    );
    expect(find.byKey(_distractedCheck), findsOneWidget);
    expect(find.text("I didn't know this"), findsNothing);
    expect(
      find.text(
        'No error card; counts as skipped and the review asks for the concept.',
      ),
      findsNothing,
    );
    expect(find.byKey(_unknownCheck), findsNothing);

    Finder checkboxSemantics(bool? checked) => find.descendant(
      of: find.byKey(_distractedCheck),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.checked == checked &&
            widget.properties.enabled == true,
      ),
    );
    expect(checkboxSemantics(false), findsOneWidget);

    await tester.ensureVisible(find.byKey(_distractedCheck));
    await pumpFrames(tester);
    await tester.tap(find.byKey(_distractedCheck));
    await pumpFrames(tester);

    expect(checkboxSemantics(true), findsOneWidget);
    expect(find.byKey(_unknownCheck), findsNothing);
  });

  testWidgets('a correct answer hides all feedback checkboxes', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startSession(harness);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    await _checkAnswer(tester, 'Correct 1');

    expect(find.text('I was distracted or read too fast'), findsNothing);
    expect(find.text("I didn't know this"), findsNothing);
    expect(find.byKey(_distractedCheck), findsNothing);
    expect(find.byKey(_unknownCheck), findsNothing);
  });

  testWidgets('a skipped answer hides all feedback checkboxes', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startSession(harness);

    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );
    await tester.tap(find.text('Skip'));
    await pumpFrames(tester);

    expect(find.text('I was distracted or read too fast'), findsNothing);
    expect(find.text("I didn't know this"), findsNothing);
    expect(find.byKey(_distractedCheck), findsNothing);
    expect(find.byKey(_unknownCheck), findsNothing);
  });
}
