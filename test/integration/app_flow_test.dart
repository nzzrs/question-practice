import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/anki_gateway.dart';
import 'package:question_practice/features/export/domain/anki_note_builder.dart';
import 'package:question_practice/features/export/domain/export_service.dart';
import 'package:question_practice/features/import/domain/import_service.dart';
import 'package:question_practice/features/practice/domain/session_service.dart';
import 'package:question_practice/features/review/domain/review_service.dart';

import '../helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('import, practice, review, lookup and export work end to end', () async {
    final gateway = FakeAnkiGateway();
    final harness = TestHarness(anki: gateway);
    addTearDown(harness.close);

    final importer = ImportService(
      repository: harness.practices,
      clock: harness.clock,
      bundle: rootBundle,
    );
    final sample = await rootBundle.loadString(
      'assets/samples/sample_practice.json',
    );
    final preview = await importer.previewText(sample, fileName: 'sample.json');
    await importer.import(preview);

    final summaries = await harness.practices.watchTopicSummaries().first;
    expect(summaries, hasLength(2));
    final practices = await harness.practices.allPractices();
    expect(practices, hasLength(3));

    final practice = practices.first;
    final sessions = SessionService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final start = await sessions.startPractice(practice.id);
    expect(start.items, hasLength(3));

    await sessions.submitAnswer(
      start: start,
      item: start.items[0],
      selectedIndex: start.items[0].question.correctIndex,
      reasoning: 'Known',
      distracted: false,
    );
    await sessions.submitAnswer(
      start: start,
      item: start.items[1],
      selectedIndex:
          (start.items[1].question.correctIndex + 1) %
          start.items[1].question.alternatives.length,
      reasoning: 'A flawed assumption',
      distracted: false,
    );
    final finalAnswer = await sessions.submitAnswer(
      start: start,
      item: start.items[2],
      selectedIndex: null,
      reasoning: '',
      distracted: false,
    );
    expect(finalAnswer.summary, isNotNull);
    expect(finalAnswer.summary!.session.correct, 1);

    final review = ReviewService(
      practices: harness.practices,
      sessions: harness.sessions,
      cards: harness.cards,
      clock: harness.clock,
    );
    final reviewData = await review.load(start.session.id);
    expect(reviewData!.steps.whereType<ErrorReviewStep>(), hasLength(1));
    expect(reviewData.steps.whereType<SkippedReviewStep>(), hasLength(1));

    final errorStep = reviewData.steps.whereType<ErrorReviewStep>().single;
    await review.saveErrorDetails(
      cardId: errorStep.card.id,
      bias: 'I mixed up two services.',
      vaccine: 'Compare the service descriptions.',
    );
    final skippedStep = reviewData.steps.whereType<SkippedReviewStep>().single;
    await review.createConcept(
      sessionId: start.session.id,
      questionId: skippedStep.question.id,
      term: 'GCP',
      definition: 'Google Cloud Platform',
      context: skippedStep.question.prompt,
      topicName: skippedStep.topicName,
      source: ConceptSource.manual,
    );

    final concepts = await harness.cards.watchConcepts().first;
    final errors = await harness.cards.watchErrorCards().first;
    final export = ExportService(
      gateway: gateway,
      cards: harness.cards,
      practices: harness.practices,
      clock: harness.clock,
    );
    final outcome = await export.exportToAnki(
      deckName: 'Question Practice',
      selection: ExportSelection(concepts: concepts, errorCards: errors),
    );
    expect(outcome.success, isTrue);
    expect(gateway.importedNotes, hasLength(2));
    expect(
      gateway.importedNotes.first.fields.first,
      'Definition of {{c1::GCP}}: {{c2::Google Cloud Platform}}',
    );
    expect(await harness.cards.watchConcepts().first, isEmpty);
    expect(await harness.cards.watchErrorCards().first, isEmpty);
  });
}
