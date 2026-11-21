import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/providers.dart';
import 'package:question_practice/core/ui/widgets.dart';
import 'package:question_practice/features/import/domain/import_service.dart';
import 'package:question_practice/features/home/home_page.dart';
import 'package:question_practice/features/topics/domain/topic_edit_service.dart';
import 'package:question_practice/features/topics/domain/topic_update_models.dart';
import 'package:question_practice/features/topics/topic_editor_sheet.dart';
import 'package:question_practice/features/topics/topic_update_preview_page.dart';

import '../../helpers/test_harness.dart';

class _RecordingTopicEditService extends TopicEditService {
  _RecordingTopicEditService({
    required super.practices,
    required super.importService,
    required super.clock,
  });

  int? sharedTopicId;

  @override
  Future<File> shareTopicJson(int topicId) async {
    sharedTopicId = topicId;
    return File('${Directory.systemTemp.path}/fake-topic.json');
  }
}

Finder _descriptionField() =>
    find.byKey(const ValueKey('topic-editor-description'));

Finder _sheetScrollable() => find
    .descendant(
      of: find.byType(TopicEditorSheet),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _openEditor(WidgetTester tester) async {
  await tester.longPress(find.text('Cloud'));
  await pumpFrames(tester);
  await tester.tap(find.text('Edit topic'));
  await pumpFrames(tester);
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _sheetScrollable());
  await pumpFrames(tester);
}

void main() {
  testWidgets('topic options only offer edit, archive and delete', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 1,
    );

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    await tester.longPress(find.text('Cloud'));
    await pumpFrames(tester);

    expect(find.byType(OptionTile), findsNWidgets(3));
    expect(find.text('Edit topic'), findsOneWidget);
    expect(find.text('Archive topic'), findsOneWidget);
    expect(find.text('Delete topic'), findsOneWidget);
    expect(find.text('Download topic JSON'), findsNothing);
    expect(find.text('Update topic JSON'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the topic update preview labels the minimum as Minimum score', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);

    await pumpTestApp(
      tester,
      home: const TopicUpdatePreviewPage(
        preview: TopicUpdatePreview(
          topicId: 1,
          topicName: 'Cloud',
          fileName: 'cloud.json',
          practices: [],
          minimumScore: 70,
          targetScore: 80,
          hasMetadataChanges: true,
        ),
      ),
      harness: harness,
    );

    expect(find.text('Minimum approval score'), findsNothing);
    expect(find.text('Minimum score'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit topic offers topic JSON download and update', (
    tester,
  ) async {
    final harness = TestHarness();
    addTearDown(harness.close);
    final seeded = await harness.seedPractice(
      topicName: 'Cloud',
      practiceName: 'Core',
      count: 1,
    );
    final service = _RecordingTopicEditService(
      practices: harness.practices,
      importService: ImportService(
        repository: harness.practices,
        clock: harness.clock,
      ),
      clock: harness.clock,
    );

    await pumpTestApp(
      tester,
      home: const HomePage(),
      harness: harness,
      overrides: [topicEditServiceProvider.overrideWithValue(service)],
    );
    await _openEditor(tester);

    expect(find.text('TOPIC FILE'), findsNothing);
    expect(find.textContaining('One file with this topic'), findsNothing);
    expect(
      find.byKey(const ValueKey('topic-editor-group-topic-file')),
      findsNothing,
    );
    expect(find.text('Download topic JSON'), findsOneWidget);
    expect(
      find.text('Share every practice in this topic as a file'),
      findsOneWidget,
    );
    expect(find.text('Update topic JSON'), findsOneWidget);
    expect(
      find.text('Add or modify practices and questions from a file'),
      findsOneWidget,
    );
    expect(find.byType(OptionTile), findsNWidgets(8));

    await _reveal(tester, find.text('Download topic JSON'));
    await tester.tap(find.text('Download topic JSON'));
    await pumpFrames(tester);

    expect(service.sharedTopicId, seeded.topicId);
    expect(find.byType(TopicEditorSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('updating over unsaved edits asks before discarding them', (
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

    await pumpTestApp(tester, home: const HomePage(), harness: harness);
    await _openEditor(tester);

    await tester.ensureVisible(find.text('Description'));
    await pumpFrames(tester);
    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('topic-editor-tile-description')),
            matching: find.text('Description'),
          )
          .first,
    );
    await pumpFrames(tester);
    await tester.enterText(_descriptionField(), 'Unsaved description');
    await pumpFrames(tester);

    await _reveal(tester, find.text('Update topic JSON'));
    await tester.tap(find.text('Update topic JSON'));
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
    expect(
      tester.widget<M3ETextField>(_descriptionField()).controller!.text,
      'Unsaved description',
    );
    final stored = await harness.practices.topicById(seeded.topicId);
    expect(stored!.description, 'Topic description');
    expect(tester.takeException(), isNull);
  });
}
