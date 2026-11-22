import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/features/export/cards_page.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets(
    'Cards reviews a pending error, saves a card and clears the selection',
    (tester) async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await harness.seedPractice(count: 1);
      final question = (await harness.practices.questionsForPractice(
        seeded.practiceId,
      )).single;
      final errorCardId = await harness.cards.createErrorCard(
        questionId: question.id,
        sessionId: null,
        question: question.prompt,
        alternatives: question.alternatives,
        correctIndexes: question.correctIndexes,
        wrongIndexes: const [1],
        reasoning: 'I mixed up the layers.',
        explanation: question.explanation,
        alternativeExplanations: question.alternativeExplanations,
        topicName: 'Topic',
        practiceName: 'Practice',
        lastWrongAt: harness.clock.now().toUtc(),
        dueAfter: const Duration(hours: 48),
      );

      await pumpTestApp(tester, home: const CardsPage(), harness: harness);

      final errorRow = find.byKey(ValueKey('error-row-$errorCardId'));
      await tester.ensureVisible(errorRow);
      await pumpFrames(tester);
      await tester.longPress(errorRow);
      await pumpFrames(tester);

      expect(find.text('1 selected · review to export'), findsOneWidget);
      await tester.tap(find.text('Review pending'));
      await pumpFrames(tester, frames: 24);
      expect(find.text('Complete the error card'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('review-create-fab')));
      await pumpFrames(tester);
      await expandCardCreatorSheet(tester);
      await tester.enterText(
        find.byKey(const ValueKey('creator-front')),
        'Which layer owns addressing?',
      );
      await tester.enterText(
        find.byKey(const ValueKey('creator-back')),
        'The network layer.',
      );
      await pumpFrames(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
      await pumpFrames(tester);
      await tester.tap(find.byKey(const ValueKey('creator-add')));
      await pumpFrames(tester);
      final close = find.byKey(const ValueKey('creator-close'));
      await tester.ensureVisible(close);
      await tester.tap(close);
      await pumpFrames(tester, frames: 24);

      await tester.tap(find.byKey(const ValueKey('review-dock-save')));
      await pumpFrames(tester, frames: 24);

      expect(find.text('Review complete'), findsWidgets);
      final completed = await tester.runAsync(
        () => harness.cards.errorCardById(errorCardId),
      );
      expect(completed!.needsDetails, isFalse);
      final manuals = await tester.runAsync(
        () => harness.cards.watchManualCards().first,
      );
      expect(manuals, hasLength(1));

      await tester.tap(find.text('Done'));
      await pumpFrames(tester, frames: 24);

      expect(find.text('Ready for AnkiDroid'), findsOneWidget);
      expect(find.textContaining('Basic cards ·'), findsOneWidget);
      final selection = await tester.runAsync(
        () => harness.settings.loadCardsSelection(),
      );
      expect(selection, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cards previews a note, reviews it with context and finishes with Save',
    (tester) async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await harness.seedPractice(count: 1);
      final question = (await harness.practices.questionsForPractice(
        seeded.practiceId,
      )).single;
      final noteId = await harness.cards.createNote(
        sessionId: null,
        questionId: question.id,
        text: 'managed service',
        context: question.prompt,
        topicName: 'Topic',
        practiceName: 'Practice',
        createdAt: harness.clock.now().toUtc(),
      );

      await pumpTestApp(tester, home: const CardsPage(), harness: harness);

      final noteRow = find.byKey(ValueKey('note-row-$noteId'));
      await tester.ensureVisible(noteRow);
      await pumpFrames(tester);
      await tester.tap(noteRow);
      await pumpFrames(tester);

      expect(find.text('Note preview'), findsOneWidget);
      expect(find.text('SAVED NOTE'), findsOneWidget);
      await tester.tap(find.text('Review'));
      await pumpFrames(tester, frames: 24);

      expect(find.text('Save and finish'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-see-context')));
      await pumpFrames(tester);
      expect(find.text('Original question'), findsOneWidget);
      expect(find.text(question.prompt), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await pumpFrames(tester, frames: 24);

      await tester.tap(find.byKey(const ValueKey('review-dock-save')));
      await pumpFrames(tester, frames: 24);

      expect(find.text('Note review complete'), findsWidgets);
      final notes = await tester.runAsync(
        () => harness.cards.watchNotes().first,
      );
      expect(notes!.single.isKept, isTrue);
    },
  );
}
