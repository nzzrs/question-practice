import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/topics/topic_actions.dart';
import 'package:question_practice/features/topics/topic_editor_sheet.dart';

import '../../helpers/test_harness.dart';

class _TopicEditHost extends ConsumerWidget {
  const _TopicEditHost({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: M3EButton.filled(
          onPressed: () => showEditTopicDialog(context, ref, topic),
          child: const Text('edit'),
        ),
      ),
    );
  }
}

Finder _nameField() => find.byKey(const ValueKey('topic-editor-name'));
Finder _descriptionField() =>
    find.byKey(const ValueKey('topic-editor-description'));
Finder _priorityField() => find.byKey(const ValueKey('topic-editor-priority'));
Finder _minimumScoreField() =>
    find.byKey(const ValueKey('topic-editor-minimum-score'));
Finder _targetScoreField() =>
    find.byKey(const ValueKey('topic-editor-target-score'));
Finder _deckField() => find.byKey(const ValueKey('topic-editor-deck'));
Finder _saveButton() => find.byKey(const ValueKey('topic-editor-save'));
Finder _tile(String field) => find.byKey(ValueKey('topic-editor-tile-$field'));

/// The eight controls the compact editor shows, in display order.
const _controlKeys = [
  'topic-editor-tile-name',
  'topic-editor-tile-description',
  'topic-editor-tile-priority',
  'topic-editor-tile-minimumScore',
  'topic-editor-tile-targetScore',
  'topic-editor-tile-deck',
  'topic-editor-download-json',
  'topic-editor-update-json',
];

const _removedGroupKeys = [
  'topic-editor-group-details',
  'topic-editor-group-study-targets',
  'topic-editor-group-ankidroid',
  'topic-editor-group-topic-file',
];

Finder _sectionHeaders() => find.descendant(
  of: find.byType(TopicEditorSheet),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.header == true,
  ),
);

/// Asserts the sheet is one continuous form: every control is present in
/// order, adjacent controls touch, and no section heading or description is
/// left between them.
void _expectCompactForm(WidgetTester tester) {
  var previousBottom = double.negativeInfinity;
  for (final (index, key) in _controlKeys.indexed) {
    final control = find.byKey(ValueKey(key));
    expect(control, findsOneWidget);
    final rect = tester.getRect(control);
    if (index > 0) {
      expect(rect.top, greaterThanOrEqualTo(previousBottom - 0.5));
      // No leftover section spacer: the rows form one continuous column.
      expect(rect.top - previousBottom, lessThanOrEqualTo(0.5));
    }
    previousBottom = rect.bottom;
  }
  for (final key in _removedGroupKeys) {
    expect(find.byKey(ValueKey(key)), findsNothing);
  }
  for (final label in const [
    'DETAILS',
    'STUDY TARGETS',
    'ANKIDROID',
    'TOPIC FILE',
  ]) {
    expect(find.text(label), findsNothing);
  }
  expect(
    find.textContaining('Priority 1 is highest'),
    findsNothing,
    reason: 'the study-target guidance paragraph must be gone',
  );
  expect(find.textContaining('red below the minimum'), findsNothing);
  expect(find.textContaining('normal between the two'), findsNothing);
  expect(find.textContaining('green at or above the target'), findsNothing);
  expect(find.textContaining('Blank uses the default deck'), findsNothing);
  expect(find.textContaining('One file with this topic'), findsNothing);
  expect(find.textContaining('target must be at least'), findsNothing);
  expect(_sectionHeaders(), findsNothing);
}

Finder _sheetScrollable() => find
    .descendant(
      of: find.byType(TopicEditorSheet),
      matching: find.byType(Scrollable),
    )
    .first;

Finder _archivedButton() => find.byWidgetPredicate(
  (widget) => widget is M3EIconButton && widget.tooltip == 'Archived topics',
);

Future<void> _enter(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await pumpFrames(tester);
  await tester.enterText(finder, text);
  await pumpFrames(tester);
}

/// Taps the header of a field tile to expand or collapse its inline editor.
Future<void> _tapTileHeader(
  WidgetTester tester,
  String field,
  String title,
) async {
  await tester.ensureVisible(_tile(field));
  await pumpFrames(tester);
  await tester.tap(
    find.descendant(of: _tile(field), matching: find.text(title)).first,
  );
  await pumpFrames(tester);
}

Future<void> _openField(WidgetTester tester, String field, String title) async {
  await _tapTileHeader(tester, field, title);
}

