import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/data/card_repository.dart';
import 'package:question_practice/core/data/practice_repository.dart';
import 'package:question_practice/core/database/app_database.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/errors/error_cards_review_page.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/review_page.dart';

import '../../helpers/test_harness.dart';

/// Holds the first question lookup so a review can move to another note before
/// the previous context load finishes.
class _GatedPracticeRepository extends PracticeRepository {
  // The repository's constructor parameters are private to its library.
  // ignore: use_super_parameters
  _GatedPracticeRepository(AppDatabase database, Clock clock)
    : super(database, clock);

  final gates = <int, Completer<void>>{};

  @override
  Future<Question?> questionById(int id) async {
    final gate = gates[id];
    if (gate != null) await gate.future;
    return super.questionById(id);
  }
}

/// Holds the first notes lookup for the same cross-card race.
class _GatedCardRepository extends CardRepository {
  // The repository's constructor parameters are private to its library.
  // ignore: use_super_parameters
  _GatedCardRepository(AppDatabase database, Clock clock)
    : super(database, clock);

  final gates = <int, Completer<void>>{};

  @override
  Future<List<Note>> notesForQuestion(int questionId) async {
    final gate = gates[questionId];
    if (gate != null) await gate.future;
    return super.notesForQuestion(questionId);
  }
}

Future<ErrorCard> _errorCard(TestHarness harness, Question question) async {
  final id = await harness.cards.createErrorCard(
    questionId: question.id,
    sessionId: null,
    question: question.prompt,
    alternatives: question.alternatives,
    correctIndexes: question.correctIndexes,
    wrongIndexes: const [1],
    reasoning: 'Reason',
    explanation: question.explanation,
    alternativeExplanations: question.alternativeExplanations,
    topicName: 'Topic',
    practiceName: 'Practice',
    lastWrongAt: harness.clock.now().toUtc(),
    dueAfter: const Duration(hours: 48),
  );
  return (await harness.cards.errorCardById(id))!;
}

void main() {
  testWidgets('a slow context load never replaces the next note context', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 2);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(seeded.practiceId);
    for (final item in start.items) {
      await sessions.submitAnswer(
        start: start,
        item: item,
        selectedIndexes: [item.question.correctIndex],
        reasoning: '',
        distracted: false,
      );
    }
    for (final question in questions) {
      await harness.cards.createNote(
        sessionId: start.session.id,
        questionId: question.id,
        text: 'Note for ${question.prompt}',
        context: question.prompt,
        topicName: 'Topic',
        practiceName: 'Practice',
        createdAt: harness.clock.now().toUtc(),
      );
      harness.clock.advance(const Duration(minutes: 1));
    }

    final repository = _GatedPracticeRepository(
      harness.database,
      harness.clock,
    );
    final first = questions.first;
    final second = questions.last;
    final gate = repository.gates[first.id] = Completer<void>();

    await pumpTestApp(
      tester,
      home: ReviewPage(sessionId: start.session.id),
      harness: harness,
      overrides: [topicRepositoryProvider.overrideWithValue(repository)],
    );

    expect(find.text('Note for ${first.prompt}'), findsOneWidget);
    expect(find.byKey(const ValueKey('note-see-context')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('review-dock-next')));
    await pumpFrames(tester);
    expect(find.text('Note for ${second.prompt}'), findsOneWidget);
    expect(find.byKey(const ValueKey('note-see-context')), findsOneWidget);

    // Let the previous note's lookup finish after the current note is shown.
    gate.complete();
    await pumpFrames(tester, frames: 24);

    await tester.tap(find.byKey(const ValueKey('note-see-context')));
    await pumpFrames(tester);

    expect(find.text('Original question'), findsOneWidget);
    expect(find.text(second.prompt), findsOneWidget);
    expect(find.text(first.prompt), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slow notes load never shows the previous error card notes', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 2);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final first = questions.first;
    final second = questions.last;
    final firstCard = await _errorCard(harness, first);
    final secondCard = await _errorCard(harness, second);
    await harness.cards.createNote(
      sessionId: null,
      questionId: first.id,
      text: 'First card note',
      context: first.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    await harness.cards.createNote(
      sessionId: null,
      questionId: second.id,
      text: 'Second card note',
      context: second.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );

    final repository = _GatedCardRepository(harness.database, harness.clock);
    final gate = repository.gates[first.id] = Completer<void>();
    await pumpTestApp(
      tester,
      home: ErrorCardsReviewPage(cards: [firstCard, secondCard]),
      harness: harness,
      overrides: [cardRepositoryProvider.overrideWithValue(repository)],
    );

    await tester.tap(find.byKey(const ValueKey('review-dock-next')));
    await pumpFrames(tester, frames: 40);
    expect(find.textContaining('Second card note'), findsOneWidget);
    expect(find.textContaining('First card note'), findsNothing);

    // Let the previous card's notes arrive after the current card is shown.
    gate.complete();
    await pumpFrames(tester, frames: 24);

    expect(find.textContaining('Second card note'), findsOneWidget);
    expect(find.textContaining('First card note'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
