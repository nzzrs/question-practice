import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/data/practice_repository.dart';
import 'package:question_practice/core/database/app_database.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/import/domain/import_service.dart';
import 'package:question_practice/features/topics/domain/topic_edit_service.dart';
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

/// Counts writes so reopening a clean sheet can prove it does not save again.
class _CountingPracticeRepository extends PracticeRepository {
  // The repository's constructor parameters are private to its library.
  // ignore: use_super_parameters
  _CountingPracticeRepository(AppDatabase database, Clock clock)
    : super(database, clock);

  int updateCalls = 0;

  @override
  Future<void> updateTopic({
    required int id,
    required String name,
    required String description,
    required int? priority,
    String? ankiDeck,
    int minimumScore = 70,
    int targetScore = 80,
  }) {
    updateCalls++;
    return super.updateTopic(
      id: id,
      name: name,
      description: description,
      priority: priority,
      ankiDeck: ankiDeck,
      minimumScore: minimumScore,
      targetScore: targetScore,
    );
  }
}

/// Blocks the first write so a JSON import can be attempted while it runs.
class _BlockingPracticeRepository extends PracticeRepository {
  // The repository's constructor parameters are private to its library.
  // ignore: use_super_parameters
  _BlockingPracticeRepository(AppDatabase database, Clock clock)
    : super(database, clock);

  Completer<void>? blocker;
  int updateCalls = 0;

  @override
  Future<void> updateTopic({
    required int id,
    required String name,
    required String description,
    required int? priority,
    String? ankiDeck,
    int minimumScore = 70,
    int targetScore = 80,
  }) async {
    updateCalls++;
    final gate = blocker;
    if (gate != null) {
      blocker = null;
      await gate.future;
    }
    return super.updateTopic(
      id: id,
      name: name,
      description: description,
      priority: priority,
      ankiDeck: ankiDeck,
      minimumScore: minimumScore,
      targetScore: targetScore,
    );
  }
}

base class _PickedPlatformFile extends PlatformFile {
  _PickedPlatformFile(this.bytes);

  final Uint8List bytes;

  @override
  String get name => 'topic.json';

  @override
  Uri get uri => Uri.file('/tmp/topic.json');

  @override
  Never get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.value(bytes);
}

class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform(this.file);

  final PlatformFile? file;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return file == null ? const [] : [file!];
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
Finder _tile(String field) => find.byKey(ValueKey('topic-editor-tile-$field'));
Finder _updateJsonTile() =>
    find.byKey(const ValueKey('topic-editor-update-json'));

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

/// Enters text without waiting for the debounce, so a test controls the write.
Future<void> _type(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await pumpFrames(tester, frames: 2);
  await tester.enterText(finder, text);
  await pumpFrames(tester, frames: 2);
}

Future<void> _waitForAutosave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await pumpFrames(tester, frames: 8);
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await pumpFrames(tester, frames: 10);
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

