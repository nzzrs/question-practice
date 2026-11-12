import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/topics/topic_actions.dart';
import 'package:question_practice/features/topics/topic_editor_page.dart';

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
Finder _deckField() => find.byKey(const ValueKey('topic-editor-deck'));
Finder _saveButton() => find.byKey(const ValueKey('topic-editor-save'));

Finder _archivedButton() => find.byWidgetPredicate(
  (widget) => widget is M3EIconButton && widget.tooltip == 'Archived topics',
);

Future<void> _enter(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await pumpFrames(tester);
  await tester.enterText(finder, text);
  await pumpFrames(tester);
}

Future<void> _openFromLongPress(WidgetTester tester) async {
  await tester.longPress(find.text('Cloud'));
  await pumpFrames(tester);
  await tester.tap(find.text('Edit topic'));
  await pumpFrames(tester);
  expect(find.byType(TopicEditorPage), findsOneWidget);
}

Future<void> _loadTestFont() async {
  final bytes = await File('test/fixtures/Roboto-Regular.ttf').readAsBytes();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadTestFont);

  testWidgets('long-press menu opens the page and saves every field', (
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
    expect(find.byType(M3EDialog), findsNothing);
    expect(find.text('AnkiDroid deck'), findsOneWidget);
    expect(find.text('Browse decks'), findsOneWidget);

    await _enter(tester, _nameField(), 'Cloud networking');
    await _enter(tester, _descriptionField(), 'Updated topic description');
    await _enter(tester, _priorityField(), '3');
    await _enter(tester, _deckField(), 'Cloud deck');

    await tester.tap(_saveButton());
    await pumpFrames(tester);

    expect(find.byType(TopicEditorPage), findsNothing);
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

  testWidgets('an archived topic opens the page and keeps its archived state', (
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
    expect(find.byType(TopicEditorPage), findsOneWidget);

    await _enter(tester, _priorityField(), '2');
    await tester.tap(_saveButton());
    await pumpFrames(tester);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.priority, 2);
    expect(stored.archived, isTrue);
    expect(stored.name, 'Cloud');
    expect(tester.takeException(), isNull);
  });

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

    await _enter(tester, _nameField(), '');
    await tester.tap(_saveButton());
    await pumpFrames(tester);
    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.byType(TopicEditorPage), findsOneWidget);

    await _enter(tester, _nameField(), 'Cloud');
    await _enter(tester, _priorityField(), '9');
    await tester.tap(_saveButton());
    await pumpFrames(tester);
    expect(find.text('Use a number from 1 to 5.'), findsOneWidget);
    expect(find.byType(TopicEditorPage), findsOneWidget);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.name, 'Cloud');
    expect(stored.priority, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel closes a clean editor without a warning', (tester) async {
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

    expect(find.byType(TopicEditorPage), findsNothing);
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

    await _enter(tester, _descriptionField(), 'Unsaved description');
    await tester.binding.handlePopRoute();
    await pumpFrames(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.byType(TopicEditorPage), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(M3EDialog),
        matching: find.text('Cancel'),
      ),
    );
    await pumpFrames(tester);
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byType(TopicEditorPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await pumpFrames(tester);
    await tester.tap(find.text('Discard'));
    await pumpFrames(tester);

    expect(find.byType(TopicEditorPage), findsNothing);
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Topic description');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the page fits a 360 dp wide phone', (tester) async {
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

    expect(find.byType(TopicEditorPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Browse decks'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFrames(tester);
    expect(find.text('Browse decks'), findsOneWidget);
    expect(_saveButton(), findsOneWidget);
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
      expect(find.byType(TopicEditorPage), findsOneWidget);

      expect(
        tester.widget<M3ETextField>(_deckField()).controller!.text,
        'Cloud deck',
      );
      expect(
        tester.widget<M3ETextField>(_descriptionField()).controller!.text,
        'Topic description',
      );

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
}
