import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/feedback/feedback_option_card.dart';
import 'package:question_practice/features/feedback/question_feedback_view.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/practice/session_page.dart';

import '../../helpers/test_harness.dart';

class _FailingSessionService extends SessionService {
  _FailingSessionService(TestHarness harness)
    : super(
        practices: harness.practices,
        sessions: harness.sessions,
        cards: harness.cards,
        clock: harness.clock,
      );

  @override
  Future<Attempt> setWrongNotes({
    required SessionStart start,
    required SessionQuestionItem item,
    required List<String> notes,
  }) async {
    throw const SessionException('The notes could not be saved.');
  }
}

Future<SessionStart> _startWrong(TestHarness harness, {int count = 2}) async {
  final seeded = await harness.seedPractice(count: count);
  final service = SessionService(
    practices: harness.practices,
    sessions: harness.sessions,
    cards: harness.cards,
    clock: harness.clock,
  );
  return service.startPractice(seeded.practiceId);
}

Future<void> _answerWrong(WidgetTester tester) async {
  await tester.tap(find.text('Wrong 1'));
  await tester.pump();
  await tester.tap(find.text('Check'));
  await pumpFrames(tester);
}

void main() {
  testWidgets('a wrong answer shows bullets and no mistake chips', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startWrong(harness);
    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    expect(find.text('Forgotten fact'), findsNothing);
    expect(find.text('What went wrong?'), findsNothing);
    await _answerWrong(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('wrong-notes-editor')),
    );
    await pumpFrames(tester);

    expect(find.text('What went wrong?'), findsOneWidget);
    expect(find.byKey(const ValueKey('wrong-notes-editor')), findsOneWidget);
    expect(find.byKey(const ValueKey('wrong-notes-field-0')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('wrong-notes-field-0')))
          .getSemanticsData()
          .label,
      contains('Wrong answer bullet 1'),
    );
    expect(find.byType(QuestionFeedbackView), findsOneWidget);
    expect(find.byType(FeedbackOptionCard), findsNWidgets(2));
    expect(find.byKey(const ValueKey('feedback-status')), findsOneWidget);
    for (final chip in const [
      'Forgotten fact',
      'Confusion between 2 options',
      'Misinterpretation',
      'Distraction',
    ]) {
      expect(find.text(chip), findsNothing);
    }
    expect(
      find.byKey(const ValueKey('distracted-answer-check')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('unknown-answer-check')), findsOneWidget);
  });

  testWidgets('a correct answer keeps the bullets hidden', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startWrong(harness);
    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    await tester.tap(find.text('Correct 1'));
    await tester.pump();
    await tester.tap(find.text('Check'));
    await pumpFrames(tester);

    expect(find.text('What went wrong?'), findsNothing);
    expect(find.byKey(const ValueKey('wrong-notes-editor')), findsNothing);
  });

  testWidgets('Enter and paste split into bullets and autosave both stores', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startWrong(harness);
    final item = start.items.first;
    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    await _answerWrong(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('wrong-notes-editor')),
    );
    await pumpFrames(tester);

    await tester.enterText(
      find.byKey(const ValueKey('wrong-notes-field-0')),
      'I rushed\n- I misread the stem',
    );
    await pumpFrames(tester, frames: 20);

    expect(find.byKey(const ValueKey('wrong-notes-field-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('wrong-notes-field-1')), findsOneWidget);
    final first = tester.widget<EditableText>(
      find.byKey(const ValueKey('wrong-notes-field-0')),
    );
    expect(first.controller.text, 'I rushed');
    final second = tester.widget<EditableText>(
      find.byKey(const ValueKey('wrong-notes-field-1')),
    );
    expect(second.controller.text, 'I misread the stem');

    final attempt = await tester.runAsync(
      () => harness.sessions.attemptForQuestion(
        start.session.id,
        item.question.id,
      ),
    );
    expect(attempt!.reasoning, 'I rushed\nI misread the stem');
    final card = await tester.runAsync(
      () => harness.cards.activeErrorForQuestion(item.question.id),
    );
    expect(card!.reasoning, 'I rushed\nI misread the stem');
    expect(find.byKey(const ValueKey('wrong-notes-save-status')), findsNothing);
  });

  testWidgets('delete and blur remove bullets but keep one row', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startWrong(harness);
    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    await _answerWrong(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('wrong-notes-editor')),
    );
    await pumpFrames(tester);

    await tester.enterText(
      find.byKey(const ValueKey('wrong-notes-field-0')),
      'First',
    );
    await tester.tap(find.byKey(const ValueKey('wrong-notes-add')));
    await pumpFrames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('wrong-notes-field-1')),
      'Second',
    );
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('wrong-notes-field-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wrong-notes-delete-1')));
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('wrong-notes-field-1')), findsNothing);
    expect(find.byKey(const ValueKey('wrong-notes-field-0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wrong-notes-add')));
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('wrong-notes-field-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wrong-notes-field-1')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('wrong-notes-field-0')));
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('wrong-notes-field-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('wrong-notes-delete-0')));
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('wrong-notes-field-0')), findsOneWidget);
  });

  testWidgets('Next flushes the draft and returning restores the bullets', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startWrong(harness);
    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    await _answerWrong(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('wrong-notes-editor')),
    );
    await pumpFrames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('wrong-notes-field-0')),
      'Only bullet',
    );
    await tester.tap(find.text('Next question'));
    await pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await pumpFrames(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('wrong-notes-editor')),
    );
    await pumpFrames(tester);
    final field = tester.widget<EditableText>(
      find.byKey(const ValueKey('wrong-notes-field-0')),
    );
    expect(field.controller.text, 'Only bullet');
  });

  testWidgets('a failed save keeps the draft, says so, and blocks Next', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startWrong(harness);
    final failing = _FailingSessionService(harness);
    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
      overrides: [sessionServiceProvider.overrideWithValue(failing)],
    );

    await _answerWrong(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('wrong-notes-editor')),
    );
    await pumpFrames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('wrong-notes-field-0')),
      'Draft that will not save',
    );
    await pumpFrames(tester, frames: 20);

    expect(find.text('Not saved. Try again.'), findsOneWidget);
    expect(find.text('Question 1?'), findsOneWidget);
    await tester.tap(find.text('Next question'));
    await pumpFrames(tester, frames: 20);
    expect(find.text('Question 1?'), findsOneWidget);
    expect(find.text('Question 2?'), findsNothing);

    final field = tester.widget<EditableText>(
      find.byKey(const ValueKey('wrong-notes-field-0')),
    );
    expect(field.controller.text, 'Draft that will not save');

    await tester.tap(find.byKey(const ValueKey('session-leave')));
    await pumpFrames(tester, frames: 20);
    expect(find.text('Leave this practice?'), findsNothing);
    expect(find.text('Question 1?'), findsOneWidget);
    expect(find.text('Your notes are not saved. Try again.'), findsOneWidget);
  });

  testWidgets('the feedback fits 360 dp at 2.0 text scale', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startWrong(harness);
    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    await _answerWrong(tester);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('wrong-notes-editor')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('wrong-notes-add')), findsOneWidget);
  });

  testWidgets('the distraction checkbox still removes and restores the card', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final start = await _startWrong(harness);
    final item = start.items.first;
    await pumpTestApp(
      tester,
      home: SessionPage(start: start),
      harness: harness,
    );

    await _answerWrong(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('wrong-notes-editor')),
    );
    await pumpFrames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('wrong-notes-field-0')),
      'A bullet',
    );
    await pumpFrames(tester, frames: 16);

    await tester.ensureVisible(
      find.byKey(const ValueKey('distracted-answer-check')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('distracted-answer-check')));
    await pumpFrames(tester);
    expect(
      await tester.runAsync(
        () => harness.cards.activeErrorForQuestion(item.question.id),
      ),
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('distracted-answer-check')));
    await pumpFrames(tester);
    final restored = await tester.runAsync(
      () => harness.cards.activeErrorForQuestion(item.question.id),
    );
    expect(restored, isNotNull);
    expect(restored!.reasoning, 'A bullet');
  });
}