/// Asserts the editor is a modal bottom sheet rather than a pushed page.
void _expectTopicSheet(WidgetTester tester) {
  expect(find.byType(TopicEditorSheet), findsOneWidget);
  expect(
    find.ancestor(
      of: find.byType(TopicEditorSheet),
      matching: find.byType(AppPage),
    ),
    findsNothing,
  );
  final route = ModalRoute.of(tester.element(find.byType(TopicEditorSheet)));
  expect(route, isA<RawDialogRoute<bool>>());
}

Future<void> _openFromLongPress(WidgetTester tester) async {
  await tester.longPress(find.text('Cloud'));
  await pumpFrames(tester);
  await tester.tap(find.text('Edit topic'));
  await pumpFrames(tester);
  _expectTopicSheet(tester);
}

Future<void> _loadTestFont() async {
  final bytes = await File('test/fixtures/Roboto-Regular.ttf').readAsBytes();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadTestFont);

  testWidgets('the sheet shows every control as one compact form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 1,
      ankiDeck: 'Cloud deck',
    );

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    expect(find.text('Edit topic'), findsOneWidget);
    expect(find.byType(M3EDialog), findsNothing);
    expect(find.byType(OptionTile), findsNWidgets(8));
    _expectCompactForm(tester);

    expect(
      find.descendant(of: _tile('name'), matching: find.text('Cloud')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _tile('description'),
        matching: find.text('Topic description'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _tile('priority'),
        matching: find.text('1 · highest'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _tile('minimumScore'), matching: find.text('70%')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _tile('targetScore'), matching: find.text('80%')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _tile('deck'), matching: find.text('Cloud deck')),
      findsOneWidget,
    );
    expect(find.text('Minimum score'), findsOneWidget);
    expect(find.text('Target score'), findsOneWidget);
    expect(find.text('AnkiDroid deck'), findsOneWidget);
    expect(find.text('Browse decks'), findsNothing);

    await _openField(tester, 'name', 'Name');
    expect(_nameField(), findsOneWidget);
    expect(_descriptionField(), findsNothing);
    expect(_priorityField(), findsNothing);
    expect(_deckField(), findsNothing);

    await _openField(tester, 'description', 'Description');
    expect(_nameField(), findsNothing);
    expect(_descriptionField(), findsOneWidget);

    await _tapTileHeader(tester, 'description', 'Description');
    expect(_descriptionField(), findsNothing);

    await _openField(tester, 'minimumScore', 'Minimum score');
    expect(_minimumScoreField(), findsOneWidget);
    expect(
      tester.widget<M3ETextField>(_minimumScoreField()).controller!.text,
      '70',
    );

    await _openField(tester, 'targetScore', 'Target score');
    expect(_targetScoreField(), findsOneWidget);
    expect(
      tester.widget<M3ETextField>(_targetScoreField()).controller!.text,
      '80',
    );
    expect(find.textContaining('target must be at least'), findsNothing);

    await _openField(tester, 'deck', 'AnkiDroid deck');
    expect(_deckField(), findsOneWidget);
    expect(find.text('Browse decks'), findsOneWidget);
    _expectCompactForm(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every control keeps an accessible name and value', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 1,
      ankiDeck: 'Cloud deck',
    );

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    const labels = {
      'name': ('Name', 'Cloud'),
      'description': ('Description', 'Topic description'),
      'priority': ('Priority', '1 · highest'),
      'minimumScore': ('Minimum score', '70%'),
      'targetScore': ('Target score', '80%'),
      'deck': ('AnkiDroid deck', 'Cloud deck'),
      'download-json': (
        'Download topic JSON',
        'Share every practice in this topic as a file',
      ),
      'update-json': (
        'Update topic JSON',
        'Add or modify practices and questions from a file',
      ),
    };
    for (final MapEntry(key: field, value: (title, value)) in labels.entries) {
      final data = tester
          .getSemantics(
            find.byKey(
              ValueKey(
                field.endsWith('-json')
                    ? 'topic-editor-$field'
                    : 'topic-editor-tile-$field',
              ),
            ),
          )
          .getSemanticsData();
      expect(data.label, title);
      expect(data.value, value);
      expect(data.flagsCollection.isButton, isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press menu opens the sheet and saves every field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 1,
    );

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    expect(find.text('Edit topic'), findsOneWidget);
    expect(find.text('AnkiDroid deck'), findsOneWidget);

    await _openField(tester, 'name', 'Name');
    await _enter(tester, _nameField(), 'Cloud networking');
    await _openField(tester, 'description', 'Description');
    await _enter(tester, _descriptionField(), 'Updated topic description');
    await _openField(tester, 'priority', 'Priority');
    await _enter(tester, _priorityField(), '3');
    await _openField(tester, 'deck', 'AnkiDroid deck');
    await _enter(tester, _deckField(), 'Cloud deck');

    await tester.tap(_saveButton());
    await pumpFrames(tester);

    expect(find.byType(TopicEditorSheet), findsNothing);
    expect(find.text('Topic updated.'), findsOneWidget);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored, isNotNull);
    expect(stored!.name, 'Cloud networking');
    expect(stored.description, 'Updated topic description');
    expect(stored.priority, 3);
    expect(stored.ankiDeck, 'Cloud deck');
    expect(find.text('Cloud networking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an archived topic opens the sheet and keeps its archived state',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await harness.seedPractice(
        topicName: 'Cloud',
        practiceName: 'Core',
        count: 1,
      );
      await harness.practices.setTopicArchived(seeded.topicId, true);

      await pumpTestApp(
        tester,
        home: const HomePage(),
        harness: harness,
        fontFamily: 'Roboto',
      );
      await tester.tap(_archivedButton());
      await pumpFrames(tester);
      expect(find.text('Archived topics'), findsOneWidget);

      await tester.tap(find.text('Cloud'));
      await pumpFrames(tester);
      await tester.tap(find.text('Edit topic'));
      await pumpFrames(tester);
      _expectTopicSheet(tester);

      await _openField(tester, 'priority', 'Priority');
      await _enter(tester, _priorityField(), '2');
      await tester.tap(_saveButton());
      await pumpFrames(tester);

      final stored = await harness.practices.topicById(seeded.topicId);
      expect(stored!.priority, 2);
      expect(stored.archived, isTrue);
      expect(stored.name, 'Cloud');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('validation blocks an empty name and an out-of-range priority', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 1,
    );

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await _openField(tester, 'name', 'Name');
    await _enter(tester, _nameField(), '');
    await tester.tap(_saveButton());
    await pumpFrames(tester);
    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.byType(TopicEditorSheet), findsOneWidget);

    await _enter(tester, _nameField(), 'Cloud');
    await _openField(tester, 'priority', 'Priority');
    await _enter(tester, _priorityField(), '9');
    // Collapse the tile: saving must reopen it to show the error.
    await _tapTileHeader(tester, 'priority', 'Priority');
    expect(_priorityField(), findsNothing);
    await tester.tap(_saveButton());
    await pumpFrames(tester);
    expect(find.text('Use a number from 1 to 5.'), findsOneWidget);
    expect(_priorityField(), findsOneWidget);
    expect(find.byType(TopicEditorSheet), findsOneWidget);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.name, 'Cloud');
    expect(stored.priority, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel closes a clean sheet without a warning', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester);

    expect(find.byType(TopicEditorSheet), findsNothing);
    expect(find.text('Discard changes?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dirty back asks before discarding changes', (tester) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await _openField(tester, 'description', 'Description');
    await _enter(tester, _descriptionField(), 'Unsaved description');
    await tester.binding.handlePopRoute();
    await pumpFrames(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byType(TopicEditorSheet), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(M3EDialog),
        matching: find.text('Cancel'),
      ),
    );
    await pumpFrames(tester);
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(TopicEditorSheet), findsOneWidget);

    await tester.binding.handlePopRoute();
    await pumpFrames(tester);
    await tester.tap(find.text('Discard'));
    await pumpFrames(tester);

    expect(find.byType(TopicEditorSheet), findsNothing);
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Topic description');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping outside a dirty sheet asks before discarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await _openField(tester, 'description', 'Description');
    await _enter(tester, _descriptionField(), 'Unsaved description');

    await tester.tapAt(const Offset(4, 4));
    await pumpFrames(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byType(TopicEditorSheet), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await pumpFrames(tester);

    expect(find.byType(TopicEditorSheet), findsNothing);
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Topic description');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet stays usable at 360 dp with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _openField(tester, 'deck', 'AnkiDroid deck');
    await tester.scrollUntilVisible(
      find.text('Browse decks'),
      250,
      scrollable: _sheetScrollable(),
    );
    await pumpFrames(tester);
    expect(find.text('Browse decks'), findsOneWidget);
    expect(_saveButton(), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The pinned action row stays above the on-screen keyboard.
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await pumpFrames(tester);
    expect(_saveButton().hitTestable(), findsOneWidget);
    expect(tester.getRect(_saveButton()).bottom, lessThanOrEqualTo(720 - 260));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the compact sheet stays readable at 320 dp and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    final topic = Topic(
      id: seeded.topicId,
      name: 'Cloud',
      description: 'Topic description',
      priority: 1,
      ankiDeck: null,
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: _TopicEditHost(topic: topic),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await tester.tap(find.text('edit'));
    await pumpFrames(tester);
    _expectTopicSheet(tester);

    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final key in _controlKeys) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        200,
        scrollable: _sheetScrollable(),
      );
      await pumpFrames(tester);
      expect(find.byKey(ValueKey(key)), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    expect(_saveButton(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the compact sheet stays usable in landscape with the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    final topic = Topic(
      id: seeded.topicId,
      name: 'Cloud',
      description: 'Topic description',
      priority: 1,
      ankiDeck: null,
      createdAt: harness.clock.now().toUtc(),
    );

    await pumpTestApp(
      tester,
      home: _TopicEditHost(topic: topic),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await tester.tap(find.text('edit'));
    await pumpFrames(tester);
    _expectTopicSheet(tester);

    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _openField(tester, 'name', 'Name');
    expect(_nameField(), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await pumpFrames(tester);
    expect(_saveButton().hitTestable(), findsOneWidget);
    expect(tester.getRect(_saveButton()).bottom, lessThanOrEqualTo(360 - 160));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a stale topic snapshot keeps the deck after a restore-like load',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final harness = TestHarness();
      addTearDown(harness.close);
      final seeded = await harness.seedPractice(
        topicName: 'Cloud',
        practiceName: 'Core',
        count: 1,
        ankiDeck: 'Cloud deck',
      );
      final stale = Topic(
        id: seeded.topicId,
        name: 'Cloud',
        description: 'Stale description',
        priority: null,
        ankiDeck: null,
        createdAt: harness.clock.now().toUtc(),
      );

      await pumpTestApp(
        tester,
        home: _TopicEditHost(topic: stale),
        harness: harness,
        fontFamily: 'Roboto',
      );
      await tester.tap(find.text('edit'));
      await pumpFrames(tester);
      _expectTopicSheet(tester);

      await _openField(tester, 'deck', 'AnkiDroid deck');
      expect(
        tester.widget<M3ETextField>(_deckField()).controller!.text,
        'Cloud deck',
      );
      await _openField(tester, 'description', 'Description');
      expect(
        tester.widget<M3ETextField>(_descriptionField()).controller!.text,
        'Topic description',
      );

      await _openField(tester, 'name', 'Name');
      await _enter(tester, _nameField(), 'Cloud restored');
      await tester.tap(_saveButton());
      await pumpFrames(tester);

      final stored = await harness.practices.topicById(seeded.topicId);
      expect(stored!.name, 'Cloud restored');
      expect(stored.ankiDeck, 'Cloud deck');
      expect(stored.description, 'Topic description');
      expect(stored.priority, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saves minimum and target score thresholds', (tester) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await _openField(tester, 'minimumScore', 'Minimum score');
    await _enter(tester, _minimumScoreField(), '60');
    await _openField(tester, 'targetScore', 'Target score');
    await _enter(tester, _targetScoreField(), '90');

    await tester.tap(_saveButton());
    await pumpFrames(tester);

    expect(find.byType(TopicEditorSheet), findsNothing);
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.minimumScore, 60);
    expect(stored.targetScore, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates score ranges and target at least minimum', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await _openField(tester, 'minimumScore', 'Minimum score');
    await _enter(tester, _minimumScoreField(), '101');
    await _tapTileHeader(tester, 'minimumScore', 'Minimum score');
    expect(_minimumScoreField(), findsNothing);
    await tester.tap(_saveButton());
    await pumpFrames(tester);
    expect(find.text('Use a number from 0 to 100.'), findsOneWidget);
    expect(_minimumScoreField(), findsOneWidget);
    expect(find.byType(TopicEditorSheet), findsOneWidget);

    await _enter(tester, _minimumScoreField(), '80');
    await _openField(tester, 'targetScore', 'Target score');
    await _enter(tester, _targetScoreField(), '70');
    await tester.tap(_saveButton());
    await pumpFrames(tester);
    expect(
      find.text('Target must be at least the minimum score.'),
      findsOneWidget,
    );
    expect(_targetScoreField(), findsOneWidget);
    expect(find.byType(TopicEditorSheet), findsOneWidget);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.minimumScore, 70);
    expect(stored.targetScore, 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an edited score marks the sheet dirty', (tester) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await _openField(tester, 'targetScore', 'Target score');
    await _enter(tester, _targetScoreField(), '90');
    await tester.binding.handlePopRoute();
    await pumpFrames(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byType(TopicEditorSheet), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await pumpFrames(tester);
    expect(find.byType(TopicEditorSheet), findsNothing);
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.targetScore, 80);
    expect(tester.takeException(), isNull);
  });
}
