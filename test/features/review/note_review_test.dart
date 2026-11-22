import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/domain/review_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late SessionService sessions;
  late ReviewService review;

  setUp(() {
    harness = TestHarness();
    sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    review = ReviewService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
  });

  tearDown(() async {
    await harness.close();
  });

  Future<int> seedNote(SessionStart start, int questionId) {
    return harness.cards.createNote(
      sessionId: start.session.id,
      questionId: questionId,
      text: 'managed service',
      context: start.items.single.question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
  }

  test('notes wait in the review and keeping one closes the step', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    await seedNote(start, start.items.single.question.id);

    final data = await review.load(start.session.id);
    final step = data!.steps.whereType<NoteReviewStep>().single;
    expect(step.note.text, 'managed service');

    await review.keepNote(step.note.id);
    final after = await review.load(start.session.id);
    expect(after!.steps.whereType<NoteReviewStep>(), isEmpty);
    final saved = await harness.cards.notesForSession(start.session.id);
    expect(saved.single.isKept, isTrue);
  });

  test('a note can become a concept card', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    final noteId = await seedNote(start, start.items.single.question.id);
    final data = await review.load(start.session.id);
    final step = data!.steps.whereType<NoteReviewStep>().single;

    await review.createConcept(
      sessionId: start.session.id,
      questionId: step.note.questionId,
      term: step.note.text,
      definition: 'A cloud service run by the provider.',
      context: step.note.context,
      topicName: step.note.topicName,
      source: ConceptSource.manual,
    );
    await review.markNoteConverted(step.note.id);

    final concepts = await harness.cards.watchConcepts().first;
    expect(concepts.single.term, 'managed service');
    final saved = await harness.cards.notesForSession(start.session.id);
    expect(saved.single.hasCard, isTrue);
    final after = await review.load(start.session.id);
    expect(after!.steps.whereType<NoteReviewStep>(), isEmpty);
    expect(noteId, step.note.id);
  });

  test('deleting a note removes it from the review', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndexes: const [0],
      reasoning: '',
      distracted: false,
    );
    final id = await seedNote(start, start.items.single.question.id);
    await harness.cards.deleteNote(id);

    final data = await review.load(start.session.id);
    expect(data!.steps.whereType<NoteReviewStep>(), isEmpty);
  });
}
