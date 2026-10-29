import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/anki_gateway.dart';
import 'package:question_practice/features/export/domain/anki_note_builder.dart';
import 'package:question_practice/features/export/domain/export_service.dart';

import '../../helpers/test_harness.dart';

void main() {
  late TestHarness harness;
  late FakeAnkiGateway gateway;
  late ExportService service;

  setUp(() {
    gateway = FakeAnkiGateway();
    harness = TestHarness(anki: gateway);
    service = ExportService(
      gateway: gateway,
      cards: harness.cards,
      practices: harness.practices,
      clock: harness.clock,
    );
  });

  tearDown(() async {
    await harness.close();
  });

  Future<ExportSelection> selection() async {
    final practice = await harness.seedPractice(
      topicName: 'Cloud',
      count: 1,
      ankiDeck: 'Cloud deck',
    );
    final question = (await harness.practices.questionsForPractice(
      practice.practiceId,
    )).single;
    final conceptId = await harness.cards.createConcept(
      sessionId: null,
      questionId: null,
      term: 'GCP',
      definition: 'Google Cloud Platform',
      context: 'Question',
      topicName: 'Cloud',
      source: ConceptSource.ai,
      createdAt: harness.clock.now().toUtc(),
    );
    final errorId = await harness.cards.createErrorCard(
      questionId: question.id,
      sessionId: null,
      question: 'Question?',
      alternatives: ['Correct', 'Wrong'],
      correctIndexes: const [0],
      wrongIndexes: const [1],
      reasoning: 'Reason',
      explanation: 'Explanation',
      alternativeExplanations: const ['Correct', 'Wrong'],
      topicName: 'Cloud',
      practiceName: 'Practice',
      lastWrongAt: harness.clock.now().toUtc(),
      dueAfter: const Duration(hours: 48),
    );
    await harness.cards.updateErrorCardDetails(
      id: errorId,
      bias: 'Bias',
      vaccine: 'Vaccine',
      completedAt: harness.clock.now().toUtc(),
    );
    final manualId = await harness.cards.createManualCard(
      sessionId: null,
      question: 'Manual question',
      answer: 'Manual answer',
      topicName: 'Cloud',
      createdAt: harness.clock.now().toUtc(),
    );
    final concepts = await harness.cards.watchConcepts().first;
    final errors = await harness.cards.watchErrorCards().first;
    final manuals = await harness.cards.watchManualCards().first;
    expect(conceptId, isPositive);
    expect(manualId, isPositive);
    return ExportSelection(
      concepts: concepts,
      errorCards: errors,
      manualCards: manuals,
    );
  }

  test('exports all selected notes and marks them exported', () async {
    final items = await selection();
    final outcome = await service.exportToAnki(
      deckName: 'Question Practice',
      selection: items,
    );

    expect(outcome.success, isTrue);
    expect(outcome.added, 3);
    expect(outcome.failed, 0);
    expect(gateway.importedNotes, hasLength(3));
    expect(gateway.importedNotes.map((note) => note.model), [
      AnkiModel.concept,
      AnkiModel.error,
      AnkiModel.basic,
    ]);
    expect(gateway.importedNotes.map((note) => note.deckName).toSet(), {
      'Cloud deck',
    });
    expect(gateway.syncCount, 1);
    expect(await harness.cards.watchConcepts().first, isEmpty);
    expect(await harness.cards.watchErrorCards().first, isEmpty);
    expect(await harness.cards.watchManualCards().first, isEmpty);
  });

  test('does not export when permission is missing', () async {
    gateway.currentStatus = const AnkiStatus(
      installed: true,
      apiAvailable: true,
      permissionGranted: false,
      deckExists: false,
      conceptModelAvailable: true,
      errorModelAvailable: false,
      basicModelAvailable: false,
    );
    final items = await selection();
    final outcome = await service.exportToAnki(
      deckName: 'Question Practice',
      selection: items,
    );

    expect(outcome.success, isFalse);
    expect(outcome.message, contains('Grant'));
    expect(gateway.importedNotes, isEmpty);
  });

  test('does not export concepts without a Cloze note type', () async {
    gateway.currentStatus = const AnkiStatus(
      installed: true,
      apiAvailable: true,
      permissionGranted: true,
      deckExists: true,
      conceptModelAvailable: false,
      errorModelAvailable: true,
      basicModelAvailable: true,
    );
    final items = await selection();
    final outcome = await service.exportToAnki(
      deckName: 'Question Practice',
      selection: items,
    );

    expect(outcome.success, isFalse);
    expect(outcome.message, contains('Cloze'));
    expect(gateway.importedNotes, isEmpty);
  });

  test('partial failures leave cards unexported', () async {
    gateway.importResult = const AnkiImportResult(
      added: 2,
      failed: 1,
      message: 'One rejected',
    );
    final items = await selection();
    final outcome = await service.exportToAnki(
      deckName: 'Question Practice',
      selection: items,
    );

    expect(outcome.success, isFalse);
    expect(outcome.added, 2);
    expect(outcome.failed, 1);
    expect(await harness.cards.watchConcepts().first, hasLength(1));
  });

  test('empty selection is rejected before touching AnkiDroid', () async {
    final outcome = await service.exportToAnki(
      deckName: 'Question Practice',
      selection: const ExportSelection(),
    );
    expect(outcome.success, isFalse);
    expect(gateway.importedNotes, isEmpty);
  });
}
