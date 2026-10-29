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

  test('builds error and skipped steps, then saves cards', () async {
    final practice = await harness.seedPractice(count: 2);
    final start = await sessions.startPractice(practice.practiceId);
    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndex: 1,
      reasoning: 'I assumed the wrong layer.',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndex: null,
      reasoning: '',
      distracted: false,
    );

    final data = await review.load(start.session.id);
    expect(data, isNotNull);
    expect(data!.steps, hasLength(2));
    final errorStep = data.steps.whereType<ErrorReviewStep>().single;
    final skippedStep = data.steps.whereType<SkippedReviewStep>().single;
    expect(errorStep.card.reasoning, 'I assumed the wrong layer.');
    expect(skippedStep.question.id, start.items[1].question.id);

    await review.saveErrorDetails(
      cardId: errorStep.card.id,
      bias: 'Confused which layer owns addresses.',
      vaccine: 'Review the TCP/IP layer boundaries.',
    );
    final card = await harness.cards.errorCardById(errorStep.card.id);
    expect(card!.needsDetails, isFalse);
    expect(card.bias, contains('layer'));

    await review.createConcept(
      sessionId: start.session.id,
      questionId: skippedStep.question.id,
      term: 'TCP',
      definition: 'Transmission Control Protocol',
      context: skippedStep.question.prompt,
      topicName: skippedStep.topicName,
      source: ConceptSource.manual,
    );
    final concepts = await harness.cards.watchConcepts().first;
    expect(concepts, hasLength(1));
    expect(concepts.single.term, 'TCP');
  });

  test('adds a definition step for a concept saved without one', () async {
    final practice = await harness.seedPractice(count: 1);
    final start = await sessions.startPractice(practice.practiceId);
    await harness.cards.createConcept(
      sessionId: start.session.id,
      questionId: start.items.single.question.id,
      term: 'GCP',
      definition: '',
      context: start.items.single.question.prompt,
      topicName: 'Topic',
      source: ConceptSource.web,
      createdAt: harness.clock.now().toUtc(),
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items.single,
      selectedIndex: 0,
      reasoning: '',
      distracted: false,
    );

    final data = await review.load(start.session.id);
    final conceptStep = data!.steps.whereType<ConceptDefinitionStep>().single;
    await review.saveConceptDefinition(
      conceptStep.concept.id,
      'Google Cloud Platform',
    );
    final concepts = await harness.cards.watchConcepts().first;
    expect(concepts.single.definition, 'Google Cloud Platform');
  });

  test('creates a basic card for another question', () async {
    final data = await review.load(999);
    expect(data, isNull);

    final practice = await harness.seedPractice(count: 1);
    final start = await sessions.startPractice(practice.practiceId);
    await review.createBasicCard(
      sessionId: start.session.id,
      question: 'What is a subnet?',
      answer: 'A range of IP addresses.',
    );
    final cards = await harness.cards.watchManualCards().first;
    expect(cards.single.question, 'What is a subnet?');
  });
}
