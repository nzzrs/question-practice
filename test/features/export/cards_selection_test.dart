import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/data/settings_repository.dart';
import 'package:question_practice/core/database/daos/settings_dao.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/secure_key_store.dart';
import 'package:question_practice/features/export/cards_page.dart';

import '../../helpers/test_harness.dart';

/// Delays the restored value until [gate] completes.
///
/// The value is read before the gate so a user action during the wait writes a
/// newer stored selection; the page must keep that newer selection.
class _GatedSettingsRepository extends SettingsRepository {
  // The base constructor takes private positional fields, which super
  // parameters cannot name from another library.
  // ignore: use_super_parameters
  _GatedSettingsRepository(SettingsDao dao, SecureKeyStore keyStore, this.gate)
    : super(dao, keyStore);

  final Future<void> gate;

  @override
  Future<CardsSelection?> loadCardsSelection() async {
    final stored = await super.loadCardsSelection();
    await gate;
    return stored;
  }
}

class _CardsLauncher extends StatelessWidget {
  const _CardsLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: M3EButton.filled(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const CardsPage())),
          child: const Text('Open cards'),
        ),
      ),
    );
  }
}

void main() {
  Future<Question> onlyQuestion(
    TestHarness harness,
    SeededPractice seeded,
  ) async {
    final questions = await harness.practices.questionsForPractice(
      seeded.practiceId,
    );
    return questions.single;
  }

  Future<int> seedConcept(
    TestHarness harness,
    Question question, {
    String term = 'VPC',
    String definition = 'A private network.',
  }) {
    return harness.cards.createConcept(
      sessionId: null,
      questionId: question.id,
      term: term,
      definition: definition,
      context: question.prompt,
      topicName: 'Topic',
      source: ConceptSource.manual,
      createdAt: harness.clock.now().toUtc(),
    );
  }

  Future<int> seedNote(TestHarness harness, Question question) {
    return harness.cards.createNote(
      sessionId: null,
      questionId: question.id,
      text: 'managed service',
      context: question.prompt,
      topicName: 'Topic',
      practiceName: 'Practice',
      createdAt: harness.clock.now().toUtc(),
    );
  }

  Future<void> settlePersistence(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await pumpFrames(tester);
  }

  Future<void> restartCards(WidgetTester tester, TestHarness harness) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
  }

  testWidgets('a fresh Cards page starts with no selection', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    await seedConcept(harness, question);
    await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    expect(find.text('Ready for AnkiDroid'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(
      await tester.runAsync(() => harness.settings.loadCardsSelection()),
      isNull,
    );
  });

  testWidgets('selection survives a restart', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final conceptId = await seedConcept(harness, question);
    final noteId = await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    final conceptRow = find.byKey(ValueKey('concept-row-$conceptId'));
    await tester.ensureVisible(conceptRow);
    await tester.longPress(conceptRow);
    await pumpFrames(tester);

    final noteRow = find.byKey(ValueKey('note-row-$noteId'));
    await tester.ensureVisible(noteRow);
    await tester.tap(noteRow);
    await pumpFrames(tester);
    expect(find.text('2 selected'), findsOneWidget);
    await settlePersistence(tester);

    final stored = await tester.runAsync(
      () => harness.settings.loadCardsSelection(),
    );
    expect(stored?.concepts, {conceptId});
    expect(stored?.notes, {noteId});

    await restartCards(tester, harness);

    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
  });

  testWidgets('selection returns after leaving and reopening the route', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final conceptId = await seedConcept(harness, question);

    await pumpTestApp(tester, home: const _CardsLauncher(), harness: harness);
    await tester.tap(find.text('Open cards'));
    await pumpFrames(tester);

    final conceptRow = find.byKey(ValueKey('concept-row-$conceptId'));
    await tester.ensureVisible(conceptRow);
    await tester.longPress(conceptRow);
    await pumpFrames(tester);
    expect(find.text('1 selected'), findsOneWidget);
    await settlePersistence(tester);

    await tester.tap(find.byKey(const ValueKey('app-page-back')));
    await pumpFrames(tester);
    expect(find.text('Open cards'), findsOneWidget);

    await tester.tap(find.text('Open cards'));
    await pumpFrames(tester);

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('deselecting the last row removes the saved value', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final conceptId = await seedConcept(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final row = find.byKey(ValueKey('concept-row-$conceptId'));
    await tester.ensureVisible(row);
    await tester.longPress(row);
    await pumpFrames(tester);
    await settlePersistence(tester);

    await tester.tap(row);
    await pumpFrames(tester);
    await settlePersistence(tester);

    expect(find.text('Ready for AnkiDroid'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    final stored = await tester.runAsync(
      () => harness.settings.loadCardsSelection(),
    );
    expect(stored, isNull);
  });

  testWidgets('stale ids are pruned and repaired in settings', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final conceptId = await seedConcept(harness, question);

    await tester.runAsync(
      () => harness.settings.saveCardsSelection(
        CardsSelection(
          concepts: {conceptId, 9999},
          basic: {9998},
          errors: {9997},
          skipped: {9996},
          notes: {9995},
        ),
      ),
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await settlePersistence(tester);

    final stored = await tester.runAsync(
      () => harness.settings.loadCardsSelection(),
    );
    expect(stored?.concepts, {conceptId});
    expect(stored?.basic, isEmpty);
    expect(stored?.errors, isEmpty);
    expect(stored?.skipped, isEmpty);
    expect(stored?.notes, isEmpty);
  });

  testWidgets('corrupt stored selection clears safely to no selection', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(count: 1);

    await tester.runAsync(
      () => harness.database.settingsDao.setValue(
        SettingsRepository.cardsSelectionKey,
        '{"version":99,"concepts":[1]}',
      ),
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(tester.takeException(), isNull);
    expect(find.text('Ready for AnkiDroid'), findsOneWidget);

    final stored = await tester.runAsync(
      () => harness.settings.loadCardsSelection(),
    );
    expect(stored, isNull);
  });

  testWidgets('a malformed family list clears safely to no selection', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(count: 1);

    await tester.runAsync(
      () => harness.database.settingsDao.setValue(
        SettingsRepository.cardsSelectionKey,
        '{"version":1,"concepts":"not-a-list"}',
      ),
    );

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    expect(tester.takeException(), isNull);
    expect(find.text('Ready for AnkiDroid'), findsOneWidget);

    final stored = await tester.runAsync(
      () => harness.settings.loadCardsSelection(),
    );
    expect(stored, isNull);
  });

  testWidgets('a selection made while restore loads wins over the saved one', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final staleId = await seedConcept(harness, question, term: 'Old');
    final freshId = await seedConcept(harness, question, term: 'New');

    await tester.runAsync(
      () => harness.settings.saveCardsSelection(
        CardsSelection(concepts: {staleId}),
      ),
    );

    final gate = Completer<void>();
    final gated = _GatedSettingsRepository(
      harness.database.settingsDao,
      harness.keyStore,
      gate.future,
    );
    await pumpTestApp(
      tester,
      home: const CardsPage(),
      harness: harness,
      overrides: [settingsRepositoryProvider.overrideWithValue(gated)],
    );

    final freshRow = find.byKey(ValueKey('concept-row-$freshId'));
    await tester.ensureVisible(freshRow);
    await tester.longPress(freshRow);
    await pumpFrames(tester);
    expect(find.text('1 selected'), findsOneWidget);

    gate.complete();
    await pumpFrames(tester);
    await settlePersistence(tester);

    // Tapping the row the user chose must clear that selection, not add to the
    // stale stored one.
    await tester.tap(freshRow);
    await pumpFrames(tester);
    expect(find.text('Ready for AnkiDroid'), findsOneWidget);
    await settlePersistence(tester);

    final stored = await tester.runAsync(
      () => harness.settings.loadCardsSelection(),
    );
    expect(stored, isNull);
  });

  testWidgets('deleting the selected rows clears the saved selection', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(count: 1);
    final question = await onlyQuestion(harness, seeded);
    final noteId = await seedNote(harness, question);

    await pumpTestApp(tester, home: const CardsPage(), harness: harness);
    final noteRow = find.byKey(ValueKey('note-row-$noteId'));
    await tester.ensureVisible(noteRow);
    await tester.longPress(noteRow);
    await pumpFrames(tester);
    expect(find.text('1 selected'), findsOneWidget);
    await settlePersistence(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await pumpFrames(tester);
    await tester.tap(find.text('Delete'));
    await pumpFrames(tester, frames: 24);

    expect(find.text('Ready for AnkiDroid'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-selection')), findsNothing);
    await settlePersistence(tester);

    final stored = await tester.runAsync(
      () => harness.settings.loadCardsSelection(),
    );
    expect(stored, isNull);
  });
}
