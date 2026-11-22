import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/export/cards_page.dart';

import '../../helpers/test_harness.dart';

final _now = DateTime.utc(2026, 1, 1, 12);

Concept _concept(
  int id, {
  String definition = 'A definition.',
  DateTime? exportedAt,
}) {
  return Concept(
    id: id,
    sessionId: null,
    questionId: null,
    term: 'Term $id',
    definition: definition,
    extra: '',
    context: '',
    topicName: 'Topic',
    source: ConceptSource.manual,
    createdAt: _now,
    exportedAt: exportedAt,
  );
}

ErrorCard _error(int id, {required bool pending, DateTime? exportedAt}) {
  return ErrorCard(
    id: id,
    questionId: id,
    sessionId: null,
    question: 'Question $id?',
    alternatives: const ['Correct', 'Wrong'],
    correctIndexes: const [0],
    wrongIndexes: const [1],
    reasoning: 'Reason',
    explanation: 'Explanation',
    alternativeExplanations: const [],
    bias: '',
    vaccine: '',
    topicName: 'Topic',
    practiceName: 'Practice',
    status: ErrorCardStatus.active,
    createdAt: _now,
    lastWrongAt: _now,
    dueAt: _now,
    detailsCompletedAt: pending ? null : _now,
    resolvedAt: null,
    exportedAt: exportedAt,
  );
}

ManualCard _manual(int id, {DateTime? exportedAt}) {
  return ManualCard(
    id: id,
    sessionId: null,
    question: 'Basic $id?',
    answer: 'Answer $id',
    topicName: 'Topic',
    createdAt: _now,
    exportedAt: exportedAt,
  );
}

SkippedQuestion _skipped(int id) {
  return SkippedQuestion(
    id: id,
    sessionId: null,
    questionId: id,
    question: 'Skipped $id?',
    alternatives: const ['Correct', 'Wrong'],
    correctIndexes: const [0],
    explanation: 'Explanation',
    alternativeExplanations: const [],
    reasoning: 'Reason',
    topicName: 'Topic',
    practiceName: 'Practice',
    unknown: false,
    createdAt: _now,
    handledAt: null,
    handledKind: null,
  );
}

Note _note(int id) {
  return Note(
    id: id,
    sessionId: null,
    questionId: id,
    text: 'Note $id',
    context: '',
    topicName: 'Topic',
    practiceName: 'Practice',
    createdAt: _now,
    keptAt: null,
    cardCreatedAt: null,
    manualCardId: null,
  );
}

