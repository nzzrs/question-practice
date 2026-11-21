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
      selectedIndexes: const [1],
      reasoning: 'I assumed the wrong layer.',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndexes: const [],
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
      selectedIndexes: const [0],
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
      topicName: 'Networking',
    );
    final cards = await harness.cards.watchManualCards().first;
    expect(cards.single.question, 'What is a subnet?');
  });

  test('creates atomic breakdown cards and completes the error', () async {
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
      reasoning: '',
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      topicName: 'Topic',
      practiceName: 'Practice',
      subtopic: 'Layer',
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    final card = (await harness.cards.errorCardById(id))!;

    final added = await review.createErrorBreakdownCards(
      card: card,
      cards: const [
        SuggestedCard(
          front: 'Which layer owns IP addresses?',
          back: 'The network layer.',
          template: CardTemplate.contrast,
        ),
        SuggestedCard(
          front: 'Given requirement X with restriction Y, what rule applies?',
          back: 'Match the layer to its addressing job.',
          template: CardTemplate.heuristic,
        ),
      ],
    );

    expect(added, 2);
    final cards = await harness.cards.watchManualCards().first;
    expect(cards, hasLength(2));
    expect(
      cards.map((item) => item.cognitiveType),
      containsAll([CognitiveType.contrast, CognitiveType.heuristic]),
    );
    expect(cards.every((item) => item.subtopic == 'Layer'), isTrue);
    expect(cards.every((item) => item.topicName == 'Topic'), isTrue);
    final saved = await harness.cards.errorCardById(card.id);
    expect(saved!.needsDetails, isFalse);
    expect(saved.detailsCompletedAt, isNotNull);
    expect(saved.bias, card.bias);
    expect(saved.vaccine, card.vaccine);
  });

  test('completing details keeps existing bias and vaccine notes', () async {
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
      reasoning: '',
      explanation: question.explanation,
      alternativeExplanations: question.alternativeExplanations,
      topicName: 'Topic',
      practiceName: 'Practice',
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    await harness.cards.updateErrorCardDetails(
      id: id,
      bias: 'Old bias',
      vaccine: 'Old rule',
      completedAt: harness.clock.now().toUtc(),
    );
    await harness.database.customStatement(
      'UPDATE error_cards SET details_completed_at = NULL WHERE id = ?',
      [id],
    );

    await review.completeErrorDetails(id);

    final saved = await harness.cards.errorCardById(id);
    expect(saved!.needsDetails, isFalse);
    expect(saved.bias, 'Old bias');
    expect(saved.vaccine, 'Old rule');
  });
}
