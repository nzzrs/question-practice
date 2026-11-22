import 'dart:io';

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
  late Directory tempDir;

  setUp(() async {
    gateway = FakeAnkiGateway();
    harness = TestHarness(anki: gateway);
    tempDir = await Directory.systemTemp.createTemp('qp-export-test-');
    service = ExportService(
      gateway: gateway,
      cards: harness.cards,
      practices: harness.practices,
      clock: harness.clock,
      temporaryDirectory: () async => tempDir,
    );
  });

  tearDown(() async {
    await harness.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
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
      subtopic: 'Layer 4',
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
    final basicId = await harness.cards.createBasicCard(
      sessionId: null,
      question: 'Manual question',
      answer: 'Manual answer',
      topicName: 'Cloud',
      subtopic: 'Layer 4',
      createdAt: harness.clock.now().toUtc(),
    );
    final concepts = await harness.cards.watchConcepts().first;
    final basics = await harness.cards.watchBasicCards().first;
    expect(conceptId, isPositive);
    expect(basicId, isPositive);
    return ExportSelection(concepts: concepts, basicCards: basics);
  }

  test('exports all selected notes and marks them exported', () async {
    final items = await selection();
    final outcome = await service.exportToAnki(
      deckName: 'Question Practice',
      selection: items,
    );

    expect(outcome.success, isTrue);
    expect(outcome.added, 2);
    expect(outcome.failed, 0);
    expect(gateway.importedNotes, hasLength(2));
    expect(gateway.importedNotes.map((note) => note.model), [
      AnkiModel.concept,
      AnkiModel.basic,
    ]);
    expect(gateway.importedNotes.first.tags, [
      'question-practice',
      'topic::cloud',
      'subtopic::layer-4',
    ]);
    expect(gateway.importedNotes.last.tags, [
      'question-practice',
      'topic::cloud',
      'subtopic::layer-4',
    ]);
    expect(gateway.importedNotes.map((note) => note.deckName).toSet(), {
      'Cloud deck',
    });
    expect(gateway.syncCount, 1);
    expect(await harness.cards.watchConcepts().first, isEmpty);
    expect(await harness.cards.watchBasicCards().first, isEmpty);
    // Errors are reviewed into atomic cards, never exported directly.
    expect(await harness.cards.watchErrorCards().first, isNotEmpty);
  });

  test(
    'writeFiles writes the header block for concepts and basic files',
    () async {
      final items = await selection();
      final files = await service.writeFiles(items);

      expect(files, hasLength(2));
      final concept = await files[0].readAsString();
      final basic = await files[1].readAsString();
      expect(concept, startsWith('#separator:Tab'));
      expect(concept, contains('#columns:Front\tExtra\tTags'));
      expect(concept, contains('#tags column:3'));
      expect(basic, startsWith('#separator:Tab'));
      expect(basic, contains('#columns:Front\tBack\tTags'));
      expect(basic, contains('#tags column:3'));
    },
  );

  test('writeFiles preserves the existing file names and extensions', () async {
    final items = await selection();
    final files = await service.writeFiles(items);

    expect(files[0].path, contains('question-practice-concepts-'));
    expect(files[0].path, endsWith('.txt'));
    expect(files[1].path, contains('question-practice-basic-'));
    expect(files[1].path, endsWith('.tsv'));
  });

  test('does not export when permission is missing', () async {
    gateway.currentStatus = const AnkiStatus(
      installed: true,
      apiAvailable: true,
      permissionGranted: false,
      deckExists: false,
      conceptModelAvailable: true,
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

  test('notes serialize as plain text outside the Anki selection', () {
    final text = service.notesText([
      Note(
        id: 1,
        sessionId: 1,
        questionId: 1,
        text: 'managed service',
        context: 'Which platform is fully managed?',
        topicName: 'Cloud',
        practiceName: 'Core',
        createdAt: harness.clock.now().toUtc(),
        keptAt: harness.clock.now().toUtc(),
        cardCreatedAt: null,
        basicCardId: null,
      ),
      Note(
        id: 2,
        sessionId: 1,
        questionId: 2,
        text: 'load balancer',
        context: 'What spreads traffic?',
        topicName: 'Cloud',
        practiceName: 'Core',
        createdAt: harness.clock.now().toUtc(),
        keptAt: null,
        cardCreatedAt: harness.clock.now().toUtc(),
        basicCardId: 7,
      ),
    ]);

    expect(text, contains('Question Practice notes'));
    expect(text, contains('# Cloud'));
    expect(text, contains('managed service'));
    expect(text, contains('Context: Which platform is fully managed?'));
    expect(text, contains('Status: Kept'));
    expect(text, contains('Status: Card made'));
  });
}
