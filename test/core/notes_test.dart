import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  test(
    'notes load, keep, convert and delete through the renamed API',
    () async {
      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await harness.seedPractice(count: 1);
      final question = (await harness.practices.questionsForPractice(
        seeded.practiceId,
      )).single;

      final noteId = await harness.cards.createNote(
        sessionId: null,
        questionId: question.id,
        text: 'object storage',
        context: question.prompt,
        topicName: 'Topic',
        practiceName: 'Practice',
        createdAt: harness.clock.now().toUtc(),
      );

      final loaded = await harness.cards.notesForQuestion(question.id);
      expect(loaded.single.text, 'object storage');
      expect(loaded.single.needsReview, isTrue);

      await harness.cards.keepNote(noteId, harness.clock.now().toUtc());
      expect(
        (await harness.cards.notesForQuestion(question.id)).single.isKept,
        isTrue,
      );

      final cardId = await harness.cards.createBasicCard(
        sessionId: null,
        questionId: question.id,
        question: 'What is a bucket?',
        answer: 'A container for objects.',
        topicName: 'Topic',
        createdAt: harness.clock.now().toUtc(),
      );
      await harness.cards.markNoteConverted(
        noteId,
        cardCreatedAt: harness.clock.now().toUtc(),
        basicCardId: cardId,
      );
      final converted = (await harness.cards.notesForQuestion(question.id))
          .single;
      expect(converted.hasCard, isTrue);
      expect(converted.basicCardId, cardId);

      await harness.cards.deleteNote(noteId);
      expect(await harness.cards.notesForQuestion(question.id), isEmpty);
      expect(await harness.cards.watchNotes().first, isEmpty);
    },
  );

  test('a conversion retry keeps the basic card link', () async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = (await harness.practices.questionsForPractice(
      seeded.practiceId,
    )).single;
    final noteId = await harness.cards.createNote(
      sessionId: null,
      questionId: question.id,
      text: 'object storage',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
    final cardId = await harness.cards.createBasicCard(
      sessionId: null,
      questionId: question.id,
      question: 'What is a bucket?',
      answer: 'A container for objects.',
      topicName: 'Topic',
      createdAt: harness.clock.now().toUtc(),
    );

    await harness.cards.markNoteConverted(
      noteId,
      cardCreatedAt: harness.clock.now().toUtc(),
      basicCardId: cardId,
    );
    harness.clock.advance(const Duration(seconds: 1));
    await harness.cards.markNoteConverted(
      noteId,
      cardCreatedAt: harness.clock.now().toUtc(),
    );

    final converted = (await harness.cards.notesForQuestion(question.id))
        .single;
    expect(converted.hasCard, isTrue);
    expect(converted.basicCardId, cardId);
  });
}
