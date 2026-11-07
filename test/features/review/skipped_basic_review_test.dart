import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/export/new_card_dialog.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/review_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('skipped review creates a basic card from another question', (
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
      reasoning: '',
      distracted: false,
    );

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
    );
    await pumpFrames(tester);

    await tester.scrollUntilVisible(
      find.text('Another question'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);
    await tester.tap(find.text('Another question'));
    await pumpFrames(tester);
    final fields = find.byType(EditableText);
    expect(fields, findsNWidgets(2));
    await tester.ensureVisible(fields.at(0));
    await tester.enterText(fields.at(0), 'What is the right answer?');
    await tester.ensureVisible(fields.at(1));
    await tester.enterText(fields.at(1), 'Correct 1');
    await pumpFrames(tester);

    expect(find.textContaining('Fill in both'), findsNothing);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await pumpFrames(tester, frames: 24);

    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
    expect(cards!.single.question, 'What is the right answer?');
    expect(cards.single.answer, 'Correct 1');
  });

  testWidgets('card dialog accepts basic fields after switching from concept', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    NewCardDraft? draft;

    await pumpTestApp(
      tester,
      harness: harness,
      home: Scaffold(
        body: Builder(
          builder: (context) => M3EButton.filled(
            onPressed: () async {
              draft = await showNewCardDialog(
                context,
                contextText: 'Selected context',
                initialTerm: 'managed service',
                initialQuestion: 'What is this?',
                initialKind: NewCardKind.concept,
              );
            },
            child: const Text('Open card dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open card dialog'));
    await pumpFrames(tester);
    await tester.tap(find.text('Basic card'));
    await pumpFrames(tester);

    final fields = find.byType(EditableText);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(1), 'A service run by the provider.');
    await pumpFrames(tester);

    await tester.tap(find.text('Create'));
    await pumpFrames(tester);

    expect(draft, isNotNull);
    expect(draft!.kind, NewCardKind.basic);
    expect(draft!.question, 'What is this?');
    expect(draft!.answer, 'A service run by the provider.');
  });
}
