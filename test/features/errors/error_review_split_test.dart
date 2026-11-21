import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/adaptive_split_view.dart';
import 'package:question_practice/features/errors/error_cards_review_page.dart';
import 'package:question_practice/features/export/card_creator_sheet.dart';
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
  await harness.cards.completeErrorCardDetails(id, harness.clock.now().toUtc());
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

String _field(WidgetTester tester, String key) {
  return tester
      .widget<M3ETextField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}

Finder get _feedbackScroll {
  return find
      .descendant(
        of: find.byType(QuestionFeedbackView),
        matching: find.byType(Scrollable),
      )
      .first;
}

Finder get _creatorScroll {
  return find
      .descendant(
        of: find.byType(CardCreatorPane),
        matching: find.byType(Scrollable),
      )
      .first;
}

double _scrollOffset(WidgetTester tester, Finder scrollable) {
  return tester.state<ScrollableState>(scrollable).position.pixels;
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
  testWidgets('error review renders a split studio instead of a modal sheet', (
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

    expect(find.byType(AdaptiveSplitView), findsOneWidget);
    expect(find.byType(QuestionFeedbackView), findsOneWidget);
    expect(find.byType(CardCreatorPane), findsOneWidget);
    expect(find.byType(CardCreatorSheet), findsNothing);
    expect(find.byKey(AdaptiveSplitView.dividerKey), findsOneWidget);
    expect(find.text('Card creator'), findsOneWidget);
    expect(find.text('Turn bullet into card'), findsWidgets);

    final window = tester.getSize(find.byType(AdaptiveSplitView));
    final feedback = tester.getSize(find.byType(QuestionFeedbackView));
    final horizontal = window.width >= 720;
    final expected = horizontal
        ? (window.width - AdaptiveSplitView.dividerExtent) * 0.56
        : (window.height - AdaptiveSplitView.dividerExtent) * 0.52;
    expect(horizontal ? feedback.width : feedback.height, closeTo(expected, 2));
  });

  testWidgets('the divider drag changes the ratio and survives a step change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(
        cards: [seeded.card],
        skippedQuestions: [_skippedQuestion(harness, seeded.question)],
      ),
      harness: harness,
    );

    final initial = tester.getSize(find.byType(QuestionFeedbackView)).height;
    await tester.drag(
      find.byKey(AdaptiveSplitView.dividerKey),
      const Offset(0, -70),
    );
    await pumpFrames(tester);
    final dragged = tester.getSize(find.byType(QuestionFeedbackView)).height;
    expect(dragged, lessThan(initial));

    await tester.tap(find.text('Skip'));
    await pumpFrames(tester);
    expect(find.byType(AdaptiveSplitView), findsNothing);
    expect(find.text('Review the skipped question'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await pumpFrames(tester);
    expect(find.byType(AdaptiveSplitView), findsOneWidget);
    final restored = tester.getSize(find.byType(QuestionFeedbackView)).height;
    expect(restored, closeTo(dragged, 2));
  });

  testWidgets('both panes scroll independently', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(
      harness,
      reasoning: [
        'I confused the network and transport layers.',
        'I read reliable as secure.',
        'I forgot that addressing belongs to the network layer.',
      ].join('\n'),
    );

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    final feedback = _feedbackScroll;
    final creator = _creatorScroll;
    expect(_scrollOffset(tester, feedback), 0);
    expect(_scrollOffset(tester, creator), 0);

    await tester.drag(feedback, const Offset(0, -140));
    await pumpFrames(tester);
    expect(_scrollOffset(tester, feedback), greaterThan(0));
    expect(_scrollOffset(tester, creator), 0);

    final feedbackOffset = _scrollOffset(tester, feedback);
    await tester.drag(creator, const Offset(0, -140));
    await pumpFrames(tester);
    expect(_scrollOffset(tester, creator), greaterThan(0));
    expect(_scrollOffset(tester, feedback), closeTo(feedbackOffset, 0.1));
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

    final bullet = find.byKey(const ValueKey('wrong-note-card-0'));
    await tester.ensureVisible(bullet);
    await pumpFrames(tester);
    await tester.tap(bullet);
    await pumpFrames(tester);

    expect(
      _field(tester, 'creator-front'),
      'I confused the network and transport layers.',
    );
    expect(_field(tester, 'creator-back'), isEmpty);
    expect(find.byKey(const ValueKey('creator-seed-hint')), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-seed-error')), findsNothing);
    expect(find.text('From this bullet'), findsOneWidget);
    expect(find.byType(CardCreatorSheet), findsNothing);
  });

  testWidgets('a bullet AI draft fills the fields after a loading state', (
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

    final bullet = find.byKey(const ValueKey('wrong-note-card-0'));
    await tester.ensureVisible(bullet);
    await pumpFrames(tester);
    await tester.tap(bullet);
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('creator-seed-loading')), findsOneWidget);

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
  });

  testWidgets(
    'an AI failure keeps the manual draft and shows an inline error',
    (tester) async {
      final harness = TestHarness(
        httpClient: MockClient((_) async => http.Response('down', 500)),
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

      final bullet = find.byKey(const ValueKey('wrong-note-card-0'));
      await tester.ensureVisible(bullet);
      await pumpFrames(tester);
      await tester.tap(bullet);
      await pumpFrames(tester, frames: 24);

      expect(find.byKey(const ValueKey('creator-seed-error')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('creator-seed-error')),
          matching: find.byType(Text),
        ),
        findsWidgets,
      );
      expect(
        _field(tester, 'creator-front'),
        'I confused the network and transport layers.',
      );
    },
  );

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

    final first = find.byKey(const ValueKey('wrong-note-card-0'));
    await tester.ensureVisible(first);
    await pumpFrames(tester);
    await tester.tap(first);
    await pumpFrames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('creator-back')),
      'My own answer.',
    );
    await pumpFrames(tester);

    final second = find.byKey(const ValueKey('wrong-note-card-1'));
    await tester.ensureVisible(second);
    await pumpFrames(tester);
    await tester.tap(second);
    await pumpFrames(tester);
    expect(find.text('Replace the draft you started?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await pumpFrames(tester);
    expect(find.text('Replace the draft you started?'), findsNothing);
    expect(
      _field(tester, 'creator-front'),
      'I confused the network and transport layers.',
    );

    await tester.tap(second);
    await pumpFrames(tester);
    await tester.tap(find.text('Replace'));
    await pumpFrames(tester);
    expect(_field(tester, 'creator-front'), 'I read reliable as secure.');
  });

  testWidgets('unsaved drafts guard Continue and Skip', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final first = await _seedCard(harness);
    final second = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [first.card, second.card]),
      harness: harness,
    );

    await _enterDraft(tester);
    await tester.tap(find.text('Continue'));
    await pumpFrames(tester);
    expect(find.text('Discard unsaved cards?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await pumpFrames(tester);
    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('creator-draft-0')), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await pumpFrames(tester);
    expect(find.text('Discard unsaved cards?'), findsOneWidget);
    await tester.tap(find.text('Discard cards'));
    await pumpFrames(tester);
    expect(find.text('Item 2 of 2'), findsOneWidget);
  });

  testWidgets('unsaved drafts guard Previous and closing the review', (
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

    await tester.tap(find.text('Continue'));
    await pumpFrames(tester);
    expect(find.text('Item 2 of 2'), findsOneWidget);

    await _enterDraft(tester);
    await tester.tap(find.text('Previous'));
    await pumpFrames(tester);
    expect(find.text('Discard unsaved cards?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await pumpFrames(tester);
    expect(find.text('Item 2 of 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-focus-exit')));
    await pumpFrames(tester);
    expect(find.text('Discard unsaved cards?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await pumpFrames(tester);
    expect(find.byType(ErrorCardsReviewPage), findsOneWidget);
  });

  testWidgets('a skipped step still uses the card creator sheet', (
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

    expect(find.byType(AdaptiveSplitView), findsNothing);
    expect(find.text('Review the skipped question'), findsOneWidget);
    await tester.tap(find.text('Create cards'));
    await pumpFrames(tester);
    expect(find.byType(CardCreatorSheet), findsOneWidget);
  });

  testWidgets('an open keyboard keeps both panes scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await _seedCard(harness);

    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [seeded.card]),
      harness: harness,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AdaptiveSplitView), findsOneWidget);
    expect(find.byType(CardCreatorPane), findsOneWidget);
    expect(_feedbackScroll, findsOneWidget);
    expect(_creatorScroll, findsOneWidget);
  });

  for (final config in const [
    (label: '320 dp', size: Size(320, 640), scale: 1.0),
    (label: '360 dp at 2.0', size: Size(360, 800), scale: 2.0),
    (label: '720 dp tablet', size: Size(720, 1024), scale: 1.0),
    (label: '720 dp at 2.0', size: Size(720, 1024), scale: 2.0),
  ]) {
    testWidgets('the split studio fits ${config.label}', (tester) async {
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
            'pushing the split panes out of the window.\nSecond bullet.',
        distracted: true,
      );
      await harness.cards.createNote(
        sessionId: seeded.card.sessionId,
        questionId: seeded.question.id,
        text: 'A note that has to wrap at the narrow width and large scale.',
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
      expect(find.byType(AdaptiveSplitView), findsOneWidget);
      expect(find.byType(CardCreatorPane), findsOneWidget);
      final divider = tester.getSize(find.byKey(AdaptiveSplitView.dividerKey));
      if (config.size.width >= 720) {
        expect(divider.width, AdaptiveSplitView.dividerExtent);
      } else {
        expect(divider.height, AdaptiveSplitView.dividerExtent);
      }
    });
  }
}
