import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/errors/error_cards_review_page.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';
import 'package:question_practice/features/review/domain/review_service.dart';
import 'package:question_practice/features/review/review_shell.dart';
import 'package:question_practice/features/feedback/question_feedback_view.dart';

import '../../helpers/test_harness.dart';

const _aiSettings = AppSettings(
  lookupMode: LookupMode.ai,
  aiModel: 'test-model',
  aiBaseUrl: 'https://example.test/v1',
);

Future<({ErrorCard card, Question question})> _seedCard(
  TestHarness harness, {
  String reasoning =
      'I confused the network and transport layers.\n'
      'I read reliable as secure.',
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

SkippedQuestion _skippedQuestion(
  TestHarness harness,
  Question question, {
  int id = 1,
}) {
  return SkippedQuestion(
    id: id,
    sessionId: null,
    questionId: question.id,
    question: question.prompt,
    alternatives: question.alternatives,
    correctIndexes: question.correctIndexes,
    explanation: question.explanation,
    alternativeExplanations: question.alternativeExplanations,
    reasoning: 'I guessed.',
    topicName: 'Topic',
    practiceName: 'Practice',
    unknown: false,
    createdAt: harness.clock.now().toUtc(),
    handledAt: null,
    handledKind: null,
  );
}

Future<void> _openBulletMenu(WidgetTester tester, int index) async {
  final more = find.byKey(ValueKey('wrong-note-more-$index'));
  await tester.ensureVisible(more);
  await pumpFrames(tester);
  await tester.tap(more);
  await pumpFrames(tester);
}

Finder _bulletCard(int index) => find.byKey(ValueKey('wrong-note-card-$index'));

Future<void> _openNoteMenu(WidgetTester tester, int noteId) async {
  final more = find.byKey(ValueKey('feedback-note-more-$noteId'));
  await tester.ensureVisible(more);
  await pumpFrames(tester);
  await tester.tap(more);
  await pumpFrames(tester);
}

Finder _noteCard(int noteId) =>
    find.byKey(ValueKey('feedback-note-card-$noteId'));

Future<void> _dismissMenu(WidgetTester tester) async {
  await tester.tapAt(const Offset(2, 2));
  await pumpFrames(tester);
}

bool _menuItemEnabled(WidgetTester tester, Finder item) {
  final row = find.ancestor(of: item, matching: find.byType(M3ETappable));
  return tester.widget<M3ETappable>(row).enabled;
}

String _field(WidgetTester tester, String key) {
  return tester
      .widget<M3ETextField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

http.Response _cardResponse(String front, String back) {
  return http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({
              'cards': [
                {'type': 'contrast', 'front': front, 'back': back},
              ],
            }),
          },
        },
      ],
    }),
    200,
  );
}

http.Response _ideaResponse({
  String front = 'Why does the network layer own addressing?',
  String back = 'It routes packets between hosts.',
}) {
  return http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({
              'ideas': [
                {
                  'template': 'contrast',
                  'variants': [
                    {'front': front, 'back': back},
                  ],
                },
              ],
            }),
          },
        },
      ],
    }),
    200,
  );
}

Future<void> _openCreator(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('review-create-fab')));
  await pumpFrames(tester);
  await expandCardCreatorSheet(tester);
}

Future<void> _closeCreator(WidgetTester tester) async {
  final close = find.byKey(const ValueKey('creator-close'));
  await tester.ensureVisible(close);
  await pumpFrames(tester);
  await tester.tap(close);
  await pumpFrames(tester, frames: 24);
}

Future<void> _enterDraft(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('creator-front')),
    'Which layer owns IP addresses?',
  );
  await tester.enterText(
    find.byKey(const ValueKey('creator-back')),
    'The network layer owns addressing.',
  );
  await pumpFrames(tester);
  await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
  await pumpFrames(tester);
  await tester.tap(find.byKey(const ValueKey('creator-add')));
  await pumpFrames(tester);
}