Future<void> _openFromLongPress(
  WidgetTester tester, {
  String topicName = 'Cloud',
}) async {
  await tester.longPress(find.text(topicName));
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

Future<Uint8List> _updateBytes(
  TestHarness harness,
  int topicId,
  String description,
) async {
  final service = TopicEditService(
    practices: harness.practices,
    importService: ImportService(
      repository: harness.practices,
      clock: harness.clock,
    ),
    clock: harness.clock,
  );
  final payload = await service.buildTopicPayload(topicId);
  final topic = (payload['topics']! as List<Object?>).single! as Map;
  topic['description'] = description;
  return Uint8List.fromList(utf8.encode(service.encodePayload(payload)));
}

void main() {
  setUpAll(_loadTestFont);

  testWidgets('the sheet shows every control as one compact form with no '
      'Save or Cancel buttons', (tester) async {
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
    expect(find.byKey(const ValueKey('topic-editor-save')), findsNothing);
    expect(find.byKey(const ValueKey('topic-editor-cancel')), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
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

  testWidgets('valid typing auto-saves after the debounce and refreshes '
      'topic providers', (tester) async {
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

    await _openField(tester, 'name', 'Name');
    await _type(tester, _nameField(), 'Cloud networking');
    final before = await harness.practices.topicById(seeded.topicId);
    expect(before!.name, 'Cloud');

    await tester.pump(const Duration(milliseconds: 250));
    final beforeDebounce = await harness.practices.topicById(seeded.topicId);
    expect(beforeDebounce!.name, 'Cloud');

    await _waitForAutosave(tester);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.name, 'Cloud networking');
    expect(find.byType(TopicEditorSheet), findsOneWidget);

    await _closeSheet(tester);
    expect(find.byType(TopicEditorSheet), findsNothing);
    expect(find.text('Cloud networking'), findsOneWidget);
    expect(find.text('Topic updated.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('close flushes the last valid edit without a Save button', (
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
    await _type(tester, _descriptionField(), 'Flushed on close');
    await _closeSheet(tester);

    expect(find.byType(TopicEditorSheet), findsNothing);
    expect(find.text('Topic updated.'), findsOneWidget);
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Flushed on close');
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving a field flushes valid edits before the debounce', (
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

    await _openField(tester, 'name', 'Name');
    await _type(tester, _nameField(), 'Focus saved');
    tester.widget<M3ETextField>(_nameField()).focusNode!.unfocus();
    await pumpFrames(tester, frames: 5);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.name, 'Focus saved');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a successfully auto-saved baseline is not written again on '
      'close or reopen', (tester) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    final repository = _CountingPracticeRepository(
      harness.database,
      harness.clock,
    );

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      overrides: [topicRepositoryProvider.overrideWithValue(repository)],
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await _openField(tester, 'name', 'Name');
    await _type(tester, _nameField(), 'Cloud saved');
    await _waitForAutosave(tester);
    expect(repository.updateCalls, 1);

    await _closeSheet(tester);
    expect(find.byType(TopicEditorSheet), findsNothing);
    expect(repository.updateCalls, 1);

    await tester.pump(const Duration(seconds: 5));
    await pumpFrames(tester);
    expect(find.text('Topic updated.'), findsNothing);

    await _openFromLongPress(tester, topicName: 'Cloud saved');
    await _closeSheet(tester);
    expect(find.byType(TopicEditorSheet), findsNothing);
    expect(repository.updateCalls, 1);
    expect(find.text('Topic updated.'), findsNothing);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.name, 'Cloud saved');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty name never persists and blocks closing with a focused '
      'error', (tester) async {
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

    await _openField(tester, 'name', 'Name');
    await _type(tester, _nameField(), '');
    await _waitForAutosave(tester);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.name, 'Cloud');

    await _closeSheet(tester);
    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(find.text('Name is required.'), findsOneWidget);
    expect(_nameField(), findsOneWidget);
    expect(
      tester.widget<M3ETextField>(_nameField()).focusNode!.hasFocus,
      isTrue,
    );
    expect(find.text('Topic updated.'), findsNothing);

    final after = await harness.practices.topicById(seeded.topicId);
    expect(after!.name, 'Cloud');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a blocked close can discard unsaved edits and keep the saved '
      'baseline', (tester) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    final repository = _CountingPracticeRepository(
      harness.database,
      harness.clock,
    );

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      overrides: [topicRepositoryProvider.overrideWithValue(repository)],
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await _openField(tester, 'description', 'Description');
    await _type(tester, _descriptionField(), 'Saved baseline');
    await _waitForAutosave(tester);
    expect(repository.updateCalls, 1);

    await _openField(tester, 'name', 'Name');
    await _type(tester, _nameField(), '');
    await _closeSheet(tester);

    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey('topic-editor-close-blocked')),
      findsOneWidget,
    );
    expect(find.text('Discard changes'), findsOneWidget);
    expect(find.text('Name is required.'), findsOneWidget);

    await tester.ensureVisible(find.text('Discard changes'));
    await pumpFrames(tester);
    await tester.tap(find.text('Discard changes'));
    await pumpFrames(tester, frames: 10);

    expect(find.byType(TopicEditorSheet), findsNothing);
    expect(repository.updateCalls, 1);
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.name, 'Cloud');
    expect(stored.description, 'Saved baseline');

    await tester.pump(const Duration(seconds: 5));
    await pumpFrames(tester);
    final after = await harness.practices.topicById(seeded.topicId);
    expect(after!.name, 'Cloud');
    expect(after.description, 'Saved baseline');
    expect(tester.takeException(), isNull);
  });

  testWidgets('updating from JSON while an invalid edit waits asks before '
      'replacing it', (tester) async {
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

    await _openField(tester, 'name', 'Name');
    await _type(tester, _nameField(), '');
    await _waitForAutosave(tester);

    await tester.ensureVisible(_updateJsonTile());
    await pumpFrames(tester);
    await tester.tap(_updateJsonTile());
    await pumpFrames(tester);

    expect(find.text('Replace this topic?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(M3EDialog),
        matching: find.text('Cancel'),
      ),
    );
    await pumpFrames(tester);

    expect(find.text('Replace this topic?'), findsNothing);
    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(find.text('Name is required.'), findsOneWidget);
    expect(tester.widget<M3ETextField>(_nameField()).controller!.text, '');
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.name, 'Cloud');
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid priority and score ranges never persist and block '
      'closing on the invalid field', (tester) async {
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

    await _openField(tester, 'priority', 'Priority');
    await _type(tester, _priorityField(), '9');
    await _waitForAutosave(tester);
    final afterPriority = await harness.practices.topicById(seeded.topicId);
    expect(afterPriority!.priority, 1);

    await _tapTileHeader(tester, 'priority', 'Priority');
    await _closeSheet(tester);
    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(find.text('Use a number from 1 to 5.'), findsOneWidget);
    expect(_priorityField(), findsOneWidget);
    expect(
      tester.widget<M3ETextField>(_priorityField()).focusNode!.hasFocus,
      isTrue,
    );

    await _type(tester, _priorityField(), '2');
    await _openField(tester, 'minimumScore', 'Minimum score');
    await _type(tester, _minimumScoreField(), '101');
    await _waitForAutosave(tester);
    final afterMinimum = await harness.practices.topicById(seeded.topicId);
    expect(afterMinimum!.minimumScore, 70);
    expect(afterMinimum.priority, 2);

    await _tapTileHeader(tester, 'minimumScore', 'Minimum score');
    await _closeSheet(tester);
    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(find.text('Use a number from 0 to 100.'), findsOneWidget);
    expect(_minimumScoreField(), findsOneWidget);
    expect(
      tester.widget<M3ETextField>(_minimumScoreField()).focusNode!.hasFocus,
      isTrue,
    );

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.minimumScore, 70);
    expect(stored.targetScore, 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty score never persists and blocks closing', (
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

    await _openField(tester, 'targetScore', 'Target score');
    await _type(tester, _targetScoreField(), '');
    await _waitForAutosave(tester);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.targetScore, 80);

    await _closeSheet(tester);
    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(find.text('Use a number from 0 to 100.'), findsOneWidget);
    expect(
      tester.widget<M3ETextField>(_targetScoreField()).focusNode!.hasFocus,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('target below minimum never persists and blocks closing', (
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
    await _type(tester, _minimumScoreField(), '80');
    await _openField(tester, 'targetScore', 'Target score');
    await _type(tester, _targetScoreField(), '70');
    await _waitForAutosave(tester);

    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.minimumScore, 80);
    expect(stored.targetScore, 80);

    await _tapTileHeader(tester, 'targetScore', 'Target score');
    await _closeSheet(tester);
    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(
      find.text('Target must be at least the minimum score.'),
      findsOneWidget,
    );
    expect(_targetScoreField(), findsOneWidget);
    expect(
      tester.widget<M3ETextField>(_targetScoreField()).focusNode!.hasFocus,
      isTrue,
    );
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
      await _type(tester, _priorityField(), '2');
      await _closeSheet(tester);

      final stored = await harness.practices.topicById(seeded.topicId);
      expect(stored!.priority, 2);
      expect(stored.archived, isTrue);
      expect(stored.name, 'Cloud');
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.byKey(const ValueKey('topic-editor-save')), findsNothing);

    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await pumpFrames(tester);
    await tester.scrollUntilVisible(
      find.text('Browse decks'),
      150,
      scrollable: _sheetScrollable(),
    );
    await pumpFrames(tester);
    expect(find.text('Browse decks').hitTestable(), findsOneWidget);
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

    expect(find.byKey(const ValueKey('topic-editor-save')), findsNothing);
    expect(tester.takeException(), isNull);

    await _openField(tester, 'name', 'Name');
    await _type(tester, _nameField(), '');
    await _closeSheet(tester);
    expect(
      find.byKey(const ValueKey('topic-editor-close-blocked')),
      findsOneWidget,
    );
    expect(find.text('Discard changes').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Discard changes'));
    await pumpFrames(tester, frames: 10);
    expect(find.byType(TopicEditorSheet), findsNothing);
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
    for (final key in _controlKeys) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        120,
        scrollable: _sheetScrollable(),
      );
      await pumpFrames(tester);
      expect(find.byKey(ValueKey(key)), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await _type(tester, _nameField(), '');
    await _closeSheet(tester);
    expect(find.text('Discard changes').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Discard changes'));
    await pumpFrames(tester, frames: 10);
    expect(find.byType(TopicEditorSheet), findsNothing);
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
      await _type(tester, _nameField(), 'Cloud restored');
      await _closeSheet(tester);

      final stored = await harness.practices.topicById(seeded.topicId);
      expect(stored!.name, 'Cloud restored');
      expect(stored.ankiDeck, 'Cloud deck');
      expect(stored.description, 'Topic description');
      expect(stored.priority, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saves minimum and target score thresholds on close', (
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
    await _type(tester, _minimumScoreField(), '60');
    await _openField(tester, 'targetScore', 'Target score');
    await _type(tester, _targetScoreField(), '90');

    await _closeSheet(tester);
    expect(find.byType(TopicEditorSheet), findsNothing);
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.minimumScore, 60);
    expect(stored.targetScore, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a JSON update cannot be started over an autosave in flight and '
      'no pending autosave overwrites the import', (tester) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(topicName: 'Cloud', count: 1);
    final repository = _BlockingPracticeRepository(
      harness.database,
      harness.clock,
    );
    final gate = Completer<void>();
    repository.blocker = gate;
    final originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _FakeFilePickerPlatform(
      _PickedPlatformFile(
        await _updateBytes(harness, seeded.topicId, 'Imported description'),
      ),
    );
    addTearDown(() => FilePickerPlatform.instance = originalPicker);

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      overrides: [topicRepositoryProvider.overrideWithValue(repository)],
      fontFamily: 'Roboto',
    );
    await _openFromLongPress(tester);

    await _openField(tester, 'description', 'Description');
    await _type(tester, _descriptionField(), 'Pending autosave');
    await tester.pump(const Duration(milliseconds: 700));
    await pumpFrames(tester, frames: 4);
    expect(repository.updateCalls, 1);

    // The JSON action is disabled while the write is in flight.
    await tester.ensureVisible(_updateJsonTile());
    await pumpFrames(tester);
    expect(tester.widget<OptionTile>(_updateJsonTile()).onTap, isNull);
    expect(find.text('Replace this topic?'), findsNothing);

    gate.complete();
    await pumpFrames(tester, frames: 8);
    var stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Pending autosave');

    await tester.tap(_updateJsonTile());
    await pumpFrames(tester);
    expect(find.text('Apply changes'), findsOneWidget);
    await tester.tap(find.text('Apply changes'));
    await pumpFrames(tester);
    await pumpFrames(tester);

    stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Imported description');

    // A stale debounce or queued write must not resurrect the typed value.
    await _waitForAutosave(tester);
    stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Imported description');
    expect(tester.takeException(), isNull);
  });
}
