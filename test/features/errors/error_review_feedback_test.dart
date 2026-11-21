import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/adaptive_split_view.dart';
import 'package:question_practice/features/errors/error_cards_review_page.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';
import 'package:question_practice/features/feedback/feedback_option_card.dart';
import 'package:question_practice/features/feedback/question_feedback_view.dart';

import '../../helpers/test_harness.dart';

Future<({ErrorCard card, Question question})> _seedCard(
  TestHarness harness, {
  String reasoning = 'I confused the network and transport layers.\nI read reliable as secure.',
  bool distracted = false,
  bool complete = true,
}) async {
  final seeded = await harness.seedPractice(count: 1);
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
    reasoning: reasoning,
    explanation: question.explanation,
    alternativeExplanations: question.alternativeExplanations,
    topicName: 'Topic',
    practiceName: 'Practice',
    subtopic: 'Layers',
    distracted: distracted,
    lastWrongAt: harness.clock.now().toUtc(),
    dueAfter: const Duration(hours: 48),
  );
  if (complete) {
    await harness.cards.completeErrorCardDetails(
      id,
      harness.clock.now().toUtc(),
    );
  }
  return (card: (await harness.cards.errorCardById(id))!, question: question);
}

void main() {
  testWidgets(
    'error review shows read-only bullets and the distraction warning',
    (tester) async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await _seedCard(harness, distracted: true);

      await pumpTestApp(
        tester,
        home: ErrorCardsReviewPage(cards: [seeded.card]),
        harness: harness,
      );

      expect(find.byType(QuestionFeedbackView), findsOneWidget);
      expect(find.byType(FeedbackOptionCard), findsNWidgets(2));
      expect(find.byKey(const ValueKey('wrong-notes-list')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QuestionFeedbackView),
          matching: find.byType(EditableText),
        ),
        findsNothing,
      );
      expect(
        find.text('I confused the network and transport layers.'),
        findsOneWidget,
      );
      expect(find.text('I read reliable as secure.'), findsOneWidget);
      expect(
        find.text('You were distracted or misread. This card stays due.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('feedback-distraction-warning')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('error-card-edit-content')),
        findsNothing,
      );
      expect(find.text('Edit question and options'), findsNothing);
    },
  );

  testWidgets('a card that was not distracted hides the warning', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness, distracted: false);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    expect(
      find.byKey(const ValueKey('feedback-distraction-warning')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('wrong-notes-list')), findsOneWidget);
  });

  testWidgets('notes can be copied and seed the existing card creator', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final seeded = await _seedCard(harness);
    final noteId = await harness.cards.createNote(
      sessionId: seeded.card.sessionId,
      questionId: seeded.question.id,
      text: 'a managed service removes host maintenance',
      context: seeded.question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    expect(find.byKey(const ValueKey('feedback-notes')), findsOneWidget);
    expect(find.byKey(ValueKey('feedback-note-$noteId')), findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(ValueKey('feedback-note-copy-$noteId')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(ValueKey('feedback-note-copy-$noteId')));
    await pumpFrames(tester);
    expect(copied, 'a managed service removes host maintenance');
    expect(find.text('Note copied.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(ValueKey('feedback-note-card-$noteId')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(ValueKey('feedback-note-card-$noteId')));
    await pumpFrames(tester);
    expect(find.byType(CardCreatorSheet), findsOneWidget);
    expect(find.byType(CardCreatorPane), findsNothing);
    expect(find.text('From this note'), findsNothing);
    expect(find.byKey(const ValueKey('creator-context')), findsNothing);
    expect(find.byKey(const ValueKey('creator-seed-hint')), findsOneWidget);

    final cloze = tester.widget<M3ETextField>(
      find.byKey(const ValueKey('creator-definition-cloze')),
    );
    expect(
      cloze.controller!.text,
      contains('a managed service removes host maintenance'),
    );
  });

  testWidgets('the old error content editor is unreachable', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    expect(find.byKey(const ValueKey('error-card-edit-content')), findsNothing);
    expect(find.text('Edit card content'), findsNothing);
    expect(find.byType(AdaptiveSplitView), findsNothing);
    expect(find.byType(CardCreatorPane), findsNothing);
    expect(find.byKey(const ValueKey('review-dock-create')), findsOneWidget);
  });

  testWidgets('deleting a note from the error review asks first', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);
    final noteId = await harness.cards.createNote(
      sessionId: seeded.card.sessionId,
      questionId: seeded.question.id,
      text: 'keep this until I confirm',
      context: seeded.question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    final more = find.byKey(ValueKey('feedback-note-more-$noteId'));
    await tester.ensureVisible(more);
    await pumpFrames(tester);
    await tester.tap(more);
    await pumpFrames(tester);
    await tester.tap(find.text('Delete'));
    await pumpFrames(tester);

    expect(find.text('Delete note?'), findsOneWidget);
    expect(find.byKey(ValueKey('feedback-note-$noteId')), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await pumpFrames(tester, frames: 24);

    final notes = await tester.runAsync(
      () => harness.cards.notesForQuestion(seeded.question.id),
    );
    expect(notes, isEmpty);
    expect(find.byKey(ValueKey('feedback-note-$noteId')), findsNothing);
  });

  testWidgets('the review fits 360 dp at 2.0 text scale', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness, distracted: true);
    await harness.cards.createNote(
      sessionId: seeded.card.sessionId,
      questionId: seeded.question.id,
      text: 'A note that has to wrap on a narrow screen.',
      context: seeded.question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AdaptiveSplitView), findsNothing);
    expect(find.byType(CardCreatorPane), findsNothing);
    expect(find.byKey(const ValueKey('wrong-notes-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