void main() {
  testWidgets('error review is one full-width reading surface with one dock', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    expect(find.byType(ReviewShell), findsOneWidget);
    expect(find.byType(CardCreatorPane), findsNothing);
    expect(find.byType(CardCreatorSheet), findsNothing);
    expect(find.byType(QuestionFeedbackView), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-create-fab')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-next')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-dock-delete')), findsNothing);
    expect(find.text('Save and finish'), findsOneWidget);
    expect(find.text('Create cards'), findsNothing);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('the create action opens the creator as a bottom sheet', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openCreator(tester);
    expect(find.byType(CardCreatorSheet), findsOneWidget);
    expect(find.byType(CardCreatorPane), findsNothing);
    expect(find.byKey(const ValueKey('creator-save')), findsNothing);
    expect(find.byKey(const ValueKey('creator-context')), findsNothing);
    expect(find.text('From this error'), findsNothing);
  });

  testWidgets('a bullet seeds the creator with a manual fallback', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openBulletMenu(tester, 0);
    await tester.tap(_bulletCard(0));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);

    expect(
      _field(tester, 'creator-front'),
      'I confused the network and transport layers.',
    );
    expect(_field(tester, 'creator-back'), isEmpty);
    expect(find.byKey(const ValueKey('creator-seed-hint')), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-seed-error')), findsNothing);
    expect(find.text('From this bullet'), findsNothing);
    expect(find.byKey(const ValueKey('creator-context')), findsNothing);
  });

  testWidgets('a bullet AI draft fills the fields and picks its template', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final harness = TestHarness(httpClient: MockClient((_) => response.future));
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openBulletMenu(tester, 0);
    await tester.tap(_bulletCard(0));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    expect(find.byKey(const ValueKey('creator-seed-loading')), findsOneWidget);
    expect(find.byTooltip('Turn this bullet into a card'), findsNothing);

    response.complete(
      _cardResponse(
        'How does the network layer differ from transport?',
        'The network layer addresses hosts; transport moves segments.',
      ),
    );
    await pumpFrames(tester, frames: 24);
    expect(find.byKey(const ValueKey('creator-seed-loading')), findsNothing);
    expect(
      _field(tester, 'creator-front'),
      'How does the network layer differ from transport?',
    );
    expect(
      _field(tester, 'creator-back'),
      'The network layer addresses hosts; transport moves segments.',
    );
    expect(find.text('Contrast'), findsWidgets);
  });

  testWidgets('a second bullet asks before replacing an edited draft', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openBulletMenu(tester, 0);
    await tester.tap(_bulletCard(0));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'My own answer.',
    );
    await pumpFrames(tester);
    await _closeCreator(tester);

    await _openBulletMenu(tester, 1);
    await tester.tap(_bulletCard(1));
    await pumpFrames(tester);
    expect(find.text('Replace the draft you started?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await pumpFrames(tester);
    await _openCreator(tester);
    expect(
      _field(tester, 'creator-front'),
      'I confused the network and transport layers.',
    );
    await _closeCreator(tester);

    await _openBulletMenu(tester, 1);
    await tester.tap(_bulletCard(1));
    await pumpFrames(tester);
    await tester.tap(find.text('Replace'));
    await pumpFrames(tester);
    expect(_field(tester, 'creator-front'), 'I read reliable as secure.');
  });

  testWidgets('a bullet menu card action tracks the added state', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openBulletMenu(tester, 0);
    await tester.tap(_bulletCard(0));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);

    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'The network layer owns addressing.',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await _closeCreator(tester);

    await _openBulletMenu(tester, 0);
    expect(find.text('Card created'), findsOneWidget);
    expect(find.text('Create card with AI'), findsNothing);
    expect(_menuItemEnabled(tester, _bulletCard(0)), isFalse);
    await _dismissMenu(tester);

    await _openCreator(tester);
    final remove = find.byIcon(Icons.delete_outline);
    await tester.ensureVisible(remove);
    await pumpFrames(tester);
    await tester.tap(remove);
    await pumpFrames(tester);
    await _closeCreator(tester);

    await _openBulletMenu(tester, 0);
    expect(find.text('Create card with AI'), findsOneWidget);
    expect(find.text('Card created'), findsNothing);
    expect(_menuItemEnabled(tester, _bulletCard(0)), isTrue);
    await _dismissMenu(tester);
  });

  testWidgets('drafts stay with their item across close and step changes', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final first = await _seedCard(harness);
    final second = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [first.card, second.card]),
      harness: harness,
    );

    await _openCreator(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'Typed front?',
    );
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'Typed back.',
    );
    await pumpFrames(tester);
    await _closeCreator(tester);

    await _openCreator(tester);
    expect(_field(tester, 'creator-front'), 'Typed front?');
    expect(_field(tester, 'creator-back'), 'Typed back.');
    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    expect(find.text('Cards to save · 1'), findsOneWidget);
    await _closeCreator(tester);

    await tester.tap(find.byKey(const ValueKey('review-dock-next')));
    await pumpFrames(tester);
    expect(find.text('Item 2 of 2'), findsOneWidget);

    await _openCreator(tester);
    expect(find.byKey(const ValueKey('creator-draft-0')), findsNothing);
    expect(_field(tester, 'creator-front'), isEmpty);
    await _closeCreator(tester);

    await tester.tap(find.byKey(const ValueKey('review-dock-back')));
    await pumpFrames(tester);
    await _openCreator(tester);
    expect(find.byKey(const ValueKey('creator-draft-0')), findsOneWidget);
    expect(_field(tester, 'creator-front'), isEmpty);
  });

  testWidgets('system back keeps the typed creator draft for its item', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openCreator(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'Survives system back?',
    );
    await tester.enterText(find.byKey(const ValueKey('creator-back')), 'Yes.');
    await pumpFrames(tester);

    await tester.binding.handlePopRoute();
    await pumpFrames(tester, frames: 24);
    expect(find.byType(CardCreatorSheet), findsNothing);

    await _openCreator(tester);
    expect(_field(tester, 'creator-front'), 'Survives system back?');
    expect(_field(tester, 'creator-back'), 'Yes.');
  });

  testWidgets('dragging the sheet down keeps the typed creator draft', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openCreator(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'Survives drag down?',
    );
    await tester.enterText(find.byKey(const ValueKey('creator-back')), 'Yes.');
    await pumpFrames(tester);

    final semantics = tester.ensureSemantics();
    await tester.drag(
      find.bySemanticsLabel('Drag handle'),
      const Offset(0, 900),
    );
    semantics.dispose();
    await pumpFrames(tester, frames: 24);
    expect(find.byType(CardCreatorSheet), findsNothing);

    await _openCreator(tester);
    expect(_field(tester, 'creator-front'), 'Survives drag down?');
    expect(_field(tester, 'creator-back'), 'Yes.');
  });

  testWidgets('edited bullet drafts guard a new seed after a step change', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final first = await _seedCard(harness);
    final second = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [first.card, second.card]),
      harness: harness,
    );

    await _openBulletMenu(tester, 0);
    await tester.tap(_bulletCard(0));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'My own answer.',
    );
    await pumpFrames(tester);
    await _closeCreator(tester);

    await tester.tap(find.byKey(const ValueKey('review-dock-next')));
    await pumpFrames(tester);
    expect(find.text('Item 2 of 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('review-dock-back')));
    await pumpFrames(tester);

    await _openBulletMenu(tester, 1);
    await tester.tap(_bulletCard(1));
    await pumpFrames(tester);
    expect(find.text('Replace the draft you started?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await pumpFrames(tester);

    await _openCreator(tester);
    expect(
      _field(tester, 'creator-front'),
      'I confused the network and transport layers.',
    );
    expect(_field(tester, 'creator-back'), 'My own answer.');
  });

  testWidgets(
    'an AI draft filled into the composer still guards the dock Save',
    (tester) async {
      final harness = TestHarness(
        httpClient: MockClient(
          (_) async => _cardResponse(
            'Which layer owns IP addresses?',
            'The network layer owns addressing.',
          ),
        ),
      );
      addTearDown(harness.close);
      await harness.settings.save(_aiSettings);
      await harness.keyStore.writeApiKey('secret-key');
      final seeded = await _seedCard(harness);

      await pumpTestApp(
        tester,
        home: ErrorCardsReviewPage(cards: [seeded.card]),
        harness: harness,
      );

      await _openBulletMenu(tester, 0);
      await tester.tap(_bulletCard(0));
      await pumpFrames(tester);
      await expandCardCreatorSheet(tester);
      await pumpFrames(tester, frames: 24);
      expect(_field(tester, 'creator-front'), 'Which layer owns IP addresses?');
      await _closeCreator(tester);

      await tester.tap(find.byKey(const ValueKey('review-dock-save')));
      await pumpFrames(tester);
      expect(
        find.text('Add this card to the list before saving.'),
        findsOneWidget,
      );
      await expandCardCreatorSheet(tester);
      expect(_field(tester, 'creator-front'), 'Which layer owns IP addresses?');
    },
  );

  testWidgets('saving from the dock uses the cached drafts and advances', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final first = await _seedCard(harness);
    final second = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [first.card, second.card]),
      harness: harness,
    );

    await _openCreator(tester);
    await _enterDraft(tester);
    await _closeCreator(tester);
    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Item 2 of 2'), findsOneWidget);
    final cards = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(cards, hasLength(1));
  });

  testWidgets('a typed card that was not added guards the dock Save', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final first = await _seedCard(harness);
    final second = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [first.card, second.card]),
      harness: harness,
    );

    await _openCreator(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'Not added yet?',
    );
    await pumpFrames(tester);
    await _closeCreator(tester);
    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
    await pumpFrames(tester);

    expect(
      find.text('Add this card to the list before saving.'),
      findsOneWidget,
    );
    await expandCardCreatorSheet(tester);
    expect(find.byType(CardCreatorSheet), findsOneWidget);
    expect(_field(tester, 'creator-front'), 'Not added yet?');
  });

  testWidgets('a note seeded card saves through the review dock', (
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

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openNoteMenu(tester, noteId);
    await tester.tap(_noteCard(noteId));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    expect(find.text('From this note'), findsNothing);
    expect(
      tester
          .widget<M3ETextField>(
            find.byKey(const ValueKey('creator-definition-cloze')),
          )
          .controller!
          .text,
      contains('a managed service removes host maintenance'),
    );

    await tester.enterText(
      find.byKey(const ValueKey('creator-definition-cloze')),
      'Definition of {{c1::managed service}}: '
      '{{c2::A service run by the provider.}}',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await _closeCreator(tester);
    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
    await pumpFrames(tester, frames: 24);

    final notes = await tester.runAsync(
      () => harness.cards.notesForQuestion(seeded.question.id),
    );
    expect(notes!.single.hasCard, isTrue);
    final concepts = await tester.runAsync(
      () => harness.cards.watchConcepts().first,
    );
    expect(concepts, hasLength(1));
  });

  testWidgets('a skipped step uses the same shell and creator sheet', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(
        cards: const [],
        skippedQuestions: [_skippedQuestion(harness, seeded.question)],
      ),
      harness: harness,
    );

    expect(find.byType(ReviewShell), findsOneWidget);
    expect(find.text('Review the skipped question'), findsOneWidget);
    expect(find.text('What was missing?'), findsNothing);
    expect(find.byKey(const ValueKey('review-create-fab')), findsOneWidget);
    expect(find.text('Save and finish'), findsOneWidget);
    await _openCreator(tester);
    expect(find.byType(CardCreatorSheet), findsOneWidget);
  });

  testWidgets('a late AI reply cannot refill a composer after Add to list', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final harness = TestHarness(httpClient: MockClient((_) => response.future));
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openBulletMenu(tester, 0);
    await tester.tap(_bulletCard(0));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    expect(find.byKey(const ValueKey('creator-seed-loading')), findsOneWidget);

    await _enterDraft(tester);
    response.complete(_cardResponse('Late AI front', 'Late AI back'));
    await pumpFrames(tester, frames: 24);

    expect(_field(tester, 'creator-front'), isEmpty);
    expect(_field(tester, 'creator-back'), isEmpty);
    expect(find.byKey(const ValueKey('creator-seed-loading')), findsNothing);
  });

  testWidgets('typing during an AI draft still guards the next bullet', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final harness = TestHarness(httpClient: MockClient((_) => response.future));
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openBulletMenu(tester, 0);
    await tester.tap(_bulletCard(0));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'My own answer.',
    );
    await pumpFrames(tester);
    await _closeCreator(tester);

    response.complete(
      _cardResponse(
        'How does the network layer differ?',
        'It addresses hosts.',
      ),
    );
    await pumpFrames(tester, frames: 24);

    await _openBulletMenu(tester, 1);
    await tester.tap(_bulletCard(1));
    await pumpFrames(tester);
    expect(find.text('Replace the draft you started?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await pumpFrames(tester, frames: 24);
    expect(_field(tester, 'creator-back'), 'It addresses hosts.');
  });

  testWidgets('a failed dock save keeps the remaining draft and stays', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final first = await _seedCard(harness);
    final second = await _seedCard(harness);
    final service = _ControlledReviewService(harness)..failOnCall = 2;

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [first.card, second.card]),
      harness: harness,
      overrides: [reviewServiceProvider.overrideWithValue(service)],
    );

    await _openCreator(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'First saved?',
    );
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'First answer.',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-front')),
      'Second stays?',
    );
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'Second answer.',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await _closeCreator(tester);

    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(
      find.textContaining('1 card saved, but the rest could not be saved'),
      findsOneWidget,
    );
    await _openCreator(tester);
    expect(find.text('Cards to save · 1'), findsOneWidget);
  });

  testWidgets(
    'a dock save that completes cards but not details retries without duplicates',
    (tester) async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await _seedCard(harness, complete: false);
      final service = _ControlledReviewService(harness)..failCompleteOnCall = 1;

      await pumpTestApp(
        tester,
        home: ErrorCardsReviewPage(cards: [seeded.card]),
        harness: harness,
        overrides: [reviewServiceProvider.overrideWithValue(service)],
      );

      await _openCreator(tester);
      await _enterDraft(tester);
      await _closeCreator(tester);

      await tester.tap(find.byKey(const ValueKey('review-dock-save')));
      await pumpFrames(tester, frames: 24);

      expect(find.text('Complete the error card'), findsOneWidget);
      expect(
        find.textContaining(
          '1 card saved, but this item could not be completed',
        ),
        findsOneWidget,
      );
      expect(service.completeCalls, 1);

      // Let the failure snackbar clear so it no longer covers the dock.
      await tester.pump(const Duration(seconds: 5));
      await pumpFrames(tester, frames: 4);
      await tester.tap(find.byKey(const ValueKey('review-dock-save')));
      await pumpFrames(tester, frames: 24);

      expect(service.completeCalls, 2);
      expect(find.text('Review complete'), findsWidgets);
      final manuals = await tester.runAsync(
        () => harness.cards.watchManualCards().first,
      );
      expect(manuals, hasLength(1));
      final completed = await tester.runAsync(
        () => harness.cards.errorCardById(seeded.card.id),
      );
      expect(completed!.needsDetails, isFalse);
    },
  );

  testWidgets('a bullet that replaces a note seed does not convert the note', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);
    final noteId = await harness.cards.createNote(
      sessionId: null,
      questionId: seeded.question.id,
      text: 'managed service',
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
    await tester.tap(_noteCard(noteId));
    await pumpFrames(tester);
    await expandCardCreatorSheet(tester);
    await _closeCreator(tester);

    await _openBulletMenu(tester, 0);
    await tester.tap(_bulletCard(0));
    await pumpFrames(tester, frames: 24);
    expect(find.text('Replace the draft you started?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await pumpFrames(tester, frames: 24);
    await expandCardCreatorSheet(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-back')));
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'They are different layers.',
    );
    await pumpFrames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('creator-add')));
    await pumpFrames(tester);
    await _closeCreator(tester);

    await tester.tap(find.byKey(const ValueKey('review-dock-save')));
    await pumpFrames(tester, frames: 24);

    final notes = await tester.runAsync(() => harness.cards.watchNotes().first);
    expect(notes!.single.hasCard, isFalse);
    final manuals = await tester.runAsync(
      () => harness.cards.watchManualCards().first,
    );
    expect(manuals, hasLength(1));
  });

  testWidgets('AI results stay with their item across steps', (tester) async {
    final harness = TestHarness(
      httpClient: MockClient((_) async => _ideaResponse()),
    );
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final first = await _seedCard(harness);
    final second = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [first.card, second.card]),
      harness: harness,
    );

    await _openCreator(tester);
    final suggest = find.byKey(const ValueKey('creator-ai-suggest'));
    await tester.ensureVisible(suggest);
    await pumpFrames(tester);
    await tester.tap(suggest);
    await pumpFrames(tester, frames: 24);
    expect(find.byKey(const ValueKey('creator-ai-idea-0')), findsOneWidget);
    await _closeCreator(tester);

    await tester.tap(find.byKey(const ValueKey('review-dock-next')));
    await pumpFrames(tester);
    await _openCreator(tester);
    expect(find.byKey(const ValueKey('creator-ai-idea-0')), findsNothing);
    await _closeCreator(tester);

    await tester.tap(find.byKey(const ValueKey('review-dock-back')));
    await pumpFrames(tester);
    await _openCreator(tester);
    expect(find.byKey(const ValueKey('creator-ai-idea-0')), findsOneWidget);
    expect(
      find.text('Why does the network layer own addressing?'),
      findsOneWidget,
    );
  });

  testWidgets('closing during an AI request reopens with the panel closed', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final harness = TestHarness(httpClient: MockClient((_) => response.future));
    addTearDown(harness.close);
    await harness.settings.save(_aiSettings);
    await harness.keyStore.writeApiKey('secret-key');
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    await _openCreator(tester);
    final suggest = find.byKey(const ValueKey('creator-ai-suggest'));
    await tester.ensureVisible(suggest);
    await pumpFrames(tester);
    await tester.tap(suggest);
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('creator-ai-loading')), findsOneWidget);
    await _closeCreator(tester);

    await _openCreator(tester);
    expect(find.byKey(const ValueKey('creator-ai-section')), findsNothing);
    await tester.ensureVisible(suggest);
    await pumpFrames(tester);
    await tester.tap(suggest);
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('creator-ai-loading')), findsOneWidget);
    response.complete(_ideaResponse());
    await pumpFrames(tester, frames: 60);
    expect(find.byKey(const ValueKey('creator-ai-idea-0')), findsOneWidget);
  });

  for (final config in const [
    (label: '320 dp', size: Size(320, 640), scale: 1.0),
    (label: '360 dp at 2.0', size: Size(360, 800), scale: 2.0),
    (label: '640 dp landscape', size: Size(640, 360), scale: 1.0),
    (label: '720 dp tablet', size: Size(720, 1024), scale: 1.0),
    (label: '720 dp at 2.0', size: Size(720, 1024), scale: 2.0),
  ]) {
    testWidgets('the review shell and creator fit ${config.label}', (
      tester,
    ) async {
      tester.view.physicalSize = config.size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = config.scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await _seedCard(
        harness,
        reasoning:
            'A long wrong-answer bullet that has to wrap cleanly without '
            'pushing the reading surface out of the window.\nSecond bullet.',
        distracted: true,
      );

      await pumpTestApp(
        tester,
        home: ErrorCardsReviewPage(cards: [seeded.card]),
        harness: harness,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CardCreatorPane), findsNothing);
      expect(find.byKey(const ValueKey('review-dock-save')), findsOneWidget);
      await _openCreator(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(CardCreatorSheet), findsOneWidget);
    });
  }
}

class _ControlledReviewService extends ReviewService {
  _ControlledReviewService(TestHarness harness)
    : super(
        practices: harness.practices,
        sessions: harness.sessions,
        cards: harness.cards,
        clock: harness.clock,
      );

  int calls = 0;
  int failOnCall = 0;
  int completeCalls = 0;
  int failCompleteOnCall = 0;

  @override
  Future<void> completeErrorDetails(int cardId) async {
    completeCalls++;
    if (completeCalls == failCompleteOnCall) {
      throw StateError('could not complete details');
    }
    return super.completeErrorDetails(cardId);
  }

  @override
  Future<int> createBasicCard({
    required int? sessionId,
    required String question,
    required String answer,
    required String topicName,
    int? questionId,
    String context = '',
    int? skippedQuestionId,
    String subtopic = '',
    CognitiveType cognitiveType = CognitiveType.fact,
  }) async {
    calls++;
    if (calls == failOnCall) throw StateError('database offline');
    return super.createBasicCard(
      sessionId: sessionId,
      question: question,
      answer: answer,
      topicName: topicName,
      questionId: questionId,
      context: context,
      skippedQuestionId: skippedQuestionId,
      subtopic: subtopic,
      cognitiveType: cognitiveType,
    );
  }
}
