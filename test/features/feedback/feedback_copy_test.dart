import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/feedback/feedback_actions.dart';
import 'package:question_practice/features/feedback/feedback_snapshot.dart';
import 'package:question_practice/features/feedback/question_feedback_view.dart';
import 'package:question_practice/features/feedback/wrong_answer_bullets_readonly.dart';

import '../../helpers/test_harness.dart';

const _fullInstructions =
    'Select every correct alternative. Select text to define a term.';

FeedbackSnapshot _snapshot({
  required FeedbackMode mode,
  bool revealed = true,
  bool distracted = false,
}) {
  return FeedbackSnapshot(
    question: 'Pick every correct alternative?',
    alternatives: const ['Alpha', 'Beta', 'Gamma'],
    correctIndexes: const [0, 1],
    selectedIndexes: const [2],
    order: const [0, 1, 2],
    explanation: 'Alpha and Beta are both correct.',
    alternativeExplanations: const [
      'Alpha is correct.',
      'Beta is correct too.',
      'Gamma is the distractor.',
    ],
    topicName: 'Topic',
    subtopic: 'Layers',
    wrongAnswerBullets: const ['I confused Alpha with Gamma.'],
    mode: mode,
    isDistracted: distracted,
    pastErrors: mode == FeedbackMode.review,
    revealed: revealed,
  );
}

Future<void> _pumpFeedback(
  WidgetTester tester,
  FeedbackSnapshot snapshot,
) async {
  final harness = TestHarness();
  addTearDown(harness.close);
  await pumpTestApp(
    tester,
    home: Scaffold(
      body: QuestionFeedbackView(
        snapshot: snapshot,
        actions: FeedbackActions(onDefine: (_, _) {}, onOpenUrl: (_) {}),
        scrollable: true,
      ),
    ),
    harness: harness,
  );
}

void main() {
  testWidgets('review feedback shows only the short verdict', (tester) async {
    await _pumpFeedback(tester, _snapshot(mode: FeedbackMode.review));

    expect(find.byKey(const ValueKey('feedback-status')), findsOneWidget);
    expect(find.text('Not quite.'), findsOneWidget);
    expect(
      find.text('Not quite. This is the error card from that attempt.'),
      findsNothing,
    );
    expect(find.textContaining('error card from that attempt'), findsNothing);
  });

  testWidgets('review feedback hides answer-time instructions', (tester) async {
    await _pumpFeedback(tester, _snapshot(mode: FeedbackMode.review));

    expect(find.byKey(const ValueKey('feedback-instructions')), findsNothing);
    expect(find.text(_fullInstructions), findsNothing);
    expect(find.text('Select text to define a term.'), findsNothing);
  });

  testWidgets('review feedback keeps the verdict, reasoning and warning', (
    tester,
  ) async {
    await _pumpFeedback(
      tester,
      _snapshot(mode: FeedbackMode.review, distracted: true),
    );

    expect(find.text('Not quite.'), findsOneWidget);
    expect(find.text('Why this answer'), findsOneWidget);
    expect(find.text('Alpha and Beta are both correct.'), findsOneWidget);
    expect(find.text('I confused Alpha with Gamma.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('feedback-distraction-warning')),
      findsOneWidget,
    );
    expect(
      find.text('You were distracted or misread. This card stays due.'),
      findsOneWidget,
    );
    expect(find.text(_fullInstructions), findsNothing);
  });

  testWidgets('practice feedback never exposes review row actions', (
    tester,
  ) async {
    await _pumpFeedback(tester, _snapshot(mode: FeedbackMode.practice));

    expect(find.byKey(const ValueKey('feedback-notes')), findsNothing);
    expect(
      find.byKey(const ValueKey('wrong-answer-bullets-list')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('wrong-answer-bullets-more-0')),
      findsNothing,
    );
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Create card'), findsNothing);
    expect(find.text('Create card with AI'), findsNothing);
    expect(find.byKey(const ValueKey('feedback-note-more-0')), findsNothing);
    expect(
      find.byKey(const ValueKey('wrong-answer-bullets-more-0')),
      findsNothing,
    );
  });

  testWidgets('a busy bullet disables its AI card action', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await pumpTestApp(
      tester,
      home: Scaffold(
        body: WrongAnswerBulletsReadonly(
          bullets: const ['I confused the layers.'],
          actions: FeedbackActions(onDefine: (_, _) {}, onOpenUrl: (_) {}),
          onTurnBulletIntoCard: (_, _) {},
          bulletBusy: true,
        ),
      ),
      harness: harness,
    );

    await tester.tap(find.byKey(const ValueKey('wrong-answer-bullets-more-0')));
    await pumpFrames(tester);
    expect(find.text('Create card with AI'), findsOneWidget);
    final row = find.ancestor(
      of: find.byKey(const ValueKey('wrong-answer-bullets-card-0')),
      matching: find.byType(M3ETappable),
    );
    expect(tester.widget<M3ETappable>(row).enabled, isFalse);
  });

  testWidgets('practice feedback keeps instructions while answering', (
    tester,
  ) async {
    await _pumpFeedback(
      tester,
      _snapshot(mode: FeedbackMode.practice, revealed: false),
    );

    expect(find.byKey(const ValueKey('feedback-instructions')), findsOneWidget);
    expect(find.text(_fullInstructions), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-status')), findsNothing);
  });

  testWidgets('practice feedback drops instructions once the answer is shown', (
    tester,
  ) async {
    await _pumpFeedback(tester, _snapshot(mode: FeedbackMode.practice));

    expect(find.byKey(const ValueKey('feedback-instructions')), findsNothing);
    expect(find.text(_fullInstructions), findsNothing);
    expect(find.byKey(const ValueKey('feedback-status')), findsOneWidget);
    expect(
      find.text('Not quite. Write what went wrong, then turn it into cards.'),
      findsOneWidget,
    );
    expect(find.text('Why this answer'), findsOneWidget);
  });
}