void main() {
  group('CardsViewCache', () {
    test('derives data once while the stream lists keep their identity', () {
      final cache = CardsViewCache();
      final concepts = [_concept(1)];
      final errors = [_error(1, pending: false)];
      final manuals = [_manual(1)];
      final skipped = [_skipped(1)];
      final notes = [_note(1)];

      final first = cache.data(
        concepts: concepts,
        errors: errors,
        manuals: manuals,
        skipped: skipped,
        notes: notes,
        showExported: false,
      );
      final second = cache.data(
        concepts: concepts,
        errors: errors,
        manuals: manuals,
        skipped: skipped,
        notes: notes,
        showExported: false,
      );

      expect(identical(first, second), isTrue);
      expect(cache.dataBuilds, 1);

      final replacement = [_concept(1)];
      final third = cache.data(
        concepts: replacement,
        errors: errors,
        manuals: manuals,
        skipped: skipped,
        notes: notes,
        showExported: false,
      );

      expect(identical(second, third), isFalse);
      expect(cache.dataBuilds, 2);
    });

    test('derives data again when the exported toggle flips', () {
      final cache = CardsViewCache();
      final concepts = [_concept(1)];

      cache.data(
        concepts: concepts,
        errors: const [],
        manuals: const [],
        skipped: const [],
        notes: const [],
        showExported: false,
      );
      cache.data(
        concepts: concepts,
        errors: const [],
        manuals: const [],
        skipped: const [],
        notes: const [],
        showExported: true,
      );
      cache.data(
        concepts: concepts,
        errors: const [],
        manuals: const [],
        skipped: const [],
        notes: const [],
        showExported: true,
      );

      expect(cache.dataBuilds, 2);
    });

    test('derives the view once per filter and selection revision', () {
      final cache = CardsViewCache();
      final data = cache.data(
        concepts: const [],
        errors: const [],
        manuals: const [],
        skipped: const [],
        notes: const [],
        showExported: false,
      );

      CardsPageView build({
        CardsFilter filter = CardsFilter.all,
        int revision = 0,
      }) {
        return cache.view(
          data: data,
          filter: filter,
          selectionRevision: revision,
          selectedConcepts: const {},
          selectedBasic: const {},
          selectedErrors: const {},
          selectedSkipped: const {},
          selectedNotes: const {},
        );
      }

      final first = build();
      final second = build();
      expect(identical(first, second), isTrue);
      expect(cache.viewBuilds, 1);

      build(revision: 1);
      expect(cache.viewBuilds, 2);

      build(revision: 1);
      expect(cache.viewBuilds, 2);

      build(filter: CardsFilter.notes, revision: 1);
      expect(cache.viewBuilds, 3);
    });
  });

  group('CardsDerivedData', () {
    final concepts = [
      _concept(1),
      _concept(2, definition: ''),
      _concept(3, exportedAt: _now),
    ];
    final errors = [
      _error(1, pending: true),
      _error(2, pending: false),
      _error(3, pending: true, exportedAt: _now),
    ];
    final manuals = [_manual(1), _manual(2, exportedAt: _now)];
    final skipped = [_skipped(1), _skipped(2)];
    final notes = [_note(1), _note(2)];

    CardsDerivedData derive({required bool showExported}) {
      return CardsViewCache().data(
        concepts: concepts,
        errors: errors,
        manuals: manuals,
        skipped: skipped,
        notes: notes,
        showExported: showExported,
      );
    }

    test('hides exported rows by default without hiding their counts', () {
      final data = derive(showExported: false);

      expect(data.concepts.map((item) => item.id), [1, 2]);
      expect(data.errors.map((item) => item.id), [1, 2]);
      expect(data.manuals.map((item) => item.id), [1]);
      expect(data.skipped.map((item) => item.id), [1, 2]);
      expect(data.notes.map((item) => item.id), [1, 2]);
      expect(data.hasAnyRows, isTrue);
      expect(data.hasAnyData, isTrue);
    });

    test('selectable ids exclude exported and incomplete rows', () {
      final data = derive(showExported: false);

      expect(data.conceptSelectableIds, [1]);
      expect(data.conceptSelectableIdSet, {1});
      expect(data.basicSelectableIds, [1]);
      expect(data.errorSelectableIds, [1, 2]);
      expect(data.skippedSelectableIds, [1, 2]);
      expect(data.noteSelectableIds, [1, 2]);
    });

    test('showing exported rows keeps selectable ids unchanged', () {
      final data = derive(showExported: true);

      expect(data.concepts.map((item) => item.id), [1, 2, 3]);
      expect(data.errors.map((item) => item.id), [1, 2, 3]);
      expect(data.manuals.map((item) => item.id), [1, 2]);
      expect(data.conceptSelectableIds, [1]);
      expect(data.basicSelectableIds, [1]);
      expect(data.errorSelectableIds, [1, 2]);
    });

    test('pending counts ignore exported errors and include skipped', () {
      for (final showExported in [false, true]) {
        final data = derive(showExported: showExported);
        expect(data.pendingErrors.map((item) => item.id), [1]);
        expect(data.globalPendingCount, 3);
      }
    });

    test('all-exported data has no rows but still has data', () {
      final data = CardsViewCache().data(
        concepts: [_concept(1, exportedAt: _now)],
        errors: const [],
        manuals: const [],
        skipped: const [],
        notes: const [],
        showExported: false,
      );

      expect(data.hasAnyRows, isFalse);
      expect(data.hasAnyData, isTrue);
    });
  });

  group('CardsPageView', () {
    final data = CardsViewCache().data(
      concepts: [
        _concept(1),
        _concept(2, definition: ''),
        _concept(3, exportedAt: _now),
      ],
      errors: [
        _error(1, pending: true),
        _error(2, pending: false),
        _error(3, pending: true, exportedAt: _now),
      ],
      manuals: [
        _manual(1),
        _manual(2, exportedAt: _now),
      ],
      skipped: [_skipped(1), _skipped(2)],
      notes: [_note(1), _note(2)],
      showExported: false,
    );

    test('keeps only exportable selected rows in the export selection', () {
      final view = CardsViewCache().view(
        data: data,
        filter: CardsFilter.all,
        selectionRevision: 1,
        selectedConcepts: {1, 2, 3},
        selectedBasic: {1, 2},
        selectedErrors: {1, 2, 3},
        selectedSkipped: {1},
        selectedNotes: {1},
      );

      expect(view.exportSelection.concepts.map((item) => item.id), [1]);
      expect(view.exportSelection.manualCards.map((item) => item.id), [1]);
      expect(view.selectedErrors.map((item) => item.id), [1, 2]);
      expect(view.selectedSkipped.map((item) => item.id), [1]);
      expect(view.selectedNotes.map((item) => item.id), [1]);
      expect(view.pendingSelectedErrors.map((item) => item.id), [1]);
      expect(view.selectedPendingCount, 2);
      expect(view.selectedCount, 6);
    });

    test('groups only the rows of the chosen filter', () {
      final view = CardsViewCache().view(
        data: data,
        filter: CardsFilter.cards,
        selectionRevision: 1,
        selectedConcepts: const {},
        selectedBasic: const {},
        selectedErrors: const {},
        selectedSkipped: const {},
        selectedNotes: const {},
      );

      expect(view.showCards, isTrue);
      expect(view.showErrors, isFalse);
      expect(view.showNotes, isFalse);
      expect(view.visibleGroups, hasLength(2));
      expect(view.visibleEntryCount, 2);
      expect(view.hasVisibleRows, isTrue);
      expect(view.allVisibleSelected, isFalse);
    });

    test('select-all covers every visible group', () {
      final view = CardsViewCache().view(
        data: data,
        filter: CardsFilter.all,
        selectionRevision: 2,
        selectedConcepts: {1},
        selectedBasic: {1},
        selectedErrors: {1, 2},
        selectedSkipped: {1, 2},
        selectedNotes: {1, 2},
      );

      expect(view.visibleGroups, hasLength(5));
      expect(view.visibleEntryCount, 8);
      expect(view.allVisibleSelected, isTrue);
      expect(view.hasVisibleRows, isTrue);
    });
  });

  testWidgets('a Cards page does not re-derive on unrelated rebuilds', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    final conceptId = await harness.cards.createConcept(
      sessionId: null,
      questionId: questions.single.id,
      term: 'VPC',
      definition: 'A private network.',
      context: questions.single.prompt,
      topicName: 'Topic',
      source: ConceptSource.manual,
      createdAt: harness.clock.now().toUtc(),
    );
    final cache = CardsViewCache();

    await pumpTestApp(
      tester,
      home: CardsPage(viewCache: cache),
      harness: harness,
    );
    await pumpFrames(tester);

    final dataBuilds = cache.dataBuilds;
    final viewBuilds = cache.viewBuilds;
    expect(dataBuilds, greaterThan(0));
    expect(viewBuilds, greaterThan(0));

    // A layout change rebuilds the page without touching stream data or the
    // selection. The cache must keep both derivations.
    tester.view.physicalSize = const Size(820, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpFrames(tester);
    expect(cache.dataBuilds, dataBuilds);
    expect(cache.viewBuilds, viewBuilds);

    // Selecting a row advances the selection revision: one view derivation,
    // no data derivation.
    final row = find.byKey(ValueKey('concept-row-$conceptId'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);
    expect(cache.dataBuilds, dataBuilds);
    expect(cache.viewBuilds, viewBuilds + 1);

    // A filter change derives the view once, not the data.
    final cardsFilter = find.byKey(const ValueKey('cards-filter-cards'));
    await tester.ensureVisible(cardsFilter);
    await tester.tap(cardsFilter);
    await pumpFrames(tester);
    expect(cache.dataBuilds, dataBuilds);
    expect(cache.viewBuilds, viewBuilds + 2);

    // A new stream value is a new data revision and derives once after it
    // settles.
    await tester.runAsync(() async {
      await harness.cards.createManualCard(
        sessionId: null,
        questionId: questions.single.id,
        question: 'What is a subnet?',
        answer: 'A network range.',
        context: questions.single.prompt,
        topicName: 'Topic',
        createdAt: harness.clock.now().toUtc(),
      );
    });
    await pumpFrames(tester, frames: 24);

    final revisedDataBuilds = cache.dataBuilds;
    final revisedViewBuilds = cache.viewBuilds;
    expect(revisedDataBuilds, greaterThan(dataBuilds));
    expect(revisedViewBuilds, greaterThan(viewBuilds + 2));

    await pumpFrames(tester);
    expect(cache.dataBuilds, revisedDataBuilds);
    expect(cache.viewBuilds, revisedViewBuilds);
  });
}
