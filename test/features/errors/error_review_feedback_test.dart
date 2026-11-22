import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/errors/error_cards_review_page.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';
import 'package:question_practice/features/feedback/feedback_option_card.dart';
import 'package:question_practice/features/feedback/question_feedback_view.dart';

import '../../helpers/test_harness.dart';

const _aiSettings = AppSettings(
  lookupMode: LookupMode.ai,
  aiModel: 'test-model',
  aiBaseUrl: 'https://example.test/v1',
);

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

Future<void> _openNoteMenu(WidgetTester tester, int noteId) async {
  final more = find.byKey(ValueKey('feedback-note-more-$noteId'));
  await tester.ensureVisible(more);
  await pumpFrames(tester);
  await tester.tap(more);
  await pumpFrames(tester);
}

Finder _noteAction(int noteId, String action) =>
    find.byKey(ValueKey('feedback-note-$action-$noteId'));

Future<void> _openBulletMenu(WidgetTester tester, int index) async {
  final more = find.byKey(ValueKey('wrong-answer-bullets-more-$index'));
  await tester.ensureVisible(more);
  await pumpFrames(tester);
  await tester.tap(more);
  await pumpFrames(tester);
}

Finder _bulletAction(int index, String action) =>
    find.byKey(ValueKey('wrong-answer-bullets-$action-$index'));

bool _menuItemEnabled(WidgetTester tester, Finder item) {
  final row = find.ancestor(of: item, matching: find.byType(M3ETappable));
  return tester.widget<M3ETappable>(row).enabled;
}

Future<void> _dismissMenu(WidgetTester tester) async {
  await tester.tapAt(const Offset(2, 2));
  await pumpFrames(tester);
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
      expect(
        find.byKey(const ValueKey('wrong-answer-bullets-list')),
        findsOneWidget,
      );
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
    expect(
      find.byKey(const ValueKey('wrong-answer-bullets-list')),
      findsOneWidget,
    );
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

    await _openNoteMenu(tester, noteId);
    await tester.tap(_noteAction(noteId, 'copy'));
    await pumpFrames(tester);
    expect(copied, 'a managed service removes host maintenance');
    expect(find.text('Note copied.'), findsOneWidget);

    await _openNoteMenu(tester, noteId);
    await tester.tap(_noteAction(noteId, 'card'));
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
    expect(find.byType(CardCreatorPane), findsNothing);
    expect(find.byKey(const ValueKey('review-create-fab')), findsOneWidget);
  });

  testWidgets('error review note actions never offer delete', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);
    final noteId = await harness.cards.createNote(
      sessionId: seeded.card.sessionId,
      questionId: seeded.question.id,
      text: 'keep this note in Cards',
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

    expect(find.text('Define'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('Delete note?'), findsNothing);

    final notes = await tester.runAsync(
      () => harness.cards.notesForQuestion(seeded.question.id),
    );
    expect(notes, hasLength(1));
    expect(find.byKey(ValueKey('feedback-note-$noteId')), findsOneWidget);
  });

  testWidgets('a saved note opens one compact action menu', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
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

    final noteMore = find.byKey(ValueKey('feedback-note-more-$noteId'));
    expect(noteMore, findsOneWidget);
    expect(tester.getSemantics(noteMore).label, 'Note actions');
    expect(_noteAction(noteId, 'copy'), findsNothing);
    expect(_noteAction(noteId, 'card'), findsNothing);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Create card'), findsNothing);

    await _openNoteMenu(tester, noteId);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Create card'), findsOneWidget);
    expect(find.text('Define'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Ask'), findsNothing);
    expect(_noteAction(noteId, 'copy'), findsOneWidget);
    expect(_noteAction(noteId, 'card'), findsOneWidget);
    expect(_noteAction(noteId, 'delete'), findsNothing);
    await _dismissMenu(tester);
  });

  testWidgets('the note menu offers Ask only with an AI provider', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
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

    await _openNoteMenu(tester, noteId);
    expect(find.text('Ask'), findsOneWidget);
    expect(_noteAction(noteId, 'ask'), findsOneWidget);
    await _dismissMenu(tester);
  });

  testWidgets('a note with a card shows a disabled Card created row', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
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
    await harness.cards.markNoteConverted(
      noteId,
      cardCreatedAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openNoteMenu(tester, noteId);
    expect(find.text('Card created'), findsOneWidget);
    expect(find.text('Create card'), findsNothing);
    expect(_menuItemEnabled(tester, _noteAction(noteId, 'card')), isFalse);
    await _dismissMenu(tester);
  });

  testWidgets('a bullet menu copies the bullet and seeds its AI card', (
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

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    final firstMore = find.byKey(const ValueKey('wrong-answer-bullets-more-0'));
    expect(firstMore, findsOneWidget);
    expect(
      find.byKey(const ValueKey('wrong-answer-bullets-more-1')),
      findsOneWidget,
    );
    expect(tester.getSemantics(firstMore).label, 'Bullet actions');
    expect(_bulletAction(0, 'copy'), findsNothing);
    expect(_bulletAction(0, 'card'), findsNothing);

    await _openBulletMenu(tester, 0);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Create card with AI'), findsOneWidget);
    expect(_bulletAction(0, 'copy'), findsOneWidget);
    expect(_bulletAction(0, 'card'), findsOneWidget);

    await tester.tap(_bulletAction(0, 'copy'));
    await pumpFrames(tester);
    expect(copied, 'I confused the network and transport layers.');
    expect(find.text('Bullet copied.'), findsOneWidget);
  });

  testWidgets('note and bullet menus fit 320 dp at 2.0 text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);
    final noteId = await harness.cards.createNote(
      sessionId: seeded.card.sessionId,
      questionId: seeded.question.id,
      text: 'A narrow note that has to wrap.',
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

    await _openNoteMenu(tester, noteId);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Create card'), findsOneWidget);
    expect(find.text('Define'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(tester.takeException(), isNull);
    await _dismissMenu(tester);

    await _openBulletMenu(tester, 0);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Create card with AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dismissMenu(tester);
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
    expect(find.byType(CardCreatorPane), findsNothing);
    expect(
      find.byKey(const ValueKey('wrong-answer-bullets-list')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('review-dock-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
